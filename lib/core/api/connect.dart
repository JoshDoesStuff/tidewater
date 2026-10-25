import 'api_exception.dart';
import 'library_api.dart';
import 'opensubsonic_client.dart';
import 'server_config.dart';

typedef ClientFactory = LibraryApi Function(ServerConfig config);

LibraryApi defaultClientFactory(ServerConfig config) => OpenSubsonicClient(config);

class Connection {
  const Connection(this.config, this.info);

  final ServerConfig config;
  final ServerInfo info;
}

/// Checks that [url] + [credentials] reach a working server.
///
/// An address typed without a scheme is tried as https and then http, so a
/// LAN server on plain http works without the person knowing the difference.
/// When every attempt fails, the most informative error wins (a rejected
/// certificate or a wrong password over "unreachable").
Future<Connection> connect({
  required String url,
  required Credentials credentials,
  bool trustBadCertificate = false,
  ClientFactory factory = defaultClientFactory,
}) async {
  final candidates = parseServerUrl(url);
  ApiException? best;
  for (final base in candidates) {
    final config = ServerConfig(baseUrl: base, credentials: credentials, trustBadCertificate: trustBadCertificate);
    final client = factory(config);
    try {
      final info = await client.ping();
      if (credentials is ApiKeyCredentials && !info.supports('apiKeyAuthentication')) {
        throw const ApiException(
          ApiErrorKind.unsupported,
          'This server doesn\'t support API keys. Sign in with your password instead.',
        );
      }
      return Connection(config, info);
    } on ApiException catch (e) {
      // Only a failure to connect makes the next scheme worth trying; the
      // server answered, so another scheme won't change what it says.
      final tryNext = e.kind == ApiErrorKind.unreachable || e.kind == ApiErrorKind.tls;
      if (!tryNext) rethrow;
      if (best == null || (best.kind == ApiErrorKind.unreachable && e.kind != ApiErrorKind.unreachable)) {
        best = e;
      }
    } finally {
      client.close();
    }
  }
  throw best!;
}
