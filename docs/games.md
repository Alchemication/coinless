# Game guide

Where each game's files go, what else it needs, and how its buttons map. Once a game's files are in place, play it from the Coinless app or with `./play <name>`.

## Files

Keep ZIPs compressed and keep their original names: MAME finds games by file name, so renaming a ZIP doesn't change which game it is. Put each game ZIP in its folder under `games/`. Required BIOS/device ZIPs go either in the same folder or once in `games/bios/`.

| Game | Name | Folder under `games/` | Also needs | Saves |
| --- | --- | --- | --- | --- |
| Heaven's Gate (1996) | `hvnsgate` | `heavens-gate` | `coh1001l.zip` (Atlus ZN-1 BIOS) | Yes |
| Cadillacs and Dinosaurs (1993) | `dino` | `cadillacs-and-dinosaurs` | `qsound_hle.zip` | Yes |
| Tekken 3 (1997) | `tekken3` | `tekken-3` | — | No |
| Street Fighter II: Champion Edition (1992) | `sf2ce` | `street-fighter-2` | — | Yes |
| Final Fight (1989) | `ffight` | `final-fight` | — | Yes |
| Golden Axe (1989) | `goldnaxe` | `golden-axe` | — | No |
| The King of Dragons (1991) | `kod` | `the-king-of-dragons` | — | Yes |
| Knights of the Round (1991) | `knights` | `knights-of-the-round` | — | Yes |
| Dungeons & Dragons: Shadow over Mystara (1996) | `ddsom` | `shadow-over-mystara` | `qsound_hle.zip` | Yes |
| Alien vs. Predator (1994) | `avsp` | `alien-vs-predator` | `qsound_hle.zip` | Yes |
| Zelda: A Link to the Past (1992, Super Nintendo) | `zelda3u` | `zelda-a-link-to-the-past` | `snes.zip` (the console's sound ROM) | Yes |

Names, dependencies, and save support were checked against MAME 0.289. After a MAME update, run `./play --check` to recheck save support.

### Getting the files

Coinless doesn't provide game files. Use ROM sets you have the right to use, matching your MAME version. `./play --inspect <name>` lists the exact ZIPs a game needs. For example, with the files in Downloads:

```sh
mkdir -p games/cadillacs-and-dinosaurs games/bios
cp ~/Downloads/dino.zip games/cadillacs-and-dinosaurs/
cp ~/Downloads/qsound_hle.zip games/bios/
./play            # Cadillacs should now say "ready"
```

### Checking a ROM set

```sh
mame dino -rompath "games/cadillacs-and-dinosaurs;games/bios" -verifyroms
```

### Console games

MAME also emulates home consoles. A console game is a cartridge from MAME's software list for that console (`share/mame/hash/<system>.xml`), so its `id` is the list's name for it and `games.json` adds `"system"`. For the Super Nintendo:

- The cartridge ZIP is named after its list entry and holds the ROM under the list's file name: `games/zelda-a-link-to-the-past/zelda3u.zip` holds `sns-zl-0.u1`. A plain `.sfc` dump is the same bytes: zip it under that name.
- `games/bios/snes.zip` holds `spc700.rom`, the console's 64-byte sound ROM (`mame snes -listroms`). Every Super Nintendo game shares it.
- `./play --check` checks the cartridge against the software list (`mame snes -verifysoftware`).
- Saves: the resume point is `sta/<id>/snes/auto.sta`, one folder per game. The game's own saves (battery memory) are `nvram/snes/<id>.nv`.
- Controls: [launcher/pads.cfg](../launcher/pads.cfg) maps the PS4 pad by position: ✕ B, ○ A, □ Y, △ X, L1 L, R1 R, Options Start, Share Select. Keys: A S D F G H for Y B A X L R, 1 Start, 5 Select (player 2: Q W E R T Y, 2, 6). Every Super Nintendo game shares the layout; changes in MAME's menu are saved in `cfg/snes.cfg`.

This confirms the files MAME needs, not playability. Known result: Heaven's Gate warns that `78081g503.ic655` has **NO GOOD DUMP KNOWN**. MAME accepts it as the best available dump and reports the set as OK.

## Controls

Every game works from the keyboard and a PS4 pad without setup. [launcher/pads.cfg](../launcher/pads.cfg) holds Coinless's layouts, and MAME treats them as its defaults:

| | Move | Buttons 1–6 | Start | Coin |
| --- | --- | --- | --- | --- |
| Player 1 keys | arrows | A S D F G H | 1 | 5 |
| Player 1 pad | D-pad or left stick | □ ✕ ○ △ L1 R1 | Options | Share |
| Player 2 keys | I J K L | Q W E R T Y | 2 | 6 |
| Player 2 pad | second pad, same layout | | | |

So attack is □ and jump ✕, as on PlayStation releases of these games. Most games need nothing more; a game with its own standard layout (Tekken, Street Fighter) gets its own section in `pads.cfg`. **Tab** opens MAME's menu, **P** pauses, **F11** shows emulation speed (hold Fn on a Mac keyboard), and **Esc** quits.

To change a layout for yourself, use **Tab → Input Settings → Input Assignments**: **(this system)** for one game (saved in `cfg/<game>.cfg`; a console's games share `cfg/<system>.cfg`), **(general)** for every game (`cfg/default.cfg`). Your changes win over `pads.cfg`. Quit with Esc so MAME saves them. To clear an unwanted extra binding, select it and press Delete, then assign again.

| Game | Buttons | Keys | Pad | Actions (confirm in play) |
| --- | --- | --- | --- | --- |
| Heaven's Gate | 3 | A, S, D | □ ✕ ○ | Guard, punch, kick |
| Cadillacs and Dinosaurs | 2 | A, S | □ ✕ | Attack, jump; both together for a special that costs health |
| Tekken 3 | 4 | A, S / Z, X | □ △ / ✕ ○ | Left punch, right punch, left kick, right kick. Hold back to guard |
| Street Fighter II | 6 | A, S, D / Z, X, C | □ △ R1 / ✕ ○ L1 | Light, medium, heavy punch / light, medium, heavy kick |
| Final Fight | 3 | A, S, D | □ ✕ ○ | Attack, jump |
| Golden Axe | 3 | A, S, D | □ ✕ ○ | Magic, attack, jump |
| The King of Dragons | 2 | A, S | □ ✕ | Attack, jump |
| Knights of the Round | 2 | A, S | □ ✕ | Attack, jump |
| Shadow over Mystara | 4 | A, S, D, F | □ ✕ ○ △ | Attack, jump, select item, use item |
| Alien vs. Predator | 3 | A, S, D | □ ✕ ○ | Attack, jump, shoot |
| Zelda: A Link to the Past | SNES pad | A S D F G H for Y B A X L R | by position: □ Y, ✕ B, ○ A, △ X | ✕ sword, ○ action, □ item, △ map |

The button counts come from MAME's input definitions; an exposed button isn't always a separate action. Player 2 uses the same pad layout on the second pad.

A game's own section in `pads.cfg` names each button by its port tag, mask and default value, exactly as MAME has them; a mismatch is silently ignored. Dump them with a Lua script in a sandbox (`manager.machine.ioport.ports`), and check the result the same way.

## Game notes

### Heaven's Gate

When the power gauge is full, press **guard + punch + kick together** for the power-up. See the [move guide](https://gamefaqs.gamespot.com/ps/572988-heavens-gate/faqs/11381); it covers the PlayStation version, so some details may differ.

The arcade version has no confirmed training mode. To practise, add two credits (**5**, **6**), start both players (**1**, **2**), and leave player 2 idle. Health and the round timer still apply. The PlayStation version's Training mode would need a separate PlayStation emulator setup.

### Tekken 3

MAME marks the graphics as imperfect and can't save this game. This is the arcade version, so the PlayStation extras aren't included.

### Street Fighter II

Up jumps and down crouches. Hold away from your opponent to block, and down-away to block low. With Ryu or Ken, roll down to forward, then punch, for a fireball. Directions flip when you switch sides.

### Zelda: A Link to the Past

Sword on ✕, action (lift, talk, read) on ○, the equipped item on □, the map on △. Options opens the item screen. The game saves itself: press Share for **SAVE AND QUIT**, or pick **SAVE AND CONTINUE** at game over; it keeps three files in `nvram/snes/zelda3u.nv`. Coinless's resume point comes on top, so quitting with Options + Share puts you back exactly where you were. New game sets only the resume point aside; the game's own files stay.

*Ocarina of Time* (Nintendo 64) isn't possible yet: MAME's Nintendo 64 driver is preliminary and can't save states.

## Adding a new game by hand

An agent can do all of this with the `add-game` skill. By hand: run `./play --inspect "<title>"`, add its suggested entry to [launcher/games.json](../launcher/games.json) and fill in the TODOs. The app reads the catalog at every refresh, so no rebuild is needed.

| Field | Meaning |
| --- | --- |
| `id` | MAME short name, also the ZIP name without `.zip` |
| `folder` | Folder under `games/` |
| `title`, `subtitle`, `genre`, `year`, `players`, `note` | Text shown in the library |
| `symbol` | [SF Symbol](https://developer.apple.com/sf-symbols/) shown before a preview exists |
| `color` | Accent colour, hex without `#` |
| `saveStates` | Whether MAME can save this game (`./play --check` compares it with MAME) |
| `requires` | Optional. Extra BIOS/device ZIPs without `.zip`, e.g. `["qsound_hle"]` |
| `previewAt` | Optional. Seconds of attract mode before the preview is captured (default 50) |
| `system` | Console games only. MAME's name for the console, e.g. `"snes"`; `requires` then lists it too |

Optional extras: facts in `launcher/facts/<id>.json` (`game-facts` skill) and your own picture at `art/<id>/cover.png`.
