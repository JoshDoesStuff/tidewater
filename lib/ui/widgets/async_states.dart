import 'package:flutter/material.dart';

import '../../app/theme/motion.dart';
import '../../core/api/api_exception.dart';
import 'effects/ripple.dart';
import 'pressable.dart';

/// Placeholder block shown while a list loads; pulses gently.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = 16, this.circle = false});

  final double? width;
  final double? height;
  final double radius;
  final bool circle;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
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
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(scheme.surfaceContainerHigh, scheme.surfaceContainerHighest, Curves.easeInOut.transform(_c.value)),
            borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
            shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
          ),
          child: SizedBox(width: widget.width, height: widget.height),
        ),
      ),
    );
  }
}

/// Something went wrong loading a list: says what, and offers a retry.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.error, required this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback onRetry;

  /// Smaller, for a row inside a page rather than a whole page.
  final bool compact;

  String get _message {
    final e = error;
    if (e is ApiException) {
      return e.isOffline ? 'Can\'t reach your server. Check your connection and try again.' : e.message;
    }
    return 'Something went wrong loading this.';
  }

  bool get _offline => error is ApiException && (error as ApiException).isOffline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 16 : 28),
        decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
        child: Row(
          children: [
            Icon(_offline ? Icons.cloud_off_rounded : Icons.error_outline_rounded, size: 28, color: scheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(child: Text(_message, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
            const SizedBox(width: 16),
            Pressable(
              onTap: onRetry,
              semanticLabel: 'Retry',
              builder: (context, s) => AnimatedContainer(
                duration: Motion.of(context, Motion.fast),
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: s.hovered ? scheme.primary : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(s.pressed ? 12 : 20),
                ),
                child: Ripple(
                  color: scheme.onSecondaryContainer,
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      'Retry',
                      style: text.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: s.hovered ? scheme.onPrimary : scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A list that has nothing in it.
class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
