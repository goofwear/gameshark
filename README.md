# GameShark Compatibility v0.9.11

**Author:** goofwear  
**Mod ID:** `GameShark`  
**Repository:** https://github.com/goofwear/gameshark

## FireRed shiny event fix — v0.9.8

The 0.9.7 Android recording shows `SHINY CHECK = START ERR` before and
after the Mew battle. The early `Battle.start` wrapper failed to install.
This version applies shiny identity to the live wild Pokémon from the
`battle.started` event, without relying on that wrapper. The picture lookup
uses the active battle from the same event, without requiring the battle
engine during setup.

If it still fails, select **SHINY CHECK** in the Wild Pokémon menu to see
its full setup or event error. Its status after a battle should say
`ID OK` or `COLOR OK`. Return after the battle to inspect it. The mod includes
no ROM or Pokémon images.

## FireRed sandbox fix and shiny check — v0.9.7

The user-provided 0.3.0 `.love` package matches the earlier source in the
FireRed battle, sprite, and mod runtime files. The previous mod used
`package.loaded` inside sprite callbacks, but the mod sandbox does not expose
`package`. Version 0.9.7 uses the permitted `require` path instead.

The Wild Pokémon menu now includes **SHINY CHECK**. After choosing SHINY YES
and entering a battle, return to the menu and check the status:

- `COLOR OK`: shiny identity and recolored sprite were reached.
- `ID OK`: shiny identity was applied, but the recolored sprite was not shown.
- `NO COLORS`: the active Pokémon was shiny, but its sprite palette was unavailable.
- `HOOK OK`: setup ran, but no shiny Pokémon was finalized.
- `WALK ERR`, `START ERR`, or `PIC ERR`: the named setup step failed.
- `NO START` or `NO PIC`: the corresponding setup step was unavailable.
- `NO HOOK`: the setup hook did not run.

Please share a screenshot of this line after testing if the sprite remains
pink. This is a diagnostic release and still needs a live Android play test.

## FireRed shiny sprite fix — v0.9.6

The reported video shows WILD PICK ON, MEW selected, SHINY YES, and a
normal-colored pink Mew in the battle. FireRed's main renderer calls
`Pokemon.frontPic` / `Pokemon.backPic` directly, bypassing the
`Ui.battlerPic` hook used by v0.9.5. This build also wraps those actual
sprite functions and applies the extracted shiny palette to the active
battle Pokémon and its party summary portrait.

The video does not show Mew's captured summary. The shiny identity and star
still need a live capture check. The ZIP contains no ROM or Pokémon images.

## FireRed shiny changes in v0.9.5

Setting **SHINY = YES** applies to wild encounters even when **WILD PICK = OFF**.
WILD PICK only controls the species. **BATTLE NOW** also uses these settings.
The wild Pokémon's personality and shiny state are written during FireRed
battle creation, and the `battle.started` event provides a second path to
finalize it. After capture, the shiny star should appear in the summary.

Original FireRed normal and shiny palette values were extracted from the
FireRed 1.0 ROM supplied for this repair. Only these small color tables are
included in this ZIP. The ROM and Pokémon sprite images are not included.
The mod recolors Gen1Recomp's imported normal battle sprites at runtime, so
no ROM file needs to remain in the game directory. For 18 species whose normal
palette repeats an RGB value with two different shiny targets, a few pixels
may differ from the original sprite when the ROM is not available at runtime.

This build passed syntax, archive, ROM palette, battle-start, and direct
FireRed sprite-path checks. A live FireRed play test is still required.

## FireRed shiny correction — v0.9.3

Video testing exposed two separate FireRed issues:

1. The forced shiny needed to be applied to the **actual live
   `Battle.getState().enemy.mon`** after FireRed finished constructing the
   battler, not just to the encounter/foe table.
2. The current Gen1Recomp FireRed battle renderer decodes Pokémon battle
   pictures with the normal `gMonPaletteTable`; a logically shiny Pokémon can
   therefore still look normal-coloured.

v0.9.3 addresses both. GameShark now:

- writes a valid Gen 3 shiny PID plus `isShiny = true` directly to the live wild
  battler before the first battle update/render frame;
- preserves the PID/OT relationship so a caught Pokémon stays shiny;
- discovers FireRed's own `gMonShinyPaletteTable` from the ROM header at
  runtime instead of hard-coding a ROM address;
- renders shiny enemy/player battle pictures using that original FireRed shiny
  palette when the battler is actually shiny.

The summary screen's existing shiny-star logic also sees the corrected
`isShiny`/PID state after capture.

## FireRed shiny Wild Pokemon fix — v0.9.2

