import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/models/track.dart';

import '../support/finders.dart';
import '../support/pump.dart';

Track _track(String id, String title) => Track(
      id: id,
      title: title,
      artist: 'Someone',
      albumId: 'a-$id',
      albumTitle: 'Album',
      duration: const Duration(seconds: 200),
    );

void main() {
  testWidgets('a long title shrinks inside its slot; the controls stay where they were', (tester) async {
    final c = await pumpApp(tester);
    final tracks = [_track('s', 'Hi'), _track('l', 'Under the Bells (Pre-Vocal Instrumental Mix) Extended')];
    await c.read(playbackProvider.notifier).playTracks(tracks);
    await c.read(playbackProvider.notifier).toggle();
    c.read(nowPlayingOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 2));
    final short = tester.getCenter(byHint('Shuffle')).dy;

    await c.read(playbackProvider.notifier).next();
    await advance(tester, const Duration(seconds: 2));
    final long = tester.getCenter(byHint('Shuffle')).dy;
    expect(long, short, reason: 'no jump between a short and a long title');

    c.read(nowPlayingOpenProvider.notifier).set(false);
    await advance(tester, const Duration(seconds: 1));
    await disposeApp(tester);
  });
}
