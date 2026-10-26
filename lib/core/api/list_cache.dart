import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// Where saved lists come from. The disk cache is the real one; tests use
/// [MemoryListStore] (file IO never completes under fake async).
abstract class ListStore {
  /// The list saved under [name], or null when there is none (or it is unreadable).
  Future<List<Map<String, dynamic>>?> read(String name);

  Future<void> write(String name, List<Map<String, dynamic>> items);
}

/// Library lists (albums, songs, artists, playlists) as JSON files in one
/// folder per server, so Library opens on the last known data at once while the
/// fresh data loads in the background. Big lists are encoded and decoded off
/// the UI isolate.
class ListCache implements ListStore {
  ListCache({required Future<Directory> Function() directory}) : _resolve = directory;

  final Future<Directory> Function() _resolve;
  Directory? _directory;

  Future<Directory> get _dir async {
    final dir = _directory ??= await _resolve();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  File _file(Directory dir, String name) =>
      File('${dir.path}${Platform.pathSeparator}${name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')}.json');

  @override
  Future<List<Map<String, dynamic>>?> read(String name) async {
    try {
      final file = _file(await _dir, name);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return await Isolate.run(() {
        final decoded = jsonDecode(utf8.decode(bytes));
        return decoded is List ? [for (final e in decoded) if (e is Map<String, dynamic>) e] : null;
      });
    } catch (_) {
      return null; // A damaged or half-written file is the same as no cache.
    }
  }

  @override
  Future<void> write(String name, List<Map<String, dynamic>> items) async {
    try {
      final file = _file(await _dir, name);
      final bytes = await Isolate.run(() => utf8.encode(jsonEncode(items)));
      // The same list again (the usual case: nothing changed since last launch)
      // is not written at all, which saves the SSD a few megabytes per start.
      if (await file.exists() && await _same(file, bytes)) return;
      // Write beside it and rename, so a crash never leaves a half file.
      final temp = File('${file.path}.tmp');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } catch (_) {
      // A cache that cannot be written is only slower, never wrong.
    }
  }
}

Future<bool> _same(File file, List<int> bytes) async {
  if (await file.length() != bytes.length) return false;
  final old = await file.readAsBytes();
  for (var i = 0; i < old.length; i++) {
    if (old[i] != bytes[i]) return false;
  }
  return true;
}

/// An in-memory [ListStore] for tests.
class MemoryListStore implements ListStore {
  final Map<String, List<Map<String, dynamic>>> saved = {};

  @override
  Future<List<Map<String, dynamic>>?> read(String name) async => saved[name];

  @override
  Future<void> write(String name, List<Map<String, dynamic>> items) async => saved[name] = items;
}