FireRed/Gen 3 does not determine shininess from Gen 2 DVs. A Pokemon is shiny
when the XOR of the player's visible Trainer ID, Secret ID, and the two halves
of the Pokemon's 32-bit Personality Value is less than 8.

Earlier GameShark builds changed `mon.isShiny` from the `battle.started` event.
That event is emitted **after FireRed has already begun its intro/send-out
sequence**, so the encounter could already have been prepared as a normal
Pokemon.

v0.9.2 now generates the FireRed Personality Value before `Battle.start()`
constructs the wild Pokemon. The generated PID simultaneously respects:

- SHINY = YES / NO
- selected Nature
- selected Gender when the species supports it

The FireRed battle engine then stamps the wild Pokemon with the player's real
Trainer ID and Secret ID before the intro, so the normal Gen1Recomp shiny check,
sparkle sequence, summary screen, and caught Pokemon all agree that it is shiny.
MAX IVS is also supplied before battle construction when enabled.

## FireRed true full noclip — v0.9.1

The latest video showed that some FireRed blockers could still prevent movement
even after `Collision.canEnter()` and the old `"blocked"` fallback were handled.
The reason is that not every movement restriction reaches `tryMove()` as the
same `"blocked"` result.

v0.9.1 changes the FireRed strategy:

- While **WALK THRU WALLS** is ON, an ordinary target cell that is inside the
  loaded map is moved into directly with FireRed's native `Player.scriptStep()`
  **before normal collision logic is consulted**.
- `scriptStep()` still uses FireRed's normal step-completion code, so camera
  movement, step events and land-on-warp checks still run.
- At the outer edge of a map, FireRed is allowed to try a legitimate route/map
  connection first. If no connection succeeds, GameShark uses the same forced
  step as the full-noclip fallback.
- The wrapper is versioned so updating the GameShark ZIP without completely
  restarting Gen1Recomp cannot leave an older GameShark movement wrapper in
  control.

This is intentionally stronger than the v0.8.8-v0.9.0 implementation.

## FireRed full noclip — v0.9.0

Video testing showed that v0.8.9 was successfully crossing ordinary FireRed
collision (trees, water, fences, solid tiles), but the remaining stop occurred
at the **outer map boundary**. That is not a normal wall/tile collision.

v0.9.0 keeps FireRed's normal connection/warp handling first. If FireRed has
already tried the map edge and returns `blocked, "bounds"` because there is no
valid connection, Walk Through Walls now falls back to Game3's native
`Player.scriptStep()` and crosses the boundary as full noclip.

This makes the cheat behave more like an unrestricted GameShark walk-through-
walls code. Walking outside the authored map area can expose blank/undefined
space, so the safest way back is to return through the same edge or use the
GameShark Teleport command.

## FireRed Walk Through Walls completion — v0.8.9

The v0.8.8 persistent `Collision.canEnter()` wrapper proved the basic FireRed
path was correct: ordinary walls/trees/fences could be crossed. Video testing
also showed that some FireRed blockers still lived outside that single
collision return path.

v0.8.9 keeps the native collision wrapper and adds a final player-movement
fallback at `Player.tryMove()`:

- FireRed first performs its normal movement logic.
- If the result is still `"blocked"` while **WALK THRU WALLS** is ON,
  GameShark calls FireRed's own `Player.scriptStep(dir)`.
- `scriptStep()` is Gen1Recomp's native forced one-cell movement routine and
  explicitly skips collision.
- `"bounds"` failures are still preserved, so map connections and loaded-map
  edges are not bypassed.

This makes Walk Through Walls cover residual water/entity/tile blockers without
rewriting the FireRed movement engine.

## FireRed Walk Through Walls correction — v0.8.8

v0.8.7 identified the correct FireRed collision function but wrapped it at the
wrong time. In Game3, the `input.step` mod hook is a **pre-tick notification**
whose `next()` function is only a no-op. Actual player movement runs afterward
inside `Game3:fixedUpdate()`. That meant v0.8.7 restored
`game3.collision.canEnter()` before `Player.tryMove()` ever called it.

v0.8.8 installs one persistent wrapper around FireRed's native
`game3.collision.canEnter()` instead. The wrapper checks the GameShark
**WALK THRU WALLS** toggle dynamically:

- OFF: native FireRed collision is returned unchanged.
- ON: blocked checks originating from the live player are allowed.
- map-boundary failures remain blocked so normal map connections/warps continue
  to work and the player cannot step outside the loaded map.
- NPC/script/pathfinding checks keep native collision behavior.

This directly covers the path used by FireRed's `Player.tryMove()`.

## FireRed Walk Through Walls fix — v0.8.7

FireRed uses its own Game3 player movement path. `Player.tryMove()` calls
`src.core.game3.collision.canEnter()` directly, so the older
`movement.collision` wrapper used by GameShark never changed normal FireRed
walking.

