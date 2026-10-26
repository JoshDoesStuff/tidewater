import 'dart:convert';

import '../models/track.dart';
import 'play_queue.dart';

/// What is remembered between launches: the queue (in play order), where we
/// were in it and the player settings. Tied to a server, so another server's
/// tracks are never restored into this one.
class SavedSession {
  const SavedSession({
    required this.server,
    required this.tracks,
    required this.index,
    required this.position,
    required this.shuffled,
    required this.repeat,
    required this.volume,
    this.savedAt,
  });

  /// Identifies the server and user (`https://host|user`).
  final String server;
  final List<Track> tracks;
  final int index;
  final Duration position;
  final bool shuffled;
  final LoopMode repeat;
  final double volume;

  /// When this was written (to tell whether the server's copy is newer).
  final DateTime? savedAt;

  /// Queues longer than this are cut around the current track when saving.
  static const maxTracks = 10000;

  String encode() {
    var from = 0;
    var upTo = tracks.length;
    var at = index;
    if (tracks.length > maxTracks) {
      from = (index - maxTracks ~/ 2).clamp(0, tracks.length - maxTracks);
      upTo = from + maxTracks;
      at = index - from;
    }
    return jsonEncode({
      'v': 1,
      'server': server,
      'tracks': [for (final t in tracks.sublist(from, upTo)) t.toJson()],
      'index': at,
      'positionMs': position.inMilliseconds,
      'shuffled': shuffled,
      'repeat': repeat.name,
      'volume': volume,
      'savedAt': (savedAt ?? DateTime.now()).toUtc().toIso8601String(),
    });
  }

  /// Null when the text is missing, from another version or damaged: a bad
  /// save must never stop the app from starting.
  static SavedSession? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final j = jsonDecode(text);
      if (j is! Map<String, dynamic> || j['v'] != 1) return null;
      final tracks = <Track>[
        for (final t in (j['tracks'] as List)) Track.fromJson(t as Map<String, dynamic>),
      ];
      if (tracks.isEmpty) return null;
      final index = ((j['index'] as num?)?.toInt() ?? 0).clamp(0, tracks.length - 1);
      return SavedSession(
        server: j['server'] as String? ?? '',
        tracks: tracks,
        index: index,
        position: Duration(milliseconds: (j['positionMs'] as num?)?.toInt() ?? 0),
        shuffled: j['shuffled'] == true,
        repeat: LoopMode.values.firstWhere((m) => m.name == j['repeat'], orElse: () => LoopMode.off),
        volume: ((j['volume'] as num?)?.toDouble() ?? .7).clamp(0.0, 1.0),
        savedAt: DateTime.tryParse(j['savedAt'] as String? ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}
