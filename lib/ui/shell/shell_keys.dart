import 'package:flutter/widgets.dart';

/// Mini player cover: the origin of the Now Playing hero flight.
final miniCoverKey = GlobalKey(debugLabel: 'miniCover');

/// Formats a position as m:ss.
String formatDuration(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
