import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/playlist_actions.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';

import '../support/fake_library.dart';
import '../support/test_app.dart';

Future<(ProviderContainer, FakeLibraryApi)> _setup() async {
  final api = FakeLibraryApi();
  final c = ProviderContainer(overrides: await testOverrides(api: api));
  addTearDown(c.dispose);
  return (c, api);
}

void main() {
  test('create makes a private playlist with the songs and says so', () async {
    final (c, api) = await _setup();
    final made = await c.read(playlistActionsProvider).create('  Road trip ', fakeTracks.take(3).toList());
    expect(made?.name, 'Road trip');
    expect(api.playlists.last.name, 'Road trip');
    expect(api.playlists.last.isPublic, isFalse, reason: 'private until switched on');
    expect(api.playlistSongs[api.playlists.last.id]!.map((t) => t.id), fakeTracks.take(3).map((t) => t.id));
    expect(c.read(toastProvider)?.message, 'Created "Road trip" with 3 songs.');
  });

  test('an empty name creates nothing', () async {
    final (c, api) = await _setup();
    expect(await c.read(playlistActionsProvider).create('   ', const []), isNull);
    expect(api.playlists.length, 2);
  });

  test('add puts songs at the end, remove takes one out by position, reorder replaces the order', () async {
    final (c, api) = await _setup();
    final actions = c.read(playlistActionsProvider);
    final pl = api.playlists.first;
    final before = [...api.playlistSongs[pl.id]!];

    expect(await actions.add(pl, [fakeTracks[5], fakeTracks[6]]), isTrue);
    expect(api.playlistSongs[pl.id]!.map((t) => t.id), [...before.map((t) => t.id), fakeTracks[5].id, fakeTracks[6].id]);
    expect(c.read(toastProvider)?.message, 'Added 2 songs to "${pl.name}".');

    expect(await actions.removeAt(pl, 0), isTrue);
    expect(api.playlistSongs[pl.id]!.first.id, before[1].id);

    final now = [...api.playlistSongs[pl.id]!];
    expect(await actions.reorder(pl, now.reversed.toList()), isTrue);
    expect(api.playlistSongs[pl.id]!.map((t) => t.id), now.reversed.map((t) => t.id));
  });

  test('rename, public and delete', () async {
    final (c, api) = await _setup();
    final actions = c.read(playlistActionsProvider);
    final pl = api.playlists.first;
    expect(await actions.rename(pl, 'Night Drive'), isTrue);
    expect(api.playlists.first.name, 'Night Drive');
    expect(await actions.rename(pl.copyWith(name: 'Night Drive'), 'Night Drive'), isFalse, reason: 'same name: nothing to do');
    expect(await actions.setPublic(pl, true), isTrue);
    expect(api.playlists.first.isPublic, isTrue);
    expect(await actions.delete(pl), isTrue);
    expect(api.playlists.any((p) => p.id == pl.id), isFalse);
    expect(c.read(toastProvider)?.message, contains('Deleted'));
  });

  test('a server error is reported and nothing claims to have worked', () async {
    final (c, api) = await _setup();
    api.failWith = const ApiException(ApiErrorKind.server, 'The server had a problem (HTTP 500).');
    final ok = await c.read(playlistActionsProvider).add(api.playlists.first, [fakeTracks[4]]);
    expect(ok, isFalse);
    expect(c.read(toastProvider)?.error, isTrue);
    expect(c.read(toastProvider)?.message, contains('HTTP 500'));
  });

  test('the duplicate choice is remembered between launches', () async {
    final (c, _) = await _setup();
    expect(c.read(duplicateBehaviorProvider), DuplicateBehavior.ask);
    c.read(duplicateBehaviorProvider.notifier).set(DuplicateBehavior.skip);
    expect(c.read(duplicateBehaviorProvider), DuplicateBehavior.skip);
    expect(c.read(sharedPreferencesProvider).getString('playlist_duplicates'), 'skip');
  });
}
