import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
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
              'Đổi mật khẩu',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sau khi đổi mật khẩu, mọi phiên cũ sẽ kết thúc. Hãy đăng nhập lại.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: current,
              obscureText: true,
              validator: requiredText,
              decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: next,
              obscureText: true,
              validator: (v) =>
                  passwordValidator(v) ??
                  (v == current.text
                      ? 'Mật khẩu mới phải khác mật khẩu cũ.'
                      : null),
              decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: confirm,
              obscureText: true,
              validator: (v) =>
                  v == next.text ? null : 'Mật khẩu xác nhận không khớp.',
              decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu'),
            ),
            const SizedBox(height: 24),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (busy) const LinearProgressIndicator(),
            PrimaryButton(
              busy ? 'Đang cập nhật…' : 'Đổi mật khẩu',
              onPressed: busy ? null : submit,
            ),
          ],
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
      await widget.session.users.changePassword(current.text, next.text);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
