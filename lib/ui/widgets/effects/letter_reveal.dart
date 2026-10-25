import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';

/// One animated glyph row.
///
/// Built to stay cheap and steady while it moves:
///  * no `Opacity` layers: the fade is the glyph color's alpha;
///  * one `RepaintBoundary` for the row;
///  * hidden from semantics while it animates, with one stable label for the
///    whole string (per-letter nodes made every frame rebuild the
///    accessibility tree);
///  * letters at rest are plain `Text`, with no transform, and the last
///    sub-pixel tail of a spring is snapped away;
///  * vertical motion is rounded to whole device pixels so glyphs don't shimmer.
///
/// `pop` is 1 when a letter is in place and 0 when fully "out" (dropped .65em,
/// tilted 10°); it may overshoot while a spring settles. `opacity` is
/// separate so exits can fade across their whole length.
Widget _letterRow(
  BuildContext context, {
  required String text,
  required List<String> chars,
  required TextStyle? style,
  required ({double pop, double opacity}) Function(int i) state,
}) {
  final base = style ?? DefaultTextStyle.of(context).style;
  final color = base.color ?? Theme.of(context).colorScheme.onSurface;
  final em = base.fontSize ?? 14;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Semantics(
    label: text,
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (var i = 0; i < chars.length; i++)
              () {
                final (:pop, :opacity) = state(i);
                final alpha = opacity.clamp(0.0, 1.0);
                final glyph = Text(
                  chars[i],
                  softWrap: false,
                  style: base.copyWith(color: alpha >= .999 ? color : color.withValues(alpha: alpha * color.a)),
                );
                // At rest: exactly the plain text, no transform at all.
                if ((1 - pop).abs() < .004 && alpha >= .999) return glyph;
                final dy = (.65 * em * (1 - pop) * dpr).round() / dpr;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.translationValues(0, dy, 0)..rotateZ(.1745 * (1 - pop)),
                  child: glyph,
                );
              }(),
          ],
        ),
      ),
    ),
  );
}

/// Letter-by-letter pop-in: each glyph rises .65em, untilts 10° and fades in
/// on the spring curve, staggered by [stagger]. Plays every time the widget
/// is built (e.g. on each tab change) and restarts when [text] changes. With
/// reduced motion it is plain text.
class LetterReveal extends StatefulWidget {
  const LetterReveal({
    super.key,
    required this.text,
    required this.style,
    this.delay = Duration.zero,
    this.stagger = const Duration(milliseconds: 26),
  });

  final String text;
  final TextStyle? style;
  final Duration delay;
  final Duration stagger;

  @override
  State<LetterReveal> createState() => _LetterRevealState();
}

class _LetterRevealState extends State<LetterReveal> with SingleTickerProviderStateMixin {
  static const _per = Duration(milliseconds: 720);

  late final AnimationController _c = AnimationController(vsync: this);
  bool _reduced = false;

  Duration get _total => widget.delay + widget.stagger * (widget.text.length - 1).clamp(0, 1000) + _per;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.reduced(context);
    if (!_c.isAnimating && _c.value == 0) _restart();
  }

  @override
  void didUpdateWidget(LetterReveal old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _restart();
  }

  void _restart() {
    if (_reduced || widget.text.isEmpty) {
      _c.value = 1;
      return;
    }
    _c.duration = _total;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) return Text(widget.text, style: widget.style, maxLines: 1, softWrap: false);
    final chars = widget.text.characters.toList();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Stays a letter row at rest (never swapped for a plain Text): the two
        // space glyphs slightly differently (kerning) and the title would
        // shift a pixel or two when the animation ends.
        final elapsed = _c.value * _total.inMicroseconds / 1000;
        return _letterRow(
          context,
          text: widget.text,
          chars: chars,
          style: widget.style,
          state: (i) {
            final start = (widget.delay + widget.stagger * i).inMicroseconds / 1000;
            final t = ((elapsed - start) / (_per.inMicroseconds / 1000)).clamp(0.0, 1.0);
            final s = Motion.spring.transform(t);
            return (pop: s, opacity: s);
          },
        );
      },
    );
  }
}

