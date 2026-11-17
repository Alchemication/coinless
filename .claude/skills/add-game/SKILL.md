---
name: add-game
description: Add an arcade game to Coinless end to end: find the right MAME set, place and verify the user's ZIPs, write the games.json entry, capture previews, research facts and tips, and update docs. Use when the user wants to add, install or set up a game, or asks what files a game needs.
---

# Add a game

Done means: the game shows in the library with a preview, facts and tips, `./play --check` is clean, and the docs list it. Ask the user only for choices and files; work out everything else.

## 1. Find the set

```sh
./play --inspect "<title>"     # search; lists parent sets only
./play --inspect <name>        # details for one short name
```

Pick the parent set of the main release; if regions or versions differ in a way that matters, ask. Prefer a game with emulation status "good". `--inspect` gives the files needed, save support, players and buttons, and a games.json draft. If it says the game is already in the catalog, skip step 3's entry and just install the files.

## 2. Files

The user supplies the files and is responsible for having the right to use them. Never download ROMs or BIOS files yourself, and don't suggest download sites. Tell them exactly which ZIPs `--inspect` listed, and ask where they are (usually `~/Downloads`).

- Game ZIP → `games/<folder>/<id>.zip`. Extra ZIPs (BIOS, devices) → `games/bios/`, unless already there.
- Copy, don't rename. Keep ZIPs compressed.
- Verify: `mame <id> -rompath "games/<folder>;games/bios" -verifyroms`. "NO GOOD DUMP KNOWN" is fine when the set is reported OK. Anything missing or wrong: tell the user which file, and stop.

## 3. Catalog

Add the draft to `launcher/games.json`, next to games of the same kind, and fill every TODO:

- `title`: the name people know, without MAME's version note or subtitle clutter. `folder`: its lowercase dashed form.
- `subtitle`: a short, warm tagline (under ~45 characters), like the others.
- `genre`: caps, like the others (`2D FIGHTING`, `CO-OP BEAT ’EM UP`).
- `symbol`: an SF Symbol that fits and isn't already used. `color`: a hex accent that reads on a dark background and differs from the others.
- `note`: one plain line on how to play.
- Keep `saveStates` and `requires` exactly as `--inspect` reported.

## 4. Facts and tips

- Follow the `game-facts` skill for `launcher/facts/<id>.json`.
- Follow the `game-tips` conventions: add `references/<folder>.md` and a line in its `SKILL.md`.

## 5. Docs

`docs/games.md`: a row in the Files table and the Controls table.

## 6. Check

```sh
./play --check                 # catalog, files, saves, requires and facts against MAME
./play --previews              # capture the attract picture now
./Coinless.app/Contents/MacOS/Coinless --preview <id>
```

Look at `art/<id>/attract.png`; if it's a dull or black frame, set `previewAt` (seconds) in games.json, delete the picture and capture again. Then look at `launcher/.build/preview.png`. Finally, `./play <id> --dry-run`, and suggest the user tries it.
