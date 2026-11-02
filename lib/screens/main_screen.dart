import '../widgets/app_navigation_bar.dart';

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

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final ValueNotifier<int> _unread = ValueNotifier<int>(0);
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  static const _dests = appDestinations;

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
    _fade.dispose();
    _unread.dispose();
    super.dispose();
  }

  Future<void> _openProfile() async {
    final session = widget.session;
    if (session == null) return;
    final tab = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => ProfileScreen(
          session: session,
          selectedTab: _currentIndex,
          unread: _unread,
        ),
      ),
    );
    if (mounted && tab != null && tab >= 0 && tab < _dests.length) {
      setState(() => _currentIndex = tab);
    }
  }

  void _select(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _fade.forward(from: 0);
  }

  Widget _icon(int i, {required bool selected}) =>
      appDestinationIcon(i, selected: selected, unread: _unread);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;

    // IndexedStack giữ trạng thái từng tab; hiệu ứng mờ dần chạy bằng controller
    // riêng nên không dựng lại các tab.
    final body = FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: IndexedStack(index: _currentIndex, children: _screens),
    );

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _dests[_currentIndex].title,
            key: ValueKey(_currentIndex),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.brandGradient),
            child: SizedBox(height: 3, width: double.infinity),
          ),
        ),
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
                  indicatorColor: AppColors.purpleSoft,
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
          : AppNavigationBar(
              selectedIndex: _currentIndex,
              onSelected: _select,
              unread: _unread,
            ),
    );
  }
}
