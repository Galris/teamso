import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_profile.dart';
import '../../widgets/app_frame.dart';
import '../../widgets/user_avatar.dart';
import '../auth/change_password_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _signingOut = false;

  void _editProfile() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EditProfileScreen(session: widget.session),
    ),
  );

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text(
          'Phiên đăng nhập sẽ được kết thúc trên thiết bị này. Bạn có muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    // Keep the messenger from before navigation resets to Login.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.session.signOut();
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Đã đăng xuất trên máy. Không thể thu hồi phiên ở server do lỗi kết nối.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    if (user == null) return const SizedBox.shrink();
    return AppFrame(
      child: SingleChildScrollView(
        key: const PageStorageKey('profile-scroll'),
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(user: user),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle(
                    'Dự án tham gia',
                    caption: 'Vai trò của bạn trong mỗi hành trình.',
                  ),
                  const SizedBox(height: 14),
                  if (user.projectsAreMock) ...[
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Dự án minh họa · Chưa có dữ liệu từ hệ thống.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (user.projects.isEmpty)
                    const _Surface(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_open_rounded,
                              color: AppColors.darkPurple,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Bạn chưa tham gia dự án nào.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final project in user.projects)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProjectCard(project: project),
                      ),
                  const SizedBox(height: 20),
                  const _SectionTitle(
                    'Liên hệ & học tập',
                    caption: 'Kết nối dễ dàng, cộng tác tốt hơn.',
                  ),
                  const SizedBox(height: 14),
                  _Surface(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          if (user.studentId?.isNotEmpty == true)
                            _ContactRow(
                              icon: Icons.badge_outlined,
                              label: 'Mã số sinh viên',
                              value: user.studentId!,
                            ),
                          if (user.className?.isNotEmpty == true)
                            _ContactRow(
                              icon: Icons.school_outlined,
                              label: 'Lớp',
                              value: user.className!,
                            ),
                          _ContactRow(
                            icon: Icons.mail_outline_rounded,
                            label: 'Email',
                            value: user.email.isEmpty
                                ? 'Chưa thêm email'
                                : user.email,
                          ),
                          _ContactRow(
                            icon: Icons.phone_outlined,
                            label: 'Số điện thoại',
                            value: user.phone.isEmpty
                                ? 'Chưa thêm số điện thoại'
                                : user.phone,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Surface(
                    color: const Color(0xFFEFECF7),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.format_quote_rounded,
                                size: 20,
                                color: AppColors.darkPurple,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Giới thiệu',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkPurple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            user.bio.isEmpty
                                ? 'Thêm một vài dòng để mọi người hiểu bạn hơn.'
                                : user.bio,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              height: 1.65,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle('Tài khoản & cài đặt'),
                  const SizedBox(height: 14),
                  _Surface(
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.edit_outlined,
                          title: 'Chỉnh sửa thông tin cá nhân',
                          subtitle: 'Họ tên, chuyên môn và giới thiệu',
                          onTap: _signingOut ? null : _editProfile,
                        ),
                        const Divider(
                          height: 1,
                          indent: 18,
                          endIndent: 18,
                          color: AppColors.border,
                        ),
                        _ActionTile(
                          icon: Icons.lock_outline_rounded,
                          title: 'Đổi mật khẩu',
                          subtitle: 'Bảo vệ tài khoản của bạn',
                          onTap: _signingOut
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => ChangePasswordScreen(
                                      session: widget.session,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Surface(
                    color: const Color(0xFFFCF0EC),
                    child: _ActionTile(
                      icon: Icons.logout_rounded,
                      title: _signingOut ? 'Đang đăng xuất…' : 'Đăng xuất',
                      subtitle: 'Kết thúc phiên trên tất cả thiết bị',
                      destructive: true,
                      onTap: _signingOut ? null : _signOut,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Center(
                    child: Text(
                      'TEAMUP  /  CÙNG NHAU TẠO GIÁ TRỊ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFEFECF7), Color(0xFFF8F7FA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
    ),
    padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Hồ sơ cá nhân',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(width: 12),
            Icon(Icons.spa_outlined, color: AppColors.darkPurple, size: 23),
          ],
        ),
        const SizedBox(height: 28),
        const UserAvatar(large: true),
        const SizedBox(height: 18),
        Text(
          user.name.isEmpty ? user.username : user.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 27,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _Tag(
          user.major.isEmpty ? 'Chưa thêm chuyên môn' : user.major,
          color: const Color(0xFFEFECF7),
          textColor: const Color(0xFF4D4379),
        ),
        const SizedBox(height: 13),
        const Text(
          'Mỗi đóng góp nhỏ, cùng tạo điều lớn.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final UserProject project;
  @override
  Widget build(BuildContext context) {
    final completed = [
      'hoàn thành',
      'completed',
      'done',
    ].contains(project.status.trim().toLowerCase());
    final label = completed
        ? 'Hoàn thành'
        : project.status.toLowerCase() == 'in_progress' ||
              project.status.toLowerCase() == 'active'
        ? 'Đang thực hiện'
        : project.status;
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: completed
                    ? const Color(0xFFECE7F3)
                    : const Color(0xFFEFECF7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.folder_outlined,
                color: completed
                    ? const Color(0xFF867CB3)
                    : AppColors.darkPurple,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _Tag(
                        project.role,
                        color: const Color(0xFFEEE9F7),
                        textColor: const Color(0xFF78638F),
                      ),
                      _Tag(
                        label,
                        color: completed
                            ? const Color(0xFFE6F2E8)
                            : const Color(0xFFFFF0D5),
                        textColor: completed
                            ? AppColors.darkPurple
                            : const Color(0xFF9A7840),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    project.specificTask ?? 'Chưa có mô tả nhiệm vụ cụ thể.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {required this.color, required this.textColor});
  final String label;
  final Color color, textColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.3,
      ),
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.color = const Color(0xFFFFFFFF)});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.caption});
  final String title;
  final String? caption;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      if (caption != null)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            caption!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
    ],
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.darkPurple),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
    leading: Icon(
      icon,
      color: destructive ? const Color(0xFFD94A4A) : AppColors.darkPurple,
      size: 21,
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: destructive ? const Color(0xFFD94A4A) : AppColors.textPrimary,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    ),
    trailing: Icon(
      Icons.chevron_right_rounded,
      color: destructive ? const Color(0xFFD94A4A) : AppColors.textSecondary,
      size: 19,
    ),
    onTap: onTap,
  );
}
