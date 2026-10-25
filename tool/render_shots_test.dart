// Offscreen renders of the app for visual review (the real window can't be
// captured when the desktop is locked). Not part of the normal suite:
//
//   flutter test tool/render_shots_test.dart
//
// Writes PNGs to `build/shots/`. Uses Flutter's bundled Roboto + Material
// Icons so text and icons look like the real app.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';

import '../test/support/fake_library.dart';
import '../test/support/test_app.dart';

Future<void> _loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  final dir = '$sdk/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String name) async => ByteData.sublistView(await File('$dir/$name').readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
    roboto.addFont(bytes(f));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(bytes('materialicons-regular.otf'));
  await icons.load();
}

Future<void> _advance(WidgetTester t, Duration total) async {
  var left = total;
  while (left > Duration.zero) {
    final step = left > const Duration(milliseconds: 50) ? const Duration(milliseconds: 50) : left;
    await t.pump(step);
    left -= step;
  }
}

void main() {
  loginShots();
  testWidgets('render shots', (tester) async {
    debugPrint('step: fonts');
    await tester.runAsync(_loadFonts);
    debugPrint('step: fonts done');
    final overrides = await testOverrides();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ProviderScope(
        retry: (_, _) => null,
        overrides: overrides,
        child: const TidewaterApp(),
      ),
    ));
    final container = ProviderScope.containerOf(tester.element(find.byType(TidewaterApp)));
    Directory('build/shots').createSync(recursive: true);

    Future<void> shot(String name) async {
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('build/shots/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    debugPrint('step: pumped');
    await _advance(tester, const Duration(seconds: 2));
    debugPrint('step: advanced');
    await shot('01-home');
    debugPrint('step: shot1');

    // Hover a "Recently added" card.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(const Offset(452, 608));
    await _advance(tester, const Duration(milliseconds: 900));
    await shot('02-home-hover-card');

    // Hover a hero.
    await mouse.moveTo(const Offset(560, 380));
    await _advance(tester, const Duration(milliseconds: 1200));
    await shot('03-home-hover-hero');
    // Hover the avatar: circle springs into the scalloped shape.
    await mouse.moveTo(const Offset(1224, 64));
    await _advance(tester, const Duration(milliseconds: 1200));
    await shot('03b-avatar-hover');
    await mouse.moveTo(const Offset(700, 300));

    // Play an album: recolor, EQ badge, spinning mini cover.
    await container.read(playbackProvider.notifier).playAlbum(fakeAlbums[6]);
    await _advance(tester, const Duration(seconds: 3));
    await shot('04-home-playing');

    // Library.
    await tester.tap(find.text('Library'));
    await _advance(tester, const Duration(seconds: 2));
    await shot('05-library');

    // Now Playing.
    container.read(nowPlayingOpenProvider.notifier).set(true);
    await _advance(tester, const Duration(seconds: 3));
    await shot('06-now-playing');

    // Visualizer picker.
    container.read(vizPopupOpenProvider.notifier).set(true);
    await _advance(tester, const Duration(seconds: 1));
    await shot('07-now-playing-picker');
    container.read(vizPopupOpenProvider.notifier).set(false);
    await _advance(tester, const Duration(milliseconds: 500));

    // Idle (lyrics on), then lyrics off.
    await _advance(tester, const Duration(seconds: 6));
    await shot('08-idle-lyrics');
    container.read(lyricsOnProvider.notifier).toggle();
    await _advance(tester, const Duration(seconds: 2));
    await shot('09-idle-no-lyrics');

    // Back to normal with lyrics off, then close.
    container.read(lyricsOnProvider.notifier).toggle();
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await _advance(tester, const Duration(seconds: 2));
    await shot('10-now-playing-awake');

    container.read(nowPlayingOpenProvider.notifier).set(false);
    await container.read(playbackProvider.notifier).toggle();
    await _advance(tester, const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

void loginShots() {
  testWidgets('render login shots', (tester) async {
    await tester.runAsync(_loadFonts);
    final overrides = await testOverrides(signedIn: false, api: FakeLibraryApi(failWith: const ApiException(ApiErrorKind.badCredentials, 'Wrong username or password.')));
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ProviderScope(retry: (_, _) => null, overrides: overrides, child: const TidewaterApp()),
    ));
    Directory('build/shots').createSync(recursive: true);

    Future<void> shot(String name) async {
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('build/shots/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    await _advance(tester, const Duration(seconds: 2));
    await shot('00-login');
    await tester.enterText(find.byType(TextField).at(0), 'music.example.com');
    await tester.enterText(find.byType(TextField).at(1), 'josh');
    await tester.enterText(find.byType(TextField).at(2), 'wrong');
    await tester.tap(find.text('Connect'));
    await _advance(tester, const Duration(seconds: 2));
    await shot('00b-login-error');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
