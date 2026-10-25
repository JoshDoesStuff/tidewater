import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/connect.dart';
import '../../core/api/library_api.dart';
import '../../core/api/server_config.dart';
import '../../core/api/session_store.dart';
import 'settings_providers.dart' show hideJapaneseProvider;

/// Overridden in `main()` (and in tests).
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('sessionStoreProvider must be overridden'),
);

/// The saved server loaded at startup, before the first frame. Not pinged: an
/// offline launch must still open the app (with its offline states).
final initialSessionProvider = Provider<ServerConfig?>((ref) => null);

/// Builds the client for a server. Tests swap in an in-memory one.
final clientFactoryProvider = Provider<ClientFactory>((ref) => defaultClientFactory);

/// Which server we are signed in to, or null (show the login screen).
class SessionNotifier extends Notifier<ServerConfig?> {
  @override
  ServerConfig? build() => ref.watch(initialSessionProvider);

  Future<void> signIn(ServerConfig config) async {
    await ref.read(sessionStoreProvider).save(config);
    state = config;
  }

  Future<void> signOut() async {
    await ref.read(sessionStoreProvider).clear();
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, ServerConfig?>(SessionNotifier.new);

/// The API for the signed-in server. Only read while signed in; the router
/// keeps the login screen up otherwise.
final apiProvider = Provider<LibraryApi>((ref) {
  final config = ref.watch(sessionProvider);
  if (config == null) throw StateError('Not signed in');
  // Names are filtered as they are parsed, so flipping the setting refetches.
  ref.watch(hideJapaneseProvider);
  final api = ref.watch(clientFactoryProvider)(config);
  ref.onDispose(api.close);
  return api;
});

/// Server version and OpenSubsonic extensions (`songLyrics`, ...). Loaded in
/// the background; null while offline.
final serverInfoProvider = FutureProvider<ServerInfo>((ref) => ref.watch(apiProvider).ping());
