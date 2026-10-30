import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../models/user_profile.dart';
import '../../widgets/app_frame.dart';
import '../../widgets/auth_layout.dart' show FormMessage;
import '../../widgets/primary_button.dart';
import '../../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, phone, bio, major;
  bool busy = false;
  String? error;
  late final UserProfile original;
  @override
  void initState() {
    super.initState();
    final u = widget.session.user!;
    original = u;
    name = TextEditingController(text: u.name);
    phone = TextEditingController(text: u.phone);
    bio = TextEditingController(text: u.bio);
    major = TextEditingController(text: u.specialty);
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    bio.dispose();
    major.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppFrame(
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
                  const UserAvatar(large: true),
                  const SizedBox(height: 12),
                  const Text(
                    'THÔNG TIN CÁ NHÂN',
                    style: TextStyle(
                      color: AppColors.darkPurple,
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
                  TextFormField(
                    controller: major,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Ngành học / Chuyên môn',
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    initialValue: original.email,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email đăng nhập',
                      suffixIcon: Icon(Icons.lock_outline),
                      helperText: 'Email đăng nhập không thay đổi ở đây',
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                    ),
                    validator: phoneValidator,
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: bio,
                    minLines: 3,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Giới thiệu bản thân',
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (error != null) FormMessage(error!),
                  if (busy) const LinearProgressIndicator(),
                  PrimaryButton(
                    busy ? 'Đang lưu…' : 'Lưu thay đổi',
                    onPressed: busy ? null : save,
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
  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.update(
        UserProfile(
          id: original.id,
          username: original.username,
          name: name.text.trim(),
          email: original.email,
          phone: phone.text.trim(),
          specialty: major.text.trim(),
          bio: bio.text.trim(),
          avatarUrl: original.avatarUrl,
          studentId: original.studentId,
          className: original.className,
          projects: original.projects,
          projectsAreMock: original.projectsAreMock,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu hồ sơ.')));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