v0.8.7 adds a FireRed-native collision bypass while **Walk Through Walls** is
enabled. It is scoped to movement checks originating from the live player and
is restored after each Game3 logic tick. Map bounds are still respected, so
the player cannot walk outside the loaded map.

## FireRed cheat execution fix — v0.8.6

v0.8.5 fixed the FireRed menu itself, but many toggles still wrote to
`game.save`. In FireRed, that is not the live gameplay state. Gen1Recomp's
Game3 layer keeps the active game in `Runtime.getSession()`.

v0.8.6 moves FireRed continuous effects to the live Runtime session and applies
them immediately when toggled as well as every FireRed logic tick:

- Max Money / Max Coins
- Master Ball ×99 / Rare Candy ×99 / PP Up ×99
- Infinite HP / Infinite PP
- All Badges, including the eight real FRLG badge script flags
- Complete Dex
- Burn Foe
- explicit FireRed battle-side handling for Infinite HP and One Hit KO

The FireRed Wild Picker also always arms its post-construction finalizer so
shiny, gender, nature and IV choices can be applied to the actual wild Pokémon.

## FireRed native menu rewrite — v0.8.5

v0.8.5 removes the FireRed dependency on the legacy Gen 1/2 ListMenu screen
registry entirely. FireRed now has its own native Game3 GameShark menu object,
pushed directly onto `src.ui.game3.stack` from the START-menu callback.

The native FireRed menu includes GameShark toggles plus Wild Pokemon, Teleport,
Give Item, Teach Move, IV/EV editing, and Friendship submenus. Gen 1 and Gen 2
continue using the existing GameShark screen system unchanged.

## FireRed activation fix — v0.8.4

The v0.8.3 native stack change still allowed one legacy UI call to happen too
early: each registered GameShark screen factory calls `mod.ui.ListMenu.new()`
while it is being constructed. FireRed's START menu protects custom `onSelect`
callbacks with `pcall`, so that constructor error was swallowed by the menu
system and the visible symptom was simply **press A and nothing happens**.

v0.8.4 does not construct a Gen 1/2 ListMenu on FireRed at all. It temporarily
uses a small capture constructor to collect the GameShark screen's title, rows,
callbacks, cursor and scrolling options. Those captured definitions are then
hosted by FireRed's native `src.ui.game3.stack`, `window`, and `frlg_font`
modules.

This keeps the existing GameShark screen logic as GameShark's own code while
using the same supported FireRed UI architecture demonstrated by working
FireRed-native mods.

Because the FireRed path directly requires engine Game3 UI modules, the
manifest now honestly declares the `engine_internals` permission.

## FireRed START-menu fix — v0.8.3

The remaining FireRed failure was not the menu drawing code itself. The mod was
still deciding whether it was in Gen 3 by looking for `game.save.generation`.
FireRed's native Game3 object does not reliably expose the same Gen 1/2
`Game.save` shape, so the mod could incorrectly fall back to the Gen 1/2
`mod.ui.push` path after the GAMESHARK row was selected.

v0.8.3 fixes that in two places:

- FireRed is detected from `src.core.GameVersion` (`firered`) first, with the old
  save-generation check retained only as a fallback.
- FireRed menus are pushed directly to `src.ui.game3.stack`, rather than looking
  for a Gen 1/2-style `game.stack` field on the live FireRed object.
- The START-menu row now has a stable `id = "gameshark"` and is inserted before
  FireRed's native `save` row by id. The hook keeps the Gen 1/2 label-based path
  unchanged.

The implementation was independently adapted to Gen1Recomp's public/current
Game3 architecture after comparing behavior with another FireRed-native cheat
mod. No source from that mod is copied into GameShark.

## FireRed menu fix — v0.8.2

FireRed uses Gen1Recomp's separate **Game3 240×160 modal UI stack**. Version
0.8.2 no longer tries to place the Gen 1/2 `ListMenu` screen directly on that
stack. Instead, GameShark builds its normal menu data and presents it through a
native FireRed menu host using Game3's own window/font/stack APIs.

This applies to the main **GAMESHARK G3** screen and every GameShark submenu.
The START-menu hook also uses the live Game3 object passed to the row's
`onSelect` callback.

Gen 1 and Gen 2 keep their existing UI path unchanged.

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
GameShark-0.9.3.zip
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



## Red Safari / trainer-catch fixes — v0.7.10

Version **0.7.10** fixes three Gen 1 compatibility problems reported on
Pokemon Red:

- **Safari Ball** now refills the active Safari Game counter after the engine
  processes a ball throw, so the displayed/usable count remains full.
- **Safari Time** now refills after the engine processes a player step, so Red
  no longer visibly counts down while the cheat is enabled.
