import 'package:material_color_utilities/material_color_utilities.dart';

/// The color an album's scheme grows from, plus whether the art has no real
/// color to speak of (gray, black-and-white), so the scheme should be quiet
/// instead of tinting the whole app a random hue.
class CoverSeed {
  const CoverSeed(this.argb, {this.muted = false});

  /// A stable stand-in for covers we can't read: a pleasant hue picked from
  /// the id, so the app still recolors per album.
  factory CoverSeed.fromKey(String key) {
    var h = 0x811c9dc5; // FNV-1a
    for (final c in key.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return CoverSeed(Hct.from((h % 360).toDouble(), 48, 50).toInt());
  }

  final int argb;
  final bool muted;

  @override
  bool operator ==(Object other) => other is CoverSeed && other.argb == argb && other.muted == muted;

  @override
  int get hashCode => Object.hash(argb, muted);

  @override
  String toString() => 'CoverSeed(${argb.toRadixString(16)}${muted ? ', muted' : ''})';
}

/// Picks the seed from decoded cover pixels (ARGB ints): Celebi quantizing,
/// then Material's `Score`, which prefers populous, colorful, not-too-dark
/// colors. Art with no color falls back to its most common color, muted.
Future<CoverSeed> seedFromPixels(List<int> argbPixels) async {
  final opaque = [for (final p in argbPixels) if (((p >> 24) & 0xff) >= 128) p | 0xff000000];
  if (opaque.isEmpty) return const CoverSeed(0xff808080, muted: true);
  final result = await QuantizerCelebi().quantize(opaque, 128);
  const none = 0;
  final ranked = Score.score(result.colorToCount, desired: 1, fallbackColorARGB: none);
  if (ranked.isNotEmpty && ranked.first != none) return CoverSeed(ranked.first);
  var best = 0xff808080;
  var bestCount = -1;
  result.colorToCount.forEach((color, count) {
    if (count > bestCount) {
      best = color;
      bestCount = count;
    }
  });
  return CoverSeed(best, muted: true);
}
