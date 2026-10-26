# Tidewater — Navidrome client for Windows (Flutter, Material 3 Expressive)

A desktop music client for Navidrome / OpenSubsonic servers in the style of Symfonium and PixelPlayer: Material 3 Expressive shapes, springy motion, wavy progress, dynamic color from album art, a fullscreen Now Playing with background visualizers, synced lyrics, and an idle mode.

## Source of truth
- `docs/tidewater-m3e-demo.html` is the **interactive reference**. Open it in a browser before building any screen or animation. It defines layout, shapes, timings, and behavior. Do not invent different ones. If code and demo disagree, the demo wins unless I say otherwise.
- `docs/mockups/tidewater-m3e-*.svg` are static layouts (Home, Library, Now Playing).
- The demo is 1280x800 HTML; translate to responsive Flutter layouts (NavigationRail collapses below ~900 px, content max-width centered above ~1600 px). Keep proportions and spacing rhythm.
- The demo's palette math is a rough HSL approximation. In the app use real Material color science (below).

## Stack (ask before changing or adding packages)
- Flutter stable, Windows desktop target, Dart 3, Material 3 (`useMaterial3: true`).
- State: `riverpod` (+ `riverpod_annotation` optional). Routing: `go_router`.
- Playback: `media_kit` + `media_kit_libs_windows_audio` (libmpv; gapless, many formats). Wrap behind `PlaybackEngine`.
- Media keys / lock screen / taskbar: `smtc_windows`. Window chrome: `window_manager`.
- Dynamic color: `material_color_utilities` (QuantizerCelebi + Score + `SchemeContent`/`SchemeTonalSpot` or `DynamicScheme`). Not `palette_generator`.
- HTTP: `dio`. JSON: plain Dart classes or `freezed`/`json_serializable`. No third-party Subsonic SDK.
- Cache: `cached_network_image` or own disk cache keyed by `coverArt` id + size. Settings: `shared_preferences`. Secrets (password / API key): `flutter_secure_storage`.
- Animations: Flutter's built-ins plus `SpringSimulation` (`flutter/physics.dart`). Custom paint for shapes, wavy progress, visualizers.
- Do **not** use a prebuilt "M3E" package for core pieces; the shape morph, wavy progress, and button-group behavior are small and we want exact control. A package may be used for reference.

## Layout
```
lib/
  app/            app.dart, router.dart, theme/ (ColorScheme from album, motion tokens)
  core/           api/ (OpenSubsonic client), models/, playback/ (engine, queue, scrobble), lyrics/
  ui/
    shell/        window shell, NavigationRail, mini player pill, FAB
    pages/        home, library, album, artist, search, playlists, settings
    now_playing/  overlay, lyrics view, idle mode, visualizer/
    widgets/      shapes/, wavy_progress, expressive_buttons, art_tile, ripple helpers
docs/             demo + mockups
```
Keep `core/` free of Flutter UI imports so it is unit-testable.

## Server API
- OpenSubsonic. Auth token = `md5(password + salt)`, params `u,t,s,v=1.16.1,c=Tidewater,f=json`. Prefer API-key auth if `getOpenSubsonicExtensions` advertises `apiKeyAuthentication`.
- Endpoints: `ping`, `getOpenSubsonicExtensions`, `getAlbumList2`, `getAlbum`, `getArtists`, `getArtist`, `getPlaylists`, `getPlaylist`, `search3`, `stream`, `getCoverArt`, `star`/`unstar`, `scrobble`, `getLyricsBySongId` (fall back to LRCLIB if the `songLyrics` extension is absent).
- Cover art: request sized variants (`size=` 300 for grids, 800 for Now Playing); cache to disk.
- Navidrome only counts a play when `scrobble` is sent with `submission=true`: send "now playing" at start, then submission at 50% or 4 minutes.

## Playback
- Everything goes through `PlaybackEngine` (play, pause, seek, next, prev, queue, position, state streams). Don't leak media_kit types out of it.
- **Visualizer data:** libmpv does not expose samples through media_kit. Drive the visualizer from `VisualizerSource` — a simulated source first (see demo: smoothed 64-band array, fast attack, slow decay, calm when paused). Real FFT is a later milestone (options: decode a parallel stream with FFmpeg/`flutter_soloud`, or a native audio tap). Say so; do not fake it silently.

