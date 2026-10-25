import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidewater/app/providers/cover_providers.dart';
import 'package:tidewater/app/providers/session_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/cover_cache.dart';
import 'package:tidewater/core/api/library_api.dart';
import 'package:tidewater/core/api/server_config.dart';
import 'package:tidewater/core/api/session_store.dart';

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
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  final fake = api ?? FakeLibraryApi();
  return [
    sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    sessionStoreProvider.overrideWithValue(store ?? MemorySessionStore(signedIn ? testServer : null)),
    initialSessionProvider.overrideWithValue(signedIn ? testServer : null),
    clientFactoryProvider.overrideWithValue((_) => fake),
    coverCacheProvider.overrideWithValue(NoCovers()),
  ];
}

/// No cover art, instantly (the real cache does file IO, which never
/// completes under fake async).
class NoCovers implements CoverStore {
  @override
  Future<Uint8List> get(String id, {int size = 300}) =>
      Future.error(const ApiException(ApiErrorKind.notFound, 'no cover in tests'));
}
