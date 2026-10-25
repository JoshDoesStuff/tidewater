import 'server_config.dart';

/// Remembers which server we are signed in to. Implementations keep the
/// secret (password / API key) somewhere safer than the rest.
abstract class SessionStore {
  Future<ServerConfig?> load();
  Future<void> save(ServerConfig config);
  Future<void> clear();

  /// Last server and user name typed, to prefill the login form after a
  /// sign-out.
  ({String url, String user}) get lastServer;
}

/// For tests and previews.
class MemorySessionStore implements SessionStore {
  MemorySessionStore([this.config]);

  ServerConfig? config;

  @override
  Future<ServerConfig?> load() async => config;

  @override
  Future<void> save(ServerConfig config) async => this.config = config;

  @override
  Future<void> clear() async => config = null;

  @override
  ({String url, String user}) get lastServer => (url: config?.baseUrl.toString() ?? '', user: config?.username ?? '');
}
