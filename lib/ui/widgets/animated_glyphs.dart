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

enum GlyphKind { list, cards, sort, filter, next, previous, shuffle, menu, repeat, repeatOne, lyrics, queue, back, search, close, collapse, visualizer }

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
      case GlyphKind.repeat:
        _repeat(canvas, line, one: false);
      case GlyphKind.repeatOne:
        _repeat(canvas, line, one: true);
      case GlyphKind.lyrics:
        // A speech bubble whose two lines type themselves in.
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 4, 18, 13), const Radius.circular(3.5)), line);
        canvas.drawPath(
          Path()
            ..moveTo(8, 17)
            ..lineTo(8, 21)
            ..lineTo(12, 17),
          line,
        );
        final typed = _running ? [Curves.easeOut.transform((t / .5).clamp(0.0, 1.0)), Curves.easeOut.transform(((t - .25) / .5).clamp(0.0, 1.0))] : [1.0, 1.0];
        canvas.drawLine(const Offset(7, 9), Offset(7 + 10 * typed[0], 9), line);
        canvas.drawLine(const Offset(7, 13), Offset(7 + 6 * typed[1], 13), line);
      case GlyphKind.queue:
        // Lines pull in one after another while the note bobs.
        const lengths = [11.0, 11.0, 6.0];
        for (var i = 0; i < 3; i++) {
          final y = 6.0 + i * 5;
          canvas.drawLine(Offset(3, y), Offset(3 + lengths[i] * (1 - .55 * _bump(i * .12)), y), line);
        }
        final bob = -3.0 * _bump(.1, .7);
        canvas.drawCircle(Offset(17.5, 17.5 + bob), 2.5, line);
        canvas.drawLine(Offset(20, 17.5 + bob), Offset(20, 6 + bob), line);
      case GlyphKind.back:
        final nudge = -3.5 * _bump(0, .7);
        canvas.drawLine(Offset(20 + nudge * .4, 12), Offset(5 + nudge, 12), line);
        canvas.drawPath(
          Path()
            ..moveTo(11 + nudge, 6)
            ..lineTo(5 + nudge, 12)
            ..lineTo(11 + nudge, 18),
          line,
        );
      case GlyphKind.search:
        // The lens roams in a small circle, as if looking around.
        final swing = _running ? math.sin(math.pi * t) : 0.0;
        final a = t * 2 * math.pi * 1.2;
        final o = Offset(2.2 * math.cos(a), 2.2 * math.sin(a)) * swing;
        canvas.drawCircle(const Offset(10.5, 10.5) + o, 6.5, line);
        canvas.drawLine(const Offset(15.5, 15.5) + o, const Offset(21, 21) + o * .6, line);
      case GlyphKind.close:
        // A turn of 90 degrees; the cross looks the same at the end.
        canvas.translate(12, 12);
        canvas.rotate(_running ? math.pi / 2 * Curves.easeInOutBack.transform(t) : 0);
        canvas.drawLine(const Offset(-6.5, -6.5), const Offset(6.5, 6.5), line);
        canvas.drawLine(const Offset(6.5, -6.5), const Offset(-6.5, 6.5), line);
      case GlyphKind.collapse:
        // Two corner arrows squeeze toward the middle and let go.
        final d = 2.6 * _bump(0, .7);
        canvas.drawLine(Offset(3 + d, 3 + d), Offset(10 + d, 10 + d), line);
        canvas.drawPath(
          Path()
            ..moveTo(10 + d, 5.5 + d)
            ..lineTo(10 + d, 10 + d)
            ..lineTo(5.5 + d, 10 + d),
          line,
        );
        canvas.drawLine(Offset(21 - d, 21 - d), Offset(14 - d, 14 - d), line);
        canvas.drawPath(
          Path()
            ..moveTo(14 - d, 18.5 - d)
            ..lineTo(14 - d, 14 - d)
            ..lineTo(18.5 - d, 14 - d),
          line,
        );
      case GlyphKind.visualizer:
        // A little equalizer: four bars that dance, each on its own beat.
        const base = [9.0, 15.0, 11.0, 6.0];
        for (var i = 0; i < 4; i++) {
          final dance = _running ? math.sin(t * 2 * math.pi * (1.5 + i * .35) + i) * math.sin(math.pi * t) : 0.0;
          final h = (base[i] * (1 + .55 * dance)).clamp(3.0, 20.0);
          final x = 4.5 + i * 5;
          canvas.drawLine(Offset(x, 20), Offset(x, 20 - h), line..strokeWidth = 2.6);
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

  /// Draws [path] up to the fraction [p] of its total length, across contours.
  void _trace(Canvas canvas, Path path, double p, Paint paint) {
    final metrics = path.computeMetrics().toList();
    var left = metrics.fold<double>(0, (a, m) => a + m.length) * p;
    for (final m in metrics) {
      if (left <= 0) break;
      canvas.drawPath(m.extractPath(0, math.min(left, m.length)), paint);
      left -= m.length;
    }
  }

  /// Straight-line shuffle: one line runs corner to corner with a gap where the
  /// other crosses it; both end in arrowheads. They draw on, then the heads pop.
  void _shuffle(Canvas canvas, Paint line) {
    final down = Path()
      ..moveTo(4, 4)
      ..lineTo(9.5, 9.5)
      ..moveTo(14, 14)
      ..lineTo(20, 20);
    final up = Path()
      ..moveTo(4, 20)
      ..lineTo(20, 4);
    for (final (i, path) in [down, up].indexed) {
      final p = _running ? Curves.easeInOut.transform(((t - i * .12) / .7).clamp(0.0, 1.0)) : 1.0;
      _trace(canvas, path, p, line);
      final head = _running ? ((p - .75) / .25).clamp(0.0, 1.0) : 1.0;
      if (head > 0) {
        final h = Paint.from(line)..color = color.withValues(alpha: head);
        final tip = i == 0 ? const Offset(20, 20) : const Offset(20, 4);
        final dy = i == 0 ? -5.0 : 5.0;
        canvas.drawLine(tip, tip + Offset(0, dy), h);
        canvas.drawLine(tip, tip + const Offset(-5, 0), h);
      }
    }
  }

  /// Two rounded arrow loops. The loop is symmetric under a half turn, so it
  /// spins 180 degrees and lands looking the same; the "1" stays put.
  void _repeat(Canvas canvas, Paint line, {required bool one}) {
    canvas.save();
    canvas.translate(12, 12);
    canvas.rotate(_running ? math.pi * Curves.easeInOutCubic.transform(t) : 0);
    canvas.translate(-12, -12);
    canvas.drawPath(
      Path()
        ..moveTo(4, 12)
        ..lineTo(4, 11)
        ..arcToPoint(const Offset(8, 7), radius: const Radius.circular(4))
        ..lineTo(20, 7)
        ..moveTo(17, 4)
        ..lineTo(20, 7)
        ..lineTo(17, 10),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(20, 12)
        ..lineTo(20, 13)
        ..arcToPoint(const Offset(16, 17), radius: const Radius.circular(4))
        ..lineTo(4, 17)
        ..moveTo(7, 14)
        ..lineTo(4, 17)
        ..lineTo(7, 20),
      line,
    );
    canvas.restore();
    if (one) {
      canvas.drawPath(
        Path()
          ..moveTo(10.5, 10.5)
          ..lineTo(12.5, 9)
          ..lineTo(12.5, 15),
        line..strokeWidth = 1.8,
      );
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
