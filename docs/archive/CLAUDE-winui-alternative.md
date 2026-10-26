# Tidewater — Navidrome client for Windows 11 (WinUI 3)

A native Windows 11 music client for Navidrome / OpenSubsonic servers. It should look and feel like a first-party Win11 app (Mica, Fluent, NavigationView) with polished micro-animations, a fullscreen Now Playing view, dynamic album-art colors, and a visualizer.

## Source of truth for design
- `docs/mockups/*.svg` are the target layouts: 1 Home, 2 Library, 3 Album, 4 Now Playing (lyrics on), 5 Now Playing (lyrics hidden), 6 Now Playing idle (controls hidden, bottom-edge progress), 7 visualizer styles. Match them.
- `docs/tidewater-motion-demo.html` is the interactive reference for **motion**: timings, easing, what animates and when. Open it in a browser before implementing any animation. Do not invent different timings.
- If code and mockups disagree, the mockups win unless I say otherwise.

## Stack (do not change without asking)
- C# / .NET 8, **WinUI 3** (Windows App SDK, latest stable), unpackaged or single-project MSIX.
- MVVM with `CommunityToolkit.Mvvm`; DI with `Microsoft.Extensions.DependencyInjection`.
- `CommunityToolkit.WinUI.Animations` for implicit/declarative animations; `ConnectedAnimationService` for shared-element transitions; `Microsoft.UI.Composition` for anything custom.
- `Win2D` (`CanvasAnimatedControl`) for the visualizer.
- `System.Text.Json` + `HttpClient` for the API. No third-party Subsonic SDK; the API surface we need is small.
- Settings: `ApplicationData.LocalSettings`. Secrets (password / API key): `Windows.Security.Credentials.PasswordVault`.

## Project layout
```
src/Tidewater/            App, Window, Pages/, Controls/, ViewModels/, Services/, Styles/
src/Tidewater.Core/       Subsonic client, models, playback abstractions (no UI refs)
docs/                     mockups + motion demo
```
Keep `Tidewater.Core` UI-free so it can be unit tested.

## Server API
- Target OpenSubsonic. Auth: token = `md5(password + salt)`, params `u,t,s,v=1.16.1,c=Tidewater,f=json`. Prefer API-key auth if the server advertises `apiKeyAuthentication` in `getOpenSubsonicExtensions`.
- Needed endpoints: `ping`, `getOpenSubsonicExtensions`, `getAlbumList2`, `getAlbum`, `getArtists`, `getArtist`, `getPlaylists`, `getPlaylist`, `search3`, `stream`, `getCoverArt`, `star`/`unstar`, `scrobble`, `getLyricsBySongId` (OpenSubsonic `songLyrics` extension; fall back to LRCLIB if absent).
- Cover art: request sized variants (`size=` 200 for grids, 600 for album/now playing) and cache to disk.
- Navidrome only counts a play when `scrobble` is called with `submission=true`; send "now playing" then submission at 50% or 4 minutes.

## Playback
- Put everything behind `IPlaybackEngine` (Play, Pause, Seek, Next, Prev, Queue, Position, State, events).
- Start with `Windows.Media.Playback.MediaPlayer` and integrate `SystemMediaTransportControls` (media keys, lock screen, taskbar thumbnail).
- Gapless/crossfade/EQ may need a different engine later (LibVLCSharp or BASS). Don't leak MediaPlayer types outside the engine.
- **Visualizer data:** MediaPlayer does not expose samples. For milestone 3 drive the visualizer from a simulated signal behind `IVisualizerSource`; real FFT is a later milestone and may require the engine swap. Say so rather than faking silently.

## Visual rules
- Window: `SystemBackdrop = new MicaBackdrop()`, `ExtendsContentIntoTitleBar = true`, custom title bar with centered `AutoSuggestBox`. Fall back gracefully if Mica is unavailable.
- Shell: `NavigationView` (left pane, Home / Library / Artists / Playlists / Radio, Settings footer), content in a rounded top-left "layer" card, persistent bottom player bar (80px).
- Use theme resources (`ThemeResource`, `AccentFillColorDefaultBrush`, `LayerFillColorDefaultBrush`, etc.). **No hardcoded colors** except album-derived colors. Support light and dark.
- Fonts: system default (Segoe UI Variable). Icons: Segoe Fluent Icons.
- Now Playing is a fullscreen overlay: blurred/gradient background from album colors, large art, lyrics column (toggle with `L`, animates art to center when hidden), visualizer along the bottom, small "colors from album art" indicator is a mockup annotation only (do not ship it).
- Dynamic color: extract 2–3 dominant colors from the cover (downscale to ~64px, k-means or median cut), clamp luminance/saturation so white text stays readable (WCAG ≥ 4.5:1 for lyrics), animate between palettes over ~1s. Cache palette per album id.

