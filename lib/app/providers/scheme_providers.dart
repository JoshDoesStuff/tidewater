import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/color/cover_seed.dart';
import 'cover_providers.dart';
import 'playback_providers.dart';
import 'session_providers.dart';

/// The seed color the app is currently themed from.
///
/// It only changes once the new cover's colors are known, so the app recolors
/// once per album (never default -> placeholder -> real). Before anything has
/// played it is null and the default scheme shows.
class SchemeSeedNotifier extends Notifier<CoverSeed?> {
  @override
  CoverSeed? build() {
    // A different server means different covers: start over.
    ref.watch(sessionProvider);
    ref.listen(currentCoverKeyProvider, (_, key) {
      if (key != null) _follow(key);
    }, fireImmediately: true);
    return null;
  }

  Future<void> _follow(CoverKey key) async {
    final seed = await ref.read(coverSeedProvider(key).future);
    // The listener may have moved on while the cover was being read.
    if (ref.mounted && ref.read(currentCoverKeyProvider) == key) state = seed;
  }
}

final schemeSeedProvider = NotifierProvider<SchemeSeedNotifier, CoverSeed?>(SchemeSeedNotifier.new);
