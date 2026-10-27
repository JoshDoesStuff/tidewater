import 'package:flutter/foundation.dart';

/// Switches for finding out what costs the most to draw, flipped while the app runs (in
/// debug and profile builds only): press Ctrl+Alt+1 to 9 and watch the "SLOW FRAME" lines.
/// Everything is on by default; a release build never turns anything off.
class PerfFlags extends ChangeNotifier {
  PerfFlags._();

  static final instance = PerfFlags._();

  bool ambient = true;
  bool aurora = true;
  bool shadows = true;
  bool smoothClip = true;
  bool covers = true;
  bool text = true;
  bool clip = true;
  bool chrome = true;
  bool cards = true;

  static const names = ['ambient shapes + spotlight', 'aurora', 'card shadows', 'smooth card edges', 'cover pictures', 'card text', 'card clipping at all', 'mini player + shuffle button', 'the cards altogether'];

  bool toggle(int index) {
    if (kReleaseMode) return false;
    switch (index) {
      case 0:
        ambient = !ambient;
      case 1:
        aurora = !aurora;
      case 2:
        shadows = !shadows;
      case 3:
        smoothClip = !smoothClip;
      case 4:
        covers = !covers;
      case 5:
        text = !text;
      case 6:
        clip = !clip;
      case 7:
        chrome = !chrome;
      case 8:
        cards = !cards;
      default:
        return false;
    }
    notifyListeners();
    debugPrint('PERF ${names[index]}: ${[ambient, aurora, shadows, smoothClip, covers, text, clip, chrome, cards][index] ? 'ON' : 'OFF'}');
    return true;
  }
}
