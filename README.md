# GameShark Compatibility 0.4.0

Built for **Gen1Recomp 0.1.47**.

## Use Surfboard

Choose **USE SURFBOARD** while standing beside and facing water. It uses the game's normal surfing routine without permanently teaching SURF or granting a badge.

## Steal Trainer Pokémon

Turn on **STEAL TRAINER** (`010157D0`) before or during a trainer battle, then throw any Poké Ball. The active opposing Pokémon is forced through the normal capture flow, including Pokédex registration, party/PC storage, and the nickname prompt.

## Existing features

Walk Through Walls, No Random Battles, item and money cheats, HP, badges, One-Hit KO, Burn, Safari cheats, and selectable wild Pokémon encounters.

# GameShark Compatibility 0.2.0

This version is built specifically against **Gen1Recomp 0.1.47** and replaces all guessed hooks with hooks confirmed in that release.

## Working translations

- `010138CD` — Walk Through Walls
- `01033CD1` — No Random Battles
- `01017CCF` — Keep 99 Master Balls in the bag
- `019947D3` — Keep money at 999,999
- `01287CCF` — Keep 99 Rare Candies in the bag
- `01FF16D0` — Keep party slot 1 at full HP
- `01FF56D3` — Grant all eight badges
- `0100E7CF` — Player attacks defeat the enemy in one hit
- `0170E9CF` — Burn the active enemy
- `016447DA` — Keep 99 Safari Balls
- `01F00ED7` — Keep Safari steps at 240

The original mart-address codes are translated to direct native inventory effects because Gen1Recomp does not emulate the Game Boy mart RAM address.

## Install

Delete every older GameShark mod folder first. Copy this folder directly into `mods`:

```text
mods/
  gen1recomp_gameshark_v0.2.0/
    manifest.json
    main.lua
    mod.card
    README.md
    CHANGELOG.md
```

Restart the game, enable the mod, and use **START → GAMESHARK**.

## Testing notes

- Walk Through Walls intentionally keeps map-boundary blocking enabled to reduce invalid-map crashes.
- One-Hit Enemies activates when the player lands a damaging move.
- Safari codes only have an effect while a Safari game is active.
- Item and badge effects remain in the save after disabling because they are real inventory/progress changes.
