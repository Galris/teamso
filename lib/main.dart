import 'package:flutter/material.dart';

import 'controllers/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'widgets/auth_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    session.restore();
  }

  @override
  void dispose() {
    if (widget.session == null) session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => MaterialApp(
      key: ValueKey(session.user != null),
      debugShowCheckedModeBanner: false,
      title: 'TeamUp',
      theme: AppTheme.light,
      home: session.initializing
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : session.startupError != null
          ? Frame(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(session.startupError!),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      'Thử kết nối lại',
                      onPressed: session.restore,
                    ),
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
            )
          : session.user == null
          ? LoginScreen(session: session)
          : MainScreen(session: session),
    ),
  );
}
