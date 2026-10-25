# Tidewater milestones

Where the project stands and what each remaining milestone must cover. Companion to `CLAUDE.md` (which stays the
source of truth for design and behavior); this file is the working plan.

Legend: ✅ done · 🟡 done against **fake/simulated** data, needs the real thing · ⬜ not started

## Milestone 1 wrap-up (done)

Window chrome, theme + motion tokens, rail, header, mini player, FAB, Home and Library, delivered, then taken well
past the original "static" scope to demo parity with a simulated player (recolor, morph shapes, card behaviors,
Now Playing with lyrics/volume/idle/visualizers, Settings). Quality at wrap-up: `flutter analyze` clean, 44 tests
passing, `flutter build windows --release` succeeds, zero console errors on launch, no frame over 33 ms in the
profile scenarios (`tool/perf_main.dart`). Working notes for future sessions: `docs/dev-notes.md`.

## Milestone 2 wrap-up (done)

The app now runs on a real Navidrome/OpenSubsonic server: login (password or API key, secrets in Windows secure
storage), a dio client written from scratch (`core/api/`), cover art with a disk cache, scheme colors from real
cover pixels, and a Home and Library built from server data with loading, error and empty states. Playback is
**still simulated** (clock only), but it now plays real tracks from real queues.

Checked against a live server: Navidrome 0.64.2 (the public demo) via `tool/server_check.dart` (auth, artists,
playlists, paging, album detail with quality info, covers at 300/800, search, random songs) and 40 real covers via
`tool/real_covers_test.dart` (0 contrast failures in dark and light; black/white/gray art gets a neutral scheme).
`flutter_secure_storage` round-trips on this machine (`tool/session_probe_main.dart`). Quality at wrap-up:
`flutter analyze` clean, 112 tests passing, Windows build and launch clean. **Also checked against the user's own server (Navidrome 0.64.2, 518 albums, 313 artists):** all albums load in two pages in about 0.6 s,
119 covers gave 0 contrast failures. Still untested: a library with many thousands of albums.

Next up is **M3 (Playback)**.

## Where we are

The original plan was shell → server → playback → color/shapes → Now Playing → polish. We deliberately built
**demo parity first** with a simulated player, so milestones 1, 4 and 5 are largely done in look and behavior,
but everything they sit on is fake. The remaining milestones are mostly *replacing the fakes* and adding the
pages that don't exist yet.

| # | Milestone | Status |
|---|-----------|--------|
| 1 | Shell | ✅ |
| 2 | Server (login, OpenSubsonic, real library, cover cache) | ✅ (search/artist pages come later) |
| 3 | Playback (real engine, queue, SMTC, scrobbling, album page) | ⬜ (UI 🟡 via `SimulatedEngine`) |
| 4 | Dynamic color + shapes | 🟡 (works, seeded from real covers; light-theme QA outstanding) |
| 5 | Now Playing | 🟡 (works, simulated audio/visualizer/lyrics) |
| 6 | Motion polish pass | 🟡 (most of the demo list is in; QA pass outstanding) |
| 7 | Search, playlists, offline cache, settings, real visualizer | ⬜ (Settings partly ✅) |

## What is simulated or stubbed today

Replace these as the milestones below land. Each is a known, deliberate stand-in.

| Stand-in | Where | Replaced in |
|----------|-------|-------------|
| `SimulatedEngine` (clock only, no audio); it plays real tracks from the server but makes no sound | `core/playback/simulated_engine.dart` | M3 |
| Fake synced lyrics (the same for every track) | `placeholderLyrics` in `core/lyrics/placeholder_lyrics.dart` | M3 |
| `SimulatedVisualizerSource` (time-based, not from audio) | `core/playback/visualizer_source.dart` | M7 |
| "Synced lyrics" tag follows the placeholder lyrics, not the track | `now_playing_overlay.dart` | M3 |
| Volume, shuffle, repeat only change in-memory state | `SimulatedEngine` | M3 |
| Liked tracks live in memory only (not read from or sent to the server) | `likedProvider` | M3 (`star`/`unstar`) |
| No-op controls: menu button, search field, cast, queue button | various | M3/M7 |
| Home chips Albums/Artists/Playlists only switch which rows show; Library has no Songs or Genres tab | `home_page.dart`, `library_page.dart` | M7 |
| Artist and playlist cards **play** on tap (artist = first 12 albums); there is no artist, album or playlist page | `playback_providers.dart` | M3 (album page), M7 |

