# Flutter Architecture Map: Tidewater

## 1. Architecture & State Structure

### Architectural Pattern
Tidewater follows a **Layered Clean Architecture** that enforces a strict unidirectional dependency rule:
- **Presentation Layer (`lib/ui/`)**: Divided into `shell/` (desktop chrome, navigation, mini player, overlays), `pages/` (routes/screens), `now_playing/` (fullscreen player, visualizers, synchronized lyrics), and `widgets/` (expressive UI design system, custom shapes, physics effects).
- **Application & State Orchestration Layer (`lib/app/`)**: Coordinates routing ([`createRouter`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/router.dart#L15-L105) with `go_router`), dynamic Material 3 color generation ([`AlbumScheme`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/theme/album_scheme.dart#L15-L56)), native Windows window management (`window_manager`), and Riverpod state controllers (`lib/app/providers/`).
- **Core / Domain & Data Layer (`lib/core/`)**: Pure Dart layer intentionally decoupled from Flutter UI imports (`flutter/material.dart` is prohibited in `core/` to ensure isolated unit testability). Encapsulates Subsonic API client communication ([`OpenSubsonicClient`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/api/opensubsonic_client.dart#L24-L433)), audio playback engine contracts ([`PlaybackEngine`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/playback/playback_engine.dart#L15-L88)), queue management ([`QueueEngine`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/playback/queue_engine.dart#L15-L418)), data models, in-memory search indexing ([`LibraryIndex`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/search/library_index.dart#L36-L224)), and LRC parser utilities ([`LrcParser`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/lyrics/lrc_parser.dart#L10-L39)).

### State Management Solution
- **Driver**: **Flutter Riverpod (v3.4.3)**.
- **Provider Types**:
  - `Notifier` / `NotifierProvider` (e.g., [`PlaybackController`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/playback_providers.dart#L29-L150) for playback state, [`RecentSearchesNotifier`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/search_providers.dart#L25-L48)).
  - `AsyncNotifier` / `AsyncNotifierProvider` & `FutureProvider` (e.g., [`libraryAlbumsProvider`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/library_providers.dart#L50-L120), [`searchResultsProvider`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/search_providers.dart#L13-L21)).
  - Pure `Provider` with lifecycle disposal (`ref.onDispose`) for engine backends ([`playbackEngineProvider`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/playback_providers.dart#L23-L27), [`scrobbleServiceProvider`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/scrobble_providers.dart#L16-L67), [`sessionPersistenceProvider`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/session_persistence.dart#L58-L328)).
- **Event Streaming**: Dart `StreamController.broadcast` inside playback engines ([`MediaKitBackend`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/playback/media_kit_backend.dart#L46-L51), [`SimulatedEngine`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/playback/simulated_engine.dart#L20-L50)), piped into Riverpod state streams and consumed via `ref.watch` or `ref.listen`.
- **Local Ephemeral State**: `ChangeNotifier` / `ValueNotifier` for micro-animations, pointer positions, and frame-rate optimization toggles ([`PerfFlags`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/perf_flags.dart#L6-L55)).

---

## 2. File Topology & Bloat

### Overview of `lib/` Directory
```text
lib/
├── main.dart                                   # Desktop entrypoint, window initialization, singletons
├── app/
│   ├── app.dart                                # MaterialApp.router, dynamic theme tween, frameless window resize
│   ├── router.dart                             # GoRouter routes (Home, Library, Album, Artist, Search, etc.)
│   ├── destinations.dart                       # Top-level shell navigation definitions
│   ├── perf_flags.dart                         # Runtime performance toggles for profiling/benchmarking
│   ├── frame_log.dart                          # Frame duration profiling logger
│   ├── image_cache_config.dart                 # ImageCache memory limits
│   ├── playback/                               # Real media_kit backend (libmpv) & Windows SMTC controls
│   ├── providers/                              # Riverpod controllers (playback, library, session, lyrics, etc.)
│   ├── session/                                # SharedPreferences session store implementation
│   └── theme/                                  # Material 3 Expressive theme, motion tokens, spring physics
├── core/                                       # Pure Dart domain & logic (no Flutter UI dependencies)
│   ├── api/                                    # OpenSubsonic client, CoverCache, ListCache, ServerConfig
│   ├── color/                                  # Celebi/Quantizer image seed extraction
│   ├── lyrics/                                 # LRC format parser, structured lyrics models, LRCLIB client
│   ├── models/                                 # Data models (Album, Track, Artist, Playlist, RadioStation)
│   ├── playback/                               # Queue engine, scrobble tracker, resume logic, audio abstractions
│   ├── search/                                 # Fast in-memory normalized search index
│   └── text/                                   # CJK and Japanese Han script classification utilities
└── ui/                                         # Presentation layer
    ├── shell/                                  # Window frame, NavigationRail, mini player, toast notifications
    ├── pages/                                  # Screens (Home, Library, Album, Artist, Playlist, Radio, Settings)
    │   └── widgets/                            # Screen-specific widgets (AlbumCard, SongRow, GenrePicker, Header)
    ├── now_playing/                            # Fullscreen overlay, visualizers, lyrics list, queue panel
    │   └── visualizer/                         # CustomPainter visualizers (Aurora, Shapes, Bars, Ring)
    └── widgets/                                # Reusable M3 expressive components, custom shapes, particle effects
        ├── effects/                            # Ripple, letter reveal, particle burst, eq bars, glyph runs
        └── shapes/                             # 120-point MorphPath and MorphShape spring algorithms
```

### Files Exceeding 300 Lines (22 Files)
| File | Lines | Responsibility |
|---|---|---|
| [lib/ui/now_playing/now_playing_overlay.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/now_playing_overlay.dart) | 1,184 | Fullscreen player overlay, FLIP cover hero flight, idle mode detection, visualizer backdrop |
| [lib/ui/pages/library_page.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/library_page.dart) | 921 | Multi-tab library view (Albums, Artists, Songs, Genres), custom scroll synchronization |
| [lib/ui/pages/widgets/album_card.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/widgets/album_card.dart) | 878 | Album/Media cards, 3D cursor tilt, hover morph, manual raster sprite baking queue (`_BakeQueue`) |
| [lib/ui/pages/home_page.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/home_page.dart) | 869 | Home dashboard with hero carousel, horizontal media shelves, letter-by-letter heading reveals |
| [lib/ui/pages/settings_page.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/settings_page.dart) | 601 | Application preferences, audio device settings, visualizer config, server diagnostics |
| [lib/ui/widgets/animated_glyphs.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/animated_glyphs.dart) | 584 | Code-drawn animated vector glyphs and morphing SVG paths |
| [lib/ui/widgets/wavy_progress.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/wavy_progress.dart) | 565 | Interactive sine-wave playback scrubber with spring damping and drag handles |
| [lib/ui/pages/login_page.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/login_page.dart) | 511 | Server connection form, TLS/SSL certificate trust dialogs, authentication flows |
| [lib/ui/pages/album_page.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/album_page.dart) | 500 | Album detail view, tracklist presentation, disc groupings, artist discography shelf |
| [lib/ui/now_playing/queue_panel.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/queue_panel.dart) | 499 | Dockable/floating playback queue panel with multi-select and drag reordering |
| [lib/ui/pages/playlist_page.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/playlist_page.dart) | 448 | Playlist detail, track management, reordering, inline editing |
| [lib/ui/pages/widgets/genre_picker.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/widgets/genre_picker.dart) | 438 | Genre selection sheet, search filter, tag chips |
| [lib/core/api/opensubsonic_client.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/api/opensubsonic_client.dart) | 433 | Core Subsonic REST API networking, salt hashing, request dispatch, payload deserialization |
| [lib/ui/widgets/effects/glyph_run.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/effects/glyph_run.dart) | 420 | Custom RenderObject and text measurement layout for animated character sequences |
| [lib/core/playback/queue_engine.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/playback/queue_engine.dart) | 418 | Queue state machine, shuffle logic, repeat cycles, play-next/play-later queues |
| [lib/ui/widgets/expressive_buttons.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/expressive_buttons.dart) | 371 | Material 3 expressive pill-to-rounded-rect morphing buttons and button groups |
| [lib/ui/widgets/playlist_flow.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/playlist_flow.dart) | 369 | Playlist creation dialog, quick-add flows, track selection checklists |
| [lib/ui/shell/shell_effects.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/shell/shell_effects.dart) | 367 | Ambient background shapes, mouse spotlight tracking, low-fps background drift |
| [lib/ui/now_playing/lyrics_list.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/lyrics_list.dart) | 367 | Synchronized lyrics engine with texture-baked line cache (`ui.Image`) and CSS spring transitions |
| [lib/app/providers/session_persistence.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/session_persistence.dart) | 350 | Local disk & server `savePlayQueue` synchronization, window close hooks |
| [lib/ui/pages/widgets/app_header.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/widgets/app_header.dart) | 347 | Global search bar, autosuggest popup, user avatar menu, navigation history controls |
| [lib/ui/pages/radio_page.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/radio_page.dart) | 313 | Internet radio station browser, custom stream input dialog, station grids |

### Flagged Widgets Containing Massive or Deeply Nested `build()` Methods
1. **[`_NowPlayingOverlayState.build`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/now_playing_overlay.dart#L325-L386) & [`_design`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/now_playing_overlay.dart#L388-L620)**:
   - Over **550 lines** of combined widget construction in a single state class.
   - Deeply nested hierarchy: `FadeTransition` -> `MouseRegion` -> `Listener` -> `Stack` -> `AnimatedPadding` -> `FittedBox` -> `SizedBox` -> `BurstLayer` -> `_design` -> `Positioned` / `AnimatedPositioned` -> nested column layouts, custom spring shapes, and audio transport controls.
2. **[`_LibraryPageState.build`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/library_page.dart#L105-L326)**:
   - Over **220 lines** in `build()`, plus massive internal sub-builders (`_albumsTab` [L517-578](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/library_page.dart#L517-L578), `_songsTab` [L580-642](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/library_page.dart#L580-L642), `_artistsTab` [L661-774](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/library_page.dart#L661-L774)).
   - Nests `CustomScrollView`, multiple dynamic sliver grids/lists, tab bars, filter dropdowns, and search delegates directly inside one monolith.
3. **[`SongRow.build`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/widgets/song_row.dart#L60-L270)**:
   - **210 lines** in a single row widget's `build()` method. Contains complex multi-state conditional logic (hover, selected, playing, drag target, context menu, heart button, animated equalizer indicators).
4. **[`_QueuePanelState.build`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/queue_panel.dart#L60-L265)**:
   - **205 lines** in `build()`. Combines `ExcludeSemantics`, `IgnorePointer`, `AnimatedScale`, `AnimatedContainer`, header controls, and a full `ReorderableListView.builder`.
5. **[`_AlbumPageState.build`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/album_page.dart#L139-L316)**:
   - **177 lines** in `build()`. Deeply embeds header hero cover art, animated action chips, disc subheaders, and sequential song rows inside a single `SingleChildScrollView`.

---

## 3. Data & Computation Layer

### Network Calls
- **[lib/core/api/opensubsonic_client.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/api/opensubsonic_client.dart)**:
  - Central HTTP transport backed by `dio: ^5.11.1`.
  - Implements the Subsonic/OpenSubsonic protocol with MD5 salt hashing (`u, t, s, v=1.16.1, c=Tidewater, f=json`).
  - Endpoints called: `ping`, `getOpenSubsonicExtensions`, `getAlbumList2`, `getAlbum`, `getArtists`, `getArtist`, `getPlaylists`, `getPlaylist`, `search3`, `getSongsByGenre`, `getStarred2`, `scrobble`, `star`/`unstar`, `getLyricsBySongId`, `savePlayQueue`, `getPlayQueue`.
- **[lib/core/lyrics/lrclib.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/lyrics/lrclib.dart)**:
  - Uses `Dio` to query public LRCLIB API endpoints (`https://lrclib.net/api/get`) as a fallback when the server does not support the OpenSubsonic `songLyrics` extension.
- **[lib/core/api/cover_cache.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/api/cover_cache.dart)**:
  - Downloads remote album art images and persists them to local storage via `Dio.download`.

### JSON Serialization & Data Mapping
- **Hand-written Plain Dart Deserialization**:
  - The project does **not** use `freezed` or `json_serializable`. All models use manual `fromJson` and `toJson` factory patterns.
  - Key mapping files:
    - [lib/core/models/album.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/models/album.dart#L18-L45) (`Album.fromJson`)
    - [lib/core/models/track.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/models/track.dart#L24-L64) (`Track.fromJson`, `toJson`)
    - [lib/core/models/artist.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/models/artist.dart#L12-L34) (`Artist.fromJson`, `ArtistWithAlbums.fromJson`)
    - [lib/core/models/playlist.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/models/playlist.dart#L15-L55) (`Playlist.fromJson`)
    - [lib/core/models/radio_station.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/models/radio_station.dart#L11-L25) (`RadioStation.fromJson`, `toJson`)
    - [lib/core/models/server_play_queue.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/models/server_play_queue.dart#L10-L24) (`ServerPlayQueue.fromJson`)
    - [lib/core/playback/saved_session.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/playback/saved_session.dart#L15-L77) (`SavedSession.fromJson`, `toJson`)
    - [lib/core/models/json_util.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/models/json_util.dart#L1-L21) (`toInt`, `toStr`, `toBool`, `toList` type-coercion helpers)

### Heavy Computation Tasks
- **In-Memory Search Indexing ([lib/core/search/library_index.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/search/library_index.dart#L36-L100))**: Full normalization (accent folding, case stripping, width normalization) and ranking across thousands of cached artists, albums, and tracks.
- **Palette Quantization ([lib/core/color/cover_seed.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/color/cover_seed.dart#L1-L66))**: Color extraction using `material_color_utilities` (`QuantizerCelebi` and `Score.score`).
- **Synchronized Lyrics Parsing ([lib/core/lyrics/lrc_parser.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/lyrics/lrc_parser.dart#L10-L39))**: Timestamp regex parsing and line segmentation.

### Utilization of `compute()` vs. `Isolate`
- **`compute()`**: **0 occurrences** across the entire project. Flutter's `compute()` is never used.
- **`Isolate.run()`**: Used in **exactly 2 specific locations**:
  1. [lib/app/providers/cover_providers.dart:L67](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/cover_providers.dart#L67): Runs Celebi color quantization in a background isolate: `await Isolate.run(() => seedFromPixels(pixels))`.
  2. [lib/core/api/list_cache.dart:L39 & L52](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/api/list_cache.dart#L39-L53): Reads and writes disk JSON caches using `Isolate.run` for `jsonDecode` / `jsonEncode`.
- **Finding**: **All Subsonic API network parsing and `LibraryIndex` generation run directly on the main UI Isolate.** Large payloads (e.g., thousands of tracks or extensive search query matches) parse synchronously on the main thread.

---

## 4. UI Complexity

### Unbounded Lists & Heavy Scroll Views
- **Non-Lazy Unbounded Lists**:
  - [lib/ui/now_playing/lyrics_list.dart:L349](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/lyrics_list.dart#L349): `_PlainList` uses `ListView(children: [for (final l in lyrics.lines) ...])`, creating all lyric widgets upfront instead of recycling via `ListView.builder`.
  - [lib/ui/widgets/playlist_flow.dart:L179](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/playlist_flow.dart#L179): Uses `ListView(children: ...)` for playlist picking dialog items.
- **Heavy Scroll Views (`CustomScrollView`, Slivers, Deep Views)**:
  - [lib/ui/pages/library_page.dart:L193](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/library_page.dart#L193): `CustomScrollView` with multiple concurrent slivers (`SliverGrid.builder`, `SliverList.builder`) for large media catalogs.
  - [lib/ui/pages/liked_page.dart:L46](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/liked_page.dart#L46): `CustomScrollView` toggling between a multi-hundred song `SliverList.builder` and `SliverGrid.builder`.
  - [lib/ui/pages/artists_page.dart:L68](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/artists_page.dart#L68): `CustomScrollView` with responsive grid layouts.
  - [lib/ui/pages/radio_page.dart:L33](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/radio_page.dart#L33) & [lib/ui/pages/lists_page.dart:L36](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/lists_page.dart#L36): `CustomScrollView` with sliver grids.
  - [lib/ui/pages/home_page.dart:L172 & L318](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/home_page.dart#L172-L318): Nested scrolling containing an outer `SingleChildScrollView` and multiple horizontal `ListView.separated` shelves.
  - [lib/ui/pages/album_page.dart:L72](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/album_page.dart#L72): `SingleChildScrollView` rendering full-length discographies and album tracks without sliver virtualization.
  - [lib/ui/now_playing/queue_panel.dart:L224](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/queue_panel.dart#L224): `ReorderableListView.builder` for the active play queue.
  - [lib/ui/widgets/smooth_scroll.dart:L33](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/smooth_scroll.dart#L33): Custom `SmoothScrollController` and `DeferringScrollPhysics` designed to hold back image decoding during high-velocity scrolling.

### Complex Animations & Custom Painters
- **Dynamic Background Visualizer ([lib/ui/now_playing/visualizer/visualizer.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/visualizer/visualizer.dart))**: 4 visualizer modes (Aurora, Shapes, Bars, Ring) rendered via `CustomPainter` and driven by continuous `Ticker` frames.
- **Continuous Ambient Background ([lib/ui/shell/shell_effects.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/shell/shell_effects.dart))**: Multi-blob procedural drift and mouse spotlight tracker.
- **Vector Path Morphing ([lib/ui/widgets/shapes/morph_shape.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/shapes/morph_shape.dart) & [morph_path.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/shapes/morph_path.dart))**: Interpolates 120 points between a 4.2-exponent superellipse and radial lobed curves with continuous spin and spring overshoot physics.
- **Wave Progress Indicator ([lib/ui/widgets/wavy_progress.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/wavy_progress.dart))**: Procedural sine-wave audio scrubber with amplitude breathing and spring physics.
- **Procedural Particle Simulator ([lib/ui/widgets/effects/particle_burst.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/effects/particle_burst.dart))**: Physics-driven 2D particle simulation for heart/like actions.
- **Texture-Backed Synced Lyrics ([lib/ui/now_playing/lyrics_list.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/lyrics_list.dart))**: Bakes rendered text lines into individual GPU `ui.Image` textures to prevent subpixel font shimmering during CSS-interpolated scale/blur animations.
- **Animated Glyphs ([lib/ui/widgets/animated_glyphs.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/animated_glyphs.dart))**: 584 lines of mathematical path metrics animations (`computeMetrics`).

### Media Rendering
- **libmpv Windows Backend ([lib/app/playback/media_kit_backend.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/playback/media_kit_backend.dart))**: Directly interfaces with `media_kit` native Windows audio binaries for gapless decoding and stream prefetching.
- **Windows System Media Transport Controls ([lib/app/playback/smtc_controls.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/playback/smtc_controls.dart))**: Bridges desktop OS media keys, taskbar thumbnails, and system lock screen notifications via `smtc_windows`.
- **Dynamic Cover Renderer ([lib/ui/widgets/cover_art.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/cover_art.dart))**: Manages multi-resolution image disk loading, hash placeholders, and cross-fade animations.

---

## 5. Lifecycle Management

### Stream Subscriptions & Listeners
- **[lib/app/playback/media_kit_backend.dart:L24-L39](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/playback/media_kit_backend.dart#L24-L39)**:
  - Manages 6 simultaneous event streams (`playing`, `position`, `buffering`, `playlist`, `completed`, `error`) and 6 broadcast `StreamController`s. Properly disposed in [`dispose()`](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/playback/media_kit_backend.dart#L168-L176).
- **[lib/app/playback/smtc_controls.dart:L30-L50](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/playback/smtc_controls.dart#L30-L50)**:
  - Manages SMTC button press event streams (`play`, `pause`, `next`, `previous`, `seek`). Cancelled on teardown.
- **[lib/app/providers/playback_providers.dart:L36-L37](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/playback_providers.dart#L36-L37)**:
  - Subscribes to playback engine state changes (`engine.states.listen`) with `ref.onDispose(sub.cancel)`.
- **[lib/app/providers/scrobble_providers.dart:L46-L54](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/scrobble_providers.dart#L46-L54)**:
  - Listens to playback position changes and engine track transitions with listener removal in `ref.onDispose`.

### Timers
- **[lib/ui/pages/widgets/album_card.dart:L273, L287-L288](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/widgets/album_card.dart#L273-L288)**:
  - Manages three timers per instance: `_popGone`, `_bakeTimer`, and `_giveUp`. Cancelled in `dispose()`.
- **[lib/ui/now_playing/now_playing_overlay.dart:L89-L90](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/now_playing_overlay.dart#L89-L90)**:
  - Manages `_idleTimer` (periodic 250ms tick checking user idle status) and `_swapTimer` (track text swap choreography). Cancelled in `dispose()`.
- **[lib/app/providers/session_persistence.dart:L61-L62, L307](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/providers/session_persistence.dart#L61-L62)**:
  - Uses `persistTimer`, `volumeDebounce`, and a periodic 30-second `ticker` to sync queue state with the server. Cancelled in `ref.onDispose`.
- **[lib/ui/shell/close_guard.dart:L30](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/shell/close_guard.dart#L30)**:
  - Debounce timer for window close events.
- **[lib/ui/pages/library_page.dart:L60, L78](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/library_page.dart#L60-L78)**:
  - Debounce timer `_swap` for tab switching animations.

### Controllers & Memory Leak Risks
- **`AnimationController` & `Ticker`s**:
  - [lib/ui/now_playing/now_playing_overlay.dart:L71-L82](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/now_playing_overlay.dart#L71-L82): Contains 3 `AnimationController`s (`_fade`, `_enter`, `_trackFx`).
  - [lib/ui/now_playing/lyrics_list.dart:L78](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/lyrics_list.dart#L78): Custom `Ticker` driven by `SingleTickerProviderStateMixin`.
  - [lib/ui/widgets/wavy_progress.dart:L60](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/wavy_progress.dart#L60): Ticker for sinusoidal motion.
  - [lib/ui/widgets/animated_glyphs.dart:L46](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/animated_glyphs.dart#L46): Multiple controllers for vector icon morphs.
- **`TextEditingController` & `FocusNode`s**:
  - [lib/ui/pages/login_page.dart:L31-L35](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/login_page.dart#L31-L35): 3 `TextEditingController`s (`_url`, `_user`, `_secret`) and 2 `FocusNode`s. Disposed in `dispose()`.
  - [lib/ui/pages/search_page.dart:L35-L36](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/search_page.dart#L35-L36): `TextEditingController` and `FocusNode`. Disposed in `dispose()`.
  - [lib/ui/pages/widgets/app_header.dart:L45](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/widgets/app_header.dart#L45): Global search input controller and focus node.
  - [lib/ui/pages/widgets/genre_picker.dart:L116](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/widgets/genre_picker.dart#L116): Genre filter controller.
  - [lib/ui/widgets/playlist_flow.dart:L43](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/widgets/playlist_flow.dart#L43): New playlist title input controller.
- **`ScrollController`s**:
  - [lib/ui/now_playing/queue_panel.dart:L39](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/queue_panel.dart#L39): `SmoothScrollController` for queue navigation.
  - [lib/ui/pages/library_page.dart:L44](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/library_page.dart#L44): Primary `ScrollController` for library grid jumping.
  - [lib/ui/pages/artists_page.dart:L42](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/artists_page.dart#L42): Artists grid scroll controller.

### Potential Memory Leak Risks
1. **GPU Texture Leak in Synchronized Lyrics ([lib/ui/now_playing/lyrics_list.dart:L109-L113](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/lyrics_list.dart#L109-L113))**:
   - Each lyric line is converted into a native `ui.Image` raster. While `_disposeImages()` is called during widget disposal, if the track changes rapidly or the widget fails to unmount cleanly, native raster textures can accumulate in VRAM.
2. **Global Hardware Keyboard Handlers ([lib/ui/shell/app_shell.dart:L67](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/shell/app_shell.dart#L67), [lib/ui/now_playing/now_playing_overlay.dart:L100](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/now_playing/now_playing_overlay.dart#L100))**:
   - `HardwareKeyboard.instance.addHandler` registers static callbacks. Any missed removal in edge-case unmounts leaks the enclosing state object.
3. **Repeated `ref.listen` Registrations in `build()`**:
   - In [lib/ui/pages/library_page.dart:L107](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/library_page.dart#L107), `ref.listen(libraryTabProvider, ...)` triggers tab transitions and timers. If parent rebuilds happen during animated state changes, overlapping timers (`_swap`) are scheduled.

---

## 6. Initial Anti-Patterns

### 1. Root-Level Rebuild Cascades via Animated `Theme` Injection
- **Location**: [lib/app/app.dart:L72-L80](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/app/app.dart#L72-L80)
- **Pattern**:
  ```dart
  TweenAnimationBuilder<ColorScheme>(
    tween: ColorSchemeTween(end: scheme),
    duration: reduced ? Duration.zero : Motion.recolor,
    curve: Curves.easeInOut,
    builder: (context, animated, child) => Theme(
      data: _themeMemo.of(animated, AppTheme.fromScheme),
      child: child!,
    ),
    child: ...,
  )
  ```
- **Bottleneck**:
  Whenever the active album changes, an 800ms tween animates between dynamic color palettes. At every tick (60 to 144+ fps), a newly generated `ThemeData` is passed to `Theme(data: ...)`, which updates the root `InheritedTheme`. Because `Theme.of(context)` is read throughout every leaf component in the app (cards, texts, navigation rail, buttons, background visualizers), **the entire widget hierarchy across the application is marked dirty and re-evaluated on every frame during the transition**, causing severe frame drops on desktop screens.

### 2. Main-Thread Heavy JSON Deserialization & Unthrottled In-Memory Indexing
- **Location**: [lib/core/api/opensubsonic_client.dart](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/api/opensubsonic_client.dart) & [lib/core/search/library_index.dart:L36-L60](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/core/search/library_index.dart#L36-L60)
- **Pattern**:
  - Subsonic JSON payload parsing (which often returns thousands of nested track and album entities) is executed synchronously on the main UI isolate inside Dio handlers.
  - `LibraryIndex` iterates over the entire library collection upon load, executing string normalization (`normalize`) and regex parsing directly on the UI thread without yielding or offloading to `compute()` or background isolates.
- **Bottleneck**:
  While `Isolate.run()` was introduced for color quantization and disk file caches, network deserialization and search indexing were left on the UI isolate, producing noticeable application hitches during library initial loads and large search queries.

### 3. Imperative Render Bypasses & Custom Offscreen Sprite Caching (`_BakeQueue`)
- **Location**: [lib/ui/pages/widgets/album_card.dart:L329-L350, L847-L877](file:///c:/Users/Josh/Documents/GitHub/tidewater/lib/ui/pages/widgets/album_card.dart#L329-L350)
- **Pattern**:
  ```dart
  final image = layer.toImageSync(
    Rect.fromLTWH(-_margin, -_margin, size.width + 2 * _margin, size.height + 2 * _margin),
    pixelRatio: MediaQuery.devicePixelRatioOf(context),
  );
  ```
- **Bottleneck**:
  Because each `MediaCard` was built with heavy multi-layer clipping (120-point squircle-to-flower shape morphs), 3D perspective transforms, blurred elevation shadows, and hover listeners, displaying grids with dozens of cards overwhelmed the Skia/Impeller raster thread. Instead of decomposing the widget into lightweight static components or using standard `RepaintBoundary` caches, the codebase created an imperative `_BakeQueue` that manually rasterizes cards into `ui.Image` sprites via `layer.toImageSync()` limited to 3 cards per frame. This introduces high complexity, manual image lifecycle management, and substantial memory overhead.
