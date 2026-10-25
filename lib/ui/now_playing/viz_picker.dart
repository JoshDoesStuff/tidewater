import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/settings_providers.dart';
import '../../app/providers/ui_providers.dart';
import '../../app/theme/motion.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/pressable.dart';

const _glyphs = {
  VizMode.aurora: GlyphKind.aurora,
  VizMode.shapes: GlyphKind.shapes,
  VizMode.bars: GlyphKind.visualizer,
  VizMode.ring: GlyphKind.ring,
  VizMode.off: GlyphKind.off,
};

/// The ✨ popup: scales and fades from the top right (the button) on the
/// spring curve. Picks the visualizer style (persisted by the provider).
class VizPicker extends ConsumerWidget {
  const VizPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final open = ref.watch(vizPopupOpenProvider);
    final mode = ref.watch(vizModeProvider);
    return IgnorePointer(
      ignoring: !open,
      child: AnimatedOpacity(
        opacity: open ? 1 : 0,
        duration: Motion.of(context, Motion.medium),
        child: AnimatedScale(
          scale: open ? 1 : .9,
          alignment: Alignment.topRight,
          duration: Motion.of(context, Motion.slow),
          curve: Motion.curve(context, Motion.spring),
          child: AnimatedSlide(
            offset: open ? Offset.zero : const Offset(0, -.02),
            duration: Motion.of(context, Motion.slow),
            curve: Motion.curve(context, Motion.spring),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: scheme.shadow.withValues(alpha: .45), blurRadius: 30, offset: const Offset(0, 12)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final m in VizMode.values)
                    Pressable(
                      onTap: () {
                        ref.read(vizModeProvider.notifier).set(m);
                        ref.read(vizPopupOpenProvider.notifier).set(false);
                      },
                      semanticLabel: m.label,
                      builder: (context, s) {
                        final selected = m == mode;
                        return AnimatedContainer(
                          duration: Motion.of(context, Motion.medium),
                          curve: Motion.curve(context, Motion.spring),
                          width: 176,
                          height: 44,
                          padding: const EdgeInsets.only(left: 14, right: 18),
                          decoration: BoxDecoration(
                            color: selected
                                ? scheme.primary
                                : (s.hovered ? scheme.surfaceContainerHigh : scheme.surfaceContainerHigh.withValues(alpha: 0)),
                            borderRadius: BorderRadius.circular(selected ? 22 : 16),
                          ),
                          child: Row(
                            children: [
                              AnimatedGlyph(
                                kind: _glyphs[m]!,
                                size: 22,
                                color: selected ? scheme.onPrimary : scheme.onSurface,
                                hovered: s.hovered,
                                active: selected,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                m.label,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontSize: 14,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      color: selected ? scheme.onPrimary : scheme.onSurface,
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
