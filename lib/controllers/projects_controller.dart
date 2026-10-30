import 'package:flutter/foundation.dart';

import '../core/utils/api_json.dart';
import '../services/api_client.dart';

/// Nguồn dữ liệu duy nhất cho Home và Task Board: dự án của tài khoản đang
/// đăng nhập và các công việc trong từng dự án, đều lấy từ API.
///
/// Endpoint sử dụng (cùng quy ước với ProjectDetailScreen):
///   GET   /projects                     danh sách dự án của người dùng
///   GET   /projects/:id/tasks           công việc của một dự án
///   PATCH /tasks/:id/start
///   POST  /tasks/:id/submit             {outputLink}
///   POST  /tasks/:id/approve
///   POST  /tasks/:id/request-changes    {comment}
class ProjectsController extends ChangeNotifier {
  ProjectsController(this.api, this.userId);

  final ApiClient api;
  final String userId;

  List<Map<String, dynamic>> projects = [];
  final Map<String, List<Map<String, dynamic>>> _tasks = {};
  bool loading = false;
  bool loaded = false;
  String? error;

  int _generation = 0;
  bool _disposed = false;

  Future<void> load({bool silent = false}) async {
    final generation = ++_generation;
    if (!silent || !loaded) {
      loading = true;
      error = null;
      _notify();
    }
    try {
      final response = await api.request('GET', '/projects', protected: true);
      final mine = extractList(response, const [
        'projects',
        'items',
        'results',
      ]).where(_isMine).toList();

      final entries = await Future.wait(
        mine.map((project) async {
          final id = projectId(project);
          try {
            final res = await api.request(
              'GET',
              '/projects/${Uri.encodeComponent(id)}/tasks',
              protected: true,
            );
            final list = extractList(res, const ['tasks', 'items', 'results'])
                .map((t) => {...t, 'projectId': id})
                .toList();
            return MapEntry(id, list);
          } on ApiException catch (e) {
            // Phiên hết hạn đã được ApiClient xử lý; các lỗi khác chỉ làm
            // dự án này tạm thời không có công việc.
            if (e.status == 401) rethrow;
            return MapEntry(id, <Map<String, dynamic>>[]);
          }
        }),
      );
      if (generation != _generation) return;
      projects = mine;
      _tasks
        ..clear()
        ..addEntries(entries);
      error = null;
    } catch (e) {
      if (generation != _generation) return;
      error = e.toString();
    } finally {
      if (generation == _generation) {
        loading = false;
        loaded = true;
        _notify();
      }
    }
  }

  // ---- Đọc dữ liệu -------------------------------------------------------

  String projectId(Map<String, dynamic> p) =>
      stringValue(p, const ['id', '_id', 'projectId', 'project_id']);

  Map<String, dynamic>? projectById(String id) {
    for (final p in projects) {
      if (projectId(p) == id) return p;
    }
    return null;
  }

  List<Map<String, dynamic>> tasksForProject(String id) =>
      _tasks[id] ?? const [];

  List<Map<String, dynamic>> get allTasks => [
    for (final list in _tasks.values) ...list,
  ];

  String taskId(Map<String, dynamic> t) =>
      stringValue(t, const ['id', '_id', 'taskId', 'task_id']);

  String taskStatus(Map<String, dynamic> t) => normalizeStatus(
    stringValue(t, const ['status', 'taskStatus', 'task_status']),
  );

  String assigneeId(Map<String, dynamic> t) {
    final raw = firstValue(t, const [
      'assigneeId',
      'assignee_id',
      'assignedTo',
      'assignee',
      'userId',
      'user_id',
    ]);
    final map = asMap(raw);
    return map == null
        ? raw?.toString() ?? ''
        : stringValue(map, const ['id', '_id', 'userId']);
  }

  List<Map<String, dynamic>> tasksForCurrentUser() =>
      allTasks.where((t) => assigneeId(t) == userId).toList();

  List<Map<String, dynamic>> tasksToReview() => allTasks
      .where(
        (t) =>
            roleInProject(t['projectId'].toString()) == 'Leader' &&
            taskStatus(t) == 'Chờ duyệt',
      )
      .toList();

