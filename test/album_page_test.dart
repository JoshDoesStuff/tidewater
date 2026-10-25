import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/ui/widgets/effects/eq_bars.dart';
import 'package:tidewater/ui/widgets/expressive_buttons.dart';

import 'support/fake_library.dart';
import 'support/pump.dart';

Future<ProviderContainer> openAlbum(WidgetTester tester, String id, {FakeLibraryApi? api}) async {
  final c = await pumpApp(tester, api: api);
  c.read(routerProvider).go('/album/$id');
  await advance(tester, const Duration(seconds: 2));
  return c;
}


void main() {
  group('album page', () {
    testWidgets('shows the album and its tracks', (tester) async {
      await openAlbum(tester, 'a1');
      expect(find.text('ALBUM · 2019 · ELECTRONIC'), findsOneWidget);
      expect(find.text('Koji & the Static'), findsOneWidget);
      expect(find.text('3 songs · 10 min'), findsOneWidget);
      expect(find.text('Last Tram Home'), findsOneWidget);
      expect(find.text('Last Tram Home 2'), findsOneWidget);
      expect(find.text('Last Tram Home 3'), findsOneWidget);
      expect(find.text('3:20'), findsNWidgets(3));
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('Play queues the whole album; the playing track gets the equalizer', (tester) async {
      final c = await openAlbum(tester, 'a1');
      await tester.tap(find.text('Play'));
      await advance(tester, const Duration(seconds: 1));
      expect(c.read(playbackProvider).queue.map((t) => t.id), ['t-a1', 't-a1-1', 't-a1-2']);
      expect(c.read(playbackProvider).playing, isTrue);
      expect(find.byType(MiniEq), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget, reason: 'the button now pauses');
      await tester.tap(find.text('Pause'));
      await advance(tester, const Duration(seconds: 1));
      expect(c.read(playbackProvider).playing, isFalse);
      expect(find.text('Resume'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('tapping a track plays from there, tapping the playing one pauses it', (tester) async {
      final c = await openAlbum(tester, 'a1');
      await tester.tap(find.text('Last Tram Home 2'));
      await advance(tester, const Duration(seconds: 1));
      expect(c.read(playbackProvider).track?.id, 't-a1-1');
      expect(c.read(playbackProvider).queue, hasLength(3), reason: 'the whole album stays queued');
      expect(c.read(playbackProvider).playing, isTrue);
      await tester.tap(find.text('Last Tram Home 2').first); // the mini player shows it too
      await advance(tester, const Duration(seconds: 1));
      expect(c.read(playbackProvider).playing, isFalse);
      expect(c.read(playbackProvider).track?.id, 't-a1-1');
      await disposeApp(tester);
    });

    testWidgets('Shuffle plays the album shuffled', (tester) async {
      final c = await openAlbum(tester, 'a1');
      await tester.tap(find.text('Shuffle'));
      await advance(tester, const Duration(seconds: 1));
      final s = c.read(playbackProvider);
      expect(s.shuffle, isTrue);
      expect({...s.queue.map((t) => t.id)}, {'t-a1', 't-a1-1', 't-a1-2'});
      expect(s.playing, isTrue);
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('the heart on a row stars the track on the server', (tester) async {
      final api = FakeLibraryApi();
      final c = await openAlbum(tester, 'a1', api: api);
      final heart = find.byIcon(Icons.favorite_border_rounded).first;
      await tester.tap(heart, warnIfMissed: false);
      await advance(tester, const Duration(milliseconds: 600));
      expect(api.calls.where((x) => x.startsWith('star:')), isNotEmpty);
      expect(c.read(likedProvider), isNotEmpty);
      await disposeApp(tester);
    });

    testWidgets('hearts the server already has are filled in', (tester) async {
      await openAlbum(tester, 'a2');
      // The filled heart on the row, and the Liked item in the rail.
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
      await disposeApp(tester);
    });

    testWidgets('the row menu adds to the queue and plays next', (tester) async {
      final c = await openAlbum(tester, 'a1');
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
      await advance(tester, const Duration(seconds: 1));
      await tester.tap(find.byIcon(Icons.more_vert_rounded).at(1));
      await advance(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Play next'));
      await advance(tester, const Duration(milliseconds: 500));
      expect(c.read(playbackProvider).queue.map((t) => t.id), ['t-a0', 't-a1-1']);
      await tester.tap(find.byIcon(Icons.more_vert_rounded).at(2));
      await advance(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Add to queue'));
      await advance(tester, const Duration(milliseconds: 500));
      expect(c.read(playbackProvider).queue.map((t) => t.id), ['t-a0', 't-a1-1', 't-a1-2']);
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('back returns to the page before, and the rail keeps Library selected', (tester) async {
      final c = await pumpApp(tester);
      await tester.tap(find.text('Library'));
      await advance(tester, const Duration(seconds: 2));
      c.read(routerProvider).push('/album/a0');
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('ALBUM · 2021 · INDIE'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('12 albums'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('opened directly, back goes to the Library', (tester) async {
      await openAlbum(tester, 'a0');
      await tester.tap(find.byTooltip('Back'));
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('12 albums'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('an album that is gone shows a message with Retry', (tester) async {
      await openAlbum(tester, 'nope');
      expect(find.text('That item no longer exists on the server.'), findsNothing); // fake says "gone"
      expect(find.text('gone'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('an unreachable server shows the offline message and recovers on Retry', (tester) async {
      final api = FakeLibraryApi();
      final c = await pumpApp(tester, api: api);
      api.failWith = const ApiException(ApiErrorKind.unreachable, 'down');
      c.read(routerProvider).go('/album/a0');
      await advance(tester, const Duration(seconds: 2));
      expect(find.textContaining('Can\'t reach your server'), findsOneWidget);
      api.failWith = null;
      await tester.tap(find.text('Retry'));
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('Lantern Season'), findsWidgets);
      await disposeApp(tester);
    });

    testWidgets('a card title opens the album; the artist under it opens the artist', (tester) async {
      final c = await pumpApp(tester);
      await tester.tap(find.text('Library'));
      await advance(tester, const Duration(seconds: 2));
      await tester.tap(find.text('Night Transit'));
      await advance(tester, const Duration(seconds: 2));
      expect(c.read(routerProvider).state.uri.path, '/album/a1');
      expect(c.read(playbackProvider).queue, isEmpty, reason: 'opening is not playing');
      await tester.tap(find.text('Koji & the Static'));
      await advance(tester, const Duration(seconds: 2));
      expect(c.read(routerProvider).state.uri.path, '/artist/ar-a1');
      await disposeApp(tester);
    });

    testWidgets('Now Playing links to the playing album and closes', (tester) async {
      final c = await pumpApp(tester);
      await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[3]);
      await c.read(playbackProvider.notifier).toggle();
      c.read(nowPlayingOpenProvider.notifier).set(true);
      await advance(tester, const Duration(seconds: 2));
      await tester.tap(find.text('ALBUM · PAPER SATELLITES'));
      await advance(tester, const Duration(seconds: 2));
      expect(c.read(nowPlayingOpenProvider), isFalse);
      expect(c.read(routerProvider).state.uri.path, '/album/a3');
      expect(find.text('ALBUM · 2018 · INDIE'), findsOneWidget);
      await disposeApp(tester);
    });
  });

  group('artist page', () {
    testWidgets('lists the artist\'s albums and plays them', (tester) async {
      final c = await pumpApp(tester);
      c.read(routerProvider).go('/artist/ar-a2');
      await advance(tester, const Duration(seconds: 2));
      expect(find.text('ARTIST'), findsOneWidget);
      expect(find.text('1 album'), findsOneWidget);
      expect(find.text('Low Tide Letters'), findsOneWidget);
      await tester.tap(find.text('Play'));
      await advance(tester, const Duration(seconds: 1));
      expect(c.read(playbackProvider).track?.artist, 'Ana Soleil');
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });

    testWidgets('Shuffle turns shuffle on', (tester) async {
      final c = await pumpApp(tester);
      c.read(routerProvider).go('/artist/ar-a1');
      await advance(tester, const Duration(seconds: 2));
      await tester.tap(find.widgetWithText(ExpressivePillButton, 'Shuffle'));
      await advance(tester, const Duration(seconds: 1));
      expect(c.read(playbackProvider).shuffle, isTrue);
      await c.read(playbackProvider.notifier).toggle();
      await disposeApp(tester);
    });
  });

}
