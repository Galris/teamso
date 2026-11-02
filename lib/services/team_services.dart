import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'service_errors.dart';
import 'api_client.dart' hide errorText;

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
  _FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ApiClient? api,
  }) : _db = firestore ?? FirebaseFirestore.instance,
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
  /// Dự án cũ chưa có `members/{uid}` thì suy ra từ `ownerId` / `memberIds`.
  Future<String?> _roleOf(String projectId, String uid) async {
    final snapshot = await _memberDoc(projectId, uid).get();
    if (snapshot.exists) {
      return (snapshot.data()?['role'] ?? 'member').toString();
    }
    final project = await _projects.doc(projectId).get();
    return _roleFromProject(project.data(), uid);
  }
}

/// Vai trò suy ra trực tiếp từ document project (dữ liệu tạo thủ công/cũ):
/// chủ dự án là leader, người có trong `memberIds` là member.
String? _roleFromProject(Map<String, dynamic>? data, String uid) {
  if (data == null || uid.isEmpty) return null;
  if (data['ownerId']?.toString() == uid) return 'leader';
  final ids = data['memberIds'];
  if (ids is List && ids.map((e) => e.toString()).contains(uid)) {
    return 'member';
  }
  return null;
}

class ProjectService extends _FirestoreService {
  ProjectService({super.firestore, super.auth, super.api});

  CollectionReference<Map<String, dynamic>> _userIndex(String uid) =>
      _users.doc(uid).collection('projectMemberships');

  /// Danh sách project của người đang đăng nhập, cập nhật realtime.
  /// Nguồn 1: chỉ mục `users/{uid}/projectMemberships` (dự án tạo qua backend).
  /// Nguồn 2: truy vấn trực tiếp `memberIds` / `ownerId` (dự án tạo thủ công
  /// trên Firebase chưa có chỉ mục). Mỗi bản ghi kèm `myRole`.
  Stream<List<Map<String, dynamic>>> watchMine() {
    final uid = _requireUid();
    late final StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? indexSubscription;
    StreamSubscription? memberQuerySubscription;
    StreamSubscription? ownerQuerySubscription;
    final projectSubscriptions = <String, StreamSubscription>{};
    final projectCache = <String, Map<String, dynamic>>{};
    final memberDocs = <String, Map<String, dynamic>>{};
    final ownerDocs = <String, Map<String, dynamic>>{};
    final roles = <String, String>{};
    var isLive = false;

    void emit() {
      if (!isLive || controller.isClosed) return;
      final legacy = {...memberDocs, ...ownerDocs};
      final ids = {...projectCache.keys, ...legacy.keys};
      controller.add(
        ids.map((id) {
          final data = projectCache[id] ?? legacy[id]!;
          return {
            ...data,
            'myRole': roles[id] ?? _roleFromProject(data, uid) ?? 'member',
          };
        }).toList(),
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

        // Truy vấn bổ sung; nếu Security Rules từ chối thì bỏ qua, chỉ dùng chỉ mục.
        memberQuerySubscription = _projects
            .where('memberIds', arrayContains: uid)
            .snapshots()
            .listen((snap) {
              memberDocs
                ..clear()
                ..addEntries(snap.docs.map((d) => MapEntry(d.id, _docMap(d))));
              emit();
            }, onError: (_) {});
        ownerQuerySubscription = _projects
            .where('ownerId', isEqualTo: uid)
            .snapshots()
            .listen((snap) {
              ownerDocs
                ..clear()
                ..addEntries(snap.docs.map((d) => MapEntry(d.id, _docMap(d))));
              emit();
            }, onError: (_) {});
      },
      onCancel: () async {
        isLive = false;
        await indexSubscription?.cancel();
        await memberQuerySubscription?.cancel();
        await ownerQuerySubscription?.cancel();
        for (final sub in projectSubscriptions.values) {
          await sub.cancel();
        }
        projectSubscriptions.clear();
        projectCache.clear();
        memberDocs.clear();
        ownerDocs.clear();
        roles.clear();
      },
    );
    return controller.stream;
  }

