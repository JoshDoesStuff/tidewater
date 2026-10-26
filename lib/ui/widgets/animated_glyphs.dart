import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../app/providers/settings_providers.dart';
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

enum GlyphKind { list, cards, sort, filter, next, previous, shuffle, menu, repeat, repeatOne, lyrics, queue, back, search, close, collapse, visualizer, aurora, shapes, ring, off, minimize, maximize, restore, more, eye, eyeOff }

/// A small 24 x 24 stroke icon drawn in code, with its own one-shot motion:
/// list rows retract and return, card tiles pop in a wave, sort bars retract
/// lengths pulling in, the filter bars pinch toward the middle, skip arrows
/// shoot off and return, shuffle's two arrows trace across each other and the
/// menu bars shift in a wave.
class AnimatedGlyph extends ConsumerStatefulWidget {
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
  ConsumerState<AnimatedGlyph> createState() => _AnimatedGlyphState();
}

class _AnimatedGlyphState extends ConsumerState<AnimatedGlyph> with SingleTickerProviderStateMixin, _PlayOnEdge {
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
        painter: _GlyphPainter(widget.kind, controller.value, widget.color, ghost: ref.watch(iconGhostProvider)),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.kind, this.t, this.color, {required this.ghost});

  /// Keep a faint copy of the icon under a redraw (a Settings option).
  final bool ghost;

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
      case GlyphKind.aurora:
        // A soft cluster of dots that breathes outward from the middle.
        final fill = Paint()..color = color;
        final breath = _running ? math.sin(math.pi * t) : 0.0;
        canvas.drawCircle(const Offset(12, 12), 1.5 + .5 * breath, fill);
        for (final (ring, count, radius) in const [(1, 6, 5.0), (2, 12, 9.0)]) {
          final lag = _bump((ring - 1) * .16, .7);
          for (var i = 0; i < count; i++) {
            final a = 2 * math.pi * i / count + ring * .4;
            final r = radius * (1 + .22 * lag);
            canvas.drawCircle(
              Offset(12 + r * math.cos(a), 12 + r * math.sin(a)),
              (ring == 1 ? 1.25 : 1.0) + .3 * lag,
              fill,
            );
          }
        }
      case GlyphKind.shapes:
        // A star that turns one point and pops; five-fold symmetry hides the seam.
        canvas.translate(12, 12);
        canvas.rotate(_running ? 2 * math.pi / 5 * Curves.easeOutBack.transform(t) : 0);
        final pop = 1 + .2 * _bump(0, .7);
        canvas.scale(pop);
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? 9.5 : 4.2;
          final a = -math.pi / 2 + i * math.pi / 5;
          final p = Offset(r * math.cos(a), r * math.sin(a));
          i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(star..close(), line);
      case GlyphKind.ring:
        // A circle with rays that stretch outward in a wave, turning one ray.
        canvas.translate(12, 12);
        canvas.rotate(_running ? math.pi / 4 * Curves.easeInOut.transform(t) : 0);
        canvas.drawCircle(Offset.zero, 4.5, line);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final reach = 1 + .5 * _bump(i * .06, .6);
          canvas.drawLine(
            Offset(7.5 * math.cos(a), 7.5 * math.sin(a)),
            Offset(7.5 * reach * math.cos(a) + 2 * math.cos(a), 7.5 * reach * math.sin(a) + 2 * math.sin(a)),
            line,
          );
        }
      case GlyphKind.off:
        // The circle traces itself, then the slash cuts through.
        final circle = Path()..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5));
        final slash = Path()
          ..moveTo(6, 6)
          ..lineTo(18, 18);
        if (_running) {
          // A faint copy stays put so the icon never vanishes while it redraws.
          _ghost(canvas, circle, line);
          _ghost(canvas, slash, line);
          _trace(canvas, circle, _redraw(t / .75), line);
          _trace(canvas, slash, _redraw((t - .15) / .85), line);
        } else {
          canvas.drawPath(circle, line);
          canvas.drawPath(slash, line);
        }
      case GlyphKind.minimize:
        // The bar dips toward the taskbar and comes back.
        final dip = 3.5 * _bump(0, .7);
        canvas.drawLine(Offset(6, 12 + dip), Offset(18, 12 + dip), line);
      case GlyphKind.maximize:
        // The square swells, then settles.
        canvas.translate(12, 12);
        canvas.scale(1 + .22 * _bump(0, .7));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 13, height: 13), const Radius.circular(2)), line);
      case GlyphKind.restore:
        // The front window slides back into the corner and out again.
        final slide = 2.2 * _bump(0, .7);
        canvas.drawPath(
          Path()
            ..moveTo(9, 5 - slide)
            ..lineTo(19, 5 - slide)
            ..lineTo(19, 15 - slide)
            ..lineTo(15.5, 15 - slide),
          line,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(5 - slide * .5, 9 + slide * .5, 10, 10), const Radius.circular(2)),
          line,
        );
      case GlyphKind.more:
        // Three dots swell one after another.
        final fill = Paint()..color = color;
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(12, 5.5 + i * 6.5), 1.8 * (1 + .45 * _bump(i * .14, .6)), fill);
        }
      case GlyphKind.eye:
      case GlyphKind.eyeOff:
        // A blink: the eye closes and opens again.
        canvas.translate(12, 12);
        canvas.scale(1, 1 - .9 * math.pow(_bump(0, .8), 2));
        canvas.translate(-12, -12);
        canvas.drawPath(
          Path()
            ..moveTo(2, 12)
            ..cubicTo(5, 6.5, 8.5, 5, 12, 5)
            ..cubicTo(15.5, 5, 19, 6.5, 22, 12)
            ..cubicTo(19, 17.5, 15.5, 19, 12, 19)
            ..cubicTo(8.5, 19, 5, 17.5, 2, 12)
            ..close(),
          line,
        );
        canvas.drawCircle(const Offset(12, 12), 3, line);
        if (kind == GlyphKind.eyeOff) {
          canvas.drawLine(const Offset(4, 4), const Offset(20, 20), line);
        }
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

  /// How much of a traced outline is showing at [u] (0 to 1): it first erases
  /// back toward its start, then draws on again, ending complete.
  static double _redraw(double u) {
    final x = u.clamp(0.0, 1.0);
    return x < .3 ? 1 - Curves.easeIn.transform(x / .3) : Curves.easeOut.transform((x - .3) / .7);
  }

  /// [path] at low strength: the resting shape kept visible under a trace-on.
  void _ghost(Canvas canvas, Path path, Paint line) {
    if (!ghost) return;
    canvas.drawPath(path, Paint.from(line)..color = color.withValues(alpha: .3));
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
    if (_running) {
      _ghost(canvas, down, line);
      _ghost(canvas, up, line);
      for (final tip in const [Offset(20, 20), Offset(20, 4)]) {
        final dy = tip.dy > 10 ? -5.0 : 5.0;
        _ghost(canvas, Path()..moveTo(tip.dx, tip.dy + dy)..lineTo(tip.dx, tip.dy)..lineTo(tip.dx - 5, tip.dy), line);
      }
    }
    for (final (i, path) in [down, up].indexed) {
      final p = _running ? _redraw((t - i * .12) / .8) : 1.0;
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

  /// Two rounded arrow loops that draw themselves on, one after the other,
  /// with their arrowheads popping at the end. Repeat-one adds a small "1"
  /// between the loops, which fades in last.
  void _repeat(Canvas canvas, Paint line, {required bool one}) {
    final top = Path()
      ..moveTo(4, 11)
      ..lineTo(4, 9)
      ..arcToPoint(const Offset(7.5, 5.5), radius: const Radius.circular(3.5))
      ..lineTo(20, 5.5);
    final bottom = Path()
      ..moveTo(20, 13)
      ..lineTo(20, 15)
      ..arcToPoint(const Offset(16.5, 18.5), radius: const Radius.circular(3.5))
      ..lineTo(4, 18.5);
    final heads = [
      (Offset(20, 5.5), const [Offset(-3, -3), Offset(-3, 3)]),
      (Offset(4, 18.5), const [Offset(3, -3), Offset(3, 3)]),
    ];
    if (_running) {
      _ghost(canvas, top, line);
      _ghost(canvas, bottom, line);
      _ghost(canvas, Path()..moveTo(17, 2.5)..lineTo(20, 5.5)..lineTo(17, 8.5), line);
      _ghost(canvas, Path()..moveTo(7, 15.5)..lineTo(4, 18.5)..lineTo(7, 21.5), line);
    }
    for (final (i, path) in [top, bottom].indexed) {
      final p = _running ? _redraw((t - i * .14) / .78) : 1.0;
      _trace(canvas, path, p, line);
      final head = _running ? ((p - .7) / .3).clamp(0.0, 1.0) : 1.0;
      if (head > 0) {
        final h = Paint.from(line)..color = color.withValues(alpha: head);
        final (tip, arms) = heads[i];
        for (final arm in arms) {
          canvas.drawLine(tip, tip + arm, h);
        }
      }
    }
    if (one) {
      final fade = _running ? ((_redraw(t / .9) - .5) / .5).clamp(0.0, 1.0) : 1.0;
      canvas.drawPath(
        Path()
          ..moveTo(10.6, 10.6)
          ..lineTo(12.4, 9.3)
          ..lineTo(12.4, 14.7),
        Paint.from(line)
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.kind != kind || old.t != t || old.color != color || old.ghost != ghost;
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

/// The cast button's icon: UseAnimations' "cast", waving when clicked.
Widget castGlyph(BuildContext context, Color color, bool hovered, bool pressed) =>
    LottieGlyph(asset: 'assets/icons/cast.json', color: color, active: pressed);

/// Builds a [GlyphKind] for an icon button: it plays on each click, and also
/// when the pointer enters if [hover] is set.
Widget Function(BuildContext, Color, bool, bool) glyphFor(GlyphKind kind, {double size = 22, bool hover = false}) =>
    (context, color, hovered, pressed) =>
        AnimatedGlyph(kind: kind, color: color, size: size, hovered: hover && hovered, active: pressed);

/// The volume speaker: UseAnimations' "volume" file scrubbed between its
/// states. At [level] 0 (loud) the waves are out, at 1 (quiet) one wave has
/// folded away, at 2 (muted) both are gone and the slash is drawn.
class VolumeGlyph extends StatefulWidget {
  const VolumeGlyph({super.key, required this.level, required this.color, this.size = 22});

  final int level;
  final Color color;
  final double size;

  @override
  State<VolumeGlyph> createState() => _VolumeGlyphState();
}

class _VolumeGlyphState extends State<VolumeGlyph> with SingleTickerProviderStateMixin {
  static const _stops = [0.0, .3, 1.0];
  late final AnimationController _c = AnimationController(vsync: this, value: _stops[widget.level]);
  LottieComposition? _composition;

  @override
  void initState() {
    super.initState();
    IconComposition.load('assets/icons/volume.json').then((c) {
      if (mounted) setState(() => _composition = c);
    });
  }

  @override
  void didUpdateWidget(VolumeGlyph old) {
    super.didUpdateWidget(old);
    if (old.level == widget.level) return;
    final target = _stops[widget.level];
    if (Motion.reduced(context)) {
      _c.value = target;
    } else {
      _c.animateTo(target, duration: Motion.of(context, Motion.slow), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.size * 1.3;
    final c = _composition;
    if (c == null) return SizedBox.square(dimension: box);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => ColorFiltered(
        colorFilter: ColorFilter.mode(widget.color, BlendMode.srcATop),
        child: RawLottie(composition: c, progress: _c.value, width: box, height: box, fit: BoxFit.contain),
      ),
    );
  }
}
