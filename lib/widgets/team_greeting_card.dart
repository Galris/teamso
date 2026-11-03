import 'package:flutter/material.dart';

class TeamGreetingCard extends StatelessWidget {
  const TeamGreetingCard({
    super.key,
    required this.dateLabel,
    required this.greeting,
    required this.description,
    required this.night,
  });
  final String dateLabel, greeting, description;
  final bool night;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFAFF), Color(0xFFE9D4FB), Color(0xFFC9A6F0)],
        stops: [0, .58, 1],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: .95), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x49734AA8),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
        BoxShadow(
          color: Color(0x889E6FE4),
          blurRadius: 0,
          offset: Offset(0, 4),
        ),
        BoxShadow(color: Color(0x45FFFFFF), blurRadius: 12, spreadRadius: 1),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            bottom: -2,
            child: CustomPaint(
              size: const Size(125, 52),
              painter: _CloudPainter(),
            ),
          ),
          Positioned(
            right: 10,
            top: 9,
            child: ExcludeSemantics(
              child: CustomPaint(
                size: const Size(86, 76),
                painter: _SkyPainter(night),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 72),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAD8FA),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: Color(0xFF8153B4),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            dateLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .7,
                              color: Color(0xFF8153B4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.7,
                    color: Color(0xFF392052),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF51346D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.night);
  final bool night;
  @override
  void paint(Canvas canvas, Size size) {
    final moonRect = const Rect.fromLTWH(28, 8, 45, 48);
    final shape = Path()..addOval(moonRect);
    final moon = night
        ? Path.combine(
            PathOperation.difference,
            shape,
            Path()..addOval(const Rect.fromLTWH(43, 0, 40, 48)),
          )
        : shape;
    canvas.drawShadow(moon, const Color(0xFF8154B5), 6, false);
    canvas.drawPath(
      moon,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF2AB), Color(0xFFFFD678)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(moonRect),
    );
    for (final point in [
      const Offset(13, 19),
      const Offset(78, 27),
      const Offset(22, 53),
    ]) {
      final star = Path()
        ..moveTo(point.dx, point.dy - 5)
        ..quadraticBezierTo(point.dx + 1, point.dy - 1, point.dx + 5, point.dy)
        ..quadraticBezierTo(point.dx + 1, point.dy + 1, point.dx, point.dy + 5)
        ..quadraticBezierTo(point.dx - 1, point.dy + 1, point.dx - 5, point.dy)
        ..quadraticBezierTo(point.dx - 1, point.dy - 1, point.dx, point.dy - 5);
      canvas.drawPath(star, Paint()..color = const Color(0xFFFFEDAA));
    }
    final cloud = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(43, 50, 40, 17),
          const Radius.circular(9),
        ),
      )
      ..addOval(const Rect.fromLTWH(49, 40, 23, 24))
      ..addOval(const Rect.fromLTWH(64, 45, 18, 18));
    canvas.drawShadow(cloud, const Color(0xFF9A73BC), 4, false);
    canvas.drawPath(
      cloud,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFE7D3F7)],
        ).createShader(const Rect.fromLTWH(43, 40, 40, 27)),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => oldDelegate.night != night;
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(22, 35, 42, 39)
      ..quadraticBezierTo(65, 14, 86, 23)
      ..quadraticBezierTo(102, -4, 125, 2)
      ..lineTo(125, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDF5FF), Color(0xFFE4CBF6)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_CloudPainter oldDelegate) => false;
}
