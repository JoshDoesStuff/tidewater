import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('pausing wakes Now Playing from idle straight away', (tester) async {
    final c = await pumpApp(tester);
    final player = c.read(playbackProvider.notifier);
    // Start paused, open Now Playing, then press play: the simulated clock does not
    // advance under the test clock, so a fresh start would stay "buffering" and never idle.
    await player.playAlbum(fakeAlbums[1]);
    await player.toggle();
    await advance(tester, const Duration(milliseconds: 600));
    c.read(nowPlayingOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 2));
    await player.toggle();
    await advance(tester, const Duration(seconds: 6));
    expect(c.read(idleProvider), isTrue, reason: 'playing with no input');

    await player.toggle(); // pause
    await advance(tester, const Duration(milliseconds: 60));
    expect(c.read(idleProvider), isFalse, reason: 'not left idle until the next check');

    c.read(nowPlayingOpenProvider.notifier).set(false);
    await advance(tester, const Duration(seconds: 1));
    await disposeApp(tester);
  });
}
