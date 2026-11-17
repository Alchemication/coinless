# Coinless

*No more CONTINUE? 9… 8… 7…*

Remember digging through your pockets while the countdown ran out? Coinless is a personal, native Mac front end for [MAME](https://www.mamedev.org/), made for playing arcade games from the couch. Open **Coinless**, browse your games with a PS4 controller, keyboard, or trackpad, and press ✕ to play. Quit a game and you're back in the library, with your place saved.

- **A carousel of round CRT screens.** Each game shows a real picture: where you left off when there's a save, otherwise a frame from its attract mode that MAME captures in the background.
- **Resume or start over.** Supported games save automatically when you quit and resume next time. Press □ twice for a new game.
- **Couch-first controls.** D-pad or stick (hold to scroll), ✕ to play, Options for settings. Settings can be changed from the controller too.
- **The same setup from Terminal.** `./play dino` launches a game with the app's settings and shows the MAME command it runs.
- **Display styles.** Smooth (OpenGL), sharp pixels, or a curved CRT shader (Metal).

Built with SwiftUI, AppKit, and GameController, using your Homebrew MAME. No Xcode project, servers, or dependencies.

## Quick start

1. Install MAME: `brew install mame` (see [brew.sh](https://brew.sh/) if Homebrew is missing).
2. Install Apple's command-line tools if `xcrun swiftc` isn't available: `xcode-select --install`.
3. Add game ZIPs under `games/`, following [the game guide](docs/games.md). Keep ZIPs compressed.
4. Build and open:

```sh
zsh launcher/build.sh
open Coinless.app
```

The build creates and locally signs `Coinless.app` in the project folder, then checks MAME, `games.json`, and your installed games. The app and game files aren't in Git, so build locally after cloning.

Drag `Coinless.app` to the Dock for one-click access. It finds the project from its own location, so keep it in the project folder (moving the whole project is fine).

## Controls

| Action | PS4 controller | Keyboard | Mouse / trackpad |
| --- | --- | --- | --- |
| Browse | D-pad or left stick (hold to keep moving) | ← → | Swipe or scroll; click a side game |
| Play / Resume | ✕ | Return | Click the centre game |
| New game (on a saved game) | □, twice | N, twice | Click **New game** twice |
| Settings and help | Options (or ○) | ? or ⌘, | Sliders button, top right |
| In settings | ↑ ↓ to move, ✕ to change, ○ to close | ↑ ↓, Return, Esc | Click |
| Refresh the library | △ | R or ⌘R | Settings → Refresh games |

Games start full screen by default; switch to windowed in Settings.

### Getting back to the library

Quitting MAME returns you to Coinless. Esc quits on the keyboard. For the couch, assign a controller button once in MAME: **Tab → Input Settings → Input Assignments (general) → User Interface → UI Cancel**. Pick a button you don't use in games. Coinless never changes your MAME bindings.

### Saves

For games whose MAME driver supports save states, Coinless passes `-autosave`: **quit normally** and MAME saves your place in `sta/<game>/auto.sta`, and next time the button says **Resume**. Force-quitting or a crash may not save, and saves can stop working after MAME updates.

- **Before the first auto-save**, Coinless resumes your newest manual save in `sta/<game>/`.
- **New game** (□ or N, twice) moves `auto.sta` to `auto.sta.bak` and starts from the beginning. Your place is saved again when you quit.
- **Turning off** "Save on exit, resume next time" plays without loading or saving. Your files stay in place.
- **Quitting Coinless mid-game** asks MAME to exit cleanly first, so the auto-save is still written.

`./play` shows which games have a save. Tekken 3 and Golden Axe can't save in the current MAME.

For saves *during* a game, assign these in MAME's general **User Interface** list: **Save State (Quick)** to L3 and **Load State (Quick)** to R3 (click the sticks). Quick saves use their own slot, separate from the auto-save.

### Library pictures

Each game's picture lives in `art/<game>/`:

| File | Shown when | Made by |
| --- | --- | --- |
| `resume.png` | You have a save to resume | Coinless, from a copy of your save, after each session |
| `cover.png` or `cover.jpg` | Always, if present (instead of `attract.png`) | You |
| `attract.png` | Otherwise | Coinless: MAME runs the game for about 50 seconds without video or sound |

Captures run one at a time in the background and pause while you play. They use a temporary folder, so your settings, NVRAM, and saves are never touched. Set `previewAt` in `games.json` to capture a different moment. **Settings → Rebuild previews** or `./play --previews` regenerates them.

### TV setup

Use screen mirroring for the simplest setup. With an extended desktop, Coinless and MAME both use the **main display**, so make the TV the main display in **System Settings → Displays** before opening Coinless.

## Playing from Terminal

`./play` uses the same settings, saves, and launch options as the app:

```sh
./play                         # list games, what's missing, and which have saves
./play dino                    # play (resumes a save if there is one)
./play cad --window            # names can be shortened; play in a window
./play sf2ce --style crt       # smooth, sharp, or crt
./play hvnsgate --fresh        # start over (auto.sta is kept as auto.sta.bak)
./play tekken3 --dry-run       # print the MAME command without running it
./play --check                 # check MAME, games.json, and installed games
```

Each launch prints the full `mame` command, so you can copy it and tweak options. In a game: **5** adds a coin, **1** starts, **Tab** opens MAME's menu, **P** pauses, and **Esc** quits and saves.

## Adding games

The catalog is [launcher/games.json](launcher/games.json). The app reads it from the project each time it refreshes, so edits don't need a rebuild. A game appears once its ZIP exists at `games/<folder>/<id>.zip`.

| Field | Meaning |
| --- | --- |
| `id` | MAME short name, also the ZIP name without `.zip` |
| `folder` | Folder under `games/` |
| `title`, `subtitle`, `genre`, `year`, `players`, `note` | Text shown in the library |
| `symbol` | [SF Symbol](https://developer.apple.com/sf-symbols/) shown before a preview exists |
| `color` | Accent colour, hex without `#` |
| `saveStates` | Whether MAME can save this game. `./play --check` compares it with MAME |
| `requires` | Optional. Extra BIOS/device ZIPs without `.zip`, e.g. `["qsound_hle"]` |
| `previewAt` | Optional. Seconds of attract mode before the preview is captured (default 50) |

BIOS and device ZIPs can sit next to the game ZIP or once in **`games/bios/`**, which every game searches. For example, a single `games/bios/qsound_hle.zip` serves Cadillacs and Dinosaurs, Shadow over Mystara, and Alien vs. Predator.

## Troubleshooting

- **A game is missing from the library:** run `./play` to see the expected path and any missing BIOS files, then refresh (△ or R).
- **MAME reports missing files:** verify the set with `mame <id> -rompath "games/<folder>;games/bios" -verifyroms`. See [the game guide](docs/games.md) for known warnings.
- **A game closes with an error:** Coinless shows the reason and the end of MAME's output. The full log is `launcher/.build/mame-last.log`.
- **Controls seem to have reset:** MAME stores them in `cfg/` relative to where it starts. Coinless and `./play` always start it from the project folder; if you run `mame` yourself, `cd` here first.
- **The controller doesn't respond after a game:** for 20 seconds after a game ends, any controller press brings Coinless back to the front. After that, click the Coinless window once.

## Project layout

```text
.
├── play                      # Terminal launcher (./play --help)
├── launcher/
│   ├── Sources/              # The Mac app
│   │   ├── App.swift         #   window, menus, app lifecycle
│   │   ├── ArcadeModel.swift #   library state, launching, saves
│   │   ├── Input.swift       #   controller, keyboard, trackpad
│   │   ├── Library.swift     #   project paths, catalog, MAME arguments
│   │   ├── Previews.swift    #   headless MAME screenshots
│   │   ├── LibraryView.swift #   carousel and main screen
│   │   ├── Disc.swift        #   round CRT screen, marquee, backdrop
│   │   ├── HelpView.swift    #   settings and help
│   │   ├── CLI.swift         #   ./play commands
│   │   └── Catalog.swift     #   game model and theme
│   ├── Tools/Icon.swift      # App icon generator
│   ├── games.json            # Game catalog
│   ├── Info.plist
│   └── build.sh              # Build, sign, and check
├── docs/games.md             # Per-game downloads, BIOS files, and controls
├── .agents/skills/game-tips/ # Gameplay coaching skill for AI agents
├── Coinless.app/               # Generated
├── art/                      # Generated library pictures (cover.png is yours)
├── games/                    # Your ROM ZIPs; games/bios/ for shared BIOS files
├── cfg/  nvram/  sta/        # MAME controls, machine data, and saves
```

`.gitignore` excludes the app, game files, pictures, saves, and local MAME data. **Back up `cfg/`, `nvram/`, and `sta/` separately**; a Git clone won't restore them.

Other useful app flags: `Coinless --preview [game]` renders the library to `launcher/.build/preview.png`, and `Coinless --smoke-test` launches and quits a game headlessly in a sandbox.

## References

- [MAME default controls](https://docs.mamedev.org/usingmame/defaultkeys.html)
- [MAME command-line options](https://docs.mamedev.org/commandline/commandline-all.html)
- [MAME BGFX shaders](https://docs.mamedev.org/advanced/bgfx.html)
