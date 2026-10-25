import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/lyrics_providers.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/opensubsonic_client.dart';
import 'package:tidewater/core/api/server_config.dart';
import 'package:tidewater/core/lyrics/lrclib.dart';
import 'package:tidewater/core/lyrics/lyrics.dart';
import 'package:tidewater/core/lyrics/structured_lyrics.dart';

import 'support/fake_library.dart';
import 'support/pump.dart';
import 'support/stub_adapter.dart';

OpenSubsonicClient _client(StubAdapter adapter) => OpenSubsonicClient(
      ServerConfig(baseUrl: Uri.parse('https://music.example.com'), credentials: const PasswordCredentials('u', 'p')),
      dio: stubDio(adapter),
      random: Random(1),
    );

void main() {
  group('server lyrics', () {
    test('prefers the synced version and sorts it by time', () async {
      final l = (await _client(StubAdapter((_) => StubResponse.fixture('lyrics_synced.json'))).getLyrics('t'))!;
      expect(l.synced, isTrue);
      expect(l.lines.map((x) => x.text), ['first line', 'second line', '']);
      expect(l.lines.first.time, const Duration(seconds: 3));
      expect(l.activeIndexAt(const Duration(seconds: 13)), 1);
    });

    test('plain lyrics are plain (never auto-scrolled)', () async {
      final l = (await _client(StubAdapter((_) => StubResponse.fixture('lyrics_plain.json'))).getLyrics('t'))!;
      expect(l.synced, isFalse);
      expect(l.lines.map((x) => x.text), ['just words', 'more words']);
    });

    test('a track with none gives null, not an error', () async {
      expect(await _client(StubAdapter((_) => StubResponse.fixture('lyrics_none.json'))).getLyrics('t'), isNull);
      expect(await _client(StubAdapter((_) => StubResponse.fixture('error_70.json'))).getLyrics('t'), isNull);
    });

    test('a server that does not know the call gives null', () async {
      expect(await _client(StubAdapter((_) => StubResponse('<html>404</html>', status: 404, contentType: 'text/html'))).getLyrics('t'), isNull);
    });

    test('a network failure is still an error (so it is not cached as "no lyrics")', () async {
      final c = _client(StubAdapter((_) => throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError)));
      expect(c.getLyrics('t'), throwsA(isA<ApiException>()));
    });

    test('parseStructuredLyrics copes with junk', () {
      expect(parseStructuredLyrics(null), isNull);
      expect(parseStructuredLyrics({'structuredLyrics': []}), isNull);
      expect(parseStructuredLyrics({'structuredLyrics': [{'line': []}]}), isNull);
      // "synced" without any timestamps is plain.
      expect(parseStructuredLyrics({'structuredLyrics': [{'synced': true, 'line': [{'value': 'a'}]}]})!.synced, isFalse);
    });
  });

  group('lrclib', () {
    test('synced lyrics win, then plain, instrumentals are none', () {
      final synced = parseLrclib({'syncedLyrics': '[00:01.00]hi\n[00:05.50]there', 'plainLyrics': 'hi\nthere'})!;
      expect(synced.synced, isTrue);
      expect(synced.lines[1].time, const Duration(milliseconds: 5500));
      final plain = parseLrclib({'syncedLyrics': null, 'plainLyrics': 'one\ntwo\r\nthree'})!;
      expect(plain.synced, isFalse);
      expect(plain.lines.map((l) => l.text), ['one', 'two', 'three']);
      expect(parseLrclib({'instrumental': true, 'plainLyrics': 'x'}), isNull);
      expect(parseLrclib({'syncedLyrics': '', 'plainLyrics': ' '}), isNull);
      expect(parseLrclib('nope'), isNull);
    });

    test('the lookup sends what lrclib needs and nothing else', () async {
      final adapter = StubAdapter((_) => StubResponse('{"plainLyrics":"la la"}'));
      final lrclib = LrclibClient(dio: Dio(BaseOptions(baseUrl: 'https://lrclib.net', validateStatus: (_) => true))..httpClientAdapter = adapter);
      final found = await lrclib.find(fakeTracks.first);
      expect(found?.lines.single.text, 'la la');
      final q = adapter.requests.single.queryParameters;
      expect(adapter.requests.single.host, 'lrclib.net');
      expect(q['artist_name'], 'Mira Vale');
      expect(q['track_name'], 'Lantern Season');
      expect(q['duration'], '200');
      expect(q.keys.toSet(), {'artist_name', 'track_name', 'album_name', 'duration'}, reason: 'no credentials, no ids');
    });

    test('not found and network trouble are just "none"', () async {
      Future<Lyrics?> run(StubAdapter a) =>
          LrclibClient(dio: Dio(BaseOptions(baseUrl: 'https://lrclib.net', validateStatus: (_) => true))..httpClientAdapter = a).find(fakeTracks.first);
      expect(await run(StubAdapter((_) => StubResponse('{}', status: 404))), isNull);
      expect(await run(StubAdapter((_) => throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionTimeout))), isNull);
    });
  });

  group('in the app', () {
    testWidgets('lyrics from the server show in Now Playing with the synced tag', (tester) async {
      final c = await pumpApp(tester);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
      await c.read(playbackProvider.notifier).toggle();
      c.read(nowPlayingOpenProvider.notifier).set(true);
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('Synced lyrics'), findsOneWidget);
      expect(find.byTooltip('Lyrics (L)'), findsOneWidget);
      expect(find.text('LYRICS'), findsOneWidget);
      c.read(nowPlayingOpenProvider.notifier).set(false);
      await advance(tester, const Duration(seconds: 1));
      await disposeApp(tester);
    });

    testWidgets('no lyrics anywhere: no lyrics button, no card, no tag', (tester) async {
      final api = FakeLibraryApi()..noLyricsFor.add('t-a0');
      final c = await pumpApp(tester, api: api);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
      await c.read(playbackProvider.notifier).toggle();
      c.read(nowPlayingOpenProvider.notifier).set(true);
      await advance(tester, const Duration(seconds: 2));
      expect(find.byTooltip('Lyrics (L)'), findsNothing);
      expect(find.text('Synced lyrics'), findsNothing);
      c.read(nowPlayingOpenProvider.notifier).set(false);
      await advance(tester, const Duration(seconds: 1));
      await disposeApp(tester);
    });

    testWidgets('lrclib fills in when the server has none, and only when allowed', (tester) async {
      final asked = <String>[];
      final api = FakeLibraryApi()..noLyricsFor.add('t-a0');
      final c = await pumpApp(tester, api: api, lrclib: (t) async {
        asked.add(t.id);
        return Lyrics.plain(['from', 'lrclib']);
      });
      c.listen(lyricsProvider, (_, _) {}); // what Now Playing does while it is open
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
      await c.read(playbackProvider.notifier).toggle();
      await advance(tester, const Duration(seconds: 1));
      expect(asked, ['t-a0']);
      expect(c.read(lyricsProvider).lines.map((l) => l.text), ['from', 'lrclib']);
      expect(c.read(lyricsProvider).synced, isFalse);

      // Switched off in Settings: the next track with no server lyrics is not looked up.
      c.read(lrclibEnabledProvider.notifier).set(false);
      api.noLyricsFor.add('t-a1');
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]);
      await c.read(playbackProvider.notifier).toggle();
      await advance(tester, const Duration(seconds: 1));
      expect(asked, ['t-a0']);
      expect(c.read(lyricsProvider).isEmpty, isTrue);
      await disposeApp(tester);
    });

    testWidgets('lyrics are fetched once per track, not on every rebuild', (tester) async {
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, api: api);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
      await c.read(playbackProvider.notifier).toggle();
      await advance(tester, const Duration(seconds: 2));
      c.read(nowPlayingOpenProvider.notifier).set(true);
      await advance(tester, const Duration(seconds: 2));
      expect(api.calls.where((x) => x == 'getLyrics:t-a0'), hasLength(1));
      c.read(nowPlayingOpenProvider.notifier).set(false);
      await advance(tester, const Duration(seconds: 1));
      await disposeApp(tester);
    });

    testWidgets('a server error while fetching lyrics does not break playback', (tester) async {
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, api: api);
      api.failWith = const ApiException(ApiErrorKind.unreachable, 'down');
      // The queue itself comes from tracks we already have.
      await c.read(playbackProvider.notifier).playTracks(fakeTracks.take(2).toList());
      await advance(tester, const Duration(seconds: 2));
      expect(c.read(lyricsProvider).isEmpty, isTrue);
      expect(c.read(playbackProvider).playing, isTrue);
      expect(tester.takeException(), isNull);
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });
  });

}
