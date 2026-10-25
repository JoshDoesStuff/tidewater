// Talks to a real server with the app's own client and prints what it finds.
// Usage:
//   dart run tool/server_check.dart <url> <user> <password>
//   dart run tool/server_check.dart <url> --api-key <key>
//
// Pages through the whole album list (the way the Library does), times each
// step, and fetches one cover. Safe against a live server: read-only.
import 'dart:io';

import 'package:tidewater/core/api/api_exception.dart';
import 'package:tidewater/core/api/connect.dart';
import 'package:tidewater/core/api/library_api.dart';
import 'package:tidewater/core/api/opensubsonic_client.dart';
import 'package:tidewater/core/api/server_config.dart';
import 'package:tidewater/core/models/album.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: server_check <url> <user> <password> | <url> --api-key <key>');
    exit(64);
  }
  final Credentials credentials = args[1] == '--api-key' && args.length > 2
      ? ApiKeyCredentials(args[2])
      : PasswordCredentials(args[1], args.length > 2 ? args[2] : '');

  final clock = Stopwatch()..start();
  void step(String what) => stdout.writeln('[${clock.elapsedMilliseconds.toString().padLeft(6)} ms] $what');

  try {
    final conn = await connect(url: args[0], credentials: credentials);
    final info = conn.info;
    step('connected to ${conn.config.baseUrl} (${info.serverName} ${info.serverVersion}, API ${info.apiVersion})');
    step('extensions: ${info.extensions.isEmpty ? 'none' : (info.extensions.toList()..sort()).join(', ')}');
    final api = OpenSubsonicClient(conn.config);

    final artists = await api.getArtists();
    step('${artists.length} artists');

    final playlists = await api.getPlaylists();
    step('${playlists.length} playlists');

    final albums = await _allAlbums(api, step);
    step('${albums.length} albums (paged like the Library)');
    final withArt = albums.where((a) => a.coverArt != null).toList();
    step('${withArt.length} albums have cover art');

    if (albums.isNotEmpty) {
      final detail = await api.getAlbum(albums.first.id);
      final t = detail.tracks.isEmpty ? null : detail.tracks.first;
      step('"${detail.album.title}" by ${detail.album.artist}: ${detail.tracks.length} tracks'
          '${t == null ? '' : ', first "${t.title}" [${t.qualityLabel ?? 'quality unknown'}]'}');
      if (t != null) step('stream URL ok: ${api.streamUri(t.id).replace(queryParameters: {}).toString()}');
    }
    if (withArt.isNotEmpty) {
      for (final size in [300, 800]) {
        final bytes = await api.getCoverArt(withArt.first.coverArt!, size: size);
        step('cover @$size: ${(bytes.length / 1024).toStringAsFixed(0)} KB');
      }
    }
    final songs = await api.getRandomSongs(size: 10);
    step('${songs.length} random songs');
    final found = albums.isEmpty ? null : await api.search(albums.first.title.split(' ').first);
    if (found != null) step('search finds ${found.albums.length} albums, ${found.tracks.length} songs');
    api.close();
    step('done');
  } on ApiException catch (e) {
    stderr.writeln('FAILED (${e.kind.name}): ${e.message}');
    exit(1);
  }
}

Future<List<Album>> _allAlbums(LibraryApi api, void Function(String) step) async {
  final all = <Album>[];
  while (true) {
    final size = all.isEmpty ? 120 : 500;
    final page = await api.getAlbumList(AlbumListType.alphabeticalByName, size: size, offset: all.length);
    all.addAll(page);
    step('  page of ${page.length} (total ${all.length})');
    if (page.length < size) return all;
  }
}
