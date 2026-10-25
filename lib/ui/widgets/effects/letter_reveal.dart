import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';
import 'glyph_run.dart';

/// Letter-by-letter pop-in, ported from the demo's `revealText`: each glyph
/// rises .65em, untilts 10° and fades in on the spring curve over 720 ms,
/// staggered by [stagger]. Plays every time the widget is built (e.g. on each
/// tab change) and restarts when [text] changes. With reduced motion it is
/// plain text.
///
/// Letters are animated as textures ([GlyphRun]) like a browser does, which
/// is what keeps the motion free of shimmer; see that class for why.
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

  LetterState _letter(int i) {
    final elapsed = _c.value * _total.inMicroseconds / 1000;
    final start = (widget.delay + widget.stagger * i).inMicroseconds / 1000;
    final t = ((elapsed - start) / (_per.inMicroseconds / 1000)).clamp(0.0, 1.0);
    final s = Motion.spring.transform(t);
    return (pop: s, opacity: s);
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) return Text(widget.text, style: widget.style, maxLines: 1, softWrap: false);
    return GlyphRun(text: widget.text, style: widget.style, repaint: _c, state: _letter);
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

  /// Read at paint time, so it follows the phase without rebuilding.
  LetterState _letter(int i) {
    final exiting = _phase == _Phase.exiting;
    final total = exiting ? _exitTotal(_shown) : _enterTotal(_shown);
    final elapsed = _c.value * total.inMicroseconds / 1000;
    final stagger = exiting ? _outStagger : _inStagger;
    final per = (exiting ? _outPer : _inPer).inMicroseconds / 1000;
    final t = ((elapsed - (stagger * i).inMicroseconds / 1000) / per).clamp(0.0, 1.0);
    if (!exiting) {
      final s = Motion.spring.transform(t);
      return (pop: s, opacity: s);
    }
    // Exit: a smooth accelerating drop and fade. (The spring played backwards
    // overshoots upward first, which read as a twitch.)
    return (pop: 1 - Motion.exitMotion.transform(t), opacity: 1 - Motion.exitFade.transform(t));
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) return Text(_shown, style: widget.style, maxLines: 1, softWrap: false);
    return GlyphRun(text: _shown, style: widget.style, repaint: _c, state: _letter);
  }
}
