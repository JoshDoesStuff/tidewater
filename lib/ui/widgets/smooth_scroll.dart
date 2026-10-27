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

  /// Roughly how long a glide takes to arrive, in seconds. It is a critically damped spring
  /// (so it starts gently, speeds up and lands softly, and keeps its speed from one wheel
  /// notch to the next), not a plain ease-out that leaps at the first frame.
  static const _smoothTime = .2;

  double _velocity = 0;

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
      // One start and one end for the whole glide (and so one "is scrolling" for whatever
      // listens), rather than a jump, and three notifications, on every frame.
      goIdle();
      didStartScroll();
      _ticker!.start();
    }
  }

  void _tick(Duration elapsed) {
    final target = _target;
    // Something else moved the page (a drag, the scrollbar, a jump): let it.
    if (target == null || (pixels - _expected).abs() > 1) {
      _stop(external: target != null);
      return;
    }
    // A long frame must not throw it past the target.
    final dt = _last == null ? 1 / 60 : math.min((elapsed - _last!).inMicroseconds / 1e6, .05);
    _last = elapsed;
    const omega = 2 / _smoothTime;
    final x = omega * dt;
    final damp = 1 / (1 + x + .48 * x * x + .235 * x * x * x);
    final change = pixels - target;
    final temp = (_velocity + omega * change) * dt;
    _velocity = (_velocity - omega * temp) * damp;
    var next = target + (change + temp) * damp;
    final done = (target - next).abs() < .5 && _velocity.abs() < 8;
    if (done) next = target;
    next = next.clamp(minScrollExtent, maxScrollExtent);
    final before = pixels;
    forcePixels(next);
    didUpdateScrollPositionBy(pixels - before);
    _expected = pixels;
    if (done) _stop();
  }

  void _stop({bool external = false}) {
    final wasGliding = _target != null || (_ticker?.isActive ?? false);
    _target = null;
    _velocity = 0;
    _ticker?.stop();
    // When something else took over, it owns the activity and the notifications now.
    if (wasGliding && !external) {
      didEndScroll();
      goBallistic(0);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// True while a page is being scrolled (by wheel, drag or scrollbar). The decoration behind the
/// pages (the drifting shapes, the aurora) stands still meanwhile: on a full-screen window its
/// drawing alone took most of a frame, and nobody is looking at it while the page flies by.
final pageScrolling = ValueNotifier<bool>(false);

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
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
          if (n is ScrollStartNotification) pageScrolling.value = true;
          if (n is ScrollEndNotification) pageScrolling.value = false;
        }
        return false;
      },
      child: PrimaryScrollController(controller: _controller, child: widget.child),
    );
  }
}
