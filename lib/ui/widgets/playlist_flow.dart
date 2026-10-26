import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/library_providers.dart';
import '../../app/providers/playlist_actions.dart';
import '../../app/providers/session_providers.dart';
import '../../app/providers/ui_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/models/playlist.dart';
import '../../core/models/track.dart';
import 'pressable.dart';

/// What the picker returns: an existing playlist, or the name of a new one.
class _Picked {
  const _Picked.existing(Playlist this.playlist) : newName = null;
  const _Picked.created(String this.newName) : playlist = null;

  final Playlist? playlist;
  final String? newName;
}

/// Adds [tracks] to a playlist the person picks (or a new one they name),
/// asking first when some of the songs are already in it (see
/// [duplicateBehaviorProvider]). The playlists that can be changed are the
/// person's own; smart playlists and other people's are left out.
Future<void> addToPlaylistFlow(BuildContext context, WidgetRef ref, List<Track> tracks) async {
  if (tracks.isEmpty) return;
  final picked = await showDialog<_Picked>(context: context, builder: (_) => _PlaylistPicker(count: tracks.length));
  if (picked == null || !context.mounted) return;
  final actions = ref.read(playlistActionsProvider);
  if (picked.newName != null) {
    await actions.create(picked.newName!, tracks);
    return;
  }
  final playlist = picked.playlist!;
  var toAdd = tracks;
  try {
    final existing = (await ref.read(playlistDetailProvider(playlist.id).future)).tracks.map((t) => t.id).toSet();
    final already = tracks.where((t) => existing.contains(t.id)).toList();
    if (already.isNotEmpty) {
      final behavior = ref.read(duplicateBehaviorProvider);
      var choice = switch (behavior) {
        DuplicateBehavior.addAgain => DuplicateBehavior.addAgain,
        DuplicateBehavior.skip => DuplicateBehavior.skip,
        DuplicateBehavior.ask => null,
      };
      if (choice == null) {
        if (!context.mounted) return;
        final answer = await showDialog<_DuplicateAnswer>(
          context: context,
          builder: (_) => _DuplicateDialog(playlist: playlist, duplicates: already.length, total: tracks.length),
        );
        if (answer == null) return; // cancelled
        choice = answer.choice;
        if (answer.dontAskAgain) ref.read(duplicateBehaviorProvider.notifier).set(choice);
      }
      if (choice == DuplicateBehavior.skip) {
        final skip = already.map((t) => t.id).toSet();
        toAdd = [for (final t in tracks) if (!skip.contains(t.id)) t];
        if (toAdd.isEmpty) {
          _toast(ref, tracks.length == 1 ? 'It is already in "${playlist.name}".' : 'They are all already in "${playlist.name}".');
          return;
        }
      }
    }
  } catch (_) {
    // Could not look inside it (offline...): add anyway and let the server answer.
  }
  await actions.add(playlist, toAdd);
}

void _toast(WidgetRef ref, String message) => ref.read(toastProvider.notifier).show(message);

class _PlaylistPicker extends ConsumerStatefulWidget {
  const _PlaylistPicker({required this.count});

  final int count;

  @override
  ConsumerState<_PlaylistPicker> createState() => _PlaylistPickerState();
}

class _PlaylistPickerState extends ConsumerState<_PlaylistPicker> {
  bool _naming = false;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(_Picked.created(name));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final username = ref.watch(sessionProvider)?.username ?? '';
    final playlists = ref.watch(playlistsProvider);
    final mine = [
      for (final p in playlists.value ?? const <Playlist>[])
        if (p.canEdit(username)) p,
    ];
    return Dialog(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.count == 1 ? 'Add to playlist' : 'Add ${widget.count} songs to playlist',
                  style: text.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              if (_naming)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _create(),
                        decoration: const InputDecoration(labelText: 'Playlist name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'New playlists start private. You can make one public on its page.',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => setState(() => _naming = false), child: const Text('Back')),
                          const SizedBox(width: 8),
                          FilledButton(onPressed: _create, child: const Text('Create')),
                        ],
                      ),
                    ],
                  ),
                )
              else ...[
                _Tile(
                  icon: Icons.add_rounded,
                  title: 'New playlist',
                  onTap: () => setState(() => _naming = true),
                  accent: true,
                ),
                Flexible(
                  child: playlists.isLoading && mine.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3))),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final p in mine)
                              _Tile(
                                icon: Icons.queue_music_rounded,
                                title: p.name,
                                subtitle: p.songCount == 1 ? '1 song' : '${p.songCount} songs',
                                onTap: () => Navigator.of(context).pop(_Picked.existing(p)),
                              ),
                            if (mine.isEmpty && !playlists.isLoading)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'You have no playlists to add to yet.',
                                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                          ],
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap, this.subtitle, this.accent = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: subtitle == null ? title : '$title, $subtitle',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: s.hovered ? scheme.surfaceContainerHighest : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: accent ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
                  if (subtitle != null)
                    Text(subtitle!, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuplicateAnswer {
  const _DuplicateAnswer(this.choice, {required this.dontAskAgain});

  final DuplicateBehavior choice;
  final bool dontAskAgain;
}

class _DuplicateDialog extends StatefulWidget {
  const _DuplicateDialog({required this.playlist, required this.duplicates, required this.total});

  final Playlist playlist;
  final int duplicates;
  final int total;

  @override
  State<_DuplicateDialog> createState() => _DuplicateDialogState();
}

class _DuplicateDialogState extends State<_DuplicateDialog> {
  bool _dontAsk = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final one = widget.total == 1;
    final message = one
        ? '"${widget.playlist.name}" already has this song. Add it again?'
        : widget.duplicates == widget.total
            ? 'All ${widget.total} songs are already in "${widget.playlist.name}". Add them again?'
            : '${widget.duplicates} of these ${widget.total} songs are already in "${widget.playlist.name}". Add them again?';
    return AlertDialog(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Already in this playlist'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: text.bodyMedium),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _dontAsk,
              onChanged: (v) => setState(() => _dontAsk = v ?? false),
              title: const Text('Don\'t ask me again'),
              subtitle: Text('Settings can change this later.', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_DuplicateAnswer(DuplicateBehavior.skip, dontAskAgain: _dontAsk)),
          child: Text(one ? 'Don\'t add it' : (widget.duplicates == widget.total ? 'Add none' : 'Skip the repeats')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_DuplicateAnswer(DuplicateBehavior.addAgain, dontAskAgain: _dontAsk)),
          child: const Text('Add again'),
        ),
      ],
    );
  }
}

/// Asks for a name and makes an empty, private playlist; returns it (null when
/// cancelled or refused).
Future<Playlist?> createPlaylistFlow(BuildContext context, WidgetRef ref) async {
  final name = await showDialog<String>(context: context, builder: (_) => const _NewPlaylistDialog());
  if (name == null || name.trim().isEmpty) return null;
  return ref.read(playlistActionsProvider).create(name, const []);
}

class _NewPlaylistDialog extends StatefulWidget {
  const _NewPlaylistDialog();

  @override
  State<_NewPlaylistDialog> createState() => _NewPlaylistDialogState();
}

class _NewPlaylistDialogState extends State<_NewPlaylistDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() => Navigator.of(context).pop(_name.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('New playlist'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              onSubmitted: (_) => _create(),
              decoration: const InputDecoration(labelText: 'Playlist name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 6),
            Text(
              'New playlists start private. You can make one public on its page.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _create, child: const Text('Create')),
      ],
    );
  }
}
