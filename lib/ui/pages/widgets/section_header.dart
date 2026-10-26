import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';
import '../../widgets/animated_glyphs.dart';
import '../../widgets/pressable.dart';

/// A section title with, at the end, a "Show all" button (or any [trailing]
/// widget, such as a [SectionPillButton]).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action = 'Show all',
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? action;

  /// Tapped "Show all"; the button is hidden without it.
  final VoidCallback? onAction;

  /// A button (or anything) shown at the end instead of the "Show all" button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: text.titleLarge),
          if (trailing != null)
            trailing!
          else if (action != null && onAction != null)
            SectionPillButton(
              label: action!,
              glyph: GlyphKind.back,
              mirrored: true,
              onPressed: onAction!,
            ),
        ],
      ),
    );
  }
}

/// The small tonal pill at the end of a section header: a label and an icon
/// that plays when the button is pressed.
class SectionPillButton extends StatelessWidget {
  const SectionPillButton({
    super.key,
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.mirrored = false,
  });

  final String label;
  final GlyphKind glyph;
  final VoidCallback onPressed;

  /// Flips the icon left to right (the "back" arrow becomes a "forward" one).
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget icon = AnimatedGlyph(
      kind: glyph,
      size: 20,
      color: scheme.onSecondaryContainer,
      active: false,
    );
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      builder: (context, s) {
        icon = AnimatedGlyph(
          kind: glyph,
          size: 20,
          color: scheme.onSecondaryContainer,
          active: s.pressed,
        );
        return AnimatedScale(
          scale: s.pressed ? .94 : 1,
          duration: Motion.of(context, Motion.fast),
          curve: Motion.curve(context, Motion.spring),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.medium),
            curve: Motion.curve(context, Motion.spring),
            height: 40,
            padding: const EdgeInsets.only(left: 16, right: 14),
            decoration: BoxDecoration(
              color: s.hovered
                  ? Color.lerp(
                      scheme.secondaryContainer,
                      scheme.onSecondaryContainer,
                      .08,
                    )
                  : scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(s.pressed ? 12 : 20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                mirrored ? Transform.scale(scaleX: -1, child: icon) : icon,
              ],
            ),
          ),
        );
      },
    );
  }
}
