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
        padding: const EdgeInsets.fromLTRB(24, 36, 32, PageFrame.bottomClearance),
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
                  const SizedBox(height: 22),
                  Text('Visualizer style', style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Shown behind Now Playing (V cycles). Levels are simulated for now, not read from the audio.',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final m in VizMode.values)
                        _ModeChip(label: m.label, selected: m == viz, onTap: () => ref.read(vizModeProvider.notifier).set(m)),
                    ],
                  ),
                ],
              ),
            ),
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
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Track change speed', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text(
                '${speed.toStringAsFixed(1)}×',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary),
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
          Slider(
            value: speed,
            min: LetterSpeedNotifier.min,
            max: LetterSpeedNotifier.max,
            divisions: 25,
            label: '${speed.toStringAsFixed(1)}×',
            onChanged: notifier.set,
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});

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
          color: selected ? scheme.primary : (s.hovered ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh),
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
  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => onChanged(!value),
      semanticLabel: title,
      builder: (context, s) => AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: s.hovered ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            IgnorePointer(child: Switch(value: value, onChanged: onChanged)),
          ],
        ),
      ),
    );
  }
}
