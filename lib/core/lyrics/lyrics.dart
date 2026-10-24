class LyricLine {
  const LyricLine(this.time, this.text);

  /// Start time of the line. Zero for unsynced lyrics.
  final Duration time;
  final String text;
}

class Lyrics {
  const Lyrics({required this.lines, required this.synced});

  /// Lyrics without timestamps: shown as a plain list, never auto-scrolled.
  Lyrics.plain(Iterable<String> lines)
      : lines = [for (final l in lines) LyricLine(Duration.zero, l)],
        synced = false;

  final List<LyricLine> lines;
  final bool synced;

  bool get isEmpty => lines.isEmpty;

  /// Index of the line being sung at [position]: the last line whose time is
  /// not after it. Returns 0 before the first line and for unsynced lyrics
  /// (callers should not auto-scroll those).
  int activeIndexAt(Duration position) {
    if (!synced || lines.isEmpty) return 0;
    var lo = 0;
    var hi = lines.length - 1;
    var found = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].time <= position) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }
}
