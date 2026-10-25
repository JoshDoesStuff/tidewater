import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/playback/play_queue.dart';

import 'support/fake_library.dart';
import 'support/pump.dart';

Future<ProviderContainer> openNowPlaying(WidgetTester tester) async {
  final c = await pumpApp(tester);
  await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[1]); // three tracks
  await c.read(playbackProvider.notifier).toggle();
  c.read(nowPlayingOpenProvider.notifier).set(true);
  await advance(tester, const Duration(seconds: 2));
  return c;
}

Future<void> closeNowPlaying(WidgetTester tester, ProviderContainer c) async {
  c.read(nowPlayingOpenProvider.notifier).set(false);
  await advance(tester, const Duration(seconds: 1));
  await disposeApp(tester);
}

void main() {
  testWidgets('the queue button opens the panel with the whole queue', (tester) async {
    final c = await openNowPlaying(tester);
    expect(c.read(queueOpenProvider), isFalse);
    await tester.tap(find.byTooltip('Queue (Q)'));
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(queueOpenProvider), isTrue);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('3 tracks · 6:40 left'), findsOneWidget);
    expect(find.text('Last Tram Home 3'), findsWidgets);
    await closeNowPlaying(tester, c);
  });

  testWidgets('Q toggles it and Esc closes the panel before Now Playing', (tester) async {
    final c = await openNowPlaying(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(queueOpenProvider), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(queueOpenProvider), isFalse);
    expect(c.read(nowPlayingOpenProvider), isTrue, reason: 'first Esc only closes the queue');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(nowPlayingOpenProvider), isFalse);
    await disposeApp(tester);
  });

  testWidgets('tapping a row jumps to that track', (tester) async {
    final c = await openNowPlaying(tester);
    c.read(queueOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 1));
    await tester.tap(find.text('Last Tram Home 3').last);
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(playbackProvider).track?.id, 't-a1-2');
    expect(c.read(playbackProvider).playing, isTrue);
    await c.read(playbackProvider.notifier).toggle();
    await closeNowPlaying(tester, c);
  });

  testWidgets('removing a row takes it out of the queue', (tester) async {
    final c = await openNowPlaying(tester);
    c.read(queueOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Remove from queue').at(2), warnIfMissed: false);
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(playbackProvider).queue.map((t) => t.id), ['t-a1', 't-a1-1']);
    await closeNowPlaying(tester, c);
  });

  testWidgets('dragging the handle reorders the queue and keeps the playing track', (tester) async {
    final c = await openNowPlaying(tester);
    c.read(queueOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 1));
    final handles = find.byIcon(Icons.drag_indicator_rounded);
    expect(handles, findsNWidgets(3));
    await tester.timedDrag(handles.at(2), const Offset(0, -64), const Duration(milliseconds: 600));
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(playbackProvider).queue.map((t) => t.id), ['t-a1', 't-a1-2', 't-a1-1']);
    expect(c.read(playbackProvider).track?.id, 't-a1', reason: 'what is playing does not change');
    await closeNowPlaying(tester, c);
  });

  testWidgets('shuffle and repeat live in the panel too', (tester) async {
    final c = await openNowPlaying(tester);
    c.read(queueOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Repeat: off').last);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(playbackProvider).repeat, LoopMode.all);
    await tester.tap(find.byTooltip('Repeat: all').last);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(playbackProvider).repeat, LoopMode.one);
    await tester.tap(find.byTooltip('Shuffle: off'));
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(playbackProvider).shuffle, isTrue);
    await closeNowPlaying(tester, c);
  });

  testWidgets('an open queue keeps Now Playing from going idle', (tester) async {
    final c = await openNowPlaying(tester);
    await c.read(playbackProvider.notifier).toggle(); // play
    c.read(queueOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 6));
    expect(c.read(idleProvider), isFalse);
    c.read(queueOpenProvider.notifier).set(false);
    await advance(tester, const Duration(seconds: 6));
    expect(c.read(idleProvider), isTrue);
    await c.read(playbackProvider.notifier).toggle();
    await closeNowPlaying(tester, c);
  });

  testWidgets('closing Now Playing closes the queue', (tester) async {
    final c = await openNowPlaying(tester);
    c.read(queueOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 1));
    c.read(nowPlayingOpenProvider.notifier).set(false);
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(queueOpenProvider), isFalse);
    await disposeApp(tester);
  });
}
