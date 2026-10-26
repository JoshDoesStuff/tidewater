import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/motion.dart';
import '../../../core/models/genre.dart';
import '../../widgets/pressable.dart';

/// A genre as a tonal card: its name and how many albums and songs are in it.
/// The tone follows [index], so a row of them is not one flat color.
class GenreCard extends StatelessWidget {
  const GenreCard({super.key, required this.genre, required this.index});

  final Genre genre;
  final int index;

  static String _count(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (bg, fg) = switch (index % 3) {
      0 => (scheme.primaryContainer, scheme.onPrimaryContainer),
      1 => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    };
    return Pressable(
      onTap: () => context.push('/genre/${Uri.encodeComponent(genre.name)}'),
      semanticLabel: '${genre.name}, ${_count(genre.albumCount, 'album')}, ${_count(genre.songCount, 'song')}',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.curve(context, Motion.spring),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        transform: Matrix4.diagonal3Values(s.pressed ? .97 : 1, s.pressed ? .97 : 1, 1),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg.withValues(alpha: s.hovered ? 1 : .85),
          borderRadius: BorderRadius.circular(s.pressed ? 20 : (s.hovered ? 32 : 28)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              genre.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              '${_count(genre.albumCount, 'album')} · ${_count(genre.songCount, 'song')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: fg.withValues(alpha: .8)),
            ),
          ],
        ),
      ),
    );
  }
}
