# GameShark Compatibility v0.7.8

**Author:** goofwear  
**Mod ID:** `GameShark`  
**Repository:** https://github.com/goofwear/gameshark

GameShark Compatibility is a standalone GameShark-style cheat and debug menu for **Gen1Recomp**. It automatically adapts to the active game and supports **Gen 1 and Gen 2** without depending on another cheat, move-manager, item-manager, or DV/EV mod.

## Supported games

- Pokemon Red
- Pokemon Blue
- Pokemon Yellow
- Pokemon Gold
- Pokemon Silver
- Pokemon Crystal

The manifest targets both generations with:

```json
"games": ["gen1", "gen2"]
```

## Requirements

- Gen1Recomp `0.1.79` or newer, or a compatible `0.0.0-dev` build
- Mod API 2

The current manifest compatibility expression is:

```text
>=0.1.79 || =0.0.0-dev
```

## Installation

The release ZIP should contain the mod inside a top-level `GameShark` folder:

```text
GameShark-0.7.8.zip
└── GameShark/
    ├── manifest.json
    ├── main.lua
    ├── README.md
    ├── CHANGELOG.md
    └── mod.card
```

Import the ZIP through Gen1Recomp's mod manager, or copy the `GameShark` folder into the game's `mods` directory. Remove older duplicate GameShark folders before testing a new release.

After enabling the mod, open the normal START menu and choose **GAMESHARK**.

## Main cheats

The available rows adapt to the active generation/game.

- **WALL WALK** — walk through normal map collision
- **NO BATTLES** — suppress normal random encounters
- **MASTER BALL** — maintains Master Balls in the bag
- **MAX MONEY** — keeps money at the supported maximum
- **MAX COINS** — keeps Game Corner coins at the native maximum
- **INFINITE PP** — prevents the player's battle moves from running out of PP
- **PP UP x99** — maintains 99 PP Up items
- **RARE CANDY** — maintains Rare Candies in the bag
- **INFINITE HP** — protects/refills the player's active Pokemon
- **ALL BADGES** — grants the appropriate badges for the active generation
- **ONE HIT KO** — forces enemy damage to resolve as a knockout
- **BURN FOE** — applies the active game's burn status to the opponent
- **SAFARI BALL** — Safari Ball support on Gen 1
- **SAFARI TIME** — Safari Zone time support on Gen 1
- **STEAL TRAINER** — permits catching trainer Pokemon through the supported battle path
- **PAY DAY FIX** — Gen 2 compatibility helper for Pay Day behavior

Save-data cheats make real changes to the active save. Disabling the toggle does not necessarily remove items, badges, money, or other values already written to the save.

## Wild Pokemon

The narrow Gen 1 main menu uses:

```text
WILD PKMN >          OFF
```

or:

```text
WILD PKMN >           ON
```

Keeping the submenu arrow with the left label leaves `ON` / `OFF` aligned with the other cheat rows.

The full submenu is still titled **WILD POKEMON** and provides:

- Enable/disable Wild Pick
- Pokemon species selection
- Optional level override
- Gender selection where supported
- Shiny selection where supported
- **BATTLE NOW** for an immediate selected encounter

If level is left on **AUTO**, normal Wild Pick preserves the game's natural encounter level.

## Instant Battle

**BATTLE NOW** starts a wild battle immediately using the selected Pokemon and level.

GameShark uses generation-appropriate Gen1Recomp battle paths rather than assuming Gen 1 and Gen 2 expose identical APIs.

## Teleport

**TELEPORT** opens a destination picker and moves the player to supported major destinations without requiring the normal Fly restrictions.

Generation-specific UI handling is used so Gen 1 preserves its live overworld state while Gen 2 clears nested overlay menus before the warp.

## Give Item

**GIVE ITEM** lets you:

1. Choose an item from the active game's own item catalog.
2. Choose a quantity.
3. Add it directly to the player's inventory.

Stackable items can be added in quantities from 1 through 99. Gen 2 Key Items and HMs are treated as unique items. Newly given items are inserted into the bag order so they appear in the normal inventory UI.

The picker is generated from the running game's decoded item definitions rather than one hard-coded cross-generation list.

## Teach Move

**TEACH MOVE** is an unrestricted move editor:

