import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/providers/library_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';

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
