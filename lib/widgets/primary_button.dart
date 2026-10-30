import 'package:flutter/material.dart';

/// Nút chính toàn chiều rộng. Màu/bo góc lấy từ [AppTheme].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(onPressed: onPressed, child: Text(label)),
  );
}
