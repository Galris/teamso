import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/app_services.dart';
import '../../services/service_errors.dart';
import '../../services/team_services.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

const Color teamUpGreen = Color(0xFF439751);
const Color teamUpPurple = Color(0xFF867CB3);
const Color teamUpPink = Color(0xFFF472B6);
const Color teamUpYellow = Color(0xFFFACC15);
const Color teamUpDarkPurple = Color(0xFF4D4379);

const Color _background = Color(0xFFF7F7FB);
const Color _textPrimary = Color(0xFF282638);
const Color _textSecondary = Color(0xFF858397);

/// Project detail screen backed by realtime Cloud Firestore streams.
class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final String? currentUserId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.currentUserId,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // Dùng chung bộ Service của toàn app thay vì tạo instance riêng ở màn hình.
  final ProjectService _projectService = AppServices.instance.projects;
  final TaskService _taskService = AppServices.instance.tasks;
  StreamSubscription? _projectSubscription;
  StreamSubscription? _taskSubscription;
  StreamSubscription? _memberSubscription;

  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _project;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _members = [];

  String get _currentUserId => _currentUserIdFromProject();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cancelSubscriptions();
    super.dispose();
  }

  void _cancelSubscriptions() {
    _projectSubscription?.cancel();
    _taskSubscription?.cancel();
    _memberSubscription?.cancel();
    _projectSubscription = null;
    _taskSubscription = null;
    _memberSubscription = null;
  }

  /// Stream realtime là nguồn dữ liệu duy nhất cho cả ba Pane (project, tasks,
  /// members), nên màn hình không gọi thêm `get`/`list` trùng logic truy vấn.
  void _listenRealtime() {
    _projectSubscription = _projectService
        .watch(widget.projectId)
        .listen(
          (project) {
            if (!mounted) return;
            if (project == null) {
              setState(() {
                _loading = false;
                _error = 'Không tìm thấy dự án.';
              });
              return;
            }
            setState(() {
              _project = project;
              _loading = false;
              _error = null;
            });
          },
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = errorText(error);
              });
            }
          },
        );
    _taskSubscription = _taskService
        .watch(projectId: widget.projectId)
        .listen(
          (rows) {
            if (!mounted) return;
            setState(() => _tasks = rows);
          },
          onError: (Object error) {
            if (mounted) setState(() => _error = errorText(error));
          },
        );
    _memberSubscription = _projectService
        .watchMembers(widget.projectId)
        .listen(
          (rows) {
            if (!mounted) return;
            setState(() => _members = rows);
          },
          onError: (Object error) {
            if (mounted) setState(() => _error = errorText(error));
          },
        );
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  dynamic _firstValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key];
      }
    }
    return null;
  }

  String _stringValue(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    final value = _firstValue(json, keys);
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    return value == null ? fallback : value.toString();
  }

  /// Kéo-làm-mới và nút thử lại: dựng lại các subscription realtime. Stream đã
  /// phát dữ liệu mới nhất nên không cần gọi `get`/`list` trùng ở đây.
  Future<void> _loadPage({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    _cancelSubscriptions();
    _listenRealtime();
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  String get _role {
    final project = _project ?? {};
    final role = _stringValue(project, const [
      'myRole',
      'role',
      'currentUserRole',
    ]);
    if (role.isNotEmpty) {
      return role.toLowerCase() == 'leader' ? 'Leader' : 'Member';
    }
    final leaderId = _stringValue(project, const [
      'leaderId',
      'leader_id',
      'ownerId',
    ]);
    if (leaderId.isNotEmpty && leaderId == _currentUserId) {
      return 'Leader';
    }
    return 'Member';
  }

  bool get _isLeader => _role.toLowerCase() == 'leader';

  String _taskId(Map<String, dynamic> task) =>
      _stringValue(task, const ['id', '_id', 'taskId', 'task_id']);

  String _status(Map<String, dynamic> task) => _normalizeStatus(
    _stringValue(task, const [
      'status',
      'taskStatus',
      'task_status',
    ], fallback: 'Cần làm'),
  );

  String _normalizeStatus(String value) {
    switch (value
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim()) {
      case 'todo':
      case 'to do':
      case 'pending':
      case 'cần làm':
        return 'Cần làm';
      case 'in progress':
      case 'doing':
      case 'đang làm':
        return 'Đang làm';
      case 'submitted':
      case 'waiting review':
      case 'pending review':
      case 'chờ duyệt':
        return 'Chờ duyệt';
      case 'revision':
      case 'needs changes':
      case 'cần sửa':
        return 'Cần sửa';
      case 'done':
      case 'completed':
      case 'hoàn thành':
        return 'Hoàn thành';
      default:
        return value.isEmpty ? 'Cần làm' : value;
    }
  }

  String _assigneeId(Map<String, dynamic> task) {
    final ids = task['assigneeIds'];
    if (ids is List && ids.isNotEmpty) return ids.first.toString();
    return _stringValue(task, const [
      'assigneeId',
      'assignee_id',
      'assignedTo',
      'userId',
      'user_id',
    ]);
  }

  String _currentUserIdFromProject() {
    final supplied = widget.currentUserId?.trim() ?? '';
    if (supplied.isNotEmpty) {
      return supplied;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  String _memberName(dynamic memberOrId) {
    if (memberOrId is Map) {
      final member = _asMap(memberOrId) ?? {};
      return _stringValue(member, const [
        'name',
        'displayName',
        'fullName',
        'full_name',
        'username',
        'email',
      ], fallback: 'Thành viên');
    }
    final id = memberOrId?.toString() ?? '';
    final found = _members.where(
      (m) =>
          _stringValue(m, const ['uid', 'id', '_id', 'userId', 'user_id']) ==
          id,
    );
    if (found.isNotEmpty) {
      return _memberName(found.first);
    }
    return id.isEmpty ? 'Chưa phân công' : 'Thành viên $id';
  }

  String _leaderId() => _stringValue(_project ?? {}, const [
    'leaderId',
    'leader_id',
    'ownerId',
    'owner_id',
  ]);

  bool _isMyTask(Map<String, dynamic> task) {
    final userId = _currentUserIdFromProject();
    final ids = task['assigneeIds'];
    return userId.isNotEmpty &&
        (ids is List ? ids.contains(userId) : _assigneeId(task) == userId);
  }

  int _countStatus(String status) =>
      _tasks.where((task) => _status(task) == status).length;

  Color _statusColor(String status) {
    switch (status) {
      case 'Hoàn thành':
        return teamUpGreen;
      case 'Đang làm':
        return const Color(0xFF4285F4);
      case 'Chờ duyệt':
        return const Color(0xFFDB9B18);
      case 'Cần sửa':
        return teamUpPink;
      default:
        return _textSecondary;
    }
  }

  Color _projectColor(Map<String, dynamic> project) {
    final raw = _firstValue(project, const ['color', 'colorValue']);
    if (raw is int) {
      return Color(raw);
    }
    switch (_stringValue(project, const ['tag', 'category']).toLowerCase()) {
      case 'mobile':
        return teamUpGreen;
      case 'marketing':
        return teamUpPink;
      case 'research':
        return const Color(0xFFE1B32C);
      default:
        return teamUpDarkPurple;
    }
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Chưa có hạn';
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      return 'Chưa có hạn';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      // Stream realtime tự cập nhật project/tasks/members sau khi ghi,
      // nên không cần gọi lại truy vấn ở đây.
      if (mounted) {
        _message(successMessage);
      }
    } catch (e) {
      if (mounted) {
        _message(errorText(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showCreateTaskDialog() async {
    if (!_isLeader) {
      _message('Chỉ Leader của dự án mới được tạo công việc.');
      return;
    }
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? assigneeId;
    String priority = 'medium';
    DateTime? dueDate;
    String outputType = 'docs';
    bool outputRequired = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tạo công việc'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tên công việc *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập tên công việc'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: assigneeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Người thực hiện',
                        border: OutlineInputBorder(),
                      ),
                      items: _members
                          .map((member) {
                            final id = _stringValue(member, const [
                              'id',
                              '_id',
                              'userId',
                              'user_id',
                            ]);
                            return DropdownMenuItem(
                              value: id,
                              child: Text(
                                _memberName(member),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          })
                          .where((item) => item.value?.isNotEmpty == true)
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => assigneeId = value),
                      validator: (value) => value == null
                          ? 'Vui lòng chọn người thực hiện'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(
                        labelText: 'Mức độ ưu tiên',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Thấp')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Trung bình'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('Cao')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => priority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: outputType,
                      decoration: const InputDecoration(
                        labelText: 'Loại đầu ra',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'docs',
                          child: Text('Google Docs / Tài liệu'),
                        ),
                        DropdownMenuItem(
                          value: 'drive',
                          child: Text('Google Drive'),
                        ),
                        DropdownMenuItem(
                          value: 'sheet',
                          child: Text('Google Sheets / Bảng tính'),
                        ),
                        DropdownMenuItem(
                          value: 'file',
                          child: Text('Tệp đính kèm'),
                        ),
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('Không yêu cầu đầu ra'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          outputType = value;
                          if (value == 'none') {
                            outputRequired = false;
                          }
                        });
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bắt buộc nộp đường dẫn/kết quả'),
                      value: outputType == 'none' ? false : outputRequired,
                      onChanged: outputType == 'none'
                          ? null
                          : (value) => setDialogState(
                              () => outputRequired = value ?? true,
                            ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dueDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => dueDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          dueDate == null
                              ? 'Chọn hạn hoàn thành'
                              : 'Hạn: ${_formatDate(dueDate!.toIso8601String())}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.pop(dialogContext, {
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'assigneeId': assigneeId,
                  'priority': priority,
                  'dueDate': dueDate?.toIso8601String(),
                  'outputType': outputType,
                  'outputRequired': outputType != 'none' && outputRequired,
                });
              },
              child: const Text('Tạo công việc'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    descriptionController.dispose();

    if (result == null || !mounted) {
      return;
    }
    await _runAction(
      () => _taskService.create(widget.projectId, result),
      successMessage: 'Đã tạo công việc.',
    );
  }

  Future<void> _startTask(Map<String, dynamic> task) async {
    final id = _taskId(task);
    if (id.isEmpty) {
      _message('Task không có ID hợp lệ.');
      return;
    }
    await _runAction(
      () => _taskService.transition(widget.projectId, id, 'in_progress'),
      successMessage: 'Đã chuyển công việc sang Đang làm.',
    );
  }

  Future<void> _submitTask(Map<String, dynamic> task) async {
    final controller = TextEditingController(
      text: _stringValue(task, const [
        'outputLink',
        'output_link',
        'submissionUrl',
        'submission_url',
      ]),
    );
    final outputType = _stringValue(task, const [
      'outputType',
      'output_type',
    ], fallback: 'docs');
    final outputRequired =
        _firstValue(task, const ['outputRequired', 'output_required']) != false;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gửi kết quả công việc'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stringValue(task, const [
                    'title',
                    'name',
                  ], fallback: 'Công việc'),
                ),
                const SizedBox(height: 12),
                if (outputType != 'none')
                  TextFormField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Đường dẫn kết quả',
                      hintText: 'https://docs.google.com/...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (outputRequired && text.isEmpty) {
                        return 'Vui lòng nhập đường dẫn kết quả.';
                      }
                      if (text.isNotEmpty) {
                        final uri = Uri.tryParse(text);
                        if (uri == null ||
                            !uri.hasAuthority ||
                            !['http', 'https'].contains(uri.scheme)) {
                          return 'Vui lòng nhập URL bắt đầu bằng http:// hoặc https://';
                        }
                      }
                      return null;
                    },
                  )
                else
                  const Text('Công việc này không yêu cầu đường dẫn đầu ra.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (outputType != 'none' && !formKey.currentState!.validate()) {
                return;
              }
              Navigator.pop(dialogContext, controller.text.trim());
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) {
      return;
    }

    final id = _taskId(task);
    if (id.isEmpty) {
      _message('Task không có ID hợp lệ.');
      return;
    }
    await _runAction(
      () => _taskService.transition(
        widget.projectId,
        id,
        _isLeader && _isMyTask(task) ? 'completed' : 'pending_review',
        outputLink: result,
      ),
      successMessage: _isLeader
          ? 'Đã cập nhật kết quả công việc.'
          : 'Đã gửi công việc để Leader duyệt.',
    );
  }

  Future<void> _reviewTask(
    Map<String, dynamic> task, {
    required bool approve,
  }) async {
    String? comment;
    if (!approve) {
      final controller = TextEditingController();
      comment = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Yêu cầu chỉnh sửa'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Nhận xét',
              hintText: 'Nêu rõ nội dung cần chỉnh sửa',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (comment == null || !mounted) {
        return;
      }
    }

    final id = _taskId(task);
    if (id.isEmpty) {
      _message('Task không có ID hợp lệ.');
      return;
    }
    await _runAction(
      () => _taskService.transition(
        widget.projectId,
        id,
        approve ? 'completed' : 'revision_required',
        comment: comment,
      ),
      successMessage: approve
          ? 'Đã duyệt công việc.'
          : 'Đã gửi yêu cầu chỉnh sửa.',
    );
  }

  Future<void> _openLink(String rawLink) async {
    final uri = Uri.tryParse(rawLink.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      _message('Đường dẫn không hợp lệ.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _message('Không thể mở đường dẫn này.');
      }
    } catch (_) {
      if (mounted) {
        _message('Đã xảy ra lỗi khi mở đường dẫn.');
      }
    }
  }

  Widget _statCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECEBF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMemberByUsername() async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm thành viên'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (username == null || username.isEmpty || !mounted) return;
    await _runAction(
      () => _projectService.addMemberByUsername(widget.projectId, username),
      successMessage: 'Đã thêm thành viên.',
    );
  }

  Future<void> _removeMember(String uid) async {
    await _runAction(
      () => _projectService.removeMember(widget.projectId, uid),
      successMessage: 'Đã xóa thành viên khỏi dự án.',
    );
  }

  /// Leader chỉnh tên/mô tả/thẻ của dự án.
  Future<void> _editProject() async {
    final project = _project;
    if (project == null) return;
    final nameController = TextEditingController(
      text: _stringValue(project, const ['name'], fallback: 'Dự án'),
    );
    final descriptionController = TextEditingController(
      text: _stringValue(project, const ['description']),
    );
    final tagController = TextEditingController(
      text: _stringValue(project, const ['tag']),
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cập nhật dự án'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên dự án *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Tên không được để trống'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: tagController,
                  decoration: const InputDecoration(
                    labelText: 'Thẻ / danh mục',
                    hintText: 'mobile, marketing, research...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    final values = saved == true
        ? {
            'name': nameController.text.trim(),
            'description': descriptionController.text.trim(),
            'tag': tagController.text.trim(),
          }
        : null;
    nameController.dispose();
    descriptionController.dispose();
    tagController.dispose();
    if (values == null || !mounted) return;
    await _runAction(
      () => _projectService.update(widget.projectId, values),
      successMessage: 'Đã cập nhật dự án.',
    );
  }

  Future<void> _leaveProject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rời dự án'),
        content: const Text('Bạn chắc chắn muốn rời khỏi dự án này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Rời dự án'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runAction(
      () => _projectService.leave(widget.projectId),
      successMessage: 'Bạn đã rời dự án.',
    );
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _deleteProject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa dự án'),
        content: const Text(
          'Toàn bộ công việc, thành viên và dữ liệu của dự án sẽ bị xóa vĩnh viễn. '
          'Bạn chắc chắn chứ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: teamUpPink),
            child: const Text('Xóa dự án'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runAction(
      () => _projectService.delete(widget.projectId),
      successMessage: 'Đã xóa dự án.',
    );
    if (mounted) Navigator.maybePop(context);
  }

  void _onMenuSelected(String value) => switch (value) {
    'edit' => _editProject(),
    'leave' => _leaveProject(),
    'delete' => _deleteProject(),
    _ => null,
  };

  Widget _buildOverview(Map<String, dynamic> project) {
    final color = _projectColor(project);
    final projectName = _stringValue(project, const [
      'name',
      'title',
      'projectName',
    ], fallback: 'Dự án');
    final leaderId = _leaderId();

    return RefreshIndicator(
      onRefresh: _loadPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Vai trò của bạn: $_role',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_stringValue(project, const [
                        'description',
                      ]).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _stringValue(project, const ['description']),
                          style: const TextStyle(color: _textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_stringValue(project, const ['joinCode']).isNotEmpty) ...[
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.qr_code_2_rounded),
              title: const Text('Mã tham gia dự án'),
              subtitle: SelectableText(
                _stringValue(project, const ['joinCode']),
              ),
              trailing: IconButton(
                tooltip: 'Sao chép mã',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: _stringValue(project, const ['joinCode']),
                    ),
                  );
                  _message('Đã sao chép mã tham gia.');
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Tiến độ công việc',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard('Cần làm', _countStatus('Cần làm'), _textSecondary),
              const SizedBox(width: 10),
              _statCard(
                'Đang làm',
                _countStatus('Đang làm'),
                const Color(0xFF4285F4),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statCard(
                'Chờ duyệt',
                _countStatus('Chờ duyệt'),
                const Color(0xFFDB9B18),
              ),
              const SizedBox(width: 10),
              _statCard('Hoàn thành', _countStatus('Hoàn thành'), teamUpGreen),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Thành viên dự án',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ),
              Text(
                '${_members.length} người',
                style: const TextStyle(color: _textSecondary),
              ),
              if (_isLeader)
                IconButton(
                  tooltip: 'Thêm thành viên bằng username',
                  onPressed: _busy ? null : _addMemberByUsername,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Chưa có thông tin thành viên.',
                style: TextStyle(color: _textSecondary),
              ),
            )
          else
            ..._members.map((member) {
              final id = _stringValue(member, const [
                'uid',
                'id',
                '_id',
                'userId',
                'user_id',
              ]);
              final name = _memberName(member);
              final isLeader = id.isNotEmpty && id == leaderId;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.13),
                  child: Text(
                    name.trim().isEmpty
                        ? '?'
                        : name.trim().substring(0, 1).toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: id.isEmpty
                    ? null
                    : Text(id, style: const TextStyle(fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLeader ? 'Leader' : 'Member',
                      style: TextStyle(
                        color: isLeader ? teamUpDarkPurple : _textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_isLeader && !isLeader && id.isNotEmpty)
                      IconButton(
                        tooltip: 'Xóa thành viên',
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          size: 18,
                        ),
                        onPressed: _busy ? null : () => _removeMember(id),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTasks() {
    if (_tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.task_alt_rounded, size: 52, color: Color(0xFFD0CEDC)),
            SizedBox(height: 12),
            Center(
              child: Text(
                'Chưa có công việc nào',
                style: TextStyle(color: _textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPage,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildTaskCard(_tasks[index]),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final title = _stringValue(task, const [
      'title',
      'name',
    ], fallback: 'Công việc');
    final status = _status(task);
    final assigneeId = _assigneeId(task);
    final color = _statusColor(status);
    final outputLink = _stringValue(task, const [
      'outputLink',
      'output_link',
      'submissionUrl',
      'submission_url',
    ]);
    final comment = _stringValue(task, const [
      'reviewComment',
      'review_comment',
      'feedback',
    ]);
    final dueDate = _stringValue(task, const [
      'dueDate',
      'due_date',
      'deadline',
    ]);
    final mine = _isMyTask(task);
    final canStart = mine && (status == 'Cần làm' || status == 'Cần sửa');
    final canSubmit = mine && status == 'Đang làm';
    final canReview = _isLeader && status == 'Chờ duyệt';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECEBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (_stringValue(task, const ['description']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _stringValue(task, const ['description']),
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 17,
                color: _textSecondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _memberName(assigneeId),
                  style: const TextStyle(fontSize: 12, color: _textSecondary),
                ),
              ),
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: _textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                _formatDate(dueDate),
                style: const TextStyle(fontSize: 12, color: _textSecondary),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: teamUpPink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Nhận xét: $comment',
                style: const TextStyle(color: Color(0xFFB94B83), fontSize: 12),
              ),
            ),
          ],
          if (outputLink.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.link_rounded, size: 17, color: teamUpPurple),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => _openLink(outputLink),
                    child: Text(
                      outputLink,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: teamUpDarkPurple,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mở link',
                  onPressed: () => _openLink(outputLink),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  color: teamUpDarkPurple,
                ),
              ],
            ),
          ],
          if (canStart || canSubmit || canReview) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canStart)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _startTask(task),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      status == 'Cần sửa' ? 'Tiếp tục chỉnh sửa' : 'Bắt đầu',
                    ),
                  ),
                if (canSubmit)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _submitTask(task),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Gửi kết quả'),
                  ),
                if (canReview) ...[
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _reviewTask(task, approve: true),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('Duyệt'),
                    style: FilledButton.styleFrom(backgroundColor: teamUpGreen),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _reviewTask(task, approve: false),
                    icon: const Icon(Icons.edit_note_rounded, size: 17),
                    label: const Text('Yêu cầu sửa'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final projectName = project == null
        ? 'Chi tiết dự án'
        : _stringValue(project, const [
            'name',
            'title',
            'projectName',
          ], fallback: 'Chi tiết dự án');
    final color = project == null ? teamUpDarkPurple : _projectColor(project);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          projectName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_project != null)
            PopupMenuButton<String>(
              tooltip: 'Tùy chọn dự án',
              enabled: !_busy,
              icon: const Icon(Icons.more_vert_rounded, color: _textPrimary),
              onSelected: _onMenuSelected,
              itemBuilder: (_) => [
                if (_isLeader)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Sửa dự án'),
                    ),
                  ),
                if (!_isLeader)
                  const PopupMenuItem(
                    value: 'leave',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout_rounded),
                      title: Text('Rời dự án'),
                    ),
                  ),
                if (_isLeader)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: teamUpPink,
                      ),
                      title: Text('Xóa dự án'),
                    ),
                  ),
              ],
            ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _loadPage,
            icon: const Icon(Icons.refresh_rounded, color: _textPrimary),
          ),
          if (_isLeader)
            IconButton(
              tooltip: 'Tạo công việc',
              onPressed: _busy ? null : _showCreateTaskDialog,
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: teamUpDarkPurple,
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: color,
          unselectedLabelColor: _textSecondary,
          indicatorColor: color,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Tổng quan'),
            Tab(text: 'Công việc'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: teamUpDarkPurple),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: _textSecondary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Không thể tải dữ liệu dự án',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _textSecondary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loadPage,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : project == null
          ? const Center(child: Text('API không trả về thông tin dự án.'))
          : Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [_buildOverview(project), _buildTasks()],
                ),
                if (_busy)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: teamUpDarkPurple,
                    ),
                  ),
              ],
            ),
      floatingActionButton: !_loading && _error == null && _isLeader
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _showCreateTaskDialog,
              backgroundColor: teamUpDarkPurple,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo công việc'),
            )
          : null,
    );
  }
}
