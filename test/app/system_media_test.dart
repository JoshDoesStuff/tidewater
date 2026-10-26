import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/playback/system_media.dart';
import 'package:tidewater/app/providers/playback_providers.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';
import '../support/recording_media.dart';

void main() {
  testWidgets('tells Windows what is playing, and whether it is playing', (tester) async {
    final media = RecordingMedia();
    final c = await pumpApp(tester, media: media);
    expect(media.log, ['clear'], reason: 'nothing playing: the overlay is emptied');
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(seconds: 1));
    expect(media.log, contains('track:Lantern Season|Mira Vale|Glass Orchard'));
    expect(media.lastThumbnail, 'http://test.local/rest/getCoverArt?id=cv-a0&size=300', reason: 'the overlay loads the cover from the server itself');
    expect(media.log, contains('playing'));
    expect(media.log, contains('timeline:0/200'));
    await c.read(playbackProvider.notifier).toggle();
    await advance(tester, const Duration(milliseconds: 300));
    expect(media.log.last, 'timeline:0/200', reason: 'pausing refreshes the timeline');
    expect(media.log, contains('paused'));
    await disposeApp(tester);
  });

  testWidgets('a new track updates it', (tester) async {
    final media = RecordingMedia();
    final c = await pumpApp(tester, media: media);
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
    await advance(tester, const Duration(seconds: 1));
    await c.read(playbackProvider.notifier).next();
    await advance(tester, const Duration(seconds: 1));
    expect(media.log.where((l) => l.startsWith('track:')), ['track:Last Tram Home|Koji & the Static|Night Transit', 'track:Last Tram Home 2|Koji & the Static|Night Transit']);
    await c.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
  });

  testWidgets('the timeline is only sent when the position jumps, not on every tick', (tester) async {
    final media = RecordingMedia();
    final c = await pumpApp(tester, media: media);
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(seconds: 1));
    final before = media.log.where((l) => l.startsWith('timeline')).length;
    final position = c.read(positionProvider);
    for (var i = 1; i <= 200; i++) {
      position.value = Duration(milliseconds: i * 100); // 20 s of normal playback
    }
    expect(media.log.where((l) => l.startsWith('timeline')).length, before, reason: 'Windows counts by itself');
    position.value = const Duration(seconds: 120); // a seek
    expect(media.lastPosition, const Duration(seconds: 120));
    await c.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
  });

  testWidgets('media keys and overlay buttons control playback', (tester) async {
    final media = RecordingMedia();
    final c = await pumpApp(tester, media: media);
    final player = c.read(playbackProvider.notifier);
    await player.playAlbum(fakeAlbums[1]);
    await advance(tester, const Duration(milliseconds: 500));

    media.press(SystemMediaButton.pause);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(playbackProvider).playing, isFalse);
    media.press(SystemMediaButton.pause);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(playbackProvider).playing, isFalse, reason: 'pause while paused does nothing');

    media.press(SystemMediaButton.play);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(playbackProvider).playing, isTrue);

    media.press(SystemMediaButton.next);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(playbackProvider).track?.id, 't-a1-1');

    media.press(SystemMediaButton.previous);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(playbackProvider).track?.id, 't-a1');

    media.press(SystemMediaButton.stop);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(playbackProvider).playing, isFalse);
    await disposeApp(tester);
  });

  testWidgets('emptying the queue clears the overlay', (tester) async {
    final media = RecordingMedia();
    final c = await pumpApp(tester, media: media);
    final player = c.read(playbackProvider.notifier);
    await player.playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(milliseconds: 500));
    await player.stop();
    await advance(tester, const Duration(milliseconds: 500));
    expect(media.log.last, 'clear');
    await disposeApp(tester);
  });
}
