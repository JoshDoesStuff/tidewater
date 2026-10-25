// The whole app for real: your server, libmpv audio (quiet), the Windows media
// overlay. Starts an album and then waits so tool/e2e_check.ps1 can read the
// overlay back and press its buttons from outside the app. Prints `E2E ...`.
//
//   flutter run -d windows -t tool/e2e_main.dart ^
//     --dart-define=TW_URL=https://your.server --dart-define=TW_USER=u --dart-define=TW_PASS=p
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/playback/real_engine.dart';
import 'package:tidewater/app/playback/smtc_controls.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/session_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/app/providers/system_media_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/api/library_api.dart';
import 'package:tidewater/core/api/opensubsonic_client.dart';
import 'package:tidewater/core/api/server_config.dart';
import 'package:tidewater/core/api/session_store.dart';

const _url = String.fromEnvironment('TW_URL', defaultValue: 'https://demo.navidrome.org');
const _user = String.fromEnvironment('TW_USER', defaultValue: 'demo');
const _pass = String.fromEnvironment('TW_PASS', defaultValue: 'demo');
const _go = String.fromEnvironment('TW_GO');
const _shuffle = bool.fromEnvironment('TW_SHUFFLE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final smtc = await SmtcControls.create();
  stdout.writeln('E2E smtc ${smtc == null ? 'UNAVAILABLE' : 'ready'}');
  final config = ServerConfig(baseUrl: Uri.parse(_url), credentials: const PasswordCredentials(_user, _pass));
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(retry: (_, _) => null, overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    sessionStoreProvider.overrideWithValue(MemorySessionStore(config)),
    initialSessionProvider.overrideWithValue(config),
    realEngineOverride(),
    if (smtc != null) systemMediaProvider.overrideWithValue(smtc),
  ]);
  runApp(UncontrolledProviderScope(container: container, child: const TidewaterApp()));

  final api = OpenSubsonicClient(config);
  final player = container.read(playbackProvider.notifier);
  container.listen(playbackProvider, (prev, next) {
    final t = next.track;
    if (t != null && (prev?.track?.id != t.id || prev?.playing != next.playing)) {
      stdout.writeln('E2E now "${t.title}" #${next.index + 1}/${next.queue.length} playing=${next.playing}');
    }
  });
  await Future<void>.delayed(const Duration(seconds: 3));
  await container.read(playbackEngineProvider).setVolume(.08);
  final albums = await api.getAlbumList(AlbumListType.random, size: 40);
  for (final a in albums) {
    final d = await api.getAlbum(a.id);
    if (d.tracks.length >= 4) {
      await player.playTracks(d.tracks, shuffle: _shuffle);
      break;
    }
  }
  stdout.writeln('E2E started');
  if (_shuffle) {
    await Future<void>.delayed(const Duration(seconds: 3));
    container.read(nowPlayingOpenProvider.notifier).set(true);
    await Future<void>.delayed(const Duration(seconds: 3));
    container.read(queueOpenProvider.notifier).set(true);
    await Future<void>.delayed(const Duration(seconds: 3));
    await player.next();
    await Future<void>.delayed(const Duration(seconds: 3));
    container.read(queueOpenProvider.notifier).set(false);
    container.read(nowPlayingOpenProvider.notifier).set(false);
  }
  for (final page in _go.split(',').where((p) => p.isNotEmpty)) {
    await Future<void>.delayed(const Duration(seconds: 6));
    container.read(routerProvider).go(page);
    stdout.writeln('E2E went to $page');
  }
  await Future<void>.delayed(const Duration(seconds: 8));
  stdout.writeln('E2E done');
  await player.stop();
  exit(0);
}
