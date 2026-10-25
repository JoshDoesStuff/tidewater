import 'package:flutter_riverpod/misc.dart' show Override;

import '../../core/playback/queue_engine.dart';
import '../providers/playback_providers.dart';
import '../providers/session_providers.dart';
import 'media_kit_backend.dart';

/// Swaps the simulated engine for libmpv. Used by `main()`; tests and tools
/// keep the simulated one. Call `MediaKit.ensureInitialized()` first.
Override realEngineOverride() => playbackEngineProvider.overrideWith((ref) {
      final engine = QueueEngine(
        // Read lazily: the API changes when the person switches servers.
        backend: MediaKitBackend(resolve: (id) => ref.read(apiProvider).streamUri(id)),
      );
      ref.onDispose(engine.dispose);
      return engine;
    });
