import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/app_services.dart';
import '../../services/service_errors.dart';
import '../../services/team_services.dart';

/// Bộ nhớ tạm thời của toàn app: gom project/member/task từ Firestore về một
/// chỗ để mọi màn hình cùng đọc, tránh mỗi nơi tạo Service và listener riêng.
class TaskStore extends ChangeNotifier {
  TaskStore._();
  static final TaskStore instance = TaskStore._();

  final ProjectService _projectsService = AppServices.instance.projects;
  final TaskService _tasksService = AppServices.instance.tasks;

  final List<Map<String, dynamic>> projects = [];
  final List<Map<String, dynamic>> members = [];
  final List<Map<String, dynamic>> tasks = [];

  StreamSubscription? _projectsSub;
  final Map<String, StreamSubscription> _memberSubs = {};
  final Map<String, StreamSubscription> _taskSubs = {};

  /// Lỗi mới nhất từ một stream Firestore; null khi mọi thứ bình thường.
  String? lastError;
  bool projectsLoading = true;
  String? projectsError;

  String get currentUserId => AppServices.instance.auth.currentUser?.uid ?? '';

  void start() {
    if (currentUserId.isEmpty || _projectsSub != null) return;
    projectsLoading = true;
    projectsError = null;
    _projectsSub = _projectsService.watchMine().listen(
      _onProjects,
      onError: (Object error) {
        projectsLoading = false;
        projectsError = errorText(error);
        _onStreamError(error);
      },
    );
  }

  void _onProjects(List<Map<String, dynamic>> items) {
    projectsLoading = false;
    projectsError = null;
    lastError = null;
    final ids = items.map((p) => p['id'].toString()).toSet();
    projects
      ..clear()
      ..addAll(
        items.map(
          (p) => {
            ...p,
            'leaderId': p['ownerId'],
            'members': members
                .where((m) => m['projectId'] == p['id'])
                .map((m) => m['uid'].toString())
                .toList(),
          },
        ),
      );
    notifyListeners();

    for (final id
        in _memberSubs.keys.where((id) => !ids.contains(id)).toList()) {
      _memberSubs.remove(id)?.cancel();
      _taskSubs.remove(id)?.cancel();
      tasks.removeWhere((t) => t['projectId'] == id);
      members.removeWhere((m) => m['projectId'] == id);
    }

    for (final id in ids) {
      _memberSubs.putIfAbsent(
        id,
        () => _projectsService
            .watchMembers(id)
            .listen((rows) => _onMembers(id, rows), onError: _onStreamError),
      );
      _taskSubs.putIfAbsent(
        id,
        () => _tasksService
            .watch(projectId: id)
            .listen((rows) => _onTasks(id, rows), onError: _onStreamError),
      );
    }
  }

  void _onMembers(String projectId, List<Map<String, dynamic>> rows) {
    members.removeWhere((m) => m['projectId'] == projectId);
    members.addAll(
      rows.map((m) {
        final name = (m['displayName'] ?? m['username'] ?? 'Thành viên')
            .toString();
        return {
          ...m,
          'id': m['uid'],
          'name': name,
          'initials': _initialsOf(name),
          'projectId': projectId,
        };
      }),
    );
    final project = projectById(projectId);
    if (project != null) {
      project['members'] = rows.map((m) => m['uid'].toString()).toList();
    }
    notifyListeners();
  }

  void _onTasks(String projectId, List<Map<String, dynamic>> rows) {
    tasks.removeWhere((t) => t['projectId'] == projectId);
    tasks.addAll(
      rows.map(
        (t) => {
          ...t,
          'projectId': projectId,
          'assigneeId':
              (t['assigneeIds'] is List &&
                  (t['assigneeIds'] as List).isNotEmpty)
              ? (t['assigneeIds'] as List).first
              : '',
          'status': _localizedStatus(t['status']?.toString() ?? 'todo'),
          'priority': _localizedPriority(t['priority']?.toString() ?? ''),
          'dueDate': _dateString(t['dueDate']),
        },
      ),
    );
    notifyListeners();
  }

  void _onStreamError(Object error) {
    lastError = errorText(error);
    notifyListeners();
  }

  static String _initialsOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  String _localizedPriority(String value) => switch (value.toLowerCase()) {
    'high' => 'Cao',
    'medium' => 'Trung bình',
    'low' => 'Thấp',
    _ => value,
  };
  String _localizedStatus(String value) => switch (value) {
    'todo' => 'Cần làm',
    'in_progress' => 'Đang làm',
    'pending_review' => 'Chờ duyệt',
    'completed' => 'Hoàn thành',
    'revision_required' => 'Cần sửa',
    _ => value,
  };
  String? _dateString(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    return value?.toString();
  }

  Future<void> stop() async {
    await _projectsSub?.cancel();
    _projectsSub = null;
    for (final sub in _memberSubs.values) {
      await sub.cancel();
    }
    for (final sub in _taskSubs.values) {
      await sub.cancel();
    }
    _memberSubs.clear();
    _taskSubs.clear();
    projectsLoading = true;
    projectsError = null;
    projects.clear();
    members.clear();
    tasks.clear();
    lastError = null;
    notifyListeners();
  }

  // =========================================================
  // 4. TRA CỨU THÔNG TIN
  // =========================================================

  Map<String, dynamic>? projectById(String projectId) {
    for (final project in projects) {
      if (project['id'] == projectId) return project;
    }
    return null;
  }

  Map<String, dynamic>? memberById(String memberId) {
    for (final member in members) {
      if (member['id'] == memberId) return member;
    }
    return null;
  }

