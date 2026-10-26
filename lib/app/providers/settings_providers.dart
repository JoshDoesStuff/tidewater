import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// Overridden in `main()` (and in tests) with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Settings toggle for reduced motion. The app root folds it into
/// `MediaQuery.disableAnimations`.
class ReduceMotionNotifier extends Notifier<bool> {
  static const _key = 'reduce_motion';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final reduceMotionProvider = NotifierProvider<ReduceMotionNotifier, bool>(ReduceMotionNotifier.new);

/// Speed of the Now Playing title swap (old title pops out, new one pops in).
/// A multiplier on the automatic pace ([titlePace]): 1 is the default, 2 is twice as fast.
class LetterSpeedNotifier extends Notifier<double> {
  static const key = 'letter_speed';
  static const min = .5;
  static const max = 3.0;

  @override
  double build() => (ref.watch(sharedPreferencesProvider).getDouble(key) ?? 1).clamp(min, max);

  void set(double value) {
    state = value.clamp(min, max);
    ref.read(sharedPreferencesProvider).setDouble(key, state);
  }
}

final letterSpeedProvider = NotifierProvider<LetterSpeedNotifier, double>(LetterSpeedNotifier.new);

/// The automatic pace of the title swap, by title length: 1x for a one-word title
/// like "Xeon" (6 characters or fewer), 1.3x around 23 characters ("Head Full of
/// Nightmares"), 1.7x for 45 or more, and smoothly in between. The Settings speed
/// multiplies it.
double titlePace(String title) {
  final n = title.runes.length.toDouble();
  if (n <= 6) return 1.0;
  if (n <= 23) return 1.0 + .3 * (n - 6) / 17;
  return 1.3 + .4 * ((n - 23) / 22).clamp(0.0, 1.0);
}

/// Dark is the default; light is supported.
class DarkThemeNotifier extends Notifier<bool> {
  static const _key = 'dark_theme';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final darkThemeProvider = NotifierProvider<DarkThemeNotifier, bool>(DarkThemeNotifier.new);

enum VizMode {
  aurora('Aurora'),
  shapes('Shapes'),
  bars('Bars'),
  ring('Ring'),
  off('Off');

  const VizMode(this.label);
  final String label;

  VizMode get next => values[(index + 1) % values.length];
}

/// Now Playing visualizer style; the choice is persisted.
class VizModeNotifier extends Notifier<VizMode> {
  static const _key = 'viz_mode';

  @override
  VizMode build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return VizMode.values.firstWhere((m) => m.name == name, orElse: () => VizMode.aurora);
  }

  void set(VizMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }

  void cycle() => set(state.next);
}

final vizModeProvider = NotifierProvider<VizModeNotifier, VizMode>(VizModeNotifier.new);

/// Whether the lyrics card is shown in Now Playing.
class LyricsOnNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final lyricsOnProvider = NotifierProvider<LyricsOnNotifier, bool>(LyricsOnNotifier.new);

/// Last known global pointer position, used as the origin of the color wash.
final pointerOriginProvider = Provider<ValueNotifier<Offset?>>((ref) {
  final n = ValueNotifier<Offset?>(null);
  ref.onDispose(n.dispose);
  return n;
});

/// Tell the server what is playing and count plays (needed for Home's
/// recently/most played).
class ScrobbleEnabledNotifier extends Notifier<bool> {
  static const _key = 'scrobble';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final scrobbleEnabledProvider = NotifierProvider<ScrobbleEnabledNotifier, bool>(ScrobbleEnabledNotifier.new);

/// Ask lrclib.net for lyrics when the server has none. Sends the artist,
/// title, album and length of the track to a third party, so it is a setting.
class LrclibEnabledNotifier extends Notifier<bool> {
  static const _key = 'lrclib';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final lrclibEnabledProvider = NotifierProvider<LrclibEnabledNotifier, bool>(LrclibEnabledNotifier.new);

/// Liked songs page: cards instead of a list. Persisted.
class LikedAsCardsNotifier extends Notifier<bool> {
  static const _key = 'liked_as_cards';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  void set(bool cards) {
    state = cards;
    ref.read(sharedPreferencesProvider).setBool(_key, cards);
  }
}

final likedAsCardsProvider = NotifierProvider<LikedAsCardsNotifier, bool>(LikedAsCardsNotifier.new);

/// The queue docks beside Now Playing (shrinking the player to fit) instead
/// of floating over it as a popup. Persisted.
class QueueSidePanelNotifier extends Notifier<bool> {
  static const _key = 'queue_side_panel';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final queueSidePanelProvider = NotifierProvider<QueueSidePanelNotifier, bool>(QueueSidePanelNotifier.new);

/// While an icon redraws itself, keep a faint copy of it underneath instead of
/// letting it disappear first. Persisted.
class IconGhostNotifier extends Notifier<bool> {
  static const _key = 'icon_ghost';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final iconGhostProvider = NotifierProvider<IconGhostNotifier, bool>(IconGhostNotifier.new);

/// Seek while dragging the progress bar. Off (the default) the song jumps once,
/// when the bar is let go, which avoids a burst of seeks (and a buffering
/// flash) mid-drag. Persisted.
class LiveScrubNotifier extends Notifier<bool> {
  static const _key = 'live_scrub';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final liveScrubProvider = NotifierProvider<LiveScrubNotifier, bool>(LiveScrubNotifier.new);

/// The sidebar collapsed to icons by hand (the menu button). Windows narrower
/// than 900 px collapse it on their own whatever this says. Persisted.
class RailCollapsedNotifier extends Notifier<bool> {
  static const _key = 'rail_collapsed';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  void toggle() => set(!state);

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final railCollapsedProvider = NotifierProvider<RailCollapsedNotifier, bool>(RailCollapsedNotifier.new);

/// Keep the play queue and position on the server too, so a restart (or another
/// device) resumes where you stopped and the app does not have to save the
/// position to disk every few seconds. Persisted.
class SyncPositionNotifier extends Notifier<bool> {
  static const _key = 'sync_position';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final syncPositionProvider = NotifierProvider<SyncPositionNotifier, bool>(SyncPositionNotifier.new);

/// Show the "Wrapping up" screen every time the app is closed, and keep it up
/// for a moment so it can be seen. Off (the default), it only appears when
/// saving to the server takes more than a moment, and closing is as quick as the
/// save. Persisted.
class WrapUpAlwaysNotifier extends Notifier<bool> {
  static const _key = 'wrap_up_always';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final wrapUpAlwaysProvider = NotifierProvider<WrapUpAlwaysNotifier, bool>(WrapUpAlwaysNotifier.new);