1. Choose a Pokemon from the party.
2. Choose any move in the current game's move table.
3. If a free move slot exists, the move is added.
4. If all four slots are occupied, choose exactly which slot to replace.

This is intentionally a GameShark/debug feature, so normal species learnsets and TM/HM compatibility restrictions are bypassed. HM moves may also be assigned or overwritten.

A newly assigned move starts with its normal base PP. Selecting a move the Pokemon already knows restores that move's PP rather than creating a duplicate slot.

## DV / EV editor

**DV / EV EDITOR** lets you select a party Pokemon and edit the original Gen 1 / Gen 2 stat-growth values.

### DVs

Editable DVs range from `0` to `15`:

- Attack
- Defense
- Speed
- Special

HP DV is derived from the other four values and is displayed separately.

Convenience option:

- **MAX ALL DVS**

### EV / Stat EXP

Gen 1 and Gen 2 use the original 16-bit **Stat EXP** system rather than the modern 0-252 EV system. GameShark exposes the five stored values:

- HP
- Attack
- Defense
- Speed
- Special

Each can range from `0` to `65535` (`FFFF` in hexadecimal).

Convenience options include:

- **MAX ALL EVS**
- **ZERO ALL EVS**
- **RECALC STATS**

The editor also displays **RESULT STATS** so the effective calculated stats can be checked immediately.

## Crystal Celebi / GS Ball event — v0.7.8

Version **0.7.8** adds a Crystal-only **CELEBI EVENT** action.

It mirrors the classic Crystal GameShark GS Ball event activation (`010B3CBE`) by setting the corresponding Crystal event state through Gen1Recomp's save representation.

The row appears only when the active Gen 2 game exposes Crystal's `GS_BALL` item/event capability. It is intentionally hidden in Gold and Silver because those games do not contain Crystal's localized GS Ball/Celebi event sequence.

After activating the event in Crystal, continue through the game's normal event flow beginning around the Goldenrod City Pokemon Center, followed by Kurt and the Ilex Forest shrine sequence.

The menu can report the event state as it progresses, such as:

```text
START
READY
GIVEN
USED
```

For a direct Celebi encounter in Gold or Silver, use the Wild Pokemon / Instant Battle tools instead of the Crystal-only event flag.

## Gen 2 / Silver / Crystal compatibility cleanup — v0.7.7

Version **0.7.7** removed old hard-coded checks for `version == "gold"`.

Gen 2 behavior now keys off generation/capability instead, allowing the same supported code paths to cover:

- Gold
- Silver
- Crystal

This change also removes the `MK409` warnings that the strict Gen 2 modkit check reported for version-specific allow-list logic.

The current compatibility design is:

```text
Gen 1 → Red / Blue / Yellow
Gen 2 → Gold / Silver / Crystal
```

`mod.exports.game()` also reports the actual running game version instead of identifying every Gen 2 game as Gold.

## Validation

GameShark is designed to pass the current Gen1Recomp mod checks, including the sandbox rules introduced for Mod API 2.

Typical checks from the Gen1Recomp source tree are:

```bash
python3 tools/modkit.py validate GameShark --strict
python3 tools/modkit.py lint GameShark
python3 tools/modkit.py gen2check GameShark --strict --notes
```

The mod does not use prohibited unrestricted filesystem/process APIs such as `io`, `os.getenv`, `os.execute`, `love.filesystem`, `dofile`, `loadfile`, or `debug`.

## Updating through Gen1Recomp

The manifest contains:

```json
"github": "goofwear/gameshark"
```

Gen1Recomp can therefore use the GitHub repository's Releases for **Update** and **Versions** support when releases contain an installable ZIP.

For best compatibility, publish release assets using the mod ID and semantic version, for example:

```text
GameShark-0.7.8.zip
```

## Development notes

GameShark translates GameShark-style effects into Gen1Recomp's supported runtime/save APIs. It does not emulate a physical GameShark device or blindly write raw Game Boy memory for every feature.

Some original GameShark codes are retained as historical/reference identifiers inside the source, while the actual implementation uses generation-aware engine behavior where needed for stability.

For the complete version-by-version history, see [`CHANGELOG.md`](CHANGELOG.md).
