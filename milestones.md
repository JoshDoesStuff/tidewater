# Tidewater milestones

Where the project stands and what each remaining milestone must cover. Companion to `CLAUDE.md` (which stays the
source of truth for design and behavior); this file is the working plan.

Legend: ✅ done · 🟡 done against **fake/simulated** data, needs the real thing · ⬜ not started

## Where we are

The original plan was shell → server → playback → color/shapes → Now Playing → polish. We deliberately built
**demo parity first** with a simulated player, so milestones 1, 4 and 5 are largely done in look and behavior,
but everything they sit on is fake. The remaining milestones are mostly *replacing the fakes* and adding the
pages that don't exist yet.

| # | Milestone | Status |
|---|-----------|--------|
| 1 | Shell | ✅ |
| 2 | Server (login, OpenSubsonic, real library, cover cache) | ⬜ |
| 3 | Playback (real engine, queue, SMTC, scrobbling, album page) | ⬜ (UI 🟡 via `SimulatedEngine`) |
| 4 | Dynamic color + shapes | 🟡 (works, seeded from placeholder gradients) |
| 5 | Now Playing | 🟡 (works, simulated audio/visualizer/lyrics) |
| 6 | Motion polish pass | 🟡 (most of the demo list is in; QA pass outstanding) |
| 7 | Search, playlists, offline cache, settings, real visualizer | ⬜ (Settings partly ✅) |

## What is simulated or stubbed today

Replace these as the milestones below land. Each is a known, deliberate stand-in.

| Stand-in | Where | Replaced in |
|----------|-------|-------------|
| Fake albums, tracks, gradients | `core/data/fake_library.dart` | M2 |
| `SimulatedEngine` (clock only, no audio) | `core/playback/simulated_engine.dart` | M3 |
| Fake synced lyrics (same for every track) | `fakeLyrics` | M3 |
| `SimulatedVisualizerSource` (time-based, not from audio) | `core/playback/visualizer_source.dart` | M7 |
| Scheme seeded from the album's placeholder gradient color | `app/theme/album_scheme.dart` | M2 (needs real cover art) |
| Hard-coded: "Good evening", Jump back in heroes, Quick picks, "Daily Mix 1", "1,284 albums · 96 GB", avatar "J", "FLAC · 24-bit / 96 kHz" tag | `home_page.dart`, `library_page.dart`, `app_header.dart`, `now_playing_overlay.dart` | M2/M3 |
| Album cards and tracks are tied together **by list index** | `AlbumCard(index:)`, `activeAlbumIndexProvider`, `fakeTracks` | M2 (switch to ids) |
| No-op controls: menu button, search field, cast, queue, sort, filter chips, "Show all", A–Z rail, avatar tap, heart persistence | various | M2/M7 |
| Volume, shuffle, repeat only change in-memory state | `SimulatedEngine` | M3 |
| Liked tracks live in memory only | `likedProvider` | M3 (`star`/`unstar`) |

## M2 — Server

- Login screen: server URL, username, password / API key; remember server; clear error states (bad URL, bad
  credentials, unreachable, TLS). Secrets in `flutter_secure_storage`, server URL/user in `shared_preferences`.
- OpenSubsonic client in `core/api/` (dio, no SDK): `md5(password+salt)` token auth, prefer API key when
  `getOpenSubsonicExtensions` advertises `apiKeyAuthentication`; `ping`, `getAlbumList2`, `getAlbum`, `getArtists`,
  `getArtist`, `getPlaylists`, `getPlaylist`, `search3`. Unit tests with recorded JSON fixtures.
- Replace `fake_library.dart` with repositories + Riverpod providers; **key everything by id, not list index**.
- Cover art: request sized variants (300 grids, 800 Now Playing), disk cache keyed by `coverArt` id + size,
  placeholder + fade-in while loading.
- **Real cover-art color**: `QuantizerCelebi` + `Score` → seed → scheme (`material_color_utilities`), cached per
  album id. Remove the gradient-seed shortcut. Keep the contrast test (WCAG ≥ 4.5 for lyrics/accent text) running
  against real covers, including low-chroma and near-monochrome art.
- Real Home (recently added, frequent, recent plays; time-based greeting) and Library (real counts, sort,
  filters, A–Z jump actually scrolls, paging/lazy loading for large libraries).
- Empty, loading (skeleton) and offline/error states for every list.
- Avatar/initial from the account; sign out / switch server.

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
- Real stream info for the quality tag (codec, bit depth, sample rate) instead of the hard-coded string.
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
    slightly differently and the swap shows as a pop (2.8× the previous frame's change). Keep a never-identity
    transform (1e-6 rad tilt) instead. Same applies to any future animated text/shape.
- Add golden tests for key screens once the design settles; add an integration test for login → play.
- CI: analyze + test on every push.

## Open decisions

- Keep `go_router` page transitions as fade + 14 px rise, or move to shared-axis for deeper pages (album/artist)?
- Menu button (top of rail): expand/collapse the rail with labels, or open a drawer?
- Should the mini player hide when nothing has ever played, or always show the resting first track?
- Where do "Daily Mix" style generated playlists come from on a Navidrome server (smart playlists vs. none)?
- Real "Radio" source: Navidrome internet radio stations only, or also similar-artist radio?
