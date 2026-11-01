import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../services/service_errors.dart';
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
  bool busy = false, hidden = true;
  String? error;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Widget _pw(
    TextEditingController c,
    String label,
    String? Function(String?) validator, {
    bool last = false,
    bool toggle = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      enabled: !busy,
      obscureText: hidden,
      validator: validator,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: last ? (_) => submit() : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
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
  Widget build(BuildContext context) => Frame(
    appBar: AppBar(
      title: const Text('Đổi mật khẩu'),
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: busy ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.purpleSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.darkPurple,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sau khi đổi mật khẩu, mọi phiên cũ sẽ kết thúc. Hãy đăng nhập lại.',
                      style: TextStyle(height: 1.45, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _pw(current, 'Mật khẩu hiện tại', requiredText, toggle: true),
            _pw(
              next,
              'Mật khẩu mới',
              (v) =>
                  passwordValidator(v) ??
                  (v == current.text
                      ? 'Mật khẩu mới phải khác mật khẩu cũ.'
                      : null),
            ),
            _pw(
              confirm,
              'Xác nhận mật khẩu',
              (v) => v == next.text ? null : 'Mật khẩu xác nhận không khớp.',
              last: true,
            ),
            const SizedBox(height: 8),
            if (error != null) InlineError(error!),
            PrimaryButton('Đổi mật khẩu', loading: busy, onPressed: submit),
          ],
        ),
      ),
    ),
  );

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.auth.changePassword(current.text, next.text);
      await widget.session.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