## Motion spec (from the demo)
| Token | Value | Use |
|---|---|---|
| fast | 120 ms | hover, press, icon swaps |
| medium | 250 ms | fades, nav indicator, page fade+rise (14px) |
| slow | 480 ms | layout moves, shared-element flights, lyrics hide/show |
| ease | decelerate `cubic-bezier(.2,.8,.2,1)` | default |
| spring | overshoot `cubic-bezier(.34,1.45,.5,1)` | play-button pop, nav indicator, icon morph |

Behaviors to implement (names match the demo):
1. Nav selection indicator slides between items (spring).
2. Album cards lift 4px + shadow on hover; a play button scales/fades in; press scales to 0.97.
3. Card → album page: `ConnectedAnimation` of the cover; track rows stagger in (35–40 ms apart).
4. Play/pause icon morph (scale + rotate crossfade), press scale 0.92.
5. Mini player cover → Now Playing: connected animation of the cover; other elements rise in with 60 ms stagger.
6. Lyrics hide/show: lyrics fade + slide 48px + blur; the art column slides to center (480 ms ease).
7. Track change: art scales down/fades, swaps, scales up; title/artist slide; background colors crossfade ~1s.
8. Active lyric line is full opacity; others dim and blur by distance; list scrolls to keep the active line centered.
9. Heart: pop (1 → 1.45 → 1, spring).
10. **Idle mode on Now Playing:** after 3.5 s with no mouse/key/touch input *while playing*, fade the transport row, linear progress bar, lyrics/visualizer buttons and top bar (fade + 10–14px slide, slow). The art column glides to center (slow, ease), the lyrics column fades/blurs out, the cursor hides. Any input restores everything. Never go idle while paused or while the visualizer flyout is open.
11. **Idle progress:** while idle, progress is a 4 px hairline along the very bottom edge of the window (white, soft glow in the album color, glowing head dot) with `elapsed` bottom-left and `-remaining` bottom-right in small dim text. In Bars and Wave styles the played portion of the visualizer stays bright and the unplayed portion dims to ~38%. Do not draw progress around the cover.
12. **Idle lyric caption:** if lyrics are enabled, the current line shows as a single centered caption under the artist (crossfade + 8px rise on each line change). If lyrics are hidden, no caption.
13. Idle title/artist re-center (short fade to hide the alignment change).

## Visualizer
- Styles: **Bars** (default), **Wave** (3 layered smooth filled curves), **Radial** (rays emerging from behind the cover's edges), **Scope** (glowing oscilloscope line), **Off**. See `docs/mockups/tidewater-7-visualizer-styles.svg`.
- Picker: the visualizer button on Now Playing opens a small flyout (scale/fade from the button, spring); `V` cycles styles. Persist the choice in LocalSettings.
- All styles draw on one `CanvasAnimatedControl` behind the content and share: the same smoothed level array (attack fast, decay slow), colors from the album palette (lerped when the track changes), and a calm idle state when paused.
- Data source goes through `IVisualizerSource` (simulated first; see Playback).
- **Respect "reduce animations":** check `UISettings.AnimationsEnabled`; when off, use instant transitions (opacity-only is fine). Wrap this in one `MotionService` so durations/easings live in a single place.
- Keep animations on the compositor (Composition / implicit animations), not per-frame XAML property animation in code-behind.

## Working agreement
- Build in milestones; stop after each so I can run it:
  1. Shell: Mica window, NavigationView, title bar, bottom bar (static), theme.
  2. Server login + Home + Library grid with real data and cover caching.
  3. Album page, playback (MediaPlayer), SMTC, queue, scrobbling.
  4. Now Playing overlay: dynamic colors, lyrics, simulated visualizer (all 4 styles + picker), lyrics toggle, idle mode with bottom-edge progress.
  5. Motion pass per the table above.
  6. Search, playlists, offline cache, settings, real visualizer.
- After each milestone: `dotnet build` must pass with zero warnings in our code, then summarize what changed in ≤5 lines. Don't refactor unrelated files.
- Ask before adding a NuGet package not listed above.
- Prefer small, reviewable commits.

## Commands
```
dotnet build src/Tidewater/Tidewater.csproj -c Debug -p:Platform=x64
dotnet run --project src/Tidewater/Tidewater.csproj -p:Platform=x64
dotnet test
```
Requires Visual Studio 2022+ with the "Windows application development" workload (WinUI 3 / Windows App SDK).
