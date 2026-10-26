import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/queue_sync_status.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/app/providers/session_persistence.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/core/models/server_play_queue.dart';
import 'package:tidewater/core/playback/resume.dart';
import 'package:tidewater/core/playback/play_queue.dart';
import 'package:tidewater/core/playback/saved_session.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';
import '../support/test_app.dart';

SavedSession _local({DateTime? savedAt, int index = 1, Duration position = const Duration(seconds: 10)}) => SavedSession(
      server: serverKeyOf(testServer),
      tracks: fakeTracks.take(4).toList(),
      index: index,
      position: position,
      shuffled: true,
      repeat: LoopMode.all,
      volume: .4,
      savedAt: savedAt,
    );

ServerPlayQueue _remote({required String current, required Duration position, DateTime? changed, int count = 4}) => ServerPlayQueue(
      tracks: fakeTracks.take(count).toList(),
      currentId: current,
      position: position,
      changed: changed,
    );

void main() {
  final key = serverKeyOf(testServer);
  final t0 = DateTime.utc(2026, 10, 26, 12);

  group('chooseResume', () {
    test('without a server copy, this device\'s copy is used as is', () {
      final local = _local(savedAt: t0);
      expect(chooseResume(serverKey: key, local: local, server: null), same(local));
    });

    test('with only the server\'s copy, it is used with default settings', () {
      final s = chooseResume(serverKey: key, server: _remote(current: fakeTracks[2].id, position: const Duration(minutes: 1), changed: t0))!;
      expect(s.index, 2);
      expect(s.position, const Duration(minutes: 1));
      expect(s.tracks.length, 4);
    });

    test('a newer server copy of the same queue gives its position and keeps this device\'s shuffle and volume', () {
      final s = chooseResume(
        serverKey: key,
        local: _local(savedAt: t0),
        server: _remote(current: fakeTracks[1].id, position: const Duration(minutes: 3), changed: t0.add(const Duration(minutes: 20))),
      )!;
      expect(s.index, 1);
      expect(s.position, const Duration(minutes: 3));
      expect(s.shuffled, isTrue);
      expect(s.volume, .4);
    });

    test('a newer server queue from another device replaces the local one', () {
      final s = chooseResume(
        serverKey: key,
        local: _local(savedAt: t0),
        server: _remote(current: fakeTracks[5].id, position: const Duration(seconds: 5), changed: t0.add(const Duration(hours: 1)), count: 8),
      )!;
      expect(s.tracks.length, 8);
      expect(s.shuffled, isTrue, reason: 'player settings stay local');
    });

    test('an older server copy loses to this device\'s', () {
      final local = _local(savedAt: t0.add(const Duration(minutes: 5)));
      final s = chooseResume(
        serverKey: key,
        local: local,
        server: _remote(current: fakeTracks[3].id, position: const Duration(minutes: 9), changed: t0),
      );
      expect(s, same(local));
    });

    test('clock differences of a few seconds do not count as newer', () {
      final local = _local(savedAt: t0);
      final s = chooseResume(
        serverKey: key,
        local: local,
        server: _remote(current: fakeTracks[3].id, position: const Duration(minutes: 9), changed: t0.add(const Duration(seconds: 3))),
      );
      expect(s, same(local));
    });
  });

  group('with the server', () {
    testWidgets('the queue is picked up from the server when this device has none', (tester) async {
      final api = FakeLibraryApi()
        ..serverQueue = _remote(current: fakeTracks[2].id, position: const Duration(seconds: 95), changed: DateTime.now());
      final c = await pumpApp(tester, api: api);
      expect(c.read(playbackProvider).track?.id, fakeTracks[2].id);
      expect(c.read(playbackProvider).playing, isFalse);
      expect(c.read(positionProvider).value, const Duration(seconds: 95));
      await disposeApp(tester);
    });

    testWidgets('a server that fails to answer leaves this device\'s copy', (tester) async {
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, api: api, prefs: {'saved_session': _local().encode()});
      expect(c.read(playbackProvider).queue.length, 4);
      await disposeApp(tester);
    });

    testWidgets('pausing sends the queue and the position to the server', (tester) async {
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, api: api);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
      await advance(tester, const Duration(seconds: 1));
      c.read(positionProvider).value = const Duration(seconds: 61);
      await c.read(playbackProvider.notifier).toggle();
      await advance(tester, const Duration(seconds: 4));
      expect(api.queueSaves, isNotEmpty);
      expect(api.queueSaves.last.ids, ['t-a1', 't-a1-1', 't-a1-2']);
      expect(api.queueSaves.last.position, const Duration(seconds: 61));
      final status = c.read(queueSyncStatusProvider);
      expect(status.home, QueueHome.server);
      expect(status.songs, 3);
      await disposeApp(tester);
    });

    testWidgets('pausing saves the position at once, and flushing on close saves it too', (tester) async {
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, api: api);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
      await advance(tester, const Duration(seconds: 4));
      final before = api.queueSaves.length;
      c.read(positionProvider).value = const Duration(seconds: 33);
      await c.read(playbackProvider.notifier).toggle();
      await advance(tester, const Duration(milliseconds: 100));
      expect(api.queueSaves.length, before + 1, reason: 'no waiting a couple of seconds after a pause');
      expect(api.queueSaves.last.position, const Duration(seconds: 33));

      c.read(positionProvider).value = const Duration(seconds: 48);
      await flushSessionPersistence();
      expect(api.queueSaves.last.position, const Duration(seconds: 48));
      await disposeApp(tester);
    });

    testWidgets('while playing, the position goes to the server every 30 seconds, not to disk every 5', (tester) async {
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, api: api);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
      await advance(tester, const Duration(seconds: 3));
      c.read(playbackProvider.notifier).toggle(); // pause, then play again (under fake time it stays buffering)
      await advance(tester, const Duration(seconds: 3));
      await c.read(playbackProvider.notifier).toggle();
      final before = api.queueSaves.length;
      await advance(tester, const Duration(seconds: 65));
      expect(api.queueSaves.length - before, lessThanOrEqualTo(3));
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('the status says why the queue is on this PC when the server cannot keep it', (tester) async {
      final api = FakeLibraryApi()..queueFailWith = const ApiException(ApiErrorKind.server, 'The server had a problem (HTTP 500).');
      final c = await pumpApp(tester, api: api);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
      await advance(tester, const Duration(seconds: 4));
      final status = c.read(queueSyncStatusProvider);
      expect(status.home, QueueHome.thisPc);
      expect(status.reason, contains('HTTP 500'));
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('with syncing off nothing goes to the server', (tester) async {
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, api: api, prefs: {'sync_position': false});
      expect(c.read(syncPositionProvider), isFalse);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
      await advance(tester, const Duration(seconds: 4));
      await c.read(playbackProvider.notifier).toggle();
      await advance(tester, const Duration(seconds: 4));
      expect(api.queueSaves, isEmpty);
      await disposeApp(tester);
    });
  });
}
