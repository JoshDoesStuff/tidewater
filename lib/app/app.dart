import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/playback_providers.dart';
import 'providers/settings_providers.dart';
import 'router.dart';
import 'theme/album_scheme.dart';
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
    final brightness = ref.watch(darkThemeProvider) ? Brightness.dark : Brightness.light;
    final scheme = AlbumScheme.of(ref.watch(currentAlbumProvider), brightness);
    return MaterialApp.router(
      title: 'Tidewater',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromScheme(scheme),
      themeAnimationDuration: Duration.zero,
      routerConfig: ref.watch(routerProvider),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
        dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.trackpad},
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final reduced = media.disableAnimations || reduceMotion;
        return MediaQuery(
          data: media.copyWith(disableAnimations: reduced),
          // The whole app recolors from the playing album's scheme.
          child: TweenAnimationBuilder<ColorScheme>(
            tween: ColorSchemeTween(end: scheme),
            duration: reduced ? Duration.zero : Motion.recolor,
            curve: Curves.easeInOut,
            builder: (context, animated, child) => Theme(data: AppTheme.fromScheme(animated), child: child!),
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => ref.read(pointerOriginProvider).value = e.position,
              child: child!,
            ),
          ),
        );
      },
    );
  }
}
