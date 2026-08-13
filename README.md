# GameShark Compatibility v0.5.2

**Author: goofwear**

A single GameShark-style cheat mod for Gen1Recomp that automatically supports both **Gen 1 (Red/Blue/Yellow)** and **Gen 2 (Pokemon Gold)**.

## Requirements

- Gen1Recomp 0.1.79 or newer in the 0.1.x line, or a compatible `0.0.0-dev` source build.
- Mod API 2.

The manifest explicitly targets both generations with `"games": ["gen1", "gen2"]`.

## Cheats

- Wall Walk
- No Random Battles
- Master Ball x99
- Max Money
- Rare Candy x99
- Party Slot 1 Full HP
- All Badges
- One-Hit KO
- Burn Foe
- Steal Trainer Pokemon
- Wild Pokemon Picker
- Surfboard action
- Safari Balls x99 *(Gen 1 only)*
- Safari Time *(Gen 1 only)*

On Gold, **All Badges** grants all eight Johto badges and all eight Kanto badges.

## Automatic game detection

The mod reads the active save supplied by Gen1Recomp. Gold saves identify themselves as `version = "gold"` / generation 2. No ROM filename or filesystem access is used.

The cheat screen title shows `GAMESHARK G1` or `GAMESHARK G2` so the user can see what was detected.

## GameShark code references

The mod translates authentic GameShark-style effects into Gen1Recomp's native state. Some original cheats were multi-line RAM patches; the menu exposes the equivalent effect rather than emulating raw Game Boy RAM.

Examples for Gold include `01000BD2` (no random battles), `010000D1` (one-hit KO), `010116D1` (steal trainer Pokemon), the `010AA3CE`-`010AA6CE` walk-through-walls family, and the `01??EDD0` wild Pokemon modifier family.

## Sandbox compatibility

This version does not use `io`, `os.getenv`, `os.execute`, `love.filesystem`, `dofile`, `loadfile`, or `debug`. It uses the public mod API and game objects supplied to public hooks.

## Installation

Copy the `gen1recomp_gameshark_v0.5.2_universal` folder into the Gen1Recomp `mods` folder, restart the game, enable **GameShark Compatibility**, then open **START -> GAMESHARK**.

Delete older GameShark Compatibility folders first so only one version is installed.

## Notes

Save-data cheats such as items and badges make real changes to the active save. Disabling the cheat does not remove items or badges already granted. Save before experimenting with trainer capture or wall walking.


## v0.5.2 fixes

- Fixed **ONE HIT KO** on Pokemon Gold / Gen 2.
  Gold's `battle.damage` hook uses the active Pokemon tables directly, so the
  mod now identifies player and enemy ownership through the live battle object.
- Fixed **BURN FOE** on Pokemon Gold / Gen 2.
  Gold stores the status id as `burn`; Gen 1 uses `BRN`.
- Added the repository to the manifest for Gen1Recomp's mod updater:

```json
"github": "goofwear/gameshark"
```

Repository: https://github.com/goofwear/gameshark


## v0.5.2 — Gold Wild Pick customization

When playing Pokemon Gold / Gen 2, **WILD PICK** now has two additional controls:

- **WILD GENDER** — `RND`, `M`, or `F`
- **WILD SHINY** — `RND`, `YES`, or `NO`

Choose the Pokemon with **PICK POKEMON**, configure the two options, then enable
**WILD PICK**. The normal encounter level and encounter rate are still preserved.

Genderless Pokemon automatically show `N/A` and keep Gen 2's native `unknown`
gender. These controls are intentionally not shown in Gen 1 because Red/Blue do
not have native Pokemon gender or shininess.

## Optional Battle Art first-person compatibility

`WALL WALK` now also supports the first-person free-movement path used by
**Battle Art Voxel Fork** (`BATTLE_ART_VOXEL_FORK`). There is **no dependency**:

- GameShark does not require Battle Art.
- Battle Art is not listed in `dependencies` or `optional_dependencies`.
- If Battle Art is absent, no compatibility code activates.
- If it is present and exports its public companion-module interface, GameShark
  adapts the first-person free walk only while `WALL WALK` is enabled.

Map bounds remain protected.
