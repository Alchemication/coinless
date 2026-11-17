# Local setup

Player uses PS4 controllers. For actual bindings, inspect project `cfg/default.cfg` and `cfg/<game>.cfg`; game overrides take priority. Do not assume suggested keyboard layouts were applied.

Save-state support per game is the `saveStates` field in `launcher/games.json`; `./play --check` verifies it against the installed MAME. `./play` lists installed games and which have saves. Idle P2 practice retains health/time limits.

See the project README for launching and saves, `docs/games.md` for files and button maps, and [MAME controls](https://docs.mamedev.org/usingmame/defaultkeys.html) for save/input bindings.
