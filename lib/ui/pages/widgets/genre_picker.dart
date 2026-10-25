import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../../../app/theme/motion.dart';
import '../../widgets/pressable.dart';

/// The Library's genre filter: a pill that opens a popup box with a search
/// field and a scrolling list (libraries can have hundreds of genres, far too
/// many for a dropdown). Picks one genre, or "All genres" (null).
class GenrePill extends StatelessWidget {
  const GenrePill({
    super.key,
    required this.genres,
    required this.selected,
    required this.onSelected,
  });

  final List<String> genres;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = selected != null;
    return Pressable(
      semanticLabel: active ? 'Genre: $selected' : 'Filter by genre',
      onTap: () async {
        final picked = await showDialog<_Pick>(
          context: context,
          barrierColor: Colors.black54,
          builder: (_) => _GenreDialog(genres: genres, selected: selected),
        );
        if (picked != null) onSelected(picked.genre);
      },
      builder: (context, s) {
        final bg = active
            ? scheme.secondaryContainer
            : (s.hovered
                  ? scheme.surfaceContainerHighest
                  : scheme.surfaceContainerHigh);
        final fg = active ? scheme.onSecondaryContainer : scheme.onSurface;
        return AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          height: 48,
          padding: const EdgeInsets.only(left: 18, right: 20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(s.pressed ? 16 : 24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list_rounded, size: 20, color: fg),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  selected ?? 'Genre',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.expand_more_rounded, size: 16, color: fg),
            ],
          ),
        );
      },
    );
  }
}

/// What the dialog returns (null genre = all); dismissing returns nothing.
class _Pick {
  const _Pick(this.genre);
  final String? genre;
}

class _GenreDialog extends StatefulWidget {
  const _GenreDialog({required this.genres, required this.selected});

  final List<String> genres;
  final String? selected;

  @override
  State<_GenreDialog> createState() => _GenreDialogState();
}

class _GenreDialogState extends State<_GenreDialog> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<String> get _matches {
    final q = _query.text.trim().toLowerCase();
    return q.isEmpty
        ? widget.genres
        : [
            for (final g in widget.genres)
              if (g.toLowerCase().contains(q)) g,
          ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final matches = _matches;
    final searching = _query.text.trim().isNotEmpty;
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: (height - 96).clamp(240.0, 640.0),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text('Genre', style: text.titleLarge)),
                    Text(
                      '${widget.genres.length} genre${widget.genres.length == 1 ? '' : 's'}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                // Enter takes the first match (a shortcut, so it works the same
                // whether or not the platform reports a "done" action).
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter): () {
                      if (matches.isNotEmpty) {
                        Navigator.pop(context, _Pick(matches.first));
                      }
                    },
                  },
                  child: TextField(
                    controller: _query,
                    focusNode: _focus,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search genres',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: matches.isEmpty && searching
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          'No genre matches "${_query.text.trim()}".',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        // "All genres" first, unless a search is narrowing the list.
                        itemCount: matches.length + (searching ? 0 : 1),
                        itemBuilder: (context, i) {
                          final genre = searching
                              ? matches[i]
                              : (i == 0 ? null : matches[i - 1]);
                          return _Row(
                            label: genre ?? 'All genres',
                            selected: genre == widget.selected,
                            onTap: () => Navigator.pop(context, _Pick(genre)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, s) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: .6)
              : (s.hovered
                    ? scheme.surfaceContainerHighest
                    : scheme.surfaceContainerHighest.withValues(alpha: 0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
