# Zelda: A Link to the Past

Super Nintendo, `zelda3u` (USA cartridge) on MAME's `snes` driver. Source: [Nintendo's manual](https://www.nintendo.com/es-es/games/oms/snes-classic/manuals/zelda/manual.pdf).

In Coinless the PS4 pad matches the SNES pad by position (`launcher/pads.cfg`): ✕ B (sword), ○ A (action: lift, talk, dash), □ Y (equipped item), △ X (map), L1 L, R1 R, Options Start (item screen), Share Select. Changes in MAME's menu go to `cfg/snes.cfg` and win.

Two kinds of save: the game's own (Select → SAVE AND CONTINUE or SAVE AND QUIT, kept in `nvram/snes/zelda3u.nv`; you restart at a house, sanctuary or dungeon entrance) and Coinless's resume point (`sta/zelda3u/snes/auto.sta`, exactly where you left). New game only sets the resume point aside; the game's three files stay.

Ask location/items only as needed. Give hints before exact puzzle solutions. Verify port differences (the GBA version adds content). Spin attack: hold the sword button, release.
