import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/core/models/track.dart';

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
  testWidgets('the mini player slides its controls when the title length changes instead of jumping', (tester) async {
    final container = await pumpApp(tester);
    final tracks = [_track('l', 'A very long title that cannot fit the pill'), _track('s', 'Hi')];
    await container.read(playbackProvider.notifier).playTracks(tracks);
    await advance(tester, const Duration(seconds: 1));
    final before = tester.getCenter(find.byTooltip('Next')).dx;

    await container.read(playbackProvider.notifier).next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final mid = tester.getCenter(find.byTooltip('Next')).dx;
    await advance(tester, const Duration(seconds: 1));
    final after = tester.getCenter(find.byTooltip('Next')).dx;

    expect(after, lessThan(before), reason: 'a shorter title pulls the controls left');
    expect(mid, lessThan(before));
    expect(mid, greaterThan(after), reason: 'mid-animation, not already at the end');
    await container.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
  });

  testWidgets('the mini player has a heart that likes the playing song', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await pumpApp(tester);
    final track = _track('h', 'Hearted');
    await container.read(playbackProvider.notifier).playTracks([track]);
    await advance(tester, const Duration(seconds: 1));
    await tester.tap(find.bySemanticsLabel('Like'));
    await advance(tester, const Duration(seconds: 1));
    expect(container.read(likedProvider), contains('h'));
    await container.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
    handle.dispose();
  });
}
