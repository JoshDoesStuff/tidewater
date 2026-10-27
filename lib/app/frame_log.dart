import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;

import '../core/api/cover_cache.dart' show CoverCacheStats;
import 'perf_stats.dart';

/// In a profile build, a log of how frames went, to the console and to a file
/// (`tidewater_perf.log` in the system temp folder; the path is printed at start).
///
/// Every three seconds that frames were drawn, a summary:
///
/// `FRAMES 3s: 162 drawn, 41 over 16.7 ms | build avg 2.1 max 9.4 | raster avg 21.3 p90 30.2 max 41.0`
///
/// and, in the file only, one line per slow frame (over 10 ms on either thread) with the
/// engine's raster cache numbers and what the app did since the frames before it (cards built
/// and pictured, covers read, downloaded, decoded and shown, entrances started) and its state
/// (live and pictured cards, covers waiting, image cache, scroll speed). "build" is Dart
/// (widgets, layout, recording paint), "raster" is the GPU thread.
void logSlowFrames() {
  if (!kProfileMode) return;
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}tidewater_perf.log');
  try {
    _out = file.openSync(mode: FileMode.write);
    _out!.writeStringSync('# Tidewater profile log, started ${DateTime.now()}\n');
  } catch (_) {}
  debugPrint('PERF LOG: ${file.path}');
  WidgetsBinding.instance.addObserver(_WindowWatch());
  // The cover queue, once a second while covers wait their turn; and the Songs tab's distinct
  // cover ids whenever that count has changed.
  var lastDistinct = 0;
  Timer.periodic(const Duration(seconds: 1), (_) {
    if (CoverCacheStats.waiting > 0) {
      perfNote('GATE waiting=${CoverCacheStats.waiting} loading=${CoverCacheStats.loading}');
    }
    final distinct = PerfStats.songsTabCovers.length;
    if (distinct != lastDistinct) {
      lastDistinct = distinct;
      if (distinct > 0) perfNote('covers distinctIds=$distinct');
    }
  });

  final clock = _clock..start();
  final build = <double>[];
  final raster = <double>[];
  var since = DateTime.now();
  // Totals over the 3 s window.
  var wBuilt = 0, wBaked = 0, wBakeUs = 0, wShown = 0, wDisk = 0, wDown = 0, wDecodes = 0, wDecodeUs = 0, wEntr = 0;
  var unflushed = 0;
  var wWasted = 0, wTwice = 0;

  String f(double v) => v.toStringAsFixed(1);

  SchedulerBinding.instance.addTimingsCallback((timings) {
    // What happened since the last batch of timings (a batch is one to a few frames).
    final built = PerfStats.cardsBuilt, baked = PerfStats.cardsBaked, bakeUs = PerfStats.bakeMicros;
    final shown = PerfStats.coversShown, mem = PerfStats.coversShownFromMemory;
    final disk = CoverCacheStats.diskReads, down = CoverCacheStats.downloads, decodes = CoverCacheStats.decodes, decodeUs = PerfStats.decodeMicros;
    final dropped = CoverCacheStats.skipped + CoverCacheStats.cancelled;
    final wasted = CoverCacheStats.downloadsWasted, twice = PerfStats.bakedTwice;
    CoverCacheStats.downloadsWasted = 0;
    wWasted += wasted;
    wTwice += twice;
    CoverCacheStats.diskReads = CoverCacheStats.downloads = CoverCacheStats.decodes = 0;
    CoverCacheStats.skipped = CoverCacheStats.cancelled = 0;
    final entr = PerfStats.entrances, failed = PerfStats.bakesFailed;
    final moved = PerfStats.moved, biggestMove = PerfStats.biggestMove;
    final cardBuilds = PerfStats.cardBuilds, rowBuilds = PerfStats.rowBuilds, standIns = PerfStats.standIns, heldBack = PerfStats.coversHeldBack;
    PerfStats.reset();
    wBuilt += built;
    wBaked += baked;
    wBakeUs += bakeUs;
    wShown += shown;
    wDisk += disk;
    wDown += down;
    wDecodes += decodes;
    wDecodeUs += decodeUs;
    wEntr += entr;

    final cache = PaintingBinding.instance.imageCache;
    final rss = ProcessInfo.currentRss ~/ 1048576;
    final rssDelta = rss - _lastRss;
    _lastRss = rss;
    for (final t in timings) {
      final b = t.buildDuration.inMicroseconds / 1000;
      final r = t.rasterDuration.inMicroseconds / 1000;
      build.add(b);
      raster.add(r);
      if ((b > 10 || r > 10) && _out != null) {
        final line = StringBuffer()
          ..write('SLOW t=${(clock.elapsedMilliseconds / 1000).toStringAsFixed(2)}s ')
          ..write('build=${f(b)} raster=${f(r)} vsyncWait=${f(t.vsyncOverhead.inMicroseconds / 1000)} total=${f(t.totalSpan.inMicroseconds / 1000)} ')
          ..write('| rasterCache layers=${t.layerCacheCount} (${(t.layerCacheBytes / 1048576).toStringAsFixed(1)} MB) ')
          ..write('pictures=${t.pictureCacheCount} (${(t.pictureCacheBytes / 1048576).toStringAsFixed(1)} MB) ')
          ..write('| since last: cardsBuilt=$built pictured=$baked (${f(bakeUs / 1000)} ms) bakeFailed=$failed ')
          ..write('cardBuilds=$cardBuilds standIns=$standIns rowBuilds=$rowBuilds coversShown=$shown (fromMemory=$mem) diskReads=$disk downloads=$down decodes=$decodes (${f(decodeUs / 1000)} ms) coversDropped=$dropped downloadsWasted=$wasted bakedTwice=$twice coversHeldBack=$heldBack entrances=$entr ')
          ..write('| now: liveCards=${PerfStats.liveCards} pictureCards=${PerfStats.pictureCards} ')
          ..write('coversWaiting=${CoverCacheStats.waiting} coversLoading=${CoverCacheStats.loading} ')
          ..write('imageCache=${cache.currentSize} (${(cache.currentSizeBytes / 1048576).toStringAsFixed(0)} MB) live=${cache.liveImageCount} pending=${cache.pendingImageCount} ')
          ..write('scrolling=${PerfStats.scrolling} speed=${PerfStats.scrollSpeed.toStringAsFixed(0)}px/s moved=${moved.toStringAsFixed(0)}px (biggest step ${biggestMove.toStringAsFixed(0)}) by=${PerfStats.scrollBy} ')
          ..write('memory=${rss}MB (${rssDelta >= 0 ? '+' : ''}$rssDelta)${PerfStats.recoloring ? ' RECOLORING' : ''} | at: ${PerfStats.screen} | ${_sinceNote.elapsedMilliseconds} ms after: $_lastNote');
        try {
          _out!.writeStringSync('$line\n');
          unflushed++;
        } catch (_) {}
      }
    }
    if (unflushed > 20) {
      try {
        _out?.flushSync();
      } catch (_) {}
      unflushed = 0;
    }

    final now = DateTime.now();
    if (now.difference(since) < const Duration(seconds: 3)) return;
    since = now;
    if (raster.length >= 20) {
      double avg(List<double> l) => l.reduce((a, b) => a + b) / l.length;
      final sorted = [...raster]..sort();
      final slow = [for (var i = 0; i < raster.length; i++) if (raster[i] > 16.7 || build[i] > 16.7) 1].length;
      final summary = 'FRAMES 3s: ${raster.length} drawn, $slow over 16.7 ms | build avg ${f(avg(build))} max ${f(build.reduce((a, b) => a > b ? a : b))}'
          ' | raster avg ${f(avg(raster))} p90 ${f(sorted[(sorted.length * .9).floor()])} max ${f(sorted.last)}';
      debugPrint(summary);
      final where = 'memory=${ProcessInfo.currentRss ~/ 1048576}MB at: ${PerfStats.screen}';
      try {
        _out?.writeStringSync('$summary | cardsBuilt=$wBuilt pictured=$wBaked (${f(wBakeUs / 1000)} ms) coversShown=$wShown '
            'diskReads=$wDisk downloads=$wDown decodes=$wDecodes (${f(wDecodeUs / 1000)} ms) entrances=$wEntr downloadsWasted=$wWasted bakedTwice=$wTwice | $where\n');
        _out?.flushSync();
      } catch (_) {}
    }
    build.clear();
    raster.clear();
    wBuilt = wBaked = wBakeUs = wShown = wDisk = wDown = wDecodes = wDecodeUs = wEntr = 0;
    wWasted = wTwice = 0;
  });
}

