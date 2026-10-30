import 'package:flutter/material.dart';

/// Khung màn hình chung: căn giữa, giới hạn chiều rộng, tôn trọng SafeArea.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});
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
