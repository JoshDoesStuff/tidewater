import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';

final _revealed = <String>{};

/// True the first time [key] is asked for in this session, so a page title
/// reveals letter by letter once and is plain afterwards.
bool revealOnce(String key) => _revealed.add(key);

/// Letter-by-letter heading reveal: each glyph rises .65em, untilts 10° and
/// fades in on the spring curve, staggered by [stagger]. Restarts whenever
/// [text] changes. With reduced motion it is plain text.
class LetterReveal extends StatefulWidget {
  const LetterReveal({
    super.key,
    required this.text,
    required this.style,
    this.delay = Duration.zero,
    this.stagger = const Duration(milliseconds: 26),
    this.animate = true,
  });

  final String text;
  final TextStyle? style;
  final Duration delay;
  final Duration stagger;

  /// False to show the text immediately (e.g. already revealed this session).
  final bool animate;

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
    if (!widget.animate || _reduced || widget.text.isEmpty) {
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
    final style = widget.style;
    if (_reduced || !widget.animate) return Text(widget.text, style: style, maxLines: 1, softWrap: false);
    final em = style?.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14;
    final chars = widget.text.characters.toList();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final elapsed = _c.value * _total.inMicroseconds / 1000;
        return Row(
          mainAxisSize: MainAxisSize.min,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (var i = 0; i < chars.length; i++)
              () {
                final start = (widget.delay + widget.stagger * i).inMicroseconds / 1000;
                final p = ((elapsed - start) / (_per.inMicroseconds / 1000)).clamp(0.0, 1.0);
                final s = Motion.spring.transform(p);
                return Opacity(
                  opacity: p.clamp(0.0, 1.0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.translationValues(0, .65 * em * (1 - s), 0)..rotateZ(.1745 * (1 - s)),
                    child: Text(chars[i], style: style, softWrap: false),
                  ),
                );
              }(),
          ],
        );
      },
    );
  }
}
