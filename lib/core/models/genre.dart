import 'json_util.dart';

/// A genre with how much of the library is in it (OpenSubsonic `getGenres`).
class Genre {
  const Genre({required this.name, this.songCount = 0, this.albumCount = 0});

  factory Genre.fromJson(Map<String, dynamic> j) => Genre(
        name: asString(j['value']) ?? asString(j['name']) ?? '',
        songCount: asInt(j['songCount']) ?? 0,
        albumCount: asInt(j['albumCount']) ?? 0,
      );

  final String name;
  final int songCount;
  final int albumCount;
}
