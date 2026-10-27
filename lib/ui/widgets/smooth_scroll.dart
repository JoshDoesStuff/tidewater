import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A scroll controller whose mouse wheel glides: each notch moves a target and the page
/// eases toward it, instead of jumping a few lines at a time. Dragging, the keyboard, the
/// scrollbar and `animateTo` are untouched (and take over from a glide in progress).
class SmoothScrollController extends ScrollController {
  SmoothScrollController({super.initialScrollOffset, super.keepScrollOffset, super.debugLabel});

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) {
    return SmoothScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class SmoothScrollPosition extends ScrollPositionWithSingleContext {
  SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  /// How quickly it settles: the time constant of the ease, in seconds.
  static const _settle = .075;

  Ticker? _ticker;
  double? _target;
  double _expected = 0;
  Duration? _last;

  @override
  void pointerScroll(double delta) {
    final notification = context.notificationContext;
    if (delta == 0 || (notification != null && MediaQuery.maybeDisableAnimationsOf(notification) == true)) {
      super.pointerScroll(delta);
      return;
    }
    // Several notches in a row add up to one longer glide.
    final from = _target ?? pixels;
    final target = (from + delta).clamp(minScrollExtent, maxScrollExtent);
    if (target == from) return;
    _target = target;
    _expected = pixels;
    _ticker ??= context.vsync.createTicker(_tick);
    if (!_ticker!.isActive) {
      _last = null;
      _ticker!.start();
    }
  }

  void _tick(Duration elapsed) {
    final target = _target;
    // Something else moved the page (a drag, the scrollbar, a jump): let it.
    if (target == null || (pixels - _expected).abs() > 1) {
      _stop();
      return;
    }
    final dt = _last == null ? 1 / 60 : (elapsed - _last!).inMicroseconds / 1e6;
    _last = elapsed;
    final k = 1 - math.exp(-dt / _settle);
    var next = pixels + (target - pixels) * k;
    final done = (target - next).abs() < .5;
    if (done) next = target;
    next = next.clamp(minScrollExtent, maxScrollExtent);
    jumpTo(next);
    _expected = pixels;
    if (done) _stop();
  }

  void _stop() {
    _target = null;
    _ticker?.stop();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// Gives the scroll views below it (the ones that use the primary controller, which is
/// every plain vertical page) the gliding wheel.
class SmoothScrollScope extends StatefulWidget {
  const SmoothScrollScope({super.key, required this.child});

  final Widget child;

  @override
  State<SmoothScrollScope> createState() => _SmoothScrollScopeState();
}

class _SmoothScrollScopeState extends State<SmoothScrollScope> {
  final _controller = SmoothScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrimaryScrollController(controller: _controller, child: widget.child);
}
