import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart' show DragToResizeArea;

import 'providers/scheme_providers.dart';
import 'providers/session_providers.dart';
import 'providers/settings_providers.dart';
import 'router.dart';
import 'theme/album_scheme.dart';
import 'theme/app_theme.dart';
import 'theme/motion.dart';
import '../ui/shell/close_guard.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Signing in or out re-runs the router's redirect.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  final router = createRouter(
    signedIn: () => ref.read(sessionProvider) != null,
    refresh: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

final _themeMemo = ThemeMemo();

class TidewaterApp extends ConsumerWidget {
  const TidewaterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = ref.watch(reduceMotionProvider);
    final brightness = ref.watch(darkThemeProvider)
        ? Brightness.dark
        : Brightness.light;
    final scheme = AlbumScheme.of(ref.watch(schemeSeedProvider), brightness);
    return MaterialApp.router(
      title: 'Tidewater',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromScheme(scheme),
      themeAnimationDuration: Duration.zero,
      routerConfig: ref.watch(routerProvider),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
        },
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final reduced = media.disableAnimations || reduceMotion;
        return MediaQuery(
          data: media.copyWith(disableAnimations: reduced),
          // The whole app recolors from the playing album's scheme.
          // Frameless window: the edges resize it (see main.dart).
          child: CloseGuard(
            child: _resizable(
              TweenAnimationBuilder<ColorScheme>(
                tween: ColorSchemeTween(end: scheme),
                duration: reduced ? Duration.zero : Motion.recolor,
                curve: Curves.easeInOut,
                builder: (context, animated, child) => Theme(
                  data: _themeMemo.of(animated, AppTheme.fromScheme),
                  child: child!,
                ),
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (e) =>
                      ref.read(pointerOriginProvider).value = e.position,
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Resize edges for the frameless window (Windows only; elsewhere the system
/// frame does it).
Widget _resizable(Widget child) => !kIsWeb && Platform.isWindows
    ? DragToResizeArea(resizeEdgeSize: 6, child: child)
    : child;
