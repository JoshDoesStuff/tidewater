import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show PopupMenuItem, TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/library_providers.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/core/models/album.dart';
import 'package:tidewater/core/models/track.dart';
import 'package:tidewater/ui/pages/widgets/album_card.dart';
import 'package:tidewater/ui/widgets/expressive_buttons.dart';
import 'package:tidewater/ui/widgets/shapes/morph_shape.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

Future<ProviderContainer> openSongs(WidgetTester tester, {FakeLibraryApi? api}) async {
  final c = await pumpApp(tester, api: api);
  await tester.tap(find.text('Library'));
  await advance(tester, const Duration(seconds: 2));
  await tester.tap(find.widgetWithText(ExpressiveChip, 'Songs'));
  await advance(tester, const Duration(seconds: 2));
  return c;
}

void main() {
  testWidgets('the Songs tab lists every song, sorted by title, with a count', (tester) async {
    final c = await openSongs(tester);
    expect(find.text('${fakeTracks.length} songs'), findsOneWidget);
    final titles = c.read(sortedSongsProvider).requireValue.songs.map((t) => t.title.toLowerCase()).toList();
    expect(titles, [...titles]..sort());
    expect(find.text('Afterglow'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('tapping a song plays from it with the whole list queued', (tester) async {
    final c = await openSongs(tester);
    await tester.tap(find.text('Afterglow'));
    await advance(tester, const Duration(seconds: 1));
    final s = c.read(playbackProvider);
    expect(s.track?.title, 'Afterglow');
    expect(s.queue.length, fakeTracks.length);
    expect(s.playing, isTrue);
    await c.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
  });

  testWidgets('sorting by artist reorders the list', (tester) async {
    final c = await openSongs(tester);
    await tester.tap(find.text('Title').first);
    await advance(tester, const Duration(milliseconds: 600));
    await tester.tap(find.widgetWithText(PopupMenuItem<SongSort>, 'Artist'));
    await advance(tester, const Duration(seconds: 1));
    final artists = c.read(sortedSongsProvider).requireValue.songs.map((t) => t.artist.toLowerCase()).toList();
    expect(artists, [...artists]..sort());
    expect(c.read(librarySongSortProvider), SongSort.artist);
    await disposeApp(tester);
  });

  testWidgets('a big library loads in pages and shows its full count', (tester) async {
    final songs = [
      for (var i = 0; i < 1300; i++)
        Track(id: 's$i', title: 'Song ${i.toString().padLeft(4, '0')}', artist: 'A', albumId: 'x', albumTitle: 'X', duration: const Duration(seconds: 100)),
    ];
    final api = FakeLibraryApi()..songs = songs;
    await openSongs(tester, api: api);
    await advance(tester, const Duration(seconds: 2));
    expect(find.text('1300 songs'), findsOneWidget);
    expect(api.calls.where((x) => x.startsWith('getSongs')), ['getSongs:0', 'getSongs:200', 'getSongs:700', 'getSongs:1200']);
    await disposeApp(tester);
  });

  testWidgets('songs are only fetched when the Songs tab is open', (tester) async {
    final api = FakeLibraryApi();
    await pumpApp(tester, api: api);
    await tester.tap(find.text('Library'));
    await advance(tester, const Duration(seconds: 2));
    expect(api.calls.where((x) => x.startsWith('getSongs')), isEmpty);
    await disposeApp(tester);
  });

  testWidgets('a library without songs says so', (tester) async {
    final api = FakeLibraryApi()..songs = [];
    await openSongs(tester, api: api);
    expect(find.text('No songs yet'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('the sort menu opens below its pill, not on top of it', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Library'));
    await advance(tester, const Duration(seconds: 2));
    final pill = tester.getRect(find.text('Recently added').first);
    await tester.tap(find.text('Recently added').first);
    await advance(tester, const Duration(milliseconds: 600));
    final item = tester.getRect(find.widgetWithText(PopupMenuItem<LibrarySort>, 'Artist'));
    expect(item.top, greaterThan(pill.bottom), reason: 'menu item at ${item.top}, pill bottom at ${pill.bottom}');
    await tester.tap(find.widgetWithText(PopupMenuItem<LibrarySort>, 'Artist'));
    await advance(tester, const Duration(seconds: 1));
    await disposeApp(tester);
  });

  testWidgets('the genre filter is a popup box with search, so hundreds of genres are easy', (tester) async {
    final albums = [
      for (var i = 0; i < 400; i++)
        Album(id: 'g$i', title: 'Album $i', artist: 'A', coverArt: 'c$i', genre: 'Genre ${i.toString().padLeft(3, '0')}'),
    ];
    await pumpApp(tester, api: FakeLibraryApi(albums: albums));
    await tester.tap(find.text('Library'));
    await advance(tester, const Duration(seconds: 3));
    await tester.tap(find.text('Genre').first);
    await advance(tester, const Duration(milliseconds: 700));
    expect(find.text('400 genres'), findsOneWidget);
    expect(find.text('All genres'), findsOneWidget);
    expect(find.text('Search genres'), findsOneWidget);
    // Type to find one of the 400.
    await tester.enterText(find.byType(TextField).last, 'genre 399');
    await advance(tester, const Duration(milliseconds: 300));
    expect(find.text('Genre 399'), findsOneWidget);
    expect(find.text('Genre 001'), findsNothing);
    expect(find.text('All genres'), findsNothing, reason: 'a search narrows the list');
    await tester.tap(find.text('Genre 399'));
    await advance(tester, const Duration(seconds: 1));
    expect(find.text('1 genre 399 album'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('the genre box: Enter picks the first match, a miss says so, All genres clears', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Library'));
    await advance(tester, const Duration(seconds: 2));
    await tester.tap(find.text('Genre').first);
    await advance(tester, const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField).last, 'zzz');
    await advance(tester, const Duration(milliseconds: 300));
    expect(find.textContaining('No genre matches'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'folk');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await advance(tester, const Duration(seconds: 1));
    expect(find.text('3 folk albums'), findsOneWidget);
    // Back to everything.
    await tester.tap(find.text('Folk').first);
    await advance(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('All genres'));
    await advance(tester, const Duration(seconds: 1));
    expect(find.text('12 albums'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('an album tile spins while hovered and stops after', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Library'));
    await advance(tester, const Duration(seconds: 2));
    double spinOf(Finder card) => tester.widget<MorphShape>(find.descendant(of: card, matching: find.byType(MorphShape)).first).spin;
    final card = find.byType(AlbumCard).first;
    expect(spinOf(card), 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card) - const Offset(0, 20));
    await advance(tester, const Duration(milliseconds: 600));
    expect(spinOf(card), greaterThan(0));
    await mouse.moveTo(const Offset(5, 5));
    await advance(tester, const Duration(milliseconds: 600));
    expect(spinOf(card), 0);
    await mouse.removePointer();
    await disposeApp(tester);
  });
}
