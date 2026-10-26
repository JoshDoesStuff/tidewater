import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/library_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('Refresh in Settings asks the server for the lists again and says so', (tester) async {
    final api = FakeLibraryApi();
    final c = await pumpApp(tester, api: api);
    c.listen(artistsProvider, (_, _) {});
    c.listen(playlistsProvider, (_, _) {});
    await advance(tester, const Duration(seconds: 1));
    final artistCalls = api.calls.where((x) => x == 'getArtists').length;
    final playlistCalls = api.calls.where((x) => x == 'getPlaylists').length;

    c.read(routerProvider).go('/settings');
    await advance(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Refresh'));
    await tester.tap(find.text('Refresh'));
    await advance(tester, const Duration(seconds: 1));

    expect(api.calls.where((x) => x == 'getArtists').length, artistCalls + 1);
    expect(api.calls.where((x) => x == 'getPlaylists').length, playlistCalls + 1);
    expect(c.read(toastProvider)?.message, contains('Refreshing'));
    await advance(tester, const Duration(seconds: 5));
    await disposeApp(tester);
  });

  testWidgets('Scan asks the server to scan, waits for it, then refreshes the library', (tester) async {
    final api = FakeLibraryApi()..scanPolls = 2;
    final c = await pumpApp(tester, api: api);
    c.listen(artistsProvider, (_, _) {});
    await advance(tester, const Duration(seconds: 1));
    final before = api.calls.where((x) => x == 'getArtists').length;
    c.read(routerProvider).go('/settings');
    await advance(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Scan'));
    await tester.tap(find.text('Scan'));
    await advance(tester, const Duration(seconds: 1));
    expect(api.calls, contains('startScan'));
    expect(c.read(toastProvider)?.message, contains('scanning'));
    await advance(tester, const Duration(seconds: 8));
    expect(api.calls.where((x) => x == 'getScanStatus').length, greaterThanOrEqualTo(2));
    expect(api.calls.where((x) => x == 'getArtists').length, before + 1, reason: 'refreshed once the scan ended');
    expect(c.read(toastProvider)?.message, contains('scan finished'));
    await advance(tester, const Duration(seconds: 6));
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
    expect(c.read(toastProvider)?.message, 'Only an admin account can start a scan.');
    expect(c.read(toastProvider)?.error, isTrue);
    await advance(tester, const Duration(seconds: 6));
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
