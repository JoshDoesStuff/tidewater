import '../lyrics/lrc_parser.dart';
import '../lyrics/lyrics.dart';
import '../models/album.dart';
import '../models/track.dart';

/// One track per album, 3:20 each like the demo, in album order.
final fakeTracks = <Track>[
  for (final a in fakeAlbums)
    Track(
      id: 't-${a.id}',
      title: a.track,
      artist: a.artist,
      albumId: a.id,
      albumTitle: a.title,
      duration: const Duration(seconds: 200),
    ),
];

const _fakeLrc = '''
[ar:Placeholder]
[00:08.00]Streetlights fold into the river,
[00:28.00]and the bridge keeps count of us
[00:48.00]I know the name of every lamp,
[01:08.00]Every window hums one song
[01:28.00]I only know the one in blue
[01:48.00]Slow the tram, leave the lamps on,
[02:08.00]we will find the long way home
[02:28.00]Hold the quiet like a lantern,
[02:48.00]till the morning takes it too
''';

/// Synced lyrics shown for every fake track until real lyrics are fetched.
final Lyrics fakeLyrics = parseLrc(_fakeLrc);

/// Fake data for milestone 1, taken from the demo. Replaced by the
/// OpenSubsonic client in milestone 2.
const fakeAlbums = <Album>[
  Album(id: 'a0', title: 'Glass Orchard', artist: 'Mira Vale', track: 'Lantern Season', colorA: 0xFFFF7E5F, colorB: 0xFF7B2FF7),
  Album(id: 'a1', title: 'Night Transit', artist: 'Koji & the Static', track: 'Last Tram Home', colorA: 0xFF00C6FF, colorB: 0xFF0F2A6B),
  Album(id: 'a2', title: 'Low Tide Letters', artist: 'Ana Soleil', track: 'Salt on the Window', colorA: 0xFFF6D365, colorB: 0xFFE4572E),
  Album(id: 'a3', title: 'Paper Satellites', artist: 'Hollow Pines', track: 'Orbit of Small Things', colorA: 0xFF43CEA2, colorB: 0xFF185A9D),
  Album(id: 'a4', title: 'Velvet Static', artist: 'Dune Parade', track: 'Velvet Static', colorA: 0xFFEE9CA7, colorB: 0xFF5B247A),
  Album(id: 'a5', title: 'Saltwater Hymns', artist: 'Orla Finch', track: 'Harbour Lights', colorA: 0xFF2193B0, colorB: 0xFF6DD5ED),
  Album(id: 'a6', title: 'Neon Cartography', artist: 'Quiet Engine', track: 'Map of Neon', colorA: 0xFFC33764, colorB: 0xFF1D2671),
  Album(id: 'a7', title: 'Slow Meridian', artist: 'Tove Lind', track: 'Slow Meridian', colorA: 0xFFFCB045, colorB: 0xFF833AB4),
  Album(id: 'a8', title: 'Ember Hours', artist: 'The Lanterns', track: 'Embers, Late', colorA: 0xFFF857A6, colorB: 0xFFFF5858),
  Album(id: 'a9', title: 'Fieldwork', artist: 'Marin Cho', track: 'Field Recording 4', colorA: 0xFF3A7BD5, colorB: 0xFF00D2FF),
  Album(id: 'a10', title: 'Afterglow Theory', artist: 'Juno Park', track: 'Afterglow', colorA: 0xFF11998E, colorB: 0xFF38EF7D),
  Album(id: 'a11', title: 'Cobalt Rooms', artist: 'Eli Marsh', track: 'Room 9', colorA: 0xFF8E2DE2, colorB: 0xFF1B1B3A),
];
