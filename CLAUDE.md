## Rules

Build with `zsh launcher/build.sh`: it compiles `launcher/Sources/*.swift` with
`swiftc`, signs `Coinless.app` for this Mac, and runs `--check`. There is no
Xcode project, Swift package or dependency; keep it that way.

The player's files are not ours: `games/`, `cfg/`, `nvram/`, `sta/` and
`art/<game>/cover.*` hold Adam's ROMs, controls, machine data, saves and
pictures. Never edit, move or delete them. Any MAME run that isn't Adam
playing (previews, smoke tests, experiments) gets a temporary folder for
`-cfg_directory`, `-nvram_directory`, `-state_directory`,
`-snapshot_directory` and `-diff_directory`, plus `-noreadconfig`, and works
on a *copy* of a save. Check a save is byte-identical (`md5`) after anything
near `sta/`.

The project folder stays `emu` (Claude Code sessions are keyed by its path);
the product is Coinless.

Work on `main`, and commit and push there directly: it's a personal toy
project, so no branches or pull requests. Commit when asked, with the
build and checks below green.

## Project

Coinless is Adam's personal, native macOS front end for Homebrew MAME,
for arcade games from the couch: PS4 controllers, a TV, an Apple Silicon
Mac. Tagline: *No more CONTINUE? 9… 8… 7…* It also makes MAME pleasant from
Terminal (`./play`). It is not distributed, and ROMs never go in Git.

**Great UX is the priority.** The look is modern meets retro: round CRT
screens with scanlines and a marquee, a blurred backdrop, spring motion,
tint-matched buttons. Everything must work from the controller alone, read
from across a room, and never lose a save. Prefer the delightful,
couch-friendly option over the minimal one.

How it fits together:

- `launcher/games.json` is the catalog, read from the project at runtime
  (no rebuild). A game appears when `games/<folder>/<id>.zip` exists.
- `Library.arguments` builds every MAME command line. The app and `./play`
  both use it; never assemble MAME arguments anywhere else.
- `Preferences` (UserDefaults, domain `local.emu.coinless`) is shared by the
  app and `./play`.
- MAME always runs from the project root, so its relative `cfg/` and
  `nvram/` stay put.
- Pictures in `art/<game>/`: `resume.png` (rendered from a copy of the save
  that will be resumed), `cover.png` (Adam's), `attract.png` (headless MAME,
  `-seconds_to_run`). `art/` is generated except covers.

MAME facts this code depends on (checked on 0.289):

- `-autosave` loads `auto.sta` by itself; `-state <slot>` is only for a
  manual slot and wins over autosave.
- SIGTERM is a clean exit: MAME still writes `auto.sta`. Quitting Coinless
  mid-game relies on this.
- `-seconds_to_run` saves a snapshot when it ends; with `-video none` this
  is how previews are captured.
- `bgfx_path` and `artpath` default to folders relative to the working
  directory, so the CRT style passes MAME's `share/mame` paths explicitly.
- Exit codes: 2 missing files, 5 unknown system, 6 bad configuration.
- `saveStates` in `games.json` must match `mame <id> -listxml`
  (`savestate="supported"`); `--check` compares them.

## Collaboration Style

Challenge my ideas early. If an approach is over-engineered, fragile, or has a
simpler alternative, say so directly with reasoning. Flag knowledge gaps,
hidden trade-offs, or narrowed thinking. Be pragmatic.

**Prose:** terse, no pleasantries / hedging / filler. Fragments fine. Full
sentences for warnings, destructive-op confirmations, and commit messages.

**Honesty about testing:** controllers, the TV, real full screen and sound
can't be tested from a session. Say what was verified and what Adam should
try on the couch.

## Documentation

| File | What it holds |
|---|---|
| `README.md` | What Coinless is, setup, controls, saves, pictures, `./play`, adding games, troubleshooting, layout. |
| `launcher/facts/<id>.json` | Researched facts per game, shown in the library ticker and by `./play`. Written with `game-facts`. |
| `docs/games.md` | Per game: folder, BIOS/device files, save support, downloads, ROM checks, button layouts, notes. |
| `CLAUDE.md` / `AGENTS.md` | Working rules (this file). |
| `.claude/skills/*/SKILL.md` | Procedures: `game-tips` (coaching, with `references/<game>.md` per game), `game-facts` (research a game into `launcher/facts/`). |
| `LICENSE` | MIT. Coinless runs MAME as a separate program and bundles no MAME code, ROMs or game content. |

