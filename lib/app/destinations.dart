import 'package:flutter/material.dart';

/// Top-level places reachable from the navigation rail.
enum Destination {
  home('/home', 'Home', Icons.home_rounded),
  library('/library', 'Library', Icons.library_music_rounded),
  artists('/artists', 'Artists', Icons.person_rounded),
  liked('/liked', 'Liked', Icons.favorite_rounded),
  lists('/lists', 'Lists', Icons.queue_music_rounded),
  radio('/radio', 'Radio', Icons.radio_rounded),
  settings('/settings', 'Settings', Icons.settings_rounded);

  const Destination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;

  /// Destination for a router location, or null if it matches none.
  static Destination? fromLocation(String location) {
    for (final d in values) {
      if (location == d.path || location.startsWith('${d.path}/')) return d;
    }
    return null;
  }
}
