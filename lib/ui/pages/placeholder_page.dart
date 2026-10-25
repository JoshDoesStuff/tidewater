import 'package:flutter/material.dart';

import '../../app/destinations.dart';
import '../widgets/effects/letter_reveal.dart';
import 'page_frame.dart';

/// Stand-in for pages that land in later milestones.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PageFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 32, PageFrame.bottomClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LetterReveal(
              text: destination.label,
              style: text.displaySmall,
              delay: const Duration(milliseconds: 100),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming in a later milestone.',
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
