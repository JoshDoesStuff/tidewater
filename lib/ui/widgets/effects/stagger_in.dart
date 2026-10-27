import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';

/// Page-enter for cards, heroes and chips: fade, 22 px rise and a slight
/// scale-up (560 ms, emphasized), delayed by [index] * 24 ms. Plays once,
/// when the item first comes into view.
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child, this.base = const Duration(milliseconds: 40)});

  final int index;
  final Duration base;
  final Widget child;

  /// The delay index for item `i` of a grid with `columns` columns: a diagonal wave across
  /// the first eight rows, so the whole screen animates in (not just the first couple of
  /// rows), and 0 (no delay) for rows scrolled in later.
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

  /// Lists build well ahead of the scroll (so covers are ready in time); an item built off
  /// screen waits here until it scrolls into view, or its entrance would play where nobody
  /// can see it and be over by the time it arrived.
  ScrollPosition? _waitingOn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
      return;
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) {
      _start();
      return;
    }
    _waitingOn = position..addListener(_checkSoon);
    _checkSoon();
  }

  bool _checkPending = false;

  /// Looks once the frame has been laid out (a scroll notifies before the list has moved).
  void _checkSoon() {
    if (_checkPending) return;
    _checkPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPending = false;
      _check();
    });
  }

  bool _firstLook = true;

  void _check() {
    final first = _firstLook;
    _firstLook = false;
    if (_waitingOn == null || !mounted || !_onScreen()) return;
    _waitingOn!.removeListener(_checkSoon);
    _waitingOn = null;
    // On screen from the start: the page-enter wave. Scrolled into view later: at once (its
    // place in the wave meant nothing to a row that arrives on its own).
    _start(wave: first);
  }

  bool _onScreen() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final view = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (view is! RenderBox || !view.hasSize) return true;
    final me = box.localToGlobal(Offset.zero) & box.size;
    final seen = view.localToGlobal(Offset.zero) & view.size;
    return me.overlaps(seen);
  }

  void _start({bool wave = true}) {
    final delay = wave ? widget.base + Duration(milliseconds: 24 * widget.index.clamp(0, 30)) : Duration.zero;
    _delay = Timer(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _waitingOn?.removeListener(_checkSoon);
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
        // The item stays in the accessibility tree while it fades (a node that appears and
        // goes at every row scrolled in is what Windows trips over). Rows scrolled in later rise
        // a little less than the first screenful.
        final rise = widget.index == 0 ? 14.0 : 22.0;
        return Opacity(
          opacity: t,
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, rise * (1 - t)),
            child: Transform.scale(scale: .96 + .04 * t, child: child),
          ),
        );
      },
    );
  }
}