(Replaced in M2: fake library, gradient-seeded scheme, list-index coupling, hard-coded Home/Library text, the
account initial, sort, genre filter, "Show all", the A–Z rail.)

## M2 — Server (done)

What was built, and the decisions that were not in the plan:

- **Login** (`ui/pages/login_page.dart`, `core/api/connect.dart`): server address, then password or API key. An
  address without a scheme is tried as https then http. Errors are specific (bad address, unreachable, certificate,
  wrong credentials, no API-key support); a rejected certificate offers **Trust this server** (accepts that host's
  certificate only, saved with the session). The saved server is trusted at launch without a ping, so starting
  offline opens the app and its lists show offline states.
- **Secrets**: password/API key in `flutter_secure_storage`; URL, user name, auth mode in `shared_preferences`
  (`app/session/prefs_session_store.dart`). Signing out drops the secret and remembers URL + user to prefill.
- **Client** (`core/api/opensubsonic_client.dart`): token auth with a fresh salt per request, or `apiKey`. Added
  `getRandomSongs` (Shuffle all) to the endpoint list. Fixtures are in `test/fixtures/`.
- **Everything keyed by id**: `Album`/`Track`/`Artist`/`Playlist` carry server ids; the engine takes a queue
  (`playQueue`), cards call `playAlbum` / `playPlaylist` / `playArtist`. Shapes come from the album id
  (`ShapeKind.forKey`), so an album keeps its shape everywhere.
- **Covers** (`core/api/cover_cache.dart`, `ui/widgets/cover_art.dart`): sizes snap to 150/300/800, files are
  `<cache>/<server hash>/<id>_<size>.img`, concurrent requests share one download, the placeholder gradient (hue from
  the album id) shows until the image fades in. The cache is trimmed to 500 MB (least recently used first) when the session starts.
- **Scheme from the cover** (`core/color/cover_seed.dart`, `app/providers/scheme_providers.dart`): Celebi quantizer
  + `Score` on a 112 px decode, run on another isolate. Art with no color (black, white, gray) gives a *muted*
  seed → `DynamicSchemeVariant.neutral`, instead of a random hue. The app only recolors once the new seed is known
  (never default → placeholder → real). Cover failures fall back to a hue from the album id.
- **Home**: greeting from the local hour; heroes = recently played topped up with newest; Quick picks = most played;
  rows for Recently added / Most played; chips switch All / Albums / Artists / Playlists.
- **Library**: Albums, Artists, Playlists tabs. Albums load page by page (120, then 500 at a time) until the server
  runs out; the grid is lazy. Sorts are server-side (recently added, name, artist, most played, recently played,
  year newest-first, verified descending on a real server). Genre filter is client-side over what is loaded. The A–Z
  rail only shows for alphabetical sorts and the Artists tab and skips articles ("The Beatles" files under B).
- **Mini player is hidden until something is queued** (decision; the old "resting first track" is gone). It rises
  in the first time it appears. Failed play requests show a toast (`ui/shell/toast_layer.dart`).
- **Account menu**: avatar shows the user's initial; menu offers sign out / switch server (stops playback first).

Known gaps / follow-ups:

- Not tested against a library with thousands of albums yet. Things to watch: Library paging time, memory of the
  metadata list, `getArtists` size, cover cache growth.
- API-key login is unit-tested but not tried against a server that advertises `apiKeyAuthentication` (the demo does
  not).
- Pull-to-refresh / automatic refresh of Home after playing: Home rows refresh only when invalidated (Retry) or on
  restart. Invalidate `recent`/`frequent` when scrobbling lands (M3).
- Library "Songs" and "Genres" tabs, and the Home chips beyond filtering rows, are M7.

## M3 — Playback

- `PlaybackEngine` implementation on `media_kit` (+ `media_kit_libs_windows_audio`), wrapped so no media_kit types
  leak; `SimulatedEngine` stays as the test/demo implementation.
