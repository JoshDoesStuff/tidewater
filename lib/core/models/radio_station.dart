import 'json_util.dart';
import 'track.dart';

/// An internet radio station kept on the server (Subsonic `getInternetRadioStations`).
class RadioStation {
  const RadioStation({required this.id, required this.name, required this.streamUrl, this.homepageUrl});

  factory RadioStation.fromJson(Map<String, dynamic> j) => RadioStation(
        id: asString(j['id']) ?? '',
        name: asString(j['name']) ?? 'Untitled station',
        streamUrl: asString(j['streamUrl']) ?? '',
        homepageUrl: asString(j['homePageUrl']) ?? asString(j['homepageUrl']),
      );

  final String id;
  final String name;
  final String streamUrl;
  final String? homepageUrl;

  /// What the player plays: a track with no length that streams from [streamUrl].
  Track get asTrack => Track(
        id: 'radio:$id',
        title: name,
        artist: 'Internet radio',
        albumId: '',
        albumTitle: '',
        duration: Duration.zero,
        streamUrl: streamUrl,
      );
}
