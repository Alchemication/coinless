---
name: game-facts
description: Research a Coinless game and write its launcher/facts/<id>.json, the short facts the library's ticker and ./play show (origin, makers, trivia, tips, combos, secrets). Use when a game is added, when a game has no facts yet (./play --check says so), or when asked to research or fix a game's facts.
---

# Game facts

Facts appear one at a time under the Play button, a few seconds each, read from the couch. So every fact is short, true, and worth a smile.

## Research

- Start with the game's Wikipedia page, then the game-tips reference for tips and combos. Search for development stories, interviews and credits. Prefer interviews, magazines and established sites over fan wikis and content farms.
- Facts are about **the arcade version MAME runs**. Mark port-only content as such ("The PlayStation port…").
- Drop anything you can't confirm, or that only one weak source claims. Sources disagree on a date? Use the better-supported one, or leave out the detail.
- Local facts count: `mame <id> -listxml` (hardware, BIOS/device ZIPs, save support). Cite it as `{ "title": "MAME 0.289: mame <id> -listxml" }`.

## Write

`launcher/facts/<id>.json`:

```json
{
  "developer": "Capcom",
  "facts": [
    { "kind": "origin", "text": "…", "sources": [0] }
  ],
  "sources": [
    { "title": "Wikipedia: …", "url": "https://…" }
  ]
}
```

- **8–10 facts**, mixing kinds: `origin` (how, why, when it was made), `people` (who made it), `trivia`, `tip`, `combo`, `secret`. At least one origin, one people, two tips or combos.
- **Concise:** at most 140 characters (the app refuses longer), ideally under 120. One idea per fact, no filler, no "Did you know".
- Plain words, present tense where possible, directions relative to the opponent, game actions rather than keyboard keys ("Block + Kick + Punch", not "Ctrl + Alt + Space").
- No spoilers beyond the first stage or boss.
- Every fact lists one or more source indexes. `developer` appears on the marquee ring; keep it short.

## Check

- `./play --check` validates the file (length, sources).
- `./play --facts <id>` prints it the way a reader sees it. Read it out loud: cut any fact that isn't interesting.
- `Coinless.app/Contents/MacOS/Coinless --preview <id>` and look at the ticker in `launcher/.build/preview.png`.
