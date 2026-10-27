import 'package:flutter/material.dart';

import '../widgets/smooth_scroll.dart';

/// Centers page content and caps its width on very wide windows. Its scroll views glide
/// with the mouse wheel (see [SmoothScrollScope]).
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child});

  static const maxWidth = 2400.0;

  /// Space reserved at the bottom for the floating mini player and FAB.
  static const bottomClearance = 140.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SmoothScrollScope(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: maxWidth), child: child),
      ),
    );
  }
}
