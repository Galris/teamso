import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../services/service_errors.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_widgets.dart';
import 'forgot_password_screen.dart';
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
  final passwordFocus = FocusNode();
  bool hidden = true;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    username.dispose();
    password.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Frame(
    child: AutofillGroup(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/app_logo.png',
                  height: 150,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.groups_rounded,
                    color: AppColors.darkPurple,
                    size: 72,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Chào mừng trở lại 👋',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Đăng nhập để tiếp tục làm việc cùng nhóm của bạn.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: username,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enableSuggestions: false,
                onFieldSubmitted: (_) => passwordFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: emailValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                focusNode: passwordFocus,
                enabled: !busy,
                obscureText: hidden,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
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
                // Khi đăng nhập chỉ cần không để trống; luật độ dài áp dụng lúc đăng ký.
                validator: requiredText,
                onFieldSubmitted: (_) => submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ForgotPasswordScreen(
                              session: widget.session,
                              initialEmail: '',
                            ),
                          ),
                        ),
                  child: const Text('Quên mật khẩu?'),
                ),
              ),
              const SizedBox(height: 4),
              if (error != null) InlineError(error!),
              PrimaryButton('Đăng nhập', loading: busy, onPressed: submit),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Chưa có tài khoản?',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
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
                    child: const Text('Đăng ký'),
                  ),
                ],
              ),
            ],
          ),
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
      await widget.session.signIn(username.text.trim(), password.text);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
