import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/library_providers.dart';
import 'package:tidewater/app/providers/refresh_library.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/library_api.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('Refresh fetches the lists anew with progress text, shows Done, and does not ask twice', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    c.listen(artistsProvider, (_, _) {});
    c.listen(playlistsProvider, (_, _) {});
    await advance(tester, const Duration(seconds: 1));
    final artistCalls = api.calls.where((x) => x == 'getArtists').length;
    final texts = <String>[];
    c.listen(libraryTaskProvider, (_, next) => texts.add(next.text), fireImmediately: false);

    c.read(routerProvider).go('/settings');
    await advance(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Refresh'));
    await tester.tap(find.text('Refresh'));
    await advance(tester, const Duration(seconds: 1));

    expect(texts.first, contains('albums'), reason: 'starts by saying what it is doing');
    expect(texts.any((t) => t.startsWith('Songs:')), isTrue);
    expect(texts.last, startsWith('Done:'));
    expect(c.read(libraryTaskProvider).running, isFalse);
    expect(find.textContaining('Done:'), findsOneWidget, reason: 'the status shows under the row');
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'no spinner once it is over');
    expect(api.calls.where((x) => x == 'getArtists').length, artistCalls + 1, reason: 'artists asked for once, then read from the fresh copy');
    await advance(tester, const Duration(seconds: 3));
    await disposeApp(tester);
  });

  testWidgets('a spinner stands in for the button while it runs, and the other buttons wait', (tester) async {
    final api = FakeLibraryApi();
    api.listGate[AlbumListType.newest] = Completer<void>();
    final c = await pumpApp(tester, api: api);
    c.read(routerProvider).go('/settings');
    await advance(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Refresh'));
    await tester.tap(find.text('Refresh'));
    await advance(tester, const Duration(milliseconds: 300));
    expect(c.read(libraryTaskProvider).running, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Refresh'), findsNothing, reason: 'the button is the spinner for now');
    final scan = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Scan'));
    expect(scan.onPressed, isNull, reason: 'one job at a time');
    api.listGate[AlbumListType.newest]!.complete();
    await advance(tester, const Duration(seconds: 2));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await advance(tester, const Duration(seconds: 3));
    await disposeApp(tester);
  });

  testWidgets('Scan shows how many songs the server has seen, then refreshes under the same row', (tester) async {
    final api = FakeLibraryApi()..scanPolls = 2;
    final c = await pumpApp(tester, api: api);
    final texts = <String>[];
    c.listen(libraryTaskProvider, (_, next) => texts.add(next.text));
    c.read(routerProvider).go('/settings');
    await advance(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Scan'));
    await tester.tap(find.text('Scan'));
    await advance(tester, const Duration(seconds: 1));
    expect(api.calls, contains('startScan'));
    expect(texts, contains('The server is scanning its music folders…'));
    await advance(tester, const Duration(seconds: 8));
    expect(texts.any((t) => t.startsWith('The server is scanning:') && t.contains('songs seen')), isTrue);
    expect(texts.any((t) => t.startsWith('The scan finished')), isTrue);
    expect(texts.last, startsWith('Done:'));
    expect(c.read(libraryTaskProvider).kind, LibraryTaskKind.scan, reason: 'the Scan row keeps the whole job');
    expect(find.textContaining('Done:'), findsOneWidget);
    await advance(tester, const Duration(seconds: 3));
    await disposeApp(tester);
  });

  testWidgets('a non-admin account is told only admins can scan', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    api.failWith = const ApiException(ApiErrorKind.badCredentials, 'not authorized', code: 50);
    c.read(routerProvider).go('/settings');
    await advance(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Scan'));
    await tester.tap(find.text('Scan'));
    await advance(tester, const Duration(seconds: 1));
    final task = c.read(libraryTaskProvider);
    expect(task.text, 'Only an admin account can start a scan.');
    expect(task.error, isTrue);
    expect(task.running, isFalse);
    expect(find.text('Only an admin account can start a scan.'), findsOneWidget);
    await advance(tester, const Duration(seconds: 3));
    await disposeApp(tester);
  });

  testWidgets('Clear the cover cache says what it did', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/settings');
    await advance(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await advance(tester, const Duration(seconds: 1));
    expect(c.read(toastProvider)?.message, contains('Covers cleared'));
    await advance(tester, const Duration(seconds: 5));
    await disposeApp(tester);
  });
}
