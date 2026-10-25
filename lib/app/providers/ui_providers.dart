import 'package:flutter_riverpod/flutter_riverpod.dart';

class BoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
  void toggle() => state = !state;
}

/// Now Playing overlay is open.
final nowPlayingOpenProvider = NotifierProvider<BoolNotifier, bool>(BoolNotifier.new);

/// The visualizer style popup is open (blocks idle mode).
final vizPopupOpenProvider = NotifierProvider<BoolNotifier, bool>(BoolNotifier.new);

/// Idle mode is active in Now Playing.
final idleProvider = NotifierProvider<BoolNotifier, bool>(BoolNotifier.new);
