---
name: setup
description: First-time setup of Coinless on a Mac, or a rebuild after pulling changes. Checks Homebrew, MAME and Apple's command-line tools, builds and checks Coinless.app, then hands over to add-game. Use when the user asks to set up, install, build or get Coinless running, or when Coinless.app is missing.
---

# Set up Coinless

Goal: Coinless.app built and opening, with the user knowing how to add games. Ask before installing anything.

## 1. Tools

- `command -v brew`. Missing: point the user to https://brew.sh (its installer needs their password, so they run it), then continue.
- `command -v mame`. Missing: offer `brew install mame`, and run it if they agree.
- `xcrun swiftc --version`. Missing: ask them to run `xcode-select --install` and finish Apple's installer.

## 2. Build

```sh
zsh launcher/build.sh
```

It compiles, signs and runs `--check`. "No installed games found" is expected on a fresh clone: say so, don't treat it as a failure.

## 3. Games

Coinless ships no games. Run `./play` to show the catalog, then ask which games they want, and follow the `add-game` skill for each. The user supplies the game files and is responsible for having the right to use them; never download ROMs or BIOS files yourself.

## 4. Hand over

- `open Coinless.app`. Suggest dragging it to the Dock; it must stay in the project folder.
- Back to the library from a game: hold Options + Share (Coinless handles it; no MAME setup). Optional quick saves, set by the user in MAME: Tab → Input Settings → Input Assignments (general) → User Interface → Save State (Quick) to L3, Load State (Quick) to R3.
- Remind them to back up `cfg/`, `nvram/` and `sta/`; Git doesn't hold them.

## After pulling changes

Rebuild with `zsh launcher/build.sh`. If `--check` warns, fix or explain each line.
