import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/selection.dart';
import 'package:tidewater/app/providers/ui_providers.dart';

import 'package:tidewater/ui/pages/widgets/album_card.dart' show MediaCard, PlaylistCard;
import 'package:tidewater/ui/shell/mini_player.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

Future<void> _ctrlTap(WidgetTester tester, Finder f) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.tap(f);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final first = fakeTracks.where((t) => t.albumId == 'a1').toList();

  testWidgets('Ctrl+click picks songs, a plain click then adds more, and the bar adds them to the queue', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/album/a1');
    await advance(tester, const Duration(seconds: 2));
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(seconds: 1));

    await _ctrlTap(tester, find.text(first[0].title).first);
    expect(c.read(selectionProvider).length, 1);
    // With some picked, a plain click picks too, instead of playing.
    await tester.tap(find.text(first[1].title).first);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(selectionProvider).length, 2);
    expect(find.text('2 selected'), findsOneWidget);
    // Clicking a picked one lets it go.
    await tester.tap(find.text(first[1].title).first);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(selectionProvider).length, 1);
    await tester.tap(find.text(first[2].title).first);
    await advance(tester, const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Add to queue'));
    await advance(tester, const Duration(milliseconds: 400));
    expect(c.read(toastProvider)?.message, 'Added 2 songs to the queue.');
    expect(c.read(playbackProvider).queue.length, 3);
    expect(c.read(selectionProvider).isEmpty, isTrue, reason: 'the bar lets go once it has done its job');
    await c.read(playbackProvider.notifier).toggle();
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('Shift+click picks the songs in between, and Esc lets go of them all', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/album/a1');
    await advance(tester, const Duration(seconds: 2));

    await _ctrlTap(tester, find.text(first[0].title).first);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text(first[2].title).first);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(selectionProvider).length, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(selectionProvider).isEmpty, isTrue);
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('picked songs are let go of when you go to another page', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/album/a1');
    await advance(tester, const Duration(seconds: 2));
    await _ctrlTap(tester, find.text(first[0].title).first);
    expect(c.read(selectionProvider).length, 1);
    c.read(routerProvider).go('/lists');
    await advance(tester, const Duration(seconds: 2));
    expect(c.read(selectionProvider).isEmpty, isTrue);
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('dragging a song onto the mini player adds it to the queue', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/album/a1');
    await advance(tester, const Duration(seconds: 2));
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(seconds: 1));

    final gesture = await tester.startGesture(tester.getCenter(find.text(first[1].title).first));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump(const Duration(milliseconds: 100));
    final pill = tester.getCenter(find.byType(MiniPlayer));
    await gesture.moveTo(pill);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await advance(tester, const Duration(milliseconds: 400));
    expect(c.read(playbackProvider).queue.length, 2);
    expect(c.read(toastProvider)?.message, 'Added to the queue.');
    await c.read(playbackProvider.notifier).toggle();
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('right-clicking an album card offers Play, Shuffle and the queue for all its songs', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/library');
    await advance(tester, const Duration(seconds: 2));
    final card = find.byType(MediaCard).first;
    await tester.tapAt(tester.getTopLeft(card) + const Offset(60, 60), buttons: kSecondaryButton);
    await advance(tester, const Duration(milliseconds: 400));
    expect(find.text('Play next'), findsOneWidget);
    await tester.tap(find.text('Add to queue'));
    await advance(tester, const Duration(milliseconds: 600));
    expect(c.read(toastProvider)?.message, startsWith('Added '));
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('dropping a playlist on another playlist adds its songs there (skipping what is already in it)', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    c.read(routerProvider).go('/lists');
    await advance(tester, const Duration(seconds: 2));
    final cards = find.byType(PlaylistCard);
    final from = tester.getTopLeft(cards.at(0)) + const Offset(60, 60); // Late Night Drive: 2 songs
    final to = tester.getTopLeft(cards.at(1)) + const Offset(60, 60); // Focus: 1 song, also in the first
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await advance(tester, const Duration(milliseconds: 600));
    // The duplicate question appears, because one of the songs is already there.
    await tester.tap(find.text('Skip the repeats'));
    await advance(tester, const Duration(seconds: 1));
    expect(api.playlistSongs['pl-2']!.length, 2);
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('Ctrl+A picks every song on the page', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/album/a1');
    await advance(tester, const Duration(seconds: 2));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(selectionProvider).length, first.length);
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('in your own playlist the bar can remove several picked songs at once', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    c.read(routerProvider).go('/playlist/pl-1'); // two songs
    await advance(tester, const Duration(seconds: 2));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await advance(tester, const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Remove from playlist'));
    await advance(tester, const Duration(seconds: 1));
    expect(api.playlistSongs['pl-1'], isEmpty);
    expect(c.read(toastProvider)?.message, 'Removed 2 songs from "Late Night Drive".');
    expect(c.read(selectionProvider).isEmpty, isTrue);
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('the queue picks rows too, and removes them together', (tester) async {
    final c = await pumpApp(tester);
    final player = c.read(playbackProvider.notifier);
    await player.playTracks(fakeTracks.take(5).toList());
    await advance(tester, const Duration(seconds: 1));
    c.read(nowPlayingOpenProvider.notifier).set(true);
    c.read(queueOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text(fakeTracks[3].title).last);
    await tester.tap(find.text(fakeTracks[4].title).last);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(queueSelectionProvider), {3, 4});
    await tester.tap(find.byTooltip('Remove from queue').first);
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(playbackProvider).queue.length, 3);
    expect(c.read(toastProvider)?.message, 'Removed 2 songs from the queue.');
    await player.toggle();
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });
}
