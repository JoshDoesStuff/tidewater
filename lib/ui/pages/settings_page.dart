import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/playlist_actions.dart';
import '../../app/providers/refresh_library.dart';
import '../../app/providers/queue_sync_status.dart';
import '../../app/providers/settings_providers.dart';
import '../../app/theme/motion.dart';
import '../widgets/effects/letter_reveal.dart';
import '../widgets/effects/ripple.dart';
import '../widgets/pressable.dart';
import 'page_frame.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final reduce = ref.watch(reduceMotionProvider);
    final dark = ref.watch(darkThemeProvider);
    final viz = ref.watch(vizModeProvider);
    final task = ref.watch(libraryTaskProvider);
    return PageFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          24,
          36,
          32,
          PageFrame.bottomClearance,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LetterReveal(
              text: 'Settings',
              style: text.displaySmall,
              delay: const Duration(milliseconds: 100),
            ),
            const SizedBox(height: 22),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SwitchRow(
                    title: 'Reduce motion',
                    subtitle: 'Instant or fade-only transitions; no spin, morph overshoot or wash.',
                    value: reduce,
                    onChanged: ref.read(reduceMotionProvider.notifier).set,
                  ),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    title: 'Dark theme',
                    subtitle: 'Colors always follow the playing album; this picks dark or light.',
                    value: dark,
                    onChanged: ref.read(darkThemeProvider.notifier).set,
                  ),
                  const SizedBox(height: 8),
                  const _SpeedRow(),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    title: 'Count plays on the server',
                    subtitle: 'Tells Navidrome what you play, so Recently and Most played stay right. A play counts after half the track or four minutes.',
                    value: ref.watch(scrobbleEnabledProvider),
                    onChanged: ref.read(scrobbleEnabledProvider.notifier).set,
                  ),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    title: 'Keep your place on the server',
                    subtitle: 'Saves the queue and position on the server (every 30 seconds while playing, and when you pause), so a restart or another device resumes where you stopped. Off, only this PC remembers.',
                    value: ref.watch(syncPositionProvider),
                    onChanged: ref.read(syncPositionProvider.notifier).set,
                  ),
                  const _QueueStatusLine(),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    title: 'Always show the "wrapping up" screen',
                    subtitle: 'When you close the app. Off, it only appears if saving to the server is taking a while. On, it shows every time and stays up for a moment so you can see it.',
                    value: ref.watch(wrapUpAlwaysProvider),
                    onChanged: ref.read(wrapUpAlwaysProvider.notifier).set,
                  ),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    title: 'Look up missing lyrics online',
                    subtitle: 'When your server has no lyrics for a track, ask lrclib.net. This sends the artist, title, album and length of that track to lrclib.net.',
                    value: ref.watch(lrclibEnabledProvider),
                    onChanged: ref.read(lrclibEnabledProvider.notifier).set,
                  ),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    title: 'Queue as a side panel',
                    subtitle: 'Docks the queue beside Now Playing and shrinks the player to fit. Off opens it as a popup over the player. Narrow windows always use the popup.',
                    value: ref.watch(queueSidePanelProvider),
                    onChanged: ref.read(queueSidePanelProvider.notifier).set,
                  ),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    title: 'Live scrubbing',
                    subtitle: 'The song seeks as you drag the progress bar. Off, it jumps once when you let go, which avoids a buffering flash mid-drag.',
                    value: ref.watch(liveScrubProvider),
                    onChanged: ref.read(liveScrubProvider.notifier).set,
                  ),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    title: 'Faint icon while it redraws',
                    subtitle: 'Some icons erase and draw themselves again when clicked. On keeps a faint copy of the icon underneath so it never fully disappears.',
                    value: ref.watch(iconGhostProvider),
                    onChanged: ref.read(iconGhostProvider.notifier).set,
                  ),
                  const SizedBox(height: 22),
                  Text('Playlists', style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'When you add a song that is already in the playlist:',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final b in DuplicateBehavior.values)
                        _ModeChip(
                          label: b.label,
                          selected: b == ref.watch(duplicateBehaviorProvider),
                          onTap: () => ref.read(duplicateBehaviorProvider.notifier).set(b),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('Library', style: text.titleLarge),
                  const SizedBox(height: 10),
                  _ActionRow(
                    title: 'Refresh the library',
                    subtitle: 'Asks the server for albums, songs, artists, playlists and Home again, for music added while the app is open. What you see stays until the new lists arrive.',
                    action: 'Refresh',
                    onPressed: () => ref.read(refreshLibraryProvider)(),
                    busy: task.running && task.kind == LibraryTaskKind.refresh,
                    status: task.kind == LibraryTaskKind.refresh ? task.text : null,
                    statusIsError: task.error,
                    disabled: task.running,
                  ),
                  const SizedBox(height: 8),
                  _ActionRow(
                    title: 'Scan the server',
                    subtitle: 'Tells your server to look for new music in its folders (needs an admin account), waits for it to finish, then refreshes the library here.',
                    action: 'Scan',
                    onPressed: () => ref.read(scanServerProvider)(),
                    busy: task.running && task.kind == LibraryTaskKind.scan,
                    status: task.kind == LibraryTaskKind.scan ? task.text : null,
                    statusIsError: task.error,
                    disabled: task.running,
                  ),
                  const SizedBox(height: 8),
                  _ActionRow(
                    title: 'Clear the cover cache',
                    subtitle: 'Deletes the saved cover art so it is downloaded again, for covers you changed on the server.',
                    action: 'Clear',
                    onPressed: () => ref.read(clearCoverCacheProvider)(),
                  ),
                  const SizedBox(height: 22),
                  Text('Visualizer style', style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Shown behind Now Playing (V cycles). Levels are simulated for now, not read from the audio.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final m in VizMode.values)
                        _ModeChip(
                          label: m.label,
                          selected: m == viz,
                          onTap: () =>
                              ref.read(vizModeProvider.notifier).set(m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
                  const SizedBox(height: 32),
                  const _Credits(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Attribution for the sidebar icon artwork.
class _Credits extends StatelessWidget {
  const _Credits();

  static const _entries = [
    (
      'Library, Cast, Artists, Lists, Radio, Settings and Volume icons',
      'UseAnimations (https://useanimations.com), MIT License',
    ),
    (
      'Home icon',
      'Lucide (https://lucide.dev) icon, animation from Lucide Animated (https://lucide-animated.com) by pqoqubbw, MIT License. Translated into code by Claude.',
    ),
    (
      'App font',
      'Google Sans Flex (https://github.com/googlefonts/googlesans-flex), SIL Open Font License 1.1',
    ),
    (
      'Japanese and Chinese text',
      'Noto Sans JP and Noto Sans SC (https://fonts.google.com/noto), SIL Open Font License 1.1',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: 'Credits',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Credits', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Sidebar icon artwork:',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            for (final (what, who) in _entries) ...[
              const SizedBox(height: 12),
              Text(what, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              SelectableText(who, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Speed of the Now Playing title swap and track-change choreography.
class _SpeedRow extends ConsumerWidget {
  const _SpeedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final speed = ref.watch(letterSpeedProvider);
    final notifier = ref.read(letterSpeedProvider.notifier);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Track change speed',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${speed.toStringAsFixed(1)}×',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: speed == 1 ? null : () => notifier.set(1),
                child: const Text('Reset'),
              ),
            ],
          ),
          Text(
            'How fast the old title pops out and the new one pops in on Now Playing. 1× is automatic: quicker for long titles.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          // The stock Material Slider
          // left Windows' accessibility tree inconsistent: hundreds of "will
          // not be in the tree" errors from the moment this page opened. One
          // explicit node instead.
          Semantics(
            container: true,
            excludeSemantics: true,
            slider: true,
            label: 'Track change speed',
            value: '${speed.toStringAsFixed(1)}×',
            increasedValue:
                '${(speed + .1).clamp(LetterSpeedNotifier.min, LetterSpeedNotifier.max).toStringAsFixed(1)}×',
            decreasedValue:
                '${(speed - .1).clamp(LetterSpeedNotifier.min, LetterSpeedNotifier.max).toStringAsFixed(1)}×',
            onIncrease: () => notifier.set(speed + .1),
            onDecrease: () => notifier.set(speed - .1),
            child: _SpeedSlider(value: speed, onChanged: notifier.set),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
      builder: (context, s) => AnimatedContainer(
        duration: Motion.of(context, Motion.slow),
        curve: Motion.curve(context, Motion.spring),
        height: 40,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : (s.hovered
                    ? scheme.surfaceContainerHighest
                    : scheme.surfaceContainerHigh),
          borderRadius: BorderRadius.circular(selected ? 20 : 12),
        ),
        child: Ripple(
          color: selected ? scheme.onPrimary : scheme.onSurface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Under the server-sync switch: where the queue was last saved, or why it is on
/// this PC instead.
class _QueueStatusLine extends ConsumerWidget {
  const _QueueStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(queueSyncStatusProvider);
    final scheme = Theme.of(context).colorScheme;
    final time = status.at == null ? '' : ' at ${TimeOfDay.fromDateTime(status.at!).format(context)}';
    final into = status.position.inSeconds;
    final place = '${into ~/ 60}:${(into % 60).toString().padLeft(2, '0')} into the song';
    final took = status.took == null ? '' : ' It took ${(status.took!.inMilliseconds / 1000).toStringAsFixed(1)} s to send.';
    final songs = status.songs == 1 ? '1 song' : '${status.songs} songs';
    final (icon, text) = switch (status.home) {
      QueueHome.none => (Icons.hourglass_empty_rounded, 'Nothing saved yet this session.'),
      QueueHome.server => (Icons.cloud_done_rounded, 'Your queue is on the server: saved$time, $songs, $place.$took'),
      QueueHome.thisPc => (
        Icons.save_alt_rounded,
        'Your queue is saved on this PC only${status.reason == null ? '' : ' (${status.reason})'}: saved$time, $songs, $place.',
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// A row with a title, a hint and a button.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onPressed,
    this.busy = false,
    this.status,
    this.statusIsError = false,
    this.disabled = false,
  });

  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onPressed;

  /// A spinner stands in for the button while the job runs, with [status] under the hint.
  final bool busy;
  final String? status;
  final bool statusIsError;

  /// Another job is running: the button waits.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                if (status != null && status!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    status!,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: statusIsError ? scheme.error : scheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (busy)
            const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3))
          else
            FilledButton.tonal(onPressed: disabled ? null : onPressed, child: Text(action)),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // One toggle node for the whole row (title, hint and the switch itself
    // would otherwise merge into one button with a toggle inside it).
    return Semantics(
      container: true,
      excludeSemantics: true,
      toggled: value,
      label: title,
      hint: subtitle,
      onTap: () => onChanged(!value),
      child: Pressable(
        onTap: () => onChanged(!value),
        builder: (context, s) => AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: s.hovered
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              IgnorePointer(
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain slider for the track change speed: a pill track, a filled part and
/// a handle, in steps of 0.1. Stands in for Material's `Slider`, which made
/// Windows' accessibility tree fail on every update once this page was open.
class _SpeedSlider extends StatelessWidget {
  const _SpeedSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  void _set(double dx, double width) {
    final t = (dx / width).clamp(0.0, 1.0);
    final raw =
        LetterSpeedNotifier.min +
        t * (LetterSpeedNotifier.max - LetterSpeedNotifier.min);
    onChanged((raw * 10).round() / 10);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t =
        (value - LetterSpeedNotifier.min) /
        (LetterSpeedNotifier.max - LetterSpeedNotifier.min);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _set(d.localPosition.dx, w),
            onHorizontalDragUpdate: (d) => _set(d.localPosition.dx, w),
            child: SizedBox(
              height: 40,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: w * t,
                    height: 8,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Positioned(
                    left: (w * t - 3).clamp(0.0, w - 6),
                    child: Container(
                      width: 6,
                      height: 28,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
