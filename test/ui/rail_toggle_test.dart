import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/ui/shell/nav_rail.dart';

import '../support/finders.dart';
import '../support/pump.dart';

void main() {
  testWidgets('the menu button hides the whole sidebar but itself (icons too), and brings it back', (tester) async {
    final c = await pumpApp(tester);
    expect(find.text('Library'), findsWidgets, reason: 'wide rail shows labels');
    final wide = tester.getSize(find.byType(NavRail)).width;

    await tester.tap(byHint('Hide menu'));
    await advance(tester, const Duration(milliseconds: 600));
    expect(c.read(railCollapsedProvider), isTrue);
    expect(byHint('Show menu'), findsOneWidget);
    expect(tester.getSize(find.byType(NavRail)).width, lessThan(wide));
    final hiddenItems = tester.widgetList<IgnorePointer>(find.descendant(of: find.byType(NavRail), matching: find.byType(IgnorePointer)));
    expect(hiddenItems.where((w) => w.ignoring), isNotEmpty, reason: 'the items cannot be clicked while hidden');
    final fade = tester.widgetList<AnimatedOpacity>(find.descendant(of: find.byType(NavRail), matching: find.byType(AnimatedOpacity)));
    expect(fade.where((w) => w.opacity == 0), isNotEmpty, reason: 'and cannot be seen');

    await tester.tap(byHint('Show menu'));
    await advance(tester, const Duration(milliseconds: 600));
    expect(c.read(railCollapsedProvider), isFalse);
    expect(tester.getSize(find.byType(NavRail)).width, wide);
    await disposeApp(tester);
  });
}
