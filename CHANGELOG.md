# Changelog

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
