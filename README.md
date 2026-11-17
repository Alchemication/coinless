# Arcade — a macOS MAME launcher

A personal, native Mac app for playing arcade games from the couch. Connect your TV, open **Arcade**, choose a game tile, and play with PS4 controllers, a keyboard, or a mouse.

Built with SwiftUI, AppKit, and GameController, using your locally installed MAME emulator. Features include:

- A full-screen game library with single-click or controller launch.
- PS4 D-pad/stick navigation, Cross to play, and support for either connected controller.
- Automatic save/resume for supported games.
- Remembered game selection and fullscreen preference.
- Existing MAME controls and saves, with a return to the library when a game exits.

The app is designed for personal use on macOS and has been built and checked on an Apple Silicon Mac. Controller and TV behaviour should be checked on your own setup.

## Build and open the Mac app

One-time setup:

1. Install [Homebrew](https://brew.sh/) if needed, then [install MAME](#install-mame).
2. Install Xcode or Apple's command-line developer tools so `xcrun swiftc` is available. If needed, run `xcode-select --install` and complete the installer.
3. Add at least one game's ZIP files under `games/`, following the [game setup instructions](#games). Keep ZIPs compressed and include the required BIOS/device files.
4. From this project's directory, build and open the app:

```sh
zsh launcher/build.sh
open Arcade.app
```

The build creates and locally signs `Arcade.app` in the project root, then checks that MAME and at least one installed game can be found. **The generated app and game files are not included in Git**: after cloning the repository, add your game files and build locally. There are no web servers or JavaScript dependencies to start.

Rebuild after editing `launcher/games.json`, changing the app source, or moving the project. The app records the project's location during the build, so launch it from that location afterward. To check library discovery without starting a game:

```sh
./Arcade.app/Contents/MacOS/Arcade --check
```

### Start from the Dock

Open **[Arcade.app](Arcade.app)** in this project. It opens a full-screen tile library, showing only games whose ZIP files are present. No Terminal is needed for normal play.

For easy access, drag `Arcade.app` from Finder to the **application side of the Dock** once. Next time, connect the TV, click Arcade in the Dock, and use your controller. Keep this project in place: the app uses its game folders, controls, and saves.

| Launcher action | PS4 controller | Keyboard |
| --- | --- | --- |
| Browse tiles | D-pad or left stick | Arrow keys |
| Play selected game | Cross (✕) | Return |
| Open/close help | Options or Circle (○) | Click the question-mark button |
| Refresh downloads | Triangle (△) | R |

Mouse/trackpad also works: **click any tile once to launch that game**. MAME runs with the same OpenGL, smoothing, aspect ratio, and project directory as the commands below. Games start fullscreen by default; the help panel has a windowed option. The launcher remembers your last played game and fullscreen preference. Either connected PS4 controller can browse and launch games, and controllers can connect while the launcher is open. Quitting a game returns you to the launcher.

**One-time controller setup for leaving a game:** in MAME, open **Tab → Input Settings → Input Assignments (general) → User Interface** and assign **UI Cancel** to a spare controller button. Keep Esc as an alternative. This lets you return to the library from the couch without a keyboard. Choose a button that is not used for attacks or other actions. The launcher does not alter your MAME bindings.

Use screen mirroring for the simplest TV setup. With an extended desktop, the launcher prefers a second screen, but MAME uses its configured/default display; make the TV the main display in macOS Displays settings if the game appears on the laptop. Switch mirroring/display settings before opening Arcade.

#### Automatic resume and controller saves

The launcher enables MAME's `-autosave` for games whose drivers support save states. **Quit normally**, and MAME saves the current session; next launch attempts to restore it. The Play button changes to **Resume** when a save is available. Cadillacs and Dinosaurs, Heaven's Gate, and SF2 support this; Tekken 3 and Golden Axe do not in the installed MAME.

On first use, if no `sta/<game>/auto.sta` exists, the launcher attempts to load the most recently modified manual `.sta` file for that game. Existing manual saves are retained. Once an automatic save exists, it takes priority. Force-quitting or a crash will not reliably create a save, and save compatibility can change with MAME updates.

To start fresh, turn off **Automatically save on exit and resume next time** in the launcher's help panel. While disabled, sessions neither auto-load nor auto-save; your existing files remain available when you turn it back on.

For save/load **during** a game without a slot-selection screen, configure these once under **Tab → Input Settings → Input Assignments (general) → User Interface** (wording varies by version):

| MAME action | Suggested PS4 button |
| --- | --- |
| Save State (Quick) / Quick Save | L3 (click the left stick) |
| Load State (Quick) / Quick Load | R3 (click the right stick) |

Choose the **Quick** actions, rather than regular Save/Load State. They write/load a separate quick-save slot without another button press; each quick save overwrites that slot. Preserve existing keyboard shortcuts when adding controller alternatives. If you click the sticks accidentally, use a deliberate two-button combination instead. Physical controller assignments must be made in MAME; the launcher does not guess joystick button numbers or overwrite your bindings.

Automatic resume restores the previous exit point; quick load restores the manual quick-save point. These can differ. You can also request a named manual slot from Terminal with `-state <slot>`. See [MAME save options](https://docs.mamedev.org/commandline/commandline-all.html) and [input controls](https://docs.mamedev.org/usingmame/defaultkeys.html).

### Add games and troubleshoot

The existing shortlist is in [launcher/games.json](launcher/games.json): downloading its games to the documented folders makes them appear after refresh. To add other games, add a catalog entry and rebuild. Set `saveStates` according to the installed MAME driver's support, which can be checked with `mame <shortname> -listxml`.

Launch errors appear in the app; the latest MAME output is saved to `launcher/.build/mame-last.log`. If a game is missing, check its folder and ZIP filename against the catalog, then refresh with Triangle or R. If MAME opens but reports missing files, follow the game's ROM verification instructions below.

### Test your couch setup

1. Open Arcade and check that your downloaded games appear.
2. Browse with the PS4 D-pad and launch Cadillacs with Cross. Also try arrow keys + Return and a single mouse click on a tile.
3. Reach a recognisable point, then quit MAME normally. Confirm the launcher returns and shows **Resume**.
4. Launch again and check that the session continues from that point.
5. After assigning controller quick-save/load actions in MAME, save, move somewhere else, then load to check the result.

The app's build, library/launch arguments, signature, and a headless MAME launch/return were checked during development. Automatic save creation and restart/resave were checked using temporary copies of a Cadillacs save. These checks do not replace physical controller, audio, or TV testing.

## Games in this setup

Four games are downloaded in the original local setup. Game files are excluded from this repository. Follow each section for its required files, controls, and optional Terminal launch command; the app handles launching once the files are in place.

| Game | `GAME_NAME` | Folder under `games/` | Instructions |
| --- | --- | --- | --- |
| Heaven's Gate | `hvnsgate` | `heavens-gate` | [Setup and controls](#heavens-gate-1996) |
| Cadillacs and Dinosaurs | `dino` | `cadillacs-and-dinosaurs` | [Setup and controls](#cadillacs-and-dinosaurs) |
| Tekken 3 | `tekken3` | `tekken-3` | [Setup and controls](#tekken-3) |
| Street Fighter II: Champion Edition | `sf2ce` | `street-fighter-2` | [Setup and controls](#street-fighter-ii-champion-edition) |

If using Terminal, copy the **whole command block** for the game, including both exports. In the game, press **5** to insert a coin, **1** to start, and use the arrow keys to select a character, or use the equivalent controller bindings. Press **Tab** to inspect or change inputs, **P** to pause, and **Esc** to quit normally and save settings.

The remaining arcade games below have download and launch instructions but are not yet present in `games/`. Zelda is listed separately because its console setup is still pending.

## Install MAME

If Homebrew is not installed, follow the instructions at [brew.sh](https://brew.sh/). Complete its “Next steps” instructions so `brew` is available in Terminal.

Install [MAME through Homebrew](https://formulae.brew.sh/formula/mame):

```sh
brew install mame
```

Check the installation:

```sh
command -v mame
mame -help
```

MAME supplies the emulator. Game ROMs and any required BIOS files are separate downloads.

## Project layout

```text
emu/
├── README.md
├── .gitignore
├── .agents/skills/game-tips/   # Gameplay coaching skill and game references
├── launcher/
│   ├── Arcade.swift           # Native Mac interface, controllers, and MAME launch
│   ├── Icon.swift             # App icon generator
│   ├── Info.plist             # macOS app metadata
│   ├── games.json             # Game library and save-state capabilities
│   ├── build.sh               # Build, sign, and check the app
│   └── .build/                # Generated build files, previews, and runtime log
├── Arcade.app/                # Generated Mac app; add to the Dock
├── cfg/                       # Saved input mappings and other MAME settings
├── nvram/                     # Persistent emulated machine data
├── sta/                       # Manual and automatic save states
└── games/
    ├── heavens-gate/
    │   ├── hvnsgate.zip        # Game ROM set
    │   └── coh1001l.zip        # Atlus ZN-1 BIOS
    ├── cadillacs-and-dinosaurs/
    │   ├── dino.zip
    │   └── qsound_hle.zip      # Required sound-device ROM
    ├── tekken-3/
    │   └── tekken3.zip
    └── street-fighter-2/
        └── sf2ce.zip
```

The launcher uses the project directory automatically. When running MAME directly from Terminal, start with:

```sh
cd ~/Projects/emu
```

With the default configuration used here, MAME creates `cfg/` and `nvram/` relative to the launch directory. Starting elsewhere can make saved settings appear to be missing.

`.gitignore` excludes game files, local controls/preferences, saves, runtime data, and generated app/build files. Keep backups of `cfg/`, `nvram/`, and `sta/` separately; a Git clone will not restore them.

## Games

### Heaven's Gate (1996)

The Racdym / Atlus arcade fighting game. Its MAME short name is `hvnsgate`.

#### Download the game and BIOS

These Planet Emulation pages list the files used for this setup:

| File | Download page | Purpose |
| --- | --- | --- |
| `hvnsgate.zip` | [Heaven's Gate](https://www.planetemu.net/en/rom/mame-roms-merged/hvnsgate) | Game ROMs |
| `coh1001l.zip` | [Atlus ZN-1](https://www.planetemu.net/en/rom/mame-roms-merged/coh1001l) | Required machine BIOS |

Use the Download section on each page; JavaScript is required. These are third-party sources, and their distribution permissions have not been verified.

Keep both ZIP files compressed and place them in:

```text
~/Projects/emu/games/heavens-gate/
```

To copy them from Downloads when setting up another installation:

```sh
mkdir -p ~/Projects/emu/games/heavens-gate
cp ~/Downloads/hvnsgate.zip ~/Downloads/coh1001l.zip ~/Projects/emu/games/heavens-gate/
```

#### Recommended launch

Use OpenGL with smoothing (`-filter`). This is a good starting point for the game's low-resolution 3D graphics.

```sh
cd ~/Projects/emu
export GAME_PATH=~/Projects/emu/games/heavens-gate
export GAME_NAME=hvnsgate
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -window -video opengl -filter -keepaspect
```

`GAME_NAME` is MAME's internal short name, usually the game ZIP's name without `.zip`. `GAME_PATH` is the folder containing that ZIP and its dependencies; the folder name can be anything. Renaming a ZIP does not change the game's short name.

Both variables last for the current Terminal session. Set **both** whenever switching games so MAME does not search for the previous game in the new folder. MAME does not read these variables automatically; the command below passes their values as arguments. For a launch without variables:

```sh
cd ~/Projects/emu
mame hvnsgate -rompath "$PWD/games/heavens-gate" -window -video opengl -filter -keepaspect
```

| Option | Effect |
| --- | --- |
| `-rompath` | Folder containing the game and BIOS ZIPs |
| `-window` | Start in a window |
| `-video opengl` | Use OpenGL for video output |
| `-filter` | Smooth the scaled image |
| `-keepaspect` | Preserve the original screen proportions; black bars are expected |

For fullscreen, replace `-window` with `-nowindow`. For crisp, visibly square pixels, replace `-filter` with `-nofilter`. These options scale and filter the original image; they do not increase model detail.

#### Controls

| Action | Default key |
| --- | --- |
| Move / jump / crouch | Arrow keys |
| Player 1 button 1 | Left Control |
| Player 1 button 2 | Left Option (Alt) |
| Player 1 button 3 | Space |
| Insert coin | `5` on the number row |
| Start player 1 | `1` on the number row |
| Pause / resume | `P` |
| Open settings | Tab |
| Toggle fullscreen | Left Option + Return |
| Toggle smoothing with SDL OpenGL | Left Option + F10 |
| Show emulation speed | F11 |
| Quit / back out of a menu | Esc |

On a Mac keyboard, function-key shortcuts may require holding Fn as well.

The game has three actions: **Guard, Punch, and Kick**. Check which action each numbered button performs in play before assigning your preferred layout.

To make the buttons easier to reach:

1. While the game runs, press **Tab**.
2. Open **Input Settings → Input Assignments (this system)**. Menu wording can vary with MAME versions.
3. Find **P1 Button 1**, press Return, then press **A**.
4. Repeat for **P1 Button 2 → S** and **P1 Button 3 → D**.
5. Keep the arrow keys for movement and press Esc to return to the game.

If an assignment retains an unwanted alternative, clear it with Delete (or Fn + Delete, depending on the keyboard), then assign the desired key again. Verify the displayed binding before leaving the menu.

When the power gauge is full, press **Guard + Punch + Kick together** to activate the power-up. With the default bindings, that is **Left Control + Left Option + Space**; with the suggested bindings, use **A + S + D**.

The [player-written move guide](https://gamefaqs.gamespot.com/ps/572988-heavens-gate/faqs/11381) includes character moves and the power-up combination. It covers the PlayStation version, so some details may differ from the arcade game.

#### Practising combos

A built-in training mode has not been confirmed for the arcade version. Try a two-player match with player 2 left idle as a practice opponent:

1. Press **5** and **6** to add credits for players 1 and 2.
2. Press **1** to start, then **2** to join as player 2.
3. Select both fighters. Check **Tab → Input Settings → Input Assignments (this system)** for player 2's movement and button assignments if needed.
4. Leave player 2's controls alone and practise moves and combos with player 1.

This is a normal versus match, so health and the round timer still apply. It does not provide an invincible training dummy or automatically reset positions.

The **PlayStation version** has a dedicated **Training** mode, documented in the [move guide](https://gamefaqs.gamespot.com/ps/572988-heavens-gate/faqs/11381). Using it would require a separate PlayStation emulator setup and a PlayStation copy of the game; it is not a mode enabled by a MAME graphics or input option.

#### Saving settings

Quit normally with Esc so MAME saves changes.

- Assignments under **this system** apply to Heaven's Gate and are saved in `cfg/hvnsgate.cfg`.
- Assignments under **general** apply across games and are saved in `cfg/default.cfg`.
- Keep `cfg/` and `nvram/` when backing up this setup.
- Launch graphics flags apply to that run. Reuse the recommended command for the same appearance each time.

#### Troubleshooting

Check the ROM set without starting the game:

```sh
cd ~/Projects/emu
export GAME_PATH=~/Projects/emu/games/heavens-gate
export GAME_NAME=hvnsgate
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -verifyroms
```

The downloaded set passed verification during initial setup. A warning about `78081g503.ic655` saying **NO GOOD DUMP KNOWN** is expected with this set; MAME accepted it as **best available** and reported the ROM set as OK.

If other required files are missing, check that both ZIPs are in the same game folder, have their original names, and are compatible with the installed MAME version. Renaming an unrelated ROM set will not make it compatible.

If controls seem to have reset, confirm you launched from `~/Projects/emu`. If the game is running slowly, F11 shows the emulation speed; it should generally stay around 100%.

### Additional games

Start with **Cadillacs and Dinosaurs**, **Tekken 3**, and **Street Fighter II: Champion Edition**, then explore the other adventures. Download and verification instructions follow for every arcade game on the shortlist.

| Game | MAME short name | Suggested folder under `games/` |
| --- | --- | --- |
| Cadillacs and Dinosaurs | `dino` | `cadillacs-and-dinosaurs` |
| Tekken 3 | `tekken3` | `tekken-3` |
| Street Fighter II: Champion Edition | `sf2ce` | `street-fighter-2` |
| Final Fight | `ffight` | `final-fight` |
| Golden Axe | `goldnaxe` | `golden-axe` |
| The King of Dragons | `kod` | `the-king-of-dragons` |
| Knights of the Round | `knights` | `knights-of-the-round` |
| Dungeons & Dragons: Shadow over Mystara | `ddsom` | `shadow-over-mystara` |
| Alien vs. Predator | `avsp` | `alien-vs-predator` |

These short names were checked against the installed MAME. Each game needs its own compatible ROM set and any required dependencies. Tekken 3 is marked as having imperfect graphics emulation, and save states are not supported in the installed version.

#### Download and run any game

The links below are Planet Emulation pages for merged MAME sets. Use the Download section with JavaScript enabled. These are third-party sources; their distribution permissions have not been verified, and downloaded contents still need local verification.

Keep all ZIPs compressed and retain their original filenames. Create the game's folder if needed, then place its game ZIP **and all required BIOS/device ZIPs in the same folder**. Use the main merged game download linked below, rather than an individual clone or bootleg.

Each game section sets both variables and includes a complete launch command. After setting the variables, this command checks the files without launching the game:

```sh
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -verifyroms
```

The default below is OpenGL with smoothing. Try `-nofilter` for sharper pixels in the 2D games, or replace `-window` with `-nowindow` for fullscreen.

#### Cadillacs and Dinosaurs

Download both [dino.zip](https://www.planetemu.net/en/rom/mame-roms-merged/dino) and [qsound_hle.zip](https://www.planetemu.net/en/rom/mame-roms-merged/qsound-hle). The second ZIP provides required sound-device data.

Place both in `games/cadillacs-and-dinosaurs/`:

```sh
cd ~/Projects/emu
export GAME_NAME=dino
export GAME_PATH="$PWD/games/cadillacs-and-dinosaurs"
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -window -video opengl -filter -keepaspect
```

**Play:** arrow keys move; **P1 Button 1** attacks and **P1 Button 2** jumps. Default keys are **Left Control** and **Left Option**. For easier play, map them to **A** and **S** under **Tab → Input Settings → Input Assignments (this system)**. Press both together for the special attack, which can cost health.

#### Tekken 3

Download [tekken3.zip](https://www.planetemu.net/en/rom/mame-roms-merged/tekken3) into `games/tekken-3/`. The selected set has no separate BIOS/device ROM ZIP requirement in the installed MAME.

```sh
cd ~/Projects/emu
export GAME_NAME=tekken3
export GAME_PATH="$PWD/games/tekken-3"
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -window -video opengl -filter -keepaspect
```

**Play:** use the arrow keys to move and four attack buttons for the fighter's left/right punches and kicks. The default keys for **P1 Buttons 1–4** are **Left Control, Left Option, Space, Left Shift**.

Suggested remapping: **Button 1 → A, Button 2 → S, Button 3 → Z, Button 4 → X**. Test the attacks to identify the limb assigned to each button. Set these under **Tab → Input Settings → Input Assignments (this system)** and keep the arrow keys for movement. Hold the direction away from your opponent to guard; Tekken does not use Heaven's Gate's dedicated guard button.

Use this arcade version for normal matches; the PlayStation version's extra modes are not included. Graphics emulation is marked imperfect, and MAME save states are unsupported for this game in the installed version.

#### Street Fighter II: Champion Edition

Download [sf2ce.zip](https://www.planetemu.net/en/rom/mame-roms-merged/sf2ce) into `games/street-fighter-2/`. The selected set has no separate BIOS/device ROM ZIP requirement in the installed MAME.

```sh
cd ~/Projects/emu
export GAME_NAME=sf2ce
export GAME_PATH="$PWD/games/street-fighter-2"
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -window -video opengl -filter -keepaspect
```

**Play:** arrow keys move, Up jumps, and Down crouches. Hold away from the opponent to block; hold down-and-away to block low attacks. There are six attack buttons:

| MAME input | Action | Default key | Suggested key |
| --- | --- | --- | --- |
| P1 Button 1 | Light punch | Left Control | A |
| P1 Button 2 | Medium punch | Left Option | S |
| P1 Button 3 | Heavy punch | Space | D |
| P1 Button 4 | Light kick | Left Shift | Z |
| P1 Button 5 | Medium kick | Z | X |
| P1 Button 6 | Heavy kick | X | C |

Remap all six under **Tab → Input Settings → Input Assignments (this system)**. With Ryu or Ken, try a quarter-circle from Down toward your opponent, followed by a punch, for a fireball. Forward/back directions reverse when you switch sides.

#### Final Fight

Download [ffight.zip](https://www.planetemu.net/en/rom/mame-roms-merged/ffight) into `games/final-fight/`. No separate BIOS/device ROM ZIP is required for this set in the installed MAME.

```sh
cd ~/Projects/emu
export GAME_NAME=ffight
export GAME_PATH="$PWD/games/final-fight"
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -window -video opengl -filter -keepaspect
```

#### Golden Axe

Download [goldnaxe.zip](https://www.planetemu.net/en/rom/mame-roms-merged/goldnaxe) into `games/golden-axe/`. No separate BIOS/device ROM ZIP is required for this set in the installed MAME.

```sh
cd ~/Projects/emu
export GAME_NAME=goldnaxe
export GAME_PATH="$PWD/games/golden-axe"
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -window -video opengl -filter -keepaspect
```

#### The King of Dragons

Download [kod.zip](https://www.planetemu.net/en/rom/mame-roms-merged/kod) into `games/the-king-of-dragons/`. No separate BIOS/device ROM ZIP is required for this set in the installed MAME.

```sh
cd ~/Projects/emu
export GAME_NAME=kod
export GAME_PATH="$PWD/games/the-king-of-dragons"
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -window -video opengl -filter -keepaspect
```

#### Knights of the Round

Download [knights.zip](https://www.planetemu.net/en/rom/mame-roms-merged/knights) into `games/knights-of-the-round/`. No separate BIOS/device ROM ZIP is required for this set in the installed MAME.

```sh
cd ~/Projects/emu
export GAME_NAME=knights
export GAME_PATH="$PWD/games/knights-of-the-round"
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -window -video opengl -filter -keepaspect
```

#### Dungeons & Dragons: Shadow over Mystara

Download both [ddsom.zip](https://www.planetemu.net/en/rom/mame-roms-merged/ddsom) and [qsound_hle.zip](https://www.planetemu.net/en/rom/mame-roms-merged/qsound-hle) into `games/shadow-over-mystara/`.

You can copy the existing `qsound_hle.zip` from the Cadillacs and Dinosaurs folder instead of downloading it again. Keep a copy alongside each game's ZIP with this per-game folder setup.

```sh
cd ~/Projects/emu
export GAME_NAME=ddsom
export GAME_PATH="$PWD/games/shadow-over-mystara"
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -window -video opengl -filter -keepaspect
```

#### Alien vs. Predator

Download both [avsp.zip](https://www.planetemu.net/en/rom/mame-roms-merged/avsp) and [qsound_hle.zip](https://www.planetemu.net/en/rom/mame-roms-merged/qsound-hle) into `games/alien-vs-predator/`. As above, you can reuse a copy of the existing QSound ZIP.

```sh
cd ~/Projects/emu
export GAME_NAME=avsp
export GAME_PATH="$PWD/games/alien-vs-predator"
mame "${GAME_NAME}" -rompath "${GAME_PATH}" -window -video opengl -filter -keepaspect
```

#### Inputs for the additional games

Configure inputs under **this system** for each game. Tekken 3 uses four attack buttons; Street Fighter II uses six, so the Heaven's Gate three-button layout is insufficient. A suggested keyboard layout is **A/S on the top row and Z/X below** for Tekken, and **A/S/D above Z/X/C** for Street Fighter II. Check each displayed button assignment when mapping them.

For the other adventures, use the arrow keys and map the numbered buttons as follows. The button counts below are taken from the installed MAME's input definitions; an exposed input is not necessarily used for a separate action in every game.

| Game | Exposed P1 buttons | Suggested keys for Buttons 1 onward |
| --- | --- | --- |
| Cadillacs and Dinosaurs | 2 | A, S |
| Final Fight | 3 | A, S, D |
| Golden Axe | 3 | A, S, D |
| The King of Dragons | 2 | A, S |
| Knights of the Round | 2 | A, S |
| Shadow over Mystara | 4 | A, S, D, F |
| Alien vs. Predator | 3 | A, S, D |

Default keys for Buttons 1–4 are **Left Control, Left Option, Space, Left Shift**. Open the input menu to see any action labels and confirm the displayed bindings; existing custom mappings override these defaults. Remapping through **this system** keeps each game's layout separate. These suggested mappings are instructions only; they have not been applied automatically.

For a second player, add credit with **6**, then join with **2**. Configure P2 controls separately, preferably on a controller: the suggested P1 letter keys overlap MAME's default P2 bindings.

ROM verification confirms required files, not playability or performance. Launch and play each game to check controls and graphics on this Mac.

### Zelda adventures (separate console setup)

These are also on the shortlist, but require console-specific setup instructions and game files:

| Game | Original console | Priority |
| --- | --- | --- |
| The Legend of Zelda: A Link to the Past | Super Nintendo | First Zelda adventure |
| The Legend of Zelda: Ocarina of Time | Nintendo 64 | Follow with a 3D adventure |

See [Nintendo's Zelda game history](https://www.nintendo.com/us/explore/characters/zelda/history/) for the original platforms. Console emulation has not yet been configured in this project.

## References

- [MAME default keyboard controls](https://docs.mamedev.org/usingmame/defaultkeys.html)
- [MAME command-line and graphics options](https://docs.mamedev.org/commandline/commandline-all.html)
- [MAME BGFX effects, including CRT monitor filters](https://docs.mamedev.org/advanced/bgfx.html)