- Queue model: play next, add to queue, reorder, shuffle, repeat (off/all/one); gapless. Wire the Now Playing
  queue button (currently a no-op).
- Volume, mute, seek, previous-restarts-track behavior against the real engine.
- Position reporting: real engines report coarsely. `WavyScrubber` already extrapolates between reports and
  ignores small backwards corrections; verify with the real engine and apply the same smoothing to time labels.
- SMTC / media keys / taskbar (`smtc_windows`), metadata + cover art.
- Scrobbling: "now playing" at start, `submission=true` at 50 % or 4 minutes. Unit-test the rule.
- Album page (and artist page): header, track list, play/shuffle, star.
- Lyrics: `getLyricsBySongId` (when `songLyrics` advertised), LRCLIB fallback, plain-vs-synced handling (the
  list already supports both; plain lyrics never auto-scroll).
- Quality tag: it shows the file's own format from the server metadata (`Track.qualityLabel`); once playing, show what the
  engine reports (transcoded vs. original).
- `star`/`unstar` for the heart; persist liked state; keep the pop + particle burst.
- Restore last queue/position on launch.

## M4 — Dynamic color + shapes (remaining)

Built: animated scheme per album (~800 ms), `MorphShape` (spring, spin, no-overshoot reduced motion), card hover
morph/lift/tilt, wavy progress.

- Real-cover seeding (see M2).
- Light theme visual QA: never reviewed. Check every surface, the visualizers (alpha tuned for dark), the halo and
  contrast in light.
- Recolor cost: the whole tree rebuilds each frame for ~800 ms (build p90 ≈ 6.7 ms in profile on track skips).
  Fine today; revisit if screens get heavier (e.g. scope the animated scheme to color-reading subtrees).
- Cache schemes persistently if extraction proves slow on large libraries.

## M5 — Now Playing (remaining)

Built: overlay with hero flight, lyrics list, lyrics toggle, volume slider, idle mode, visualizer styles + picker,
heart burst, track-change choreography, `V`/`L`/`Esc`/`Space`/`N`/`P`.

- Queue panel behind the top-bar queue button; cast button is a no-op.
- Check layout at the window minimum (720×520) and at ultrawide: the design is a 1280×800 canvas scaled to fit.
- Verify the hero flight when the mini player is at different widths / the rail is compact.
- Idle mode edge cases with real playback: buffering, track end, pause/resume, window deactivation.
- Keyboard focus handling: global `Space` shouldn't also activate a focused button; add visible focus styling.

## M6 — Motion polish pass

Most of the demo list is in. Remaining and review items:

- Walk `CLAUDE.md` "Behaviors" 1–16 against the demo side by side and tick each off (hover/press, ripples,
  stagger, letter reveals, wash, ambient, heart, track change).
- Tune the track-change feel. Settings has a **Track change speed** slider (0.5×–3×); once you settle on a value,
  make it the default (currently 1×: 260 ms exit / 520 ms entrance per letter).
- Pause the visualizer when Now Playing is hidden or the window is minimized (done for minimize via lifecycle;
  confirm on a real minimize).
- Reduced motion audit: every new animation must honor `MediaQuery.disableAnimations` (no spin, overshoot, wash,
  letter motion).
- Consider fading the Aurora behind pages when paused for a long time (idle GPU use).

## M7 — Search, playlists, offline, settings, real visualizer

- Search page (`search3`): artists/albums/songs, recent searches, keyboard-first; wire the header search pill.
- Playlists: list, detail, create/edit, add-to-playlist from context menus, reorder.
- Artists, Lists, Radio pages (currently placeholders) and Library tabs (Artists, Songs, Playlists, Genres).
- Offline cache: download albums/playlists, cache management (size, clear), offline mode.
- Settings expansion: server/account, cache, scrobbling toggle, ReplayGain, audio output device, crossfade/gapless,
  visualizer frame cap, startup page. (Done: reduce motion, dark/light, visualizer style, track change speed.)
- **Real visualizer**: replace `SimulatedVisualizerSource` with FFT data (options: decode a parallel stream with
  FFmpeg, `flutter_soloud`, or a native audio tap). Same `VisualizerSource` interface; keep the 64-band,
  fast-attack/slow-decay smoothing. Say so in the UI until it ships.
