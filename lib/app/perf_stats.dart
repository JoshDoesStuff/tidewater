import 'package:flutter/foundation.dart';

/// Counts of what the app did, for the profile log (`frame_log.dart`): each slow frame is
/// written out with what happened since the frame before it, so a spike can be matched to
/// its cause (a burst of covers decoding, of cards being pictured, of cards being built...).
/// Counting is a few integer additions; in release builds nothing is counted.
class PerfStats {
  PerfStats._();

  static const enabled = !kReleaseMode;

  // Since the last frame (reset by the log after each frame).
  static int cardsBuilt = 0;
  static int cardsBaked = 0;
  static int bakeMicros = 0;
  static int bakesFailed = 0;
  static int coversShown = 0;
  static int coversShownFromMemory = 0;
  static int diskReads = 0;
  static int downloads = 0;
  static int decodes = 0;
  static int decodeMicros = 0;
  static int entrances = 0;
  static int cardBuilds = 0; // every build of a card, not only new ones
  static int rowBuilds = 0;
  static int standIns = 0; // cards shown as a stand-in, over the frame's build budget
  static int coversHeldBack = 0; // new covers waiting a frame (frame share used up)
  static int bakedTwice = 0; // cards pictured again because their cover arrived after the first picture

  // Running totals / current state.
  static int coversWaiting = 0;
  static int coversLoading = 0;
  static int liveCards = 0;
  static int pictureCards = 0;
  static double scrollSpeed = 0;
  static bool scrolling = false;

  // Page movement since the last frame (any cause), and what moved it last.
  static double moved = 0;
  static double biggestMove = 0;
  static String scrollBy = '-';

  /// Where the user is (page, tab, Now Playing...), kept by `perf_watch.dart`.
  static String screen = '?';

  /// Cover ids asked for on the Songs tab since it was opened (see `perf_watch.dart`).
  static final songsTabCovers = <String>{};

  static final _recolor = Stopwatch();
  static void recolorStarted() => _recolor..reset()..start();

  /// Whether the app is in the middle of recoloring (800 ms after a new album's colors).
  static bool get recoloring => _recolor.isRunning && _recolor.elapsedMilliseconds < 900;

  static void reset() {
    cardsBuilt = 0;
    cardsBaked = 0;
    bakeMicros = 0;
    bakesFailed = 0;
    coversShown = 0;
    coversShownFromMemory = 0;
    diskReads = 0;
    downloads = 0;
    decodes = 0;
    decodeMicros = 0;
    entrances = 0;
    cardBuilds = 0;
    rowBuilds = 0;
    standIns = 0;
    coversHeldBack = 0;
    bakedTwice = 0;
    moved = 0;
    biggestMove = 0;
  }
}
