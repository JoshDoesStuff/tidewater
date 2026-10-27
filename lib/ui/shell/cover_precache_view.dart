import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/cover_precache.dart';
import '../../app/theme/motion.dart';

/// The first launch on a server saves the Library's covers to disk (see [CoverPrecacheNotifier]):
/// a screen like "Wrapping up" with a squiggle that fills as they arrive, and "Keep browsing",
/// which shrinks it to a small pill in the corner while it carries on. Later launches top the
/// cache up quietly, with nothing on screen.
class CoverPrecacheView extends ConsumerWidget {
  const CoverPrecacheView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(coverPrecacheProvider);
    final show = p.firstRun && p.running && p.total > 0;
    final big = show && !p.hidden;
    final small = show && p.hidden;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !big,
            child: AnimatedOpacity(
              opacity: big ? 1 : 0,
              duration: Motion.of(context, Motion.medium),
              child: big
                  ? _Screen(p: p, onHide: () => ref.read(coverPrecacheProvider.notifier).hide())
                  : const SizedBox(),
            ),
          ),
        ),
        Positioned(
          left: 104,
          bottom: 20,
          child: IgnorePointer(
            ignoring: !small,
            child: AnimatedOpacity(
              opacity: small ? 1 : 0,
              duration: Motion.of(context, Motion.medium),
              child: small ? _Pill(p: p) : const SizedBox(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.p, required this.onHide});

  final CoverPrecache p;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: scheme.surface.withValues(alpha: .94),
      child: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Saving covers',
                value: '${p.done} of ${p.total}',
                child: ProgressSquiggle(fraction: p.fraction),
              ),
              const SizedBox(height: 18),
              Text(
                'Saving your covers…',
                style: (text.titleLarge ?? const TextStyle()).copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                '${_count(p.done)} of ${_count(p.total)}. Once they are on this computer, browsing never waits for them.',
                textAlign: TextAlign.center,
                style: (text.bodyMedium ?? const TextStyle()).copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(onPressed: onHide, child: const Text('Keep browsing')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.p});

  final CoverPrecache p;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 90,
              child: ProgressSquiggle(fraction: p.fraction, height: 12, strokeWidth: 4, wavelength: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Saving covers ${(p.fraction * 100).floor()}%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

String _count(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// The wavy progress bar's look, filled to [fraction]: a moving squiggle for the done part and
/// a flat track for the rest. Holds still with reduced motion.
class ProgressSquiggle extends StatefulWidget {
  const ProgressSquiggle({
    super.key,
    required this.fraction,
    this.height = 16,
    this.strokeWidth = 6,
    this.wavelength = 28,
  });

  final double fraction;
  final double height;
  final double strokeWidth;
  final double wavelength;

  @override
  State<ProgressSquiggle> createState() => _ProgressSquiggleState();
}

class _ProgressSquiggleState extends State<ProgressSquiggle> with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1150));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _flow.stop();
    } else if (!_flow.isAnimating) {
      _flow.repeat();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.fraction),
          duration: Motion.of(context, Motion.slow),
          curve: Motion.standard,
          builder: (context, f, _) => CustomPaint(
            painter: _ProgressPainter(
              flow: _flow,
              fraction: f,
              color: scheme.primary,
              track: scheme.secondaryContainer,
              strokeWidth: widget.strokeWidth,
              wavelength: widget.wavelength,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.flow,
    required this.fraction,
    required this.color,
    required this.track,
    required this.strokeWidth,
    required this.wavelength,
  }) : super(repaint: flow);

  final Animation<double> flow;
  final double fraction;
  final Color color;
  final Color track;
  final double strokeWidth;
  final double wavelength;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final amp = (size.height - strokeWidth) / 2;
    final end = size.width * fraction;
    final gap = strokeWidth * 1.5;
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (end + gap < size.width - strokeWidth / 2) {
      canvas.drawLine(
        Offset(math.min(size.width, end + gap), mid),
        Offset(size.width - strokeWidth / 2, mid),
        paint..color = track,
      );
    }
    if (end > strokeWidth / 2) {
      final path = Path();
      final phase = flow.value * 2 * math.pi;
      for (var x = strokeWidth / 2; x <= end; x += 2) {
        final y = mid + amp * math.sin(x / wavelength * 2 * math.pi - phase);
        x == strokeWidth / 2 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) => old.fraction != fraction || old.color != color || old.track != track;
}
