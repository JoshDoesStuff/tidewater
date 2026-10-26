import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/destinations.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  const sizes = {
    'the 720 x 520 minimum': Size(720, 520),
    'a small laptop': Size(1024, 640),
    'ultrawide': Size(3440, 1440),
    'a tall, narrow window': Size(800, 1200),
  };

  for (final MapEntry(key: label, value: size) in sizes.entries) {
    testWidgets('every main screen lays out without errors at $label', (tester) async {
      final c = await pumpApp(tester, size: size);
      for (final page in [...Destination.values.map((d) => d.path), '/home']) {
        c.read(routerProvider).go(page);
        await advance(tester, const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: '$page at $label');
      }
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
      await advance(tester, const Duration(seconds: 1));
      c.read(nowPlayingOpenProvider.notifier).set(true);
      await advance(tester, const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'Now Playing at $label');
      c.read(queueOpenProvider.notifier).set(true);
      await advance(tester, const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: 'the queue at $label');
      c.read(nowPlayingOpenProvider.notifier).set(false);
      await advance(tester, const Duration(seconds: 1));
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });
  }
}
