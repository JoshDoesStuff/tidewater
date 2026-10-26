import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' show LottieComposition;

import '../../app/destinations.dart';
import '../../app/theme/motion.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/pressable.dart';
import 'rail_icon_motion.dart';

/// Left navigation rail. Custom rather than Flutter's NavigationRail so the
/// pill indicator can spring between items as in the demo. [compact] drops
/// the labels for narrow windows.
class NavRail extends StatelessWidget {
  const NavRail({
    super.key,
    required this.selected,
    required this.compact,
    required this.onSelected,
    this.onBack,
    this.onMenu,
  });

  static double widthFor({required bool compact}) => compact ? 72 : 96;

  final Destination? selected;
  final bool compact;
  final ValueChanged<Destination> onSelected;

  /// Set on detail pages (album, artist, playlist): shows a back arrow at the top.
  final VoidCallback? onBack;

  /// Collapses or expands the rail by hand (the menu button, shown when there is no back arrow).
  final VoidCallback? onMenu;

  static const _main = [
    Destination.home,
    Destination.library,
    Destination.artists,
    Destination.liked,
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
          // The menu button collapses and expands the rail; on detail pages the back arrow takes its place.
          SizedBox(
            height: 56,
            // Menu and back arrow swap with a spring pop, scaling from their center.
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.medium),
              switchInCurve: Motion.curve(context, Motion.spring),
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: onBack == null
                  ? ExpressiveIconButton(
                      key: const ValueKey('menu'),
                      icon: Icons.menu_rounded,
                      glyph: glyphFor(GlyphKind.menu, size: 24),
                      size: 56,
                      iconSize: 24,
                      squareRadius: 16,
                      tooltip: compact ? 'Expand menu' : 'Collapse menu',
                      onPressed: onMenu,
                    )
                  : ExpressiveIconButton(
                      key: const ValueKey('back'),
                      icon: Icons.arrow_back_rounded,
                      glyph: glyphFor(GlyphKind.back, size: 24),
                      size: 56,
                      iconSize: 24,
                      squareRadius: 16,
                      tooltip: 'Back',
                      onPressed: onBack,
                    ),
            ),
          ),
          const SizedBox(height: 34),
          // Scrolls when the window is too short for every item.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final d in _main) ...[
                    _RailItem(
                      destination: d,
                      selected: d == selected,
                      compact: compact,
                      onTap: () => onSelected(d),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
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

class _RailItem extends StatefulWidget {
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
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> with SingleTickerProviderStateMixin {
  /// Plays once each time the item becomes the selected one, alongside the
  /// page transition: each destination has its own icon animation.
  late final AnimationController _pop = AnimationController(vsync: this, duration: Motion.slow);
  LottieComposition? _composition;

  @override
  void initState() {
    super.initState();
    RailIcons.load(widget.destination)?.then((c) {
      if (!mounted) return;
      _pop.duration = c.duration;
      setState(() => _composition = c);
    });
  }

  Destination get destination => widget.destination;
  bool get selected => widget.selected;
  bool get compact => widget.compact;
  VoidCallback get onTap => widget.onTap;

  @override
  void didUpdateWidget(_RailItem old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected && !Motion.reduced(context)) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

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
                      child: AnimatedBuilder(
                        animation: _pop,
                        builder: (context, _) => railIconMotion(destination, _pop.value, fg, composition: _composition),
                      ),
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
