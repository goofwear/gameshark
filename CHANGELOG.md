# Changelog

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
