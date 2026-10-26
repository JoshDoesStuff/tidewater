import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';

import 'support/fake_library.dart';
import 'support/pump.dart';

void main() {
  testWidgets('walking through the main screens with accessibility on raises no semantics errors', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await pumpApp(tester);
    // Home with a hero row reshuffle, then each rail destination.
    for (final label in ['Library', 'Artists', 'Liked', 'Lists', 'Home']) {
      await tester.tap(find.text(label).first);
      await advance(tester, const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: label);
    }
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
    await advance(tester, const Duration(seconds: 1));
    c.read(nowPlayingOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 2));
    c.read(queueOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 1));
    await c.read(playbackProvider.notifier).next();
    await advance(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(tester.semantics.find(find.text('Queue')), isNotNull);
    c.read(nowPlayingOpenProvider.notifier).set(false);
    await advance(tester, const Duration(seconds: 1));
    await c.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
    handle.dispose();
  });
}