/// Text that changes with a letter animation in both directions: the old text
/// drops away and fades (left to right) and then the new text pops in, so a
/// track change flows instead of jumping.
class LetterSwap extends StatefulWidget {
  const LetterSwap({
    super.key,
    required this.text,
    required this.style,
    this.speed = 1,
  });

  final String text;
  final TextStyle? style;

  /// Pace multiplier (Settings): 2 plays the whole swap twice as fast.
  final double speed;

  @override
  State<LetterSwap> createState() => _LetterSwapState();
}

enum _Phase { entering, exiting }

class _LetterSwapState extends State<LetterSwap> with SingleTickerProviderStateMixin {
  // Base pace at speed 1: snappy exit, then a springy entrance.
  static const _baseInPer = Duration(milliseconds: 520);
  static const _baseOutPer = Duration(milliseconds: 260);
  static const _baseInStagger = Duration(milliseconds: 18);
  static const _baseOutStagger = Duration(milliseconds: 8);

  late final AnimationController _c = AnimationController(vsync: this);
  late String _shown = widget.text;
  _Phase _phase = _Phase.entering;
  bool _reduced = false;
  bool _started = false;

  Duration _scaled(Duration d) => d * (1 / widget.speed.clamp(.1, 10.0));
  Duration get _inPer => _scaled(_baseInPer);
  Duration get _outPer => _scaled(_baseOutPer);
  Duration get _inStagger => _scaled(_baseInStagger);
  Duration get _outStagger => _scaled(_baseOutStagger);

  Duration _enterTotal(String s) => _inStagger * (s.length - 1).clamp(0, 1000) + _inPer;
  Duration _exitTotal(String s) => _outStagger * (s.length - 1).clamp(0, 1000) + _outPer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.reduced(context);
    if (!_started) {
      _started = true;
      _enter();
    }
  }

  @override
  void didUpdateWidget(LetterSwap old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    if (_reduced) {
      setState(() => _shown = widget.text);
      return;
    }
    if (_phase == _Phase.exiting && _c.isAnimating) return; // picks up the latest text when done
    _exit();
  }

  void _enter() {
    _shown = widget.text;
    _phase = _Phase.entering;
    if (_reduced) {
      _c.value = 1;
      return;
    }
    _c.duration = _enterTotal(_shown);
    _c.forward(from: 0);
  }

  void _exit() {
    _phase = _Phase.exiting;
    _c.duration = _exitTotal(_shown);
    _c.forward(from: 0).whenComplete(() {
      if (!mounted || _phase != _Phase.exiting) return;
      setState(_enter);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plain = Text(_shown, style: widget.style, maxLines: 1, softWrap: false);
    if (_reduced) return plain;
    final chars = _shown.characters.toList();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final exiting = _phase == _Phase.exiting;
        final total = exiting ? _exitTotal(_shown) : _enterTotal(_shown);
        final elapsed = _c.value * total.inMicroseconds / 1000;
        final stagger = exiting ? _outStagger : _inStagger;
        final per = (exiting ? _outPer : _inPer).inMicroseconds / 1000;
        return _letterRow(
          context,
          text: _shown,
          chars: chars,
          style: widget.style,
          state: (i) {
            final start = (stagger * i).inMicroseconds / 1000;
            final t = ((elapsed - start) / per).clamp(0.0, 1.0);
            if (!exiting) {
              final s = Motion.spring.transform(t);
              return (pop: s, opacity: s);
            }
            // Exit: a smooth accelerating drop and fade. (The spring played
            // backwards overshoots upward first, which read as a twitch.)
            final e = Curves.easeInCubic.transform(t);
            return (pop: 1 - e, opacity: 1 - Curves.easeIn.transform(t));
          },
        );
      },
    );
  }
}
