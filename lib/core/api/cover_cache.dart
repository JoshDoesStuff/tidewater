import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// What the cover cache has done (read by the profile log; plain counters, no Flutter here).
class CoverCacheStats {
  static int diskReads = 0;
  static int downloads = 0;
  static int decodes = 0;
  static int waiting = 0;
  static int loading = 0;
  static int cancelled = 0;
  static int skipped = 0;
}

typedef CoverFetch = Future<Uint8List> Function(String coverArt, int size);

/// Where cover bytes come from. The disk cache is the real one; tests use an
/// in-memory stand-in (file IO never completes under fake async).
abstract class CoverStore {
  Future<Uint8List> get(String id, {int size = 300, bool Function()? wanted});
}

/// Cover art on disk, keyed by `coverArt` id and pixel size (the same cover at
/// 300 and 800 px are two files). A request for something already on disk
/// never touches the network; concurrent requests for the same file share one
/// download.
class CoverCache implements CoverStore {
  CoverCache({required Future<Directory> Function() directory, required this._fetch}) : _resolve = directory;

  final Future<Directory> Function() _resolve;
  Directory? _directory;

  /// Cache folder (one per server, so ids from different servers never mix).
  Future<Directory> get directory async => _directory ??= await _resolve();
  final CoverFetch _fetch;
  final _inFlight = <String, Future<Uint8List>>{};

  /// At most this many covers are read or downloaded at once. A screenful of new cards used to
  /// start sixty reads, decodes and downloads in the same instant and arrive in one burst; now
  /// they come in a steady stream, the newest requests first (those are the cards the user just
  /// scrolled to; older ones may already be off screen).
  final _gate = _Gate(6);

  /// A folder name that identifies one server (same URL -> same folder).
  static String serverFolder(Uri baseUrl) => sha1.convert(baseUrl.toString().codeUnits).toString().substring(0, 12);

  /// Sizes snap to a few buckets so the cache doesn't fill with one-off sizes.
  static int bucket(int size) => size <= 150 ? 150 : (size <= 300 ? 300 : 800);

  File _file(Directory dir, String id, int size) {
    // Ids are opaque strings from the server; keep file names safe.
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return File('${dir.path}${Platform.pathSeparator}${safe}_$size.img');
  }

  @override
  Future<Uint8List> get(String id, {int size = 300, bool Function()? wanted}) {
    final px = bucket(size);
    final key = '${id}_$px';
    return _inFlight.putIfAbsent(key, () async {
      await _gate.enter();
      try {
        if (wanted != null && !wanted()) {
          // Nobody is waiting for it any more (the card scrolled away while it queued).
          CoverCacheStats.skipped++;
          throw const CoverSkipped();
        }
        final dir = await directory;
        final file = _file(dir, id, px);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          CoverCacheStats.diskReads++;
          if (bytes.isNotEmpty) return bytes;
        }
        CoverCacheStats.downloads++;
        final bytes = await _fetch(id, px);
        try {
          await dir.create(recursive: true);
          // Write then rename so a crash never leaves a half-written image.
          final tmp = File('${file.path}.part');
          await tmp.writeAsBytes(bytes, flush: true);
          await tmp.rename(file.path);
        } on FileSystemException {
          // A full or read-only disk only costs us caching.
        }
        return bytes;
      } finally {
        _gate.leave();
        // (A block body: returning the removed future would re-raise its error.)
        scheduleMicrotask(() {
          _inFlight.remove(key);
        });
      }
    });
  }

  /// Deletes the oldest files until the folder is under [maxBytes].
  Future<void> trim(int maxBytes) async {
    final dir = await directory;
    if (!await dir.exists()) return;
    final files = <(File, FileStat)>[];
    var total = 0;
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final stat = await e.stat();
      files.add((e, stat));
      total += stat.size;
    }
    if (total <= maxBytes) return;
    files.sort((a, b) => a.$2.accessed.compareTo(b.$2.accessed));
    for (final (file, stat) in files) {
      if (total <= maxBytes) break;
      try {
        await file.delete();
        total -= stat.size;
      } on FileSystemException {
        // In use or already gone.
      }
    }
  }

  Future<void> clear() async {
    final dir = await directory;
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// A load given up before it began: [CoverStore.get]'s `wanted` said no.
class CoverSkipped implements Exception {
  const CoverSkipped();
}

/// Lets [limit] callers through at a time; the rest wait, newest first.
class _Gate {
  _Gate(this.limit);

  final int limit;
  int _inside = 0;
  final _waiting = <Completer<void>>[];

  Future<void> enter() {
    if (_inside < limit) {
      _inside++;
      CoverCacheStats.loading = _inside;
      return Future.value();
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    CoverCacheStats.waiting = _waiting.length;
    return turn.future;
  }

  void leave() {
    if (_waiting.isNotEmpty) {
      // The place passes straight to the newest waiter.
      _waiting.removeLast().complete();
      CoverCacheStats.waiting = _waiting.length;
    } else {
      _inside--;
      CoverCacheStats.loading = _inside;
    }
  }
}
