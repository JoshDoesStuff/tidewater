import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/connect.dart';
import 'package:tidewater/core/api/library_api.dart';
import 'package:tidewater/core/api/server_config.dart';

import '../support/fake_library.dart';

/// Answers `ping` per scheme from a script, and records which servers were tried.
class _ScriptedApi extends FakeLibraryApi {
  _ScriptedApi(this.config, this.script, this.log);

  final ServerConfig config;
  final Map<String, Object> script; // scheme -> ApiException | ServerInfo
  final List<String> log;
  bool closed = false;

  @override
  Future<ServerInfo> ping() async {
    log.add(config.baseUrl.toString());
    final answer = script[config.baseUrl.scheme];
    if (answer is ApiException) throw answer;
    return (answer as ServerInfo?) ?? await super.ping();
  }

  @override
  void close() => closed = true;
}

const _password = PasswordCredentials('josh', 'sesame');

Future<Connection> _connect(
  String url,
  Map<String, Object> script,
  List<String> log, {
  Credentials credentials = _password,
  bool trust = false,
  List<_ScriptedApi>? made,
}) =>
    connect(
      url: url,
      credentials: credentials,
      trustBadCertificate: trust,
      factory: (config) {
        final api = _ScriptedApi(config, script, log);
        made?.add(api);
        return api;
      },
    );

const _unreachable = ApiException(ApiErrorKind.unreachable, 'down');
const _tls = ApiException(ApiErrorKind.tls, 'cert');
const _badLogin = ApiException(ApiErrorKind.badCredentials, 'nope', code: 40);

void main() {
  test('an address without a scheme tries https first and uses it when it works', () async {
    final log = <String>[];
    final c = await _connect('music.example.com', {}, log);
    expect(log, ['https://music.example.com']);
    expect(c.config.baseUrl.scheme, 'https');
  });

  test('falls back to http when https is unreachable', () async {
    final log = <String>[];
    final c = await _connect('192.168.1.5:4533', {'https': _unreachable}, log);
    expect(log, ['https://192.168.1.5:4533', 'http://192.168.1.5:4533']);
    expect(c.config.baseUrl.scheme, 'http');
  });

  test('a typed scheme is never second-guessed', () async {
    final log = <String>[];
    await expectLater(_connect('https://music.example.com', {'https': _unreachable}, log), throwsA(isA<ApiException>()));
    expect(log, ['https://music.example.com']);
  });

  test('wrong password stops immediately (another scheme would say the same)', () async {
    final log = <String>[];
    try {
      await _connect('music.example.com', {'https': _badLogin}, log);
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.kind, ApiErrorKind.badCredentials);
    }
    expect(log, hasLength(1));
  });

  test('when both fail, the certificate error wins over "unreachable"', () async {
    final log = <String>[];
    try {
      await _connect('music.example.com', {'https': _tls, 'http': _unreachable}, log);
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.kind, ApiErrorKind.tls);
    }
    expect(log, hasLength(2));
  });

  test('every probe client is closed', () async {
    final made = <_ScriptedApi>[];
    await _connect('x.example.com', {'https': _unreachable}, [], made: made);
    expect(made, hasLength(2));
    expect(made.every((a) => a.closed), isTrue);
  });

  test('trusting the certificate is passed on to the client', () async {
    final seen = <bool>[];
    await connect(
      url: 'https://nas.local',
      credentials: _password,
      trustBadCertificate: true,
      factory: (config) {
        seen.add(config.trustBadCertificate);
        return FakeLibraryApi();
      },
    );
    expect(seen, [true]);
  });

  test('an API key needs the apiKeyAuthentication extension', () async {
    const plain = ServerInfo(apiVersion: '1.16.1', openSubsonic: true);
    try {
      await connect(
        url: 'https://music.example.com',
        credentials: const ApiKeyCredentials('k'),
        factory: (config) => _ScriptedApi(config, {'https': plain}, []),
      );
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.kind, ApiErrorKind.unsupported);
    }
    // FakeLibraryApi advertises it.
    final ok = await connect(
      url: 'https://music.example.com',
      credentials: const ApiKeyCredentials('k'),
      factory: (_) => FakeLibraryApi(),
    );
    expect(ok.info.supports('apiKeyAuthentication'), isTrue);
  });

  test('a bad address fails before any request', () async {
    final log = <String>[];
    await expectLater(_connect('   ', {}, log), throwsA(isA<ApiException>()));
    expect(log, isEmpty);
  });
}
