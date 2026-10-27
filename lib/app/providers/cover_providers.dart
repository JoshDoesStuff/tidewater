import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/cover_cache.dart';
import '../../core/color/cover_seed.dart';
import 'seed_store.dart';
import 'session_providers.dart';
import 'settings_providers.dart';

/// Where covers are cached. Tests override this with a temp folder.
final coverRootProvider = Provider<Future<Directory> Function()>((ref) => () async {
      final base = await getApplicationCacheDirectory();
      return Directory('${base.path}${Platform.pathSeparator}covers');
    });

/// The cover cache for the signed-in server (its own sub-folder).
final coverCacheProvider = Provider<CoverStore>((ref) {
  final config = ref.watch(sessionProvider);
  // Covers still on screen while signing out ask for images once more; they
  // just fail quietly until the login page replaces them.
  if (config == null) return const _NoCovers();
  final api = ref.watch(apiProvider);
  final root = ref.watch(coverRootProvider);
  final folder = CoverCache.serverFolder(config.baseUrl);
  final cache = CoverCache(
    directory: () async => Directory('${(await root()).path}${Platform.pathSeparator}$folder'),
    fetch: (id, size) => api.getCoverArt(id, size: size),
  );
  // Keep the cache under 1 GB, dropping the least recently used covers. (512 albums
  // take about 150 MB; the cap only matters for huge libraries.)
  unawaited(cache.trim(1024 * 1024 * 1024).catchError((Object _) {}));
  return cache;
});

class _NoCovers implements CoverStore {
  const _NoCovers();

  @override
  Future<Uint8List> get(String id, {int size = 300, bool Function()? wanted}) async => throw StateError('Not signed in');
}

/// Identifies one album's cover for scheme generation.
typedef CoverKey = ({String albumId, String? coverArt});

/// Decodes an image (downscaled to 112 px, plenty for color) and picks its
/// seed color. The quantizing runs on another isolate.
Future<CoverSeed> seedFromImageBytes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 112);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width;
    final h = image.height;
    image.dispose();
    if (data == null) throw StateError('could not read pixels');
    final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final pixels = <int>[
      for (var i = 0; i + 3 < w * h * 4; i += 4) (rgba[i + 3] << 24) | (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2],
    ];
    return await Isolate.run(() => seedFromPixels(pixels));
  } finally {
    codec.dispose();
  }
}

final seedStoreProvider = Provider<SeedStore>((ref) => SeedStore(ref.watch(sharedPreferencesProvider)));

/// The seed color of a cover. Cached per cover for the session and, once
/// extracted, on disk ([SeedStore]) so the next launch skips decoding it.
/// Failure (no art, offline, undecodable) yields a stable color from the
/// album id so the app still recolors (and is not remembered).
final coverSeedProvider = FutureProvider.family<CoverSeed, CoverKey>((ref, key) async {
  final art = key.coverArt;
  if (art == null) return CoverSeed.fromKey(key.albumId);
  final config = ref.read(sessionProvider);
  final storeKey = config == null ? null : '${CoverCache.serverFolder(config.baseUrl)}|$art';
  final store = ref.read(seedStoreProvider);
  if (storeKey != null) {
    final known = store.get(storeKey);
    if (known != null) return known;
  }
  try {
    final seed = await seedFromImageBytes(await ref.watch(coverCacheProvider).get(art, size: 300));
    if (storeKey != null) store.put(storeKey, seed);
    return seed;
  } catch (_) {
    return CoverSeed.fromKey(key.albumId);
  }
});
