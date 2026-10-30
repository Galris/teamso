import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/utils/validators.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/primary_button.dart';
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
  String? notice;

  @override
  void initState() {
    super.initState();
    // Lấy thông báo một lần (vd. vừa đổi mật khẩu) rồi xóa khỏi session.
    notice = widget.session.notice;
    widget.session.notice = null;
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Chào mừng trở lại',
    subtitle: 'Đăng nhập để tiếp tục hành trình của bạn.',
    children: [
      AutofillGroup(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notice != null) FormMessage(notice!, isError: false),
              TextFormField(
                controller: username,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập',
                  prefixIcon: Icon(Icons.person_outline),
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
              const SizedBox(height: 24),
              if (error != null) FormMessage(error!),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              PrimaryButton(
                busy ? 'Đang đăng nhập…' : 'Đăng nhập',
                onPressed: busy ? null : submit,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: busy ? null : openRegister,
                  child: const Text('Chưa có tài khoản? Đăng ký'),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Future<void> openRegister() async {
    // Đăng ký xong trả về username để điền sẵn vào form đăng nhập.
    final registered = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => RegisterScreen(session: widget.session),
      ),
    );
    if (!mounted || registered == null) return;
    setState(() {
      username.text = registered;
      password.clear();
      error = null;
      notice = 'Đăng ký thành công. Hãy đăng nhập bằng tài khoản vừa tạo.';
    });
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
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
