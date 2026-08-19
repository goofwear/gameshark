# Changelog

## [0.6.1] - 2026-08-19

### Fixed
- Fixed **BATTLE NOW** doing nothing in Pokemon Gold.
- Gold Instant Battle now uses Gen1Recomp's supported Gen-2 `start_battle`
  script verb through `mod.world:queueScript()` instead of the Gen-1-only
  `startWildBattle()` API.
- Gold Instant Battle now works from indoor and outdoor maps, provided the
  player is in a valid overworld state and has a healthy party.
- Red, Blue and Yellow continue using the Gen-1 `startWildBattle()` service.
- Gold Gender/Shiny selections remain wired into the Mon-construction path.


## [0.6.0] - 2026-08-19

### Added
- Added **BATTLE NOW** to the Wild Pokemon setup screen.
- Starts an immediate wild battle with the selected Pokemon and selected
  level through Gen1Recomp's public `mod.world:startWildBattle()` API.
- Supports Red, Blue, Yellow, and Gold.
- Gold Instant Battles honor the existing Gender and Shiny selections.
- If `LEVEL = AUTO`, choosing BATTLE NOW opens the level selector rather than
  inventing an arbitrary battle level.

### UI
- Shortened `ENABLE WILD PICK` to `WILD PICK` to prevent left/right text
  overlap on the 160px Game Boy menu.
- Genderless Gold Pokemon display `N/A` in the narrow value column.
- Preserved cursor/scroll behavior from previous releases.


## [0.5.9] - 2026-08-18

### Added
- Added **Wild Level** selection with `AUTO` plus levels 1-100.
- `AUTO` preserves the level produced by the game's normal encounter table.
- Manual level selection overrides only the resulting wild Pokémon level.
- Added a dedicated **WILD POKEMON** setup submenu.

### UI
- Consolidated Wild Pick configuration into one self-explanatory screen:
  Enable, Pokémon, Level, Gender, and Shiny.
- Main GameShark menu now shows one `WILD POKEMON  ON/OFF >` entry instead of
  multiple scattered Wild Pick controls.
- Gen 2-only Gender and Shiny settings appear only on Gold.
- Added cursor/scroll memory for both the Wild Pokémon setup and level picker.
- Existing `wild_pick` effect/save state remains compatible.


## [0.5.8] - 2026-08-17

### Fixed
- Reworked **SLOT 1 HP** into a true **INFINITE HP** cheat.
- Incoming move damage to the player's active Pokemon is now zeroed at the
  `battle.damage` hook before HP loss/faint processing.
- Live battle HP is refilled in addition to the saved party copy.
- Added a post-engine-step refill for residual/status HP writes.
- Fix targets Red, Blue and Yellow through their shared Gen 1 BattleState path,
  while retaining Gold support.
- Preserved the existing `party_hp` effect id so saved toggle state migrates
  automatically.


## [0.5.7] - 2026-08-17

### Fixed
- Fixed **STEAL TRAINER** on Red, Blue and Yellow causing an extremely long
  Poké Ball wobble/shake animation.
- Removed the Gen 1 forced `catch.rate -> true,255` path.
- Trainer captures now use a deterministic successful `catchAttempt` with
  the normal three-wobble caught animation.
- Keeps the v0.5.5 `win` conversion after capture so the Pokémon is retained
  and the trainer remains defeated.
- Gold behavior is unchanged.


## [0.5.6] - 2026-08-17

### Added
- Added **INFINITE PP** for Red, Blue, Yellow and Gold.
- Player move PP is restored to its true maximum in battle and never runs out.
- Infinite PP does not refill the opponent's moves.
- Added **PP UP x99**, which maintains 99 normal PP Up items in the bag.


## [0.5.5] - 2026-08-17

### Fixed
- Fixed **STEAL TRAINER** on Red, Blue and Yellow so a successful stolen-Pokemon
  capture resolves the trainer encounter as a win after the normal capture
  storage flow.
- The captured Pokemon is retained and the trainer NPC is marked defeated,
  preventing the same trainer from immediately starting the battle again.
- Restores the battle's original trainer identity before teardown.

### Added
- Added **MAX COINS** for both Gen 1 and Gen 2.
- Keeps the Game Corner Coin Case at the native maximum of 9,999 while enabled.


## [0.5.4] - 2026-08-15

### Fixed
- Fixed Gold Wild Pick shinies on Gen1Recomp 0.1.93 by writing persistent,
  authentic Gen-2 shiny DVs instead of relying only on the hook return value.
- Keeps stored shiny/gender identity synchronized with the generated DVs.

### Added
- Added Gen-2-only **PAY DAY FIX**, enabled by default, to restore Gold's
  missing Pay Day money accumulation/payout behavior.

### Compatibility
- Removed the `<0.2.0` engine-version ceiling.
- New supported engine expression: `>=0.1.79 || =0.0.0-dev`.
- Author remains `goofwear`; GitHub updater remains `goofwear/gameshark`.


## [0.5.3] - 2026-08-14

### Fixed
- Gold ALL BADGES now creates exactly 16 badge entries instead of 32.
- Cleans duplicate numeric badge aliases written by v0.5.0-v0.5.2.
- Removed `growthRates` and `tmhmMoves` from the Wild Pokemon picker.
- Preserved the GameShark-menu cursor/scroll position after changes.
- Preserved the Pokemon-picker cursor/scroll position after selection.


## [0.5.2] - 2026-08-12

### Added
- Gold Wild Pick gender choice: Random / Male / Female.
- Gold Wild Pick shiny choice: Random / Yes / No.
- Genderless Pokemon detection; genderless species cannot be forced male/female.
- Runtime-only compatibility for Battle Art Voxel Fork first-person movement.

### Compatibility
- `WALL WALK` now relaxes Battle Art's separate first-person free-movement
  collision checks when that mod is already installed.
- Battle Art remains completely optional and is not a dependency or optional
  dependency in the manifest.
- Standard Gen1Recomp `movement.collision` behavior remains unchanged.


## [0.5.1] - 2026-08-12

### Fixed
- Fixed One-Hit KO on Pokemon Gold / Gen 2 by identifying the active player
  and enemy Pokemon through `ctx.battle.player` and `ctx.battle.enemy`.
- Fixed Burn Foe on Pokemon Gold / Gen 2 by using Gold's native `burn`
  status id instead of Gen 1's `BRN`.

### Added
- Added `"github": "goofwear/gameshark"` to `manifest.json` so Gen1Recomp can
  check GitHub releases for updates and older versions.


## 0.5.0 - 2026-08-12

- Added Pokemon Gold / Gen 2 support.
- One package now targets `gen1` and `gen2`.
- Added automatic generation detection.
- Added Gold-specific money and badge handling.
- Added Gold trainer-capture handling through the Gen 2 battle screen.
- Shared collision, encounter, damage, catching, item, HP and Pokemon-picker behavior across generations.
- Safari cheats are hidden on Gold.
- Changed author to **goofwear**.
- Raised packaged-release target to Gen1Recomp 0.1.79+ while retaining compatible `0.0.0-dev` builds.
