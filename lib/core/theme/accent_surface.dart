import 'package:flutter/material.dart';

/// A shared leading accent painted inside the rounded surface without changing
/// its layout, hit testing, or existing outline.
class AccentBoxDecoration extends BoxDecoration {
  const AccentBoxDecoration({
    this.accent = const Color(0xFF8878B7),
    super.color,
    super.gradient,
    super.borderRadius,
    super.border,
    super.boxShadow,
  });
  final Color accent;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _AccentPainter(this, super.createBoxPainter(onChanged), onChanged);
}

class _AccentPainter extends BoxPainter {
  _AccentPainter(this.decoration, this.base, super.onChanged);
  final AccentBoxDecoration decoration;
  final BoxPainter base;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    base.paint(canvas, offset, configuration);
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    final radius =
        decoration.borderRadius?.resolve(configuration.textDirection) ??
        BorderRadius.zero;
    canvas.save();
    canvas.clipRRect(radius.toRRect(rect));
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, 4, rect.height),
      Paint()..color = decoration.accent,
    );
    canvas.restore();
  }

  @override
  void dispose() {
    base.dispose();
    super.dispose();
  }
}

/// Equivalent treatment for Material/Card surfaces and their ink effects.
class AccentCardBorder extends RoundedRectangleBorder {
  const AccentCardBorder({
    this.accent = const Color(0xFF8878B7),
    super.side,
    super.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });
  final Color accent;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    super.paint(canvas, rect, textDirection: textDirection);
    canvas.save();
    canvas.clipPath(getOuterPath(rect, textDirection: textDirection));
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, 4, rect.height),
      Paint()..color = accent,
    );
    canvas.restore();
  }
}
