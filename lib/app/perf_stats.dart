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

  // Running totals / current state.
  static int coversWaiting = 0;
  static int coversLoading = 0;
  static int liveCards = 0;
  static int pictureCards = 0;
  static double scrollSpeed = 0;
  static bool scrolling = false;

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
  }
}
