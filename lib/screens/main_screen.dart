import 'package:flutter/material.dart';

import '../controllers/session_controller.dart';
import '../core/theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'chat/chat_screen.dart';
import 'home/home_screen.dart';
import 'notify/notification_screen.dart';
import 'profile/profile_screen.dart';
import 'tasks/task_board_screen.dart';
import 'workspace/workspace_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.session});
  final SessionController? session;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _Dest {
  const _Dest(this.title, this.label, this.icon, this.selectedIcon);
  final String title, label;
  final IconData icon, selectedIcon;
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final ValueNotifier<int> _unread = ValueNotifier<int>(0);

  static const _dests = [
    _Dest('TeamUp', 'Trang chủ', Icons.home_outlined, Icons.home_rounded),
    _Dest(
      'Bảng công việc',
      'Công việc',
      Icons.checklist_rounded,
      Icons.checklist_rtl_rounded,
    ),
    _Dest(
      'Không gian nhóm',
      'Workspace',
      Icons.folder_outlined,
      Icons.folder_rounded,
    ),
    _Dest(
      'Trò chuyện',
      'Chat',
      Icons.chat_bubble_outline_rounded,
      Icons.chat_bubble_rounded,
    ),
    _Dest(
      'Thông báo',
      'Thông báo',
      Icons.notifications_none_rounded,
      Icons.notifications_rounded,
    ),
  ];

  late final List<Widget> _screens = [
    HomeScreen(userName: widget.session?.user?.name ?? ''),
    const TaskBoardScreen(),
    WorkspaceScreen(session: widget.session),
    ChatScreen(
      session: widget.session,
      userName: widget.session?.user?.name ?? '',
    ),
    NotificationScreen(session: widget.session, unread: _unread),
  ];

  @override
  void dispose() {
    _unread.dispose();
    super.dispose();
  }

  void _openProfile() {
    final session = widget.session;
    if (session == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProfileScreen(session: session)),
    );
  }

  void _select(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  Widget _icon(int i, {required bool selected}) {
    final d = _dests[i];
    final icon = Icon(selected ? d.selectedIcon : d.icon);
    if (i != 4) return icon;
    return ValueListenableBuilder<int>(
      valueListenable: _unread,
      builder: (_, count, _) => Badge(
        isLabelVisible: count > 0,
        label: Text(count > 9 ? '9+' : '$count'),
        backgroundColor: AppColors.pink,
        child: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;

    final body = IndexedStack(index: _currentIndex, children: _screens);

    return Scaffold(
      appBar: AppBar(
        title: Text(_dests[_currentIndex].title),
        actions: [
          ListenableBuilder(
            listenable: widget.session ?? _unread,
            builder: (context, _) {
              final u = widget.session?.user;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Tooltip(
                  message: 'Hồ sơ cá nhân',
                  child: InkResponse(
                    onTap: widget.session == null ? null : _openProfile,
                    radius: 24,
                    child: Avatar(
                      radius: 17,
                      url: u?.avatarUrl ?? '',
                      name: u?.name ?? '',
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  indicatorColor: AppColors.purple.withValues(alpha: 0.2),
                  destinations: [
                    for (var i = 0; i < _dests.length; i++)
                      NavigationRailDestination(
                        icon: _icon(i, selected: false),
                        selectedIcon: _icon(i, selected: true),
                        label: Text(_dests[i].label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: _select,
                destinations: [
                  for (var i = 0; i < _dests.length; i++)
                    NavigationDestination(
                      icon: _icon(i, selected: false),
                      selectedIcon: _icon(i, selected: true),
                      label: _dests[i].label,
                    ),
                ],
              ),
            ),
    );
  }
}
