// Runs the cover-color pipeline on real covers from a real server and checks
// that every resulting scheme keeps text readable (WCAG >= 4.5). Not part of
// the normal suite (it needs the network):
//
//   flutter test tool/probes/real_covers_test.dart
//
// Defaults to the public Navidrome demo; point it at your own server with
// TIDEWATER_URL, TIDEWATER_USER and TIDEWATER_PASS (and TIDEWATER_ALBUMS to
// check more than 40 albums).
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidewater/app/providers/cover_providers.dart';
import 'package:tidewater/app/theme/album_scheme.dart';
import 'package:tidewater/core/api/library_api.dart';
import 'package:tidewater/core/api/opensubsonic_client.dart';
import 'package:tidewater/core/api/server_config.dart';

double _lum(Color c) {
  double ch(double v) => v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  return .2126 * ch(c.r) + .7152 * ch(c.g) + .0722 * ch(c.b);
}

double _ratio(Color a, Color b) {
  final l1 = _lum(a);
  final l2 = _lum(b);
  return (math.max(l1, l2) + .05) / (math.min(l1, l2) + .05);
}

void main() {
  testWidgets('real covers give readable schemes', (tester) async {
    HttpOverrides.global = null; // flutter test blocks the network by default
    final env = Platform.environment;
    final client = OpenSubsonicClient(ServerConfig(
      baseUrl: Uri.parse(env['TIDEWATER_URL'] ?? 'https://demo.navidrome.org'),
      credentials: PasswordCredentials(env['TIDEWATER_USER'] ?? 'demo', env['TIDEWATER_PASS'] ?? 'demo'),
    ));
    final count = int.tryParse(env['TIDEWATER_ALBUMS'] ?? '') ?? 40;

    await tester.runAsync(() async {
      final albums = await client.getAlbumList(AlbumListType.random, size: count);
      var checked = 0;
      var muted = 0;
      final failures = <String>[];
      for (final album in albums) {
        if (album.coverArt == null) continue;
        final seed = await seedFromImageBytes(await client.getCoverArt(album.coverArt!, size: 300));
        checked++;
        if (seed.muted) muted++;
        for (final brightness in Brightness.values) {
          final s = AlbumScheme.of(seed, brightness);
          final worst = [
            _ratio(s.primary, s.surfaceContainerHigh),
            _ratio(s.onSurface, s.surface),
            _ratio(s.onSurfaceVariant, s.surfaceContainerHigh),
          ].reduce(math.min);
          if (worst < 4.5) failures.add('${album.title} ($brightness): $worst');
        }
        debugPrint('${album.title.padRight(32).substring(0, 32)} ${seed.argb.toRadixString(16)}${seed.muted ? '  muted' : ''}');
      }
      debugPrint('$checked covers, $muted muted, ${failures.length} failures');
      expect(checked, greaterThan(0));
      expect(failures, isEmpty);
    });
    client.close();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
