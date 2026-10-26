import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned answer for one request.
class StubResponse {
  StubResponse(this.body, {this.status = 200, this.contentType = 'application/json'});

  /// JSON fixture file (relative to `test/fixtures`).
  factory StubResponse.fixture(String name, {int status = 200}) =>
      StubResponse(File('test/fixtures/$name').readAsStringSync(), status: status);

  final Object body; // String or List<int>
  final int status;
  final String contentType;
}

/// Replaces the network: [handler] sees every request and returns the answer,
/// or throws a [DioException] to simulate a transport failure.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);

  final FutureOr<StubResponse> Function(Uri uri) handler;
  final requests = <Uri>[];
  final methods = <String>[];

  /// The body of each request (empty for GETs).
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options.uri);
    methods.add(options.method);
    bodies.add(requestStream == null ? '' : utf8.decode([for (final chunk in await requestStream.toList()) ...chunk]));
    final r = await handler(options.uri);
    final bytes = r.body is String ? utf8.encode(r.body as String) : r.body as List<int>;
    return ResponseBody.fromBytes(
      bytes,
      r.status,
      headers: {
        Headers.contentTypeHeader: [r.contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A `Dio` wired to a [StubAdapter].
Dio stubDio(StubAdapter adapter) => Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = adapter;
