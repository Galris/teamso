import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'app_frame.dart';
import 'brand_logo.dart';

/// Bố cục chung cho đăng nhập / đăng ký / đổi mật khẩu để ba màn hình
/// có cùng khoảng cách, logo, tiêu đề và kiểu thông báo.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
    this.backEnabled = true,
    this.showLogo = true,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;
  final bool backEnabled;
  final bool showLogo;

  @override
  Widget build(BuildContext context) => AppFrame(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Quay lại',
                onPressed: backEnabled ? () => Navigator.maybePop(context) : null,
                icon: const Icon(Icons.arrow_back),
              ),
            )
          else
            const SizedBox(height: 28),
          if (showLogo) ...[
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: BrandLogo(),
            ),
            const SizedBox(height: 28),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 28),
          ...children,
        ],
      ),
    ),
  );
}

/// Thông báo lỗi/thành công nằm trong form, cùng một kiểu ở mọi màn auth.
class FormMessage extends StatelessWidget {
  const FormMessage(this.text, {super.key, this.isError = true});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.green;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
