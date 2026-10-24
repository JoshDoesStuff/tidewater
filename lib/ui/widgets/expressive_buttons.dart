import 'package:flutter/material.dart';

import '../../app/theme/motion.dart';
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
  });

  final IconData icon;
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
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(square ? squareRadius : size / 2),
            ),
            child: Icon(icon, size: iconSize, color: fg),
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
            clipBehavior: Clip.hardEdge,
            transform: Matrix4.translationValues(0, s.hovered ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(s.hovered ? 36 : 24),
              boxShadow: [
                BoxShadow(color: scheme.shadow.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: scheme.onPrimaryContainer),
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary
                  : (s.hovered ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(selected ? 20 : 12),
            ),
            // widthFactor keeps the chip hugging its label (an `alignment` on
            // the container would stretch it to the full row).
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
