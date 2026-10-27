import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/core/models/playlist.dart';
import 'package:tidewater/ui/pages/widgets/song_row.dart';
import 'package:tidewater/ui/widgets/effects/letter_reveal.dart';

import '../support/finders.dart';
import '../support/fake_library.dart';
import '../support/pump.dart';

Future<ProviderContainer> _open(WidgetTester tester, FakeLibraryApi api, String id) async {
  final c = await pumpApp(tester, api: api);
  c.read(routerProvider).go('/playlist/$id');
  await advance(tester, const Duration(seconds: 2));
  return c;
}

void main() {
  testWidgets('your own playlist shows its songs and the edit controls', (tester) async {
    final api = FakeLibraryApi();
    await _open(tester, api, 'pl-1');
    expect(tester.widget<LetterReveal>(find.byType(LetterReveal)).text, 'Late Night Drive');
    expect(find.byType(SongRow), findsNWidgets(2));
    expect(find.text('Private'), findsOneWidget, reason: 'new and existing playlists default to private');
    expect(byHint('Rename'), findsOneWidget);
    expect(byHint('Delete playlist'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(2));
    expect(find.textContaining('smart playlist'), findsNothing);
    await advance(tester, const Duration(seconds: 3));
    await disposeApp(tester);
  });

  testWidgets('the Private / Public pill switches who can see it', (tester) async {
    final api = FakeLibraryApi();
    await _open(tester, api, 'pl-1');
    await tester.tap(find.text('Private'));
    await advance(tester, const Duration(seconds: 1));
    expect(api.playlists.first.isPublic, isTrue);
    expect(find.text('Public'), findsOneWidget);
    await tester.tap(find.text('Public'));
    await advance(tester, const Duration(seconds: 1));
    expect(api.playlists.first.isPublic, isFalse);
    expect(find.text('Private'), findsOneWidget);
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('renaming asks for the new name and saves it', (tester) async {
    final api = FakeLibraryApi();
    await _open(tester, api, 'pl-1');
    await tester.tap(byHint('Rename'));
    await advance(tester, const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Dawn Drive');
    await tester.tap(find.text('Save'));
    await advance(tester, const Duration(seconds: 1));
    expect(api.playlists.first.name, 'Dawn Drive');
    expect(tester.widget<LetterReveal>(find.byType(LetterReveal)).text, 'Dawn Drive', reason: 'the page title follows the new name');
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('deleting asks first, then removes it and leaves the page', (tester) async {
    final api = FakeLibraryApi();
    final c = await _open(tester, api, 'pl-1');
    await tester.tap(byHint('Delete playlist'));
    await advance(tester, const Duration(milliseconds: 400));
    expect(find.textContaining('The songs stay in your library'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await advance(tester, const Duration(milliseconds: 400));
    expect(api.playlists.any((p) => p.id == 'pl-1'), isTrue, reason: 'cancelled');

    await tester.tap(byHint('Delete playlist'));
    await advance(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Delete'));
    await advance(tester, const Duration(seconds: 2));
    expect(api.playlists.any((p) => p.id == 'pl-1'), isFalse);
    expect(c.read(routerProvider).state.uri.path, isNot('/playlist/pl-1'));
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('Remove from this playlist in the song menu takes the song out', (tester) async {
    final api = FakeLibraryApi();
    await _open(tester, api, 'pl-1');
    final first = api.playlistSongs['pl-1']!.first.title;
    await tester.tap(find.widgetWithText(SongRow, first), buttons: kSecondaryButton);
    await advance(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Remove from this playlist'));
    await advance(tester, const Duration(seconds: 1));
    expect(api.playlistSongs['pl-1']!.length, 1);
    expect(find.byType(SongRow), findsOneWidget);
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('dragging a song by its handle saves the new order', (tester) async {
    final api = FakeLibraryApi();
    await _open(tester, api, 'pl-1');
    final before = api.playlistSongs['pl-1']!.map((t) => t.id).toList();
    final handle = find.byIcon(Icons.drag_indicator_rounded).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await advance(tester, const Duration(seconds: 1));
    expect(api.playlistSongs['pl-1']!.map((t) => t.id).toList(), before.reversed.toList());
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('a smart playlist is read-only, with a note that says why', (tester) async {
    final api = FakeLibraryApi();
    api.playlists.add(const Playlist(id: 'smart', name: 'Smart mix', owner: 'josh', readonly: true));
    api.playlistSongs['smart'] = api.playlistSongs['pl-1']!;
    await _open(tester, api, 'smart');
    expect(find.textContaining('smart playlist'), findsOneWidget);
    expect(byHint('Rename'), findsNothing);
    expect(byHint('Delete playlist'), findsNothing);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
    expect(find.text('Private'), findsNothing);
    await advance(tester, const Duration(seconds: 3));
    await disposeApp(tester);
  });

  testWidgets('someone else\'s playlist is read-only too', (tester) async {
    final api = FakeLibraryApi();
    api.playlists.add(const Playlist(id: 'theirs', name: 'Their mix', owner: 'someone', isPublic: true));
    api.playlistSongs['theirs'] = api.playlistSongs['pl-1']!;
    await _open(tester, api, 'theirs');
    expect(find.textContaining('belongs to someone'), findsOneWidget);
    expect(byHint('Rename'), findsNothing);
    await advance(tester, const Duration(seconds: 3));
    await disposeApp(tester);
  });

  testWidgets('renaming to the same name sends nothing', (tester) async {
    final api = FakeLibraryApi();
    await _open(tester, api, 'pl-1');
    await tester.tap(byHint('Rename'));
    await advance(tester, const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Late Night Drive');
    await tester.tap(find.text('Save'));
    await advance(tester, const Duration(seconds: 1));
    expect(api.calls.where((c) => c == 'updatePlaylist'), isEmpty);
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });
}
