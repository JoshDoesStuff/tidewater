import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidewater/app/providers/cover_providers.dart';
import 'package:tidewater/app/providers/lyrics_providers.dart';
import 'package:tidewater/app/playback/system_media.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/system_media_providers.dart';
import 'package:tidewater/app/providers/session_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/connect.dart';
import 'package:tidewater/core/api/cover_cache.dart';
import 'package:tidewater/core/api/library_api.dart';
import 'package:tidewater/core/api/server_config.dart';
import 'package:tidewater/core/api/session_store.dart';
import 'package:tidewater/core/lyrics/lyrics.dart';
import 'package:tidewater/core/models/track.dart';
import 'package:tidewater/core/playback/simulated_engine.dart';

import 'fake_library.dart';

final testServer = ServerConfig(
  baseUrl: Uri.parse('http://test.local'),
  credentials: const PasswordCredentials('josh', 'sesame'),
);

/// Overrides that put the app on an in-memory server. [signedIn] false starts
/// at the login screen.
Future<List<Override>> testOverrides({
  LibraryApi? api,
  bool signedIn = true,
  SessionStore? store,
  Map<String, Object> prefs = const {},
  ClientFactory? factory,
  Future<Lyrics?> Function(Track track)? lrclib,
  SystemMediaControls? media,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  final fake = api ?? FakeLibraryApi();
  return [
    sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    sessionStoreProvider.overrideWithValue(store ?? MemorySessionStore(signedIn ? testServer : null)),
    initialSessionProvider.overrideWithValue(signedIn ? testServer : null),
    clientFactoryProvider.overrideWithValue(factory ?? (_) => fake),
    coverCacheProvider.overrideWithValue(NoCovers()),
    lyricsFallbackProvider.overrideWithValue(lrclib ?? (_) async => null),
    systemMediaProvider.overrideWithValue(media ?? const NoSystemMedia()),
    // The simulated clock uses the real stopwatch, which fake time does not
    // advance; a slow tick keeps it from emitting stray positions.
    playbackEngineProvider.overrideWith((ref) {
      final engine = SimulatedEngine(tick: const Duration(hours: 1));
      ref.onDispose(engine.dispose);
      return engine;
    }),
  ];
}

/// No cover art, instantly (the real cache does file IO, which never
/// completes under fake async).
class NoCovers implements CoverStore {
  @override
  Future<Uint8List> get(String id, {int size = 300}) =>
      Future.error(const ApiException(ApiErrorKind.notFound, 'no cover in tests'));

  @override
  Future<String?> localPath(String id, {int size = 300}) async => null;
}
