import 'package:flutter/material.dart';

/// Shared sizing and form treatment for all Workspace creation dialogs.
class WorkspaceDialogStyle extends StatelessWidget {
  const WorkspaceDialogStyle({
    super.key,
    required this.accent,
    required this.tint,
    required this.child,
  });
  final Color accent, tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: accent,
          onPrimary: Colors.white,
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: tint,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          titleTextStyle: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: Colors.white,
          floatingLabelStyle: TextStyle(
            color: accent,
            fontWeight: FontWeight.w600,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: border(accent.withValues(alpha: .18)),
          enabledBorder: border(accent.withValues(alpha: .18)),
          focusedBorder: border(accent, 1.5),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(96, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accent,
            minimumSize: const Size(72, 48),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.white,
            selectedBackgroundColor: accent.withValues(alpha: .14),
            selectedForegroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: .18)),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

class WorkspaceDialogTitle extends StatelessWidget {
  const WorkspaceDialogTitle(
    this.title, {
    super.key,
    required this.icon,
    required this.color,
  });
  final String title;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 28),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    ],
  );
}
