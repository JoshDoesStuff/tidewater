# Tidewater milestones

Where the project stands and what each milestone covers. Companion to `CLAUDE.md` (which stays the source of truth
for design and behavior) and `dev-notes.md` (how to verify, lessons learned); this file is the working plan.

Legend: ✅ done · 🟡 in progress or done against **fake/simulated** data · ⬜ not started

## Status at a glance

The original plan was shell → server → playback → color/shapes → Now Playing → polish. We deliberately built
**demo parity first** with a simulated player, so the look and behavior came early; the later milestones are mostly
*replacing the fakes* and adding the pages that don't exist yet.

**The Windows app**

| # | Milestone | Status |
|---|-----------|--------|
| 1 | Shell: window chrome, theme + motion tokens, rail, header, mini player, FAB | ✅ |
| 2 | Server: login, OpenSubsonic client, real library, cover cache | ✅ |
| 3 | Playback: real engine, queue, SMTC, scrobbling, album and artist pages | ✅ (gaps listed in M3) |
| 4 | Dynamic color + shapes | ✅ |
| 5 | Animated icons (sidebar, buttons, transport) | ✅ |
| 6 | Now Playing polish | 🟡 (real audio, lyrics and queue; the visualizer is still simulated) |
| 7 | Motion polish pass | 🟡 (most of the demo list is in; QA pass outstanding) |
| 8 | Search, playlists, offline cache, settings, real visualizer | ⬜ (Settings partly ✅) |
| 9 | Settings overhaul | ⬜ |
| 10 | Casting (Chromecast, DLNA; the Windows app is feature complete after this) | ⬜ |

**Release and other platforms**

| # | Milestone | Status |
|---|-----------|--------|
| 11 | Website (after all the Windows builds are ready) | ⬜ |
| 12 | Linux | ⬜ |
| 13 | Android | ⬜ |
| 14 | macOS | ⬜ (somewhere in the future…) |
| 15 | iOS | ⬜ (somewhere in the future…) |

## Next up: M6

M6 is done apart from one look by eye at the hero flight (open and the new snappier flight back) at different mini player widths and with the compact rail.

## Stand-ins and gaps today

Each is a known, deliberate stand-in. Replace them as the milestones land.

| Stand-in | Where | Replaced in |
|----------|-------|-------------|
| `SimulatedVisualizerSource` (time-based, not from audio) | `core/playback/visualizer_source.dart` | M8 |
| `SimulatedEngine` is still the engine in tests, previews and the perf tools (the app itself uses libmpv) | `core/playback/simulated_engine.dart` | stays (test double) |
| No-op controls: sidebar menu button (hidden for now), header search field | various | M8 (menu button is the sidebar toggle) |
| Cast button (hidden until casting exists) | header, Now Playing | M10 |
| Library has no Genres tab (Songs has its own sort and cards/list view; the genre filter is a popup with search, Ctrl+click for several) | `library_page.dart` | M8 |
| Radio is a placeholder page (Artists, Liked and Lists are real; playlists open a playlist page) | `placeholder_page.dart` | M8 |
| The quality tag shows the file's own format from the server, not the engine's decoded format | `now_playing_overlay.dart` | M8 (with transcoding) |
| Lists (albums, songs, artists, playlists, liked) are fetched on every launch, not cached | providers | M8 |

---

## M1 — Shell (done)

Window chrome, theme + motion tokens, rail, header, mini player, FAB, Home and Library, delivered, then taken well
past the original "static" scope to demo parity with a simulated player (recolor, morph shapes, card behaviors,
Now Playing with lyrics/volume/idle/visualizers, Settings). Quality at wrap-up: `flutter analyze` clean, 44 tests
passing, `flutter build windows --release` succeeds, zero console errors on launch, no frame over 33 ms in the
profile scenarios (`tool/perf/perf_main.dart`).

## M2 — Server (done)

