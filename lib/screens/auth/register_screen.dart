import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/utils/validators.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController(),
      name = TextEditingController(),
      major = TextEditingController(),
      phone = TextEditingController();
  bool busy = false, hidden = true;
  String? error;

  @override
  void dispose() {
    for (final c in [username, email, password, confirm, name, major, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Tạo tài khoản',
    subtitle: 'Bắt đầu cùng nhóm của bạn.',
    showBack: true,
    backEnabled: !busy,
    showLogo: false,
    children: [
      Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field(
              name,
              'Họ tên',
              requiredText,
              icon: Icons.badge_outlined,
              max: 80,
            ),
            field(
              username,
              'Tên đăng nhập',
              usernameValidator,
              icon: Icons.person_outline,
              max: 30,
            ),
            field(
              email,
              'Email',
              emailValidator,
              icon: Icons.mail_outline,
              keyboard: TextInputType.emailAddress,
            ),
            passwordField(password, 'Mật khẩu', passwordValidator),
            passwordField(
              confirm,
              'Xác nhận mật khẩu',
              (v) => v == password.text ? null : 'Mật khẩu xác nhận không khớp.',
              toggle: false,
            ),
            field(
              major,
              'Ngành học / Chuyên môn (không bắt buộc)',
              null,
              icon: Icons.school_outlined,
              max: 120,
            ),
            field(
              phone,
              'Số điện thoại (không bắt buộc)',
              phoneValidator,
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 6),
            if (error != null) FormMessage(error!),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            PrimaryButton(
              busy ? 'Đang đăng ký…' : 'Đăng ký',
              onPressed: busy ? null : submit,
            ),
          ],
        ),
      ),
    ],
  );

  Widget field(
    TextEditingController c,
    String label,
    String? Function(String?)? validator, {
    required IconData icon,
    int? max,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: c,
      maxLength: max,
      keyboardType: keyboard,
      textInputAction: TextInputAction.next,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        counterText: '',
      ),
    ),
  );

  Widget passwordField(
    TextEditingController c,
    String label,
    String? Function(String?) validator, {
    bool toggle = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: c,
      obscureText: hidden,
      validator: validator,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: toggle
            ? IconButton(
                tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: () => setState(() => hidden = !hidden),
                icon: Icon(
                  hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : null,
      ),
    ),
  );

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final registered = username.text.trim().toLowerCase();
    try {
      await widget.session.auth.signUp({
        'username': registered,
        'email': email.text.trim().toLowerCase(),
        'password': password.text,
        'displayName': name.text.trim(),
        'major': major.text.trim(),
        'phone': phone.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, registered);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
