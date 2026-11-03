import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_messaging/firebase_messaging.dart';

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
  bool _profileOpen = false;
  StreamSubscription<RemoteMessage>? _foregroundPush;
  StreamSubscription<RemoteMessage>? _openedPush;

  @override
  void initState() {
    super.initState();
    final push = widget.session?.push;
    if (push == null || !push.supported) return;
    unawaited(push.start());
    _foregroundPush = FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.notification?.title ?? 'Bạn có thông báo mới'),
          action: SnackBarAction(label: 'Xem', onPressed: () => _select(4)),
        ),
      );
    });
    _openedPush = FirebaseMessaging.onMessageOpenedApp.listen((_) {
      if (mounted) _select(4);
    });
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
          if (message != null && mounted) _select(4);
        })
        .catchError((Object _) {});
  }

  final ValueNotifier<int> _unread = ValueNotifier<int>(0);
  final ValueNotifier<int> _chatUnread = ValueNotifier<int>(0);
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  static const _dests = appDestinations;

  List<Widget> get _screens => [
    HomeScreen(userName: widget.session?.user?.name ?? ''),
    const TaskBoardScreen(),
    WorkspaceScreen(session: widget.session),
    ChatScreen(
      active: _currentIndex == 3 && !_profileOpen,
      unread: _chatUnread,
      session: widget.session,
      userName: widget.session?.user?.name ?? '',
    ),
    NotificationScreen(session: widget.session, unread: _unread),
  ];

  @override
  void dispose() {
    _foregroundPush?.cancel();
    _openedPush?.cancel();
    _fade.dispose();
    _unread.dispose();
    _chatUnread.dispose();
    super.dispose();
  }

  Future<void> _openProfile() async {
    final session = widget.session;
    if (session == null) return;
    setState(() => _profileOpen = true);
    final tab = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => ProfileScreen(
          session: session,
          selectedTab: _currentIndex,
          unread: _unread,
          chatUnread: _chatUnread,
        ),
      ),
    );
    if (mounted) setState(() => _profileOpen = false);
    if (mounted && tab != null && tab >= 0 && tab < _dests.length) {
      setState(() => _currentIndex = tab);
    }
  }

  void _select(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _fade.forward(from: 0);
  }

  Widget _icon(int i, {required bool selected}) => appDestinationIcon(
    i,
    selected: selected,
    unread: _unread,
    chatUnread: _chatUnread,
  );

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
        toolbarHeight: 80,
        backgroundColor: _currentIndex == 0
            ? const Color(0xFF788CDD)
            : _currentIndex == 3
            ? const Color(0xFF7661AA)
            : const Color(0xFF867CB3),
        foregroundColor: Colors.white,
        titleTextStyle: _currentIndex <= 2
            ? const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              )
            : null,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _currentIndex == 0
              ? Row(
                  key: const ValueKey('home-brand'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Transform.scale(
                        scale: 1.2,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: 1.5,
                                sigmaY: 1.5,
                              ),
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                                child: Image.asset(
                                  'assets/images/app_logo_transparent.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            Image.asset(
                              'assets/images/app_logo_transparent.png',
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'TeamUp',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: ValueKey(_currentIndex),
                  children: [
                    if (_currentIndex == 1)
                      const SizedBox(
                        width: 52,
                        height: 52,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.assignment_turned_in_outlined,
                              size: 46,
                              color: Colors.white,
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Color(0xFFFFD469),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_currentIndex == 2)
                      const SizedBox(
                        width: 52,
                        height: 52,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 1,
                              right: 5,
                              child: Icon(
                                Icons.description_rounded,
                                size: 34,
                                color: Colors.white,
                              ),
                            ),
                            Positioned(
                              bottom: 1,
                              child: Icon(
                                Icons.folder_rounded,
                                size: 49,
                                color: Color(0xFFBDA4EA),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              child: Icon(
                                Icons.groups_rounded,
                                size: 21,
                                color: Colors.white,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Color(0xFFFFD469),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _currentIndex == 1
                              ? Colors.white.withValues(alpha: .20)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .5),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              _dests[_currentIndex].selectedIcon,
                              size: 27,
                              color: _currentIndex == 1
                                  ? Colors.white
                                  : AppColors.darkPurple,
                            ),
                            Positioned(
                              right: 3,
                              top: 3,
                              child: Icon(
                                Icons.auto_awesome,
                                size: 10,
                                color: _currentIndex == 1
                                    ? const Color(0xFFFACC15)
                                    : AppColors.pink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _dests[_currentIndex].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
                  indicatorColor: AppColors.darkPurple,
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
              chatUnread: _chatUnread,
            ),
    );
  }
}
