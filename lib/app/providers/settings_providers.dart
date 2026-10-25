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
/// A multiplier: 1 is the default pace, 2 is twice as fast.
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

/// Draw Japanese text (artist, album, track and playlist names) with Japanese
/// fonts instead of the system's default CJK pick. Persisted.
class JapaneseTextNotifier extends Notifier<bool> {
  static const _key = 'japanese_text';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final japaneseTextProvider = NotifierProvider<JapaneseTextNotifier, bool>(JapaneseTextNotifier.new);

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
