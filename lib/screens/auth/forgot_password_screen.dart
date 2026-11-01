import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../services/service_errors.dart';
import '../../utils/validators.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/auth_widgets.dart';

/// Quên mật khẩu 2 bước: nhập email -> nhập mã + mật khẩu mới.
/// Endpoint: /auth/forgot-password và /auth/reset-password (xem API_CONTRACT.md).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.session,
    this.initialEmail = '',
  });
  final SessionController session;
  final String initialEmail;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailForm = GlobalKey<FormState>();
  final resetForm = GlobalKey<FormState>();
  late final email = TextEditingController(text: widget.initialEmail);
  final code = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool codeSent = false, busy = false, hidden = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (!emailForm.currentState!.validate()) return;
    await _run(() async {
      await widget.session.auth.forgotPassword(email.text);
      if (mounted) {
        showAppSnack(
          context,
          'Email đặt lại mật khẩu đã được gửi. Hãy mở email và làm theo liên kết từ Firebase.',
        );
        Navigator.pop(context);
      }
    });
  }

  Future<void> _reset() async {
    if (!resetForm.currentState!.validate()) return;
    await _run(() async {
      await widget.session.auth.resetPassword(
        email: email.text,
        code: code.text,
        newPassword: password.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnack(context, 'Đã đặt lại mật khẩu. Hãy đăng nhập lại.');
    });
  }

  @override
  Widget build(BuildContext context) => Frame(
    appBar: AppBar(
      title: const Text('Quên mật khẩu'),
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: busy ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: codeSent ? _resetStep() : _emailStep(),
      ),
    ),
  );

  Widget _emailStep() => Form(
    key: emailForm,
    child: Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_unread_outlined,
          size: 56,
          color: AppColors.purple,
        ),
        const SizedBox(height: 16),
        const Text(
          'Nhập email đã đăng ký. Firebase sẽ gửi liên kết để bạn đặt lại mật khẩu.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: email,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _sendCode(),
          validator: emailValidator,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        const SizedBox(height: 20),
        if (error != null) InlineError(error!),
        PrimaryButton(
          'Gửi liên kết đặt lại mật khẩu',
          loading: busy,
          onPressed: _sendCode,
        ),
      ],
    ),
  );

  Widget _resetStep() => Form(
    key: resetForm,
    child: Column(
      key: const ValueKey('reset'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mã xác nhận đã gửi tới ${email.text.trim()}.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: code,
          enabled: !busy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          validator: requiredText,
          decoration: const InputDecoration(
            labelText: 'Mã xác nhận',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: password,
          enabled: !busy,
          obscureText: hidden,
          textInputAction: TextInputAction.next,
          validator: passwordValidator,
          decoration: InputDecoration(
            labelText: 'Mật khẩu mới',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
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
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: confirm,
          enabled: !busy,
          obscureText: hidden,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _reset(),
          validator: (v) =>
              v == password.text ? null : 'Mật khẩu xác nhận không khớp.',
          decoration: const InputDecoration(
            labelText: 'Xác nhận mật khẩu',
            prefixIcon: Icon(Icons.lock_reset_rounded),
          ),
        ),
        const SizedBox(height: 20),
        if (error != null) InlineError(error!),
        PrimaryButton('Đặt lại mật khẩu', loading: busy, onPressed: _reset),
        TextButton(
          onPressed: busy ? null : () => setState(() => codeSent = false),
          child: const Text('Gửi lại mã / đổi email'),
        ),
      ],
    ),
  );
}
