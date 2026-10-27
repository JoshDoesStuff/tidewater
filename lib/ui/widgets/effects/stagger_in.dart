import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';

/// Page-enter for cards, heroes and chips: fade, 22 px rise and a slight
/// scale-up (560 ms, emphasized), delayed by [index] * 24 ms. Plays once.
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child, this.base = const Duration(milliseconds: 40)});

  final int index;
  final Duration base;
  final Widget child;

  /// The delay index for item `i` of a grid with `columns` columns: a diagonal wave across
  /// the first eight rows, so the whole screen animates in (not just the first couple of
  /// rows), and 0 (a plain fade) for rows scrolled in later.
  static int wave(int i, int columns) => i < columns * 8 ? i ~/ columns + i % columns : 0;

  /// How many columns a grid with a maximum cell width has (what Flutter's
  /// `SliverGridDelegateWithMaxCrossAxisExtent` picks).
  static int columnsFor(double extent, double maxCellExtent, double spacing) =>
      (extent / (maxCellExtent + spacing)).ceil().clamp(1, 200);

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  Timer? _delay;
  final _childKey = GlobalKey();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _delay = Timer(widget.base + Duration(milliseconds: 24 * widget.index.clamp(0, 30)), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: KeyedSubtree(key: _childKey, child: widget.child),
      builder: (context, child) {
        // Done: no opacity or transform around it any more (an opacity layer, even at full, is an
        // offscreen pass for every card, and a hundred of them per screen add up). The key lets the
        // card move out of the wrappers without being rebuilt.
        if (_c.value >= 1) return child!;
        final t = Motion.emphasized.transform(_c.value);
        // The row stays in the accessibility tree while it fades (a node that appears and
        // goes at every row scrolled in is what Windows trips over), and only the first
        // screenful also rises: moving a transform makes the tree update on every frame.
        return Opacity(
          opacity: t,
          alwaysIncludeSemantics: true,
          child: widget.index == 0
              ? child
              : Transform.translate(
                  offset: Offset(0, 22 * (1 - t)),
                  child: Transform.scale(scale: .96 + .04 * t, child: child),
                ),
        );
      },
    );
  }
}
