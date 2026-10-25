import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/server_config.dart';
import '../../core/api/session_store.dart';

/// Server URL, user name and auth mode live in `shared_preferences`; the
/// password or API key lives in `flutter_secure_storage` (Windows Credential
/// Locker / DPAPI) and is never written anywhere else.
class PrefsSessionStore implements SessionStore {
  PrefsSessionStore(this._prefs, [FlutterSecureStorage? secure]) : _secure = secure ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _url = 'server.url';
  static const _user = 'server.user';
  static const _mode = 'server.mode'; // 'password' | 'apiKey'
  static const _trust = 'server.trustCert';
  static const _secret = 'server.secret';

  @override
  Future<ServerConfig?> load() async {
    final url = _prefs.getString(_url);
    final mode = _prefs.getString(_mode);
    if (url == null || mode == null) return null;
    final String? secret;
    try {
      secret = await _secure.read(key: _secret);
    } catch (_) {
      // Unreadable secret store: behave as signed out rather than crash.
      return null;
    }
    if (secret == null) return null;
    final user = _prefs.getString(_user) ?? '';
    return ServerConfig(
      baseUrl: Uri.parse(url),
      credentials: mode == 'apiKey' ? ApiKeyCredentials(secret, username: user) : PasswordCredentials(user, secret),
      trustBadCertificate: _prefs.getBool(_trust) ?? false,
    );
  }

  @override
  Future<void> save(ServerConfig config) async {
    final (mode, secret) = switch (config.credentials) {
      PasswordCredentials c => ('password', c.password),
      ApiKeyCredentials c => ('apiKey', c.apiKey),
    };
    await _secure.write(key: _secret, value: secret);
    await _prefs.setString(_url, config.baseUrl.toString());
    await _prefs.setString(_user, config.username);
    await _prefs.setString(_mode, mode);
    await _prefs.setBool(_trust, config.trustBadCertificate);
  }

  @override
  Future<void> clear() async {
    // Keep the URL and user name so signing back in is quick; drop the secret.
    try {
      await _secure.delete(key: _secret);
    } catch (_) {}
    await _prefs.remove(_mode);
  }

  @override
  ({String url, String user}) get lastServer => (url: _prefs.getString(_url) ?? '', user: _prefs.getString(_user) ?? '');
}