## Design system (from the demo)
**Color**
- Generate a full `ColorScheme` from the current album's cover (dark theme default; support light). Animate between schemes over ~800 ms (`ColorScheme.lerp` in a `TweenAnimationBuilder`), and cache the scheme per album id.
- The whole app recolors when the playing album changes: surfaces, containers, nav rail, FAB, buttons, wavy bar, visualizer.
- Demo roles map to M3: `surface`, `surfaceContainerLow/-/High/Highest`, `primary`, `onPrimary`, `primaryContainer`, `secondaryContainer`, `tertiaryContainer`, `onSurface`, `onSurfaceVariant`. Primary is bright (tone ~80) on dark.
- Keep lyrics text at WCAG ≥ 4.5:1 against its background.

**Type**: Roboto Flex if licensing/packaging allows (variable weight/width gives the expressive headlines), else Roboto. Big bold headlines (Now Playing title ~58 px, w700, tight tracking), small caps eyebrows (13 px, w700, +1.5 letter spacing).

**Shape (the signature)**
- Art tiles are superellipse "squircles" that **morph** to scalloped shapes on hover/selection/play: `cookie` (9 lobes, amp .06), `clover` (4, .14), `sunny` (8, .10), `flower` (6, .13), `scallop` (12, .045), plus `circle`.
- Implementation: a `MorphShape` widget with a `ShapeBorder`/`CustomClipper<Path>` that interpolates each of ~120 points between superellipse (exponent ~4.2) and the radial lobed shape `r = R*base*(1 + amp*cos(n*θ + rot))` by morph factor `m`. Drive `m` with a spring (stiffness ~170, damping ratio ~0.55, i.e. visible overshoot). Optional continuous `rot` spin.
- Playing album's tile stays morphed and slowly spins. Cards are assigned a shape by index. Clicking the Now Playing cover cycles shapes.
- Buttons: shape changes on state. Round (pill) at rest → squarer on press or when selected (e.g. play button radius 40 → 28 while playing). Button groups: selected item becomes squarer with the primary fill.
- Wavy progress indicator: sine path along the played portion, flat track for the remainder, vertical pill handle. Wave amplitude breathes with bass while playing; flatten when paused. Drag to scrub (handle grows while dragging).

**Motion tokens** (`app/theme/motion.dart`; single source — never inline durations)
| Token | Value | Use |
|---|---|---|
| fast | 150 ms | hover, press, icon swaps |
| medium | 300 ms | fades, nav indicator, small moves |
| slow | 520 ms | layout moves, shared-element flights, lyrics/idle transitions |
| standard | `Cubic(.2, 0, 0, 1)` | default |
| emphasized | `Cubic(.05, .7, .1, 1)` | large moves, entrances |
| spring | `Cubic(.34, 1.56, .64, 1)` (or real spring) | pops, shape morphs, nav indicator |
Honor reduced motion: `MediaQuery.disableAnimations` plus a Settings toggle → instant/opacity-only transitions, no spin, no morph overshoot.

