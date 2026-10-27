import 'package:flutter/material.dart';

import '../tasks/task_store.dart';
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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware {
  final TaskStore _store = TaskStore.instance;
  final TextEditingController _searchController =
      TextEditingController();

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

      final matchesRole = _filter == 'Tất cả' ||
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
        builder: (_) => ProjectDetailScreen(
          projectId: projectId,
        ),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Chức năng tạo dự án sẽ được bổ sung sau.',
                        ),
                      ),
                    );
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Chức năng tham gia dự án sẽ được bổ sung sau.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
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
        selectedColor: teamUpDarkPurple,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? teamUpDarkPurple : _borderColor,
        ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
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

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final projectId = project['id'].toString();
    final name = project['name']?.toString() ?? 'Dự án';
    final tag = project['tag']?.toString() ?? 'Project';
    final role = _store.roleInProject(projectId);
    final isLeader = role == 'Leader';
    final color = _projectColor(project);
    final progress = _projectProgress(projectId);
    final memberCount = _projectMemberCount(project);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openProject(project),
      child: Card(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _borderColor),
        ),
        child: Padding(
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
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 7,
                        backgroundColor: _borderColor,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                          teamUpGreen,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final projects = _filteredProjects;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Text(
              'Chào buổi chiều, ${_store.memberName(_store.currentUserId)}! 👋',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cùng nhau tạo nên những dự án tuyệt vời!',
              style: TextStyle(
                fontSize: 13,
                color: _secondaryColor,
              ),
            ),
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
                fillColor: _pageBackground,
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
              ...projects.map(
                (project) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildProjectCard(project),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showProjectOptions,
        backgroundColor: teamUpDarkPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}