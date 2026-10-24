import 'package:flutter/material.dart';

import 'models/user_profile.dart';

void main() => runApp(const MyApp());
const olive = Color(0xFF707B55);
const ink = Color(0xFF202B42);

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final session = SessionController();
  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'TeamUp • Nghi',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFAF8F0),
      colorScheme: ColorScheme.fromSeed(seedColor: olive),
      textTheme: const TextTheme(bodyMedium: TextStyle(color: ink)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E3DA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E3DA)),
        ),
      ),
    ),
    home: ListenableBuilder(
      listenable: session,
      builder: (_, _) => session.user == null
          ? LoginScreen(session: session)
          : ProfileScreen(session: session),
    ),
  );
}

class Frame extends StatelessWidget {
  const Frame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SafeArea(child: child),
      ),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: olive,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: large ? 45 : 30,
    backgroundColor: const Color(0xFFE7DEC9),
    child: Icon(Icons.person_rounded, size: large ? 65 : 40, color: olive),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool hidden = true;
  @override
  void dispose() {
    email.dispose();
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
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (v) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch((v ?? '').trim())
                    ? null
                    : 'Vui lòng nhập email hợp lệ',
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
                validator: (v) => (v ?? '').length >= 6
                    ? null
                    : 'Nhập ít nhất 6 ký tự cho bản demo',
                onFieldSubmitted: (_) => submit(),
              ),
              const SizedBox(height: 28),
              PrimaryButton('Đăng nhập', onPressed: submit),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDDE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'BẢN DEMO GIAO DIỆN\nDùng email bất kỳ hợp lệ và mật khẩu từ 6 ký tự. Chưa kết nối API; dữ liệu sẽ mất khi tải lại ứng dụng.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
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
  void submit() {
    if (form.currentState!.validate()) widget.session.signIn(email.text.trim());
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) {
    final u = session.user!;
    return Frame(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE5E7CF), Color(0xFFFAF3E4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(36),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Hồ sơ cá nhân',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(Icons.spa_outlined, color: olive),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const Avatar(large: true),
                        const SizedBox(height: 16),
                        Text(
                          u.name,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(u.specialty),
                          side: BorderSide.none,
                          backgroundColor: const Color(0xFFE8EBD9),
                        ),
                        const Text(
                          'Không gian của bạn, câu chuyện của bạn.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        contact(Icons.mail_outline, u.email),
                        const SizedBox(height: 15),
                        contact(
                          Icons.phone_outlined,
                          u.phone.isEmpty ? 'Chưa thêm số điện thoại' : u.phone,
                        ),
                        const SizedBox(height: 22),
                        if (u.bio.isNotEmpty) ...[
                          const Text(
                            'GIỚI THIỆU',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: olive,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(u.bio, style: const TextStyle(height: 1.6)),
                          const SizedBox(height: 24),
                        ],
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFEAE7DE)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.edit_outlined),
                                title: const Text(
                                  'Chỉnh sửa thông tin cá nhân',
                                  style: TextStyle(fontSize: 14),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        EditProfileScreen(session: session),
                                  ),
                                ),
                              ),
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.logout,
                                  color: Colors.redAccent,
                                ),
                                title: const Text(
                                  'Đăng xuất',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () async {
                                  final yes = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Đăng xuất?'),
                                      content: const Text(
                                        'Bạn có thể đăng nhập lại để tiếp tục bản demo.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text('Hủy'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text('Đăng xuất'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (yes == true) session.signOut();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Bản demo • Thông tin chỉ lưu trong phiên này',
                          style: TextStyle(color: Colors.black45, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, color: olive),
                SizedBox(width: 8),
                Text('Tài khoản của tôi', style: TextStyle(color: olive)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget contact(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 19, color: olive),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ],
  );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, phone, bio;
  late String specialty;
  @override
  void initState() {
    super.initState();
    final u = widget.session.user!;
    name = TextEditingController(text: u.name);
    phone = TextEditingController(text: u.phone);
    bio = TextEditingController(text: u.bio);
    specialty = u.specialty;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Frame(
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            const Expanded(
              child: Text(
                'Chỉnh sửa thông tin',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: form,
              child: Column(
                children: [
                  const Avatar(large: true),
                  const SizedBox(height: 12),
                  const Text(
                    'THÔNG TIN CÁ NHÂN',
                    style: TextStyle(
                      color: olive,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Họ tên'),
                    maxLength: 80,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Vui lòng nhập họ tên'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: specialty,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Chuyên môn'),
                    items:
                        [
                              'UI/UX Designer',
                              'Flutter Developer',
                              'Backend Developer',
                              'Product Manager',
                              'Khác',
                            ]
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: (v) => specialty = v!,
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    initialValue: widget.session.user!.email,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email đăng nhập',
                      suffixIcon: Icon(Icons.lock_outline),
                      helperText: 'Email chỉ xem trong bản demo',
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                    ),
                    validator: (v) {
                      final s = (v ?? '').replaceAll(RegExp(r'[\s()+-]'), '');
                      return s.isEmpty || RegExp(r'^\d{9,15}$').hasMatch(s)
                          ? null
                          : 'Số điện thoại cần 9–15 chữ số';
                    },
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: bio,
                    minLines: 3,
                    maxLines: 4,
                    maxLength: 250,
                    decoration: const InputDecoration(
                      labelText: 'Giới thiệu bản thân',
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    'Lưu thay đổi',
                    onPressed: () {
                      if (!form.currentState!.validate()) return;
                      widget.session.update(
                        UserProfile(
                          name: name.text.trim(),
                          email: widget.session.user!.email,
                          phone: phone.text.trim(),
                          specialty: specialty,
                          bio: bio.text.trim(),
                        ),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã cập nhật hồ sơ trong phiên demo'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
