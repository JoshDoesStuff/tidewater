import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/destinations.dart';
import '../../app/providers/playback_providers.dart';
import '../../app/providers/settings_providers.dart';
import '../../app/providers/ui_providers.dart';
import '../now_playing/now_playing_overlay.dart';
import '../widgets/expressive_buttons.dart';
import 'mini_player.dart';
import 'nav_rail.dart';
import 'shell_effects.dart';
import 'title_bar.dart';

/// Window shell: rail on the left, routed content, custom title bar on top,
/// floating mini player (bottom center) and Shuffle FAB (bottom right), with
/// ambient background, color wash and the Now Playing overlay.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _pointer = ValueNotifier<Offset>(Offset.zero);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _pointer.dispose();
    super.dispose();
  }

  /// Space play/pause, N next, P previous, L lyrics, V visualizer style,
  /// Esc closes Now Playing. Ignored while typing in a text field.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.findAncestorWidgetOfExactType<EditableText>() != null) return false;
    final player = ref.read(playbackProvider.notifier);
    final npOpen = ref.read(nowPlayingOpenProvider);
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      player.toggle();
    } else if (key == LogicalKeyboardKey.keyN) {
      player.next();
    } else if (key == LogicalKeyboardKey.keyP) {
      player.previous();
    } else if (key == LogicalKeyboardKey.keyL && npOpen) {
      ref.read(lyricsOnProvider.notifier).toggle();
    } else if (key == LogicalKeyboardKey.keyV && npOpen) {
      ref.read(vizModeProvider.notifier).cycle();
    } else if (key == LogicalKeyboardKey.escape) {
      if (ref.read(vizPopupOpenProvider)) {
        ref.read(vizPopupOpenProvider.notifier).set(false);
      } else if (npOpen) {
        ref.read(nowPlayingOpenProvider.notifier).set(false);
      } else {
        return false;
      }
    } else {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final compact = width < 900;
        final fabExtended = width >= 1000;
        final railWidth = NavRail.widthFor(compact: compact);
        final fabWidth = fabExtended ? 192.0 : 72.0;
        // Keep the pill centered in the window and clear of the FAB.
        final miniWidth = math.max(320.0, math.min(700.0, width - 2 * (32 + fabWidth + 24)));
        return Material(
          color: scheme.surface,
          child: MouseRegion(
            onHover: (e) => _pointer.value = e.localPosition,
            child: Stack(
              children: [
                Positioned.fill(child: AmbientLayer(pointer: _pointer)),
                Positioned.fill(left: railWidth, child: widget.child),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: railWidth,
                  child: NavRail(
                    selected: Destination.fromLocation(widget.location),
                    compact: compact,
                    onSelected: (d) => context.go(d.path),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(child: SizedBox(width: miniWidth, child: const MiniPlayer())),
                ),
                Positioned(
                  right: 32,
                  bottom: 24,
                  child: ExpressiveFab(
                    icon: Icons.shuffle_rounded,
                    label: 'Shuffle all',
                    extended: fabExtended,
                    onPressed: () => ref.read(playbackProvider.notifier).shuffleAll(),
                  ),
                ),
                const Positioned.fill(child: WashLayer()),
                const Positioned.fill(child: NowPlayingOverlay()),
                const Positioned(left: 0, right: 0, top: 0, child: TitleBar()),
              ],
            ),
          ),
        );
      },
    );
  }
}
