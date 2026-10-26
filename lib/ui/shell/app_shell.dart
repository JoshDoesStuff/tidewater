import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/destinations.dart';
import '../../app/providers/library_providers.dart';
import '../../app/providers/playback_providers.dart';
import '../../app/providers/cover_prefetch.dart';
import '../../app/providers/scrobble_providers.dart';
import '../../app/providers/selection.dart';
import '../../app/providers/session_persistence.dart';
import '../../app/providers/system_media_providers.dart';
import '../../app/providers/settings_providers.dart';
import '../../app/providers/ui_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/models/track.dart';
import '../now_playing/now_playing_overlay.dart';
import '../widgets/animated_glyphs.dart';
import '../widgets/expressive_buttons.dart';
import '../pages/album_page.dart' show goBack;
import 'mini_player.dart';
import 'selection_bar.dart';
import '../widgets/track_drag.dart';
import 'nav_rail.dart';
import 'shell_effects.dart';
import 'title_bar.dart';
import 'toast_layer.dart';

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
  static bool _isDetail(String location) =>
      location.startsWith('/album/') ||
      location.startsWith('/artist/') ||
      location.startsWith('/playlist/') ||
      location == '/search';

  final _pointer = ValueNotifier<Offset>(Offset.zero);

  @override
  void didUpdateWidget(AppShell old) {
    super.didUpdateWidget(old);
    // Songs picked on one page do not follow you to the next.
    if (old.location != widget.location) Future.microtask(() => mounted ? ref.read(selectionProvider.notifier).clear() : null);
  }

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

  /// What the FAB shuffles on this page: the whole library on Home, otherwise
  /// the songs the page shows. Null hides it (Library, Artists, Settings...).
  ({String label, Future<void> Function() run})? _shuffleFor(String location) {
    final player = ref.read(playbackProvider.notifier);
    if (location == Destination.home.path) {
      return (label: 'Shuffle all', run: player.shuffleAll);
    }
    if (location == Destination.liked.path) {
      return (
        label: 'Shuffle liked',
        run: () async {
          final liked = ref.read(likedProvider);
          final songs = [
            for (final t in ref.read(likedSongsProvider).value ?? const <Track>[])
              if (liked.contains(t.id)) t,
          ];
          if (songs.isNotEmpty) await player.playTracks(songs, shuffle: true);
        },
      );
    }
    return null;
  }

  /// Songs dropped on the mini player join the end of the queue (or start it).
  Future<void> _dropOnQueue(TrackDrag drag) async {
    final player = ref.read(playbackProvider.notifier);
    try {
      final tracks = await drag.load();
      if (tracks.isEmpty) return;
      if (ref.read(playbackProvider).queue.isEmpty) {
        await player.playTracks(tracks);
        return;
      }
      await player.addLast(tracks);
      ref.read(toastProvider.notifier).show(tracks.length == 1 ? 'Added to the queue.' : 'Added ${tracks.length} songs to the queue.');
    } catch (_) {
      ref.read(toastProvider.notifier).show('Couldn\'t add those to the queue.', error: true);
    }
    ref.read(selectionProvider.notifier).clear();
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
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (ctrl && key == LogicalKeyboardKey.keyA) {
      if (npOpen) {
        if (!ref.read(queueOpenProvider)) return false;
        ref.read(queueSelectionProvider.notifier).selectAll(ref.read(playbackProvider).queue.length);
        return true;
      }
      final scope = ref.read(selectionScopeProvider);
      if (scope == null || scope.tracks.isEmpty) return false;
      ref.read(selectionProvider.notifier).selectAll(scope.tracks);
      return true;
    }
    if (key == LogicalKeyboardKey.escape && npOpen && ref.read(queueSelectionProvider).isNotEmpty) {
      ref.read(queueSelectionProvider.notifier).clear();
      return true;
    }
    if (key == LogicalKeyboardKey.escape && !npOpen && ref.read(selectionProvider).isNotEmpty) {
      ref.read(selectionProvider.notifier).clear();
      return true;
    }
    if ((ctrl && key == LogicalKeyboardKey.keyK) || key == LogicalKeyboardKey.slash) {
      if (!npOpen) GoRouter.of(context).go('/search');
    } else if (key == LogicalKeyboardKey.space) {
      player.toggle();
    } else if (key == LogicalKeyboardKey.keyN) {
      player.next();
    } else if (key == LogicalKeyboardKey.keyP) {
      player.previous();
    } else if (key == LogicalKeyboardKey.keyM) {
      player.toggleMute();
    } else if (key == LogicalKeyboardKey.keyL && npOpen) {
      ref.read(lyricsOnProvider.notifier).toggle();
    } else if (key == LogicalKeyboardKey.keyQ && npOpen) {
      ref.read(queueOpenProvider.notifier).toggle();
    } else if (key == LogicalKeyboardKey.keyV && npOpen) {
      ref.read(vizModeProvider.notifier).cycle();
    } else if (key == LogicalKeyboardKey.escape) {
      if (ref.read(queueOpenProvider)) {
        ref.read(queueOpenProvider.notifier).set(false);
      } else if (ref.read(vizPopupOpenProvider)) {
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
    ref.watch(scrobbleServiceProvider); // keeps plays reported for as long as the shell lives
    ref.watch(coverPrefetchProvider); // decodes upcoming covers ahead of time
    ref.watch(sessionPersistenceProvider); // saves and restores the queue
    ref.watch(systemMediaServiceProvider); // Windows media overlay and media keys
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final compact = width < 900 || ref.watch(railCollapsedProvider);
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
                // The rail glides between its wide and icon-only widths.
                AnimatedPositioned(
                  duration: Motion.of(context, Motion.medium),
                  curve: Motion.curve(context, Motion.emphasized),
                  left: railWidth,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: widget.child,
                ),
                AnimatedPositioned(
                  duration: Motion.of(context, Motion.medium),
                  curve: Motion.curve(context, Motion.emphasized),
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: railWidth,
                  child: NavRail(
                    // Album and artist pages belong to the Library.
                    selected: widget.location == '/search'
                        ? null
                        : widget.location.startsWith('/playlist/')
                            ? Destination.lists
                            : (Destination.fromLocation(widget.location) ?? Destination.library),
                    compact: compact,
                    onSelected: (d) => context.go(d.path),
                    onMenu: ref.read(railCollapsedProvider.notifier).toggle,
                    onBack: _isDetail(widget.location) ? () => goBack(context) : null,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: miniWidth),
                      // Drop songs on the pill to add them to the end of the queue.
                      child: TrackDropTarget(radius: 36, onDrop: _dropOnQueue, child: const MiniPlayer()),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: TitleBar.height + 8,
                  child: const Center(child: SelectionBar()),
                ),
                Positioned(
                  right: 32,
                  bottom: 24,
                  child: Builder(
                    builder: (context) {
                      final shuffle = _shuffleFor(widget.location);
                      final d = Motion.of(context, Motion.medium);
                      return IgnorePointer(
                        ignoring: shuffle == null,
                        child: AnimatedOpacity(
                          opacity: shuffle == null ? 0 : 1,
                          duration: d,
                          child: AnimatedScale(
                            scale: shuffle == null ? .8 : 1,
                            duration: d,
                            curve: Motion.curve(context, Motion.spring),
                            child: ExpressiveFab(
                              icon: Icons.shuffle_rounded,
                              glyph: GlyphKind.shuffle,
                              label: shuffle?.label ?? 'Shuffle all',
                              extended: fabExtended,
                              onPressed: () => shuffle?.run(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Positioned.fill(child: WashLayer()),
                const Positioned.fill(child: NowPlayingOverlay()),
                const Positioned.fill(child: ToastLayer()),
                const Positioned(left: 0, right: 0, top: 0, child: TitleBar()),
              ],
            ),
          ),
        );
      },
    );
  }
}
