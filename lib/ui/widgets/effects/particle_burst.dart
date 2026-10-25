import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme/motion.dart';

class _Particle {
  _Particle({
    required this.origin,
    required this.size,
    required this.angle,
    required this.distance,
    required this.spin,
    required this.round,
    required this.life,
    required this.born,
  });

  final Offset origin;
  final double size;
  final double angle;
  final double distance;
  final double spin;
  final bool round;
  final Duration life;
  final Duration born;
}

/// Overlay that can burst a handful of particles from any point inside it
/// (the heart "like" burst). Use a [GlobalKey] to call [BurstLayerState.burst].
class BurstLayer extends StatefulWidget {
  const BurstLayer({super.key, required this.color, this.child});

  final Color color;
  final Widget? child;

  @override
  State<BurstLayer> createState() => BurstLayerState();
}

class BurstLayerState extends State<BurstLayer> with SingleTickerProviderStateMixin {
  final _particles = <_Particle>[];
  final _random = math.Random();
  final _clock = Stopwatch()..start();
  final _frame = ValueNotifier<int>(0);
  Ticker? _ticker;

  /// 14 particles from [center] (in this layer's coordinates).
  void burst(Offset center) {
    if (Motion.reduced(context)) return;
    final born = _clock.elapsed;
    for (var i = 0; i < 14; i++) {
      _particles.add(_Particle(
        origin: center,
        size: 6 + _random.nextDouble() * 9,
        angle: i / 14 * math.pi * 2 + _random.nextDouble() * .5,
        distance: 50 + _random.nextDouble() * 80,
        spin: _random.nextDouble() * math.pi * 2,
        round: _random.nextBool(),
        life: Duration(milliseconds: 700 + _random.nextInt(300)),
        born: born,
      ));
    }
    _ticker ??= createTicker(_onTick);
    if (!_ticker!.isActive) _ticker!.start();
  }

  void _onTick(Duration _) {
    final now = _clock.elapsed;
    _particles.removeWhere((p) => now - p.born > p.life);
    _frame.value++;
    if (_particles.isEmpty) _ticker?.stop();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.child != null) widget.child!,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _BurstPainter(_particles, _clock, _frame, widget.color)),
          ),
        ),
      ],
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.particles, this.clock, ValueNotifier<int> frame, this.color) : super(repaint: frame);

  final List<_Particle> particles;
  final Stopwatch clock;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final now = clock.elapsed;
    for (final p in particles) {
      final t = ((now - p.born).inMicroseconds / p.life.inMicroseconds).clamp(0.0, 1.0);
      final e = Motion.emphasized.transform(t);
      final scale = 1 - e;
      if (scale <= 0) continue;
      final c = p.origin + Offset(math.cos(p.angle), math.sin(p.angle)) * p.distance * e;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(p.spin * e);
      final paint = Paint()..color = color.withValues(alpha: 1 - t);
      final s = p.size * scale;
      if (p.round) {
        canvas.drawCircle(Offset.zero, s / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s, height: s), Radius.circular(s * .28)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.color != color;
}
