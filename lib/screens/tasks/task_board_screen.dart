import 'package:flutter/material.dart';

import '../../widgets/motion.dart';
import '../../widgets/prompt_dialog.dart';
import 'task_calendar.dart';
import 'task_store.dart';
import '../../core/theme/app_colors.dart';


const Color _background = Color(0xFFF7F7FB);
const Color _textPrimary = Color(0xFF282638);
const Color _textSecondary = Color(0xFF858397);

class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen>
    with SingleTickerProviderStateMixin {
  final TaskStore _store = TaskStore.instance;

  late final TabController _tabController;

  /// 0 = danh sách theo trạng thái, 1 = lịch deadline.
  int _viewMode = 0;

  static const List<String> _statuses = [
    'Cần làm',
    'Đang làm',
    'Cần sửa',
    'Chờ duyệt',
    'Cần bạn duyệt',
  ];

  @override
  void initState() {
    super.initState();

    // Mở mặc định ở tab Đang làm.
    _tabController = TabController(
      length: _statuses.length,
      initialIndex: 1,
      vsync: this,
    );

    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

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

  int _countForStatus(String status) {
    if (status == 'Cần bạn duyệt') {
      return _store.tasksToReview().length;
    }

    return _store
        .tasksForCurrentUser()
        .where((task) => task['status'] == status)
        .length;
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

  TabBar _buildStatusTabs() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: _tabColor(_tabController.index),
      unselectedLabelColor: _textSecondary,
      indicatorColor: _tabColor(_tabController.index),
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: const Color(0xFFECEBF2),
      tabs: _statuses.map((status) {
        final count = _countForStatus(status);
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(status),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _tabController.index == _statuses.indexOf(status)
                      ? _tabColor(_statuses.indexOf(status)).withValues(alpha: 0.16)
                      : const Color(0xFFF0EFF5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTaskList(String status) {
    final tasks = _tasksForStatus(status);

    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 110),
            Icon(Icons.task_alt_rounded, size: 52, color: Color(0xFFD0CEDC)),
            SizedBox(height: 12),
            Center(
              child: Text(
                'Không có công việc trong mục này',
                style: TextStyle(color: _textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return FadeSlideIn(
            key: ValueKey(tasks[index]['id']),
            index: index,
            child: _buildTaskCard(tasks[index], status),
          );
        },
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
    final isMyTask = assigneeId == _store.currentUserId;
    final isLeader = _store.roleInProject(projectId) == 'Leader';
    final isReviewTab = currentTab == 'Cần bạn duyệt';

    final canStart = isMyTask && (status == 'Cần làm' || status == 'Cần sửa');

    final canSubmit = isMyTask && status == 'Đang làm';

    final canReview = isLeader && status == 'Chờ duyệt';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                    style: const TextStyle(
                      color: teamUpDarkPurple,
                      fontSize: 12,
                    ),
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

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.view_list_rounded, size: 18),
              label: Text('Công việc'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.calendar_month_rounded, size: 18),
              label: Text('Lịch deadline'),
            ),
          ],
          selected: {_viewMode},
          onSelectionChanged: (value) =>
              setState(() => _viewMode = value.first),
        ),
      ),
    );
  }

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
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => Scaffold(
        backgroundColor: _background,
        body: Column(
          children: [
            Material(
              color: Colors.white,
              child: Column(
                children: [
                  _buildViewToggle(),
                  if (_viewMode == 0) _buildStatusTabs(),
                ],
              ),
            ),
            Expanded(
              child: _viewMode == 0
                  ? TabBarView(
                      controller: _tabController,
                      children: _statuses.map(_buildTaskList).toList(),
                    )
                  : TaskCalendarView(
                      store: _store,
                      myTasks: _myCalendarTasks(),
                      teamTasks: List.of(_store.tasks),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
