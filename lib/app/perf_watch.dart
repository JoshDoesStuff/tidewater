import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart' show routerProvider;
import 'frame_log.dart';
import 'perf_stats.dart';
import 'providers/library_providers.dart';
import 'providers/playback_providers.dart';
import 'providers/scheme_providers.dart';
import 'providers/settings_providers.dart';
import 'providers/ui_providers.dart';

/// In a profile build, writes what the user is looking at into the profile log: every page
/// change, Now Playing opening and closing, idle mode, lyrics, visualizer style, track changes
/// and recolors, as `NOTE` lines; and keeps [PerfStats.screen] up to date so each slow frame
/// says where it happened. Watched once from the shell; does nothing in other builds.
final perfWatchProvider = Provider<void>((ref) {
  if (!kProfileMode) return;

  var route = '?';
  var tab = ref.read(libraryTabProvider).name;
  var nowPlaying = ref.read(nowPlayingOpenProvider);
  var idle = ref.read(idleProvider);
  var lyrics = ref.read(lyricsOnProvider);
  var viz = ref.read(vizModeProvider).name;
  var queue = ref.read(queueOpenProvider);

  void update() {
    PerfStats.screen = [
      route,
      if (route.startsWith('/library')) 'tab=$tab',
      if (nowPlaying) 'nowPlaying(viz=$viz lyrics=${lyrics ? 'on' : 'off'}${idle ? ' idle' : ''})',
      if (queue) 'queue',
    ].join(' ');
  }

  final router = ref.read(routerProvider);
  void onRoute() {
    final next = router.routerDelegate.currentConfiguration.uri.toString();
    if (next == route) return;
    route = next;
    perfNote('PAGE $route');
    update();
  }

  router.routerDelegate.addListener(onRoute);
  ref.onDispose(() => router.routerDelegate.removeListener(onRoute));
  onRoute();

  ref.listen(libraryTabProvider, (_, t) {
    if (tab == 'songs' && PerfStats.songsTabCovers.isNotEmpty) {
      perfNote('covers distinctIds=${PerfStats.songsTabCovers.length} (Songs tab, final)');
    }
    PerfStats.songsTabCovers.clear();
    tab = t.name;
    perfNote('TAB $tab');
    update();
  });
  ref.listen(nowPlayingOpenProvider, (_, open) {
    nowPlaying = open;
    perfNote(open ? 'NOW PLAYING open' : 'NOW PLAYING closed');
    update();
  });
  ref.listen(idleProvider, (_, on) {
    idle = on;
    perfNote(on ? 'IDLE on' : 'IDLE off');
    update();
  });
  ref.listen(lyricsOnProvider, (_, on) {
    lyrics = on;
    perfNote('LYRICS ${on ? 'on' : 'off'}');
    update();
  });
  ref.listen(vizModeProvider, (_, m) {
    viz = m.name;
    perfNote('VISUALIZER $viz');
    update();
  });
  ref.listen(queueOpenProvider, (_, open) {
    queue = open;
    perfNote('QUEUE ${open ? 'open' : 'closed'}');
    update();
  });
  ref.listen(currentTrackIdProvider, (_, id) => perfNote('TRACK $id'));
  ref.listen(schemeSeedProvider, (_, _) {
    PerfStats.recolorStarted();
    perfNote('RECOLOR start (800 ms)');
  });
  update();
});
