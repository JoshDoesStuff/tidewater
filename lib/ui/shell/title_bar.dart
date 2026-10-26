import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../widgets/animated_glyphs.dart';
import '../widgets/pressable.dart';

/// Draggable region plus minimize / maximize / close, since the native title
/// bar is hidden. Sits in the top 36 px of the window.
class TitleBar extends StatefulWidget {
  const TitleBar({super.key});

  static const height = 36.0;

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _sync();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _sync() async {
    try {
      final m = await windowManager.isMaximized();
      if (mounted) setState(() => _maximized = m);
    } catch (_) {
      // No window host (e.g. widget tests).
    }
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TitleBar.height,
      child: Row(
        children: [
          const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
          _CaptionButton(glyph: GlyphKind.minimize, label: 'Minimize', onTap: windowManager.minimize),
          _CaptionButton(
            glyph: _maximized ? GlyphKind.restore : GlyphKind.maximize,
            label: _maximized ? 'Restore' : 'Maximize',
            onTap: () => _maximized ? windowManager.unmaximize() : windowManager.maximize(),
          ),
          _CaptionButton(glyph: GlyphKind.close, label: 'Close', onTap: windowManager.close, danger: true),
        ],
      ),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({required this.glyph, required this.label, required this.onTap, this.danger = false});

  final GlyphKind glyph;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      cursor: SystemMouseCursors.basic,
      builder: (context, s) {
        final hot = s.hovered || s.pressed;
        return Container(
          width: 46,
          height: TitleBar.height,
          color: hot
              ? (danger ? scheme.error : scheme.surfaceContainerHighest)
              : scheme.surfaceContainerHighest.withValues(alpha: 0),
          child: Center(
            child: AnimatedGlyph(
              kind: glyph,
              size: 16,
              color: hot && danger ? scheme.onError : scheme.onSurfaceVariant,
              hovered: s.hovered,
              active: s.pressed,
            ),
          ),
        );
      },
    );
  }
}
