import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/core/models/track.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

Track _t(int i) => Track(
      id: 'big$i',
      title: 'Song $i',
      artist: 'Artist',
      albumId: 'a',
      albumTitle: 'Album',
      duration: const Duration(seconds: 200),
    );

void main() {
  testWidgets('Shuffle all queues every song in the library, shuffled, not a random handful', (tester) async {
    final big = [for (var i = 0; i < 1300; i++) _t(i)];
    final c = await pumpApp(tester, api: FakeLibraryApi()..songs = big);
    await c.read(playbackProvider.notifier).shuffleAll();
    await advance(tester, const Duration(seconds: 1));
    final s = c.read(playbackProvider);
    expect(s.queue.length, 1300, reason: 'all of them');
    expect(s.queue.map((t) => t.id).toSet().length, 1300, reason: 'each once');
    expect(s.shuffle, isTrue);
    final inOrder = [for (var i = 0; i < 1300; i++) 'big$i'];
    expect(s.queue.map((t) => t.id).toList(), isNot(inOrder), reason: 'in a shuffled order');
    await c.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
  });
}
