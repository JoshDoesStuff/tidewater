import 'package:flutter/material.dart' show TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';

import '../support/finders.dart';
import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('New playlist on the Playlists page asks for a name, creates it private and opens it', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    c.read(routerProvider).go('/lists');
    await advance(tester, const Duration(seconds: 2));
    await tester.tap(find.text('New playlist'));
    await advance(tester, const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Fresh start');
    await tester.tap(find.text('Create'));
    await advance(tester, const Duration(seconds: 2));
    final made = api.playlists.last;
    expect(made.name, 'Fresh start');
    expect(made.isPublic, isFalse);
    expect(api.playlistSongs[made.id], isEmpty);
    expect(c.read(routerProvider).state.uri.path, '/playlist/${made.id}', reason: 'opens the new playlist');
    expect(find.text('This playlist is empty'), findsOneWidget);
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('the album page More button adds the whole album to a playlist', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    c.read(routerProvider).go('/album/a1');
    await advance(tester, const Duration(seconds: 2));
    await tester.tap(byHint('More').first); // the header button, before the rows' own
    await advance(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Add to playlist…'));
    await advance(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Focus'));
    await advance(tester, const Duration(seconds: 1));
    // Focus held one song already; the album's three are added, the first being 'Last Tram Home'.
    expect(api.playlistSongs['pl-2']!.length, 4);
    expect(c.read(toastProvider)?.message, 'Added 3 songs to "Focus".');
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('Play next and Add to queue from the menu say what they did', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/album/a1');
    await advance(tester, const Duration(seconds: 2));
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(seconds: 1));
    await tester.tap(byHint('More').first);
    await advance(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Add to queue'));
    await advance(tester, const Duration(milliseconds: 400));
    expect(c.read(toastProvider)?.message, 'Added 3 songs to the queue.');
    expect(c.read(playbackProvider).queue.length, 4);
    await c.read(playbackProvider.notifier).toggle();
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });
}
