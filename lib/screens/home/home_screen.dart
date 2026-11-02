import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/motion.dart';
import '../tasks/task_store.dart';
import '../projects/create_project_screen.dart';
import '../projects/join_project_screen.dart';
import 'project_detail_screen.dart';

const Color teamUpGreen = Color(0xFF439751);
const Color teamUpPurple = Color(0xFF867CB3);
const Color teamUpPink = Color(0xFFF472B6);
const Color teamUpYellow = Color(0xFFFACC15);
const Color teamUpDarkPurple = Color(0xFF4D4379);

const Color _borderColor = Color(0xFFE8E6ED);
const Color _textColor = Color(0xFF252331);
const Color _secondaryColor = Color(0xFF777482);
const Color _pageBackground = Color(0xFFF8F7FA);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.userName = ''});

  /// Tên hiển thị của người dùng đăng nhập (rỗng -> dùng tên trong dữ liệu mẫu).
  final String userName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final TaskStore _store = TaskStore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _filter = 'Tất cả';

  List<Map<String, dynamic>> get _filteredProjects {
    final query = _searchController.text.trim().toLowerCase();

    return _store.projectsForCurrentUser().where((project) {
      final name = project['name']?.toString() ?? '';
      final tag = project['tag']?.toString() ?? '';
      final role = _store.roleInProject(project['id'].toString());

      final matchesSearch =
          name.toLowerCase().contains(query) ||
          tag.toLowerCase().contains(query);

      final matchesRole =
          _filter == 'Tất cả' ||
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

  /// Tên gọi (từ cuối của họ tên theo thói quen người Việt).
  String get _displayName {
    final name = widget.userName.trim();
    if (name.isEmpty) return _store.memberName(_store.currentUserId);
    return name.split(RegExp(r'\s+')).last;
  }

  Widget _statTile(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.20),
              color.withValues(alpha: 0.07),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(height: 10),
            AnimatedCount(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textColor,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: _secondaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final mine = _store.tasksForCurrentUser();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final doing = mine.where((t) => t['status'] == 'Đang làm').length;
    final review = mine.where((t) => t['status'] == 'Chờ duyệt').length;
    final done = mine.where((t) => t['status'] == 'Hoàn thành').length;
    final overdue = mine.where((t) {
      if (t['status'] == 'Hoàn thành') return false;
      final due = DateTime.tryParse(t['dueDate']?.toString() ?? '');
      return due != null && due.isBefore(today);
    }).length;
    return Row(
      children: [
        _statTile('Đang làm', doing, Icons.play_circle_outline, teamUpPurple),
        const SizedBox(width: 8),
        _statTile(
          'Chờ duyệt',
          review,
          Icons.hourglass_empty_rounded,
          const Color(0xFFE1B32C),
        ),
        const SizedBox(width: 8),
        _statTile('Hoàn thành', done, Icons.task_alt_rounded, teamUpGreen),
        const SizedBox(width: 8),
        _statTile(
          'Quá hạn',
          overdue,
          Icons.warning_amber_rounded,
          teamUpPink,
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
    return members.length;
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

  void _showProjectOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn muốn làm gì?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.add_box_outlined,
                    color: teamUpDarkPurple,
                  ),
                  title: const Text('Tạo project mới'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _createProject();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.group_add_outlined,
                    color: teamUpGreen,
                  ),
                  title: const Text('Tham gia project'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _joinProject();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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

  Widget _buildFilterChip(String label) {
    final selected = _filter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: teamUpPurple,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? teamUpPurple : _borderColor),
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : _textColor,
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
    final projectId = project['id'].toString();
    final name = project['name']?.toString() ?? 'Dự án';
    final tag = project['tag']?.toString() ?? 'Project';
    final role = _store.roleInProject(projectId);
    final isLeader = role == 'Leader';
    final color = _projectColor(project);
    final progress = _projectProgress(projectId);
    final memberCount = _projectMemberCount(project);

    return FadeSlideIn(
      index: index,
      child: Semantics(
      button: true,
      label: 'Dự án $name, hoàn thành $progress%',
      child: Card(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _borderColor),
        ),
        child: InkWell(
          onTap: () => _openProject(project),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 5)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _projectIcon(project),
                        color: color,
                        size: 26,
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _smallTag(
                                role,
                                isLeader ? teamUpPurple : teamUpGreen,
                              ),
                              _smallTag(tag, color),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _secondaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress / 100),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                value: value,
                                minHeight: 7,
                                backgroundColor: _borderColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress >= 100 ? teamUpGreen : color,
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$progress%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _secondaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.people_outline,
                      size: 17,
                      color: _secondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$memberCount',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _secondaryColor,
                      ),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final projects = _filteredProjects;
        return Scaffold(
          backgroundColor: _pageBackground,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                FadeSlideIn(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: teamUpPurple.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_greeting, $_displayName! 👋',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Cùng nhau tạo nên những dự án tuyệt vời!',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xE6FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildStats(),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm dự án...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tất cả'),
                      _buildFilterChip('Tôi là leader'),
                      _buildFilterChip('Tôi là member'),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dự án của bạn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    Text(
                      '${projects.length} dự án',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _secondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (projects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 44,
                          color: _secondaryColor,
                        ),
                        SizedBox(height: 12),
                        Text('Không tìm thấy dự án phù hợp'),
                      ],
                    ),
                  )
                else
                  ...projects.indexed.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildProjectCard(entry.$2, entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showProjectOptions,
            backgroundColor: teamUpGreen,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Dự án'),
          ),
        );
      },
    );
  }
}
