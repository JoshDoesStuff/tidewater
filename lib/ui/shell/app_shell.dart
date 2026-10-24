import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/destinations.dart';
import '../widgets/expressive_buttons.dart';
import 'mini_player.dart';
import 'nav_rail.dart';
import 'title_bar.dart';

/// Window shell: rail on the left, routed content, custom title bar on top,
/// floating mini player (bottom center) and Shuffle FAB (bottom right).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final compact = width < 900;
        final fabExtended = width >= 1000;
        final railWidth = NavRail.widthFor(compact: compact);
        final fabWidth = fabExtended ? 192.0 : 72.0;
        // Keep the pill centered in the window and clear of the FAB.
        final miniWidth = math.max(320.0, math.min(700.0, width - 2 * (32 + fabWidth + 24)));
        return Material(
          color: scheme.surface,
          child: Stack(
            children: [
              Positioned.fill(left: railWidth, child: child),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: railWidth,
                child: NavRail(
                  selected: Destination.fromLocation(location),
                  compact: compact,
                  onSelected: (d) => context.go(d.path),
                ),
              ),
              const Positioned(left: 0, right: 0, top: 0, child: TitleBar()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(child: SizedBox(width: miniWidth, child: const MiniPlayer())),
              ),
              Positioned(
                right: 32,
                bottom: 24,
                child: ExpressiveFab(icon: Icons.shuffle_rounded, label: 'Shuffle all', extended: fabExtended),
              ),
            ],
          ),
        );
      },
    );
  }
}
