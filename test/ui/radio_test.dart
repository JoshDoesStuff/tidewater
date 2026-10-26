import 'package:flutter/material.dart' show TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('Radio lists the server\'s stations and a tap plays one as a live stream, not counted as a song play', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    c.read(routerProvider).go('/radio');
    await advance(tester, const Duration(seconds: 2));
    expect(find.text('Harbour FM'), findsOneWidget);
    expect(find.text('Night Signal'), findsOneWidget);
    expect(find.text('2 stations'), findsOneWidget);
    await tester.tap(find.text('Harbour FM'));
    await advance(tester, const Duration(seconds: 2));
    final s = c.read(playbackProvider);
    expect(s.queue.length, 1);
    expect(s.track!.isRadio, isTrue);
    expect(s.track!.streamUrl, 'http://radio.example/harbour');
    expect(api.calls.where((x) => x == 'scrobble'), isEmpty, reason: 'a station is not a song on the server');
    await c.read(playbackProvider.notifier).toggle();
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('Add station asks for a name and address, and the new station shows up', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    c.read(routerProvider).go('/radio');
    await advance(tester, const Duration(seconds: 2));
    await tester.tap(find.text('Add station'));
    await advance(tester, const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).at(0), 'Deep Cuts');
    await tester.enterText(find.byType(TextField).at(1), 'not an address');
    await tester.tap(find.text('Add'));
    await advance(tester, const Duration(milliseconds: 300));
    expect(find.textContaining('http://'), findsOneWidget, reason: 'asks for a real address');
    await tester.enterText(find.byType(TextField).at(1), 'https://deep.example/live');
    await tester.tap(find.text('Add'));
    await advance(tester, const Duration(seconds: 2));
    expect(api.stations.map((s) => s.name), contains('Deep Cuts'));
    expect(find.text('Deep Cuts'), findsOneWidget);
    expect(c.read(toastProvider)?.message, 'Added "Deep Cuts".');
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });

  testWidgets('an account that may not change stations is told so, and nothing changes', (tester) async {
    final api = FakeLibraryApi()..failRadioEditWith = const ApiException(ApiErrorKind.server, 'User is not authorized for the given operation');
    final c = await pumpApp(tester, api: api);
    c.read(routerProvider).go('/radio');
    await advance(tester, const Duration(seconds: 2));
    await tester.tap(find.text('Add station'));
    await advance(tester, const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).at(0), 'Nope FM');
    await tester.enterText(find.byType(TextField).at(1), 'https://nope.example/live');
    await tester.tap(find.text('Add'));
    await advance(tester, const Duration(seconds: 2));
    expect(c.read(toastProvider)?.error, isTrue);
    expect(api.stations.length, 2);
    await advance(tester, const Duration(seconds: 6));
    await disposeApp(tester);
  });
}