  String memberName(String memberId) {
    return memberById(memberId)?['name']?.toString() ?? 'Thành viên';
  }

  String memberInitials(String memberId) {
    return memberById(memberId)?['initials']?.toString() ?? '?';
  }

  String roleInProject(String projectId) {
    final project = projectById(projectId);

    if (project == null) return 'Member';

    if ((project['myRole'] ?? '').toString().toLowerCase() == 'leader' ||
        project['leaderId'] == currentUserId) {
      return 'Leader';
    }

    final projectMembers = (project['members'] as List<dynamic>? ?? [])
        .map((id) => id.toString())
        .toList();

    return projectMembers.contains(currentUserId) ? 'Member' : 'Không có quyền';
  }

  bool isMemberOfProject(String projectId, String memberId) {
    final project = projectById(projectId);
    if (project == null) return false;

    final projectMembers = (project['members'] as List<dynamic>? ?? [])
        .map((id) => id.toString())
        .toList();

    return projectMembers.contains(memberId);
  }

  List<Map<String, dynamic>> projectsForCurrentUser() =>
      List.unmodifiable(projects);

  List<Map<String, dynamic>> tasksForProject(String projectId) {
    return tasks.where((task) {
      return task['projectId'] == projectId;
    }).toList();
  }

  List<Map<String, dynamic>> tasksForCurrentUser() {
    return tasks.where((task) {
      final ids = task['assigneeIds'];
      return task['assigneeId'] == currentUserId ||
          (ids is List && ids.contains(currentUserId));
    }).toList();
  }

  List<Map<String, dynamic>> tasksToReview() {
    return tasks.where((task) {
      final projectId = task['projectId'].toString();

      return roleInProject(projectId) == 'Leader' &&
          task['status'] == 'Chờ duyệt';
    }).toList();
  }

  int countTasks({String? status, String? projectId, String? assigneeId}) {
    return tasks.where((task) {
      if (status != null && task['status'] != status) {
        return false;
      }

      if (projectId != null && task['projectId'] != projectId) {
        return false;
      }

      if (assigneeId != null && task['assigneeId'] != assigneeId) {
        return false;
      }

      return true;
    }).length;
  }

  // =========================================================
  // 5. PHÂN QUYỀN
  // =========================================================

  bool canCreateTask(String projectId) {
    return roleInProject(projectId) == 'Leader';
  }

  bool canReviewTask(String taskId) {
    final task = _taskById(taskId);
    if (task == null) return false;

    return roleInProject(task['projectId'].toString()) == 'Leader' &&
        task['status'] == 'Chờ duyệt';
  }

  bool canEditTask(String taskId) {
    final task = _taskById(taskId);
    if (task == null) return false;

    final assigned = task['assigneeIds'];
    if (task['assigneeId'] != currentUserId &&
        !(assigned is List && assigned.contains(currentUserId))) {
      return false;
    }

    return task['status'] == 'Cần làm' ||
        task['status'] == 'Đang làm' ||
        task['status'] == 'Cần sửa';
  }

  // =========================================================
  // 7. BẮT ĐẦU CÔNG VIỆC
  // =========================================================

  Future<void> startTask(String taskId) async {
    final task = _taskById(taskId);
    if (task == null) throw const ServiceException('Không tìm thấy công việc.');
    await _tasksService.transition(
      task['projectId'].toString(),
      taskId,
      TaskStatus.inProgress,
    );
  }

  // =========================================================
  // 8. GỬI KẾT QUẢ
  // =========================================================

  Future<void> submitTask(String taskId, {String outputLink = ''}) async {
    final task = _taskById(taskId);
    if (task == null) throw const ServiceException('Không tìm thấy công việc.');
    final link = outputLink.trim();
    final outputType = task['outputType']?.toString() ?? 'none';
    if (outputType != 'none' &&
        task['outputRequired'] == true &&
        link.isEmpty) {
      throw const ServiceException(
        'Công việc này yêu cầu cung cấp kết quả đầu ra.',
      );
    }
    await _tasksService.transition(
      task['projectId'].toString(),
      taskId,
      roleInProject(task['projectId'].toString()) == 'Leader'
          ? TaskStatus.completed
          : TaskStatus.pendingReview,
      outputLink: link.isEmpty ? null : link,
    );
  }

  // =========================================================
  // 9. LEADER DUYỆT CÔNG VIỆC
  // =========================================================

  Future<void> approveTask(String taskId, {String comment = ''}) async {
    final task = _taskById(taskId);
    if (task == null) throw const ServiceException('Không tìm thấy công việc.');
    final note = comment.trim();
    await _tasksService.transition(
      task['projectId'].toString(),
      taskId,
      TaskStatus.completed,
      comment: note.isEmpty ? null : note,
    );
  }

  // =========================================================
  // 10. LEADER YÊU CẦU CHỈNH SỬA
  // =========================================================

  Future<void> requestTaskChanges(String taskId, {String comment = ''}) async {
    final task = _taskById(taskId);
    if (task == null) throw const ServiceException('Không tìm thấy công việc.');
    await _tasksService.transition(
      task['projectId'].toString(),
      taskId,
      TaskStatus.revisionRequired,
      comment: comment.trim().isEmpty ? null : comment.trim(),
    );
  }

  // =========================================================
  // 11. TÌM CÔNG VIỆC THEO ID
  // =========================================================

  Map<String, dynamic>? _taskById(String taskId) {
    for (final task in tasks) {
      if (task['id'] == taskId) return task;
    }

    return null;
  }
}
