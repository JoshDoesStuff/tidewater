<p align="center">
  <img src="assets/branding/tidewater_banner_1280x640.png" alt="Tidewater" width="100%">
</p>

<!--
  ╔══════════════════════════════════════════════════════════════════════╗
  ║  YOUR SPACE: write whatever you want here (what it is, why you made   ║
  ║  it, a screenshot, a short story). Delete this comment when you do.   ║
  ╚══════════════════════════════════════════════════════════════════════╝
-->

## About

_Write your own intro here._

<!-- END OF YOUR SPACE -->

## What it is

Tidewater is a desktop music client for [Navidrome](https://www.navidrome.org) (and other OpenSubsonic servers),
built with Flutter for Windows in the Material 3 Expressive style: springy motion, shapes that morph, a wavy
progress bar, and colors that follow the album you're playing.

- Browse your library by albums, songs, artists, playlists and liked songs
- Gapless playback with media keys and the Windows media overlay, plus scrobbling to your server
- Synced lyrics (from your server, or from [LRCLIB](https://lrclib.net) if you allow it)
- A fullscreen Now Playing with visualizer styles, a docked or popup queue, and an idle mode
- The whole app recolors from the cover art of what's playing

## Get started

You need Flutter (stable), Visual Studio 2022 with the "Desktop development with C++" workload, and Rust
(`rustup`, needed by `smtc_windows` for media keys and the Windows media overlay).

```bash
flutter pub get
flutter run -d windows
```

Sign in with your server address and a username and password (or an API key).

```bash
flutter analyze
flutter test
flutter build windows --release
```

## Project notes

| File | What's in it |
|---|---|
| [CLAUDE.md](CLAUDE.md) | The design and behavior guide the app is built from |
| [milestones.md](milestones.md) | What is done, what is simulated, what each milestone covers |
| [docs/dev-notes.md](docs/dev-notes.md) | How to verify changes and lessons learned (animation rules, things not to redo) |
| [docs/handoff.md](docs/handoff.md) | The original handoff note |
| [docs/tidewater-m3e-demo.html](docs/tidewater-m3e-demo.html) | Interactive reference for the design |
| [docs/mockups/](docs/mockups) | Static layouts, plus rough mobile mockups and a prototype |

## Credits

Icon artwork and fonts come from other people's work; see the Credits card in the app's Settings and the
licenses in [third-party-licenses/](third-party-licenses):

- UseAnimations (MIT): Library, Cast, Artists, Lists, Radio, Settings and Volume icons
- Lucide and Lucide Animated (ISC and MIT): the Home icon
- Google Sans Flex (SIL Open Font License): the name on the banner (the font file is kept in `tool/fonts` to regenerate it)

## License

_Add the license you want for the project here._
