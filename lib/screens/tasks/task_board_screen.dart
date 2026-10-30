import 'package:flutter/material.dart';
import '../../controllers/projects_controller.dart';
import '../../core/theme/app_colors.dart';

class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({super.key, required this.projects});
  final ProjectsController projects;

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen>
    with SingleTickerProviderStateMixin {
  ProjectsController get _data => widget.projects;
  bool _busy = false;

  late final TabController _tabController;

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
      result = _data.tasksToReview();
    } else {
      result = _data
          .tasksForCurrentUser()
          .where((task) => _data.taskStatus(task) == status)
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
      return _data.tasksToReview().length;
    }

    return _data
        .tasksForCurrentUser()
        .where((task) => _data.taskStatus(task) == status)
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
        return AppColors.green;
      case 'Đang làm':
        return const Color(0xFF4285F4);
      case 'Chờ duyệt':
      case 'Cần bạn duyệt':
        return const Color(0xFFDB9B18);
      case 'Cần sửa':
        return AppColors.pink;
      default:
        return AppColors.textSecondary;
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
        return AppColors.green;
      case 'Marketing':
        return AppColors.pink;
      case 'Research':
        return const Color(0xFFE1B32C);
      default:
        return AppColors.purple;
    }
  }

  /// Chạy một thao tác API, chặn bấm trùng và báo kết quả bằng snackbar.
  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _showMessage(successMessage);
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startTask(Map<String, dynamic> task) => _run(
    () => _data.startTask(task),
    'Đã chuyển công việc sang Đang làm.',
  );

  Future<void> _submitTask(Map<String, dynamic> task) async {
    final controller = TextEditingController(
      text: task['outputLink']?.toString() ?? '',
    );

    // Cùng quy ước với ProjectDetailScreen: mặc định yêu cầu đầu ra.
    final outputType = task['outputType']?.toString() ?? 'docs';
    final outputRequired = task['outputRequired'] != false;
    final isLeader =
        _data.roleInProject(task['projectId'].toString()) == 'Leader';

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Gửi kết quả công việc'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task['title']?.toString() ?? 'Công việc'),
              if (outputType != 'none') ...[
                const SizedBox(height: 12),
                Text(
                  outputRequired
                      ? 'Công việc này yêu cầu đầu ra.'
                      : 'Bạn có thể bổ sung đường dẫn kết quả.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Đường dẫn kết quả',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final link = controller.text.trim();

                if (outputType != 'none' && outputRequired && link.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập đường dẫn kết quả.'),
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(link);
              },
              child: const Text('Gửi'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) {
      return;
    }

    if (!mounted) return;
    await _run(
      () => _data.submitTask(task, result),
      isLeader ? 'Đã hoàn thành công việc.' : 'Đã gửi công việc cho Leader duyệt.',
    );
  }

  Future<void> _reviewTask(
    Map<String, dynamic> task, {
    required bool approve,
  }) async {
    if (approve) {
      await _run(() => _data.approveTask(task), 'Đã duyệt công việc.');
      return;
    }

    final controller = TextEditingController();

    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Yêu cầu chỉnh sửa'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Nhận xét',
              hintText: 'Nêu rõ phần cần chỉnh sửa',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                controller.text.trim(),
              ),
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (comment == null || !mounted) {
      return;
    }

    await _run(
      () => _data.requestChanges(task, comment),
      'Đã yêu cầu chỉnh sửa công việc.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildStatusTabs() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: AppColors.darkPurple,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.purple,
      indicatorWeight: 3,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _tabController.index == _statuses.indexOf(status)
                      ? AppColors.purple.withValues(alpha: 0.15)
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
        onRefresh: _data.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 110),
            Icon(
              Icons.task_alt_rounded,
              size: 52,
              color: Color(0xFFD0CEDC),
            ),
            SizedBox(height: 12),
            Center(
              child: Text(
                'Không có công việc trong mục này',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _data.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildTaskCard(tasks[index], status);
        },
      ),
    );
  }

  Widget _buildTaskCard(
    Map<String, dynamic> task,
    String currentTab,
  ) {
    final projectId = task['projectId']?.toString() ?? '';
    final project = _data.projectById(projectId);
    final projectColor = _projectColor(project);
    final status = _data.taskStatus(task);
    final statusColor = _statusColor(status);
    final isMyTask = _data.assigneeId(task) == _data.userId;
    final isLeader = _data.roleInProject(projectId) == 'Leader';
    final isReviewTab = currentTab == 'Cần bạn duyệt';

    final canStart = !_busy && isMyTask && (status == 'Cần làm' || status == 'Cần sửa');

    final canSubmit = !_busy && isMyTask && (status == 'Đang làm' || status == 'Cần sửa');

    final canReview = !_busy && isLeader && status == 'Chờ duyệt';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFECEBF2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
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
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
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
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _data.assigneeName(task),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                _formatDate(task['dueDate']?.toString()),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
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
                color: AppColors.pink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Nhận xét: ${task['reviewComment']}',
                style: const TextStyle(
                  color: Color(0xFFB94B83),
                  fontSize: 12,
                ),
              ),
            ),
          ],

          if (task['outputLink'] != null &&
              task['outputLink'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.link_rounded,
                  color: AppColors.purple,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task['outputLink'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.darkPurple,
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
                if (canStart && status == 'Cần làm')
                  OutlinedButton.icon(
                    onPressed: () => _startTask(task),
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                    ),
                    label: const Text('Bắt đầu'),
                  ),
                if (canSubmit)
                  FilledButton.icon(
                    onPressed: () => _submitTask(task),
                    icon: const Icon(
                      Icons.send_rounded,
                      size: 16,
                    ),
                    label: const Text('Gửi kết quả'),
                  ),
                if (canReview && isReviewTab) ...[
                  FilledButton.icon(
                    onPressed: () => _reviewTask(
                      task,
                      approve: true,
                    ),
                    icon: const Icon(
                      Icons.check_rounded,
                      size: 17,
                    ),
                    label: const Text('Duyệt'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _reviewTask(
                      task,
                      approve: false,
                    ),
                    icon: const Icon(
                      Icons.edit_note_rounded,
                      size: 17,
                    ),
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

  Widget _buildBody() {
    if (!_data.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data.error != null && _data.projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 12),
              Text(_data.error!, textAlign: TextAlign.center),
              TextButton.icon(
                onPressed: _data.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_data.projects.isEmpty) {
      return RefreshIndicator(
        onRefresh: _data.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 110),
            Icon(Icons.folder_open_rounded, size: 52, color: Color(0xFFD0CEDC)),
            SizedBox(height: 12),
            Center(child: Text('Chưa có dự án')),
            SizedBox(height: 4),
            Center(
              child: Text(
                'Tham gia dự án để nhận công việc.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return TabBarView(
      controller: _tabController,
      children: _statuses.map(_buildTaskList).toList(),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _data,
    builder: (context, _) => Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildStatusTabs(),
        ),
      ),
      body: _buildBody(),
    ),
  );
}