RandomAccessFile? _out;
var _lastRss = 0;
var _lastNote = 'start';
final _sinceNote = Stopwatch()..start();
final _clock = Stopwatch();
var _marks = 0;

/// Writes a line to the console and the profile log file (switch changes, marks).
void perfNote(String message) {
  if (!kProfileMode) return;
  _lastNote = message;
  _sinceNote..reset()..start();
  debugPrint(message);
  try {
    _out?.writeStringSync('NOTE t=${(_clock.elapsedMilliseconds / 1000).toStringAsFixed(2)}s $message\n');
    _out?.flushSync();
  } catch (_) {}
}

/// Ctrl+Alt+M: a numbered mark in the log, to split it into the steps of a test run.
void perfMark() => perfNote('MARK ${++_marks}');

/// Window size changes (a resize redraws every card) and focus or minimize, into the log.
class _WindowWatch with WidgetsBindingObserver {
  Timer? _settle;

  @override
  void didChangeMetrics() {
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 300), () {
      final view = WidgetsBinding.instance.platformDispatcher.implicitView;
      if (view == null) return;
      final size = view.physicalSize / view.devicePixelRatio;
      perfNote('WINDOW ${size.width.round()}x${size.height.round()} at ${view.devicePixelRatio}x');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => perfNote('APP ${state.name}');
}

/// Seconds on the profile log's clock (the `t=` of every line).
double get perfClockSeconds => _clock.elapsedMilliseconds / 1000;

/// Whether a screen recording is marked as running (Ctrl+Alt+R); see `RecordingBadge`.
final perfRecording = ValueNotifier<bool>(false);

/// Ctrl+Alt+R: marks the start or end of a screen recording in the log (and on screen).
void perfToggleRecording() {
  perfRecording.value = !perfRecording.value;
  perfNote(perfRecording.value ? 'REC start (badge on screen shows this clock)' : 'REC stop');
}
