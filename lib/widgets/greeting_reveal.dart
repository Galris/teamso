import 'package:flutter/material.dart';

/// A single entrance and highlight sweep; no repeating motion while reading.
class GreetingReveal extends StatefulWidget {
  const GreetingReveal({super.key, required this.child});
  final Widget child;
  @override
  State<GreetingReveal> createState() => _GreetingRevealState();
}

class _GreetingRevealState extends State<GreetingReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final entrance = Curves.easeOutCubic.transform(
        (_controller.value / .45).clamp(0.0, 1.0),
      );
      final sweep = ((_controller.value - .3) / .7).clamp(0.0, 1.0);
      return Opacity(
        opacity: entrance,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - entrance)),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              child!,
              if (sweep > 0 && sweep < 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Transform.translate(
                            offset: Offset(
                              (constraints.maxWidth + 140) * sweep - 140,
                              0,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 110,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: .55),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
