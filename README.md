# GameShark Compatibility v0.7.2

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

Copy the `gen1recomp_gameshark_v0.7.2_universal` folder into the Gen1Recomp `mods` folder, restart the game, enable **GameShark Compatibility**, then open **START -> GAMESHARK**.

Delete older GameShark Compatibility folders first so only one version is installed.

## Notes

Save-data cheats such as items and badges make real changes to the active save. Disabling the cheat does not remove items or badges already granted. Save before experimenting with trainer capture or wall walking.


## v0.7.2 fixes

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


## v0.7.2 — Gold Wild Pick customization

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


## v0.7.2 fixes

- **ALL BADGES on Gold now creates exactly 16 badges**: eight Johto and eight
  Kanto. Numeric duplicate badge aliases left by v0.5.0-v0.5.2 are removed.
- `growthRates` and `tmhmMoves` are excluded from **PICK POKEMON** because they
  are internal Gold data records, not Pokemon.
- The GameShark menu now preserves its cursor and scroll position after toggling
  cheats or changing Wild Pick settings.
- The Pokemon picker also preserves its cursor and scroll position after a
  selection instead of jumping back to the top.


## v0.7.2 — Gen1Recomp 0.1.93 compatibility

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


## v0.7.2

### Fixed: Steal Trainer Pokemon on Red / Blue / Yellow

Gen 1's native capture path ends a caught Pokemon battle with the result
`caught`. That is correct for a wild battle, but a trainer encounter only marks
the trainer NPC defeated when the result is `win`.

When **STEAL TRAINER** is enabled, v0.7.2 now:

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


## v0.7.2

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

Starting with the clean-ID v0.7.2 package, the manifest ID and installed folder
are both:

```text
GameShark
```

Older builds used `gameshark_compat`. Because Gen1Recomp identifies installed
mods by manifest ID, users upgrading from an older build should remove the old
`gameshark_compat` installation once, then install this `GameShark` package.
Future updates should continue using the `GameShark` ID.


## v0.7.2 — Red / Blue / Yellow trainer-capture fix

The extremely long Poké Ball wobble was caused by older universal builds
forcing the Gen 1 capture seam with `true, 255`. Current Gen1Recomp ultimately
uses that second value as the shake count, so the ball could visibly wobble
hundreds of times before the capture finished.

v0.7.2 changes the Gen 1 path:

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


## v0.7.2 — Infinite HP fix

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


## v0.7.2 — Wild Pokémon setup redesign

Wild Pick is now grouped into a dedicated **WILD POKEMON** submenu instead of
scattering species, gender, shiny, and the enable switch across the main
GameShark list.

The submenu shows:

```text
WILD POKEMON
  ENABLE WILD PICK   ON/OFF
  POKEMON            <selected species>
  LEVEL              AUTO / 1-100
  GENDER             RANDOM / MALE / FEMALE / GENDERLESS   [Gold only]
  SHINY              RANDOM / YES / NO                      [Gold only]
  BACK
```

### Wild level

- **AUTO** is the default.
- AUTO preserves the exact level selected by the game's normal encounter table.
- Choosing **1 through 100** overrides only the encountered Pokémon's level.
- Species selection, encounter rate, map, and normal encounter triggering are
  otherwise unchanged.
- The level setting is saved per GameShark save and remains selected until
  changed back to AUTO.

### Cleaner main menu

The main GameShark screen now contains one entry:

```text
WILD POKEMON   ON >
```

or:

```text
WILD POKEMON   OFF >
```

Selecting it opens the full setup screen. This removes the old separate
`WILD PICK`, `PICK POKEMON`, `WILD GENDER`, and `WILD SHINY` rows from the main
list while preserving the same underlying `wild_pick` effect id for existing
saved settings and external integrations.


## v0.7.2 — Instant Battle + Wild menu spacing

### Instant Battle

The **WILD POKEMON** screen now includes:

```text
WILD POKEMON
  WILD PICK      ON/OFF
  POKEMON        <species>
  LEVEL          AUTO / 1-100
  GENDER         RANDOM / MALE / FEMALE / N/A   [Gold only]
  SHINY          RANDOM / YES / NO               [Gold only]
  BATTLE NOW     >
  BACK
```

**BATTLE NOW** immediately starts a normal wild battle using the selected
Pokemon and level. It uses Gen1Recomp's public `mod.world:startWildBattle()`
service, so the normal battle transition, EXP, evolutions, capture flow,
blackout handling, battle return, and Pokedex behavior stay intact.

Supported games:

- Pokemon Red
- Pokemon Blue
- Pokemon Yellow
- Pokemon Gold

The battle can be started while standing on an indoor or outdoor map as long as
the game is in a safe overworld state, the player has a healthy Pokemon, and no
other battle is already running.

### Level behavior

`LEVEL = AUTO` still means **do not override normal random encounter levels**.
For Instant Battle, the player must choose a specific level from 1-100. If the
user selects **BATTLE NOW** while Level is AUTO, GameShark opens the level
picker instead of silently choosing a level.

### Gold identity options

Instant Gold battles reuse the same Gender and Shiny settings as Wild Pick.
Genderless Pokemon display `N/A`; no male/female value is forced onto them.

