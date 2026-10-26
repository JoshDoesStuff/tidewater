import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show TextField;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/library_providers.dart';
import 'package:tidewater/app/providers/playlist_actions.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/models/playlist.dart';
import 'package:tidewater/ui/pages/widgets/song_row.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

// "Late Night Drive" (pl-1) holds 'Lantern Season' and 'Last Tram Home'; "Focus" (pl-2) holds 'Lantern Season'.
const _inBoth = 'Lantern Season';
const _inNeither = 'Afterglow';

/// Opens the Library's Songs tab and returns the container.
Future<ProviderContainer> _songs(WidgetTester tester, FakeLibraryApi api) async {
  final c = await pumpApp(tester, api: api);
  c.read(libraryTabProvider.notifier).set(LibraryTab.songs);
  c.read(routerProvider).go('/library');
  await advance(tester, const Duration(seconds: 2));
  return c;
}

Future<void> _openPicker(WidgetTester tester, String song) async {
  await tester.tap(find.widgetWithText(SongRow, song), buttons: kSecondaryButton);
  await advance(tester, const Duration(milliseconds: 400));
  await tester.tap(find.text('Add to playlist…'));
  await advance(tester, const Duration(milliseconds: 500));
}

Future<void> _addTo(WidgetTester tester, String song, String playlist) async {
  await _openPicker(tester, song);
  await tester.tap(find.text(playlist));
  await advance(tester, const Duration(seconds: 1));
}

void main() {
  testWidgets('a song that is not in the playlist is added without a question, and the toast says so', (tester) async {
    final api = FakeLibraryApi();
    final c = await _songs(tester, api);
    await _addTo(tester, _inNeither, 'Focus');
    expect(find.text('Already in this playlist'), findsNothing);
    expect(api.playlistSongs['pl-2']!.map((t) => t.title), contains(_inNeither));
    expect(c.read(toastProvider)?.message, 'Added 1 song to "Focus".');
    await advance(tester, const Duration(seconds: 5));
    await disposeApp(tester);
  });

  testWidgets('a repeat asks first; Cancel adds nothing', (tester) async {
    final api = FakeLibraryApi();
    final c = await _songs(tester, api);
    await _addTo(tester, _inBoth, 'Late Night Drive');
    expect(find.text('Already in this playlist'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await advance(tester, const Duration(milliseconds: 400));
    expect(api.playlistSongs['pl-1']!.length, 2);
    expect(c.read(duplicateBehaviorProvider), DuplicateBehavior.ask);
    await advance(tester, const Duration(seconds: 4));
    await disposeApp(tester);
  });

  testWidgets('"Add again" adds the repeat, and "Don\'t ask me again" makes it the rule', (tester) async {
    final api = FakeLibraryApi();
    final c = await _songs(tester, api);
    await _addTo(tester, _inBoth, 'Late Night Drive');
    await tester.tap(find.text('Don\'t ask me again'));
    await tester.pump();
    await tester.tap(find.text('Add again'));
    await advance(tester, const Duration(seconds: 1));
    expect(api.playlistSongs['pl-1']!.length, 3);
    expect(c.read(duplicateBehaviorProvider), DuplicateBehavior.addAgain);
    await advance(tester, const Duration(seconds: 5));

    await _addTo(tester, _inBoth, 'Late Night Drive');
    expect(find.text('Already in this playlist'), findsNothing, reason: 'no question the second time');
    expect(api.playlistSongs['pl-1']!.length, 4);
    await advance(tester, const Duration(seconds: 5));
    await disposeApp(tester);
  });

  testWidgets('"Don\'t add it" plus "don\'t ask again" skips repeats from then on', (tester) async {
    final api = FakeLibraryApi();
    final c = await _songs(tester, api);
    await _addTo(tester, _inBoth, 'Late Night Drive');
    await tester.tap(find.text('Don\'t ask me again'));
    await tester.pump();
    await tester.tap(find.text('Don\'t add it'));
    await advance(tester, const Duration(seconds: 1));
    expect(api.playlistSongs['pl-1']!.length, 2);
    expect(c.read(duplicateBehaviorProvider), DuplicateBehavior.skip);
    expect(c.read(toastProvider)?.message, contains('already in'));
    await advance(tester, const Duration(seconds: 5));
    await disposeApp(tester);
  });

  testWidgets('New playlist asks for a name and makes it private with the song in it', (tester) async {
    final api = FakeLibraryApi();
    await _songs(tester, api);
    await _openPicker(tester, _inNeither);
    await tester.tap(find.text('New playlist'));
    await advance(tester, const Duration(milliseconds: 300));
    expect(find.textContaining('start private'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Brand new');
    await tester.tap(find.text('Create'));
    await advance(tester, const Duration(seconds: 1));
    final made = api.playlists.last;
    expect(made.name, 'Brand new');
    expect(made.isPublic, isFalse);
    expect(api.playlistSongs[made.id]!.map((t) => t.title), [_inNeither]);
    await advance(tester, const Duration(seconds: 5));
    await disposeApp(tester);
  });

  testWidgets('smart playlists and other people\'s playlists are not offered', (tester) async {
    final api = FakeLibraryApi();
    api.playlists
      ..add(const Playlist(id: 'smart', name: 'Smart mix', owner: 'josh', readonly: true))
      ..add(const Playlist(id: 'theirs', name: 'Their mix', owner: 'someone'));
    await _songs(tester, api);
    await _openPicker(tester, _inNeither);
    expect(find.text('Late Night Drive'), findsOneWidget);
    expect(find.text('Smart mix'), findsNothing);
    expect(find.text('Their mix'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await advance(tester, const Duration(seconds: 1));
    await disposeApp(tester);
  });
}
