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

## Milestone 4 wrap-up (done)

Most of M4 had already landed with the earlier milestones (scheme from real cover pixels, animated recolor,
`MorphShape`, card behaviors, wavy progress); what was left is done:

- **Light theme reviewed** (`flutter test tool/render_shots_test.dart --dart-define=TW_LIGHT=true` renders every main
  screen to `build/shots-light`): Home, Library, Now Playing (cover halo, lyrics card, volume, visualizer mountains),
  idle mode and login all read well; the contrast test already checks 4.5:1 for accent and body text in both
  brightnesses, including gray and black-and-white art. No fixes were needed. Known soft spot: tonal buttons (previous/next,
  FAB) and the progress track are pale on a pale background, which is how Material's light roles work.
- **Recolor cost**: the fade now moves in 40 steps (~50 Hz) and builds one `ThemeData` per step (`ColorSchemeTween`,
  `ThemeMemo`). Before, a 180 Hz display rebuilt the whole themed tree and a fresh `ThemeData` 144 times per recolor
  (build p90 4.7 ms, almost the entire 5.6 ms budget); now 2.1 ms, and track skips measure 5.6 ms p90 total.
- **Extracted colors are remembered** (`SeedStore`, in `shared_preferences`, up to 4000 covers, keyed by server and
  cover id): a cover is decoded and quantized once ever, so the next launch (and a restored queue) themes instantly
  with no cover download. Failed covers fall back to a color from the album id and are *not* remembered.
- Now Playing shows no lyrics button and no lyrics card for a track without lyrics (suggestion from the user).

Left for M7: the visual QA of the tonal-button contrast in light, and reduced-motion review of the stepped recolor
(it already respects `disableAnimations` by being instant).

## Milestone 3 wrap-up (done)

The app plays music for real. Audio comes from libmpv (`media_kit`) behind the `AudioBackend` interface; a
`QueueEngine` owns the queue, shuffle and repeat and keeps a two-item window (current + next) loaded so tracks join
gaplessly. Plays are reported to the server (now playing, then a counted play after half the track or 4 minutes),
the Windows media overlay and media keys work (`smtc_windows`), the last queue and position come back at launch,
hearts are real (`star`/`unstar`), lyrics come from the server (optionally lrclib.net), and there are album and artist
pages and a queue panel (drag to reorder, remove, jump). Quality at wrap-up: `flutter analyze` clean, 228 tests
passing, release build bundles `libmpv-2.dll` and `smtc_windows.dll` and starts.

