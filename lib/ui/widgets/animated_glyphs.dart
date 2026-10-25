import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../app/theme/motion.dart';

/// Compositions are parsed once and shared.
abstract final class IconComposition {
  static final _loading = <String, Future<LottieComposition>>{};

  static Future<LottieComposition> load(String asset) => _loading.putIfAbsent(asset, () => AssetLottie(asset).load());
}

/// Plays once on the rising edge of [hovered] or [active] (a hover, a click that
/// selects) and rests on frame 0, which is the whole icon. Reduced motion
/// skips the play.
mixin _PlayOnEdge<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController controller = AnimationController(vsync: this, duration: Motion.slow);

  bool get hovered;
  bool get active;

  void playIfRisen(bool wasHovered, bool wasActive) {
    if (((hovered && !wasHovered) || (active && !wasActive)) && !Motion.reduced(context)) {
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

enum GlyphKind { list, cards, sort, filter, next, previous, shuffle, menu }

/// A small 24 x 24 stroke icon drawn in code, with its own one-shot motion:
/// list rows retract and return, card tiles pop in a wave, sort bars retract
/// lengths pulling in, the filter bars pinch toward the middle, skip arrows
/// shoot off and return, shuffle's two arrows trace across each other and the
/// menu bars shift in a wave.
class AnimatedGlyph extends StatefulWidget {
  const AnimatedGlyph({
    super.key,
    required this.kind,
    required this.color,
    this.size = 22,
    this.hovered = false,
    this.active = false,
  });

  final GlyphKind kind;
  final Color color;
  final double size;
  final bool hovered;
  final bool active;

  @override
  State<AnimatedGlyph> createState() => _AnimatedGlyphState();
}

class _AnimatedGlyphState extends State<AnimatedGlyph> with SingleTickerProviderStateMixin, _PlayOnEdge {
  @override
  bool get hovered => widget.hovered;
  @override
  bool get active => widget.active;

  @override
  void didUpdateWidget(AnimatedGlyph old) {
    super.didUpdateWidget(old);
    playIfRisen(old.hovered, old.active);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _GlyphPainter(widget.kind, controller.value, widget.color),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.kind, this.t, this.color);

  final GlyphKind kind;
  final double t;
  final Color color;

  bool get _running => t > 0 && t < 1;

  /// A 0 to 1 to 0 bump for the slice of the animation starting at [delay].
  double _bump(double delay, [double span = .6]) =>
      _running ? math.sin(math.pi * ((t - delay) / span).clamp(0.0, 1.0)) : 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    switch (kind) {
      case GlyphKind.list:
        for (var i = 0; i < 3; i++) {
          final y = 6.0 + i * 6;
          final dip = _bump(i * .14);
          // The row's line pulls in toward its dot and springs back.
          canvas.drawLine(Offset(9, y), Offset(21 - 9.5 * dip, y), line);
          canvas.drawCircle(Offset(4, y), 1.0 + .5 * dip, Paint()..color = color);
        }
      case GlyphKind.cards:
        // Tiles pop in a clockwise wave: top-left, top-right, bottom-right, bottom-left.
        const origins = [Offset(3, 3), Offset(14, 3), Offset(14, 14), Offset(3, 14)];
        for (var i = 0; i < 4; i++) {
          final grow = 1 + .24 * _bump(i * .15);
          final c = origins[i] + const Offset(3.5, 3.5);
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.scale(grow);
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 7, height: 7), const Radius.circular(1.5)),
            line,
          );
          canvas.restore();
        }
      case GlyphKind.sort:
        // Three bars, long to short, left-aligned; each pulls in toward its
        // start and springs back, top to bottom.
        const lengths = [18.0, 12.0, 6.0];
        for (var i = 0; i < 3; i++) {
          final len = lengths[i] * (1 - .6 * _bump(i * .14));
          final y = 6.0 + i * 6;
          canvas.drawLine(Offset(3, y), Offset(3 + len, y), line);
        }
      case GlyphKind.filter:
        // The classic three centered bars; they pinch toward the middle and
        // spring back, bottom to top, like something being filtered down.
        const lengths = [18.0, 12.0, 6.0];
        for (var i = 0; i < 3; i++) {
          final len = lengths[i] * (1 - .75 * _bump((2 - i) * .14));
          final y = 6.0 + i * 6;
          canvas.drawLine(Offset(12 - len / 2, y), Offset(12 + len / 2, y), line);
        }
      case GlyphKind.next:
        _skip(canvas, line);
      case GlyphKind.previous:
        canvas.translate(24, 0);
        canvas.scale(-1, 1);
        _skip(canvas, line);
      case GlyphKind.shuffle:
        _shuffle(canvas, line);
      case GlyphKind.menu:
        // Three bars slide right and settle back, one after another.
        for (var i = 0; i < 3; i++) {
          final y = 6.0 + i * 6;
          final dx = 4.0 * _bump(i * .14);
          canvas.drawLine(Offset(4 + dx, y), Offset(20 + dx * .5, y), line);
        }
    }
  }

  /// Skip-next: a triangle and a bar. On play the triangle shoots off to the
  /// right and a new one slides in from the left while the bar nudges.
  void _skip(Canvas canvas, Paint line) {
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, 0, 24, 24));
    var dx = 0.0;
    if (_running) {
      dx = t < .5
          ? 16 * Curves.easeIn.transform(t / .5)
          : -16 * (1 - Curves.easeOutBack.transform((t - .5) / .5));
    }
    canvas.translate(dx, 0);
    final tri = Path()
      ..moveTo(5, 5.5)
      ..lineTo(5, 18.5)
      ..lineTo(15, 12)
      ..close();
    final fill = Paint()..color = color;
    canvas.drawPath(tri, fill);
    canvas.drawPath(tri, line);
    canvas.restore();
    final nudge = 1.6 * _bump(.35, .5);
    canvas.drawLine(Offset(19 + nudge, 5.5), Offset(19 + nudge, 18.5), line);
  }

  /// Two arrows crossing left to right, each traced on from its start.
  void _shuffle(Canvas canvas, Paint line) {
    final a = Path()
      ..moveTo(3, 6.5)
      ..cubicTo(9, 6.5, 12, 17.5, 19, 17.5);
    final b = Path()
      ..moveTo(3, 17.5)
      ..cubicTo(9, 17.5, 12, 6.5, 19, 6.5);
    for (final (i, path) in [a, b].indexed) {
      final p = _running ? Curves.easeInOut.transform(((t - i * .12) / .7).clamp(0.0, 1.0)) : 1.0;
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * p), line);
      }
      final y = i == 0 ? 17.5 : 6.5;
      // Arrowhead appears as its line arrives.
      final head = _running ? ((p - .7) / .3).clamp(0.0, 1.0) : 1.0;
      if (head > 0) {
        final h = Paint.from(line)..color = color.withValues(alpha: head);
        final tip = Offset(19.5, y);
        canvas.drawLine(tip + const Offset(-3, -3), tip, h);
        canvas.drawLine(tip + const Offset(-3, 3), tip, h);
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.kind != kind || old.t != t || old.color != color;
}