  /// Hồ sơ thành viên kèm displayName/username/avatar, lấy từ backend API.
  /// Nếu backend không có dữ liệu (dự án cũ chưa có `members/{uid}`) thì dựng
  /// danh sách từ `ownerId` + `memberIds` và hồ sơ `users/{uid}`.
  Future<List<Map<String, dynamic>>> listMembers(String projectId) async {
    _requireUid();
    var rows = <Map<String, dynamic>>[];
    try {
      final response = await _api.get('/projects/$projectId/members');
      final raw = response['members'];
      if (raw is List) {
        rows = raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    } catch (_) {
      // Rơi xuống nguồn dự phòng bên dưới.
    }
    if (rows.isEmpty) {
      rows = await _guard(() => _membersFromProjectDoc(projectId));
    }
    return _uniqueByUid(rows);
  }

  /// Loại bản ghi trùng uid: danh sách trùng làm DropdownButton chọn người
  /// thực hiện ném assertion (màn hình đỏ) ngay sau khi thêm thành viên.
  static List<Map<String, dynamic>> _uniqueByUid(
    List<Map<String, dynamic>> rows,
  ) {
    final seen = <String>{};
    return rows.where((row) {
      final id = (row['uid'] ?? row['id'] ?? '').toString();
      return id.isEmpty || seen.add(id);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _membersFromProjectDoc(
    String projectId,
  ) async {
    final doc = await _projects.doc(projectId).get();
    final data = doc.data();
    if (data == null) return [];
    final ownerId = data['ownerId']?.toString() ?? '';
    final ids = <String>{
      if (ownerId.isNotEmpty) ownerId,
      if (data['memberIds'] is List)
        ...(data['memberIds'] as List).map((e) => e.toString()),
    };
    return Future.wait(
      ids.map((id) async {
        Map<String, dynamic> profile = {};
        try {
          profile = (await _users.doc(id).get()).data() ?? {};
        } catch (_) {}
        return {
          ...profile,
          'uid': id,
          'username': profile['username'] ?? '',
          'displayName':
              profile['displayName'] ?? profile['username'] ?? 'Thành viên',
          'role': id == ownerId ? 'leader' : 'member',
        };
      }),
    );
  }

  /// Làm mới khi `members` hoặc chính document project (memberIds) thay đổi.
  Stream<List<Map<String, dynamic>>> watchMembers(String projectId) {
    late final StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? membersSub;
    StreamSubscription? projectSub;

    Future<void> refresh() async {
      try {
        final rows = await listMembers(projectId);
        if (!controller.isClosed) controller.add(rows);
      } catch (error) {
        if (!controller.isClosed) controller.addError(error);
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        membersSub = _membersOf(projectId)
            .snapshots()
            .listen((_) => refresh(), onError: (_) {});
        projectSub = _projects
            .doc(projectId)
            .snapshots()
            .listen((_) => refresh(), onError: controller.addError);
      },
      onCancel: () async {
        await membersSub?.cancel();
        await projectSub?.cancel();
      },
    );
    return controller.stream;
  }

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
    final result = entries.whereType<Map<String, dynamic>>().toList();
    final seen = result.map((p) => p['id']).toSet();
    try {
      final legacy = await _projects
          .where('memberIds', arrayContains: uid)
          .get();
      for (final doc in legacy.docs.where((d) => !seen.contains(d.id))) {
        final data = _docMap(doc);
        result.add({
          ...data,
          'myRole': _roleFromProject(data, uid) ?? 'member',
        });
      }
    } catch (_) {}
    return result;
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
    final response = await _guard(
      () => _api.post(
        '/projects',
        body: {
          'name': name.trim(),
          'tag': tag.trim(),
          'description': description.trim(),
          'coverUrl': coverUrl,
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (endDate != null) 'endDate': endDate.toIso8601String(),
        },
      ),
    );
    final project = response['project'];
    if (project is! Map) {
      throw const ServiceException('Máy chủ không trả dữ liệu dự án.');
    }
    return Map<String, dynamic>.from(project);
  }

  /// Mã tham gia được backend kiểm tra để không lộ dự án công khai.
  Future<Map<String, dynamic>> join(String joinCode) async {
    _requireUid();
    final code = joinCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw const ServiceException('Vui lòng nhập mã tham gia.');
    }
    final response = await _guard(
      () => _api.post('/projects/join', body: {'joinCode': code}),
    );
    final projectId = response['projectId']?.toString() ?? '';
    if (projectId.isEmpty) {
      throw const ServiceException('Không thể tham gia dự án.');
    }
    return get(projectId);
  }

  Future<void> addMemberByUsername(String projectId, String username) async {
    _requireUid();
    final name = username.trim().toLowerCase();
    if (name.isEmpty) {
      throw const ServiceException('Vui lòng nhập tên đăng nhập.');
    }
    await _guard(
      () => _api.post('/projects/$projectId/members', body: {'username': name}),
    );
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
    await _guard(
      () => _api.patch(
        '/projects/$projectId',
        body: {
          for (final entry in safe.entries)
            entry.key: entry.value is DateTime
                ? (entry.value as DateTime).toIso8601String()
                : entry.value,
        },
      ),
    );
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

  late final ResourceService _resources = ResourceService(
    firestore: _db,
    auth: _auth,
  );

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
    if (created is! Map) {
      throw const ServiceException('Máy chủ không trả dữ liệu công việc.');
    }
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

    // Hoàn thành công việc có link kết quả -> cập nhật Tài nguyên của dự án.
    String? resourceError;
    final finalStatus = nextStatus ?? oldStatus;
    final link = '${data['outputLink'] ?? old['outputLink'] ?? ''}'.trim();
    if (finalStatus == TaskStatus.completed &&
        (nextStatus == TaskStatus.completed || data.containsKey('outputLink')) &&
        link.isNotEmpty) {
      try {
        await _resources.upsertFromTask(
          projectId: projectId,
          taskId: taskId,
          title: '${old['title'] ?? 'Công việc'}',
          url: link,
          uploadedBy: assignees.isNotEmpty ? assignees.first : uid,
        );
      } catch (error) {
        resourceError = errorText(error);
      }
    }

    return {
      ...old,
      ...data,
      'id': taskId,
      'projectId': projectId,
      if (resourceError != null) 'resourceError': resourceError,
    };
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
}

/// Tài nguyên của dự án: `projects/{id}/resources/{resourceId}` với các trường
/// name, type, url, uploadedBy, createdAt (+ taskId khi sinh từ công việc).
class ResourceService extends _FirestoreService {
  ResourceService({super.firestore, super.auth});

  CollectionReference<Map<String, dynamic>> _resourcesOf(String projectId) =>
      _projects.doc(projectId).collection('resources');

  /// Danh sách tài nguyên, mới nhất trước, cập nhật realtime.
  Stream<List<Map<String, dynamic>>> watch(String projectId) =>
      _resourcesOf(projectId).snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => _docMap(doc)).toList()
          ..sort(
            (a, b) => _stamp(b['createdAt']).compareTo(_stamp(a['createdAt'])),
          ),
      );

  /// Ghi (hoặc cập nhật) tài nguyên sinh từ một công việc đã hoàn thành.
  /// Document ID cố định `task_{taskId}` nên gọi lặp lại không tạo bản trùng.
  Future<void> upsertFromTask({
    required String projectId,
    required String taskId,
    required String title,
    required String url,
    String? uploadedBy,
  }) async {
    final uid = _requireUid();
    final link = url.trim();
    if (link.isEmpty) return;
    await _guard(
      () => _resourcesOf(projectId).doc('task_$taskId').set({
        'name': title.trim().isEmpty ? 'Công việc' : title.trim(),
        'type': 'link',
        'url': link,
        'uploadedBy': (uploadedBy ?? '').isEmpty ? uid : uploadedBy,
        'taskId': taskId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }
}

class ChatService extends _FirestoreService {
  ChatService({super.firestore, super.auth});

  CollectionReference<Map<String, dynamic>> _messagesOf(String projectId) =>
      _projects.doc(projectId).collection('messages');

  /// Bản xem trước chỉ đọc tin gần nhất trong dự án, không tải cả lịch sử.
  Stream<Map<String, dynamic>?> watchLatest(String projectId) =>
      _messagesOf(projectId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.isEmpty ? null : _docMap(snapshot.docs.first),
          );

  /// Tin nhắn của một dự án, cập nhật realtime, tối đa 50 tin gần nhất.
  Stream<List<Map<String, dynamic>>> watch(String projectId) =>
      _messagesOf(projectId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) => _docMap(doc)).toList()
              ..sort(
                (a, b) =>
                    _stamp(a['createdAt']).compareTo(_stamp(b['createdAt'])),
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
  /// Nội dung do backend ghi cùng sự kiện task/Workspace.
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
    for (var start = 0; start < unread.docs.length; start += 400) {
      final batch = _db.batch();
      for (final doc in unread.docs.skip(start).take(400)) {
        batch.update(doc.reference, {'read': true});
      }
      await _guard(batch.commit);
    }
  }
}

/// Workspace của dự án: tài liệu, lịch họp và bình chọn, tất cả lưu ở Firestore.
class WorkspaceService extends _FirestoreService {
  WorkspaceService({super.firestore, super.auth, super.api});

  CollectionReference<Map<String, dynamic>> _rows(
    String projectId,
    String collection,
  ) => _projects.doc(projectId).collection(collection);

  Stream<List<Map<String, dynamic>>> watchDocuments(String projectId) =>
      _rows(projectId, 'documents').snapshots().map(_sortedByCreated);

  Stream<List<Map<String, dynamic>>> watchMeetings(String projectId) =>
      _rows(projectId, 'meetings').snapshots().map(_sortedByCreated);

  Stream<List<Map<String, dynamic>>> watchVotes(String projectId) {
    final uid = _requireUid();
    final votesCollection = _rows(projectId, 'votes');

    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? votesSubscription;

    final ballotSubscriptions = <String, StreamSubscription>{};
    final voteDocuments = <String, Map<String, dynamic>>{};
    final ballotDocuments = <String, List<Map<String, dynamic>>>{};

    void emit() {
      if (controller.isClosed) return;

      final rows = <Map<String, dynamic>>[];

      for (final entry in voteDocuments.entries) {
        final voteId = entry.key;
        final vote = entry.value;
        final ballots = ballotDocuments[voteId] ?? const [];

        final options = (vote['options'] as List?) ?? const [];
        final counts = List<int>.filled(options.length, 0);

        final myVotes = <int>[];
        var totalParticipants = 0;

        for (final ballot in ballots) {
          final selected = <int>{};

          // Hỗ trợ phiếu mới: options = [0, 1, ...]
          final multiple = ballot['options'];
          if (multiple is List) {
            for (final value in multiple) {
              if (value is int && value >= 0 && value < counts.length) {
                selected.add(value);
              }
            }
          } else {
            // Hỗ trợ phiếu cũ: option = 0
            final single = ballot['option'];
            if (single is int && single >= 0 && single < counts.length) {
              selected.add(single);
            }
          }

          if (selected.isNotEmpty) {
            totalParticipants++;
          }

          for (final index in selected) {
            counts[index]++;
          }

          if (ballot['id'] == uid) {
            myVotes.addAll(selected);
          }
        }

        myVotes.sort();

        rows.add({
          ...vote,
          'counts': counts,
          'totalVotes': totalParticipants,
          'myVotes': myVotes,
        });
      }

      rows.sort(
        (a, b) => _stamp(b['createdAt']).compareTo(_stamp(a['createdAt'])),
      );

      controller.add(rows);
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        votesSubscription = votesCollection.snapshots().listen(
          (snapshot) {
            final ids = snapshot.docs
                .where((doc) => doc.data()['deleting'] != true)
                .map((doc) => doc.id)
                .toSet();

            for (final id in ballotSubscriptions.keys.toList()) {
              if (!ids.contains(id)) {
                ballotSubscriptions.remove(id)?.cancel();
                ballotDocuments.remove(id);
              }
            }

            voteDocuments.clear();

            for (final doc in snapshot.docs) {
              final voteId = doc.id;
              if (doc.data()['deleting'] == true) continue;
              voteDocuments[voteId] = _docMap(doc);

              if (ballotSubscriptions.containsKey(voteId)) {
                continue;
              }

              ballotSubscriptions[voteId] = votesCollection
                  .doc(voteId)
                  .collection('ballots')
                  .snapshots()
                  .listen(
                    (ballotsSnapshot) {
                      if (controller.isClosed ||
                          !voteDocuments.containsKey(voteId)) {
                        return;
                      }

                      ballotDocuments[voteId] = ballotsSnapshot.docs.map((
                        ballot,
                      ) {
                        return {...ballot.data(), 'id': ballot.id};
                      }).toList();

                      emit();
                    },
                    onError: (Object error, StackTrace stackTrace) {
                      if (!controller.isClosed &&
                          voteDocuments.containsKey(voteId)) {
                        controller.addError(error, stackTrace);
                      }
                    },
                  );
            }

            emit();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );
      },
      onCancel: () async {
        await votesSubscription?.cancel();

        for (final subscription in ballotSubscriptions.values) {
          await subscription.cancel();
        }

        ballotSubscriptions.clear();
        ballotDocuments.clear();
        voteDocuments.clear();
      },
    );

    return controller.stream;
  }

  static List<Map<String, dynamic>> _sortedByCreated(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => snapshot.docs.map((doc) => _docMap(doc)).toList()
    ..sort((a, b) => _stamp(b['createdAt']).compareTo(_stamp(a['createdAt'])));

  String _path(String projectId, String collection) {
    _requireUid();
    if (!{'documents', 'meetings', 'votes'}.contains(collection)) {
      throw const ServiceException('Loại dữ liệu Workspace không hợp lệ.');
    }
    return '/projects/$projectId/workspace/$collection';
  }

  Future<void> addDocument(
    String projectId,
    String label, {
    String url = '',
  }) async {
    await _guard(
      () => _api.post(
        _path(projectId, 'documents'),
        body: {'label': label.trim(), 'url': _validatedUrl(url)},
      ),
    );
  }

  Future<void> addMeeting(
    String projectId,
    String label, {
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    await _guard(
      () => _api.post(
        _path(projectId, 'meetings'),
        body: {
          'label': label.trim(),
          'startsAt': startsAt.toUtc().toIso8601String(),
          'endsAt': endsAt.toUtc().toIso8601String(),
        },
      ),
    );
  }

  Future<void> addVote(
    String projectId,
    String question,
    List<String> options,
  ) async {
    await _guard(
      () => _api.post(
        _path(projectId, 'votes'),
        body: {
          'question': question.trim(),
          'options': options.map((v) => v.trim()).toList(),
        },
      ),
    );
  }

  Future<void> removeRow(String projectId, String collection, String id) async {
    await _guard(() => _api.delete('${_path(projectId, collection)}/$id'));
  }

  Future<void> voteMultiple(
    String projectId,
    String voteId,
    List<int> selectedOptions,
  ) async {
    await _guard(
      () => _api.put(
        '${_path(projectId, 'votes')}/$voteId/ballot',
        body: {'options': selectedOptions.toSet().toList()..sort()},
      ),
    );
  }

  static String _validatedUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !['http', 'https'].contains(uri.scheme)) {
      throw const ServiceException(
        'Đường dẫn cần bắt đầu bằng http:// hoặc https://',
      );
    }
    return text;
  }
}
