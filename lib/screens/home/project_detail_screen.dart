import 'package:flutter/material.dart';
import 'package:teamup_app/screens/tasks/task_store.dart';

const Color teamUpGreen = Color(0xFF439751);
const Color teamUpPurple = Color(0xFF867CB3);
const Color teamUpPink = Color(0xFFF472B6);
const Color teamUpYellow = Color(0xFFFACC15);
const Color teamUpDarkPurple = Color(0xFF4D4379);

const Color _background = Color(0xFFF7F7FB);
const Color _textPrimary = Color(0xFF282638);
const Color _textSecondary = Color(0xFF858397);

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TaskStore _store = TaskStore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _project =>
      _store.projectById(widget.projectId);

  String get _role =>
      _store.roleInProject(widget.projectId);

  bool get _isLeader => _role == 'Leader';

  List<Map<String, dynamic>> get _projectTasks {
    final result = _store.tasksForProject(widget.projectId);

    result.sort((a, b) {
      final dateA =
          DateTime.tryParse(a['dueDate']?.toString() ?? '');
      final dateB =
          DateTime.tryParse(b['dueDate']?.toString() ?? '');

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateA.compareTo(dateB);
    });

    return result;
  }

  int _countStatus(String status) {
    return _projectTasks
        .where((task) => task['status'] == status)
        .length;
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Chưa có hạn';
    }

    final date = DateTime.tryParse(value);
    if (date == null) return 'Chưa có hạn';

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
        return const Color(0xFFDB9B18);
      case 'Cần sửa':
        return teamUpPink;
      default:
        return _textSecondary;
    }
  }

  Color _projectColor(Map<String, dynamic> project) {
    final value = project['color'];

    if (value is Color) return value;
    if (value is int) return Color(value);

    switch (project['tag']?.toString()) {
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

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showCreateTaskDialog() async {
    if (!_store.canCreateTask(widget.projectId)) {
      _showMessage('Chỉ Leader của dự án mới được tạo công việc.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final outputRequired = ValueNotifier<bool>(true);

    String? assigneeId;
    String outputType = 'docs';
    String priority = 'Trung bình';
    DateTime? dueDate;

    final project = _project;
    if (project == null) {
      _showMessage('Không tìm thấy dự án.');
      titleController.dispose();
      outputRequired.dispose();
      return;
    }

    final members = (project['members'] as List<dynamic>? ?? [])
        .map((id) => id.toString())
        .toList();

    if (members.isNotEmpty) {
      assigneeId = members.first;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tạo công việc'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Tên công việc',
                            hintText: 'Nhập tên công việc',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập tên công việc';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: assigneeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Người thực hiện',
                            border: OutlineInputBorder(),
                          ),
                          items: members.map((id) {
                            return DropdownMenuItem(
                              value: id,
                              child: Text(_store.memberName(id)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              assigneeId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration: const InputDecoration(
                            labelText: 'Mức độ ưu tiên',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Thấp',
                              child: Text('Thấp'),
                            ),
                            DropdownMenuItem(
                              value: 'Trung bình',
                              child: Text('Trung bình'),
                            ),
                            DropdownMenuItem(
                              value: 'Cao',
                              child: Text('Cao'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                priority = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
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
                              value: 'files',
                              child: Text('Tệp đính kèm'),
                            ),
                            DropdownMenuItem(
                              value: 'none',
                              child: Text('Không yêu cầu đầu ra'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                outputType = value;
                                if (value == 'none') {
                                  outputRequired.value = false;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                        ValueListenableBuilder<bool>(
                          valueListenable: outputRequired,
                          builder: (context, required, child) {
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Bắt buộc nộp đường dẫn hoặc kết quả',
                              ),
                              value: outputType == 'none'
                                  ? false
                                  : required,
                              onChanged: outputType == 'none'
                                  ? null
                                  : (value) {
                                      outputRequired.value =
                                          value ?? true;
                                    },
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );

                            if (picked != null) {
                              setDialogState(() {
                                dueDate = picked;
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                          ),
                          label: Text(
                            dueDate == null
                                ? 'Chọn hạn hoàn thành'
                                : 'Hạn: ${_formatDate(dueDate!.toIso8601String())}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;

                    if (assigneeId == null) {
                      ScaffoldMessenger.of(dialogContext)
                          .showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng chọn người thực hiện'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Tạo công việc'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      try {
        _store.createTask(
          projectId: widget.projectId,
          title: titleController.text.trim(),
          assigneeId: assigneeId!,
          priority: priority,
          dueDate: dueDate?.toIso8601String(),
          outputType: outputType,
          outputRequired: outputType != 'none' &&
              outputRequired.value,
        );

        _refresh();
        _showMessage('Đã tạo công việc.');
      } catch (e) {
        _showMessage(e.toString());
      }
    }

    titleController.dispose();
    outputRequired.dispose();
  }

  Future<void> _startTask(Map<String, dynamic> task) async {
    try {
      _store.startTask(task['id'].toString());
      _refresh();
      _showMessage('Đã chuyển sang Đang làm.');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _submitTask(Map<String, dynamic> task) async {
    final outputController = TextEditingController(
      text: task['outputLink']?.toString() ?? '',
    );

    final outputType = task['outputType']?.toString() ?? 'none';
    final outputRequired = task['outputRequired'] == true;

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Gửi công việc'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task['title']?.toString() ?? 'Công việc'),
              const SizedBox(height: 12),
              if (outputType != 'none')
                Text(
                  outputRequired
                      ? 'Vui lòng nhập đường dẫn kết quả.'
                      : 'Có thể nhập đường dẫn kết quả nếu có.',
                  style: const TextStyle(
                    color: _textSecondary,
                  ),
                ),
              if (outputType != 'none') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: outputController,
                  decoration: const InputDecoration(
                    labelText: 'Đường dẫn kết quả',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final link = outputController.text.trim();

                if (outputType != 'none' &&
                    outputRequired &&
                    link.isEmpty) {
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Bạn cần nhập đường dẫn kết quả.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, link);
              },
              child: const Text('Gửi'),
            ),
          ],
        );
      },
    );

    outputController.dispose();

    if (result == null) return;

    try {
      _store.submitTask(
        task['id'].toString(),
        outputLink: result,
      );

      _refresh();
      _showMessage(
        _isLeader
            ? 'Đã hoàn thành công việc.'
            : 'Đã gửi công việc để Leader duyệt.',
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
        _store.approveTask(task['id'].toString());
        _refresh();
        _showMessage('Đã duyệt công việc.');
      } catch (e) {
        _showMessage(e.toString());
      }
      return;
    }

    final commentController = TextEditingController(
      text: task['reviewComment']?.toString() ?? '',
    );

    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Yêu cầu chỉnh sửa'),
          content: TextField(
            controller: commentController,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Nhận xét cho người thực hiện',
              hintText: 'Nêu rõ nội dung cần chỉnh sửa',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                commentController.text.trim(),
              ),
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        );
      },
    );

    commentController.dispose();

    if (comment == null) return;

    try {
      _store.requestTaskChanges(
        task['id'].toString(),
        comment: comment,
      );
      _refresh();
      _showMessage('Đã gửi yêu cầu chỉnh sửa.');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Widget _buildOverview(Map<String, dynamic> project) {
    final color = _projectColor(project);

    return ListView(
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
                      project['name']?.toString() ??
                          'Dự án',
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
                  ],
                ),
              ),
            ],
          ),
        ),
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
            _buildStatCard(
              'Cần làm',
              _countStatus('Cần làm'),
              _textSecondary,
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              'Đang làm',
              _countStatus('Đang làm'),
              const Color(0xFF4285F4),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard(
              'Chờ duyệt',
              _countStatus('Chờ duyệt'),
              const Color(0xFFDB9B18),
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              'Hoàn thành',
              _countStatus('Hoàn thành'),
              teamUpGreen,
            ),
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
              '${(project['members'] as List<dynamic>? ?? []).length} người',
              style: const TextStyle(
                color: _textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(project['members'] as List<dynamic>? ?? [])
            .map((id) {
          final memberId = id.toString();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.13),
              child: Text(
                _store.memberInitials(memberId),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(
              _store.memberName(memberId),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: memberId ==
                    project['leaderId']?.toString()
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: teamUpPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Leader',
                      style: TextStyle(
                        color: teamUpDarkPurple,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  )
                : const Text(
                    'Member',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
                  ),
          );
        }),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    int count,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFECEBF2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasks() {
    final tasks = _projectTasks;

    if (tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 52,
              color: Color(0xFFD0CEDC),
            ),
            SizedBox(height: 12),
            Text(
              'Chưa có công việc nào',
              style: TextStyle(
                color: _textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildTaskCard(tasks[index]);
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final title = task['title']?.toString() ?? 'Công việc';
    final status = task['status']?.toString() ?? 'Cần làm';
    final assigneeId =
        task['assigneeId']?.toString() ?? '';
    final color = _statusColor(status);
    final taskId = task['id']?.toString() ?? '';
    final isMyTask = assigneeId == 'user_linh';
    final isWaiting = status == 'Chờ duyệt';

    final canStart = isMyTask && status == 'Cần làm';
    final canSubmit =
        isMyTask &&
        (status == 'Đang làm' || status == 'Cần sửa');
    final canReview = _isLeader && isWaiting;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFECEBF2),
        ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
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
                color: teamUpPink.withValues(alpha: 0.08),
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
                  size: 17,
                  color: teamUpPurple,
                ),
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
                if (canReview) ...[
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
                      backgroundColor: teamUpGreen,
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
          if (taskId.isNotEmpty) const SizedBox(height: 0),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;

    if (project == null) {
      return Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text('Chi tiết dự án'),
        ),
        body: const Center(
          child: Text('Không tìm thấy dự án.'),
        ),
      );
    }

    final color = _projectColor(project);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: _textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          project['name']?.toString() ?? 'Chi tiết dự án',
          style: const TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
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
        actions: [
          if (_store.canCreateTask(widget.projectId))
            IconButton(
              tooltip: 'Tạo công việc',
              onPressed: _showCreateTaskDialog,
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: color,
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverview(project),
          _buildTasks(),
        ],
      ),
      floatingActionButton:
          _store.canCreateTask(widget.projectId)
              ? FloatingActionButton.extended(
                  onPressed: _showCreateTaskDialog,
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tạo công việc'),
                )
              : null,
    );
  }
}