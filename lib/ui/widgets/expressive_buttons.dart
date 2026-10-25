import 'package:flutter/material.dart';

import '../../app/theme/motion.dart';
import 'effects/ripple.dart';
import 'pressable.dart';

enum ButtonTone { standard, ghost, tonal, filled }

/// Round at rest, squarer when pressed or selected. Radius changes on the
/// spring curve.
class ExpressiveIconButton extends StatelessWidget {
  const ExpressiveIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.selected = false,
    this.tone = ButtonTone.standard,
    this.size = 48,
    this.iconSize = 24,
    this.squareRadius = 16,
    this.tooltip,
    this.glyph,
  });

  final IconData icon;

  /// Replaces [icon] with custom artwork; told the foreground color and whether
  /// the pointer is over the button.
  final Widget Function(BuildContext context, Color color, bool hovered)? glyph;
  final VoidCallback? onPressed;
  final bool selected;
  final ButtonTone tone;
  final double size;
  final double iconSize;

  /// Corner radius when pressed or selected.
  final double squareRadius;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget button = Pressable(
      onTap: onPressed ?? () {},
      semanticLabel: tooltip,
      builder: (context, s) {
        final (bg, fg) = switch ((selected, tone)) {
          (true, _) => (scheme.primary, scheme.onPrimary),
          (_, ButtonTone.filled) => (scheme.primary, scheme.onPrimary),
          (_, ButtonTone.tonal) => (scheme.secondaryContainer, scheme.onSecondaryContainer),
          (_, ButtonTone.ghost) => (
              s.hovered ? scheme.surfaceContainerHigh : scheme.surfaceContainerHigh.withValues(alpha: 0),
              scheme.onSurface,
            ),
          _ => (s.hovered ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh, scheme.onSurface),
        };
        final square = selected || s.pressed;
        return AnimatedScale(
          scale: s.pressed ? .9 : 1,
          duration: Motion.of(context, Motion.fast),
          curve: Motion.curve(context, Motion.spring),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.medium),
            curve: Motion.curve(context, Motion.spring),
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(square ? squareRadius : size / 2),
            ),
            child: Ripple(
              color: fg,
              child: Center(child: glyph?.call(context, fg, s.hovered) ?? Icon(icon, size: iconSize, color: fg)),
            ),
          ),
        );
      },
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}

/// Play/pause glyph that scales and rotates between the two icons.
class PlayPauseIcon extends StatelessWidget {
  const PlayPauseIcon({super.key, required this.playing, this.size = 24, this.color});

  final bool playing;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.slow);
    final curve = Motion.curve(context, Motion.spring);
    Widget glyph(IconData icon, bool shown, double hiddenTurns) => AnimatedRotation(
          turns: shown ? 0 : hiddenTurns,
          duration: duration,
          curve: curve,
          child: AnimatedScale(
            scale: shown ? 1 : .3,
            duration: duration,
            curve: curve,
            child: AnimatedOpacity(
              opacity: shown ? 1 : 0,
              duration: Motion.of(context, Motion.fast),
              child: Icon(icon, size: size, color: color),
            ),
          ),
        );
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          glyph(Icons.play_arrow_rounded, !playing, .25),
          glyph(Icons.pause_rounded, playing, -.25),
        ],
      ),
    );
  }
}

/// Extended FAB: rounded rect that grows rounder on hover.
class ExpressiveFab extends StatelessWidget {
  const ExpressiveFab({
    super.key,
    required this.icon,
    required this.label,
    this.extended = true,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool extended;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onPressed ?? () {},
      semanticLabel: label,
      builder: (context, s) {
        return AnimatedScale(
          scale: s.pressed ? .95 : 1,
          duration: Motion.of(context, Motion.fast),
          curve: Motion.curve(context, Motion.spring),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.slow),
            curve: Motion.curve(context, Motion.spring),
            width: extended ? 192 : 72,
            height: 72,
            clipBehavior: Clip.antiAlias,
            transform: Matrix4.translationValues(0, s.hovered ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(s.hovered ? 36 : 24),
              boxShadow: [
                BoxShadow(color: scheme.shadow.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: Ripple(
              color: scheme.onPrimaryContainer,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Wiggle(
                      active: s.hovered,
                      child: Icon(icon, size: 24, color: scheme.onPrimaryContainer),
                    ),
                    if (extended) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          label,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Icon wiggle on hover: tilts -16° and swells to 1.25, then settles (700 ms
/// on the spring curve).
class _Wiggle extends StatefulWidget {
  const _Wiggle({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<_Wiggle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(_Wiggle old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !Motion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        // 0 → 30%: ease out to the wiggle pose, then spring back to rest.
        final t = _c.value;
        final pose = t < .3 ? Curves.easeOut.transform(t / .3) : 1 - Motion.spring.transform((t - .3) / .7);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationZ(-.279 * pose)..scaleByDouble(1 + .25 * pose, 1 + .25 * pose, 1, 1),
          child: child,
        );
      },
    );
  }
}

/// Filter chip in a button group: the selected item turns primary and squarer.
class ExpressiveChip extends StatelessWidget {
  const ExpressiveChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      builder: (context, s) {
        return AnimatedScale(
          scale: s.pressed ? .94 : 1,
          duration: Motion.of(context, Motion.fast),
          curve: Motion.curve(context, Motion.spring),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.slow),
            curve: Motion.curve(context, Motion.spring),
            height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary
                  : (s.hovered ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(selected ? 20 : 12),
            ),
            // widthFactor keeps the chip hugging its label (an `alignment` on
            // the container would stretch it to the full row).
            child: Ripple(
              color: selected ? scheme.onPrimary : scheme.onSurface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? scheme.onPrimary : scheme.onSurface,
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A row of [ExpressiveChip]s with the 4 px button-group gap.
class ExpressiveChipGroup extends StatelessWidget {
  const ExpressiveChipGroup({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < labels.length; i++)
          ExpressiveChip(label: labels[i], selected: i == selectedIndex, onTap: () => onSelected(i)),
      ],
    );
  }
}

/// A pill button with an icon and a label: filled (primary) or tonal. Round at
/// rest, squarer while pressed, like the other expressive buttons.
class ExpressivePillButton extends StatelessWidget {
  const ExpressivePillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = true,
    this.height = 56,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Primary fill, or the quieter tonal one.
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = filled ? scheme.primary : scheme.secondaryContainer;
    final fg = filled ? scheme.onPrimary : scheme.onSecondaryContainer;
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      builder: (context, s) => AnimatedScale(
        scale: s.pressed ? .96 : 1,
        duration: Motion.of(context, Motion.fast),
        curve: Motion.curve(context, Motion.spring),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.slow),
          curve: Motion.curve(context, Motion.spring),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: s.hovered && !filled ? Color.lerp(bg, scheme.onSecondaryContainer, .08) : bg,
            borderRadius: BorderRadius.circular(s.pressed ? 16 : height / 2),
          ),
          child: Ripple(
            color: fg,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: fg),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
