import 'package:flutter/material.dart';

import 'controllers/session_controller.dart';
import 'screens/auth/login_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'widgets/auth_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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
      // Recreate the navigator when authentication changes, clearing private routes.
      key: ValueKey(session.user != null),
      debugShowCheckedModeBanner: false,
      title: 'TeamUp',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAF8F0),
        colorScheme: ColorScheme.fromSeed(seedColor: olive),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: ink)),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E3DA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E3DA)),
          ),
        ),
      ),

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
          : ProfileScreen(session: session),
    ),
  );
}
