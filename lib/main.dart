import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'controllers/session_controller.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/auth_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TeamUpApp());
}

class TeamUpApp extends MyApp {
  const TeamUpApp({super.key, super.session});
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.session});
  final SessionController? session;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final SessionController session;
  @override
  void initState() {
    super.initState();
    session = widget.session ?? SessionController();
  }

  @override
  void dispose() {
    if (widget.session == null) session.dispose();
    super.dispose();
  }

  Widget _startupError() => Frame(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 56,
            color: AppColors.purple,
          ),
          const SizedBox(height: 18),
          const Text(
            'Không thể kết nối',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            session.startupError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            'Thử kết nối lại',
            icon: Icons.refresh_rounded,
            onPressed: session.restore,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await session.signOut();
              session.startupError = null;
            },
            child: const Text('Về đăng nhập'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => MaterialApp(
      key: ValueKey(session.user != null),
      debugShowCheckedModeBanner: false,
      title: 'TeamUp',
      theme: AppTheme.light,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: session.initializing
            ? const SplashScreen(
                key: ValueKey('splash'),
                message: 'Đang khôi phục phiên đăng nhập…',
              )
            : session.startupError != null
            ? KeyedSubtree(key: const ValueKey('error'), child: _startupError())
            : session.user == null
            ? LoginScreen(key: const ValueKey('login'), session: session)
            : MainScreen(key: const ValueKey('main'), session: session),
      ),
    ),
  );
}
