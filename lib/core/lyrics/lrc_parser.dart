import 'lyrics.dart';

final _stamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _offsetTag = RegExp(r'^\[offset:\s*(-?\d+)\s*\]', caseSensitive: false);

/// Parses LRC text. Lines may carry several timestamps; metadata tags such as
/// `[ar:...]` are ignored and `[offset:ms]` is applied. Text with no
/// timestamps at all becomes plain (unsynced) lyrics.
Lyrics parseLrc(String source) {
  final entries = <LyricLine>[];
  final plain = <String>[];
  var offsetMs = 0;

  for (final raw in source.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final offset = _offsetTag.firstMatch(line);
    if (offset != null) {
      offsetMs = int.parse(offset.group(1)!);
      continue;
    }
    final stamps = _stamp.allMatches(line).toList();
    if (stamps.isEmpty) {
      // Metadata like [ar:Artist] is bracketed; anything else is lyric text.
      if (!RegExp(r'^\[[a-zA-Z#]+:.*\]$').hasMatch(line)) plain.add(line);
      continue;
    }
    final text = line.substring(stamps.last.end).trim();
    for (final m in stamps) {
      final minutes = int.parse(m.group(1)!);
      final seconds = int.parse(m.group(2)!);
      final frac = m.group(3);
      // ".5" is half a second, ".05" is 50 ms, ".050" is 50 ms.
      final ms = frac == null ? 0 : int.parse(frac.padRight(3, '0').substring(0, 3));
      final total = (minutes * 60 + seconds) * 1000 + ms + offsetMs;
      entries.add(LyricLine(Duration(milliseconds: total < 0 ? 0 : total), text));
    }
  }

  if (entries.isEmpty) return Lyrics.plain(plain);
  entries.sort((a, b) => a.time.compareTo(b.time));
  return Lyrics(lines: entries, synced: true);
}
