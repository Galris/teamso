import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Logo TeamUp dùng chung cho splash, đăng nhập, đăng ký.
/// Nếu chưa có ảnh trong assets thì hiển thị chữ thay thế.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 180, this.fontSize = 38});
  final double width;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/teamup_logo_text.png',
    width: width,
    errorBuilder: (_, _, _) => Text(
      'TeamUp',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: AppColors.darkPurple,
      ),
    ),
  );
}
