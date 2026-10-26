import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/settings_providers.dart';

import '../support/pump.dart';

void main() {
  testWidgets('the menu button collapses the sidebar to icons and back, and remembers it', (tester) async {
    final c = await pumpApp(tester);
    expect(find.text('Library'), findsWidgets, reason: 'wide rail shows labels');

    await tester.tap(find.byTooltip('Collapse menu'));
    await advance(tester, const Duration(milliseconds: 600));
    expect(c.read(railCollapsedProvider), isTrue);
    expect(find.byTooltip('Expand menu'), findsOneWidget);
    expect(find.text('Library'), findsNothing, reason: 'icon-only rail has no labels');

    await tester.tap(find.byTooltip('Expand menu'));
    await advance(tester, const Duration(milliseconds: 600));
    expect(c.read(railCollapsedProvider), isFalse);
    await disposeApp(tester);
  });
}
