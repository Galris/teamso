import 'package:flutter/material.dart';

/// Bảng màu duy nhất của TeamUp. Mọi màn hình phải lấy màu từ đây
/// (hoặc từ `Theme.of(context).colorScheme`), không tự khai báo lại.
abstract final class AppColors {
  // Thương hiệu
  static const green = Color(0xFF439751);
  static const purple = Color(0xFF867CB3);
  static const pink = Color(0xFFF472B6);
  static const yellow = Color(0xFFFACC15);
  static const darkPurple = Color(0xFF4D4379);

  // Nền & bề mặt
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const pageBackground = Color(0xFFF8F7FA);
  static const inputBackground = Color(0xFFF8F7FA);
  static const softPurple = Color(0xFFEFECF7);

  // Viền & chữ
  static const border = Color(0xFFE8E6ED);
  static const textPrimary = Color(0xFF252331);
  static const textSecondary = Color(0xFF777482);

  // Trạng thái
  static const error = Color(0xFFD94A4A);
}
