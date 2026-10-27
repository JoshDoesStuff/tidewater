import '../../../app/perf_flags.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import 'morph_path.dart';

/// Clips [child] to a squircle that springs to a scalloped shape.
///
/// [morph] is the target (0 squircle, 1 lobed); the widget drives a spring
/// (stiffness 170, damping ratio .55, so it visibly overshoots) toward it.
/// [spin] rotates the lobes in radians per second. Changing [params] while
/// morphed first relaxes to the squircle, swaps, then morphs back. Reduced
/// motion sets values instantly and never spins.
class MorphShape extends StatefulWidget {
  const MorphShape({
    super.key,
    required this.child,
    this.params = const ShapeParams(lobes: 9, amp: .06, base: .955),
    this.morph = 0,
    this.spin = 0,
    this.squareBase = true,
    this.exponent = 4.2,
    this.shadow = true,
    this.shadowAlpha = .28,
  });

  final Widget child;
  final ShapeParams params;
  final double morph;
  final double spin;
  final bool squareBase;

  /// Superellipse exponent of the resting outline (2 is a circle).
  final double exponent;
  final bool shadow;
  final double shadowAlpha;

  @override
  State<MorphShape> createState() => _MorphShapeState();
}

class _MorphShapeState extends State<MorphShape> with TickerProviderStateMixin {
  static final _spring = SpringDescription.withDampingRatio(mass: 1, stiffness: 170, ratio: .55);

  late final AnimationController _m = AnimationController.unbounded(vsync: this, value: widget.morph);
  final ValueNotifier<double> _rot = ValueNotifier(0);
  late final Listenable _repaint = Listenable.merge([_m, _rot]);
  late final _clipper = _MorphClipper(this);

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  late ShapeParams _params = widget.params;
  Timer? _swap;
  bool _reduced = false;

  // Path cache: recomputed only when morph, rotation, size or params change.
  Path? _path;
  Size? _pathSize;
  double _pathM = double.nan;
  double _pathRot = double.nan;
  ShapeParams? _pathParams;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _syncTicker();
  }

  @override
  void didUpdateWidget(MorphShape old) {
    super.didUpdateWidget(old);
    final swapping = _swap?.isActive ?? false;
    if (widget.params != old.params) {
      if (_m.value > .05 && !_reduced) {
        _springTo(0);
        _swap?.cancel();
        _swap = Timer(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          _params = widget.params;
          _springTo(widget.morph);
        });
      } else {
        _params = widget.params;
        _springTo(widget.morph);
      }
    } else if (widget.morph != old.morph && !swapping) {
      _springTo(widget.morph);
    }
    if (widget.spin != old.spin) _syncTicker();
  }

  void _springTo(double target) {
    if (_reduced) {
      _m.stop();
      _m.value = target;
    } else {
      _m.animateWith(SpringSimulation(_spring, _m.value, target, _m.velocity));
    }
  }

  void _syncTicker() {
    final want = widget.spin != 0 && !_reduced;
    if (want && _ticker == null) {
      _lastTick = Duration.zero;
      _ticker = createTicker(_onTick)..start();
    } else if (!want && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _rot.value += widget.spin * dt;
  }

  Path _pathFor(Size size) {
    final m = _m.value;
    final rot = _rot.value;
    if (_path == null || _pathSize != size || _pathM != m || _pathRot != rot || _pathParams != _params) {
      _path = morphPath(size, m: m, params: _params, rot: rot, squareBase: widget.squareBase, exponent: widget.exponent);
      _pathSize = size;
      _pathM = m;
      _pathRot = rot;
      _pathParams = _params;
    }
    return _path!;
  }

  @override
  void dispose() {
    _swap?.cancel();
    _ticker?.dispose();
    _m.dispose();
    _rot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: PerfFlags.instance, builder: _build);
  }

  Widget _build(BuildContext context, Widget? _) {
    final flags = PerfFlags.instance;
    Widget shaped = flags.clip
        ? ClipPath(
            clipper: _clipper,
            clipBehavior: flags.smoothClip ? Clip.antiAlias : Clip.hardEdge,
            child: widget.child,
          )
        : widget.child;
    if (widget.shadow && flags.shadows) {
      shaped = CustomPaint(
        painter: _ShadowPainter(this, Theme.of(context).colorScheme.shadow.withValues(alpha: widget.shadowAlpha)),
        child: shaped,
      );
    }
    return RepaintBoundary(child: shaped);
  }
}

class _MorphClipper extends CustomClipper<Path> {
  _MorphClipper(this._state) : super(reclip: _state._repaint);

  final _MorphShapeState _state;

  @override
  Path getClip(Size size) => _state._pathFor(size);

  @override
  bool shouldReclip(_MorphClipper old) => true;
}

class _ShadowPainter extends CustomPainter {
  _ShadowPainter(this._state, this._color) : super(repaint: _state._repaint);

  final _MorphShapeState _state;
  final Color _color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 112;
    final paint = Paint()
      ..color = _color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * k);
    final w = _state.widget;
    if (_state._m.value.abs() < .01 && w.squareBase) {
      // At rest the shape is a squircle, which a rounded rectangle matches closely, and a
      // blurred rounded rectangle has a fast path where a blurred arbitrary path does not:
      // this was the dearest part of drawing each new card scrolled into view.
      final r = size.shortestSide * (.5 - ((w.exponent - 2) * .09).clamp(0.0, .2));
      canvas.drawRRect(RRect.fromRectAndRadius(Offset(0, 8 * k) & size, Radius.circular(r)), paint);
      return;
    }
    canvas.drawPath(_state._pathFor(size).shift(Offset(0, 8 * k)), paint);
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => old._color != _color;
}