Verified with the real thing, not just fakes (all against the user's own server):

- `tool/engine_probe_main.dart` (audible, quiet): play, pause, seek, **gapless hand-over** at the end of a track,
  next/previous, play next, shuffle, repeat-one, a missing track being reported and skipped, position reported 16
  times a second with at most an 89 ms gap.
- `tool/e2e_main.dart` + `tool/e2e_check.ps1`: Windows shows the playing track with its cover, and its media-key
  Pause/Play/Next/Previous drive the real engine.
- `tool/perf_real_main.dart` (profile, 180 Hz laptop panel, real covers/lyrics/engine): see "Performance" below.

Decisions and discoveries that were not in the plan:

- **Rust is now a build requirement** (`smtc_windows` compiles a Rust library). Install with `rustup`; a shell opened
  before the install needs `~/.cargo/bin` on its PATH. `flutter_rust_bridge` is pinned to 2.11.1 in
  `dependency_overrides` because the package's generated code refuses a newer runtime at startup.
- Windows ignores `file://` covers in the media overlay (silently); it needs an `https://` URL, so the overlay is given
  the server's cover URL (it carries the token, not the password).
- libmpv quirks handled in `MediaKitBackend`: it reports "completed" at the end of *every* file, reports a negative
  position while joining tracks, reports "not playing" for a moment at every track change (the engine waits 3 s
  before believing it), and skips a broken file by itself and reports the error *after* moving on (so the engine
  checks that something is really playing instead of guessing which track failed).
- A track that fails is retried once, then skipped; at the end of the queue playback stops.
- **Next always moves on** (even with repeat-one, even at the end of the queue); only a track ending by itself
  follows repeat. Previous restarts the track when more than 3 s in.
- Natural end of the queue (repeat off): rewinds to the first track, paused.
- Shuffle keeps the playing track first and shuffles the rest; turning it off restores the original order around
  the playing track. A shuffled lap that repeats is reshuffled.
- A restored queue is paused, shows no color wash, and is only restored for the server and user it was saved for.
- New settings: *Count plays on the server*, *Look up missing lyrics online* (lrclib.net; sends artist, title,
  album and length, so it is opt-out and visible).
- New keys: `M` mute (anywhere), `Q` queue (in Now Playing). Clicking the speaker also mutes.

Performance, measured on real data at 180 Hz (frame budget 5.6 ms; use `tool/run_perf_real.ps1`):

- Opening Now Playing, the queue panel and skipping tracks used to hitch 105-114 ms (first-time decode of the
  full-size cover). Covers for the playing and next two tracks are now decoded ahead of time
  (`cover_prefetch.dart`): those worst frames are now 9-26 ms.
- The placeholder gradient painted under every loaded cover cost ~10 ms of raster time per frame on a screenful of
  tiles. It is now dropped once the image is in. Library scrolling over cached covers went from p90 17.9 ms to 6.9 ms;
  Now Playing at rest from 5.7 to 4.2 ms median.
- Still heavy: scrolling the Library fast onto tiles that are *new* (p90 ~17 ms raster-bound). The remaining cost is
  the first draw of new cover textures. Ideas: smaller covers for fast scrolls, `cacheExtent` tuning (now two rows
  ahead), skipping the fade-in when scrolling fast.
- Measurements on this machine are noisy when another app is using the GPU (frame times 1.5-3x worse for no
  reason). Compare against the `startup` phase of the same run and repeat before trusting a regression.

Known gaps / follow-ups:

- The visualizer is still simulated (M8). The Now Playing quality tag shows the file's own format from the server, not
  what the engine decodes (matters once transcoding is used; there is no transcoding setting yet).
- The position is saved at pause, on queue changes and every 5 s, not on window close (up to 5 s lost on exit).
- Failed counted plays are retried for as long as the app runs, not across restarts.
- Hearts only exist for tracks; there is no starring of albums/artists from the UI yet.
- No ReplayGain, crossfade or audio-device choice (M8). No sleep timer.
- `Space` can still also activate a focused button (M6 item).
- Playlists have cards that play but no playlist page (M8).

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

Next up was **M3 (Playback)**, below.

## Where we are

The original plan was shell → server → playback → color/shapes → Now Playing → polish. We deliberately built
**demo parity first** with a simulated player, so milestones 1, 4 and 6 are largely done in look and behavior,
but everything they sit on is fake. The remaining milestones are mostly *replacing the fakes* and adding the
pages that don't exist yet.

| # | Milestone | Status |
|---|-----------|--------|
| 1 | Shell | ✅ |
| 2 | Server (login, OpenSubsonic, real library, cover cache) | ✅ (search/artist pages come later) |
| 3 | Playback (real engine, queue, SMTC, scrobbling, album page) | ✅ (gaps listed in the M3 section) |
| 4 | Dynamic color + shapes | ✅ |
| 5 | Animated icons (sidebar, buttons, transport) | 🟡 (see the M5 section) |
| 6 | Now Playing | 🟡 (real audio, lyrics and queue; the visualizer is still simulated) |
| 7 | Motion polish pass | 🟡 (most of the demo list is in; QA pass outstanding) |
| 8 | Search, playlists, offline cache, settings, real visualizer | ⬜ (Settings partly ✅) |
| 9 | Settings overhaul | ⬜ |

## What is simulated or stubbed today

Replace these as the milestones below land. Each is a known, deliberate stand-in.

| Stand-in | Where | Replaced in |
|----------|-------|-------------|
| `SimulatedVisualizerSource` (time-based, not from audio) | `core/playback/visualizer_source.dart` | M8 |
| `SimulatedEngine` is still the engine in tests, previews and the perf tools (the app itself uses libmpv) | `core/playback/simulated_engine.dart` | stays (test double) |
| No-op controls: menu button, search field, cast button | various | M8 |
| Library has no Genres tab (Songs, with its own sort and cards/list view, shipped after M4; the genre filter is a popup box with search, Ctrl+click for several) | `library_page.dart` | M8 |
| Only the Radio rail page is a placeholder (Artists, Liked and Lists are real pages; playlists open a playlist page) | `placeholder_page.dart` | M8 |
| The quality tag shows the file's own format from the server, not the engine's decoded format | `now_playing_overlay.dart` | M8 (with transcoding) |

(Replaced in M3: the simulated player, placeholder lyrics, in-memory hearts, the queue button, the album and artist
pages.)

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
- Library "Songs" and "Genres" tabs, and the Home chips beyond filtering rows, are M8.

## M3 — Playback (done; see the wrap-up above)

Built: libmpv engine behind `AudioBackend`, queue (play next, add to queue, reorder, remove, shuffle, repeat
off/all/one), gapless, volume/mute/seek, scrobbling, SMTC and media keys, album and artist pages, lyrics (server +
lrclib), hearts, restore on launch, queue panel. Not done (moved to M8 or noted above): transcoding/format choice,
ReplayGain, crossfade, device choice, saving the position on window close.

## M4 — Dynamic color + shapes (done; see the wrap-up above)

## M5 — Animated icons (in progress)

Every icon that moves does so with its own one-shot animation, rest state = the whole icon, reduced motion = still.
Artwork is a mix: UseAnimations Lottie files (`assets/icons/`, via the `lottie` package), Lucide Home and the
UseAnimations heart shape drawn in code, and small stroke glyphs in `ui/widgets/animated_glyphs.dart`.
Credits live in Settings and `third-party-licenses/`; add an entry for any new artwork.

Done: sidebar (Home, Library, Artists, Liked, Lists, Radio, Settings), cast button, list/cards toggle, sort and filter.

Also done: Next and Previous, Shuffle (straight lines), Menu, Repeat (rounded), Lyrics, Queue, Back, Search, Close,
Visualizer (mini bars), Collapse. Still static: the volume speaker (has its own swap), title bar buttons, play on cards,
login page icons. The queue also became a docked side panel (Settings switches it back to a popup).

## M6 — Now Playing (remaining)

Built: overlay with hero flight, lyrics list, lyrics toggle, volume slider, idle mode, visualizer styles + picker,
heart burst, track-change choreography, `V`/`L`/`Esc`/`Space`/`N`/`P`.

- Queue panel behind the top-bar queue button; cast button is a no-op.
- Check layout at the window minimum (720×520) and at ultrawide: the design is a 1280×800 canvas scaled to fit.
- Verify the hero flight when the mini player is at different widths / the rail is compact.
- Idle mode edge cases with real playback: buffering, track end, pause/resume, window deactivation.
- Keyboard focus handling: global `Space` shouldn't also activate a focused button; add visible focus styling.
- Buffering state on the wavy progress bar (mini player, Now Playing and the idle-mode line): while the engine is
  loading or stalled, an animated squiggle runs across the bar instead of a static position. Needs a `buffering`
  flag in the engine's state stream (media_kit exposes `player.stream.buffering`), shown in `PlaybackState`, with
  reduced motion falling back to a pulsing bar. Belongs here because it is part of the progress bar and idle mode
  edge cases above.
- Skipping fast between songs sometimes freezes mid-transition (reported). Reproduce with real playback first
  (rapid Next presses); likely a race between `open` calls in the engine/queue, so cancel or ignore stale loads
  and make the buffering animation the visible fallback while the latest track loads.

## M7 — Motion polish pass

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

## M8 — Search, playlists, offline, settings, real visualizer

- Search page (`search3`): artists/albums/songs, recent searches, keyboard-first; wire the header search pill.
- Playlists: list, detail, create/edit, add-to-playlist from context menus, reorder.
- Radio page (placeholder). Library Genres tab.
- Offline cache: download albums/playlists, cache management (size, clear), offline mode.
- Cache the list data on disk (songs, albums, artists, playlists, liked songs; Home rows) so the Library and the Songs
  tab open instantly and refresh in the background. Today only covers, extracted colors and the saved queue persist.
- Settings expansion: server/account, cache, scrobbling toggle, ReplayGain, audio output device, crossfade/gapless,
  visualizer frame cap, startup page. (Done: reduce motion, dark/light, visualizer style, track change speed.)
- **Real visualizer**: replace `SimulatedVisualizerSource` with FFT data (options: decode a parallel stream with
  FFmpeg, `flutter_soloud`, or a native audio tap). Same `VisualizerSource` interface; keep the 64-band,
  fast-attack/slow-decay smoothing. Say so in the UI until it ships.
- Context menus (right click), drag and drop, multi-select.

## M9 — Settings overhaul

Settings today is one flat column of switches that grew a row at a time. Redo it as a real settings area:

- Group the options under headings (Appearance, Playback, Library, Now Playing, Account, About) with a section nav or
  tabs; the page should still scroll smoothly and keep the reveal animations.
- Move the scattered preferences in here: view mode (cards/list), default Library tab and sorts, queue style
  (side panel or popup), hide Japanese text, motion settings, visualizer style, Home layout options.
- Account: server address, signed-in user, sign out, and a "forget cached covers" button with the cache size.
- Playback: scrobbling, lyrics lookup, crossfade and ReplayGain when they exist (M8).
- About: version, the credits and licences (currently the Credits card), links.
- Add a search box that filters the settings.
- Every preference stays persisted through `sharedPreferencesProvider`, with tests that each one survives a restart.

## Cross-cutting

**Quality gates (every milestone):** `flutter analyze` clean, `flutter test` passing, ≤ 5-line summary, small
reviewable commits, ask before adding packages not listed in `CLAUDE.md`.

**Performance:** measure in `--profile`, never debug (debug is several times slower and makes animations look
janky). The real displays are a **180 Hz laptop panel and a 144 Hz external monitor**, so the frame budget is
5.5-7 ms, not 16.7. Measure with real data: `tool/run_perf_real.ps1` (real server, covers, engine, lyrics; it reads
the display's refresh rate and prints budgets for it) found problems the fake-data `tool/perf_main.dart` hid (first-time
cover decodes, a gradient under every cover). Baseline at 180 Hz after M3: Now Playing steady build 0.6 / raster 2.7 /
total 4.2 ms median (p99 6.3), idle mode 4.6 (p99 8), lyric changes 4.6 (p99 8.8), skips and queue never above 10 ms.
Budget: no frames > 33 ms in any scenario, and steady states under the display's frame time.

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
