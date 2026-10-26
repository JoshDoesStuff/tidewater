import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/core/api/library_api.dart';

import '../support/fake_library.dart';
import '../support/pump.dart';

void main() {
  testWidgets('Jump back in copes with its hero cards arriving one list at a time', (tester) async {
    final gate = Completer<void>();
    final api = FakeLibraryApi()..listGate[AlbumListType.recent] = gate;
    await pumpApp(tester, api: api);
    await advance(tester, const Duration(seconds: 1));
    expect(tester.takeException(), isNull, reason: 'two heroes while recently played is still loading');
    gate.complete();
    await advance(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull, reason: 'a third hero appears (this used to throw a RangeError)');
    await disposeApp(tester);
  });
}
