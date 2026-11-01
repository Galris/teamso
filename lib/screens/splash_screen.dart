import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, value, child) => Opacity(
                opacity: value.clamp(0, 1).toDouble(),
                child: Transform.scale(scale: value, child: child),
              ),
              child: Image.asset(
                'assets/images/app_logo_text.png',
                width: 260,
                errorBuilder: (_, _, _) => const Text(
                  'TeamUp',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkPurple,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            if (message != null) ...[
              const SizedBox(height: 14),
              Text(
                message!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
