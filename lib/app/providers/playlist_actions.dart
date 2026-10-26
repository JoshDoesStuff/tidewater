import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/playlist.dart';
import '../../core/models/track.dart';
import 'library_providers.dart';
import 'session_providers.dart';
import 'ui_providers.dart';

/// What to do when a song being added is already in the playlist.
enum DuplicateBehavior {
  ask('Ask me'),
  addAgain('Add it again'),
  skip('Skip it');

  const DuplicateBehavior(this.label);
  final String label;
}

/// The choice "Don't ask me again" remembers (changed in Settings too).
final duplicateBehaviorProvider = NotifierProvider<PickNotifier<DuplicateBehavior>, DuplicateBehavior>(
  () => SavedPickNotifier('playlist_duplicates', DuplicateBehavior.values, DuplicateBehavior.ask),
);

/// Changes to playlists on the server. Each one reloads the playlist lists and
/// the playlist page afterwards, and says what happened (or why it did not).
class PlaylistActions {
  PlaylistActions(this._ref);

  final Ref _ref;

  void _say(String message, {bool error = false}) => _ref.read(toastProvider.notifier).show(message, error: error);

  void _reload([String? playlistId]) {
    _ref.invalidate(playlistsProvider);
    if (playlistId != null) _ref.invalidate(playlistDetailProvider(playlistId));
  }

  /// Runs [change], turning a server error into a message; true when it worked.
  Future<bool> _try(Future<void> Function() change, {String? failure}) async {
    try {
      await change();
      return true;
    } on ApiException catch (e) {
      _say(
        e.isOffline ? 'Can\'t reach the server. Nothing was changed.' : '${failure ?? 'That didn\'t work'}: ${e.message}',
        error: true,
      );
      return false;
    }
  }

  /// A new, private playlist with [tracks]; null when the server refused.
  Future<Playlist?> create(String name, List<Track> tracks) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return null;
    Playlist? made;
    final ok = await _try(
      () async => made = await _ref.read(apiProvider).createPlaylist(name: cleaned, songIds: [for (final t in tracks) t.id]),
      failure: 'Couldn\'t create the playlist',
    );
    if (!ok) return null;
    _reload();
    _say(tracks.isEmpty ? 'Created "$cleaned".' : 'Created "$cleaned" with ${_songs(tracks.length)}.');
    return made ?? Playlist(id: '', name: cleaned);
  }

  Future<bool> add(Playlist playlist, List<Track> tracks) async {
    if (tracks.isEmpty) return true;
    final ok = await _try(
      () => _ref.read(apiProvider).updatePlaylist(playlist.id, addSongIds: [for (final t in tracks) t.id]),
      failure: 'Couldn\'t add to "${playlist.name}"',
    );
    if (!ok) return false;
    _reload(playlist.id);
    _say('Added ${_songs(tracks.length)} to "${playlist.name}".');
    return true;
  }

  Future<bool> removeAt(Playlist playlist, int index) async {
    final ok = await _try(
      () => _ref.read(apiProvider).updatePlaylist(playlist.id, removeIndexes: [index]),
      failure: 'Couldn\'t remove the song',
    );
    if (ok) _reload(playlist.id);
    return ok;
  }

  Future<bool> removeAll(Playlist playlist, List<int> indexes) async {
    final ok = await _try(
      () => _ref.read(apiProvider).updatePlaylist(playlist.id, removeIndexes: indexes),
      failure: 'Couldn\'t remove the songs',
    );
    if (ok) {
      _reload(playlist.id);
      _say(indexes.length == 1 ? 'Removed 1 song from "${playlist.name}".' : 'Removed ${indexes.length} songs from "${playlist.name}".');
    }
    return ok;
  }

  /// Puts the songs in [order] (the server has no "move", so this replaces them all).
  Future<bool> reorder(Playlist playlist, List<Track> order) async {
    final ok = await _try(
      () => _ref.read(apiProvider).createPlaylist(playlistId: playlist.id, songIds: [for (final t in order) t.id]),
      failure: 'Couldn\'t save the new order',
    );
    if (ok) _reload(playlist.id);
    return ok;
  }

  Future<bool> rename(Playlist playlist, String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty || cleaned == playlist.name) return false;
    final ok = await _try(
      () => _ref.read(apiProvider).updatePlaylist(playlist.id, name: cleaned),
      failure: 'Couldn\'t rename it',
    );
    if (ok) _reload(playlist.id);
    return ok;
  }

  Future<bool> setPublic(Playlist playlist, bool isPublic) async {
    final ok = await _try(
      () => _ref.read(apiProvider).updatePlaylist(playlist.id, isPublic: isPublic),
      failure: 'Couldn\'t change who can see it',
    );
    if (ok) _reload(playlist.id);
    return ok;
  }

  Future<bool> delete(Playlist playlist) async {
    final ok = await _try(() => _ref.read(apiProvider).deletePlaylist(playlist.id), failure: 'Couldn\'t delete it');
    if (!ok) return false;
    _reload();
    _say('Deleted "${playlist.name}".');
    return true;
  }

  static String _songs(int n) => n == 1 ? '1 song' : '$n songs';
}

final playlistActionsProvider = Provider<PlaylistActions>(PlaylistActions.new);
