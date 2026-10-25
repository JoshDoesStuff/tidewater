// Plays real audio from a real server through the real engine (libmpv) and
// checks the behavior that cannot be unit-tested: gapless hand-over, seeking,
// pause/resume, skipping, shuffle, repeat, a track that fails. It is AUDIBLE
// (volume is kept low) and takes about a minute.
//
//   flutter run -d windows -t tool/engine_probe_main.dart ^
//     --dart-define=TW_URL=https://your.server --dart-define=TW_USER=u --dart-define=TW_PASS=p
//
// Prints `PROBE ok/FAIL ...` lines and exits with the result.
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:tidewater/app/playback/media_kit_backend.dart';
import 'package:tidewater/core/api/library_api.dart';
import 'package:tidewater/core/api/opensubsonic_client.dart';
import 'package:tidewater/core/api/server_config.dart';
import 'package:tidewater/core/models/track.dart';
import 'package:tidewater/core/playback/play_queue.dart' show LoopMode;
import 'package:tidewater/core/playback/queue_engine.dart';

const _url = String.fromEnvironment('TW_URL', defaultValue: 'https://demo.navidrome.org');
const _user = String.fromEnvironment('TW_USER', defaultValue: 'demo');
const _pass = String.fromEnvironment('TW_PASS', defaultValue: 'demo');

var _ok = true;
void check(String what, bool pass, [String detail = '']) {
  _ok &= pass;
  stdout.writeln('PROBE ${pass ? 'ok  ' : 'FAIL'} $what${detail.isEmpty ? '' : '  ($detail)'}');
}

Future<void> until(bool Function() cond, {int seconds = 20, String what = 'condition'}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) {
      check('waited for $what', false, 'timed out after ${seconds}s');
      throw TimeoutException(what);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final api = OpenSubsonicClient(ServerConfig(baseUrl: Uri.parse(_url), credentials: const PasswordCredentials(_user, _pass)));
  final engine = QueueEngine(backend: MediaKitBackend(resolve: api.streamUri));
  try {
    await run(api, engine);
  } catch (e, st) {
    stdout.writeln('PROBE FAIL exception: $e\n$st');
    _ok = false;
  }
  stdout.writeln('PROBE ${_ok ? 'ALL OK' : 'FAILED'}');
  await engine.dispose();
  exit(_ok ? 0 : 1);
}

Future<void> run(LibraryApi api, QueueEngine e) async {
  // An album with several tracks, preferably short ones.
  final albums = await api.getAlbumList(AlbumListType.random, size: 40);
  final details = [for (final a in albums.take(25)) await api.getAlbum(a.id)];
  final album = details.firstWhere((d) => d.tracks.length >= 4, orElse: () => details.first);
  final tracks = album.tracks.take(4).toList();
  stdout.writeln('PROBE using "${album.album.title}": ${tracks.map((t) => t.title).join(' | ')}');

  final states = <int>[];
  e.states.listen((s) => states.add(s.index));
  final errors = <String>[];
  e.errors.listen(errors.add);

  final b = e.backendForTest;
  final t0 = DateTime.now();
  String ts() => '${DateTime.now().difference(t0).inMilliseconds} ms';
  b.advanced.listen((i) => stdout.writeln('PROBE   [${ts()}] backend advanced -> $i'));
  b.completed.listen((_) => stdout.writeln('PROBE   [${ts()}] backend completed'));
  b.errors.listen((m) => stdout.writeln('PROBE   [${ts()}] backend error: $m'));
  Timer.periodic(const Duration(seconds: 2), (_) => stdout.writeln('PROBE   [${ts()}] idx=${e.state.index} pos=${e.position} playing=${e.state.playing} dur=${e.state.track?.duration}'));

  await e.setVolume(.12);
  await e.playQueue(tracks);
  await until(() => e.position > const Duration(seconds: 1), what: 'first track producing audio');
  check('plays and reports position', e.state.playing, 'at ${e.position}');

  // Pause and resume keep the position.
  await e.pause();
  await Future<void>.delayed(const Duration(milliseconds: 400));
  final held = e.position;
  await Future<void>.delayed(const Duration(milliseconds: 800));
  check('pause holds position', e.position == held && !e.state.playing, '$held');
  await e.play();
  await until(() => e.position > held + const Duration(milliseconds: 500), what: 'resume');
  check('resume continues', e.state.playing);

  // Seek.
  await e.seek(const Duration(seconds: 20));
  await until(() => e.position >= const Duration(seconds: 20), what: 'seek');
  check('seek lands near the target', (e.position - const Duration(seconds: 20)).abs() < const Duration(seconds: 2), '${e.position}');

  // Gapless: seek close to the end of track 0 and watch it roll over by itself.
  final first = e.state.track!;
  await e.seek(first.duration - const Duration(seconds: 4));
  final startedAt = DateTime.now();
  await until(() => e.state.index == 1, seconds: 15, what: 'automatic advance to track 2');
  final took = DateTime.now().difference(startedAt);
  check('rolls over to the next track by itself', e.state.track?.id == tracks[1].id, 'after ${took.inMilliseconds} ms');
  check('position restarts for the new track', e.position < const Duration(seconds: 5), '${e.position}');
  check('still playing after the hand-over', e.state.playing);

  // Skip forward/back.
  await e.next();
  await until(() => e.state.index == 2 && e.position < const Duration(seconds: 3), what: 'next');
  check('next goes to track 3', e.state.track?.id == tracks[2].id);
  await e.previous();
  await until(() => e.state.index == 1, what: 'previous');
  check('previous goes back (near the start)', e.state.track?.id == tracks[1].id);

  // Play next: the added track follows the current one.
  final extra = tracks[3];
  await e.addNext([extra]);
  check('Play next is queued after the current track', e.state.queue[e.state.index + 1].id == extra.id);

  // Shuffle keeps what is playing.
  final playingId = e.state.track!.id;
  await e.setShuffle(true);
  check('shuffle keeps the playing track', e.state.track!.id == playingId && e.state.index == 0);
  await e.setShuffle(false);
  check('shuffle off restores order', e.state.track!.id == playingId);

  // Repeat one: the same track rolls over to itself.
  await e.setRepeat(LoopMode.one);
  await e.seek(e.state.track!.duration - const Duration(seconds: 3));
  await Future<void>.delayed(const Duration(seconds: 6));
  check('repeat-one stays on the track', e.state.track!.id == playingId && e.state.playing, 'now ${e.position}');
  await e.setRepeat(LoopMode.off);

  // A track that does not exist is reported and skipped.
  final ghost = Track(id: 'does-not-exist', title: 'Ghost', artist: 'x', albumId: 'x', albumTitle: 'x', duration: const Duration(minutes: 3));
  await e.playQueue([ghost, tracks[0]]);
  await until(() => e.state.index == 1 || errors.isNotEmpty, seconds: 15, what: 'error for the missing track');
  await until(() => e.state.index == 1, seconds: 10, what: 'skip past the missing track');
  check('a missing track is skipped', e.state.track?.id == tracks[0].id && errors.isNotEmpty, '${errors.length} error(s)');
  await until(() => e.position > const Duration(milliseconds: 500), what: 'audio after the skip');
  check('and playback continues', e.state.playing);

  await e.pause();
  await e.stop();
  check('stop empties the queue', e.state.queue.isEmpty);
}
