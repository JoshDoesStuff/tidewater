/// Lenient readers for Subsonic JSON: servers disagree on int vs. string vs.
/// missing, so every reader returns null instead of throwing.
int? asInt(Object? v) => switch (v) {
      int i => i,
      num n => n.round(),
      String s => int.tryParse(s),
      _ => null,
    };

String? asString(Object? v) => switch (v) {
      String s when s.isNotEmpty => s,
      num n => n.toString(),
      _ => null,
    };

/// Display-name policy. With [hideJapanese] on, kana, kanji and CJK
/// punctuation are dropped from names (an all-Japanese name becomes a dash).
/// The app flips this from Settings and refetches, so models carry the result.
abstract final class NameFilter {
  static bool hideJapanese = false;

  static final _japanese = RegExp(r'[　-〿぀-ヿ㐀-䶿一-鿿＀-￯]');
  static final _empty = RegExp(r'^[\s\-_/&,.:;|()\[\]{}]*$');

  static String apply(String s) {
    if (!hideJapanese || !_japanese.hasMatch(s)) return s;
    final kept = s
        .replaceAll(_japanese, '')
        .replaceAll(RegExp(r'\(\s*\)|\[\s*\]|\{\s*\}'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return _empty.hasMatch(kept) ? '—' : kept;
  }
}

/// [asString] for names people read (titles, artists, playlists).
String? asName(Object? v) {
  final s = asString(v);
  return s == null ? null : NameFilter.apply(s);
}

DateTime? asDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

Duration asSeconds(Object? v) => Duration(seconds: asInt(v) ?? 0);

/// Some servers return a one-item list as a bare object.
List<Map<String, dynamic>> asObjects(Object? v) => switch (v) {
      List l => [for (final e in l) if (e is Map<String, dynamic>) e],
      Map<String, dynamic> m => [m],
      _ => const [],
    };
