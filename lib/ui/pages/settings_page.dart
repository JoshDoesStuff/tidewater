import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                    title: 'Look up missing lyrics online',
                    subtitle: 'When your server has no lyrics for a track, ask lrclib.net. This sends the artist, title, album and length of that track to lrclib.net.',
                    value: ref.watch(lrclibEnabledProvider),
                    onChanged: ref.read(lrclibEnabledProvider.notifier).set,
                  ),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    title: 'Hide Japanese text',
                    subtitle: 'Removes Japanese characters from artist, album, track and playlist names. A name that is only Japanese shows as a dash.',
                    value: ref.watch(hideJapaneseProvider),
                    onChanged: ref.read(hideJapaneseProvider.notifier).set,
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
      'Library, Cast, Artists, Lists, Radio and Settings icons',
      'UseAnimations (https://useanimations.com), MIT License',
    ),
    (
      'Home icon',
      'Lucide (https://lucide.dev) icon, animation from Lucide Animated (https://lucide-animated.com) by pqoqubbw, MIT License. Translated into code by Claude.',
    ),
    (
      'Liked icon',
      'Heart shape from UseAnimations (https://useanimations.com), MIT License. Animated in code by Claude.',
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
            'How fast the old title pops out and the new one pops in on Now Playing.',
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
