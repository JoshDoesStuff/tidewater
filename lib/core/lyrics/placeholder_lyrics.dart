import 'lrc_parser.dart';
import 'lyrics.dart';

const _lrc = '''
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

/// STAND-IN: the same synced lyrics for every track until real lyrics are
/// fetched (`getLyricsBySongId`, milestone 3).
final Lyrics placeholderLyrics = parseLrc(_lrc);
