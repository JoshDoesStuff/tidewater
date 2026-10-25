import '../models/json_util.dart';
import 'lrc_parser.dart';
import 'lyrics.dart';

/// Reads an OpenSubsonic `lyricsList` (from `getLyricsBySongId`). Prefers a
/// synced version; otherwise the first plain one. Null when there is none.
Lyrics? parseStructuredLyrics(Object? lyricsList) {
  if (lyricsList is! Map) return null;
  Lyrics? plain;
  for (final s in asObjects(lyricsList['structuredLyrics'])) {
    final raw = asObjects(s['line']);
    if (raw.isEmpty) continue;
    final synced = s['synced'] == true && raw.any((l) => l['start'] != null);
    if (synced) {
      final lines = [
        for (final l in raw) LyricLine(Duration(milliseconds: asInt(l['start']) ?? 0), asString(l['value']) ?? ''),
      ]..sort((a, b) => a.time.compareTo(b.time));
      return Lyrics(lines: lines, synced: true);
    }
    plain ??= Lyrics.plain([for (final l in raw) asString(l['value']) ?? '']);
  }
  return plain;
}

/// Reads an lrclib.net `get` answer: synced lyrics when it has them, else plain.
Lyrics? parseLrclib(Object? json) {
  if (json is! Map) return null;
  if (json['instrumental'] == true) return null;
  final synced = json['syncedLyrics'];
  if (synced is String && synced.trim().isNotEmpty) {
    final l = parseLrc(synced);
    if (l.synced && !l.isEmpty) return l;
  }
  final plain = json['plainLyrics'];
  if (plain is String && plain.trim().isNotEmpty) {
    return Lyrics.plain(plain.split(RegExp(r'\r?\n')).map((e) => e.trimRight()));
  }
  return null;
}
