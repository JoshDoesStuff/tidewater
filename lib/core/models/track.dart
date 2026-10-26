import 'album.dart';
import 'json_util.dart';

/// A playable track. Plain Dart so `core/` stays Flutter-free.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumId,
    required this.albumTitle,
    required this.duration,
    this.artistId,
    this.coverArt,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.suffix,
    this.bitRate,
    this.samplingRate,
    this.bitDepth,
    this.starred = false,
  });

  factory Track.fromJson(Map<String, dynamic> j, {Album? fallbackAlbum}) => Track(
        id: asString(j['id']) ?? '',
        title: asString(j['title']) ?? 'Unknown title',
        artist: asString(j['artist']) ?? fallbackAlbum?.artist ?? 'Unknown artist',
        artistId: asString(j['artistId']),
        albumId: asString(j['albumId']) ?? fallbackAlbum?.id ?? '',
        albumTitle: asString(j['album']) ?? fallbackAlbum?.title ?? '',
        // Tracks usually share the album's cover; fall back to it.
        coverArt: asString(j['coverArt']) ?? fallbackAlbum?.coverArt,
        duration: asSeconds(j['duration']),
        trackNumber: asInt(j['track']),
        discNumber: asInt(j['discNumber']),
        year: asInt(j['year']),
        suffix: asString(j['suffix']),
        bitRate: asInt(j['bitRate']),
        samplingRate: asInt(j['samplingRate']),
        bitDepth: asInt(j['bitDepth']),
        starred: j['starred'] != null,
      );

  /// Back to the shape the server sends, so [Track.fromJson] reads it again
  /// (used to save and restore the queue). Durations keep whole seconds.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        if (artistId != null) 'artistId': artistId,
        'albumId': albumId,
        'album': albumTitle,
        if (coverArt != null) 'coverArt': coverArt,
        'duration': duration.inSeconds,
        if (trackNumber != null) 'track': trackNumber,
        if (discNumber != null) 'discNumber': discNumber,
        if (year != null) 'year': year,
        if (suffix != null) 'suffix': suffix,
        if (bitRate != null) 'bitRate': bitRate,
        if (samplingRate != null) 'samplingRate': samplingRate,
        if (bitDepth != null) 'bitDepth': bitDepth,
        if (starred) 'starred': true,
      };

  final String id;
  final String title;
  final String artist;
  final String? artistId;
  final String albumId;
  final String albumTitle;
  final String? coverArt;
  final Duration duration;
  final int? trackNumber;
  final int? discNumber;
  final int? year;

  /// File extension ("flac", "mp3"), bit rate in kbit/s, sample rate in Hz.
  final String? suffix;
  final int? bitRate;
  final int? samplingRate;
  final int? bitDepth;
  final bool starred;

  /// "FLAC · 24-bit / 96 kHz" style tag, or null when the server says nothing.
  String? get qualityLabel {
    final format = suffix?.toUpperCase();
    final lossless = const {'FLAC', 'ALAC', 'WAV', 'AIFF', 'APE', 'WV'}.contains(format);
    final parts = <String>[];
    if (lossless) {
      if (bitDepth != null && bitDepth! > 0) parts.add('$bitDepth-bit');
      final hz = samplingRate;
      if (hz != null && hz > 0) parts.add('${_khz(hz)} kHz');
    } else if (bitRate != null && bitRate! > 0) {
      parts.add('$bitRate kbps');
    }
    if (format == null) return parts.isEmpty ? null : parts.join(' / ');
    return parts.isEmpty ? format : '$format · ${parts.join(' / ')}';
  }

  static String _khz(int hz) {
    final k = hz / 1000;
    return k == k.roundToDouble() ? k.round().toString() : k.toStringAsFixed(1);
  }

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
