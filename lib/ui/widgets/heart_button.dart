import 'package:flutter/material.dart';

import '../../app/theme/motion.dart';
import 'effects/particle_burst.dart';
import 'pressable.dart';

/// The like heart used in track rows: pops (1 -> 1.45 -> 1) with a small burst
/// of particles when it becomes liked, and just eases back when un-liked.
class HeartButton extends StatefulWidget {
  const HeartButton({super.key, required this.liked, required this.onTap, this.size = 22});

  final bool liked;
  final VoidCallback onTap;
  final double size;

  @override
  State<HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<HeartButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  final _burst = GlobalKey<BurstLayerState>();

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 65),
  ]);

  @override
  void didUpdateWidget(HeartButton old) {
    super.didUpdateWidget(old);
    if (widget.liked && !old.liked && !Motion.reduced(context)) {
      _pop.forward(from: 0);
      _burst.currentState?.burst(Offset(20, 20));
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: widget.onTap,
      semanticLabel: widget.liked ? 'Unlike' : 'Like',
      builder: (context, s) => SizedBox.square(
        dimension: 40,
        child: BurstLayer(
          key: _burst,
          color: scheme.primary,
          child: Center(
            child: AnimatedScale(
              scale: s.pressed ? .8 : (widget.liked ? 1 : (s.hovered ? 1.15 : 1)),
              duration: Motion.of(context, Motion.fast),
              curve: Motion.curve(context, Motion.spring),
              child: AnimatedBuilder(
                animation: _pop,
                builder: (context, child) => Transform.scale(scale: _scale.evaluate(_pop), child: child),
                child: Icon(
                  widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: widget.size,
                  color: widget.liked ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
