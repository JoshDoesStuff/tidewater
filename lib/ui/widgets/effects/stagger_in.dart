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

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  Timer? _delay;
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
      child: widget.child,
      builder: (context, child) {
        final t = Motion.emphasized.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - t)),
            child: Transform.scale(scale: .96 + .04 * t, child: child),
          ),
        );
      },
    );
  }
}