The app runs on a real Navidrome/OpenSubsonic server: login (password or API key, secrets in Windows secure
storage), a dio client written from scratch (`core/api/`), cover art with a disk cache, scheme colors from real cover
pixels, and Home and Library built from server data with loading, error and empty states. At wrap-up playback was
still simulated (clock only), but it already played real tracks from real queues. Quality: `flutter analyze` clean,
112 tests passing, Windows build and launch clean.

Checked against a live server: Navidrome 0.64.2 (the public demo) via `tool/probes/server_check.dart` (auth, artists,
playlists, paging, album detail with quality info, covers at 300/800, search, random songs) and 40 real covers via
`tool/probes/real_covers_test.dart` (0 contrast failures in dark and light; black/white/gray art gets a neutral
scheme). `flutter_secure_storage` round-trips on this machine (`tool/probes/session_probe_main.dart`). Also checked
against the user's own server (Navidrome 0.64.2, 518 albums, 313 artists): all albums load in two pages in about
0.6 s, 119 covers gave 0 contrast failures. Still untested: a library with many thousands of albums.

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
  the album id) shows until the image fades in. The cache is trimmed to 500 MB (least recently used first) when the
  session starts.
- **Scheme from the cover** (`core/color/cover_seed.dart`, `app/providers/scheme_providers.dart`): Celebi quantizer
  + `Score` on a 112 px decode, run on another isolate. Art with no color (black, white, gray) gives a *muted*
  seed → `DynamicSchemeVariant.neutral`, instead of a random hue. The app only recolors once the new seed is known
  (never default → placeholder → real). Cover failures fall back to a hue from the album id.
- **Home** (as built then; reworked since): greeting from the local hour, hero cards, rows for Recently added / Most
  played.
- **Library**: Albums load page by page (120, then 500 at a time) until the server runs out; the grid is lazy. Sorts
  are server-side (recently added, name, artist, most played, recently played, year newest-first, verified descending
  on a real server). The genre filter is client-side over what is loaded. The A–Z rail only shows for alphabetical
  sorts and skips articles ("The Beatles" files under B).
- **Mini player is hidden until something is queued** (decision; the old "resting first track" is gone). It rises
  in the first time it appears. Failed play requests show a toast (`ui/shell/toast_layer.dart`).
- **Account menu**: avatar shows the user's initial; menu offers sign out / switch server (stops playback first).

Known gaps:

- Not tested against a library with thousands of albums. Things to watch: Library paging time, memory of the
  metadata list, `getArtists` size, cover cache growth.
- API-key login is unit-tested but not tried against a server that advertises `apiKeyAuthentication` (the demo does
  not).
- Home rows refresh only when invalidated (Retry) or on restart (scrobbling now invalidates `recent`/`frequent`).

## M3 — Playback (done)

The app plays music for real. Audio comes from libmpv (`media_kit`) behind the `AudioBackend` interface; a
`QueueEngine` owns the queue, shuffle and repeat and keeps a two-item window (current + next) loaded so tracks join
gaplessly. Plays are reported to the server (now playing, then a counted play after half the track or 4 minutes),
the Windows media overlay and media keys work (`smtc_windows`), the last queue and position come back at launch,
hearts are real (`star`/`unstar`), lyrics come from the server (optionally lrclib.net), and there are album and artist
pages and a queue panel (drag to reorder, remove, jump). Also built: play next, add to queue, repeat off/all/one,
volume/mute/seek. Quality at wrap-up: `flutter analyze` clean, 228 tests passing, release build bundles
`libmpv-2.dll` and `smtc_windows.dll` and starts.

