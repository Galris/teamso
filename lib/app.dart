import 'package:flutter/material.dart';

import 'controllers/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/app_frame.dart';
import 'widgets/primary_button.dart';

/// Tên cũ, giữ lại để test/code cũ vẫn biên dịch được.
typedef MyApp = TeamUpApp;

/// Gốc ứng dụng. Luồng điều hướng theo trạng thái của [SessionController]:
///
///   initializing  → SplashScreen
///   startupError  → màn lỗi kết nối (thử lại / về đăng nhập)
///   user == null  → LoginScreen  ⇄ RegisterScreen
///   user != null  → MainScreen   → ProfileScreen → Edit / ChangePassword
///
/// Đăng xuất, hết phiên hoặc đổi mật khẩu đều làm `user = null`, app tự
/// quay về LoginScreen (Navigator được reset nhờ `key`).
class TeamUpApp extends StatefulWidget {
  const TeamUpApp({super.key, this.session});
  final SessionController? session;

  @override
  State<TeamUpApp> createState() => _TeamUpAppState();
}

class _TeamUpAppState extends State<TeamUpApp> {
  late final SessionController session;

  @override
  void initState() {
    super.initState();
    session = widget.session ?? SessionController();
    session.restore();
  }

  @override
  void dispose() {
    if (widget.session == null) session.dispose();
    super.dispose();
  }

  Widget _home() {
    if (session.initializing) return const SplashScreen();
    if (session.startupError != null) {
      return _StartupErrorScreen(session: session);
    }
    if (session.user == null) return LoginScreen(session: session);
    return MainScreen(session: session);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => MaterialApp(
      key: ValueKey(session.user != null),
      debugShowCheckedModeBanner: false,
      title: 'TeamUp',
      theme: AppTheme.light,
      home: _home(),
    ),
  );
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) => AppFrame(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 16),
          Text(session.startupError!, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          PrimaryButton('Thử kết nối lại', onPressed: session.restore),
          TextButton(
            onPressed: () => session.api.clearSession().then((_) {
              session.startupError = null;
              session.restore();
            }),
            child: const Text('Về đăng nhập'),
          ),
        ],
      ),
    ),
  );
}
