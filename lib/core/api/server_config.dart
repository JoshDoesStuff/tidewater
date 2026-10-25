import 'api_exception.dart';

/// How we prove who we are: Subsonic token auth (`md5(password + salt)`) or
/// an OpenSubsonic API key.
sealed class Credentials {
  const Credentials();
}

class PasswordCredentials extends Credentials {
  const PasswordCredentials(this.username, this.password);

  final String username;
  final String password;
}

class ApiKeyCredentials extends Credentials {
  const ApiKeyCredentials(this.apiKey, {this.username = ''});

  final String apiKey;

  /// Only used for display; API-key requests carry no username.
  final String username;
}

/// A server we can talk to: base URL (no trailing slash, no `/rest`) plus
/// credentials.
class ServerConfig {
  const ServerConfig({required this.baseUrl, required this.credentials, this.trustBadCertificate = false});

  final Uri baseUrl;
  final Credentials credentials;

  /// The user chose to accept this server's untrusted certificate.
  final bool trustBadCertificate;

  String get username => switch (credentials) {
        PasswordCredentials c => c.username,
        ApiKeyCredentials c => c.username,
      };

  ServerConfig copyWith({Credentials? credentials, Uri? baseUrl, bool? trustBadCertificate}) => ServerConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        credentials: credentials ?? this.credentials,
        trustBadCertificate: trustBadCertificate ?? this.trustBadCertificate,
      );
}

/// Turns what a person types into candidate base URLs, most likely first.
///
/// "music.example.com" has no scheme, so we try https then http. A trailing
/// slash, `/rest` and `/app` are dropped; a sub-path (reverse proxy) is kept.
List<Uri> parseServerUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) throw const ApiException(ApiErrorKind.badUrl, 'Enter your server address.');
  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(text);
  final schemes = hasScheme ? [''] : ['https://', 'http://'];
  final out = <Uri>[];
  for (final scheme in schemes) {
    final uri = Uri.tryParse('$scheme$text');
    if (uri == null || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const ApiException(ApiErrorKind.badUrl, 'That doesn\'t look like a web address. Try https://music.example.com');
    }
    final slashes = RegExp(r'/+$');
    var path = uri.path.replaceAll(slashes, '');
    for (final tail in const ['/rest', '/app']) {
      if (path.endsWith(tail)) path = path.substring(0, path.length - tail.length);
    }
    path = path.replaceAll(slashes, '');
    out.add(Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null, path: path));
  }
  return out;
}
