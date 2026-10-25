import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';

/// Pointer ripple that expands from the touch point (demo: 650 ms, alpha .24).
/// Doesn't take part in gestures. Put it inside something that already clips
/// to the right shape (`AnimatedContainer(clipBehavior: ...)`, `MorphShape`).
class Ripple extends StatefulWidget {
  const Ripple({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  State<Ripple> createState() => _RippleState();
}

class _Drop {
  _Drop(this.center, this.radius, this.controller);
  final Offset center;
  final double radius;
  final AnimationController controller;
}

class _RippleState extends State<Ripple> with TickerProviderStateMixin {
  final _drops = <_Drop>[];

  void _add(PointerDownEvent e) {
    if (Motion.reduced(context)) return;
    final size = context.size;
    if (size == null) return;
    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    final drop = _Drop(e.localPosition, math.max(size.width, size.height) * 1.2, controller);
    setState(() => _drops.add(drop));
    controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _drops.remove(drop));
      controller.dispose();
    });
  }

  @override
  void dispose() {
    for (final d in _drops) {
      d.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _add,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_drops.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RipplePainter(List.of(_drops), widget.color),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.drops, this.color) : super(repaint: Listenable.merge([for (final d in drops) d.controller]));

  final List<_Drop> drops;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in drops) {
      final t = Motion.standard.transform(d.controller.value);
      canvas.drawCircle(d.center, d.radius * t, Paint()..color = color.withValues(alpha: .24 * (1 - t)));
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => true;
}
