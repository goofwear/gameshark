# GameShark Compatibility v0.5.8

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

Copy the `gen1recomp_gameshark_v0.5.8_universal` folder into the Gen1Recomp `mods` folder, restart the game, enable **GameShark Compatibility**, then open **START -> GAMESHARK**.

Delete older GameShark Compatibility folders first so only one version is installed.

## Notes

Save-data cheats such as items and badges make real changes to the active save. Disabling the cheat does not remove items or badges already granted. Save before experimenting with trainer capture or wall walking.


## v0.5.8 fixes

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


## v0.5.8 — Gold Wild Pick customization

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


## v0.5.8 fixes

- **ALL BADGES on Gold now creates exactly 16 badges**: eight Johto and eight
  Kanto. Numeric duplicate badge aliases left by v0.5.0-v0.5.2 are removed.
- `growthRates` and `tmhmMoves` are excluded from **PICK POKEMON** because they
  are internal Gold data records, not Pokemon.
- The GameShark menu now preserves its cursor and scroll position after toggling
  cheats or changing Wild Pick settings.
- The Pokemon picker also preserves its cursor and scroll position after a
  selection instead of jumping back to the top.


## v0.5.8 — Gen1Recomp 0.1.93 compatibility

### Persistent Gold shinies
Gold Wild Pick no longer relies only on the `shiny.roll` return value.
When **WILD SHINY = YES**, GameShark now writes an authentic Gen-2 shiny DV
pattern into the spawned Pokemon and synchronizes its stored shiny/gender
identity. This keeps the Pokemon shiny after capture and later recalculation.

`WILD SHINY = NO` likewise breaks a naturally shiny DV pattern so the choice
remains non-shiny.

### Gen 2 Pay Day compatibility
Gen1Recomp 0.1.93 contains Pay Day in Gold's move data but currently lacks the
Gen-2 Pay Day battle effect. **PAY DAY FIX** is therefore available on Gold
and is enabled by default.

A successful player Pay Day hit accumulates `2 x user level` money. The
accumulated amount is added to the player's money after winning the battle.
The option can be disabled from the GameShark menu if a later engine version
implements Pay Day itself.

### Engine version range
The old upper bound `<0.2.0` has been removed. The manifest now uses:

```text
>=0.1.79 || =0.0.0-dev
```

This prevents the mod from being rejected merely because Gen1Recomp reaches
0.2.0 or later. `modApi = 2` remains declared. Future engine/API changes can
still require a GameShark update even though the manifest no longer imposes
an artificial upper version ceiling.


## v0.5.8

### Fixed: Steal Trainer Pokemon on Red / Blue / Yellow

Gen 1's native capture path ends a caught Pokemon battle with the result
`caught`. That is correct for a wild battle, but a trainer encounter only marks
the trainer NPC defeated when the result is `win`.

When **STEAL TRAINER** is enabled, v0.5.8 now:

1. uses the normal capture animation and forced catch;
2. keeps the captured Pokemon in the normal party/PC flow;
3. preserves Pokedex registration and nickname handling;
4. restores the battle's trainer identity after storage;
5. changes that stolen-trainer capture result from `caught` to `win`;
6. returns to the overworld with the trainer marked defeated instead of
   immediately restarting the encounter.

Gold's existing trainer-capture implementation is unchanged.

### Added: Max Coins

**MAX COINS** keeps the Game Corner Coin Case at **9,999 coins** while enabled.
It supports both generations:

- Gen 1: `save.coins = 9999`
- Gen 2 / Gold: `save.player.coins = 9999`

The cheat does not grant a Coin Case item; it fills the player's existing coin
balance. Because the balance is refreshed continuously, purchased prizes and
slot-machine bets are effectively unlimited while the cheat is ON.


## v0.5.8

### Added: Infinite PP

A new **INFINITE PP** toggle prevents the player's Pokemon from running out of
move PP during battle.

- Only the player's Pokemon are refilled; opponents are not affected.
- Existing moves at 0 PP are restored when the cheat is enabled.
- PP is restored to the move's true maximum, including PP Up bonuses.
- Gen 1 active battle `curMoves` and saved party moves are both maintained.
- Gen 2 / Gold uses each move's `maxPp` value.
- The `battle.move_used` hook restores PP immediately after normal PP
  consumption so the move remains available every turn.

### Added: PP UP x99

A new **PP UP x99** toggle keeps **99 PP Ups** in the player's bag, matching
the behavior of the existing Master Ball and Rare Candy cheats.

The cheat grants the normal `PP_UP` item, so it uses Gen1Recomp's normal item
UI and PP-Up rules when the player applies one to a move.


## Mod ID migration

Starting with the clean-ID v0.5.8 package, the manifest ID and installed folder
are both:

```text
GameShark
```

Older builds used `gameshark_compat`. Because Gen1Recomp identifies installed
mods by manifest ID, users upgrading from an older build should remove the old
`gameshark_compat` installation once, then install this `GameShark` package.
Future updates should continue using the `GameShark` ID.


## v0.5.8 — Red / Blue / Yellow trainer-capture fix

The extremely long Poké Ball wobble was caused by older universal builds
forcing the Gen 1 capture seam with `true, 255`. Current Gen1Recomp ultimately
uses that second value as the shake count, so the ball could visibly wobble
hundreds of times before the capture finished.

v0.5.8 changes the Gen 1 path:

- **STEAL TRAINER** temporarily wraps the active battle's `catchAttempt`.
- The stolen trainer Pokémon is a deterministic successful catch.
- The caught animation uses the normal **3-wobble** count.
- The regular capture/storage flow still runs, so party/PC, Pokédex, nickname
  and caught-event behavior are preserved.
- The existing GameShark trainer-capture result fix still converts the completed
  capture to **win**, so the trainer is marked defeated afterward.

This applies to Red, Blue and Yellow because they share Gen1Recomp's Gen 1
BattleState capture implementation.

Gold's working trainer-capture code is unchanged.


## v0.5.8 — Infinite HP fix

The old **SLOT 1 HP** implementation mainly refilled `save.party[1].hp`.
On newer Gen1Recomp builds that is not sufficient for true in-battle
invulnerability because move damage is resolved on the live battler during the
battle step and can trigger faint handling before a later refill.

The option is now named **INFINITE HP** (the saved effect id remains
`party_hp`, so existing users keep their toggle state).

While enabled:

- incoming move damage targeting the player's active Pokemon is changed to 0
  at the shared `battle.damage` hook;
- the active live battler is continuously restored to maximum HP;
- party slot 1 is still restored for backward compatibility;
- a post-step refill covers residual/status paths that write HP directly.

This uses the shared Gen 1 battle path and therefore applies to Red, Blue and
Yellow, as well as the existing Gold support.
