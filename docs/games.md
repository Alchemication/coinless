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

Names, dependencies, and save support were checked against MAME 0.289. After a MAME update, run `./play --check` to recheck save support.

### Downloads

This setup used Planet Emulation's merged MAME sets. Use each page's Download section (JavaScript required) and pick the main merged set, not a clone or bootleg. These are third-party sources whose distribution rights haven't been verified.

[hvnsgate](https://www.planetemu.net/en/rom/mame-roms-merged/hvnsgate) ·
[coh1001l](https://www.planetemu.net/en/rom/mame-roms-merged/coh1001l) ·
[dino](https://www.planetemu.net/en/rom/mame-roms-merged/dino) ·
[qsound_hle](https://www.planetemu.net/en/rom/mame-roms-merged/qsound-hle) ·
[tekken3](https://www.planetemu.net/en/rom/mame-roms-merged/tekken3) ·
[sf2ce](https://www.planetemu.net/en/rom/mame-roms-merged/sf2ce) ·
[ffight](https://www.planetemu.net/en/rom/mame-roms-merged/ffight) ·
[goldnaxe](https://www.planetemu.net/en/rom/mame-roms-merged/goldnaxe) ·
[kod](https://www.planetemu.net/en/rom/mame-roms-merged/kod) ·
[knights](https://www.planetemu.net/en/rom/mame-roms-merged/knights) ·
[ddsom](https://www.planetemu.net/en/rom/mame-roms-merged/ddsom) ·
[avsp](https://www.planetemu.net/en/rom/mame-roms-merged/avsp)

For example, from Downloads:

```sh
mkdir -p games/cadillacs-and-dinosaurs games/bios
mv ~/Downloads/dino.zip games/cadillacs-and-dinosaurs/
mv ~/Downloads/qsound_hle.zip games/bios/
./play            # Cadillacs should now say "ready"
```

### Checking a ROM set

```sh
mame dino -rompath "games/cadillacs-and-dinosaurs;games/bios" -verifyroms
```

This confirms the files MAME needs, not playability. Known result: Heaven's Gate warns that `78081g503.ic655` has **NO GOOD DUMP KNOWN**. MAME accepts it as the best available dump and reports the set as OK.

## Controls

MAME's default keys: arrows move; **Left Control, Left Option, Space, Left Shift, Z, X** are buttons 1–6; **5** adds a coin and **1** starts (**6** and **2** for player 2). **Tab** opens MAME's menu, **P** pauses, **F11** shows emulation speed (hold Fn on a Mac keyboard), and **Esc** quits.

Remap buttons in **Tab → Input Settings → Input Assignments (this system)** so each game keeps its own layout (saved in `cfg/<game>.cfg`). Assignments under **(general)** apply to every game (`cfg/default.cfg`). Quit with Esc so MAME saves changes. To clear an unwanted extra binding, select it and press Delete, then assign again.

| Game | Buttons | Suggested keys (buttons 1 onward) | Usual actions (confirm in play) |
| --- | --- | --- | --- |
| Heaven's Gate | 3 | A, S, D | Guard, punch, kick (check in play) |
| Cadillacs and Dinosaurs | 2 | A, S | Attack, jump; both together for a special that costs health |
| Tekken 3 | 4 | A, S, Z, X | Left punch, right punch, left kick, right kick. Hold back to guard |
| Street Fighter II | 6 | A, S, D / Z, X, C | Light, medium, heavy punch / light, medium, heavy kick |
| Final Fight | 3 | A, S, D | Attack, jump |
| Golden Axe | 3 | A, S, D | Magic, attack, jump |
| The King of Dragons | 2 | A, S | Attack, jump |
| Knights of the Round | 2 | A, S | Attack, jump |
| Shadow over Mystara | 4 | A, S, D, F | Attack, jump, select item, use item |
| Alien vs. Predator | 3 | A, S, D | Attack, jump, shoot |

The button counts come from MAME's input definitions; an exposed button isn't always a separate action. The suggested letter keys overlap MAME's default player 2 keys, so give player 2 a controller.

## Game notes

### Heaven's Gate

When the power gauge is full, press **guard + punch + kick together** for the power-up. See the [move guide](https://gamefaqs.gamespot.com/ps/572988-heavens-gate/faqs/11381); it covers the PlayStation version, so some details may differ.

The arcade version has no confirmed training mode. To practise, add two credits (**5**, **6**), start both players (**1**, **2**), and leave player 2 idle. Health and the round timer still apply. The PlayStation version's Training mode would need a separate PlayStation emulator setup.

### Tekken 3

MAME marks the graphics as imperfect and can't save this game. This is the arcade version, so the PlayStation extras aren't included.

### Street Fighter II

Up jumps and down crouches. Hold away from your opponent to block, and down-away to block low. With Ryu or Ken, roll down to forward, then punch, for a fireball. Directions flip when you switch sides.

## Zelda (not set up yet)

*A Link to the Past* (Super Nintendo) and *Ocarina of Time* (Nintendo 64) are on the wish list. They need console emulation, which this project doesn't configure yet.
