// Frame timings with everything real: your server's data and covers, the
// libmpv engine making sound (quietly), real lyrics, the Windows media
// overlay. Run in --profile; it prints per-phase build/raster times and exits.
//
//   flutter run -d windows --profile -t tool/perf_real_main.dart ^
//     --dart-define=TW_URL=https://your.server --dart-define=TW_USER=u --dart-define=TW_PASS=p
//
// The refresh rate is read from the display; budgets are for that rate.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tidewater/app/app.dart';
import 'package:tidewater/app/playback/real_engine.dart';
import 'package:tidewater/app/providers/playback_providers.dart';
import 'package:tidewater/app/providers/session_providers.dart';
import 'package:tidewater/app/providers/settings_providers.dart';
import 'package:tidewater/app/providers/ui_providers.dart';
import 'package:tidewater/core/api/library_api.dart';
import 'package:tidewater/core/api/opensubsonic_client.dart';
import 'package:tidewater/core/api/server_config.dart';
import 'package:tidewater/core/api/session_store.dart';
import 'package:tidewater/core/models/track.dart';
import 'package:window_manager/window_manager.dart';

const _url = String.fromEnvironment('TW_URL', defaultValue: 'https://demo.navidrome.org');
const _user = String.fromEnvironment('TW_USER', defaultValue: 'demo');
const _pass = String.fromEnvironment('TW_PASS', defaultValue: 'demo');

/// Comma-separated scenario names to run (empty: all): home, library, scroll,
/// album, play, np, queue, lyrics, skips, idle.
const _only = String.fromEnvironment('TW_ONLY');
bool _want(String name) => _only.isEmpty || _only.split(',').contains(name);

class _Sample {
  _Sample(this.build, this.raster, this.total);
  final double build;
  final double raster;
  final double total;
}

final _phases = <String, List<_Sample>>{};
String _phase = 'startup';
double _hz = 60;

double _ms(Duration d) => d.inMicroseconds / 1000;

String _stats(List<double> v) {
  if (v.isEmpty) return '-';
  final s = [...v]..sort();
  double p(double q) => s[((s.length - 1) * q).round()];
  return 'p50 ${p(.5).toStringAsFixed(1)}  p90 ${p(.9).toStringAsFixed(1)}  p99 ${p(.99).toStringAsFixed(1)}  max ${s.last.toStringAsFixed(1)}';
}

void _report() {
  final budget = 1000 / _hz;
  debugPrint('\n===== real-data frame timings, display ${_hz.toStringAsFixed(0)} Hz (budget ${budget.toStringAsFixed(1)} ms) =====');
  for (final e in _phases.entries) {
    final f = e.value;
    debugPrint('[${e.key}] frames=${f.length}  >budget: ${f.where((x) => x.total > budget * 1.05).length}  '
        '>2x: ${f.where((x) => x.total > budget * 2).length}  >33ms: ${f.where((x) => x.total > 33.4).length}');
    debugPrint('   build  ${_stats([for (final x in f) x.build])}');
    debugPrint('   raster ${_stats([for (final x in f) x.raster])}');
    debugPrint('   total  ${_stats([for (final x in f) x.total])}');
  }
  debugPrint('===== done =====');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  const options = WindowOptions(size: Size(1280, 800), minimumSize: Size(720, 520), center: true, title: 'Tidewater (perf, real)', titleBarStyle: TitleBarStyle.hidden);
  await windowManager.waitUntilReadyToShow(options, () async => windowManager.show());

  final config = ServerConfig(baseUrl: Uri.parse(_url), credentials: const PasswordCredentials(_user, _pass));
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(retry: (_, _) => null, overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    sessionStoreProvider.overrideWithValue(MemorySessionStore(config)),
    initialSessionProvider.overrideWithValue(config),
    realEngineOverride(),
  ]);

  SchedulerBinding.instance.addTimingsCallback((List<ui.FrameTiming> timings) {
    for (final t in timings) {
      _phases.putIfAbsent(_phase, () => []).add(_Sample(_ms(t.buildDuration), _ms(t.rasterDuration), _ms(t.totalSpan)));
    }
  });
  _hz = WidgetsBinding.instance.platformDispatcher.displays.firstOrNull?.refreshRate ?? 60;

  runApp(UncontrolledProviderScope(container: container, child: const TidewaterApp()));
  unawaited(_scenario(container, OpenSubsonicClient(config)));
}

