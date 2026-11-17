# Coinless

*No more CONTINUE? 9… 8… 7…*

Remember digging through your pockets while the countdown ran out? Coinless is a native Mac front end for [MAME](https://www.mamedev.org/), made for playing arcade games from the couch with a PS4 controller, keyboard or trackpad. Quit a game and you're back in the library, with your place saved.

- **Round CRT screens** showing where you left off, or a frame from the game's attract mode.
- **Stories behind the games:** short, sourced facts, tips and combos turn over under the Play button. No clicks needed.
- **Resume or start over:** supported games save when you quit and resume next time.
- **Couch-first:** everything works from the controller, settings included.
- **Terminal too:** `./play dino` launches with the same settings and shows the MAME command.

Coinless ships no games. You add the ones you want, using game files you have the right to use.

## Setup

**With a coding agent (easiest).** Open this folder in Claude Code, Codex or another coding agent and say:

> Set up Coinless

then, for each game:

> Add Final Fight

The agent follows the project's skills (`.claude/skills/`): `setup` checks MAME and Apple's tools and builds the app; `add-game` finds the right MAME set, tells you which ZIPs to provide, verifies them, and adds pictures, facts and tips.

**By hand.**

```sh
brew install mame                     # needs Homebrew: https://brew.sh
xcode-select --install                # if `xcrun swiftc` is missing
zsh launcher/build.sh                 # builds, signs and checks Coinless.app
./play --inspect "final fight"        # which ZIPs a game needs
open Coinless.app
```

Put each game's ZIP in `games/<folder>/` and BIOS or device ZIPs in `games/bios/`; [docs/games.md](docs/games.md) lists the catalog and explains adding new games. Keep `Coinless.app` in the project folder; drag it to the Dock for one-click access.

## Controls

| Action | PS4 controller | Keyboard | Mouse / trackpad |
| --- | --- | --- | --- |
| Browse | D-pad or left stick | ← → | Swipe; click a side game |
| Play / Resume | ✕ | Return | Click the centre game |
| New game (on a saved game) | □, twice | N, twice | **New game**, twice |
| Next fact (optional) | ↓ ↑ or R1 L1 | ↓ ↑ | Click the fact |
| Settings | Options | ? or ⌘, | Sliders, top right |
| Refresh the library | △ | R | Settings → Refresh games |

**Back to the library from the couch:** in MAME, set a spare controller button once as **Tab → Input Settings → Input Assignments (general) → User Interface → UI Cancel**. Esc works on the keyboard.

**TV:** mirror the display, or make the TV the main display before opening Coinless; games open on the main display.

## Saves

For games MAME can save (`./play` shows which), **quit normally** and your place is saved to `sta/<game>/auto.sta`; next time, **Resume**. New game keeps the old save as `auto.sta.bak`. Quitting Coinless mid-game still saves. Turn saving off in Settings.

For saves during play, set **Save State (Quick)** and **Load State (Quick)** in MAME's User Interface list, e.g. L3 and R3.

Back up `cfg/`, `nvram/` and `sta/` yourself; Git doesn't hold them.

## Terminal

```sh
./play                       # your games, what's missing, which have saves
./play dino                  # play (names can be shortened: ./play cad)
./play sf2ce --style crt     # smooth, sharp or crt; also --window, --fresh, --no-save
./play --facts tekken3       # every fact, with sources
./play --inspect mslug       # what MAME needs for a game
./play --check               # check MAME, the catalog and your files
./play --help                # everything else
```

## Troubleshooting

- **A game is missing:** `./play` shows the expected file and any missing BIOS, then refresh with △ or R.
- **MAME says files are missing:** `mame <id> -rompath "games/<folder>;games/bios" -verifyroms`.
- **A game closes with an error:** Coinless shows why; the full output is in `launcher/.build/mame-last.log`.
- **The controller stops responding after a game:** press any button within 20 seconds, or click the Coinless window.

## Licence

MIT (see [LICENSE](LICENSE)). Coinless contains no MAME code: it runs your separately installed `mame`, which has its own [licence](https://docs.mamedev.org/license.html). It includes no ROMs, BIOS files or game content; obtaining them, and the right to use them, is up to you. Facts are short summaries that link to their sources.

Working on Coinless itself? [CLAUDE.md](CLAUDE.md) has the layout, rules and checks.
