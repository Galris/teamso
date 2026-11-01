import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'service_errors.dart';
import 'api_client.dart'hide errorText;

/// Trạng thái công việc: giá trị lưu trong Firestore và nhãn hiển thị trên UI.
abstract final class TaskStatus {
  static const todo = 'todo';
  static const inProgress = 'in_progress';
  static const pendingReview = 'pending_review';
  static const revisionRequired = 'revision_required';
  static const completed = 'completed';

  static const all = [
    todo,
    inProgress,
    pendingReview,
    revisionRequired,
    completed,
  ];

  /// Chuyển nhãn UI (hoặc giá trị cũ dạng có dấu cách) về mã Firestore.
  static String toCode(String value) {
    switch (value.toLowerCase().replaceAll('_', ' ').trim()) {
      case 'cần làm':
      case 'to do':
      case 'todo':
        return todo;
      case 'đang làm':
      case 'in progress':
        return inProgress;
      case 'chờ duyệt':
      case 'pending review':
        return pendingReview;
      case 'hoàn thành':
      case 'completed':
        return completed;
      case 'cần sửa':
      case 'revision required':
        return revisionRequired;
      default:
        return value;
    }
  }
}

/// Các bước trạng thái member được phép tự chuyển.
const Map<String, Set<String>> _memberTransitions = {
  TaskStatus.todo: {TaskStatus.inProgress},
  TaskStatus.inProgress: {TaskStatus.pendingReview},
  TaskStatus.revisionRequired: {TaskStatus.inProgress},
};

/// Gộp Map từ Firestore và gắn document ID làm khóa chính.
Map<String, dynamic> _docMap(
  DocumentSnapshot<Map<String, dynamic>> doc, {
  String? projectId,
}) {
  final data = {...?doc.data(), 'id': doc.id};
  if (projectId != null) data['projectId'] = projectId;
  return data;
}

/// serverTimestamp còn pending sẽ trả null; coi như tin mới nhất chưa chốt giờ.
DateTime _stamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on ServiceException {
    rethrow;
  } catch (error) {
    throw ServiceException(errorText(error));
  }
}

