import 'package:flutter/widgets.dart' show IgnorePointer;
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/ui/widgets/wavy_progress.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('the Continue listening card only shows progress: a wavy bar with no handle that cannot be clicked', (tester) async {
    final c = await pumpApp(tester);
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(seconds: 1));
    final bars = tester.widgetList<WavyScrubber>(find.byType(WavyScrubber)).toList();
    expect(bars.where((b) => b.readOnly), hasLength(1), reason: 'the card has one, the mini player has the live one');
    expect(bars.where((b) => !b.readOnly), isNotEmpty);
    final card = find.byWidgetPredicate((w) => w is WavyScrubber && w.readOnly);
    expect(find.descendant(of: card, matching: find.byType(IgnorePointer)), findsWidgets);
    await c.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
  });

  testWidgets('the hero cards fill the row until there is something to continue, then the card slides in', (tester) async {
    final c = await pumpApp(tester);
    expect(find.text('Continue listening'), findsNothing);
    await c.read(playbackProvider.notifier).playAlbum(fakeAlbums[0]);
    await advance(tester, const Duration(seconds: 2));
    expect(find.text('Continue listening'), findsOneWidget);
    expect(c.read(wrapUpAlwaysProvider), isFalse, reason: 'sanity: unrelated setting stays off');
    await c.read(playbackProvider.notifier).toggle();
    await disposeApp(tester);
  });

  testWidgets('the always show wrapping up setting is remembered', (tester) async {
    final c = await pumpApp(tester);
    expect(c.read(wrapUpAlwaysProvider), isFalse);
    c.read(wrapUpAlwaysProvider.notifier).set(true);
    expect(c.read(sharedPreferencesProvider).getBool('wrap_up_always'), isTrue);
    c.read(routerProvider).go('/settings');
    await advance(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Always show the "wrapping up" screen'));
    expect(find.text('Always show the "wrapping up" screen'), findsOneWidget);
    await disposeApp(tester);
  });
}
