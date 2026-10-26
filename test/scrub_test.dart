import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/ui/widgets/wavy_progress.dart';

import 'support/fake_library.dart';
import 'support/pump.dart';

void main() {
  Future<void> playPaused(WidgetTester tester, dynamic c) async {
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await c.read(playbackProvider.notifier).toggle();
    await advance(tester, const Duration(seconds: 1));
  }

  testWidgets('with live scrubbing off, a drag seeks once, when it is let go', (tester) async {
    final c = await pumpApp(tester);
    await playPaused(tester, c);
    final bar = find.byType(WavyScrubber).first;
    final rect = tester.getRect(bar);
    final g = await tester.startGesture(rect.centerLeft + const Offset(10, 0));
    await g.moveBy(Offset(rect.width * .5, 0));
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(positionProvider).value, lessThan(const Duration(seconds: 5)), reason: 'nothing requested mid-drag');
    await g.up();
    await advance(tester, const Duration(milliseconds: 500));
    expect(c.read(positionProvider).value, greaterThan(const Duration(seconds: 30)), reason: 'one seek on release');
    await disposeApp(tester);
  });

  testWidgets('with live scrubbing on, the song follows the drag', (tester) async {
    final c = await pumpApp(tester);
    c.read(liveScrubProvider.notifier).set(true);
    await playPaused(tester, c);
    final rect = tester.getRect(find.byType(WavyScrubber).first);
    final g = await tester.startGesture(rect.centerLeft + const Offset(10, 0));
    await g.moveBy(Offset(rect.width * .5, 0));
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(positionProvider).value, greaterThan(const Duration(seconds: 30)));
    await g.up();
    await disposeApp(tester);
  });

  testWidgets('Show all only appears on rows that run off the screen', (tester) async {
    await pumpApp(tester);
    expect(find.text('Show all'), findsOneWidget, reason: 'Recently added has more albums than fit; Most played has 3');
    await disposeApp(tester);
  });

  testWidgets('a click ahead of or behind the playhead seeks there (and animates, without errors)', (tester) async {
    final c = await pumpApp(tester);
    await playPaused(tester, c);
    final rect = tester.getRect(find.byType(WavyScrubber).first);
    await tester.tapAt(rect.centerLeft + Offset(rect.width * .75, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(positionProvider).value, greaterThan(const Duration(seconds: 100)));
    await tester.tapAt(rect.centerLeft + Offset(rect.width * .25, 0));
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(positionProvider).value, lessThan(const Duration(seconds: 80)));
    await disposeApp(tester);
  });
}
