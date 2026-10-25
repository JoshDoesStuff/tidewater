import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The "now playing" badge on a card: a primary circle with three bouncing
/// bars. The bars freeze when [animating] is false (paused).
class EqBadge extends StatefulWidget {
  const EqBadge({super.key, required this.animating, this.size = 52});

  final bool animating;
  final double size;

  @override
  State<EqBadge> createState() => _EqBadgeState();
}

class _EqBadgeState extends State<EqBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    if (widget.animating) _c.repeat();
  }

  @override
  void didUpdateWidget(EqBadge old) {
    super.didUpdateWidget(old);
    if (widget.animating && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animating && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const heights = [16.0, 24.0, 12.0];
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .93), shape: BoxShape.circle),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              // Half-cycle 900 ms between full height and .35, offset per bar.
              Transform.scale(
                scaleY: 1 - .65 * (1 - math.cos(2 * math.pi * (_c.value + i * .1667))) / 2,
                child: Container(
                  width: 5,
                  height: heights[i],
                  decoration: BoxDecoration(color: scheme.onPrimary, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
