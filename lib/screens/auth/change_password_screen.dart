import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/utils/validators.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/primary_button.dart';

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
  bool busy = false, hidden = true;
  String? error;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Widget passwordField(
    TextEditingController c,
    String label,
    String? Function(String?) validator, {
    bool toggle = false,
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

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Đổi mật khẩu',
    subtitle:
        'Sau khi đổi mật khẩu, mọi phiên cũ sẽ kết thúc. Hãy đăng nhập lại.',
    showBack: true,
    backEnabled: !busy,
    showLogo: false,
    children: [
      Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            passwordField(current, 'Mật khẩu hiện tại', requiredText, toggle: true),
            passwordField(
              next,
              'Mật khẩu mới',
              (v) =>
                  passwordValidator(v) ??
                  (v == current.text
                      ? 'Mật khẩu mới phải khác mật khẩu cũ.'
                      : null),
            ),
            passwordField(
              confirm,
              'Xác nhận mật khẩu',
              (v) => v == next.text ? null : 'Mật khẩu xác nhận không khớp.',
            ),
            const SizedBox(height: 6),
            if (error != null) FormMessage(error!),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            PrimaryButton(
              busy ? 'Đang cập nhật…' : 'Đổi mật khẩu',
              onPressed: busy ? null : submit,
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Thành công: session bị xóa → app tự quay về màn đăng nhập.
      await widget.session.changePassword(current.text, next.text);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