Verified with the real thing, not just fakes (all against the user's own server):

- `tool/probes/engine_probe_main.dart` (audible, quiet): play, pause, seek, **gapless hand-over** at the end of a
  track, next/previous, play next, shuffle, repeat-one, a missing track being reported and skipped, position reported
  16 times a second with at most an 89 ms gap.
- `tool/probes/e2e_main.dart` + `tool/probes/e2e_check.ps1`: Windows shows the playing track with its cover, and its
  media-key Pause/Play/Next/Previous drive the real engine.
- `tool/perf/perf_real_main.dart` (profile, 180 Hz laptop panel, real covers/lyrics/engine): see "Performance" below.

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
- Settings added: *Count plays on the server*, *Look up missing lyrics online* (lrclib.net; sends artist, title,
  album and length, so it is visible and can be switched off).
- Keys added: `M` mute (anywhere), `Q` queue (in Now Playing). Clicking the speaker also mutes.

Performance, measured on real data at 180 Hz (frame budget 5.6 ms; use `tool/perf/run_perf_real.ps1`):

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

Known gaps (moved to M6 or M8 where noted):

- The visualizer is still simulated (M8). The Now Playing quality tag shows the file's own format from the server, not
  what the engine decodes (matters once transcoding is used; there is no transcoding setting yet).
- The position is saved at pause, on queue changes and every 5 s, not on window close (up to 5 s lost on exit).
- Failed counted plays are retried for as long as the app runs, not across restarts.
- Hearts only exist for tracks; there is no starring of albums/artists from the UI yet.
- No ReplayGain, crossfade or audio-device choice (M8). No sleep timer.

## M4 — Dynamic color + shapes (done)

Most of M4 had already landed with the earlier milestones (scheme from real cover pixels, animated recolor,
`MorphShape`, card behaviors, wavy progress); what was left is done:

- **Light theme reviewed** (`flutter test tool/probes/render_shots_test.dart --dart-define=TW_LIGHT=true` renders every
  main screen to `build/shots-light`): Home, Library, Now Playing (cover halo, lyrics card, volume, visualizer
  mountains), idle mode and login all read well; the contrast test already checks 4.5:1 for accent and body text in
  both brightnesses, including gray and black-and-white art. No fixes were needed. Known soft spot: tonal buttons
  (previous/next, FAB) and the progress track are pale on a pale background, which is how Material's light roles work.
- **Recolor cost**: the fade now moves in 40 steps (~50 Hz) and builds one `ThemeData` per step (`ColorSchemeTween`,
  `ThemeMemo`). Before, a 180 Hz display rebuilt the whole themed tree and a fresh `ThemeData` 144 times per recolor
  (build p90 4.7 ms, almost the entire 5.6 ms budget); now 2.1 ms, and track skips measure 5.6 ms p90 total.
- **Extracted colors are remembered** (`SeedStore`, in `shared_preferences`, up to 4000 covers, keyed by server and
  cover id): a cover is decoded and quantized once ever, so the next launch (and a restored queue) themes instantly
  with no cover download. Failed covers fall back to a color from the album id and are *not* remembered.
- Now Playing shows no lyrics button and no lyrics card for a track without lyrics.

Left for M7: the visual QA of the tonal-button contrast in light, and a reduced-motion review of the stepped recolor
(it already respects `disableAnimations` by being instant).

## M5 — Animated icons (done)

Every icon that moves does so with its own one-shot animation; rest state is the whole icon, reduced motion means still.

- **Artwork:** UseAnimations Lottie files in `assets/icons/` (Library, Cast, Artists, Lists, Radio, Settings, Volume;
  played through the `lottie` package, tinted with a color filter), the Lucide house for Home (`home_icon.dart`), the
  Material heart for Liked (`code_icons.dart`), and small stroke glyphs in `ui/widgets/animated_glyphs.dart`: list,
  cards, sort, filter, next, previous, shuffle, repeat, repeat-one, lyrics, queue, back, search, close, collapse,
  menu, visualizer and its four siblings, minimize, maximize, restore, eye. Credits are in Settings and
  `third-party-licenses/`; add an entry for any new artwork.
- **Rule of thumb:** actions and toggles animate on click (`glyphFor`, `active: pressed`); hover only animates
  things that are decorative or in menus (search, sort, filter, the visualizer picker options). The Settings
  switch "Faint icon while it redraws" keeps a ghost under trace-on animations (erase-and-redraw is the default).
- **Beyond icons:** queue docks as a side panel (setting, popup still available), the mini player hugs its content
  and has a heart, the Now Playing lyrics button grows in and out with the controls centered under the progress bar,
  and the progress bar got its buffering squiggle, retract/squiggle-back transitions, a handle that shrinks into the
  end dot, click-to-squiggle seeking and an optional live scrub (see `wavy_progress.dart`).
- **Also done around it:** the app icon and banner (`tool/branding`), rounded window corners, a frameless window with
  our own caption buttons, the Home rework (Continue listening, Surprise me), and the repo, license and security
  setup.
- **Left alone on purpose:** the play arrows on cards and rows (they already pop in), the heart buttons (they have the
  like pop and burst), login-page field icons (decorative).

## M6 — Now Playing polish (in progress)

Built: overlay with hero flight, lyrics list, lyrics toggle, volume slider, idle mode, visualizer styles + picker,
heart burst, track-change choreography, queue panel (docked or popup), `V`/`L`/`Esc`/`Space`/`N`/`P`/`Q`/`M`.
Done recently: the buffering squiggle (the bar holds and a squiggle sweeps until the track really starts; it no longer
runs ahead of the sound).

Done in this pass:

- Window sizes: a smoke test lays out every page, Now Playing and the queue at 720 x 520, 1024 x 640, ultrawide and a
  tall narrow window. It caught an overflow of the Artists A-Z rail on short windows (now shrinks to fit).
- `Space` no longer also presses a focused button; keyboard focus shows a ring.
- Fast skipping: queued Next/Previous presses are coalesced so only the last track loads (no more freeze).
- Idle mode: never starts while buffering, and pausing wakes it immediately.

Still to do:

- Verify the hero flight by eye when the mini player is at different widths and the rail is compact.
- Idle mode on real playback: track end and window deactivation.
- Cast button hidden from the header and Now Playing until M10.
- Done since: the back arrow replaces the hidden menu button on detail pages (springs in and out), wider content cap on
  big monitors, diagonal grid stagger, a readable A-Z rail, the squiggle on a track restart, a snappier flight back
  on close (360 ms, symmetrical ease, the cover holds no longer), Google Sans Flex with bundled Noto Sans JP and SC and
  per-string Japanese or Chinese detection, and the new sign-in scene.

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

## M8 — Search, playlists, offline, real visualizer

- Search page (`search3`): artists/albums/songs, recent searches, keyboard-first; wire the header search pill.
- Playlists: list, detail, create/edit, add-to-playlist from context menus, reorder.
- Radio page (placeholder). Library Genres tab.
- Offline cache: download albums/playlists, cache management (size, clear), offline mode.
- **List cache**: cache the list data on disk (songs, albums, artists, playlists, liked songs; Home rows) so the
  Library and the Songs tab open instantly and refresh in the background. Today only covers, extracted colors and the
  saved queue persist. With it:
  - remember the last Library tab between launches (it always opens on Albums for now, because the Songs and
    Playlists tabs load slowly);
  - remember whether each track has lyrics (disk cache keyed by track id, with the lyrics themselves), so the lyrics
    button and the centered controls settle the moment a track starts: skipping to a track known to have lyrics grows
    the button in at once, and one known to have none folds it away in step with the skip, not after the lookup.
- Settings additions that depend on new features: ReplayGain, audio output device, crossfade/gapless, visualizer
  frame cap, startup page. (The Settings page itself is reorganized in M9.)
- **Real visualizer**: replace `SimulatedVisualizerSource` with FFT data (options: decode a parallel stream with
  FFmpeg, `flutter_soloud`, or a native audio tap). Same `VisualizerSource` interface; keep the 64-band,
  fast-attack/slow-decay smoothing. Say so in the UI until it ships.
- Context menus (right click), drag and drop, multi-select.
- **Sidebar menu button** (the hamburger at the top of the rail, a no-op today): make it collapse and expand the rail
  by hand at any window size (icon-only vs labeled), remembered between launches; the narrow-window auto-collapse
  stays.

## M9 — Settings overhaul

Settings today is one flat column of switches that grew a row at a time. Redo it as a real settings area:

- Group the options under headings (Appearance, Playback, Library, Now Playing, Account, About) with a section nav or
  tabs; the page should still scroll smoothly and keep the reveal animations.
- Move the scattered preferences in here: view mode (cards/list), default Library tab and sorts, queue style
  (side panel or popup), motion settings, visualizer style, Home layout options.
- Account: server address, signed-in user, sign out, and a "forget cached covers" button with the cache size.
- Playback: scrobbling, lyrics lookup, crossfade and ReplayGain when they exist (M8).
- About: version, the credits and licenses (currently the Credits card), links.
- Add a search box that filters the settings.
- Every preference stays persisted through `sharedPreferencesProvider`, with tests that each one survives a restart.

## M10 — Casting

The cast button (header and Now Playing) was removed from the UI until this lands. It comes before the website and
the platform ports so that the Windows app is complete first.

- Cast to Chromecast / Google Cast and DLNA / UPnP renderers on the local network: discover devices, show them in a
  picker from the cast button (animated, Material 3 Expressive), and send the current queue.
- Playback hands over to the remote device: the mini player and Now Playing show where it is playing, volume and
  seek control the remote, local audio pauses. Falls back cleanly if the device disappears.
- Needs stream URLs the device can reach (Navidrome over the LAN or a reachable address), and a decision on
  transcoding for devices that do not play every format. Likely needs new packages: ask first.
- Bring back the `cast.json` animation (still in `assets/icons/`, `castGlyph`) for the button.

## M11 — Website

Do this once every Windows build is ready (M1 to M9 shipped as a downloadable Windows release).

- A one-page site on GitHub Pages (Settings → Pages, served from `docs/` or a `site/` folder): the banner, a short
  pitch, real screenshots, a download button that links to the latest GitHub Release, and a link back to the repo.
- Needs a packaged Windows build first (installer or zip on GitHub Releases) with release notes.
- Screenshots and a short screen recording once the UI has settled. Keep the credits and licenses reachable from it.
- Optional later: a custom domain, and a changelog page generated from the release notes.

## M12 — Linux

- Flutter's Linux desktop target. Replace the Windows-only pieces: the custom frameless window (`window_manager`
  works on Linux too; check the resize edges and rounded corners), media keys and now-playing via MPRIS instead of
  SMTC (`audio_service` or an MPRIS package; ask before adding), `media_kit` Linux libs instead of the Windows ones.
