import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_widgets.dart';

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
  Widget build(BuildContext context) => Frame(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            const Text(
              'Tạo tài khoản TeamUp',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Bắt đầu cùng nhóm của bạn.'),
            const SizedBox(height: 24),
            field(name, 'Họ tên', requiredText, max: 80),
            field(username, 'Tên đăng nhập', usernameValidator, max: 30),
            field(
              email,
              'Email',
              emailValidator,
              keyboard: TextInputType.emailAddress,
            ),
            TextFormField(
              controller: password,
              obscureText: hidden,
              validator: passwordValidator,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                suffixIcon: IconButton(
                  tooltip: 'Ẩn / hiện mật khẩu',
                  onPressed: () => setState(() => hidden = !hidden),
                  icon: const Icon(Icons.visibility_outlined),
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: confirm,
              obscureText: hidden,
              validator: (v) =>
                  v == password.text ? null : 'Mật khẩu xác nhận không khớp.',
              decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu'),
            ),
            const SizedBox(height: 18),
            field(
              major,
              'Ngành học / Chuyên môn (không bắt buộc)',
              null,
              max: 120,
            ),
            field(
              phone,
              'Số điện thoại (không bắt buộc)',
              phoneValidator,
              keyboard: TextInputType.phone,
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (busy) const LinearProgressIndicator(),
            PrimaryButton(
              busy ? 'Đang đăng ký…' : 'Đăng ký',
              onPressed: busy ? null : submit,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  Widget field(
    TextEditingController c,
    String label,
    String? Function(String?)? validator, {
    int? max,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: c,
      maxLength: max,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    ),
  );
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.auth.signUp({
        'username': username.text.trim().toLowerCase(),
        'email': email.text.trim().toLowerCase(),
        'password': password.text,
        'displayName': name.text.trim(),
        'major': major.text.trim(),
        'phone': phone.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đăng ký thành công. Hãy đăng nhập bằng tên đăng nhập.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