/// A Lottie icon that rests on its first frame and plays once when hovered
/// or [active]. Tinted to [color] with a filter over the whole drawing.
class LottieGlyph extends StatefulWidget {
  const LottieGlyph({
    super.key,
    required this.asset,
    required this.color,
    this.size = 24,
    this.hovered = false,
    this.active = false,
  });

  final String asset;
  final Color color;
  final double size;
  final bool hovered;
  final bool active;

  @override
  State<LottieGlyph> createState() => _LottieGlyphState();
}

class _LottieGlyphState extends State<LottieGlyph> with SingleTickerProviderStateMixin, _PlayOnEdge {
  LottieComposition? _composition;

  @override
  bool get hovered => widget.hovered;
  @override
  bool get active => widget.active;

  @override
  void initState() {
    super.initState();
    IconComposition.load(widget.asset).then((c) {
      if (!mounted) return;
      controller.duration = c.duration;
      setState(() => _composition = c);
    });
  }

  @override
  void didUpdateWidget(LottieGlyph old) {
    super.didUpdateWidget(old);
    playIfRisen(old.hovered, old.active);
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.size * 1.3;
    final c = _composition;
    if (c == null) return SizedBox.square(dimension: box);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ColorFiltered(
        colorFilter: ColorFilter.mode(widget.color, BlendMode.srcATop),
        child: RawLottie(composition: c, progress: controller.value, width: box, height: box, fit: BoxFit.contain),
      ),
    );
  }
}

/// The cast button's icon: UseAnimations' "cast", waving when hovered.
Widget castGlyph(BuildContext context, Color color, bool hovered, bool pressed) =>
    LottieGlyph(asset: 'assets/icons/cast.json', color: color, hovered: hovered);

/// Builds a [GlyphKind] for an icon button: it plays on hover, or on press
/// when [onPress] (transport buttons that fire an action).
Widget Function(BuildContext, Color, bool, bool) glyphFor(GlyphKind kind, {double size = 22, bool onPress = false}) =>
    (context, color, hovered, pressed) =>
        AnimatedGlyph(kind: kind, color: color, size: size, hovered: !onPress && hovered, active: onPress && pressed);
