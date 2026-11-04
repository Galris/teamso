import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/accent_surface.dart';

/// Chuỗi nhúng vào QR. `JoinProjectScreen.extractJoinCode` lấy đoạn cuối
/// của đường dẫn nên quét ra là tham gia được ngay.
String projectJoinPayload(String joinCode) => 'teamup://join/$joinCode';

/// Hiện mã QR tham gia dự án để thành viên khác quét.
Future<void> showProjectQrSheet(
  BuildContext context, {
  required String projectName,
  required String joinCode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF7F4FC),
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              projectName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.darkPurple,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Quét mã QR này để tham gia dự án',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AccentBoxDecoration(
                accent: AppColors.purple,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE5E5FB), Color(0xFFF4E8F5)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: projectJoinPayload(joinCode),
                  size: 220,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.circle,
                    color: AppColors.darkPurple,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: AppColors.darkPurple,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SelectableText(
              joinCode,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: AppColors.darkPurple,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: joinCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép mã tham gia.')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Sao chép mã'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
