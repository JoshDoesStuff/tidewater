/// Why a request to the server failed, in terms the login screen and the
/// offline/error states can act on.
enum ApiErrorKind {
  /// The URL could not be understood.
  badUrl,

  /// No answer: DNS, refused connection, timeout, no network.
  unreachable,

  /// Certificate rejected (self-signed, expired, wrong host).
  tls,

  /// Something answered, but it is not a Subsonic/Navidrome server.
  notSubsonic,

  /// Wrong user, password or API key.
  badCredentials,

  /// The server lacks something we need (for example API keys).
  unsupported,

  /// The requested item no longer exists.
  notFound,

  /// The server reported an error of its own.
  server,
}

class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.code});

  final ApiErrorKind kind;
  final String message;

  /// Subsonic error code, when the server sent one.
  final int? code;

  /// Network-level failures that a retry may fix (shown with a retry button).
  bool get isOffline => kind == ApiErrorKind.unreachable;

  @override
  String toString() => 'ApiException(${kind.name}${code == null ? '' : ' $code'}): $message';
}