- **Steal Trainer** now installs from the engine's `battle.started` event in
  addition to the compatibility stack scan. This makes the cheat independent
  of the exact battle-screen stack layout and restores the Red path used by
  current Gen1Recomp builds/forks.

The Gen 1 trainer-catch path still performs a guaranteed normal capture, stores
the caught Pokemon through Gen1Recomp's stock catch routine, then finishes the
trainer encounter with a **win** result so the same NPC does not immediately
restart the battle.

These changes apply to the shared Gen 1 path used by **Red, Blue, and Yellow**.
Gold, Silver, and Crystal keep their existing Gen 2 trainer-catch
implementation.

## Friendship editor — v0.7.9

Version **0.7.9** adds a **FRIENDSHIP** editor.

### Gold / Silver / Crystal

Every non-Egg party Pokemon can be selected individually. The menu shows its
current friendship value and provides:

- **MAX FRIENDSHIP — 255**
- **ZERO FRIENDSHIP — 0**

This is useful for friendship evolutions and for immediately testing the Gen 2
moves **Return** and **Frustration** at opposite ends of the friendship scale.

Eggs are shown but cannot be edited because Gen1Recomp keeps their hatch
counter separate from normal Pokemon friendship.

### Pokemon Yellow

Yellow uses its original starter-Pikachu-only friendship system rather than
the per-Pokemon Gen 2 system. When the active save exposes Yellow's
`pikachuHappiness` capability, GameShark shows the same **FRIENDSHIP** menu for
Pikachu and lets you set it to 255 or 0.

Pikachu's separate mood byte is intentionally left alone. The original Yellow
engine combines friendship and mood when choosing Pikachu's reaction, so this
cheat changes friendship without overwriting temporary/scripted moods.

### Red / Blue

The friendship menu is hidden because Red and Blue do not have a corresponding
friendship value.

The implementation is capability/generation based rather than a hard-coded
game-version allow-list, keeping it compatible with the Gen1Recomp mod lint and
Gen 2 compatibility checks.

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
GameShark-0.9.3.zip
```

## Development notes

GameShark translates GameShark-style effects into Gen1Recomp's supported runtime/save APIs. It does not emulate a physical GameShark device or blindly write raw Game Boy memory for every feature.

Some original GameShark codes are retained as historical/reference identifiers inside the source, while the actual implementation uses generation-aware engine behavior where needed for stability.

For the complete version-by-version history, see [`CHANGELOG.md`](CHANGELOG.md).


## FireRed / Gen 3 support — v0.8.0

GameShark now declares and supports **Gen 3** in current Gen1Recomp builds,
with FireRed as the first supported Gen 3 game.

### FireRed features

- Walk Through Walls
- No Random Battles
- Master Ball x99
- Rare Candy x99
- PP Up x99
- Max Money and Max Game Corner Coins
- Infinite PP
- Infinite HP
- All 8 Kanto Badges
- One Hit KO
- Burn Foe
- **Easy Catch** (guaranteed wild catches)
- **Complete Dex** (seen + caught)
- Wild Pokemon picker and level override
- Wild Shiny control
- **Wild Nature selector**
- **Wild Max IVs**
- Instant Battle
- Give Item from FireRed's item catalog
- Unrestricted Teach Move using FireRed's move catalog
- Friendship editor
- **Gen 3 IV / EV editor** (six IVs and six EVs)
- Teleport to Kanto/Sevii Pokemon Center destinations

### Intentionally not exposed on FireRed yet

The legacy **Safari Ball**, **Safari Time**, **Pay Day Fix**, **Surfboard**, and
**Steal Trainer Pokemon** entries remain generation-specific. In particular,
trainer-Pokemon capture needs a FireRed-native battle teardown implementation
before it can be enabled safely without leaving trainer scripts in a bad state.

### Why the FireRed implementation does not write raw GBA addresses

The historical GameShark/Action Replay codes are used as behavior references.
Inside Gen1Recomp the mod implements the equivalent effects through Mod API 2
and the Gen 3 compatibility facade, avoiding ROM-revision-specific RAM
addresses.

## FireRed menu activation fix — v0.8.1

Version **0.8.1** fixes the FireRed **GAMESHARK** start-menu row appearing correctly but doing nothing when **A** was pressed.

FireRed uses Gen1Recomp's Gen 3 modal UI stack while the shared GameShark `ListMenu` screens use the Gen 1/2 StateStack-style screen contract. GameShark now hosts those registered screens through a small Gen 3 compatibility bridge, adapts their method-style `update` and `draw` calls, and prevents the still-open FireRed START menu underneath from consuming the same button edge.

The existing Red/Blue/Yellow and Gold/Silver/Crystal UI paths are unchanged.
