// Publishes a fake "now playing" to the Windows media overlay and prints every
// button press it receives, for about 75 seconds. Pair it with
// tool/probes/smtc_check.ps1, which reads the session back through the Windows API
// and presses its buttons.
//
//   flutter run -d windows -t tool/probes/smtc_probe_main.dart [--dart-define=THUMB=file|https]
//
// THUMB=file writes a small PNG to the temp folder and gives its file:// address
// as the cover; THUMB=https uses TW_URL's cover art URL (needs TW_URL/USER/PASS).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tidewater/app/playback/smtc_controls.dart';
import 'package:tidewater/core/api/library_api.dart';
import 'package:tidewater/core/api/opensubsonic_client.dart';
import 'package:tidewater/core/api/server_config.dart';

const _thumb = String.fromEnvironment('THUMB');
const _url = String.fromEnvironment('TW_URL');
const _user = String.fromEnvironment('TW_USER');
const _pass = String.fromEnvironment('TW_PASS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final smtc = await SmtcControls.create();
  if (smtc == null) {
    stdout.writeln('PROBE FAIL smtc unavailable');
    exit(1);
  }
  stdout.writeln('PROBE smtc created');
  smtc.buttons.listen((b) => stdout.writeln('PROBE button ${b.name}'));

  String? thumbnail;
  if (_thumb == 'file') {
    final file = File('${Directory.systemTemp.path}/tw_probe_cover.png');
    await file.writeAsBytes(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=='));
    thumbnail = Uri.file(file.path).toString();
  } else if (_thumb == 'https') {
    final api = OpenSubsonicClient(ServerConfig(baseUrl: Uri.parse(_url), credentials: const PasswordCredentials(_user, _pass)));
    final albums = await api.getAlbumList(AlbumListType.random, size: 5);
    final art = albums.firstWhere((a) => a.coverArt != null).coverArt!;
    thumbnail = api.coverArtUri(art, size: 300).toString();
  }
  stdout.writeln('PROBE thumbnail=$thumbnail');
  await smtc.setTrack(title: 'Probe Song', artist: 'Probe Artist', album: 'Probe Album', thumbnailUri: thumbnail);
  await smtc.setPlaying(true);
  await smtc.setTimeline(position: const Duration(seconds: 12), duration: const Duration(minutes: 3, seconds: 30));
  stdout.writeln('PROBE published');
  await Future<void>.delayed(const Duration(seconds: 75));
  await smtc.clear();
  stdout.writeln('PROBE done');
  exit(0);
}
