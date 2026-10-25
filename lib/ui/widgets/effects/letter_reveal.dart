import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';

/// One glyph row. `pop` is 1 when the letter is fully in place and 0 when it
/// is fully "out" (dropped .65em, tilted 10°); it may overshoot while a
/// spring settles. `opacity` is separate so exits can fade across their
/// whole length.
Widget _letterRow(
  List<String> chars,
  TextStyle? style,
  double em,
  ({double pop, double opacity}) Function(int i) state,
) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    textBaseline: TextBaseline.alphabetic,
    children: [
      for (var i = 0; i < chars.length; i++)
        () {
          final (:pop, :opacity) = state(i);
          final p = pop;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(0, .65 * em * (1 - p), 0)..rotateZ(.1745 * (1 - p)),
              child: Text(chars[i], style: style, softWrap: false),
            ),
          );
        }(),
    ],
  );
}

double _emOf(BuildContext context, TextStyle? style) =>
    style?.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14;

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
    final em = _emOf(context, widget.style);
    final chars = widget.text.characters.toList();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final elapsed = _c.value * _total.inMicroseconds / 1000;
        return _letterRow(chars, widget.style, em, (i) {
          final start = (widget.delay + widget.stagger * i).inMicroseconds / 1000;
          final t = ((elapsed - start) / (_per.inMicroseconds / 1000)).clamp(0.0, 1.0);
          final s = Motion.spring.transform(t);
          return (pop: s, opacity: s);
        });
      },
    );
  }
}

/// Text that changes with the same letter animation in both directions: the
/// old text pops out (the pop-in played in reverse, left to right) and then
/// the new text pops in, so a track change flows instead of jumping.
class LetterSwap extends StatefulWidget {
  const LetterSwap({
    super.key,
    required this.text,
    required this.style,
    this.outStagger = const Duration(milliseconds: 12),
    this.inStagger = const Duration(milliseconds: 26),
  });

  final String text;
  final TextStyle? style;
  final Duration outStagger;
  final Duration inStagger;

  @override
  State<LetterSwap> createState() => _LetterSwapState();
}

enum _Phase { entering, exiting }

class _LetterSwapState extends State<LetterSwap> with SingleTickerProviderStateMixin {
  static const _inPer = Duration(milliseconds: 720);
  static const _outPer = Duration(milliseconds: 380);

  late final AnimationController _c = AnimationController(vsync: this);
  late String _shown = widget.text;
  _Phase _phase = _Phase.entering;
  bool _reduced = false;
  bool _started = false;

  Duration _enterTotal(String s) => widget.inStagger * (s.length - 1).clamp(0, 1000) + _inPer;
  Duration _exitTotal(String s) => widget.outStagger * (s.length - 1).clamp(0, 1000) + _outPer;

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
    if (_reduced) return Text(_shown, style: widget.style, maxLines: 1, softWrap: false);
    final em = _emOf(context, widget.style);
    final chars = _shown.characters.toList();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final exiting = _phase == _Phase.exiting;
        final total = exiting ? _exitTotal(_shown) : _enterTotal(_shown);
        final elapsed = _c.value * total.inMicroseconds / 1000;
        final stagger = exiting ? widget.outStagger : widget.inStagger;
        final per = (exiting ? _outPer : _inPer).inMicroseconds / 1000;
        return _letterRow(chars, widget.style, em, (i) {
          final start = (stagger * i).inMicroseconds / 1000;
          final t = ((elapsed - start) / per).clamp(0.0, 1.0);
          if (!exiting) {
            final s = Motion.spring.transform(t);
            return (pop: s, opacity: s);
          }
          // Exit plays the pop-in motion backwards (same path, 1 → 0) while
          // fading steadily over the whole exit.
          return (pop: Motion.spring.transform(1 - t), opacity: 1 - Curves.easeIn.transform(t));
        });
      },
    );
  }
}
