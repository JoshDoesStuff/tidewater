import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/pages/home_page.dart';
import '../ui/pages/library_page.dart';
import '../ui/pages/placeholder_page.dart';
import '../ui/pages/settings_page.dart';
import '../ui/shell/app_shell.dart';
import 'destinations.dart';
import 'theme/motion.dart';

GoRouter createRouter() => GoRouter(
      initialLocation: Destination.home.path,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
          routes: [
            for (final d in Destination.values)
              GoRoute(
                path: d.path,
                pageBuilder: (context, state) => _enterPage(state, _pageFor(d)),
              ),
          ],
        ),
      ],
    );

Widget _pageFor(Destination d) => switch (d) {
      Destination.home => const HomePage(),
      Destination.library => const LibraryPage(),
      Destination.settings => const SettingsPage(),
      _ => PlaceholderPage(destination: d),
    };

/// Page enter: fade plus a 14 px rise. The outgoing page fades out so the two
/// never overlap. Reduced motion keeps the fade and drops the rise.
Page<void> _enterPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: Motion.slow,
      reverseTransitionDuration: Motion.medium,
      transitionsBuilder: (context, animation, secondary, child) {
        final fadeIn = CurvedAnimation(parent: animation, curve: Motion.standard);
        final fadeOut = CurvedAnimation(parent: secondary, curve: const Interval(0, .5, curve: Motion.standard));
        Widget page = FadeTransition(
          opacity: ReverseAnimation(fadeOut),
          child: FadeTransition(opacity: fadeIn, child: child),
        );
        if (!Motion.reduced(context)) {
          final rise = CurvedAnimation(parent: animation, curve: Motion.emphasized);
          page = SlideTransition(
            position: Tween(begin: const Offset(0, 14 / 800), end: Offset.zero).animate(rise),
            child: page,
          );
        }
        return page;
      },
    );
