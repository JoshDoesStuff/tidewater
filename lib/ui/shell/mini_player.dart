import 'package:flutter/material.dart';

import '../../app/theme/motion.dart';
import '../../core/data/fake_library.dart';
import '../widgets/art_tile.dart';
import '../widgets/expressive_buttons.dart';
import '../widgets/pressable.dart';
import '../widgets/wavy_progress.dart';

/// Floating pill at the bottom of the window. Static placeholder data until
/// playback exists (milestone 3); the play button only toggles its own icon.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final album = fakeAlbums.first;
    return Pressable(
      onTap: () {}, // Opens Now Playing in milestone 5.
      semanticLabel: 'Now playing: ${album.track}',
      builder: (context, s) {
        return AnimatedContainer(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.curve(context, Motion.spring),
          height: 72,
          padding: const EdgeInsets.only(left: 10, right: 24),
          transform: Matrix4.translationValues(0, s.hovered ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(color: scheme.shadow.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final showProgress = box.maxWidth >= 600;
              return Row(
                children: [
                  ArtTile(album: album, size: 52),
                  const SizedBox(width: 14),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 168),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.track,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            album.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(fontSize: 12.5, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const ExpressiveIconButton(
                    icon: Icons.skip_previous_rounded,
                    tone: ButtonTone.ghost,
                    size: 40,
                    iconSize: 22,
                    tooltip: 'Previous',
                  ),
                  const SizedBox(width: 10),
                  _PlayButton(playing: _playing, onTap: () => setState(() => _playing = !_playing)),
                  const SizedBox(width: 10),
                  const ExpressiveIconButton(
                    icon: Icons.skip_next_rounded,
                    tone: ButtonTone.ghost,
                    size: 40,
                    iconSize: 22,
                    tooltip: 'Next',
                  ),
                  if (showProgress) ...[
                    const SizedBox(width: 24),
                    const Expanded(
                      child: Align(
                        child: SizedBox(width: 170, height: 30, child: WavyProgress(value: .38)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 30,
                      child: Text('1:16', style: text.bodySmall?.copyWith(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ),
                  ] else
                    const Spacer(),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: playing ? 'Pause' : 'Play',
      builder: (context, s) {
        return AnimatedScale(
          scale: s.pressed ? .92 : 1,
          duration: Motion.of(context, Motion.fast),
          curve: Motion.curve(context, Motion.spring),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.slow),
            curve: Motion.curve(context, Motion.spring),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(playing || s.pressed ? 16 : 24),
            ),
            child: Center(child: PlayPauseIcon(playing: playing, size: 24, color: scheme.onPrimary)),
          ),
        );
      },
    );
  }
}
