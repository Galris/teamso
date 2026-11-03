import 'dart:async';

import '../../core/theme/accent_surface.dart';
import '../home/project_detail_screen.dart';

import 'package:flutter/material.dart';

import '../../widgets/prompt_dialog.dart';
import 'task_calendar.dart';
import 'task_store.dart';
import '../../core/theme/app_colors.dart';

const Color _textPrimary = Color(0xFF282638);
const Color _textSecondary = Color(0xFF858397);

class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  State<TaskBoardScreen> createState() => TaskBoardScreenState();
}

class TaskBoardScreenState extends State<TaskBoardScreen> {
  String? _notificationProject, _notificationTask;
  Timer? _notificationTimeout;

  @override
  void initState() {
    super.initState();
    _store.addListener(_openPendingNotification);
  }

  void openFromNotification(String projectId, String taskId) {
    _notificationTimeout?.cancel();
    _notificationProject = projectId;
    _notificationTask = taskId;
    setState(() {
      _viewMode = 0;
      _focusedStatus = null;
    });
    _notificationTimeout = Timer(const Duration(seconds: 15), () {
      if (!mounted || _notificationTask == null) return;
      _notificationTask = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa tải được công việc. Vui lòng thử lại thông báo.'),
        ),
      );
    });
    _openPendingNotification();
  }

  void _openPendingNotification() {
    if (!mounted || _notificationTask == null) return;
    final task = _store.tasks
        .where(
          (t) =>
              t['id'] == _notificationTask &&
              t['projectId'] == _notificationProject,
        )
        .firstOrNull;
    if (task == null) return;
    _notificationTask = null;
    _notificationTimeout?.cancel();
    final status = task['status']?.toString() ?? 'Cần làm';
    final review =
        status == 'Chờ duyệt' &&
        _store.roleInProject(task['projectId'].toString()) == 'Leader';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openTask(task, review ? 'Cần bạn duyệt' : status);
    });
  }

  final TaskStore _store = TaskStore.instance;

  final ScrollController _statusScroll = ScrollController();
  final Map<String, GlobalKey> _statusKeys = {};
  String? _focusedStatus;
  final Set<String> _collapsed = {};

  /// 0 = danh sách theo trạng thái, 1 = lịch deadline.
  int _viewMode = 0;

  static const List<String> _statuses = [
    'Cần làm',
    'Đang làm',
    'Cần sửa',
    'Chờ duyệt',
    'Cần bạn duyệt',
  ];

  List<Map<String, dynamic>> _tasksForStatus(String status) {
    List<Map<String, dynamic>> result;

    if (status == 'Cần bạn duyệt') {
      result = _store.tasksToReview();
    } else {
      result = _store
          .tasksForCurrentUser()
          .where((task) => task['status'] == status)
          .toList();
    }

    result.sort((a, b) {
      // Ưu tiên cao xếp trước; không hiện nhãn "Ưu tiên 1".
      final priorityA = _priorityRank(a['priority']?.toString());
      final priorityB = _priorityRank(b['priority']?.toString());

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      final dateA = DateTime.tryParse(a['dueDate']?.toString() ?? '');
      final dateB = DateTime.tryParse(b['dueDate']?.toString() ?? '');

      if (dateA == null && dateB == null) {
        return 0;
      }
      if (dateA == null) {
        return 1;
      }
      if (dateB == null) {
        return -1;
      }

      return dateA.compareTo(dateB);
    });

    return result;
  }

  int _priorityRank(String? priority) {
    switch (priority) {
      case 'Cao':
        return 0;
      case 'Trung bình':
        return 1;
      case 'Thấp':
        return 2;
      default:
        return 3;
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

  Color _statusColor(String status) {
    switch (status) {
      case 'Hoàn thành':
        return teamUpGreen;
      case 'Đang làm':
        return const Color(0xFF4285F4);
      case 'Chờ duyệt':
      case 'Cần bạn duyệt':
        return const Color(0xFFDB9B18);
      case 'Cần sửa':
        return teamUpPink;
      default:
        return _textSecondary;
    }
  }

  Color _projectColor(Map<String, dynamic>? project) {
    final color = project?['color'];

    if (color is Color) {
      return color;
    }
    if (color is int) {
      return Color(color);
    }

    switch (project?['tag']?.toString()) {
      case 'Mobile':
        return teamUpGreen;
      case 'Marketing':
        return teamUpPink;
      case 'Research':
        return const Color(0xFFE1B32C);
      default:
        return teamUpPurple;
    }
  }

  Future<void> _startTask(Map<String, dynamic> task) async {
    try {
      await _store.startTask(task['id'].toString());
      setState(() {});
      _showMessage('Đã chuyển công việc sang Đang làm.');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _submitTask(Map<String, dynamic> task) async {
    final outputType = task['outputType']?.toString() ?? 'none';
    final outputRequired = task['outputRequired'] == true;
    final needsLink = outputType != 'none';
    final title = task['title']?.toString() ?? 'Công việc';

    final result = await showTextPrompt(
      context,
      title: 'Gửi kết quả công việc',
      message: needsLink
          ? '$title\n\n${outputRequired ? 'Công việc này yêu cầu đầu ra.' : 'Bạn có thể bổ sung đường dẫn kết quả.'}'
          : title,
      label: 'Đường dẫn kết quả',
      hint: 'https://...',
      initialText: task['outputLink']?.toString() ?? '',
      confirmLabel: 'Gửi',
      maxLines: 3,
      showField: needsLink,
      validator: (text) => outputRequired && text.isEmpty
          ? 'Vui lòng nhập đường dẫn kết quả.'
          : null,
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      final warning = await _store.submitTask(
        task['id'].toString(),
        outputLink: result,
      );

      if (!mounted) return;
      setState(() {});
      _showMessage(
        warning != null
            ? 'Đã hoàn thành nhưng chưa cập nhật được Tài nguyên: $warning'
            : _store.roleInProject(task['projectId'].toString()) == 'Leader'
            ? 'Đã hoàn thành công việc.'
            : 'Đã gửi công việc cho Leader duyệt.',
      );
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _reviewTask(
    Map<String, dynamic> task, {
    required bool approve,
  }) async {
    if (approve) {
      try {
        final warning = await _store.approveTask(task['id'].toString());
        if (!mounted) return;
        setState(() {});
        _showMessage(
          warning != null
              ? 'Đã duyệt nhưng chưa cập nhật được Tài nguyên: $warning'
              : 'Đã duyệt công việc.',
        );
      } catch (e) {
        _showMessage(e.toString());
      }
      return;
    }

    final comment = await showTextPrompt(
      context,
      title: 'Yêu cầu chỉnh sửa',
      label: 'Nhận xét',
      hint: 'Nêu rõ phần cần chỉnh sửa',
      confirmLabel: 'Gửi yêu cầu',
      minLines: 2,
      maxLines: 5,
    );

    if (comment == null || !mounted) {
      return;
    }

    try {
      await _store.requestTaskChanges(task['id'].toString(), comment: comment);
      if (!mounted) return;
      setState(() {});
      _showMessage('Đã yêu cầu chỉnh sửa công việc.');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Mỗi cột trạng thái một màu riêng.
  Color _tabColor(int index) {
    const colors = [
      _textSecondary, // Cần làm
      Color(0xFF4285F4), // Đang làm
      teamUpPink, // Cần sửa
      Color(0xFFDB9B18), // Chờ duyệt
      teamUpGreen, // Cần bạn duyệt
    ];
    return colors[index.clamp(0, colors.length - 1)];
  }

  Color _selectedFilterColor(String? status) => switch (status) {
    'Cần làm' => const Color(0xFF7666A5),
    'Đang làm' => const Color(0xFF356BAE),
    'Cần sửa' => const Color(0xFFB5447D),
    'Chờ duyệt' => const Color(0xFF926713),
    'Cần bạn duyệt' => const Color(0xFF347546),
    _ => teamUpDarkPurple,
  };

  @override
  void dispose() {
    _notificationTimeout?.cancel();
    _store.removeListener(_openPendingNotification);
    _statusScroll.dispose();
    super.dispose();
  }

  Widget _buildStatusTabs() => SingleChildScrollView(
    controller: _statusScroll,
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final status in <String?>[null, ..._statuses])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              key: _statusKeys.putIfAbsent(status ?? 'all', () => GlobalKey()),
              color: _focusedStatus == status
                  ? _selectedFilterColor(status)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  setState(() => _focusedStatus = status);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final target = _statusKeys[status ?? 'all']?.currentContext;
                    if (target != null) {
                      final renderObject = target.findRenderObject();
                      if (renderObject != null) {
                        Scrollable.of(target).position.ensureVisible(
                          renderObject,
                          alignment: .5,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  child: Text(
                    status ?? 'Tất cả',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _focusedStatus == status
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: _focusedStatus == status
                          ? Colors.white
                          : _textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  void _openTask(Map<String, dynamic> task, String group) {
    final taskId = task['id'];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .72,
          child: ListenableBuilder(
            listenable: _store,
            builder: (context, _) {
              final current = _store.tasks
                  .where(
                    (t) =>
                        t['id'] == taskId &&
                        t['projectId'] == task['projectId'],
                  )
                  .firstOrNull;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: current == null
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Công việc không còn khả dụng.'),
                      )
                    : _buildTaskCard(current, group),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _taskRow(Map<String, dynamic> task, String group) {
    final status = task['status']?.toString() ?? group;
    final color = _tabColor(_statuses.indexOf(group));
    final project = _store.projectById(task['projectId']?.toString() ?? '');
    final date = _formatDate(task['dueDate']?.toString());
    return Material(
      color: Colors.white.withValues(alpha: .92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openTask(task, group),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  status == 'Đang làm'
                      ? Icons.play_circle_outline_rounded
                      : status == 'Chờ duyệt'
                      ? Icons.hourglass_top_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 23,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['title']?.toString() ?? 'Công việc',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.folder_outlined,
                              size: 14,
                              color: _textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                project?['name']?.toString() ?? 'Dự án',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: _textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              date,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: group == 'Chờ duyệt'
                        ? const Color(0xFF90651D)
                        : teamUpDarkPurple,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(String status) {
    final tasks = _tasksForStatus(status);
    if (tasks.isEmpty && _focusedStatus == null) return const SizedBox.shrink();
    final color = _tabColor(_statuses.indexOf(status));
    final collapsed = _collapsed.contains(status);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      decoration: AccentBoxDecoration(
        accent: color,
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() {
              if (collapsed) {
                _collapsed.remove(status);
              } else {
                _collapsed.add(status);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_right_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: color,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '$status (${tasks.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed) ...[
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Chưa có công việc trong mục này.',
                  style: TextStyle(color: _textSecondary),
                ),
              ),
            for (var i = 0; i < tasks.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 3),
                child: _taskRow(tasks[i], status),
              ),
          ],
        ],
      ),
    );
  }

  void _createTask() {
    final projects = _store
        .projectsForCurrentUser()
        .where((p) => _store.canCreateTask(p['id'].toString()))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Text(
              'Tạo công việc cho dự án',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            for (final project in projects)
              ListTile(
                leading: const Icon(Icons.folder_outlined, color: teamUpPurple),
                title: Text(project['name']?.toString() ?? 'Dự án'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ProjectDetailScreen(
                        projectId: project['id'].toString(),
                        openCreateTask: true,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, String currentTab) {
    final projectId = task['projectId']?.toString() ?? '';
    final project = _store.projectById(projectId);
    final projectColor = _projectColor(project);
    final status = task['status']?.toString() ?? 'Cần làm';
    final statusColor = _statusColor(status);
    final assigneeId = task['assigneeId']?.toString() ?? '';
    final isMyTask =
        assigneeId == _store.currentUserId ||
        (task['assigneeIds'] is List &&
            (task['assigneeIds'] as List).contains(_store.currentUserId));
    final isLeader = _store.roleInProject(projectId) == 'Leader';
    final isReviewTab = currentTab == 'Cần bạn duyệt';

    final canStart = isMyTask && (status == 'Cần làm' || status == 'Cần sửa');

    final canSubmit = isMyTask && status == 'Đang làm';

    final canReview = isLeader && status == 'Chờ duyệt';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECEBF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F4D4379),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: statusColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildTaskCardBody(
                  task,
                  currentTab,
                  project,
                  projectColor,
                  status,
                  statusColor,
                  assigneeId,
                  canStart,
                  canSubmit,
                  canReview,
                  isReviewTab,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCardBody(
    Map<String, dynamic> task,
    String currentTab,
    Map<String, dynamic>? project,
    Color projectColor,
    String status,
    Color statusColor,
    String assigneeId,
    bool canStart,
    bool canSubmit,
    bool canReview,
    bool isReviewTab,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                task['title']?.toString() ?? 'Công việc',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Nhãn dự án
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: projectColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                project?['tag']?.toString() ??
                    project?['name']?.toString() ??
                    'Dự án',
                style: TextStyle(
                  color: projectColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (task['priority'] == 'Cao')
              const Text(
                'Cao',
                style: TextStyle(
                  color: Color(0xFFB94B54),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
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
                _store.memberName(assigneeId),
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: _textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              _formatDate(task['dueDate']?.toString()),
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),

        if (task['reviewComment'] != null &&
            task['reviewComment'].toString().trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: teamUpPink.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Nhận xét: ${task['reviewComment']}',
              style: const TextStyle(color: Color(0xFFB94B83), fontSize: 12),
            ),
          ),
        ],

        if (task['outputLink'] != null &&
            task['outputLink'].toString().trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.link_rounded, color: teamUpPurple, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task['outputLink'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: teamUpDarkPurple, fontSize: 12),
                ),
              ),
            ],
          ),
        ],

        if (canStart || canSubmit || (canReview && isReviewTab)) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canStart)
                OutlinedButton.icon(
                  onPressed: () => _startTask(task),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    status == 'Cần sửa' ? 'Tiếp tục chỉnh sửa' : 'Bắt đầu',
                  ),
                ),
              if (canSubmit)
                FilledButton.icon(
                  onPressed: () => _submitTask(task),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Gửi kết quả'),
                ),
              if (canReview && isReviewTab) ...[
                FilledButton.icon(
                  onPressed: () => _reviewTask(task, approve: true),
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text('Duyệt'),
                  style: FilledButton.styleFrom(backgroundColor: teamUpGreen),
                ),
                OutlinedButton.icon(
                  onPressed: () => _reviewTask(task, approve: false),
                  icon: const Icon(Icons.edit_note_rounded, size: 17),
                  label: const Text('Yêu cầu sửa'),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildViewToggle() => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .75),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      children: [
        for (var i = 0; i < 2; i++)
          Expanded(
            child: Material(
              color: _viewMode == i ? teamUpDarkPurple : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
              child: InkWell(
                borderRadius: BorderRadius.circular(26),
                onTap: () => setState(() => _viewMode = i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        i == 0
                            ? Icons.format_list_bulleted_rounded
                            : Icons.calendar_month_outlined,
                        size: 18,
                        color: _viewMode == i ? Colors.white : teamUpDarkPurple,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          i == 0 ? 'Công việc' : 'Lịch deadline',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _viewMode == i
                                ? Colors.white
                                : teamUpDarkPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  /// Task của tôi + task tôi cần duyệt (không trùng).
  List<Map<String, dynamic>> _myCalendarTasks() {
    final byId = <String, Map<String, dynamic>>{};
    for (final task in _store.tasksForCurrentUser()) {
      byId[task['id'].toString()] = task;
    }
    for (final task in _store.tasksToReview()) {
      byId[task['id'].toString()] = task;
    }
    return byId.values.toList();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) {
      final canCreate = _store.projectsForCurrentUser().any(
        (p) => _store.canCreateTask(p['id'].toString()),
      );
      final groups = _focusedStatus == null ? _statuses : [_focusedStatus!];
      final empty = groups.every((status) => _tasksForStatus(status).isEmpty);
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .72, 1],
              colors: [Colors.white, Colors.white, Color(0xFFFFF1F7)],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: _viewMode == 0
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          _buildViewToggle(),
                          const SizedBox(height: 16),
                          _buildStatusTabs(),
                          if (empty && _focusedStatus == null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.task_alt_rounded,
                                    color: teamUpPurple,
                                    size: 44,
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    'Bạn chưa có công việc cần xử lý',
                                    style: TextStyle(
                                      color: teamUpDarkPurple,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          for (final status in groups) _group(status),
                        ],
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildViewToggle(),
                          ),
                          Expanded(
                            child: TaskCalendarView(
                              store: _store,
                              myTasks: _myCalendarTasks(),
                              teamTasks: List.of(_store.tasks),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: canCreate
            ? FloatingActionButton.extended(
                onPressed: _createTask,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo công việc'),
              )
            : null,
      );
    },
  );
}
