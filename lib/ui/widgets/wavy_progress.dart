import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wavy progress: a sine path over the played portion, a flat track for the
/// rest, and a vertical pill handle. Static in milestone 1; [phase],
/// [amplitude] and [dragging] are the hooks for the animated version.
class WavyProgress extends StatelessWidget {
  const WavyProgress({
    super.key,
    required this.value,
    this.amplitude = 3,
    this.wavelength = 18,
    this.strokeWidth = 4,
    this.padding = 2,
    this.phase = 0,
    this.dragging = false,
  });

  final double value;
  final double amplitude;
  final double wavelength;
  final double strokeWidth;
  final double padding;
  final double phase;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _WavyPainter(
          value: value.clamp(0.0, 1.0),
          amplitude: amplitude,
          wavelength: wavelength,
          strokeWidth: strokeWidth,
          padding: padding,
          phase: phase,
          dragging: dragging,
          played: scheme.primary,
          track: scheme.secondaryContainer,
        ),
      ),
    );
  }
}

class _WavyPainter extends CustomPainter {
  _WavyPainter({
    required this.value,
    required this.amplitude,
    required this.wavelength,
    required this.strokeWidth,
    required this.padding,
    required this.phase,
    required this.dragging,
    required this.played,
    required this.track,
  });

  final double value;
  final double amplitude;
  final double wavelength;
  final double strokeWidth;
  final double padding;
  final double phase;
  final bool dragging;
  final Color played;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final x0 = padding;
    final x1 = size.width - padding;
    final cy = size.height / 2;
    final xp = x0 + (x1 - x0) * value;

    // Played portion: sine path stopping short of the handle.
    final wave = Path()..moveTo(x0, cy);
    for (var x = x0; x <= math.max(x0, xp - 6); x += 3) {
      final y = cy + amplitude * math.sin(2 * math.pi * (x - x0) / wavelength - phase);
      wave.lineTo(x, y);
    }
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = played,
    );

    // Handle.
    final hw = dragging ? 2.5 : 4.0;
    final hh = math.min(13.0, size.height * .32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(xp - hw / 2, cy - hh, hw, hh * 2), Radius.circular(hw / 2)),
      Paint()..color = played,
    );

    // Remaining track and end dot.
    final gap = strokeWidth * 1.3;
    final trackLeft = xp + gap;
    if (x1 > trackLeft) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(trackLeft, cy - strokeWidth / 2, x1, cy + strokeWidth / 2),
          Radius.circular(strokeWidth / 2),
        ),
        Paint()..color = track,
      );
    }
    canvas.drawCircle(Offset(x1 - 3, cy), 2, Paint()..color = played);
  }

  @override
  bool shouldRepaint(_WavyPainter old) =>
      old.value != value ||
      old.amplitude != amplitude ||
      old.wavelength != wavelength ||
      old.strokeWidth != strokeWidth ||
      old.padding != padding ||
      old.phase != phase ||
      old.dragging != dragging ||
      old.played != played ||
      old.track != track;
}