## Behaviors to implement (names match the demo)
1. **Page enter:** fade + 14 px rise, section headings reveal letter-by-letter on first load (stagger ~25 ms, once).
2. **Cards:** hover lifts and morphs the tile to its shape; a play button pops in (scale, spring); press scales .97; 3D tilt toward the cursor (small, ±6°); ripple from the pointer on tap.
3. **Click an album to play:** whole UI recolors from that album; color wash expands from the click point; mini player updates.
4. **Mini player pill** (bottom, floating): cover, title, transport, wavy progress, time. Click cover → Now Playing (shared-element/hero flight with FLIP-style transition; other elements rise with 60 ms stagger).
5. **FAB "Shuffle all":** bottom-right, rounded rect that grows rounder on hover (radius 24 → 36), icon wiggles.
6. **Play/pause:** icon morph (scale + rotate crossfade); button radius morphs; press scale .92–.94.
7. **Heart:** pop (1 → 1.45 → 1, spring) plus a small burst of particles; the chip squares off when liked.
8. **Track change:** cover scales down/fades, swaps, springs up; title reveals letter by letter; artist slides; colors crossfade ~800 ms; a wash spreads from the trigger.
9. **Ambient:** faint floating shapes behind pages (very slow drift), mouse spotlight glow. Keep subtle; never reduce text contrast.
10. **Visualizer (Now Playing background):** one `CustomPainter` driven by a `Ticker`, behind the content, colors from the scheme (lerped on track change). Styles: **Aurora** (default; 4 soft radial blobs, slow drift ~19 s periods, size/brightness follow smoothed bass; do not make them fast), **Shapes** (large faint morphing polygons, low alpha ≈ .05–.17), **Bars** (bottom mountain-range bars), **Ring** (rays around the cover, the old style kept as an option), **Off**. Picker: ✨ button opens a small popup (scale/fade from the button, spring); `V` cycles; persist the choice. A fainter Aurora also renders behind Home/Library while playing.
11. **Lyrics (Now Playing, right column):** a card containing **one scrolling list of all lines**, not text swaps. The active line is large (scale 1.3), accent colored, full opacity; neighbors dim and blur by distance (1: 45%, 2: 25%, rest ~20%); the list translates (900 ms, emphasized) so the active line stays vertically centered; edges fade with a mask. Old lines must animate out, never vanish. Use real timestamps from synced lyrics; plain lyrics → no auto-scroll.
12. **Lyrics toggle (`L` or button):** card collapses (height + fade + margin, slow, emphasized) and the cover column glides to center.
13. **Volume slider:** pill track with gap-less filled part, separate vertical handle (grows on hover, narrows/lengthens while dragging), tick dots at 25/50/75%, value bubble above the handle, springy fill, speaker icon swaps loud/quiet/muted with a small bump.
14. **Idle mode (Now Playing):** after 3.5 s with no mouse/key/touch input **while playing**, fade out (fade + 14 px slide, slow) the transport row, text column, top bar, volume, and wavy progress; hide the cursor. Any input restores. Never go idle while paused or while the visualizer popup is open.
    - **Lyrics ON:** cover stays on the left half with title + artist centered beneath it; the right half shows the large scrolling lyric list (same list mechanics as #11, bigger: ~36 px, active scale 1.28, column ~440 px wide). No caption under the cover.
    - **Lyrics OFF:** cover glides to center, title + artist beneath. **No lyric caption anywhere.**
    - **Idle progress:** a wavy line along the bottom edge of the window (≈ 40 px tall zone, handle at the played position) with elapsed/remaining time at the corners. Never draw progress around the cover.
15. **Keyboard:** Space play/pause, N next, P previous, L lyrics, V visualizer style, Esc close Now Playing.
16. **Removed from the demo (don't add back):** floating badge shapes next to the "Good evening" and "Library" titles.

## Visual rules
- Window: custom title bar (`window_manager`, hidden native title bar, our own draggable region + min/max/close). Rounded outer corners follow Windows 11.
- Shell: left `NavigationRail` (Home, Library, Artists, Lists, Radio; Settings pinned bottom) with a pill indicator that springs between items; menu button on top; content to the right; search bar + avatar in the header (the cast button returns in M10); mini player pill floats bottom-center; FAB bottom-right.
- No hardcoded colors outside the color-scheme generator. Everything via `Theme.of(context).colorScheme` (animated scheme).
- Keep animations cheap: `RepaintBoundary` around painters and large animated subtrees; cache shape `Path`s when `m` and `rot` are unchanged; cap visualizer to 60 fps and pause when Now Playing is hidden or the window is minimized.

## Working agreement
Build in milestones; stop after each so I can run it.
1. **Shell:** window chrome, theme + motion tokens, NavigationRail, header, mini player (static), FAB, static Home/Library with fake data.
2. **Server:** login, OpenSubsonic client, Home + Library with real data and cover caching.
3. **Playback:** engine, queue, album page, SMTC/media keys, scrobbling.
4. **Dynamic color + shapes:** scheme from cover with animated recolor, `MorphShape`, card/tile behaviors, wavy progress.
5. **Animated icons:** one-shot animation per icon (sidebar, buttons, transport); Lottie files + code-drawn glyphs; credits in Settings.
6. **Now Playing:** overlay + hero transition, lyrics list, lyrics toggle, volume slider, idle mode, simulated visualizer with all styles + picker.
7. **Motion polish pass** against the demo list above (ripples, tilt, reveals, heart burst, wash, ambient).
8. **Search, playlists, offline cache, settings, real visualizer.**
9. **Settings overhaul:** grouped, searchable settings page with account, playback and about sections.
10. **Casting:** Chromecast and DLNA devices, a cast picker, remote playback control (the Windows app is complete after this).
11. **Website:** a GitHub Pages one-pager once every Windows build is ready.
12. **Linux:** desktop target, MPRIS media controls, AppImage and Flatpak.
13. **Android:** phone layouts, media notification, background playback.
14. **macOS:** desktop target, system media center, signed and notarized dmg.
15. **iOS:** phone layouts from Android, background audio, TestFlight and App Store.
After each milestone: `flutter analyze` clean, `flutter test` passing, summarize in ≤ 5 lines. Don't refactor unrelated files. Ask before adding packages not listed. Small, reviewable commits.

## Commands
```
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release
```
Requires Flutter SDK, Visual Studio 2022 with the "Desktop development with C++" workload.

## Before you start
Read docs/milestones.md (status, what is simulated, what each milestone must cover) and docs/dev-notes.md (how to verify, animation rules learned the hard way, things not to redo).