Future<void> _wait(double seconds) => Future<void>.delayed(Duration(milliseconds: (seconds * 1000).round()));

/// A mouse wheel turning over [at]: [ticks] notches of [dy] pixels.
Future<void> _scroll(Offset at, {int ticks = 60, double dy = 90}) async {
  for (var i = 0; i < ticks; i++) {
    GestureBinding.instance.handlePointerEvent(PointerScrollEvent(position: at, scrollDelta: Offset(0, dy)));
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
}

Future<void> _scenario(ProviderContainer c, OpenSubsonicClient api) async {
  final router = c.read(routerProvider);
  final player = c.read(playbackProvider.notifier);
  final engine = c.read(playbackEngineProvider);
  await engine.setVolume(.08);

  await _wait(3);
  if (_want('home')) {
    _phase = 'home (covers loading)';
    await _wait(4);
  }

  router.go('/library');
  if (_want('library')) {
    _phase = 'library (covers loading)';
    await _wait(5);
  } else {
    await _wait(4);
  }

  if (_want('scroll')) {
    _phase = 'library scrolling';
    await _scroll(const Offset(700, 500), ticks: 80);
    await _wait(1);
    await _scroll(const Offset(700, 500), ticks: 40, dy: -120);
    await _wait(1);
  }

  final albums = await api.getAlbumList(AlbumListType.random, size: 30);
  if (_want('album')) {
    _phase = 'album page';
    router.go('/album/${albums.first.id}');
    await _wait(3);
  }
  router.go('/home');
  await _wait(2.5);

  final detail = await api.getAlbum(albums[1].id);
  if (_want('play') || _want('np') || _want('queue') || _want('skips') || _want('idle')) {
    _phase = 'play album (recolor + wash)';
    await player.playTracks(detail.tracks);
    await _wait(3);
  }

  if (_want('np')) {
    _phase = 'open Now Playing';
    c.read(nowPlayingOpenProvider.notifier).set(true);
    await _wait(3);
    _phase = 'Now Playing steady (real position stream)';
    await _wait(6);
  } else if (_want('queue') || _want('skips') || _want('idle')) {
    c.read(nowPlayingOpenProvider.notifier).set(true);
    await _wait(3);
  }

  if (_want('queue')) {
    _phase = 'queue panel';
    c.read(queueOpenProvider.notifier).set(true);
    await _wait(2);
    c.read(queueOpenProvider.notifier).set(false);
    await _wait(1.5);
  }

  if (_want('lyrics')) {
    // A track that has lyrics (so the lyric transitions are the real ones).
    Track? withLyrics;
    for (final t in await api.getRandomSongs(size: 80)) {
      final l = await api.getLyrics(t.id);
      if (l != null && l.synced && l.lines.length > 12 && t.duration > const Duration(minutes: 2)) {
        withLyrics = t;
        break;
      }
    }
    c.read(nowPlayingOpenProvider.notifier).set(true);
    if (withLyrics != null) {
      await player.playTracks([withLyrics]);
      await _wait(3);
      final lyrics = await api.getLyrics(withLyrics.id);
      _phase = 'real lyric changes (card)';
      for (final i in [4, 5, 6, 7, 8]) {
        await engine.seek(lyrics!.lines[i].time - const Duration(milliseconds: 600));
        await _wait(2.4);
      }
    } else {
      debugPrint('(no synced lyrics found to measure)');
    }
  }

  if (_want('skips')) {
    _phase = 'track skips (title swap + recolor)';
    await player.playTracks(detail.tracks);
    await _wait(2);
    for (var i = 0; i < 3 && i < detail.tracks.length - 1; i++) {
      await player.next();
      await _wait(2.8);
    }
  }

  if (_want('idle')) {
    _phase = 'Now Playing idle mode';
    await _wait(7);
  }

  _report();
  await player.stop();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  exit(0);
}
