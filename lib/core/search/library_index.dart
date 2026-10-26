import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';

enum SuggestionKind { artist, album, song }

/// One autosuggest entry: what to show, what it is, and where the typed text
/// matched inside [title] (to highlight it).
class Suggestion {
  const Suggestion({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    this.coverArt,
    this.matchStart = -1,
    this.matchLength = 0,
  });

  final SuggestionKind kind;
  final String id;
  final String title;
  final String subtitle;
  final String? coverArt;
  final int matchStart;
  final int matchLength;
}

/// An in-memory index over the artists, albums and songs of the library, so
/// autosuggest answers as fast as you type, offline, without asking the server.
///
/// Matching ignores case, accents and width (fullwidth Latin, hiragana against
/// katakana), then ranks: exact title, starts with the typed text, a word inside
/// the title starts with it, contains it, then the artist plus title, and
/// finally a typo (one letter off) at the start of a word.
class LibraryIndex {
  LibraryIndex({Iterable<Artist> artists = const [], Iterable<Album> albums = const [], Iterable<Track> songs = const []}) {
    for (final a in artists) {
      _add(SuggestionKind.artist, a.id, a.name, '${a.albumCount} album${a.albumCount == 1 ? '' : 's'}', a.coverArt, '');
    }
    for (final a in albums) {
      _add(SuggestionKind.album, a.id, a.title, a.artist, a.coverArt, a.artist);
    }
    for (final t in songs) {
      _add(SuggestionKind.song, t.id, t.title, '${t.artist} · ${t.albumTitle}', t.coverArt, t.artist);
    }
  }

  final _entries = <_Entry>[];

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;

  void _add(SuggestionKind kind, String id, String title, String subtitle, String? cover, String extra) {
    if (title.trim().isEmpty) return;
    _entries.add(
      _Entry(Suggestion(kind: kind, id: id, title: title, subtitle: subtitle, coverArt: cover), normalize(title), normalize(extra)),
    );
  }

  /// The best matches for [query], at most [limit], with no more than
  /// [perKind] of any one kind so a thousand songs cannot push out the artist.
  List<Suggestion> suggest(String query, {int limit = 8, int perKind = 4}) {
    final q = normalize(query.trim());
    if (q.isEmpty) return const [];
    final scored = <(_Entry, int, int)>[];
    for (final e in _entries) {
      final (score, at) = _score(e, q);
      if (score > 0) scored.add((e, score, at));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      final byKind = a.$1.s.kind.index.compareTo(b.$1.s.kind.index);
      if (byKind != 0) return byKind;
      return a.$1.title.length.compareTo(b.$1.title.length);
    });
    final counts = <SuggestionKind, int>{};
    final out = <Suggestion>[];
    final seen = <String>{};
    for (final (e, _, at) in scored) {
      final kind = e.s.kind;
      if ((counts[kind] ?? 0) >= perKind) continue;
      // The same title twice (an album and its single) shows once per kind.
      if (!seen.add('${kind.name}|${e.title}|${e.s.subtitle}')) continue;
      counts[kind] = (counts[kind] ?? 0) + 1;
      out.add(
        Suggestion(
          kind: kind,
          id: e.s.id,
          title: e.s.title,
          subtitle: e.s.subtitle,
          coverArt: e.s.coverArt,
          matchStart: at,
          matchLength: at < 0 ? 0 : q.length,
        ),
      );
      if (out.length >= limit) break;
    }
    return out;
  }

  /// (score, where in the normalized title the match starts); score 0 is no match.
  (int, int) _score(_Entry e, String q) {
    final t = e.title;
    if (t == q) return (100, 0);
    if (t.startsWith(q)) return (90, 0);
    // A later word starts with it ("night" in "Last Night Transit").
    final word = t.indexOf(' $q');
    if (word >= 0) return (70, word + 1);
    final at = t.indexOf(q);
    if (at >= 0) return (50, at);
    // Typed together with the artist ("koji night").
    if (q.length >= 3 && '${e.extra} $t'.contains(q)) return (35, -1);
    if (q.length >= 4 && _typo(t, q)) return (20, -1);
    return (0, -1);
  }

  /// True when some word of [title] starts like [q] with at most one letter
  /// swapped, missing or extra.
  bool _typo(String title, String q) {
    for (final word in title.split(' ')) {
      if (word.length < 3) continue;
      final head = word.length >= q.length ? word.substring(0, q.length) : word;
      if (_withinOne(head, q)) return true;
      if (word.length >= q.length - 1 && q.length > 1 && _withinOne(word.substring(0, q.length - 1), q)) return true;
      if (word.length > q.length && _withinOne(word.substring(0, q.length + 1), q)) return true;
    }
    return false;
  }

  static bool _withinOne(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    if (a.length == b.length) {
      // Two neighbors swapped ("beatels") counts as one slip.
      final i = _firstDiff(a, b);
      if (i >= 0 && i + 1 < a.length && a[i] == b[i + 1] && a[i + 1] == b[i] && a.substring(i + 2) == b.substring(i + 2)) return true;
    }
    var i = 0, j = 0, edits = 0;
    while (i < a.length && j < b.length) {
      if (a.codeUnitAt(i) == b.codeUnitAt(j)) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length > b.length) {
        i++;
      } else if (a.length < b.length) {
        j++;
      } else {
        i++;
        j++;
      }
    }
    return edits + (a.length - i) + (b.length - j) <= 1;
  }

  static int _firstDiff(String a, String b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a.codeUnitAt(i) != b.codeUnitAt(i)) return i;
    }
    return -1;
  }

  /// Lowercase, accents folded to plain letters, fullwidth Latin to ASCII,
  /// hiragana to katakana (so either finds the other), runs of spaces to one.
  static String normalize(String s) {
    final out = StringBuffer();
    var lastSpace = false;
    for (final r in s.runes) {
      var c = r;
      if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0; // fullwidth ASCII
      if (c == 0x3000) c = 0x20; // ideographic space
      if (c >= 0x3041 && c <= 0x3096) c += 0x60; // hiragana -> katakana
      final ch = _fold[c] ?? String.fromCharCode(c).toLowerCase();
      if (ch.trim().isEmpty) {
        if (!lastSpace) out.write(' ');
        lastSpace = true;
      } else {
        out.write(ch);
        lastSpace = false;
      }
    }
    return out.toString().trim();
  }

  static final Map<int, String> _fold = _buildFold();

  static Map<int, String> _buildFold() {
    const groups = {
      'a': 'àáâãäåāăąÀÁÂÃÄÅĀĂĄ',
      'c': 'çćčÇĆČ',
      'd': 'ďđĎĐ',
      'e': 'èéêëēėęěÈÉÊËĒĖĘĚ',
      'g': 'ğĞ',
      'i': 'ìíîïīįıÌÍÎÏĪĮİ',
      'l': 'łĺľŁĹĽ',
      'n': 'ñńňÑŃŇ',
      'o': 'òóôõöøōőÒÓÔÕÖØŌŐ',
      'r': 'řŕŘŔ',
      's': 'śšşșŚŠŞȘ',
      't': 'ťţțŤŢȚ',
      'u': 'ùúûüūůűųÙÚÛÜŪŮŰŲ',
      'y': 'ýÿÝŸ',
      'z': 'źżžŹŻŽ',
    };
    return {
      for (final e in groups.entries)
        for (final c in e.value.runes) c: e.key,
    };
  }
}

class _Entry {
  _Entry(this.s, this.title, this.extra);

  final Suggestion s;

  /// Normalized title and artist (for "artist title" typing).
  final String title;
  final String extra;
}