- Packaging: an AppImage first, then Flatpak or a .deb; test on GNOME and KDE, X11 and Wayland, with fractional
  scaling.
- Secure storage needs libsecret on Linux; check the fallback when no keyring is running.
- Icons: add the `.png` set and a `.desktop` file; reuse `tool/branding`.

## M13 — Android

- Responsive shell for phones (see `docs/mockups/tidewater-mobile-prototype.html`): bottom navigation bar in portrait,
  side rail in landscape, mini player above it, queue as a bottom sheet, touch replacements for hover, Ctrl+click and
  keyboard shortcuts (long-press, swipe, back gesture).
- Now Playing needs its own portrait and landscape layouts; the desktop 1280 × 800 canvas does not carry over.
- Background playback with a media notification and lock-screen controls, audio focus and headset buttons
  (`audio_service` + `audio_session`; ask before adding), and `media_kit` Android libs.
- Permissions (notifications), battery use of the visualizer and idle mode, soft keyboard on login, edge-to-edge
  insets. Build and test with the Android SDK from Windows; publish as an APK on Releases, Play Store later.

## M14 — macOS

> **Somewhere in the future… when I can afford a Mac and a developer license to make one app, lol.** Until then this
> is a plan only: macOS and iOS apps can only be built, signed and tested on Apple hardware. CI (GitHub macOS runners)
> can build them, but testing the UI needs a Mac or a tester who has one.

