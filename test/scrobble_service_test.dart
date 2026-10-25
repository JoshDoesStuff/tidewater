import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';

import 'support/fake_library.dart';
import 'support/pump.dart';

/// Pretends the track has been playing up to [seconds] (the simulated clock
/// does not run under fake time), in 250 ms steps.
Future<void> listenTo(WidgetTester tester, ProviderContainer c, int seconds, {int from = 0}) async {
  final position = c.read(positionProvider);
  for (var i = from * 4; i <= seconds * 4; i++) {
    position.value = Duration(milliseconds: i * 250);
  }
  await tester.pump(const Duration(milliseconds: 50));
}

List<String> scrobbles(FakeLibraryApi api) => [
      for (final c in api.calls)
        if (c.startsWith('scrobble:')) c,
    ];

void main() {
  testWidgets('reports now playing, then a counted play after half the track', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]); // 200 s
    await advance(tester, const Duration(milliseconds: 500));
    expect(scrobbles(api), ['scrobble:t-a0:nowplaying']);

    await listenTo(tester, c, 60);
    expect(scrobbles(api), ['scrobble:t-a0:nowplaying'], reason: 'not yet half');
    await listenTo(tester, c, 105, from: 60);
    await advance(tester, const Duration(milliseconds: 200));
    expect(scrobbles(api), ['scrobble:t-a0:nowplaying', 'scrobble:t-a0:submission']);

    await listenTo(tester, c, 190, from: 105);
    expect(scrobbles(api), hasLength(2), reason: 'a play is counted once');
    await c.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
  });

  testWidgets('a counted play makes Home refresh its recently and most played rows', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    final before = api.calls.where((x) => x.startsWith('getAlbumList:recent')).length;
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(milliseconds: 500));
    await listenTo(tester, c, 105);
    await advance(tester, const Duration(seconds: 1));
    expect(api.calls.where((x) => x.startsWith('getAlbumList:recent')).length, greaterThan(before));
    await c.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
  });

  testWidgets('pausing stops the count', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    final player = c.read(playbackProvider.notifier);
    await player.playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(milliseconds: 500));
    await listenTo(tester, c, 50);
    await player.toggle(); // pause
    await advance(tester, const Duration(milliseconds: 200));
    await listenTo(tester, c, 150, from: 50);
    await advance(tester, const Duration(milliseconds: 200));
    expect(scrobbles(api).where((s) => s.endsWith('submission')), isEmpty);
    await disposeApp(tester);
  });

  testWidgets('a failed submission is kept and retried when the server is back', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(milliseconds: 500));
    api.failScrobbleWith = const ApiException(ApiErrorKind.unreachable, 'down');
    await listenTo(tester, c, 105);
    await advance(tester, const Duration(milliseconds: 200));
    expect(scrobbles(api).where((s) => s.endsWith('submission')), hasLength(1), reason: 'tried once, failed');

    api.failScrobbleWith = null;
    await advance(tester, const Duration(seconds: 65));
    expect(scrobbles(api).where((s) => s.endsWith('submission')), hasLength(2), reason: 'retried a minute later');
    await advance(tester, const Duration(seconds: 65));
    expect(scrobbles(api).where((s) => s.endsWith('submission')), hasLength(2), reason: 'and not again');
    await c.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
  });

  testWidgets('turning the setting off sends nothing', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    c.read(scrobbleEnabledProvider.notifier).set(false);
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(milliseconds: 500));
    await listenTo(tester, c, 120);
    await advance(tester, const Duration(milliseconds: 200));
    expect(scrobbles(api), isEmpty);
    await c.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
  });

  testWidgets('the Settings page has the toggles', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Settings'));
    await advance(tester, const Duration(seconds: 2));
    expect(find.text('Count plays on the server'), findsOneWidget);
    expect(find.text('Look up missing lyrics online'), findsOneWidget);
    await disposeApp(tester);
  });
}
