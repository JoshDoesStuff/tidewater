import 'package:dio/dio.dart';

import '../models/track.dart';
import 'lyrics.dart';
import 'structured_lyrics.dart';

/// Looks a track up on lrclib.net (free, no account). It is sent the artist,
/// title, album and length of the track, which is why it is a setting.
class LrclibClient {
  LrclibClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://lrclib.net',
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              headers: {'User-Agent': 'Tidewater (https://github.com/JoshDoesStuff/tidewater)'},
              validateStatus: (_) => true,
            ));

  final Dio _dio;

  /// The best lyrics lrclib has for [track], or null (not found, instrumental,
  /// no network).
  Future<Lyrics?> find(Track track) async {
    try {
      final res = await _dio.get<Object?>('/api/get', queryParameters: {
        'artist_name': track.artist,
        'track_name': track.title,
        if (track.albumTitle.isNotEmpty) 'album_name': track.albumTitle,
        if (track.duration > Duration.zero) 'duration': track.duration.inSeconds,
      });
      if (res.statusCode != 200) return null;
      return parseLrclib(res.data);
    } on DioException {
      return null;
    }
  }
}
