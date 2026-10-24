import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/motion.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});

class TidewaterApp extends ConsumerWidget {
  const TidewaterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = ref.watch(reduceMotionProvider);
    return MaterialApp.router(
      title: 'Tidewater',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
        dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.trackpad},
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: media.disableAnimations || reduceMotion),
          child: child!,
        );
      },
    );
  }
}
