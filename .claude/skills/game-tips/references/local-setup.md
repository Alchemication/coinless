# Local setup

Player uses PS4 controllers. Bindings: `launcher/pads.cfg` (Coinless's layouts; the Controls table in `docs/games.md` lists them), overridden by anything in `cfg/default.cfg` and `cfg/<game>.cfg` (the player's own changes from MAME's menu).

Save-state support per game is the `saveStates` field in `launcher/games.json`; `./play --check` verifies it against the installed MAME. `./play` lists installed games and which have saves. Idle P2 practice retains health/time limits.

See the project README for launching and saves, `docs/games.md` for files and button maps, and [MAME controls](https://docs.mamedev.org/usingmame/defaultkeys.html) for save/input bindings.