- Flutter's macOS target. Replace the Windows pieces: native traffic-light window controls or a custom title bar,
  media keys and Now Playing through the system media center, `media_kit` macOS libs.
- Menu bar (App, File, View, Window), standard shortcuts (Cmd instead of Ctrl), trackpad gestures, Retina assets and a
  proper `.icns` icon.
- Needs a Mac and Xcode to build; code signing and notarization with an Apple developer account to distribute outside
  the App Store. Packaging as a `.dmg`.

## M15 — iOS

> **Somewhere in the future… when I can afford a Mac and a developer license to make one app, lol.** Same story as
> M14: it needs a Mac, Xcode and the paid Apple developer program ($99 a year).

- Reuses the phone layouts from M13; adds Cupertino-friendly touches only where Material feels wrong (back swipe,
  safe areas, haptics).
- Background audio capability and lock-screen controls, `media_kit` iOS libs, App Transport Security for servers on
  plain HTTP or self-signed certificates.
- Needs a Mac, Xcode and an Apple developer account (a free one installs for 7 days at a time); TestFlight for
  testing and the App Store for release, with App Review's rules on streaming clients in mind.


---

## Cross-cutting

**Quality gates (every milestone):** `flutter analyze` clean, `flutter test` passing, ≤ 5-line summary, small
reviewable commits, ask before adding packages not listed in `CLAUDE.md`.

