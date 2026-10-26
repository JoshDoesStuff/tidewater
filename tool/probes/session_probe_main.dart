// Round-trips a session through the real PrefsSessionStore (shared_preferences
// + Windows secure storage) and prints the result, then exits.
//
//   flutter run -d windows -t tool/probes/session_probe_main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidewater/app/session/prefs_session_store.dart';
import 'package:tidewater/core/api/server_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = PrefsSessionStore(await SharedPreferences.getInstance());
  final config = ServerConfig(
    baseUrl: Uri.parse('https://probe.example.com:4533/navidrome'),
    credentials: const PasswordCredentials('probe-user', 'p@ss w0rd/ünïcode'),
    trustBadCertificate: true,
  );
  var ok = true;
  void check(String what, bool pass) {
    ok &= pass;
    stdout.writeln('PROBE ${pass ? 'ok  ' : 'FAIL'} $what');
  }

  await store.save(config);
  final back = await store.load();
  final creds = back?.credentials;
  check('round trip url', back?.baseUrl == config.baseUrl);
  check('round trip secret', creds is PasswordCredentials && creds.password == 'p@ss w0rd/ünïcode' && creds.username == 'probe-user');
  check('trust flag', back?.trustBadCertificate == true);
  final prefs = await SharedPreferences.getInstance();
  check('secret is not in shared_preferences', !prefs.getKeys().any((k) => (prefs.get(k) ?? '').toString().contains('p@ss')));

  await store.clear();
  check('cleared', await store.load() == null);
  check('last server is remembered', store.lastServer.user == 'probe-user');

  await store.save(config.copyWith(credentials: const ApiKeyCredentials('key-123', username: 'probe-user')));
  final key = (await store.load())?.credentials;
  check('api key round trip', key is ApiKeyCredentials && key.apiKey == 'key-123');
  await store.clear();
  await prefs.clear();
  stdout.writeln('PROBE ${ok ? 'ALL OK' : 'FAILED'}');
  exit(ok ? 0 : 1);
}
