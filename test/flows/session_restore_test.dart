import 'dart:convert';

import 'package:flutter/widgets.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/session_persistence.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/list_cache.dart';
import 'package:tidewater/core/models/track.dart';
import 'package:tidewater/core/playback/play_queue.dart';
import 'package:tidewater/core/playback/saved_session.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';
import '../support/test_app.dart';

SavedSession _saved({String? server, List<Track>? tracks, int index = 1, Duration? position}) => SavedSession(
      server: server ?? serverKeyOf(testServer),
      tracks: tracks ?? fakeTracks.take(4).toList(),
      index: index,
      position: position ?? const Duration(seconds: 42),
      shuffled: false,
      repeat: LoopMode.all,
      volume: .35,
    );

SavedSession? _stored(MemoryListStore store) {
  final list = store.saved['session'];
  return list == null || list.isEmpty ? null : SavedSession.decode(jsonEncode(list.first));
}

void main() {
  group('SavedSession', () {
    test('round trips a queue with everything the UI shows', () {
      final s = _saved();
      final back = SavedSession.decode(s.encode())!;
      expect(back.tracks.map((t) => t.id), s.tracks.map((t) => t.id));
      expect(back.index, 1);
      expect(back.position, const Duration(seconds: 42));
      expect(back.repeat, LoopMode.all);
      expect(back.volume, .35);
      expect(back.server, s.server);
      final t = back.tracks[1];
      expect(t.title, s.tracks[1].title);
      expect(t.coverArt, s.tracks[1].coverArt);
      expect(t.qualityLabel, s.tracks[1].qualityLabel);
      expect(t.duration, s.tracks[1].duration);
    });

    test('keeps the heart flag', () {
      final starred = fakeTracks.firstWhere((t) => t.starred);
      final back = SavedSession.decode(_saved(tracks: [starred], index: 0).encode())!;
      expect(back.tracks.single.starred, isTrue);
    });

    test('damaged or foreign data is ignored, never thrown', () {
      expect(SavedSession.decode(null), isNull);
      expect(SavedSession.decode(''), isNull);
      expect(SavedSession.decode('not json'), isNull);
      expect(SavedSession.decode('{"v":2,"tracks":[]}'), isNull);
      expect(SavedSession.decode('{"v":1,"tracks":[]}'), isNull);
      expect(SavedSession.decode('{"v":1,"tracks":[{"id":5}],"index":"x"}'), isNull);
      expect(SavedSession.decode('{"v":1,"tracks":"nope"}'), isNull);
    });

    test('an index outside the queue is pulled back in', () {
      final s = SavedSession.decode(_saved(index: 3).encode().replaceFirst('"index":3', '"index":99'))!;
      expect(s.index, 3);
    });

    test('very long queues are cut around the current track', () {
      final many = [
        for (var i = 0; i < 2500; i++)
          Track(id: 't$i', title: 'T$i', artist: 'a', albumId: 'x', albumTitle: 'x', duration: const Duration(seconds: 1)),
      ];
      final back = SavedSession.decode(_saved(tracks: many, index: 1800).encode())!;
      expect(back.tracks.length, SavedSession.maxTracks);
      expect(back.tracks[back.index].id, 't1800');
    });
  });

  group('restoring at launch', () {
    testWidgets('puts the queue back paused, at the saved position, with the saved settings', (tester) async {
      final c = await pumpApp(tester, prefs: {'saved_session': _saved().encode()});
      final s = c.read(playbackProvider);
      expect(s.queue.length, 4);
      expect(s.track?.id, fakeTracks[1].id);
      expect(s.playing, isFalse);
      expect(s.repeat, LoopMode.all);
      expect(s.volume, .35);
      expect(c.read(positionProvider).value, const Duration(seconds: 42));
      expect(find.text(fakeTracks[1].title), findsWidgets, reason: 'mini player shows it');
      await disposeApp(tester);
    });

    testWidgets('does not wash the screen or start playing', (tester) async {
      final c = await pumpApp(tester, prefs: {'saved_session': _saved().encode()});
      expect(c.read(playbackProvider).playing, isFalse);
      await disposeApp(tester);
    });

    testWidgets('another server\'s saved queue is not restored', (tester) async {
      final c = await pumpApp(tester, prefs: {'saved_session': _saved(server: 'https://elsewhere.example|josh').encode()});
      expect(c.read(playbackProvider).queue, isEmpty);
      await disposeApp(tester);
    });

    testWidgets('a corrupt save starts the app normally', (tester) async {
      final c = await pumpApp(tester, prefs: {'saved_session': '{broken'});
      expect(c.read(playbackProvider).queue, isEmpty);
      expect(find.text('Jump back in'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('the saved volume applies even with nothing queued', (tester) async {
      final c = await pumpApp(tester, prefs: {'player.volume': 0.2});
      expect(c.read(playbackProvider).volume, .2);
      await disposeApp(tester);
    });
  });

  group('saving', () {
    testWidgets('a new queue goes to the server, not to the disk; shuffle, repeat and volume go to the settings', (tester) async {
      final store = MemoryListStore();
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, listStore: store, api: api);
      final prefs = c.read(sharedPreferencesProvider);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
      await advance(tester, const Duration(seconds: 4));
      expect(api.serverQueue!.tracks.map((t) => t.id), ['t-a1', 't-a1-1', 't-a1-2']);
      expect(_stored(store), isNull, reason: 'the server holds it, so there is nothing to write here');

      await c.read(playbackProvider.notifier).toggleRepeat();
      await c.read(playbackProvider.notifier).setVolume(.55);
      await advance(tester, const Duration(seconds: 2));
      expect(prefs.getString('player.repeat'), 'all');
      expect(prefs.getDouble('player.volume'), .55);
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('the position goes to the server when pausing', (tester) async {
      final store = MemoryListStore();
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, listStore: store, api: api);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
      await advance(tester, const Duration(seconds: 1));
      c.read(positionProvider).value = const Duration(seconds: 77);
      await c.read(playbackProvider.notifier).toggle();
      await advance(tester, const Duration(seconds: 4));
      expect(api.serverQueue!.position, const Duration(seconds: 77));
      expect(_stored(store), isNull);
      await disposeApp(tester);
    });

    testWidgets('a server that cannot keep the queue gets a copy on this PC instead', (tester) async {
      final store = MemoryListStore();
      final api = FakeLibraryApi()..queueFailWith = const ApiException(ApiErrorKind.server, 'not supported');
      final c = await pumpApp(tester, listStore: store, api: api);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
      await advance(tester, const Duration(seconds: 4));
      expect(_stored(store)!.tracks.map((t) => t.id), ['t-a1', 't-a1-1', 't-a1-2']);
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('with syncing off the queue is written to this PC', (tester) async {
      final store = MemoryListStore();
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, listStore: store, api: api, prefs: {'sync_position': false});
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
      await advance(tester, const Duration(seconds: 4));
      expect(_stored(store)!.tracks.length, 3);
      expect(api.serverQueue, isNull);
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('signing out forgets the queue', (tester) async {
      final store = MemoryListStore();
      final c = await pumpApp(tester, listStore: store, prefs: {'saved_session': _saved().encode()});
      final prefs = c.read(sharedPreferencesProvider);
      expect(c.read(playbackProvider).queue, isNotEmpty, reason: 'an old save in the settings moves over');
      expect(prefs.getString('saved_session'), isNull, reason: 'and is removed from the settings file');
      await tester.tap(find.byKey(const Key('account-avatar')));
      await advance(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Sign out or switch server'));
      await advance(tester, const Duration(seconds: 2));
      expect(store.saved['session'], isEmpty, reason: 'the file no longer holds a queue');
      await disposeApp(tester);
    });
  });

  group('hearts', () {
    testWidgets('tracks the server says are starred start out hearted', (tester) async {
      final c = await pumpApp(tester);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[2]);
      await advance(tester, const Duration(seconds: 1));
      expect(c.read(likedProvider), contains('t-a2'));
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('toggling stars and unstars on the server', (tester) async {
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, api: api);
      final track = fakeTracks.first;
      await c.read(likedProvider.notifier).toggle(track);
      expect(c.read(likedProvider), contains(track.id));
      expect(api.calls, contains('star:${track.id}'));
      await c.read(likedProvider.notifier).toggle(track);
      expect(c.read(likedProvider), isNot(contains(track.id)));
      expect(api.calls, contains('unstar:${track.id}'));
      await disposeApp(tester);
    });

    testWidgets('a failed heart goes back and says why', (tester) async {
      final api = FakeLibraryApi(failWith: null)..failStarWith = const ApiException(ApiErrorKind.unreachable, 'down');
      final c = await pumpApp(tester, api: api);
      final track = fakeTracks.first;
      await c.read(likedProvider.notifier).toggle(track);
      expect(c.read(likedProvider), isNot(contains(track.id)), reason: 'rolled back');
      expect(c.read(toastProvider)?.error, isTrue);
      await advance(tester, const Duration(seconds: 5));
      await disposeApp(tester);
    });

    testWidgets('a restored queue does not un-heart anything', (tester) async {
      final c = await pumpApp(tester, prefs: {'saved_session': _saved(tracks: [fakeTracks[0]], index: 0).encode()});
      c.read(likedProvider.notifier).seed([fakeTracks[0]], addOnly: true);
      await c.read(likedProvider.notifier).toggle(fakeTracks[0]);
      c.read(likedProvider.notifier).seed([fakeTracks[0]], addOnly: true);
      expect(c.read(likedProvider), contains(fakeTracks[0].id), reason: 'stale unstarred data must not remove it');
      await disposeApp(tester);
    });
  });
}
