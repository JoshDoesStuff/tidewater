import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';

import 'support/fake_library.dart';
import 'support/pump.dart';

void main() {
  testWidgets('the speaker mutes and brings the volume back to where it was', (tester) async {
    final c = await pumpApp(tester);
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await c.read(playbackProvider.notifier).toggle();
    await c.read(playbackProvider.notifier).setVolume(.3);
    c.read(nowPlayingOpenProvider.notifier).set(true);
    await advance(tester, const Duration(seconds: 2));
    expect(find.byIcon(Icons.volume_down_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Mute (M)'));
    await advance(tester, const Duration(milliseconds: 500));
    expect(c.read(playbackProvider).volume, 0);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Unmute (M)'));
    await advance(tester, const Duration(milliseconds: 500));
    expect(c.read(playbackProvider).volume, .3);
    c.read(nowPlayingOpenProvider.notifier).set(false);
    await advance(tester, const Duration(seconds: 1));
    await disposeApp(tester);
  });

  testWidgets('M mutes and unmutes from anywhere', (tester) async {
    final c = await pumpApp(tester);
    await c.read(playbackProvider.notifier).setVolume(.8);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await advance(tester, const Duration(milliseconds: 200));
    expect(c.read(playbackProvider).volume, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await advance(tester, const Duration(milliseconds: 200));
    expect(c.read(playbackProvider).volume, .8);
    await disposeApp(tester);
  });

  testWidgets('un-muting a volume that was dragged to zero goes to half', (tester) async {
    final c = await pumpApp(tester);
    await c.read(playbackProvider.notifier).setVolume(0);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await advance(tester, const Duration(milliseconds: 200));
    expect(c.read(playbackProvider).volume, .5);
    await disposeApp(tester);
  });
}
