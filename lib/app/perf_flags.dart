import 'package:flutter/foundation.dart';

/// Switches for finding out what costs the most to draw, flipped while the app runs (in
/// debug and profile builds only): press Ctrl+Alt+1 to 9 (0 is the ninth switch after the cards) and watch the "FRAMES" summaries.
/// Everything is on by default; a release build never turns anything off.
class PerfFlags extends ChangeNotifier {
  PerfFlags._();

  static final instance = PerfFlags._();

  bool ambient = true;
  bool aurora = true;
  bool shadows = true;
  bool smoothClip = true;
  bool covers = true;
  bool scrollIn = true;
  bool deferCovers = true;
  bool chrome = true;
  bool cards = true;
  bool sprites = true;

  static const names = ['ambient shapes + spotlight', 'aurora', 'card shadows', 'smooth card edges', 'cover pictures', 'rows animating in as they scroll into view', 'holding covers back while scrolling fast', 'mini player + shuffle button', 'the cards altogether', 'resting cards as one picture'];

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
        scrollIn = !scrollIn;
      case 6:
        deferCovers = !deferCovers;
      case 7:
        chrome = !chrome;
      case 8:
        cards = !cards;
      case 9:
        sprites = !sprites;
      default:
        return false;
    }
    notifyListeners();
    debugPrint('PERF ${names[index]}: ${[ambient, aurora, shadows, smoothClip, covers, scrollIn, deferCovers, chrome, cards, sprites][index] ? 'ON' : 'OFF'}');
    return true;
  }
}