- Context menus (right click), drag and drop, multi-select.

## Cross-cutting

**Quality gates (every milestone):** `flutter analyze` clean, `flutter test` passing, ≤ 5-line summary, small
reviewable commits, ask before adding packages not listed in `CLAUDE.md`.

**Performance:** measure in `--profile`, never debug (debug is several times slower and makes animations look
janky). Current profile baseline (60 Hz, this machine): build ≈ 1 ms, raster ≈ 5–6 ms; worst phase is track skips
(recolor) at build p90 ≈ 6.7 ms. Budget: no frames > 33 ms in any scenario.

**Accessibility:**
- Animated text must be hidden from semantics behind one stable label (per-letter nodes caused hundreds of
  `AXTree` errors per launch; fixed for letter animations and decorative layers).
- Audit the rest for per-frame semantics churn (cards under tilt, hero carousel resizing).
- Keyboard navigation and visible focus for every control; Narrator pass; check contrast in light theme.

**Windows / packaging:**
- `flutter build windows --release` check, app icon, window title, installer (MSIX), single-instance.
- Roboto Flex packaging (variable weight/width) if licensing allows; fall back to Roboto.
- Rounded window corners when maximized/snapped; high-DPI (125–200 %) pass; multi-monitor.
- Confirm Impeller/GL behavior on other GPUs.

**Testing & tooling:**
- `test/` — unit + widget tests (keep adding with each feature).
- `tool/render_shots_test.dart` — offscreen screenshots of the main screens to `build/shots/` (works with the
  desktop locked): `flutter test tool/render_shots_test.dart`.
- `tool/perf_main.dart` — per-phase frame build/raster times through the heavy scenarios:
  `flutter run -d windows --profile -t tool/perf_main.dart`.
- `tool/letter_probe_main.dart` — pixel-level measurement of how smoothly the engine renders animated letters
  (jitter in px, plus a landing/start "pop" metric): `flutter run -d windows --profile -t tool/letter_probe_main.dart`.
  Lessons learned, all measured in the real engine (Impeller/GL):
  - Don't round animated transforms to whole pixels: ~10× *more* jitter.
  - Use `PreciseCubic` (`app/theme/precise_cubic.dart`) for easings, not Flutter's `Cubic`: its 0.001 bisection
    tolerance adds up to ~0.17 px of per-frame noise on a 58 px title. All `Motion` curves use it.
  - Never swap an animating widget for a transform-free one when it lands/leaves: the engine draws the two
    slightly differently and the swap shows as a pop (2.8× the previous frame's change).
  - **Animate text as textures, like a browser does** (`ui/widgets/effects/glyph_run.dart`). Re-drawing glyph
    outlines each frame at fractional positions makes stems shimmer (ink varied 0.5–0.7 % frame to frame) even when
    positions are exact. Bake glyphs once into an atlas and draw all letters with one `drawRawAtlas` (per-sprite
    transform and color): position jitter 0.070 → 0.006 px, ink shimmer 0.46 → 0.06 %. Per-glyph `drawImageRect`
    with a color filter was NOT acceptable: it made the GPU do an off-screen pass per glyph per frame and
    stalled raster (40 ms frames) while the theme recolored. Use `GlyphRun` for any future animated headline.
  - When porting CSS transitions, port them literally (`ui/now_playing/lyrics_motion.dart`): each property with its
    own duration and curve (lyrics: opacity/blur .8 s, scale/slide .9 s, color .6 s default `ease`), retargeting
    from the value currently shown, fixed anchors instead of measuring. Never swap widget structure while an
    animation is running (a blur wrapper that appeared/disappeared reset the line's scale and color animations,
    which read as jumps). Scaled/slid text is baked to textures too (`LyricsList`).
- Add golden tests for key screens once the design settles; add an integration test for login → play.
- CI: analyze + test on every push.

## Open decisions

- Keep `go_router` page transitions as fade + 14 px rise, or move to shared-axis for deeper pages (album/artist)?
- Menu button (top of rail): expand/collapse the rail with labels, or open a drawer?
- Where do "Daily Mix" style generated playlists come from on a Navidrome server (smart playlists vs. none)?
- Real "Radio" source: Navidrome internet radio stations only, or also similar-artist radio?
