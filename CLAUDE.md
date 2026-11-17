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

Adam's checkout is a folder named `emu` (Claude Code sessions are keyed by
its path), a fresh clone is `coinless`; the product is Coinless either way.
Never hard-code either name: find the project from paths, as `Library` does.

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
| `README.md` | For players: what Coinless is, setup (agent or by hand), controls, saves, `./play`, troubleshooting, licence. Keep it short. |
| `launcher/facts/<id>.json` | Researched facts per game, shown in the library ticker and by `./play`. Written with `game-facts`. |
| `site/` | The public site, https://alchemication.github.io/coinless/: one page (`index.html`, `assets/site.css`), published by `.github/workflows/pages.yml` on every push to `main` that touches it, after `site/check.py`. |
| `site/images/` | Images shared by the README and the site (arcade, terminal, coinless, link preview, icons), rendered by `launcher/Tools/readme-images.sh` (never edit by hand). `arcade.png` is original pixel art, drawn in `ReadmeArt.swift`. |
| `docs/games.md` | The catalog: folders, BIOS/device files, save support, ROM checks, button layouts, game notes, adding a game by hand (catalog fields). |
| `CLAUDE.md` / `AGENTS.md` | Working rules (this file). |
| `.claude/skills/*/SKILL.md` | Procedures: `setup` (first install, rebuilds), `add-game` (a game end to end), `game-facts` (research into `launcher/facts/`), `game-tips` (coaching, `references/<game>.md` per game). |
| `LICENSE` | MIT. Coinless runs MAME as a separate program and bundles no MAME code, ROMs or game content. |

Keep `AGENTS.md` and `CLAUDE.md` identical. When editing either, update both.
Adding, renaming or removing a doc or file updates this table and the layout below.

Skills live in `.claude/skills/` (Claude Code). `.agents/skills` is a
symlink to it, for Codex and other agents; never make it a real folder or
copy a skill. Each skill keeps `name` and `description` frontmatter, and the
description says when to use it. `agents/openai.yaml` is optional
Codex/OpenAI metadata.

Docs describe current behaviour, not history or plans. A change to controls
updates README's controls table, the footer hints (`LibraryView`) and the
settings text (`HelpView`) together. A change to `./play` updates
`CLI.usage` and README together.

## Layout

```text
play                     ./play: Terminal launcher (thin wrapper around the app's CLI)
launcher/
  Sources/*.swift        the app (files by job, below)
  facts/<id>.json        researched facts per game
  games.json             the catalog
  Tools/Icon.swift       app icon generator
  Tools/readme-images.sh README images (ReadmeArt.swift draws the Terminal one)
  Info.plist, build.sh
docs/games.md            catalog, files, controls
site/                    the public site (index.html, assets/, images/, check.py)
.github/workflows/       pages.yml publishes site/
.claude/skills/          agent skills (.agents/skills links here)
Coinless.app/            generated by build.sh
art/                     generated pictures; art/<id>/cover.* is the player's
games/  games/bios/      the player's ROM ZIPs
cfg/  nvram/  sta/       the player's MAME controls, machine data, saves
```

Never commit game files, saves or generated folders; `.gitignore` covers them.

## Code Style

- **Platform:** Swift with SwiftUI, AppKit and GameController only, macOS 14+.
  Must also type-check cleanly in Swift 6 strict-concurrency mode. The model
  is `@MainActor`; blocking work (MAME runs) goes in a detached task.
- **Files by job** (`launcher/Sources/`), each well under ~400 lines:
  `Library` (paths, catalog, MAME arguments, `Preferences`), `ArcadeModel`
  (state, launching, saves, previews), `Input` (pad, keyboard, trackpad),
  `Previews` (headless captures), `Facts` (facts format and checks),
  `MameInfo` (what MAME says a system needs, for `--inspect` and `--check`),
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
  long copied text; link to sources instead. One exception, Adam's call: the
  site's hero ghosts (`site/images/ghosts/`) are real Street Fighter II and
  Golden Axe stance sprites, shown as a tribute and credited in the footer.
  Adding characters keeps that credit line true.
- **No backward-compat shims:** when moving code, update all callers. One
  exception: `Preferences.migrateFromArcade` (settings from the old app name).

## The site

One page that tells the story (the arcade, MAME in Terminal, Coinless) in
one column: extremely simple, elegant, retro. English only. Plain HTML and
CSS with one small inline script (the countdown); no build step, no
frameworks, nothing loaded from another site (system fonts only), every
colour in `assets/site.css`. Check with `python3 site/check.py` and look at
it in a browser at desktop and phone widths before pushing; a push to
`main` publishes it.

## Output Rules (`./play`)

- Normal output to stdout; errors to stderr as `error: <what to do>`, exit 1.
- Colour only on a TTY and without `NO_COLOR`.
- A launch prints the full `mame` command it runs, so it can be copied.

## Verification

Before reporting done:

- `zsh launcher/build.sh`: compiles, signs, and runs `--check` (catalog,
  BIOS files, argument self-test, `saveStates` and `requires` against MAME,
  facts).
- Swift 6 check:
  `xcrun swiftc -parse-as-library -typecheck -swift-version 6 launcher/Sources/*.swift`
- `./Coinless.app/Contents/MacOS/Coinless --smoke-test`: launches and quits
  Cadillacs headlessly in a sandbox.
- MAME arguments changed: `./play <game> --dry-run` for the affected modes.
- UI changed: `./Coinless.app/Contents/MacOS/Coinless --preview [game]`,
  then look at `launcher/.build/preview.png`. It briefly opens a window.
  A visible change to the library also re-renders the README images:
  `zsh launcher/Tools/readme-images.sh`, then look at both.
- After moves or renames, grep for stale paths and names.

## Adding a game

Follow the `add-game` skill. It covers the set (`./play --inspect`), the
player's files (never download ROMs or BIOS files, never suggest sites;
the player supplies them and is responsible for the right to use them),
`games.json`, facts, tips, docs and checks.
