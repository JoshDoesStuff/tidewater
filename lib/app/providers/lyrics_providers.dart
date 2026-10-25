import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/lyrics/lrclib.dart';
import '../../core/lyrics/lyrics.dart';
import '../../core/models/track.dart';
import 'playback_providers.dart';
import 'session_providers.dart';
import 'settings_providers.dart';

/// Where lyrics come from when the server has none (lrclib.net). Tests swap
/// this out so nothing touches the network.
final lyricsFallbackProvider = Provider<Future<Lyrics?> Function(Track)>((ref) => LrclibClient().find);

/// Lyrics for one track: the server's (`getLyricsBySongId`) first, then
/// lrclib.net when that is switched on in Settings. Null when there are none.
/// Cached per track for the session.
final trackLyricsProvider = FutureProvider.family<Lyrics?, Track>((ref, track) async {
  Lyrics? found;
  try {
    found = await ref.watch(apiProvider).getLyrics(track.id);
  } on ApiException {
    found = null; // offline or a server hiccup: lyrics are never worth an error
  }
  if ((found == null || found.isEmpty) && ref.read(lrclibEnabledProvider)) {
    found = await ref.read(lyricsFallbackProvider)(track);
  }
  return found == null || found.isEmpty ? null : found;
});

/// Loading / none / found, for the playing track.
final lyricsStateProvider = Provider<AsyncValue<Lyrics?>>((ref) {
  final track = ref.watch(currentTrackProvider);
  if (track == null) return const AsyncData(null);
  return ref.watch(trackLyricsProvider(track));
});

/// The lyrics to show: empty while loading or when there are none.
final lyricsProvider = Provider<Lyrics>((ref) => ref.watch(lyricsStateProvider).value ?? Lyrics.none);
