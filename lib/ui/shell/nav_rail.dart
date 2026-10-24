import 'package:flutter/material.dart';

import '../../app/destinations.dart';
import '../../app/theme/motion.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/pressable.dart';

/// Left navigation rail. Custom rather than Flutter's NavigationRail so the
/// pill indicator can spring between items as in the demo. [compact] drops
/// the labels for narrow windows.
class NavRail extends StatelessWidget {
  const NavRail({super.key, required this.selected, required this.compact, required this.onSelected});

  static double widthFor({required bool compact}) => compact ? 72 : 96;

  final Destination? selected;
  final bool compact;
  final ValueChanged<Destination> onSelected;

  static const _main = [
    Destination.home,
    Destination.library,
    Destination.artists,
    Destination.lists,
    Destination.radio,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widthFor(compact: compact),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const ExpressiveIconButton(
            icon: Icons.menu_rounded,
            size: 56,
            iconSize: 24,
            squareRadius: 16,
            tooltip: 'Menu',
          ),
          const SizedBox(height: 34),
          for (final d in _main) ...[
            _RailItem(
              destination: d,
              selected: d == selected,
              compact: compact,
              onTap: () => onSelected(d),
            ),
            const SizedBox(height: 12),
          ],
          const Spacer(),
          _RailItem(
            destination: Destination.settings,
            selected: Destination.settings == selected,
            compact: compact,
            onTap: () => onSelected(Destination.settings),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final Destination destination;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: destination.label,
      builder: (context, s) {
        final active = selected || s.hovered;
        final fg = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
        return SizedBox(
          width: double.infinity,
          height: compact ? 56 : 72,
          child: Column(
            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                height: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Indicator pill: springs wider on select/hover.
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: active ? 1 : .35),
                      duration: Motion.of(context, Motion.slow),
                      curve: Motion.curve(context, Motion.spring),
                      builder: (context, sx, child) => Transform.scale(scaleX: sx, child: child),
                      child: AnimatedOpacity(
                        opacity: selected ? 1 : (s.hovered ? .5 : 0),
                        duration: Motion.of(context, Motion.medium),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    AnimatedScale(
                      scale: s.pressed ? .8 : 1,
                      duration: Motion.of(context, Motion.fast),
                      child: Icon(destination.icon, size: 22, color: fg),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                Text(
                  destination.label,
                  style: text.labelMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
