import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/color/cover_seed.dart';

/// Remembers the color extracted from each cover, so a cover is decoded and
/// quantized once ever, not once per launch. Small (one short entry per cover),
/// kept in `shared_preferences`, oldest entries dropped past [maxEntries].
///
/// Keys are `server|coverArt`: cover ids from different servers must not mix.
class SeedStore {
  SeedStore(this._prefs, {this.saveDelay = const Duration(seconds: 2)}) : _entries = _load(_prefs);

  final Duration saveDelay;

  static const _key = 'cover_seeds';
  static const maxEntries = 4000;

  final SharedPreferences _prefs;
  final Map<String, String> _entries; // insertion-ordered: oldest first
  Timer? _save;

  static Map<String, String> _load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return {};
      final j = jsonDecode(raw);
      if (j is! Map) return {};
      return {
        for (final e in j.entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      };
    } catch (_) {
      return {}; // a damaged cache is just an empty one
    }
  }

  CoverSeed? get(String key) {
    final v = _entries[key];
    if (v == null) return null;
    final parts = v.split(',');
    final argb = int.tryParse(parts.first);
    if (argb == null) return null;
    return CoverSeed(argb, muted: parts.length > 1 && parts[1] == 'm');
  }

  void put(String key, CoverSeed seed) {
    _entries.remove(key);
    _entries[key] = '${seed.argb}${seed.muted ? ',m' : ''}';
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    // Many covers arrive at once when a grid loads: write once, shortly after.
    _save?.cancel();
    _save = Timer(saveDelay, () => _prefs.setString(_key, jsonEncode(_entries)));
  }

  int get length => _entries.length;
}
