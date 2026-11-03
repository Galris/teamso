import '../../core/theme/accent_surface.dart';
import '../../models/task_model.dart';
import '../tasks/task_detail_screen.dart';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/motion.dart';
import '../tasks/task_store.dart';
import '../projects/create_project_screen.dart';
import '../projects/join_project_screen.dart';
import 'project_detail_screen.dart';

const Color _borderColor = Color(0xFFE8E6ED);
const Color _textColor = Color(0xFF252331);
const Color _secondaryColor = Color(0xFF777482);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.userName = ''});

  /// Tên hiển thị của người dùng đang đăng nhập.
  final String userName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final TaskStore _store = TaskStore.instance;
  final TextEditingController _searchController = TextEditingController();

  static const String _hiddenFilter = 'Đã ẩn';
  String _filter = 'Tất cả';

  int get _hiddenCount => _store
      .projectsForCurrentUser()
      .where((p) => _store.isProjectHidden(p['id'].toString()))
      .length;

  int get _visibleCount =>
      _store.projectsForCurrentUser().length - _hiddenCount;

  List<Map<String, dynamic>> get _filteredProjects {
    final query = _searchController.text.trim().toLowerCase();

    return _store.projectsForCurrentUser().where((project) {
      final hidden = _store.isProjectHidden(project['id'].toString());
      // Dự án đã ẩn chỉ hiện ở tab "Đã ẩn"; các tab khác không có chúng.
      if ((_filter == _hiddenFilter) != hidden) return false;
      final name = project['name']?.toString() ?? '';
      final tag = project['tag']?.toString() ?? '';
      final role = _store.roleInProject(project['id'].toString());

      final matchesSearch =
          name.toLowerCase().contains(query) ||
          tag.toLowerCase().contains(query);

      final matchesRole =
          _filter == 'Tất cả' ||
          _filter == _hiddenFilter ||
          (_filter == 'Tôi là leader' && role == 'Leader') ||
          (_filter == 'Tôi là member' && role == 'Member');

      return matchesSearch && matchesRole;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get hasOverdueTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _store.tasksForCurrentUser().any((task) {
      final due = DateTime.tryParse(task['dueDate']?.toString() ?? '');
      return task['status'] != 'Hoàn thành' &&
          due != null &&
          due.isBefore(today);
    });
  }

  bool get hasManyTasks =>
      _store
          .tasksForCurrentUser()
          .where((task) => task['status'] != 'Hoàn thành')
          .length >=
      5;

  bool get completedEarly {
    final now = DateTime.now();
    return _store.tasksForCurrentUser().any((task) {
      final due = DateTime.tryParse(task['dueDate']?.toString() ?? '');
      return task['status'] == 'Hoàn thành' && due != null && due.isAfter(now);
    });
  }

  String get _greeting {
    if (hasOverdueTasks) return 'Cùng xử lý công việc quá hạn nhé';
    if (hasManyTasks) return 'Nhiều việc đang chờ, mình làm từng bước nhé';
    if (completedEarly) return 'Hoàn thành sớm rồi, bạn làm tốt lắm';

    final hour = DateTime.now().hour;
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 14) return 'Chào buổi trưa';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  /// Câu cổ vũ theo số việc chưa hoàn thành trong "Việc của tôi".
  /// Mỗi nhóm có vài câu, đổi theo ngày để không lặp lại mãi một câu.
  String get _motivation {
    final mine = _store.tasksForCurrentUser();
    final open = mine.where((t) => t['status'] != 'Hoàn thành').length;
    final List<String> quotes;
    if (open >= 6) {
      quotes = const [
        'Còn rất nhiều task chờ bạn hoàn thành đấy!',
        'Việc nhiều thì chia nhỏ ra, làm từng cái một thôi!',
        'Bắt đầu từ task dễ nhất, đà sẽ đến ngay!',
      ];
    } else if (open >= 3) {
      quotes = const [
        'Còn vài task nữa thôi, cố lên nào!',
        'Bạn đang đi đúng hướng, tăng tốc một chút nhé!',
        'Từng bước nhỏ mỗi ngày sẽ thành kết quả lớn!',
      ];
    } else if (open >= 1) {
      quotes = const [
        'Chỉ còn một chút nữa là xong rồi, cố lên!',
        'Sắp về đích rồi, giữ vững phong độ nhé!',
        'Gần xong rồi, hoàn thành nốt để nhẹ đầu thôi!',
      ];
    } else if (mine.any((t) => t['status'] == 'Hoàn thành')) {
      // Từng hoàn thành task và hiện không còn việc nào.
      quotes = const [
        'Bạn đã hoàn thành hết task, tuyệt vời lắm!',
        'Không còn task nào, hãy tận hưởng chút thời gian nghỉ nhé!',
        'Làm tốt lắm! Sẵn sàng cho thử thách tiếp theo chưa?',
      ];
    } else if (_store.projectsForCurrentUser().isEmpty) {
      // Tài khoản mới: chưa có dự án nào.
      quotes = const [
        'Chào mừng bạn đến với TeamUp! Tạo hoặc tham gia dự án đầu tiên nhé!',
        'Mọi hành trình đều bắt đầu từ dự án đầu tiên, bắt đầu thôi!',
      ];
    } else {
      // Đã có dự án nhưng chưa được giao task nào.
      quotes = const [
        'Chưa có task nào dành cho bạn, hãy cùng nhóm lên kế hoạch nhé!',
        'Dự án đã sẵn sàng, chỉ chờ task đầu tiên của bạn thôi!',
      ];
    }
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return quotes[dayOfYear % quotes.length];
  }

  /// Tên gọi (từ cuối của họ tên theo thói quen người Việt).
  String get _displayName {
    final name = widget.userName.trim();
    if (name.isEmpty) return _store.memberName(_store.currentUserId);
    return name.split(RegExp(r'\s+')).last;
  }

  void _showStatTasks(String label, List<Map<String, dynamic>> tasks) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                '$label · ${tasks.length} công việc',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: teamUpDarkPurple,
                ),
              ),
              const SizedBox(height: 16),
              if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'Chưa có công việc trong mục này.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _secondaryColor),
                  ),
                ),
              for (final task in tasks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.task_alt_outlined,
                    color: teamUpPurple,
                  ),
                  title: Text(
                    task['title']?.toString() ?? 'Công việc',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _store
                            .projectById(
                              task['projectId']?.toString() ?? '',
                            )?['name']
                            ?.toString() ??
                        'Dự án',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => TaskDetailScreen(
                          task: TaskModel.fromJson(task),
                          projectName: _store
                              .projectById(
                                task['projectId']?.toString() ?? '',
                              )?['name']
                              ?.toString(),
                          assigneeName: _store.memberName(
                            task['assigneeId']?.toString() ?? '',
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(
    String label,
    List<Map<String, dynamic>> tasks,
    int total,
    IconData icon,
    Color color,
  ) {
    final ratio = total == 0 ? 0.0 : tasks.length / total;
    final dark = Color.lerp(color, Colors.black, .35)!;
    return Semantics(
      button: true,
      label:
          '$label, ${tasks.length} công việc, ${(ratio * 100).round()} phần trăm',
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        color: Color.lerp(Colors.white, color, .12),
        child: InkWell(
          onTap: () => _showStatTasks(label, tasks),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .5),
                  color.withValues(alpha: .1),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    icon,
                    size: 23,
                    color: color.withValues(alpha: .75),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Tooltip(
                    message: 'Tỷ lệ trên tổng $total công việc được giao',
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: ratio,
                              strokeWidth: 4,
                              backgroundColor: color.withValues(alpha: .2),
                              color: color,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            '${(ratio * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dark,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${tasks.length} công việc',
                    style: TextStyle(fontSize: 11, color: dark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final mine = _store.tasksForCurrentUser();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = mine.where((t) {
      if (t['status'] == 'Hoàn thành') return false;
      final due = DateTime.tryParse(t['dueDate']?.toString() ?? '');
      return due != null && due.isBefore(today);
    }).toList();
    final tiles = [
      _statTile(
        'Đang làm',
        mine.where((t) => t['status'] == 'Đang làm').toList(),
        mine.length,
        Icons.assignment_outlined,
        teamUpPurple,
      ),
      _statTile(
        'Chờ duyệt',
        mine.where((t) => t['status'] == 'Chờ duyệt').toList(),
        mine.length,
        Icons.hourglass_empty_rounded,
        const Color(0xFFFFAC2F),
      ),
      _statTile(
        'Hoàn thành',
        mine.where((t) => t['status'] == 'Hoàn thành').toList(),
        mine.length,
        Icons.check_circle_outline_rounded,
        teamUpGreen,
      ),
      _statTile(
        'Quá hạn',
        overdue,
        mine.length,
        Icons.event_busy_outlined,
        teamUpPink,
      ),
    ];
    final activeProjects = _store.projectsForCurrentUser().where((project) {
      final status = (project['status'] ?? '').toString().toLowerCase();
      return !{'completed', 'done', 'hoàn thành'}.contains(status);
    }).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tiến độ công việc',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$activeProjects dự án đang thực hiện',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: teamUpDarkPurple),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
            final minWidth = largeText ? 110.0 : 74.0;
            final width = (constraints.maxWidth - 24) / 4;
            if (width < minWidth) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      SizedBox(width: minWidth, child: tiles[i]),
                    ],
                  ],
                ),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: tiles[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Color _projectColor(Map<String, dynamic> project) {
    final value = project['color'];

    if (value is Color) return value;
    if (value is int) return Color(value);

    switch (project['tag']?.toString()) {
      case 'Mobile':
      case 'Mobile App':
        return teamUpGreen;
      case 'Marketing':
        return teamUpPink;
      case 'Research':
        return teamUpYellow;
      default:
        return teamUpPurple;
    }
  }

  IconData _projectIcon(Map<String, dynamic> project) {
    switch (project['tag']?.toString()) {
      case 'Mobile':
      case 'Mobile App':
        return Icons.phone_android_rounded;
      case 'Marketing':
        return Icons.campaign_outlined;
      case 'Research':
        return Icons.lightbulb_outline_rounded;
      default:
        return Icons.dashboard_customize_outlined;
    }
  }

  int _projectProgress(String projectId) {
    final projectTasks = _store.tasksForProject(projectId);

    if (projectTasks.isEmpty) return 0;

    final completed = projectTasks
        .where((task) => task['status'] == 'Hoàn thành')
        .length;

    return ((completed / projectTasks.length) * 100).round();
  }

  int _projectMemberCount(Map<String, dynamic> project) {
    final members = project['members'] as List<dynamic>? ?? [];
    return members.isNotEmpty
        ? members.length
        : (project['memberIds'] as List?)?.length ?? 0;
  }

  void _openProject(Map<String, dynamic> project) {
    final projectId = project['id'].toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(projectId: projectId),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _createProject() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const CreateProjectScreen()),
    );
  }

  void _joinProject() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const JoinProjectScreen()),
    );
  }

  Future<void> _toggleHidden(Map<String, dynamic> project) async {
    final id = project['id'].toString();
    final name = project['name']?.toString() ?? 'Dự án';
    final hide = !_store.isProjectHidden(id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _store.setProjectHidden(id, hide);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    if (!mounted) return;
    // Dự án cuối cùng ở tab "Đã ẩn" vừa được bỏ ẩn thì quay về tab Tất cả.
    if (!hide && _filter == _hiddenFilter && _hiddenCount == 0) {
      setState(() => _filter = 'Tất cả');
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            hide ? 'Đã ẩn dự án "$name".' : 'Đã bỏ ẩn dự án "$name".',
          ),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => _store.setProjectHidden(id, !hide).catchError((_) {}),
          ),
        ),
      );
  }

  Widget _buildFilterChip(String label) {
    final selected = _filter == label;
    final accent = switch (label) {
      'Tôi là leader' => const Color(0xFF9A621A),
      'Tôi là member' => const Color(0xFF347C57),
      _hiddenFilter => const Color(0xFF777482),
      _ => const Color(0xFF7663A4),
    };

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(switch (label) {
          'Tôi là leader' => 'Trưởng nhóm',
          'Tôi là member' => 'Thành viên',
          _hiddenFilter => 'Đã ẩn ($_hiddenCount)',
          _ => label,
        }),
        selected: selected,
        showCheckmark: false,
        selectedColor: accent,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? accent : _borderColor),
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : _secondaryColor,
          fontWeight: FontWeight.w700,
        ),
        onSelected: (_) {
          setState(() => _filter = label);
        },
      ),
    );
  }

  Widget _smallTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color == teamUpYellow ? teamUpDarkPurple : color,
        ),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project, int index) {
    final id = project['id'].toString();
    final name = project['name']?.toString() ?? 'Dự án';
    final tag = project['tag']?.toString() ?? '';
    final role = _store.roleInProject(id);
    final color = _projectColor(project);
    final progress = _projectProgress(id);
    final tasks = _store.tasksForProject(id);
    final completed = tasks.where((t) => t['status'] == 'Hoàn thành').length;
    final members = _projectMemberCount(project);
    return FadeSlideIn(
      index: index,
      child: Semantics(
        button: true,
        label: 'Dự án $name, hoàn thành $progress%',
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openProject(project),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: color, width: 4)),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _projectIcon(project),
                          color: color == teamUpYellow
                              ? const Color(0xFFAD7A14)
                              : color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _smallTag(
                                  role == 'Leader'
                                      ? 'Trưởng nhóm'
                                      : 'Thành viên',
                                  role == 'Leader'
                                      ? teamUpDarkPurple
                                      : teamUpGreen,
                                ),
                                if (tag.isNotEmpty) _smallTag(tag, color),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: PopupMenuButton<String>(
                          tooltip: 'Tùy chọn',
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: _secondaryColor,
                          ),
                          onSelected: (_) => _toggleHidden(project),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'hide',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  _store.isProjectHidden(id)
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                title: Text(
                                  _store.isProjectHidden(id)
                                      ? 'Bỏ ẩn dự án'
                                      : 'Ẩn dự án',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tiến độ dự án',
                          style: TextStyle(
                            fontSize: 12,
                            color: _secondaryColor,
                          ),
                        ),
                      ),
                      Text(
                        '$progress%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: teamUpDarkPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 6,
                      backgroundColor: AppColors.purpleSoft,
                      color: progress == 100 ? teamUpGreen : teamUpPurple,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: _secondaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$completed/${tasks.length} công việc',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _secondaryColor,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_outline_rounded,
                            size: 17,
                            color: _secondaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$members thành viên',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyProjects() {
    final hasProjects = _store.projectsForCurrentUser().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: AccentBoxDecoration(
        accent: teamUpPurple,
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.purpleSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasProjects
                  ? Icons.search_off_rounded
                  : Icons.folder_open_rounded,
              size: 30,
              color: teamUpPurple,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasProjects ? 'Chưa tìm thấy dự án' : 'Bắt đầu dự án đầu tiên',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            hasProjects ? 'Thử một từ khóa khác hoặc bỏ bộ lọc.' : 'Tạo không gian làm việc mới hoặc tham gia cùng nhóm bằng mã dự án.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _secondaryColor, height: 1.5),
          ),
          const SizedBox(height: 18),
          if (hasProjects)
            TextButton(
              onPressed: () => setState(() {
                _searchController.clear();
                _filter = 'Tất cả';
              }),
              child: const Text('Xóa bộ lọc'),
            )
          else
            FilledButton.icon(
              onPressed: _createProject,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo dự án'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) {
      final projects = _filteredProjects;
      final all = _store.projectsForCurrentUser();
      final now = DateTime.now();
      final day = now.weekday == 7 ? 'CHỦ NHẬT' : 'THỨ ${now.weekday + 1}';
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .24, .50, .80],
            colors: [
              Color(0xFF788CDD),
              Color(0xFFA68AE5),
              Color(0xFFE6DDF8),
              Color(0xFFF8F7FA),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              padding: EdgeInsets.fromLTRB(
                constraints.maxWidth > 1000
                    ? (constraints.maxWidth - 960) / 2
                    : 20,
                16,
                constraints.maxWidth > 1000
                    ? (constraints.maxWidth - 960) / 2
                    : 20,
                32,
              ),
              children: [
                Text(
                  '$day · ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFEFEAFF),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$_greeting, ${_displayName.isEmpty ? 'bạn' : _displayName}!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  _store.projectsLoading
                      ? 'Đang tải không gian làm việc…'
                      : '$_visibleCount dự án · $_motivation',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF5F0FF),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm dự án…',
                    hintStyle: const TextStyle(color: Color(0xFFF3EEFF)),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                    fillColor: Colors.white.withValues(alpha: .17),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: .4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa tìm kiếm',
                            onPressed: () => setState(_searchController.clear),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildStats(),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, c) {
                    final buttons = [
                      FilledButton.icon(
                        onPressed: _createProject,
                        style: FilledButton.styleFrom(
                          backgroundColor: teamUpDarkPurple,
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Tạo dự án'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _joinProject,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: .8),
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.group_add_outlined, size: 20),
                        label: const Text('Tham gia'),
                      ),
                    ];
                    return c.maxWidth < 320 ||
                            MediaQuery.textScalerOf(context).scale(14) > 21
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buttons[0],
                              const SizedBox(height: 10),
                              buttons[1],
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: buttons[0]),
                              const SizedBox(width: 12),
                              Expanded(child: buttons[1]),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Dự án của bạn',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),
                    ),
                    _smallTag('${projects.length}', teamUpDarkPurple),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tất cả'),
                      _buildFilterChip('Tôi là leader'),
                      _buildFilterChip('Tôi là member'),
                      if (_hiddenCount > 0 || _filter == _hiddenFilter)
                        _buildFilterChip(_hiddenFilter),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_store.projectsLoading && all.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_store.projectsError != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AccentBoxDecoration(
                      accent: teamUpPurple,
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chưa tải được dự án',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _store.projectsError!,
                          style: const TextStyle(height: 1.5),
                        ),
                      ],
                    ),
                  )
                else if (projects.isEmpty)
                  _emptyProjects()
                else
                  ...projects.indexed.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildProjectCard(entry.$2, entry.$1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
