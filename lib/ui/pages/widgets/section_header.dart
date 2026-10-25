import 'package:flutter/material.dart';

import '../../widgets/pressable.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action = 'Show all', this.onAction});

  final String title;
  final String? action;

  /// Tapped "Show all"; the link is hidden without it.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: text.titleLarge),
          if (action != null && onAction != null)
            Pressable(
              onTap: onAction!,
              builder: (context, s) => Text(
                action!,
                style: text.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  decoration: s.hovered ? TextDecoration.underline : null,
                  decorationColor: scheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
