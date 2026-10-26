import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/motion.dart';

/// "Tidewater" with the width and weight of the letters rolling like a swell
/// (heavy and wide on the crests, light and narrow in the troughs), every
/// letter fully round. Each letter rises in on its own.
class BrandTitle extends StatefulWidget {
  const BrandTitle({super.key, this.size = 64});

  final double size;

  @override
  State<BrandTitle> createState() => _BrandTitleState();
}

class _BrandTitleState extends State<BrandTitle>
    with SingleTickerProviderStateMixin {
  static const _word = 'Tidewater';

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: _word,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _word.length; i++) _letter(i, color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _letter(int i, Color color) {
    final swell = math.cos(2 * math.pi * i / 4);
    final t = Motion.emphasized.transform(
      ((_c.value * 1100 - i * 60) / 520).clamp(0.0, 1.0),
    );
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, widget.size * .4 * (1 - t)),
        child: Text(
          _word[i],
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: widget.size,
            height: 1.1,
            color: color,
            letterSpacing: -widget.size * .01,
            fontVariations: [
              const FontVariation('ROND', 100),
              FontVariation('wght', 640 + 260 * swell),
              FontVariation('wdth', 100 + 38 * swell),
            ],
          ),
        ),
      ),
    );
  }
}