Keep `AGENTS.md` and `CLAUDE.md` identical. When editing either, update both.
Adding, renaming or removing a doc updates this table and README's layout.

Skills live in `.claude/skills/` (Claude Code). `.agents/skills` is a
symlink to it, for Codex and other agents; never make it a real folder or
copy a skill. Each skill keeps `name` and `description` frontmatter, and the
description says when to use it. `agents/openai.yaml` is optional
Codex/OpenAI metadata.

Docs describe current behaviour, not history or plans. A change to controls
updates README's controls table, the footer hints (`LibraryView`) and the
settings text (`HelpView`) together. A change to `./play` updates
`CLI.usage` and README together.

## Code Style

- **Platform:** Swift with SwiftUI, AppKit and GameController only, macOS 14+.
  Must also type-check cleanly in Swift 6 strict-concurrency mode. The model
  is `@MainActor`; blocking work (MAME runs) goes in a detached task.
- **Files by job** (`launcher/Sources/`), each well under ~400 lines:
  `Library` (paths, catalog, MAME arguments, `Preferences`), `ArcadeModel`
  (state, launching, saves, previews), `Input` (pad, keyboard, trackpad),
  `Previews` (headless captures), `Facts` (facts format and checks),
  `LibraryView` / `Disc` / `FactTicker` / `HelpView` (UI),
  `App` (window, menus, lifecycle), `CLI` (`./play`), `Catalog` (`Game`,
  `Theme`). A new job gets a new file; `build.sh` picks it up.
- **Input:** every control routes through the verbs in `Input.swift`
  (`handle(direction)`, `confirm`, `back`, `newGame`, `refresh`), so pad,
  keyboard, mouse and help panel stay consistent. A new action is a verb,
  then its button, key, footer hint and README row.
- **Look:** colours live in `Theme` (`Catalog.swift`), never inline.
  Monospaced caps with tracking for labels, rounded heavy for titles. Size
  for a TV across the room. Animate state changes (`withAnimation`, springs
  for movement); no hard cuts.
- **Errors the player sees** are a `Notice`: a title saying what happened and
  a message saying what to do next, in plain words. Never a raw exit code
  alone.
- **Destructive actions** need a second press (New game) and keep a backup
  (`auto.sta.bak`).
- **Facts** stay short (`GameFacts.maxLength`, 140 characters), sourced,
  and about the arcade version. The ticker never needs a press: anything
  added there must work hands-off.
- **Catalog changes** keep `Library.validate` strict: a bad `games.json`
  fails with a message naming the entry.
- **Licence:** MIT. Never vendor MAME code, ROMs, BIOS files, game art or
  long copied text; link to sources instead.
- **No backward-compat shims:** when moving code, update all callers. One
  exception: `Preferences.migrateFromArcade` (settings from the old app name).

## Output Rules (`./play`)

- Normal output to stdout; errors to stderr as `error: <what to do>`, exit 1.
- Colour only on a TTY and without `NO_COLOR`.
- A launch prints the full `mame` command it runs, so it can be copied.

## Verification

Before reporting done:

- `zsh launcher/build.sh`: compiles, signs, and runs `--check` (catalog,
  BIOS files, argument self-test, `saveStates` against MAME).
- Swift 6 check:
  `xcrun swiftc -parse-as-library -typecheck -swift-version 6 launcher/Sources/*.swift`
- `./Coinless.app/Contents/MacOS/Coinless --smoke-test`: launches and quits
  Cadillacs headlessly in a sandbox.
- MAME arguments changed: `./play <game> --dry-run` for the affected modes.
- UI changed: `./Coinless.app/Contents/MacOS/Coinless --preview [game]`,
  then look at `launcher/.build/preview.png`. It briefly opens a window.
- After moves or renames, grep for stale paths and names.

## Adding a game

1. Entry in `launcher/games.json` (fields in README). Check the short name,
   `saveStates` and BIOS/device ZIPs against `mame <id> -listxml`
   (`romof`, and referenced devices that have ROMs). Optional I/O boards
   don't go in `requires`.
2. Row in `docs/games.md` (files, download, buttons).
3. `references/<game>.md` in the `game-tips` skill, and a line in its
   `SKILL.md`.
4. Facts: `launcher/facts/<id>.json`, with the `game-facts` skill.
   `./play --check` flags a game without them.
5. Once the ZIP is in place: `./play --check`, `./play --previews`, then
   look at `art/<id>/attract.png`. Set `previewAt` if the moment is dull.
