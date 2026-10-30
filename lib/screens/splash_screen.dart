import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../widgets/brand_logo.dart';

/// Màn hình chờ khi app khôi phục phiên đăng nhập. Không tự điều hướng:
/// [TeamUpApp] quyết định chuyển sang Login hay Main khi `restore()` xong.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandLogo(width: 220, fontSize: 42),
          SizedBox(height: 16),
          Text(
            'Kết nối · Phối hợp · Hoàn thành',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          SizedBox(height: 28),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ],
      ),
    ),
  );
}
