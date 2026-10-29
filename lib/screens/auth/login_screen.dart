import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../widgets/auth_widgets.dart';
import '../../utils/validators.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  bool hidden = true;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Frame(
    child: AutofillGroup(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 36),
              const Icon(Icons.spa_rounded, color: olive, size: 48),
              const Text(
                'TeamUp',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: ink,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cùng nhau hoàn thành điều tuyệt vời.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 46),
              const Text(
                'Chào mừng trở lại 👋',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              const Text('Đăng nhập để tiếp tục hành trình của bạn.'),
              const SizedBox(height: 28),
              TextFormField(
                controller: username,
                keyboardType: TextInputType.text,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: usernameValidator,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: password,
                obscureText: hidden,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: passwordValidator,
                onFieldSubmitted: (_) => submit(),
              ),
              const SizedBox(height: 28),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (busy) const LinearProgressIndicator(),
              PrimaryButton(
                busy ? 'Đang đăng nhập…' : 'Đăng nhập',
                onPressed: busy ? null : submit,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RegisterScreen(session: widget.session),
                        ),
                      ),
                child: const Text('Chưa có tài khoản? Đăng ký'),
              ),
              const SizedBox(height: 35),
              const Center(
                child: Text(
                  'TEAMUP  /  AUTH & PROFILE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: olive,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.signIn(username.text.trim(), password.text);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