  int progressOf(String id) {
    final list = tasksForProject(id);
    if (list.isEmpty) return 0;
    final done = list.where((t) => taskStatus(t) == 'Hoàn thành').length;
    return ((done / list.length) * 100).round();
  }

  List<Map<String, dynamic>> _membersOf(Map<String, dynamic> p) =>
      asMapList(firstValue(p, const ['members', 'projectMembers']));

  int memberCount(Map<String, dynamic> p) {
    final raw = firstValue(p, const ['members', 'projectMembers']);
    if (raw is List) return raw.length;
    final n = firstValue(p, const ['memberCount', 'membersCount']);
    return n is num ? n.toInt() : int.tryParse('$n') ?? 0;
  }

  String roleInProject(String id) {
    final p = projectById(id);
    if (p == null) return 'Member';
    final role = stringValue(p, const ['myRole', 'role', 'currentUserRole']);
    if (role.isNotEmpty) {
      return const ['leader', 'owner', 'admin'].contains(role.toLowerCase())
          ? 'Leader'
          : 'Member';
    }
    final leader = stringValue(p, const ['leaderId', 'leader_id', 'ownerId']);
    return leader == userId ? 'Leader' : 'Member';
  }

  String assigneeName(Map<String, dynamic> task) {
    final direct = stringValue(task, const ['assigneeName', 'assignee_name']);
    if (direct.isNotEmpty) return direct;
    final embedded = asMap(task['assignee']);
    if (embedded != null) {
      final name = stringValue(embedded, const [
        'displayName',
        'name',
        'fullName',
        'username',
      ]);
      if (name.isNotEmpty) return name;
    }
    final id = assigneeId(task);
    if (id == userId) return 'Bạn';
    final project = projectById(task['projectId'].toString());
    for (final m in project == null ? const <Map<String, dynamic>>[] : _membersOf(project)) {
      if (stringValue(m, const ['id', '_id', 'userId', 'user_id']) == id) {
        return stringValue(m, const [
          'displayName',
          'name',
          'fullName',
          'username',
        ], fallback: 'Thành viên');
      }
    }
    return 'Thành viên';
  }

  /// Chỉ giữ dự án mà tài khoản là thành viên (phòng khi API trả rộng hơn).
  bool _isMine(Map<String, dynamic> p) {
    if (stringValue(p, const ['myRole', 'role', 'currentUserRole']).isNotEmpty) {
      return true;
    }
    if (stringValue(p, const ['leaderId', 'leader_id', 'ownerId']) == userId) {
      return true;
    }
    final raw = firstValue(p, const ['members', 'projectMembers']);
    if (raw is! List || raw.isEmpty) return true;
    return raw.any((m) {
      final map = asMap(m);
      final id = map == null
          ? m.toString()
          : stringValue(map, const ['id', '_id', 'userId', 'user_id']);
      return id == userId;
    });
  }

  // ---- Thao tác công việc ------------------------------------------------

  Future<void> startTask(Map<String, dynamic> task) => _act(
    () => api.request(
      'PATCH',
      _taskPath(task, 'start'),
      body: const {},
      protected: true,
    ),
  );

  Future<void> submitTask(Map<String, dynamic> task, String outputLink) => _act(
    () => api.request(
      'POST',
      _taskPath(task, 'submit'),
      body: {'outputLink': outputLink},
      protected: true,
    ),
  );

  Future<void> approveTask(Map<String, dynamic> task) => _act(
    () => api.request(
      'POST',
      _taskPath(task, 'approve'),
      body: const {},
      protected: true,
    ),
  );

  Future<void> requestChanges(Map<String, dynamic> task, String comment) =>
      _act(
        () => api.request(
          'POST',
          _taskPath(task, 'request-changes'),
          body: {'comment': comment},
          protected: true,
        ),
      );

  String _taskPath(Map<String, dynamic> task, String action) {
    final id = taskId(task);
    if (id.isEmpty) throw const ApiException('Công việc không có ID hợp lệ.');
    return '/tasks/${Uri.encodeComponent(id)}/$action';
  }

  Future<void> _act(Future<Map<String, dynamic>> Function() action) async {
    await action();
    await load(silent: true);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
