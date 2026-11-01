import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../services/service_errors.dart';
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

  /// 0..4 – chỉ để gợi ý trực quan, luật thật nằm ở passwordValidator.
  int get _strength {
    final p = password.text;
    var s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p) && RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) => Frame(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: busy ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Form(
        key: form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tạo tài khoản TeamUp',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bắt đầu cùng nhóm của bạn.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _field(
              name,
              'Họ tên',
              requiredText,
              icon: Icons.badge_outlined,
              max: 80,
              capitalization: TextCapitalization.words,
            ),
            _field(
              username,
              'Tên đăng nhập',
              usernameValidator,
              icon: Icons.person_outline_rounded,
              max: 30,
              hints: const [AutofillHints.newUsername],
            ),
            _field(
              email,
              'Email',
              emailValidator,
              icon: Icons.mail_outline_rounded,
              keyboard: TextInputType.emailAddress,
              hints: const [AutofillHints.email],
            ),
            TextFormField(
              controller: password,
              enabled: !busy,
              obscureText: hidden,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: passwordValidator,
              onChanged: (_) => setState(() {}),
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
            ),
            if (password.text.isNotEmpty) _StrengthBar(level: _strength),
            const SizedBox(height: 16),
            TextFormField(
              controller: confirm,
              enabled: !busy,
              obscureText: hidden,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == password.text ? null : 'Mật khẩu xác nhận không khớp.',
              decoration: const InputDecoration(
                labelText: 'Xác nhận mật khẩu',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
            ),
            const SizedBox(height: 16),
            _field(
              major,
              'Ngành học / Chuyên môn (không bắt buộc)',
              null,
              icon: Icons.school_outlined,
              max: 120,
            ),
            _field(
              phone,
              'Số điện thoại (không bắt buộc)',
              phoneValidator,
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
              last: true,
            ),
            if (error != null) InlineError(error!),
            PrimaryButton('Đăng ký', loading: busy, onPressed: submit),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController c,
    String label,
    String? Function(String?)? validator, {
    required IconData icon,
    int? max,
    TextInputType? keyboard,
    Iterable<String>? hints,
    TextCapitalization capitalization = TextCapitalization.none,
    bool last = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      enabled: !busy,
      maxLength: max,
      keyboardType: keyboard,
      autofillHints: hints,
      textCapitalization: capitalization,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: last ? (_) => submit() : null,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        counterText: '',
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
      await widget.session.signUp({
        'username': username.text.trim().toLowerCase(),
        'email': email.text.trim().toLowerCase(),
        'password': password.text,
        'displayName': name.text.trim(),
        'major': major.text.trim(),
        'phone': phone.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công. Đang mở TeamUp...')),
      );
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.level});
  final int level;
  @override
  Widget build(BuildContext context) {
    const labels = ['Rất yếu', 'Yếu', 'Khá', 'Mạnh', 'Rất mạnh'];
    const colors = [
      AppColors.danger,
      AppColors.danger,
      AppColors.yellow,
      AppColors.green,
      AppColors.green,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                decoration: BoxDecoration(
                  color: i < level ? colors[level] : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          const SizedBox(width: 10),
          Text(
            labels[level],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors[level] == AppColors.yellow
                  ? AppColors.darkPurple
                  : colors[level],
            ),
          ),
        ],
      ),
    );
  }
}