### Spacing cleanup

The old `ENABLE WILD PICK` label was too wide once an `ON/OFF` value was drawn
in the right column. It is now simply `WILD PICK`. `GENDERLESS` was also
shortened to `N/A` in the value column. These changes keep the Game Boy-width
menu columns separated instead of allowing text to overlap.


## v0.7.2 — Gold Instant Battle fix

v0.6.0 incorrectly called the Gen-1-only `mod.world:startWildBattle()` helper
for every game. That made Instant Battle work in Red/Blue/Yellow but silently
return to the menu in Gold.

v0.7.2 selects the proper supported Gen1Recomp API at runtime:

- **Red / Blue / Yellow:** `mod.world:startWildBattle(species, level)`
- **Gold:** `mod.world:queueScript({{"start_battle", "wild", species, level}})`

Gold's `start_battle` verb is implemented by its own WorldAPI. It constructs a
native Gen-2 `Mon`, marks the species seen in the Pokédex, and calls Gold's
`World:startBattle()` path. It does not depend on the current map having a
natural wild encounter table, so GameShark Instant Battle can be started while
inside buildings as well as outside.

The selected Gold Gender and Shiny options are prepared before the Gen-2 Mon is
constructed, so they remain applicable to Instant Battles.


## v0.7.2 — Teleport + DV / EV Editor

### Teleport

A new **TELEPORT >** action is available from the GameShark menu.

It presents the game's standard major travel destinations and teleports the
player there without requiring Fly, the Fly HM, a badge, or a previously
visited destination.

Supported games:
- Pokemon Red
- Pokemon Blue
- Pokemon Yellow
- Pokemon Gold
- Pokemon Silver

Implementation uses Gen1Recomp's public `mod.world:warpTo()` service. Gen 1
destinations come from the game's extracted `flyOrder` / `flyWarps` data.
Gen 2 destinations use the ROM-extracted spawn points for Johto and Kanto.
GameShark does **not** alter the player's real visited-location flags.

### DV / EV Editor

A new **DV / EV EDITOR >** action lets the player choose any Pokemon currently
in the party and edit the values stored on that Pokemon.

#### DVs
- Attack: 0-15
- Defense: 0-15
- Speed: 0-15
- Special: 0-15
- HP DV is displayed read-only because Gen 1 and Gen 2 both derive it from the
  low bits of the other four DVs.
- **MAX ALL DVS** sets all four editable DVs to 15.

#### EV / Stat EXP
Pokemon Gen 1 and Gen 2 do not use the modern 0-252 EV system. Their save data
stores five 16-bit **Stat EXP** values, each ranging from 0 to 65,535:
- HP
- Attack
- Defense
- Speed
- Special

The editor labels these values as EVs for familiarity, but edits the authentic
Stat EXP fields used by the games.

Each EV opens a four-digit hexadecimal editor:
- `0000` = 0
- `FFFF` = 65,535
- **A** increases the selected hex digit
- **SELECT** decreases the selected hex digit
- **APPLY** writes the exact 16-bit value

Convenience actions:
- **MAX ALL EVS** = 65,535 in every Stat EXP field
- **ZERO ALL EVS** = 0 in every Stat EXP field

After an edit GameShark immediately recalculates the Pokemon's actual stats.
For Gen 2, DV changes also refresh gender and shiny state because both are
derived from DVs.

### Independence / attribution

This editor was implemented against Gen1Recomp's own documented/runtime
Pokemon structures and stat formulas. It does not include, copy, or require
FAFF0x's DV/EV editor code.


## v0.7.2 — Teleport UI + DV/EV stat refresh fixes

### Gold Teleport menu
Gold could complete the warp while the GameShark ListMenu was still on the UI
stack, leaving the menu visible after arrival. Teleport is now deferred until
the frame after the Teleport screen closes.

### DV/EV editor
The editor now recalculates through the same native engine code used by the
games themselves:

- Gen 1: `src.pokemon.Stats.calc`
- Gen 2: `src.battle.gen2.Mon.refreshStats`

The editor now reads the species definition from `game.data.pokemon`, matching
the native Summary screens, rather than relying on a merged registry record for
stat calculation.

This fixes the case where the editor showed DVs/Stat EXP as changed while the
Pokemon's displayed battle stats remained at their old values.

Opening a Pokemon in the editor now recalculates it immediately, so values
already changed with v0.7.0 can be repaired without re-entering every number.
A **RECALC STATS** action is also available explicitly.


## v0.7.2 — Teleport menu-stack fix

Teleport now clears the complete menu overlay stack immediately before the
warp. This matters when GameShark was opened through nested START / MODS
screens: closing only the Teleport list left those underlying menus visible
after arriving in Gold.

The DV/EV implementation is unchanged from v0.7.1. A verification note for
Gen 1: "EV" in this editor means the original games' 16-bit Stat EXP. A value
of 65,535 is fed through the original stat formula; it is not added directly
to the visible stat. For example, a level-20 Mew with 15 DVs and 65,535 Stat
EXP has 88 HP and 63 in Attack, Defense, Speed and Special.
