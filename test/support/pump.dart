import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/playback/system_media.dart';
import 'package:tidewater/core/api/connect.dart';
import 'package:tidewater/core/api/session_store.dart';
import 'package:tidewater/core/lyrics/lyrics.dart';
import 'package:tidewater/core/models/track.dart';

import 'fake_library.dart';
import 'test_app.dart';

/// Pumps the whole app on an in-memory server and returns its container.
/// Call [disposeApp] at the end of a test that plays audio (the simulated
/// clock must stop).
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  FakeLibraryApi? api,
  bool signedIn = true,
  SessionStore? store,
  ClientFactory? factory,
  Map<String, Object> prefs = const {},
  Future<Lyrics?> Function(Track track)? lrclib,
  SystemMediaControls? media,
  Duration settle = const Duration(seconds: 2),
}) async {
  final overrides = await testOverrides(api: api, signedIn: signedIn, store: store, factory: factory, prefs: prefs, lrclib: lrclib, media: media);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: overrides,
    child: const TidewaterApp(),
  ));
  await advance(tester, settle);
  return ProviderScope.containerOf(tester.element(find.byType(TidewaterApp)));
}

/// Advances fake time in 100 ms frames so route and implicit animations run.
Future<void> advance(WidgetTester tester, Duration total) async {
  var left = total;
  while (left > Duration.zero) {
    final step = left > const Duration(milliseconds: 100) ? const Duration(milliseconds: 100) : left;
    await tester.pump(step);
    left -= step;
  }
}

Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await advance(tester, const Duration(seconds: 1));
}