abstract class _FirestoreService {
  _FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth, ApiClient? api})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance,
      _api = api ?? ApiClient();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final ApiClient _api;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  String _requireUid() {
    final uid = currentUserId;
    if (uid.isEmpty) {
      throw const ServiceException(
        'Bạn cần đăng nhập để thực hiện thao tác này.',
      );
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection('projects');

  CollectionReference<Map<String, dynamic>> _membersOf(String projectId) =>
      _projects.doc(projectId).collection('members');

  DocumentReference<Map<String, dynamic>> _memberDoc(
    String projectId,
    String uid,
  ) => _membersOf(projectId).doc(uid);

  /// Vai trò của một uid trong dự án; null nếu không phải thành viên.
  Future<String?> _roleOf(String projectId, String uid) async {
    final snapshot = await _memberDoc(projectId, uid).get();
    if (!snapshot.exists) return null;
    return (snapshot.data()?['role'] ?? 'member').toString();
  }
}

class ProjectService extends _FirestoreService {
  ProjectService({super.firestore, super.auth, super.api});

  CollectionReference<Map<String, dynamic>> _userIndex(String uid) =>
      _users.doc(uid).collection('projectMemberships');

  /// Danh sách project của người đang đăng nhập, cập nhật realtime.
  /// Mỗi bản ghi kèm `myRole` là `leader` hoặc `member`.
  Stream<List<Map<String, dynamic>>> watchMine() {
    final uid = _requireUid();
    late final StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? indexSubscription;
    final projectSubscriptions = <String, StreamSubscription>{};
    final projectCache = <String, Map<String, dynamic>>{};
    final roles = <String, String>{};
    var isLive = false;

    void emit() {
      if (!isLive || controller.isClosed) return;
      controller.add(
        projectCache.entries
            .map(
              (entry) => {
                ...entry.value,
                'myRole': roles[entry.key] ?? 'member',
              },
            )
            .toList(),
      );
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        isLive = true;
        indexSubscription = _userIndex(uid).snapshots().listen((index) {
          final activeIds = index.docs.map((doc) => doc.id).toSet();
          roles
            ..clear()
            ..addEntries(
              index.docs.map(
                (doc) => MapEntry(
                  doc.id,
                  (doc.data()['role'] ?? 'member').toString(),
                ),
              ),
            );
          for (final id
              in projectSubscriptions.keys
                  .where((id) => !activeIds.contains(id))
                  .toList()) {
            projectSubscriptions.remove(id)?.cancel();
            projectCache.remove(id);
          }
          for (final id in activeIds) {
            projectSubscriptions.putIfAbsent(
              id,
              () => _projects.doc(id).snapshots().listen((doc) {
                if (!doc.exists) {
                  projectCache.remove(id);
                } else {
                  projectCache[id] = _docMap(doc);
                }
                emit();
              }, onError: controller.addError),
            );
          }
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        isLive = false;
        await indexSubscription?.cancel();
        for (final sub in projectSubscriptions.values) {
          await sub.cancel();
        }
        projectSubscriptions.clear();
        projectCache.clear();
        roles.clear();
      },
    );
    return controller.stream;
  }

  /// Hồ sơ thành viên kèm displayName/username/avatar, lấy từ backend API.
  Future<List<Map<String, dynamic>>> listMembers(String projectId) async {
    _requireUid();
    return _guard(() async {
      final response = await _api.get('/projects/$projectId/members');
      final rows = response['members'];
      return rows is List ? rows.whereType<Map>().map(Map<String, dynamic>.from).toList() : <Map<String, dynamic>>[];
    });
  }

  Stream<List<Map<String, dynamic>>> watchMembers(String projectId) =>
      _membersOf(projectId).snapshots().asyncMap((_) => listMembers(projectId));

  Future<List<Map<String, dynamic>>> list() async {
    final uid = _requireUid();
    final index = await _guard(() => _userIndex(uid).get());
    final entries = await _guard(
      () => Future.wait(
        index.docs.map((entry) async {
          final doc = await _projects.doc(entry.id).get();
          if (!doc.exists) return null;
          return {
            ..._docMap(doc),
            'myRole': (entry.data()['role'] ?? 'member'),
          };
        }),
      ),
    );
    return entries.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> get(String projectId) async {
    final uid = _requireUid();
    final doc = await _guard(() => _projects.doc(projectId).get());
    if (!doc.exists) throw const ServiceException('Không tìm thấy dự án.');
    final role = await _guard(() => _roleOf(projectId, uid));
    if (role == null) {
      throw const ServiceException('Bạn không phải thành viên của dự án này.');
    }
    return {..._docMap(doc), 'myRole': role};
  }

  /// Project hiện tại + vai trò của người xem, cập nhật realtime.
  Stream<Map<String, dynamic>?> watch(String projectId) {
    final uid = _requireUid();
    return _projects.doc(projectId).snapshots().asyncMap((doc) async {
      if (!doc.exists) return null;
      final role = await _roleOf(projectId, uid);
      if (role == null) {
        throw const ServiceException('Bạn không có quyền xem dự án này.');
      }
      return {..._docMap(doc), 'myRole': role};
    });
  }

  /// Hoạt động gần đây của dự án, cập nhật realtime.
  Stream<List<Map<String, dynamic>>> watchActivities(String projectId) =>
      _projects
          .doc(projectId)
          .collection('activities')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs.map((d) => _docMap(d)).toList());

  Future<Map<String, dynamic>> create({
    required String name,
    String tag = '',
    String description = '',
    String coverUrl = '',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (name.trim().isEmpty) {
      throw const ServiceException('Tên dự án không được để trống.');
    }
    final response = await _guard(() => _api.post('/projects', body: {
      'name': name.trim(), 'tag': tag.trim(), 'description': description.trim(),
      'coverUrl': coverUrl,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    }));
    final project = response['project'];
    if (project is! Map) throw const ServiceException('Máy chủ không trả dữ liệu dự án.');
    return Map<String, dynamic>.from(project);

  }

  /// Mã tham gia được backend kiểm tra để không lộ dự án công khai.
  Future<Map<String, dynamic>> join(String joinCode) async {
    _requireUid();
    final code = joinCode.trim().toUpperCase();
    if (code.isEmpty) throw const ServiceException('Vui lòng nhập mã tham gia.');
    final response = await _guard(() => _api.post('/projects/join', body: {'joinCode': code}));
    final projectId = response['projectId']?.toString() ?? '';
    if (projectId.isEmpty) throw const ServiceException('Không thể tham gia dự án.');
    return get(projectId);
  }

  Future<void> addMemberByUsername(String projectId, String username) async {
    _requireUid();
    final name = username.trim().toLowerCase();
    if (name.isEmpty) throw const ServiceException('Vui lòng nhập tên đăng nhập.');
    await _guard(() => _api.post('/projects/$projectId/members', body: {'username': name}));
  }

  Future<void> removeMember(String projectId, String memberUid) async {
    _requireUid();
    await _guard(() => _api.delete('/projects/$projectId/members/$memberUid'));
  }

  Future<void> leave(String projectId) async {
    _requireUid();
    await _guard(() => _api.post('/projects/$projectId/leave'));
  }

  Future<void> update(String projectId, Map<String, dynamic> changes) async {
    _requireUid();
    await _requireLeader(projectId, 'Chỉ leader mới được cập nhật dự án.');
    const writable = {
      'name',
      'description',
      'tag',
      'coverUrl',
      'status',
      'startDate',
      'endDate',
    };
    final safe = Map<String, dynamic>.from(changes)
      ..removeWhere((key, value) => !writable.contains(key));
    if (safe.isEmpty) return;
    if (safe.containsKey('name')) {
      final name = safe['name'].toString().trim();
      if (name.isEmpty) {
        throw const ServiceException('Tên dự án không được để trống.');
      }
      safe['name'] = name;
    }
    await _guard(() => _api.patch('/projects/$projectId', body: {
      for (final entry in safe.entries)
        entry.key: entry.value is DateTime ? (entry.value as DateTime).toIso8601String() : entry.value,
    }));
  }

  /// Xóa dự án qua backend; backend cũng xóa subcollection và dọn chỉ mục
  /// projectMemberships trong hồ sơ từng thành viên.
  Future<void> delete(String projectId) async {
    _requireUid();
    await _guard(() => _api.delete('/projects/$projectId'));
  }

  Future<void> _requireLeader(String projectId, String message) async {
    final uid = _requireUid();
    final role = await _guard(() => _roleOf(projectId, uid));
    if (role != 'leader') throw ServiceException(message);
  }
}

class TaskService extends _FirestoreService {
  TaskService({super.firestore, super.auth, super.api});

  CollectionReference<Map<String, dynamic>> _tasksOf(String projectId) =>
      _projects.doc(projectId).collection('tasks');

  DocumentReference<Map<String, dynamic>> _taskDoc(
    String projectId,
    String taskId,
  ) => _tasksOf(projectId).doc(taskId);

  /// Task của một dự án, cập nhật realtime; có thể lọc theo người nhận hoặc trạng thái.
  Stream<List<Map<String, dynamic>>> watch({
    required String projectId,
    String? assigneeId,
    String? status,
  }) {
    final code = status == null ? null : TaskStatus.toCode(status);
    return _tasksOf(projectId).snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) => _docMap(doc, projectId: projectId))
              .where(
                (task) => _matches(task, code: code, assigneeId: assigneeId),
              )
              .toList()
            ..sort(_compareByDueDate),
    );
  }

  static bool _matches(
    Map<String, dynamic> task, {
    String? code,
    String? assigneeId,
  }) {
    if (code != null && task['status'] != code) return false;
    if (assigneeId?.isNotEmpty == true &&
        !_assignees(task).contains(assigneeId)) {
      return false;
    }
    return true;
  }

  static List<String> _assignees(Map<String, dynamic> task) =>
      ((task['assigneeIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();

  /// Task được giao cho người đang đăng nhập ở mọi dự án.
  Stream<List<Map<String, dynamic>>> watchMyTasks({String? status}) {
    final uid = _requireUid();
    Query<Map<String, dynamic>> query = _db
        .collectionGroup('tasks')
        .where('assigneeIds', arrayContains: uid);
    if (status?.isNotEmpty == true) {
      query = query.where('status', isEqualTo: TaskStatus.toCode(status!));
    }
    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map(
                (doc) => _docMap(
                  doc,
                  projectId: doc.reference.parent.parent?.id ?? '',
                ),
              )
              .toList()
            ..sort(_compareByDueDate),
    );
  }

  Future<List<Map<String, dynamic>>> list({
    required String projectId,
    String? assigneeId,
    String? status,
  }) async {
    final code = status == null ? null : TaskStatus.toCode(status);
    final snapshot = await _guard(() => _tasksOf(projectId).get());
    return snapshot.docs
        .map((doc) => _docMap(doc, projectId: projectId))
        .where((task) => _matches(task, code: code, assigneeId: assigneeId))
        .toList()
      ..sort(_compareByDueDate);
  }

  static int _compareByDueDate(Map<String, dynamic> a, Map<String, dynamic> b) {
    final left = _dueDate(a['dueDate']);
    final right = _dueDate(b['dueDate']);
    if (left == null) return right == null ? 0 : 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }

  /// Đổi ngày (Timestamp/DateTime) sang chuỗi ISO để gửi qua JSON.
  static void _normalizeDates(Map<String, dynamic> data) {
    for (final key in ['startDate', 'dueDate']) {
      final value = data[key];
      if (value is Timestamp) data[key] = value.toDate().toIso8601String();
      if (value is DateTime) data[key] = value.toIso8601String();
    }
  }

  static DateTime? _dueDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  Future<Map<String, dynamic>> create(
    String projectId,
    Map<String, dynamic> task,
  ) async {
    final uid = _requireUid();
    final role = await _guard(() => _roleOf(projectId, uid));
    if (role != 'leader') {
      throw const ServiceException('Chỉ leader mới được tạo công việc.');
    }
    final title = (task['title'] ?? '').toString().trim();
    if (title.isEmpty) {
      throw const ServiceException('Tên công việc không được để trống.');
    }
    final data = Map<String, dynamic>.from(task)..remove('id');
    final singleAssignee = data.remove('assigneeId');
    final assignedIds = <String>{
      ...(data['assigneeIds'] as List? ?? const []).map((e) => e.toString()),
      if (singleAssignee != null && singleAssignee.toString().isNotEmpty)
        singleAssignee.toString(),
    }.toList();
    if (assignedIds.isEmpty) {
      throw const ServiceException(
        'Vui lòng chọn ít nhất một người thực hiện.',
      );
    }
    data['assigneeIds'] = assignedIds;
    data['title'] = title;
    data['status'] = TaskStatus.toCode(
      (data['status'] ?? TaskStatus.todo).toString(),
    );
    final members = await Future.wait(
      assignedIds.map((id) => _memberDoc(projectId, id).get()),
    );
    if (members.any((m) => !m.exists)) {
      throw const ServiceException('Người được giao phải là thành viên dự án.');
    }
    if (data['status'] != TaskStatus.todo) {
      throw const ServiceException(
        'Công việc mới luôn bắt đầu ở trạng thái Cần làm.',
      );
    }
    _normalizeDates(data);
    final response = await _guard(
      () => _api.post('/projects/$projectId/tasks', body: data),
    );
    final created = response['task'];
    if (created is! Map) throw const ServiceException('Máy chủ không trả dữ liệu công việc.');
    return Map<String, dynamic>.from(created);
  }

  Future<Map<String, dynamic>> update(
    String projectId,
    String taskId,
    Map<String, dynamic> changes,
  ) async {
    final uid = _requireUid();
    final ref = _taskDoc(projectId, taskId);
    final snapshot = await _guard(ref.get);
    final old = snapshot.data();
    if (old == null) throw const ServiceException('Không tìm thấy công việc.');
    final role = await _guard(() => _roleOf(projectId, uid));
    if (role == null) {
      throw const ServiceException('Bạn không phải thành viên dự án.');
    }
    final isLeader = role == 'leader';
    final assignees = _assignees(old);
    final data = Map<String, dynamic>.from(changes)..remove('id');

    final nextStatus = data['status'] is String
        ? TaskStatus.toCode(data['status'] as String)
        : null;
    final oldStatus = TaskStatus.toCode('${old['status'] ?? TaskStatus.todo}');

    if (isLeader) {
      if (data['assigneeIds'] is List) {
        final ids = (data['assigneeIds'] as List)
            .map((e) => e.toString())
            .toList();
        if (ids.isEmpty) {
          throw const ServiceException(
            'Công việc cần có ít nhất một người thực hiện.',
          );
        }
        final members = await Future.wait(
          ids.map((id) => _memberDoc(projectId, id).get()),
        );
        if (members.any((m) => !m.exists)) {
          throw const ServiceException(
            'Người được giao phải là thành viên dự án.',
          );
        }
      }
      if (nextStatus != null && nextStatus != oldStatus) {
        final reviewStep =
            nextStatus == TaskStatus.completed ||
            nextStatus == TaskStatus.revisionRequired;
        final leaderOwnTask = assignees.contains(uid);
        final selfStart =
            nextStatus == TaskStatus.inProgress &&
            (oldStatus == TaskStatus.todo ||
                oldStatus == TaskStatus.revisionRequired);
        if (!reviewStep && !selfStart && !leaderOwnTask) {
          throw const ServiceException(
            'Bạn không được chuyển trạng thái công việc này.',
          );
        }
        if (reviewStep &&
            oldStatus != TaskStatus.pendingReview &&
            !(leaderOwnTask && nextStatus == TaskStatus.completed)) {
          throw const ServiceException(
            'Chỉ được duyệt công việc đang chờ duyệt.',
          );
        }
      }
    } else {
      if (!assignees.contains(uid)) {
        throw const ServiceException('Bạn không được giao công việc này.');
      }
      const allowed = {'status', 'outputLink', 'reviewComment', 'updatedAt'};
      if (data.keys.any((key) => !allowed.contains(key))) {
        throw const ServiceException(
          'Member không được sửa thông tin phân công.',
        );
      }
      if (nextStatus != null &&
          !(_memberTransitions[oldStatus]?.contains(nextStatus) ?? false)) {
        throw const ServiceException('Trạng thái công việc không hợp lệ.');
      }
    }

    if (nextStatus != null) data['status'] = nextStatus;
    // Các mốc thời gian do backend ghi, client không gửi lên.
    data
      ..remove('updatedAt')
      ..remove('completedAt');
    _normalizeDates(data);
    await _guard(
      () => _api.patch('/projects/$projectId/tasks/$taskId', body: data),
    );
    return {...old, ...data, 'id': taskId, 'projectId': projectId};
  }

  Future<Map<String, dynamic>> transition(
    String projectId,
    String taskId,
    String status, {
    String? comment,
    String? outputLink,
  }) {
    final changes = <String, dynamic>{'status': TaskStatus.toCode(status)};
    if (comment != null) changes['reviewComment'] = comment;
    if (outputLink != null) changes['outputLink'] = outputLink;
    return _guard(() => update(projectId, taskId, changes));
  }

  Future<void> delete(String projectId, String taskId) async {
    _requireUid();
    await _guard(() => _api.delete('/projects/$projectId/tasks/$taskId'));
  }

  Future<void> _requireLeader(String projectId, String message) async {
    final uid = _requireUid();
    if (await _roleOf(projectId, uid) != 'leader') {
      throw ServiceException(message);
    }
  }
}

class ChatService extends _FirestoreService {
  ChatService({super.firestore, super.auth});

  CollectionReference<Map<String, dynamic>> _messagesOf(String projectId) =>
      _projects.doc(projectId).collection('messages');

  /// Tin nhắn của một dự án, cập nhật realtime, tối đa 200 tin gần nhất.
  Stream<List<Map<String, dynamic>>> watch(String projectId) =>
      _messagesOf(projectId).snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => _docMap(doc)).toList()
          ..sort(
            (a, b) => _stamp(a['createdAt']).compareTo(_stamp(b['createdAt'])),
          ),
      );

  Future<void> send(String projectId, String content) async {
    final uid = _requireUid();
    final text = content.trim();
    if (text.isEmpty) {
      throw const ServiceException('Tin nhắn không được để trống.');
    }
    if (text.length > 2000) {
      throw const ServiceException('Tin nhắn tối đa 2000 ký tự.');
    }
    if (await _guard(() => _roleOf(projectId, uid)) == null) {
      throw const ServiceException('Bạn không phải thành viên dự án này.');
    }
    final profile = await _guard(() => _users.doc(uid).get());
    final name =
        (profile.data()?['displayName'] ??
                profile.data()?['username'] ??
                'Thành viên')
            .toString();
    await _guard(
      () => _messagesOf(projectId).add({
        'senderId': uid,
        'senderName': name,
        'content': text,
        'kind': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }
}

class NotificationService extends _FirestoreService {
  NotificationService({super.firestore, super.auth});

  CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _users.doc(uid).collection('notifications');

  /// Thông báo của người đang đăng nhập, cập nhật realtime.
  /// Nội dung do Cloud Function viết khi dự án/task/thành viên thay đổi.
  Stream<List<Map<String, dynamic>>> watchMine() {
    final uid = _requireUid();
    return _inbox(uid).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => _docMap(doc)).toList()
        ..sort(
          (a, b) => _stamp(b['createdAt']).compareTo(_stamp(a['createdAt'])),
        ),
    );
  }

  Future<void> markRead(String notificationId) async {
    final uid = _requireUid();
    await _guard(() => _inbox(uid).doc(notificationId).update({'read': true}));
  }

  Future<void> markAllRead() async {
    final uid = _requireUid();
    final unread = await _guard(
      () => _inbox(uid).where('read', isEqualTo: false).get(),
    );
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await _guard(batch.commit);
  }
}

/// Workspace của dự án: tài liệu, lịch họp và bình chọn, tất cả lưu ở Firestore.
class WorkspaceService extends _FirestoreService {
  WorkspaceService({super.firestore, super.auth});

  CollectionReference<Map<String, dynamic>> _rows(
    String projectId,
    String collection,
  ) => _projects.doc(projectId).collection(collection);

  Stream<List<Map<String, dynamic>>> watchDocuments(String projectId) =>
      _rows(projectId, 'documents').snapshots().map(_sortedByCreated);

  Stream<List<Map<String, dynamic>>> watchMeetings(String projectId) =>
      _rows(projectId, 'meetings').snapshots().map(_sortedByCreated);

  Stream<List<Map<String, dynamic>>> watchVotes(String projectId) =>
      _rows(projectId, 'votes').snapshots().asyncMap((snapshot) async {
        final uid = _requireUid();
        final rows = await Future.wait(
          snapshot.docs.map((doc) async {
            final ballots = await _rows(
              projectId,
              'votes',
            ).doc(doc.id).collection('ballots').get();
            final counts = List<int>.filled(
              ((doc.data()['options'] as List?) ?? const []).length,
              0,
            );
            for (final ballot in ballots.docs) {
              final index = ballot.data()['option'];
              if (index is int && index >= 0 && index < counts.length) {
                counts[index]++;
              }
            }
            return {
              ..._docMap(doc),
              'counts': counts,
              'totalVotes': ballots.docs.length,
              'myVote': ballots.docs
                  .where((b) => b.id == uid)
                  .map((b) => b.data()['option'])
                  .firstOrNull,
            };
          }),
        );
        return rows..sort(
          (a, b) => _stamp(b['createdAt']).compareTo(_stamp(a['createdAt'])),
        );
      });

  static List<Map<String, dynamic>> _sortedByCreated(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => snapshot.docs.map((doc) => _docMap(doc)).toList()
    ..sort((a, b) => _stamp(b['createdAt']).compareTo(_stamp(a['createdAt'])));

  Future<void> addDocument(String projectId, String label, {String url = ''}) =>
      _add(projectId, 'documents', label, extra: {'url': _validatedUrl(url)});

  Future<void> addMeeting(String projectId, String label) =>
      _add(projectId, 'meetings', label);

  Future<void> addVote(
    String projectId,
    String question,
    List<String> options,
  ) async {
    _requireUid();
    final choices = options
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    if (question.trim().isEmpty) {
      throw const ServiceException('Câu hỏi bình chọn không được để trống.');
    }
    if (choices.length < 2) {
      throw const ServiceException('Bình chọn cần ít nhất hai phương án.');
    }
    await _guard(
      () => _rows(projectId, 'votes').add({
        'question': question.trim(),
        'options': choices,
        'createdBy': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> removeRow(String projectId, String collection, String id) async {
    final uid = _requireUid();
    final role = await _guard(() => _roleOf(projectId, uid));
    if (role == null) {
      throw const ServiceException('Bạn không phải thành viên dự án này.');
    }
    final doc = await _guard(() => _rows(projectId, collection).doc(id).get());
    if (!doc.exists) return;
    if (doc.data()?['createdBy'] != uid && role != 'leader') {
      throw const ServiceException('Bạn chỉ xóa được mục do chính mình tạo.');
    }
    await _guard(() => _rows(projectId, collection).doc(id).delete());
  }

  /// Mỗi người chỉ bầu một lần cho một bình chọn.
  Future<void> vote(String projectId, String voteId, int option) async {
    final uid = _requireUid();
    if (await _guard(() => _roleOf(projectId, uid)) == null) {
      throw const ServiceException('Bạn không phải thành viên dự án này.');
    }
    final vote = await _guard(
      () => _rows(projectId, 'votes').doc(voteId).get(),
    );
    final options = (vote.data()?['options'] as List?) ?? const [];
    if (!vote.exists) throw const ServiceException('Không tìm thấy bình chọn.');
    if (option < 0 || option >= options.length) {
      throw const ServiceException('Phương án bình chọn không hợp lệ.');
    }
    await _guard(
      () => _rows(projectId, 'votes')
          .doc(voteId)
          .collection('ballots')
          .doc(uid)
          .set({'option': option, 'createdAt': FieldValue.serverTimestamp()}),
    );
  }

  Future<void> _add(
    String projectId,
    String collection,
    String label, {
    Map<String, dynamic> extra = const {},
  }) async {
    final uid = _requireUid();
    final text = label.trim();
    if (text.isEmpty) throw const ServiceException('Tên không được để trống.');
    if (await _guard(() => _roleOf(projectId, uid)) == null) {
      throw const ServiceException('Bạn không phải thành viên dự án này.');
    }
    await _guard(
      () => _rows(projectId, collection).add({
        'label': text,
        ...extra,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  static String _validatedUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      throw const ServiceException(
        'Đường dẫn cần bắt đầu bằng http:// hoặc https://',
      );
    }
    return text;
  }
}