**Performance:** measure in `--profile`, never debug (debug is several times slower and makes animations look
janky). The real displays are a **180 Hz laptop panel and a 144 Hz external monitor**, so the frame budget is
5.5-7 ms, not 16.7. Measure with real data: `tool/perf/run_perf_real.ps1` (real server, covers, engine, lyrics; it
reads the display's refresh rate and prints budgets for it) found problems the fake-data `tool/perf/perf_main.dart`
hid (first-time cover decodes, a gradient under every cover). Baseline at 180 Hz after M3: Now Playing steady build
0.6 / raster 2.7 / total 4.2 ms median (p99 6.3), idle mode 4.6 (p99 8), lyric changes 4.6 (p99 8.8), skips and queue
never above 10 ms. Budget: no frames > 33 ms in any scenario, and steady states under the display's frame time.

**Accessibility:**
- Animated text must be hidden from semantics behind one stable label (per-letter nodes caused hundreds of
  `AXTree` errors per launch; fixed for letter animations and decorative layers). Closed panels (queue, visualizer
  picker) are excluded from the tree too.
- Audit the rest for per-frame semantics churn (cards under tilt, hero carousel resizing).
- Keyboard navigation and visible focus for every control; Narrator pass; check contrast in light theme.

**Windows and packaging:**
- `flutter build windows --release` check, window title, installer (MSIX or similar), single-instance.
- Done: app icon (multi-size `.ico`, bold simplified frames for the taskbar), rounded corners through DWM, window icons
  set at the window's DPI. Still to check: rounded corners when maximized or snapped, high-DPI (125–200 %) pass,
  multi-monitor, Impeller/GL behavior on other GPUs.
- Headline font: the app uses the default Roboto; Roboto Flex / Google Sans Flex (variable weight, width, roundness)
  for expressive headlines if packaging allows (the banner already uses Google Sans Flex).

**Testing and tooling:**
- `test/` is sorted into `core/` (API, queue, engine, color), `app/` (providers, services, theme), `ui/` (widgets
  and pages) and `flows/` (whole-app tests against a fake server), with shared helpers in `test/support/` and
  fixtures in `test/fixtures/`. Keep adding tests with each feature.
- `tool/` is sorted into `branding/` (icon and banner: `flutter test tool/branding/render_app_icon_test.dart`),
  `perf/` and `probes/`.
- `tool/probes/render_shots_test.dart`: offscreen screenshots of the main screens to `build/shots/` (works with the
  desktop locked): `flutter test tool/probes/render_shots_test.dart`.
- `tool/perf/perf_main.dart`: per-phase frame build/raster times through the heavy scenarios:
  `flutter run -d windows --profile -t tool/perf/perf_main.dart`.
- `tool/probes/letter_probe_main.dart`: pixel-level measurement of how smoothly the engine renders animated letters
  (jitter in px, plus a landing/start "pop" metric):
  `flutter run -d windows --profile -t tool/probes/letter_probe_main.dart`.
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
- Where do "Daily Mix" style generated playlists come from on a Navidrome server (smart playlists vs. none)?
- Real "Radio" source: Navidrome internet radio stations only, or also similar-artist radio?
