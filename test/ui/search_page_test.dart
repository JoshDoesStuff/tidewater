import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/search_providers.dart';
import 'package:tidewater/ui/pages/search_page.dart';
import 'package:tidewater/ui/widgets/squiggle_loader.dart';

import '../support/pump.dart';

void main() {
  testWidgets('the Home search pill opens the Search page, which starts on the hint', (tester) async {
    final c = await pumpApp(tester);
    await tester.tap(find.byType(TextField).first);
    await advance(tester, const Duration(seconds: 1));
    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.text('Search your library'), findsWidgets);
    expect(c.read(routerProvider).state.uri.path, '/search');
    await disposeApp(tester);
  });

  testWidgets('clicking the search icon or the edge of the pill opens Search, not only the text', (tester) async {
    final c = await pumpApp(tester);
    final pill = tester.getRect(find.byType(TextField).first);
    // Left of the text field: the icon area.
    await tester.tapAt(Offset(pill.left - 30, pill.center.dy));
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(routerProvider).state.uri.path, '/search');
    await disposeApp(tester);
  });

  testWidgets('typing searches after a short wait and lists songs, albums and artists', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/search');
    await advance(tester, const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'Velvet');
    await advance(tester, const Duration(milliseconds: 100));
    expect(find.text('Songs'), findsNothing, reason: 'still waiting for the pause after typing');
    expect(find.textContaining('No results'), findsNothing, reason: 'waiting is not an empty answer');
    expect(tester.widget<SquiggleLoader>(find.byType(SquiggleLoader)).active, isTrue, reason: 'the searching squiggle runs');
    await advance(tester, const Duration(seconds: 1));
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Songs'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('a search with no matches says so; Enter remembers a search and the chip brings it back', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/search');
    await advance(tester, const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'zzzzzz');
    await advance(tester, const Duration(seconds: 1));
    expect(find.text('No results for "zzzzzz"'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(recentSearchesProvider), ['zzzzzz']);

    await tester.tap(find.byTooltip('Clear'));
    await advance(tester, const Duration(milliseconds: 300));
    expect(find.text('Recent searches'), findsOneWidget);
    await tester.tap(find.text('zzzzzz'));
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(searchQueryProvider), 'zzzzzz');
    await disposeApp(tester);
  });

  testWidgets('clicking the glass on the Search page keeps the field focused (the pill does not shrink and grow back)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows; // only desktop blurs a field on an outside tap
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/search');
    await advance(tester, const Duration(seconds: 1));
    final field = find.byType(EditableText);
    expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
    final node = tester.widget<EditableText>(field).focusNode;
    final changes = <bool>[];
    node.addListener(() => changes.add(node.hasFocus));
    final rect = tester.getRect(find.byType(TextField));
    await tester.tapAt(Offset(rect.left - 30, rect.center.dy));
    await tester.pump(const Duration(milliseconds: 50));
    expect(changes, isEmpty, reason: 'the field is never blurred and refocused by the click');
    await advance(tester, const Duration(seconds: 1));
    expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
    debugDefaultTargetPlatformOverride = null;
    await disposeApp(tester);
  });

  testWidgets('Ctrl+K opens Search from anywhere', (tester) async {
    final c = await pumpApp(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(routerProvider).state.uri.path, '/search');
    await disposeApp(tester);
  });

  test('recent searches keep the newest first, without duplicates, at most ten, and are remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    final n = c.read(recentSearchesProvider.notifier);
    n.add('a');
    expect(c.read(recentSearchesProvider), isEmpty, reason: 'one letter is not a search');
    for (var i = 0; i < 12; i++) {
      n.add('song $i');
    }
    n.add('SONG 5');
    final list = c.read(recentSearchesProvider);
    expect(list.length, 10);
    expect(list.first, 'SONG 5');
    expect(list.where((s) => s.toLowerCase() == 'song 5').length, 1);
    expect(prefs.getStringList('recent_searches'), list);
    n.remove('SONG 5');
    expect(c.read(recentSearchesProvider), isNot(contains('SONG 5')));
    n.clear();
    expect(c.read(recentSearchesProvider), isEmpty);
  });
}
