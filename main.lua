-- GameShark Compatibility 0.7.8
-- Universal Gen 1 + Gen 2 build for Gen1Recomp 0.1.79+.
-- Author: goofwear
-- Uses only the public mod API and objects handed to hooks.

local MAIN_SCREEN = "GameSharkCompat"
local PICK_SCREEN = "GameSharkPokemonPicker"
local WILD_SCREEN = "GameSharkWildPokemon"
local LEVEL_SCREEN = "GameSharkWildLevel"
local TELEPORT_SCREEN = "GameSharkTeleport"
local PARTY_EDIT_SCREEN = "GameSharkPartyEdit"
local MON_EDIT_SCREEN = "GameSharkMonEdit"
local DV_PICK_SCREEN = "GameSharkDvPick"
local EV_HEX_SCREEN = "GameSharkEvHex"
local ITEM_PICK_SCREEN = "GameSharkItemPick"
local ITEM_QTY_SCREEN = "GameSharkItemQty"
local MOVE_PARTY_SCREEN = "GameSharkMoveParty"
local MOVE_PICK_SCREEN = "GameSharkMovePick"
local MOVE_SLOT_SCREEN = "GameSharkMoveSlot"

local GENDER_CHOICES = { "random", "male", "female" }
local SHINY_CHOICES = { "random", "yes", "no" }

local CHEATS = {
  { name="WALL WALK", effect="walk", gen1="010138CD", gold="010AA3CE" },
  { name="NO BATTLES", effect="no_encounters", gen1="01033CD1", gold="01000BD2" },
  { name="MASTER BALL", effect="master_ball", gen1="01017CCF", gold="0101FDD5" },
  { name="MAX MONEY", effect="cash", gen1="019947D3", gold="019973D5" },
  { name="MAX COINS", effect="coins", gen1=nil, gold=nil },
  { name="INFINITE PP", effect="infinite_pp", gen1=nil, gold=nil },
  { name="PP UP x99", effect="pp_up", gen1=nil, gold=nil },
  { name="RARE CANDY", effect="rare_candy", gen1="01287CCF", gold="0120ABD5" },
  { name="INFINITE HP", effect="party_hp", gen1="01FF16D0", gold="01FF4CDA" },
  { name="ALL BADGES", effect="badges", gen1="01FF56D3", gold="01FF7CD5" },
  { name="ONE HIT KO", effect="enemy_hp", gen1="0100E7CF", gold="010000D1" },
  { name="BURN FOE", effect="enemy_burn", gen1="0170E9CF", gold="0100ADD7" },
  { name="SAFARI BALL", effect="safari_balls", gen1="016447DA", gen2=false },
  { name="SAFARI TIME", effect="safari_time", gen1="01F00ED7", gen2=false },
  { name="STEAL TRAINER", effect="steal_trainer", gen1="010157D0", gold="010116D1" },
  { name="WILD PICK", effect="wild_pick", gen1="01FF00D0", gold="01??EDD0" },
  { name="PAY DAY FIX", effect="payday_fix", gen1=false, gold=nil, gen2only=true },
}

local GEN1_BADGES = {
  "BOULDERBADGE","CASCADEBADGE","THUNDERBADGE","RAINBOWBADGE",
  "SOULBADGE","MARSHBADGE","VOLCANOBADGE","EARTHBADGE",
}
local JOHTO_BADGES = { "ZEPHYR","HIVE","PLAIN","FOG","MINERAL","STORM","GLACIER","RISING" }
local KANTO_BADGES = { "BOULDER","CASCADE","THUNDER","RAINBOW","SOUL","MARSH","VOLCANO","EARTH" }

local function isGen2(game)
  local s=game and game.save
  return s and s.generation==2 or false
end

-- Crystal-only capability probe. Gold and Silver do not contain the GS Ball
-- item/event scripts; Crystal does. Checking the active game's decoded item
-- table keeps this generation-safe without hard-coding save.version strings.
local function hasCrystalGsBallEvent(game)
  local items=game and game.data and game.data.items
  return isGen2(game) and type(items)=="table" and type(items.GS_BALL)=="table"
end
local function cleanCode(v) return (tostring(v or ""):upper():gsub("[^0-9A-F]", "")) end
local function parseCode(v)
  local raw=cleanCode(v)
  if #raw~=8 then return nil,"eight hexadecimal digits required" end
  if raw:sub(1,2)~="01" and raw:sub(1,2)~="91" then return nil,"unsupported code type" end
  return {raw=raw,value=tonumber(raw:sub(3,4),16),addressHex=raw:sub(7,8)..raw:sub(5,6)}
end

return function(mod)
  local state = {
    active={}, selectedSpecies="PIKACHU",
    wildGender="random", wildShiny="random",
    wildLevel=nil, -- nil = AUTO / preserve the game's normal encounter level
    pendingWild=nil,
  }

  local uiPos = {
    mainIndex = 1, mainScroll = 0,
    wildIndex = 1, wildScroll = 0,
    pickIndex = 1, pickScroll = 0,
    levelIndex = 1, levelScroll = 0,
    teleportIndex = 1, teleportScroll = 0,
    partyEditIndex = 1, partyEditScroll = 0,
    monEditIndex = 1, monEditScroll = 0,
    dvPickIndex = 1, dvPickScroll = 0,
    evHexIndex = 1, evHexScroll = 0,
    itemPickIndex = 1, itemPickScroll = 0,
    itemQtyIndex = 1, itemQtyScroll = 0,
    movePartyIndex = 1, movePartyScroll = 0,
    movePickIndex = 1, movePickScroll = 0,
    moveSlotIndex = 1, moveSlotScroll = 0,
  }

  local moveEditor = {
    partySlot = 1,
    moveId = nil,
    moveName = nil,
  }

  local giveItemState = {
    itemId = nil,
    itemName = nil,
    pocket = nil,
  }

  -- Session-local editor state. The actual DV/Stat EXP values live on the
  -- Pokemon in the game's save; these fields only remember which row is open.
  local editor = {
    partySlot = 1,
    dvKey = nil,
    evKey = nil,
    hexDigits = {0,0,0,0},
  }

  -- Warp on the frame after the Teleport menu closes. Gold otherwise begins
  -- its map transition while the ListMenu is still the top UI screen.
  local pendingTeleport=nil
  local pendingTeleportFrames=0
  if type(mod.save)=="table" then
    if type(mod.save.activeEffects)=="table" then state.active=mod.save.activeEffects end
    if type(mod.save.selectedSpecies)=="string" then state.selectedSpecies=mod.save.selectedSpecies end
    if mod.save.wildGender=="male" or mod.save.wildGender=="female" or mod.save.wildGender=="random" then
      state.wildGender=mod.save.wildGender
    end
    if mod.save.wildShiny=="yes" or mod.save.wildShiny=="no" or mod.save.wildShiny=="random" then
      state.wildShiny=mod.save.wildShiny
    end
    if type(mod.save.wildLevel)=="number"
       and mod.save.wildLevel>=1 and mod.save.wildLevel<=100 then
      state.wildLevel=math.floor(mod.save.wildLevel)
    end
    -- migrate v0.4.x code-keyed state
    if type(mod.save.active)=="table" then
      for _,c in ipairs(CHEATS) do
        if (c.gen1 and mod.save.active[c.gen1]) or (c.gold and not c.gold:find('?',1,true) and mod.save.active[c.gold]) then
          state.active[c.effect]=true
        end
      end
    end
  end
  -- Gen1Recomp 0.1.93 has PAY_DAY in Gold's move data but no Gen-2
  -- EFFECT_PAY_DAY implementation. Keep the compatibility repair enabled by
  -- default; users can turn it off from the GameShark menu.
  if state.active.payday_fix == nil then
    state.active.payday_fix = true
  end

  local function persist()
    if type(mod.save)=="table" then
      mod.save.activeEffects=state.active
      mod.save.selectedSpecies=state.selectedSpecies
      mod.save.wildGender=state.wildGender
      mod.save.wildShiny=state.wildShiny
      mod.save.wildLevel=state.wildLevel
    end
  end
  local function enabled(effect) return state.active[effect]==true end
  local function setEnabled(effect,value) state.active[effect]=value==true; persist() end

  -- Emulate the real Crystal GameShark code 010B3CBE. In the original game
  -- that writes $0B to sGSBallFlag. Gen1Recomp represents that SRAM byte as
  -- save.crystal.gsBall = "have"; the native Crystal script then hands out
  -- the GS Ball when the player tries to leave Goldenrod Pokemon Center.
  local function enableCelebiEvent(game)
    if not hasCrystalGsBallEvent(game) then
      return false,"GS Ball event is Crystal-only"
    end
    local save=game and game.save
    if not save then return false,"save unavailable" end
    save.crystal=save.crystal or {}
    save.crystal.gsBall="have"
    return true
  end

  local function celebiEventStatus(game)
    if not hasCrystalGsBallEvent(game) then return nil end
    local crystal=game.save and game.save.crystal
    local v=crystal and crystal.gsBall
    if v=="have" then return "READY" end
    if v=="given" then return "GIVEN" end
    if v=="used" then return "USED" end
    return "START"
  end

  local function ensureItem(save,id,qty)
    save.inventory=save.inventory or {}
    if (save.inventory[id] or 0)<qty then save.inventory[id]=qty end

    -- Both generations use bagOrder in current Gen1Recomp. Gen 2 then buckets
    -- the same flat inventory into ITEM / BALL / KEY_ITEM / TM_HM pockets.
    save.bagOrder=save.bagOrder or {}
    local found=false
    for _,v in ipairs(save.bagOrder) do
      if v==id then found=true break end
    end
    if not found then table.insert(save.bagOrder,id) end
  end

  local function addItemToBag(game,id,qty)
    local save=game and game.save
    if not (save and id) then return false,"save unavailable" end
    save.inventory=save.inventory or {}
    save.bagOrder=save.bagOrder or {}

    local def=game and game.data and game.data.items and game.data.items[id]
    local pocket=(def and def.pocket) or "ITEM"

    -- Gen 2 key items and HMs are unique inventory entries. Keep those at one
    -- copy even if a larger quantity somehow reaches this helper.
    local unique = pocket=="KEY_ITEM"
      or (pocket=="TM_HM" and tostring(id):sub(1,3)=="HM_")

    local add=math.max(1,math.min(99,math.floor(tonumber(qty) or 1)))
    local cur=tonumber(save.inventory[id]) or 0
    local target=unique and 1 or math.min(99,cur+add)
    save.inventory[id]=target

    local found=false
    for _,v in ipairs(save.bagOrder) do
      if v==id then found=true break end
    end
    if not found then table.insert(save.bagOrder,id) end
    return true,target
  end

  local function itemRows(game)
    local rows={}
    local items=game and game.data and game.data.items or {}

    for id,def in pairs(items) do
      -- Gen 2's decoded tables may expose auxiliary/alias entries alongside
      -- the canonical symbolic item records. Inventory keys throughout
      -- Gen1Recomp are symbolic strings, so only those are valid Give Item
      -- candidates. This also prevents mixed number/string keys from reaching
      -- Lua's relational operators during sorting.
      if type(id)=="string" and type(def)=="table" then
        local name=def.name
        local index=def.index
        local pocket=def.pocket or "ITEM"
        local upper=id:upper()

        local giveable = type(name)=="string" and name~=""
          and upper~="NO_ITEM"
          and upper~="TERU_SAMA"
          and not upper:find("BADGE",1,true)

        if giveable then
          rows[#rows+1]={
            id=id,
            name=name,
            index=type(index)=="number" and index or 99999,
            pocket=type(pocket)=="string" and pocket or "ITEM",
          }
        end
      end
    end

    table.sort(rows,function(a,b)
      local ai=tonumber(a.index) or 99999
      local bi=tonumber(b.index) or 99999
      if ai~=bi then return ai<bi end

      local an=tostring(a.name or a.id or "")
      local bn=tostring(b.name or b.id or "")
      if an~=bn then return an<bn end

      -- tostring is intentional: never allow heterogeneous IDs to raise
      -- "attempt to compare number with string" on Gen 2.
      return tostring(a.id)<tostring(b.id)
    end)
    return rows
  end

  -- Restore one player move to its real maximum PP.
  --
  -- Gen 1 derives maximum PP from the move's base PP plus PP Ups.
  -- Gen 2 stores the computed maximum directly in move.maxPp.

  ---------------------------------------------------------------------------
  -- Unrestricted move editor
  ---------------------------------------------------------------------------

  local function moveRows(game,mon)
    local rows={}
    local moves=game and game.data and game.data.moves or {}
    local known={}
    for _,mv in ipairs((mon and mon.moves) or {}) do
      if type(mv)=="table" and type(mv.id)=="string" then known[mv.id]=true end
    end

    for id,def in pairs(moves) do
      if type(id)=="string" and type(def)=="table"
         and type(def.name)=="string" and def.name~="" then
        local upper=id:upper()
        if upper~="NO_MOVE" and upper~="NONE" and not upper:find("UNUSED",1,true) then
          rows[#rows+1]={
            id=id,
            name=def.name,
            index=type(def.index)=="number" and def.index or 99999,
            pp=tonumber(def.pp) or 0,
            known=known[id]==true,
          }
        end
      end
    end

    table.sort(rows,function(a,b)
      local ai=tonumber(a.index) or 99999
      local bi=tonumber(b.index) or 99999
      if ai~=bi then return ai<bi end
      local an=tostring(a.name or a.id or "")
      local bn=tostring(b.name or b.id or "")
      if an~=bn then return an<bn end
      return tostring(a.id)<tostring(b.id)
    end)
    return rows
  end

  local function selectedMoveMon(game)
    local party=game and game.save and game.save.party
    return party and party[moveEditor.partySlot] or nil
  end

  local function setMoveSlot(game,mon,slot,moveId)
    if not (game and mon and type(slot)=="number" and slot>=1 and slot<=4) then
      return false,"invalid slot"
    end
    local def=game.data and game.data.moves and game.data.moves[moveId]
    if type(def)~="table" then return false,"unknown move" end

    mon.moves=mon.moves or {}

    -- A GameShark-taught move is a fresh move: full base PP and no inherited
    -- PP Ups from whatever move previously occupied the slot.
    local base=math.max(0,math.floor(tonumber(def.pp) or 0))
    local entry={ id=moveId, pp=base }

    -- Gen 2 stores maxPp on the move instance. Keeping it on Gen 1 is harmless,
    -- but only add it where the current save is actually Gen 2.
    if isGen2(game) then entry.maxPp=base end

    mon.moves[slot]=entry

    -- Ensure compact sequential slots. This matters if an old/debug save had
    -- a hole in its move table.
    local compact={}
    for i=1,4 do
      local mv=mon.moves[i]
      if type(mv)=="table" and mv.id then compact[#compact+1]=mv end
    end
    mon.moves=compact
    return true
  end

  local function teachMove(game,mon,moveId)
    if not (game and mon and moveId) then return false,"missing target" end
    mon.moves=mon.moves or {}

    -- Never create duplicate move slots. Selecting an already-known move just
    -- restores its PP and treats the operation as successful.
    for _,mv in ipairs(mon.moves) do
      if mv.id==moveId then
        local def=game.data and game.data.moves and game.data.moves[moveId]
        local base=def and tonumber(def.pp) or 0
        local bonus=math.floor((base or 0)/5)*(mv.ppUps or 0)
        local max=math.max(0,(base or 0)+bonus)
        mv.pp=max
        if isGen2(game) then mv.maxPp=max end
        return true,"known"
      end
    end

    if #mon.moves<4 then
      return setMoveSlot(game,mon,#mon.moves+1,moveId)
    end
    return false,"full"
  end

  local function refillMovePP(game,mv,gold)
    if type(mv)~="table" or not mv.id then return end
    local maxPP
    if gold then
      maxPP=mv.maxPp
      if not maxPP then
        local def=game and game.data and game.data.moves and game.data.moves[mv.id]
        if def and def.pp then
          local bonus=math.min(math.floor(def.pp/5),7)
          maxPP=def.pp+(mv.ppUps or 0)*bonus
          mv.maxPp=maxPP
        end
      end
    else
      local def=game and game.data and game.data.moves and game.data.moves[mv.id]
      if def and def.pp then
        maxPP=def.pp+(mv.ppUps or 0)*math.floor(def.pp/5)
      end
    end
    if maxPP and maxPP>0 then mv.pp=maxPP end
  end

  local function refillMonPP(game,mon,gold)
    if type(mon)~="table" or type(mon.moves)~="table" then return end
    for _,mv in ipairs(mon.moves) do refillMovePP(game,mv,gold) end
  end

  -- Keep both the save-party copy and the currently active battle copy full.
  -- Gen 1 uses a battler.curMoves working set; Gold battles directly reference
  -- the active party mon's moves.
  local function refillPlayerPP(game)
    if not game then return end
    local gold=isGen2(game)
    local save=game.save
    if save and type(save.party)=="table" then
      for _,mon in ipairs(save.party) do refillMonPP(game,mon,gold) end
    end

    if gold then
      for _,screen in ipairs(goldBattleScreens(game)) do
        local battle=screen.battle
        if battle then
          refillMonPP(game,battle.player,true)
        end
      end
    else
      for _,battle in ipairs(gen1BattleStates(game)) do
        if battle.player then
          -- Active Gen-1 PP lives in curMoves while the battle is running.
          if type(battle.player.curMoves)=="table" then
            for _,mv in ipairs(battle.player.curMoves) do
              refillMovePP(game,mv,false)
            end
          end
          refillMonPP(game,battle.player.mon,false)
        end
      end
    end
  end

  local function grantBadges(save)
    if save.generation==2 then
      save.player=save.player or {}
      save.player.badges=save.player.badges or {}
      save.player.kantoBadges=save.player.kantoBadges or {}

      -- Older universal builds wrote each Gold badge twice: once by name
      -- and once by numeric index. Remove those duplicate aliases first.
      for i=1,8 do
        save.player.badges[i]=nil
        save.player.kantoBadges[i]=nil
      end

      for _,b in ipairs(JOHTO_BADGES) do save.player.badges[b]=true end
      for _,b in ipairs(KANTO_BADGES) do save.player.kantoBadges[b]=true end
    else
      save.inventory=save.inventory or {}
      for _,b in ipairs(GEN1_BADGES) do save.inventory[b]=1 end
    end
  end

  local trainerCatchInProgress=false
  local patched={}
  local function gen1BattleStates(game)
    local out={}; local stack=game and game.stack and game.stack.states
    if type(stack)~="table" then return out end
    for _,s in ipairs(stack) do
      if type(s)=="table" and type(s.enemy)=="table" and type(s.enemy.mon)=="table" then out[#out+1]=s end
    end
    return out
  end
  local function goldBattleScreens(game)
    local out={}; local stack=game and game.stack and game.stack.states
    if type(stack)~="table" then return out end
    for _,s in ipairs(stack) do
      if type(s)=="table" and type(s.battle)=="table" and s.battle.enemy and type(s.throwBallAtTrainer)=="function" then out[#out+1]=s end
    end
    return out
  end
  local function patchGoldTrainer(screen)
    if patched[screen] then return end
    patched[screen]=screen.throwBallAtTrainer
    screen.throwBallAtTrainer=function(self,itemId)
      trainerCatchInProgress=true
      local oldWild=self.battle.wild; self.battle.wild=true
      local ok,res=pcall(function() return self:useItem(itemId) end)
      self.battle.wild=oldWild; trainerCatchInProgress=false
      if not ok then error(res,0) end
      return res
    end
  end
  local function unpatchGoldTrainer(screen)
    if patched[screen] then screen.throwBallAtTrainer=patched[screen]; patched[screen]=nil end
  end
  local function patchGen1Trainer(b)
    if b._gamesharkThrowInstalled or b.kind~="trainer" then return end

    b._gamesharkThrowInstalled=true
    b._gamesharkOriginalThrowBall=b.throwBall
    b._gamesharkOriginalStoreCaughtMon=b.storeCaughtMon
    b._gamesharkOriginalCatchAttempt=b.catchAttempt

    -- Gen 1 trainer stealing should be a guaranteed catch, but the second
    -- result from the capture path is the shake count.  Older builds forced
    -- true,255 through catch.rate, producing 255 wobble steps on current
    -- Gen1Recomp.  Intercept the actual attempt instead.
    b.catchAttempt=function(self,ball,overrideRate)
      if self._gamesharkStealActive then
        return true,3
      end
      return self:_gamesharkOriginalCatchAttempt(ball,overrideRate)
    end

    b.throwBall=function(self,ball)
      -- The stock Gen-1 routine blocks balls whenever kind ~= "wild".
      -- Switch only this trainer battle into the catchable path.  The
      -- storeCaughtMon wrapper below restores trainer identity before finish.
      self._gamesharkStealActive=true
      self._gamesharkOriginalKind=self.kind
      self.kind="wild"
      return self:_gamesharkOriginalThrowBall(ball)
    end

    b.storeCaughtMon=function(self)
      -- Let Gen1Recomp do every normal capture side effect first: party/box,
      -- Pokedex, OT, nickname prompt and pokemon.caught event.  Vanilla then
      -- sets result="caught".  For a stolen trainer Pokemon that result is
      -- wrong: trainer encounter continuations only mark the NPC defeated on
      -- "win", otherwise the same trainer sees the player and starts again.
      local result=self:_gamesharkOriginalStoreCaughtMon()
      if self._gamesharkStealActive then
        self.kind=self._gamesharkOriginalKind or "trainer"
        self.result="win"
        self._gamesharkStealActive=nil
        if type(self.playVictoryMusic)=="function" then self:playVictoryMusic() end
      end
      return result
    end
  end

  local function unpatchGen1Trainer(b)
    if b and b._gamesharkThrowInstalled and not b._gamesharkStealActive then
      b.throwBall=nil
      b.storeCaughtMon=nil
      b.catchAttempt=nil
      b._gamesharkOriginalThrowBall=nil
      b._gamesharkOriginalStoreCaughtMon=nil
      b._gamesharkOriginalCatchAttempt=nil
      b._gamesharkThrowInstalled=nil
      b._gamesharkOriginalKind=nil
    end
  end

  local function burnEnemy(game)
    if isGen2(game) then
      for _,s in ipairs(goldBattleScreens(game)) do
        local mon=s.battle and s.battle.enemy
        -- Gen 2 stores the full status id ("burn"), while Gen 1 stores "BRN".
        if mon and not mon.status then mon.status="burn" end
      end
    else
      for _,b in ipairs(gen1BattleStates(game)) do
        if b.enemy and b.enemy.mon and not b.enemy.mon.status then
          b.enemy.mon.status="BRN"; b.enemy.shownStatus="BRN"
        end
      end
    end
  end

  local function useSurfboard(game)
    local save=game and game.save; local mon=save and save.party and save.party[1]
    if not mon then return false end
    mon.moves=mon.moves or {}
    local tempMove=nil; local knows=false
    for _,m in ipairs(mon.moves) do if m.id=="SURF" then knows=true break end end
    if not knows then tempMove={id="SURF",pp=15}; table.insert(mon.moves,tempMove) end
    local ok=false
    if isGen2(game) then
      local player=save.player or {}; save.player=player; player.badges=player.badges or {}
      local hadFog=player.badges.FOG; player.badges.FOG=true
      local world=game.world
      if world and type(world.trySurfOW)=="function" then ok=world:trySurfOW() and true or false end
      if not hadFog then player.badges.FOG=nil end
    else
      local ow=game.overworld
      if ow and type(ow.useSurfFieldMove)=="function" then
        local reason=ow:useSurfFieldMove()
        if reason=="ok" and ow.player and ow.player.facingCell and ow.trySurf then
          local fx,fy=ow.player:facingCell(); ow:trySurf(fx,fy); ok=true
        end
      end
    end
    if tempMove then for i=#mon.moves,1,-1 do if mon.moves[i]==tempMove then table.remove(mon.moves,i); break end end end
    return ok
  end

  local function selectedDef()
    return mod.content.pokemon:get(state.selectedSpecies)
  end

  local function selectedGenderless()
    local def=selectedDef()
    return not def or def.genderRatio==nil or def.genderRatio==0xff
  end

  local function cycleChoice(current, choices)
    for i,v in ipairs(choices) do
      if v==current then return choices[(i % #choices)+1] end
    end
    return choices[1]
  end

  local function startInstantBattle(game)
    -- Instant Battle deliberately requires a manual level. AUTO remains the
    -- "do not override the encounter table" setting for normal Wild Pick.
    if not state.wildLevel then return false,"set level" end
    if not mod.world then return false,"world API unavailable" end

    local level=state.wildLevel
    local gold=isGen2(game)

    -- Gold's Mon constructor runs shiny.roll/gender.roll while the Gen-2
    -- start_battle script verb constructs the enemy. Reuse the same pending
    -- identity marker as normal Wild Pick so Gender/Shiny apply here too.
    if gold and (state.wildGender~="random" or state.wildShiny~="random") then
      state.pendingWild={ species=state.selectedSpecies, level=level }
    end

    local ok,err
    if gold then
      -- Gen 2 intentionally has no WorldAPI:startWildBattle(). Its supported
      -- facade exposes the cart-native start_battle verb through queueScript.
      -- That path builds a src.battle.gen2.Mon and calls Gold's World:startBattle,
      -- so it works on both indoor and outdoor maps and preserves native Gold
      -- battle teardown/return behavior.
      if type(mod.world.queueScript)~="function" then
        state.pendingWild=nil
        return false,"Gen 2 battle API unavailable"
      end
      ok,err=mod.world:queueScript({
        {"start_battle","wild",state.selectedSpecies,level}
      })
    else
      -- Gen 1 has a dedicated public startWildBattle helper.
      if type(mod.world.startWildBattle)~="function" then
        return false,"Gen 1 battle API unavailable"
      end
      ok,err=mod.world:startWildBattle(state.selectedSpecies,level)
    end

    if not ok then
      state.pendingWild=nil
      return false,err
    end
    return true
  end

  -- Battle Art 1ST compatibility is OPTIONAL. Nothing in the manifest depends
  -- on Battle Art. If it is installed, its public `exports.lib` lets companion
  -- mods reach the same cached FreeMove module that its first-person walk uses.
  local battleArtCompatInstalled=false
  local function installBattleArtCompat()
    if battleArtCompatInstalled or not mod.find then return end
    local ok, other=pcall(mod.find, "BATTLE_ART_VOXEL_FORK")
    if not ok or not other or not other.exports then return end
    local V=other.exports.lib
    if not V or type(V.require)~="function" then return end
    local okFree, FreeMove=pcall(V.require, "FreeMove")
    if not okFree or type(FreeMove)~="table" or type(FreeMove.tick)~="function" then return end
    if FreeMove._gamesharkWallWalkCompat then
      battleArtCompatInstalled=true
      return
    end

    local originalTick=FreeMove.tick
    FreeMove.tick=function(stateObj)
      if not enabled("walk") or not stateObj or not stateObj.map then
        return originalTick(stateObj)
      end

      -- Battle Art's free walk bypasses movement.collision and checks these
      -- three sources directly. Relax only those checks, only for this tick,
      -- then restore the other mod's state exactly as it was.
      local map=stateObj.map
      local oldWalkable=rawget(map, "isWalkableCell")
      local oldEntities=stateObj.entities
      local game=mod.game
      local field=game and game.data and game.data.field
      local oldPairs=field and field.tilePairs

      map.isWalkableCell=function(self,cx,cy)
        return self:inBounds(cx,cy)
      end
      stateObj.entities={}
      if field and oldPairs then
        field.tilePairs={ land={}, water={} }
      end

      local okTick,a,b,c=pcall(originalTick,stateObj)

      if oldWalkable==nil then map.isWalkableCell=nil else map.isWalkableCell=oldWalkable end
      stateObj.entities=oldEntities
      if field and oldPairs then field.tilePairs=oldPairs end

      if not okTick then error(a,0) end
      return a,b,c
    end
    FreeMove._gamesharkWallWalkCompat=true
    battleArtCompatInstalled=true
  end

  local SHINY_ATTACK_DVS = { 2, 3, 6, 7, 10, 11, 14, 15 }

  local function hpDV(dvs)
    local function bit(v) return (v or 0) % 2 end
    return bit(dvs.attack) * 8 + bit(dvs.defense) * 4
      + bit(dvs.speed) * 2 + bit(dvs.special)
  end

  local function vanillaGender(def, dvs)
    local ratio=def and def.genderRatio
    if ratio==nil or ratio==0xff then return "unknown" end
    local threshold=math.floor(ratio/16)
    return ((dvs and dvs.attack or 0)<threshold) and "female" or "male"
  end

  local function isShinyDVs(dvs)
    if not dvs then return false end
    if dvs.speed~=10 or dvs.defense~=10 or dvs.special~=10 then return false end
    local a=dvs.attack or 0
    return a%4==2 or a%4==3
  end

  local function chooseAttackDV(def, current, wantedGender, requireShiny)
    local pool={}
    if requireShiny then
      for _,v in ipairs(SHINY_ATTACK_DVS) do pool[#pool+1]=v end
    else
      for v=0,15 do pool[#pool+1]=v end
    end

    local best=nil
    local bestDist=999
    for _,v in ipairs(pool) do
      local ok=true
      if wantedGender=="male" or wantedGender=="female" then
        ok=(vanillaGender(def,{attack=v})==wantedGender)
      end
      if ok then
        local dist=math.abs(v-(current or v))
        if dist<bestDist then best,bestDist=v,dist end
      end
    end
    return best
  end

  local function statValue(base,dv,level,statExp)
    local exp=math.floor(math.sqrt(statExp or 0)/4)
    return math.floor((((base or 1)*2+(dv or 0)*2+exp)*level)/100)+5
  end

  local function refreshGoldStats(mon,def)
    if not (mon and def and mon.dvs) then return end
    local level=mon.level or 1
    local se=mon.statExp or {}
    mon.dvs.hp=hpDV(mon.dvs)
    local hp=math.floor((((def.baseStats and def.baseStats.hp or 1)*2
      +(mon.dvs.hp or 0)*2+math.floor(math.sqrt(se.hp or 0)/4))*level)/100)
      +level+10
    local oldMax=mon.maxHp or (mon.stats and mon.stats.hp) or hp
    local oldHp=mon.hp or oldMax
    mon.stats=mon.stats or {}
    mon.stats.hp=hp
    mon.stats.attack=statValue(def.baseStats and def.baseStats.attack,mon.dvs.attack,level,se.attack)
    mon.stats.defense=statValue(def.baseStats and def.baseStats.defense,mon.dvs.defense,level,se.defense)
    mon.stats.speed=statValue(def.baseStats and def.baseStats.speed,mon.dvs.speed,level,se.speed)
    mon.stats.specialAttack=statValue(def.baseStats and def.baseStats.specialAttack,mon.dvs.special,level,se.special or se.specialAttack)
    mon.stats.specialDefense=statValue(def.baseStats and def.baseStats.specialDefense,mon.dvs.special,level,se.special or se.specialDefense)
    mon.maxHp=hp
    -- Wild Pokemon are normally full when built. Preserve damage if some other
    -- mod deliberately altered HP before battle.started.
    if oldHp>=oldMax then mon.hp=hp else mon.hp=math.max(1,math.min(hp,oldHp)) end
  end

  local function applyPendingWildIdentity(mon)
    local p=state.pendingWild
    if not (p and mon and mon.species==p.species
       and (p.level==nil or mon.level==nil or mon.level==p.level)) then
      return
    end

    local def=mod.content.pokemon:get(mon.species)
    if not def then state.pendingWild=nil; return end
    mon.dvs=mon.dvs or {}

    if state.wildShiny=="yes" then
      mon.dvs.defense=10
      mon.dvs.speed=10
      mon.dvs.special=10
      local chosen=chooseAttackDV(def,mon.dvs.attack,state.wildGender,true)
      -- Some authentic Gen-2 gender/shiny combinations are impossible
      -- (for example certain 12.5%-female species). Shininess wins in that
      -- case and the engine-derived gender is retained.
      mon.dvs.attack=chosen or chooseAttackDV(def,mon.dvs.attack,"random",true) or 10
    elseif state.wildShiny=="no" and isShinyDVs(mon.dvs) then
      -- Break the shiny pattern without disturbing Attack/gender.
      mon.dvs.speed=9
    end

    if state.wildGender=="male" or state.wildGender=="female" then
      local chosen=chooseAttackDV(def,mon.dvs.attack,state.wildGender,state.wildShiny=="yes")
      if chosen then mon.dvs.attack=chosen end
    end

    mon.dvs.hp=hpDV(mon.dvs)
    mon.shiny=isShinyDVs(mon.dvs)
    mon.gender=vanillaGender(def,mon.dvs)
    refreshGoldStats(mon,def)
    state.pendingWild=nil
  end


  ---------------------------------------------------------------------------
  -- Teleport
  ---------------------------------------------------------------------------

  local GEN2_TELEPORT_SPAWNS = {
    "SPAWN_NEW_BARK","SPAWN_CHERRYGROVE","SPAWN_VIOLET","SPAWN_AZALEA",
    "SPAWN_GOLDENROD","SPAWN_ECRUTEAK","SPAWN_OLIVINE","SPAWN_CIANWOOD",
    "SPAWN_MAHOGANY","SPAWN_LAKE_OF_RAGE","SPAWN_BLACKTHORN","SPAWN_MT_SILVER",
    "SPAWN_PALLET","SPAWN_VIRIDIAN","SPAWN_PEWTER","SPAWN_CERULEAN",
    "SPAWN_ROCK_TUNNEL","SPAWN_VERMILION","SPAWN_LAVENDER","SPAWN_CELADON",
    "SPAWN_SAFFRON","SPAWN_FUCHSIA","SPAWN_CINNABAR","SPAWN_INDIGO",
  }

  local function prettyId(id, prefix)
    local s=tostring(id or "")
    if prefix and s:sub(1,#prefix)==prefix then s=s:sub(#prefix+1) end
    return s:gsub("_"," ")
  end

  local function teleportRows(game)
    local rows={}
    if isGen2(game) then
      local landmarks=game and game.data and game.data.gen2Landmarks
      local spawns=landmarks and landmarks.spawns or {}
      for _,spawnId in ipairs(GEN2_TELEPORT_SPAWNS) do
        local sp=spawns[spawnId]
        if sp and sp.map and sp.x~=nil and sp.y~=nil then
          rows[#rows+1]={
            label=prettyId(spawnId,"SPAWN_"),
            mapId=sp.map, x=sp.x, y=sp.y, facing="down"
          }
        end
      end
    else
      local field=game and game.data and game.data.field or {}
      local warps=field.flyWarps or {}
      local seen={}
      for _,mapId in ipairs(field.flyOrder or {}) do
        local spot=warps[mapId]
        local standard = mapId=="PALLET_TOWN"
          or mapId=="CINNABAR_ISLAND"
          or mapId=="INDIGO_PLATEAU"
          or mapId:find("_CITY",1,true)
          or mapId:find("_TOWN",1,true)
        if standard and not seen[mapId] and spot
           and spot.x~=nil and spot.y~=nil then
          seen[mapId]=true
          rows[#rows+1]={
            label=prettyId(mapId), mapId=mapId,
            x=spot.x, y=spot.y, facing="down"
          }
        end
      end
    end
    return rows
  end

  local function teleportTo(game,row)
    if not (row and mod.world and type(mod.world.warpTo)=="function") then
      return false,"warp API unavailable"
    end
    return mod.world:warpTo(row.mapId,row.x,row.y,row.facing or "down",
      { arrive="teleport" })
  end

  ---------------------------------------------------------------------------
  -- DV / EV (Stat EXP) editor
  --
  -- Gen 1 and Gen 2 both store four independent 0..15 DVs. HP DV is derived
  -- from their low bits. They also both store five 16-bit Stat EXP words.
  -- Gen 2's single Special DV / Stat EXP word feeds both SpA and SpD.
  ---------------------------------------------------------------------------

  local DV_KEYS = {
    {key="attack", label="ATK DV"},
    {key="defense",label="DEF DV"},
    {key="speed",  label="SPD DV"},
    {key="special",label="SPC DV"},
  }
  local EV_KEYS = {
    {key="hp",     label="HP EV"},
    {key="attack", label="ATK EV"},
    {key="defense",label="DEF EV"},
    {key="speed",  label="SPD EV"},
    {key="special",label="SPC EV"},
  }

  local function hpDv(dvs)
    local function bit(v) return (v or 0)%2 end
    return bit(dvs.attack)*8+bit(dvs.defense)*4+bit(dvs.speed)*2+bit(dvs.special)
  end

  local function getPartyMon(game)
    local party=game and game.save and game.save.party
    return party and party[editor.partySlot] or nil
  end

  local function editorSpeciesDef(mon,game)
    if not mon then return nil end
    local data=game and game.data
    local native=data and data.pokemon and data.pokemon[mon.species]
    if native then return native end
    return mod.content.pokemon:get(mon.species)
  end

  local function calcGen1One(base,dv,statExp,level,isHp)
    local root=math.min(255,math.ceil(math.sqrt(statExp or 0)))
    local ev=math.floor(root/4)
    local v=math.floor((((base or 1)+(dv or 0))*2+ev)*(level or 1)/100)
    return v+(isHp and ((level or 1)+10) or 5)
  end

  local function calcGen2One(base,dv,statExp,level,isHp)
    local ev=math.floor(math.sqrt(statExp or 0)/4)
    local v=math.floor((((base or 1)*2+(dv or 0)*2+ev)*(level or 1))/100)
    return v+(isHp and ((level or 1)+10) or 5)
  end

  local SHINY_ATK_DV = {
    [2]=true,[3]=true,[6]=true,[7]=true,
    [10]=true,[11]=true,[14]=true,[15]=true,
  }

  local function refreshEditedMon(game,mon)
    if not (game and mon) then return false end
    local def=editorSpeciesDef(mon,game)
    if not (def and def.baseStats) then return false end

    mon.dvs=mon.dvs or {}
    mon.statExp=mon.statExp or {}
    mon.dvs.hp=hpDv(mon.dvs)

    local oldMax=mon.maxHp or (mon.stats and mon.stats.hp) or mon.hp or 1
    local oldHp=mon.hp or oldMax
    local wasFull=oldHp>=oldMax

    if isGen2(game) then
      -- Use the exact same Gen-2 routine Gold's Summary screen uses.
      local ok,Mon=pcall(require,"src.battle.gen2.Mon")
      if ok and Mon and type(Mon.refreshStats)=="function" then
        Mon.refreshStats(mon,game.data)
        if wasFull then mon.hp=mon.maxHp or (mon.stats and mon.stats.hp) or mon.hp end
        return true
      end

      -- Fallback for a restricted engine build.
      local level=mon.level or 1
      local b,se,d=def.baseStats,mon.statExp,mon.dvs
      local stats={
        hp=calcGen2One(b.hp,d.hp,se.hp,level,true),
        attack=calcGen2One(b.attack,d.attack,se.attack,level,false),
        defense=calcGen2One(b.defense,d.defense,se.defense,level,false),
        speed=calcGen2One(b.speed,d.speed,se.speed,level,false),
        specialAttack=calcGen2One(b.specialAttack,d.special,se.special,level,false),
        specialDefense=calcGen2One(b.specialDefense,d.special,se.special,level,false),
      }
      mon.stats=stats
      mon.maxHp=stats.hp
      mon.hp=wasFull and stats.hp or math.max(0,math.min(oldHp,stats.hp))
      mon.shiny=(d.defense==10 and d.speed==10 and d.special==10
        and SHINY_ATK_DV[d.attack]==true)
      local ratio=def.genderRatio
      if ratio==nil or ratio==0xff then
        mon.gender="unknown"
      else
        mon.gender=((d.attack or 0)<math.floor(ratio/16)) and "female" or "male"
      end
      return true
    end

    -- Gen 1's party Summary does not recalc an existing party stat block on
    -- every open, so explicitly use the engine's canonical Stats.calc here.
    local ok,Stats=pcall(require,"src.pokemon.Stats")
    if ok and Stats and type(Stats.calc)=="function" then
      mon.stats=Stats.calc(def,mon.level or 1,mon.dvs,mon.statExp)
      if wasFull then
        mon.hp=mon.stats.hp
      else
        mon.hp=math.max(0,math.min(oldHp,mon.stats.hp))
      end
      return true
    end

    -- Fallback mirrors src/pokemon/Stats.lua.
    local level=mon.level or 1
    local b,se,d=def.baseStats,mon.statExp,mon.dvs
    local stats={
      hp=calcGen1One(b.hp,d.hp,se.hp,level,true),
      attack=calcGen1One(b.attack,d.attack,se.attack,level,false),
      defense=calcGen1One(b.defense,d.defense,se.defense,level,false),
      speed=calcGen1One(b.speed,d.speed,se.speed,level,false),
      special=calcGen1One(b.special,d.special,se.special,level,false),
    }
    mon.stats=stats
    mon.hp=wasFull and stats.hp or math.max(0,math.min(oldHp,stats.hp))
    return true
  end

  local function hexFromValue(value)
    value=math.max(0,math.min(65535,math.floor(tonumber(value) or 0)))
    return {
      math.floor(value/4096)%16,
      math.floor(value/256)%16,
      math.floor(value/16)%16,
      value%16,
    }
  end

  local function valueFromHex(d)
    return (d[1] or 0)*4096+(d[2] or 0)*256+(d[3] or 0)*16+(d[4] or 0)
  end

  local HEX="0123456789ABCDEF"
  local function hexDigit(v) return HEX:sub((v or 0)+1,(v or 0)+1) end

  local function openEvEditor(game,key)
    local mon=getPartyMon(game)
    if not mon then return false end
    mon.statExp=mon.statExp or {}
    editor.evKey=key
    editor.hexDigits=hexFromValue(mon.statExp[key] or 0)
    mod.ui.push(game,EV_HEX_SCREEN)
    return true
  end

  local function speciesRows()
    local rows={}
    for id,mon in mod.content.pokemon:each() do
      if id~="growthRates" and id~="tmhmMoves" then
        rows[#rows+1]={id=id,name=mon.name or id,dex=mon.dex or 9999}
      end
    end
    table.sort(rows,function(a,b)
      if a.dex~=b.dex then return a.dex<b.dex end
      return a.id<b.id
    end)
    return rows
  end

  mod.hooks:wrap("input.step", function(next,game,dt)
    installBattleArtCompat()
    local save=game and game.save
    if save then
      if enabled("cash") then
        if isGen2(game) then
          save.player=save.player or {}
          save.player.money=999999
        else
          save.money=999999
        end
      end
      if enabled("coins") then
        -- Both generations use a 4-digit Coin Case capped at 9,999.
        -- Keep it full every input step, making Game Corner spending infinite.
        if isGen2(game) then
          save.player=save.player or {}
          save.player.coins=9999
        else
          save.coins=9999
        end
      end
      if enabled("master_ball") then ensureItem(save,"MASTER_BALL",99) end
      if enabled("rare_candy") then ensureItem(save,"RARE_CANDY",99) end
      if enabled("pp_up") then ensureItem(save,"PP_UP",99) end
      if enabled("infinite_pp") then refillPlayerPP(game) end
      if enabled("badges") then grantBadges(save) end
      if enabled("party_hp") then
        -- Keep slot 1 full outside battle for compatibility with the original
        -- GameShark-style cheat, then also heal the live active battler below.
        local mon=save.party and save.party[1]
        if mon then
          mon.hp=mon.maxHp or (mon.stats and mon.stats.hp) or mon.hp
        end

        if isGen2(game) then
          for _,screen in ipairs(goldBattleScreens(game)) do
            local active=screen.battle and screen.battle.player
            if active then
              active.hp=active.maxHp or (active.stats and active.stats.hp) or active.hp
            end
          end
        else
          for _,battle in ipairs(gen1BattleStates(game)) do
            local active=battle.player and battle.player.mon
            if active then
              active.hp=active.maxHp or (active.stats and active.stats.hp) or active.hp
            end
          end
        end
      end
      if not isGen2(game) and save.safari then
        if enabled("safari_balls") then save.safari.balls=99 end
        if enabled("safari_time") then save.safari.steps=240 end
      end
    end
    if isGen2(game) then
      for _,s in ipairs(goldBattleScreens(game)) do if enabled("steal_trainer") and not s.battle.wild then patchGoldTrainer(s) else unpatchGoldTrainer(s) end end
    else
      for _,b in ipairs(gen1BattleStates(game)) do
        if enabled("steal_trainer") then patchGen1Trainer(b) else unpatchGen1Trainer(b) end
      end
    end
    if enabled("enemy_burn") then burnEnemy(game) end

    local result=next(game,dt)

    if pendingTeleport then
      if pendingTeleportFrames>0 then
        pendingTeleportFrames=pendingTeleportFrames-1
      else
        local row=pendingTeleport
        pendingTeleport=nil

        -- Gen 2 keeps START / MODS / GameShark as nested opaque screens, so
        -- Gold/Silver need the whole overlay stack removed before a warp.
        -- Gen 1's stack also owns the live overworld state; clearing it there
        -- destroys the scene and produces a blank screen.  Red/Blue/Yellow
        -- therefore keep the older working behavior: only Teleport itself was
        -- closed when the destination was chosen.
        if isGen2(game) and game and game.stack
           and type(game.stack.clear)=="function" then
          game.stack:clear()
        end

        local ok=teleportTo(game,row)
        if not ok then
          mod.ui.push(game,MAIN_SCREEN)
        end
      end
    end

    -- Some residual/status effects write HP directly rather than passing
    -- through battle.damage. Refill once more after the engine step.
    if enabled("party_hp") then
      local save=game and game.save
      if save and save.party then
        local mon=save.party[1]
        if mon then mon.hp=mon.maxHp or (mon.stats and mon.stats.hp) or mon.hp end
      end
      if isGen2(game) then
        for _,screen in ipairs(goldBattleScreens(game)) do
          local active=screen.battle and screen.battle.player
          if active then active.hp=active.maxHp or (active.stats and active.stats.hp) or active.hp end
        end
      else
        for _,battle in ipairs(gen1BattleStates(game)) do
          local active=battle.player and battle.player.mon
          if active then active.hp=active.maxHp or (active.stats and active.stats.hp) or active.hp end
        end
      end
    end

    return result
  end)

  mod.hooks:wrap("movement.collision", function(next,allowed,ctx)
    local result=next(allowed,ctx)
    if enabled("walk") and ctx and ctx.reason~="bounds" then ctx.reason="gameshark"; return true end
    return result
  end)
  mod.hooks:wrap("encounter.roll", function(next,def,ctx)
    if enabled("no_encounters") then return nil end
    local r=next(def,ctx)
    if r and enabled("wild_pick") and state.selectedSpecies then
      r.species=state.selectedSpecies

      -- AUTO leaves the encounter's native level alone. A selected level
      -- overrides only the level after the normal encounter slot has rolled.
      if state.wildLevel then
        r.level=state.wildLevel
      end

      -- Gold constructs the actual Mon after the encounter roll. Carry these
      -- choices into that next matching build for gender/shiny finalization.
      local game=mod.game
      if isGen2(game) and (state.wildGender~="random" or state.wildShiny~="random") then
        state.pendingWild={ species=state.selectedSpecies, level=r.level }
      end
    end
    return r
  end)

  mod.hooks:wrap("shiny.roll", function(next,ctx)
    local p=state.pendingWild
    if not (p and ctx and ctx.species==p.species
       and (p.level==nil or ctx.level==nil or ctx.level==p.level)) then
      return next(ctx)
    end

    if state.wildShiny=="yes" then
      -- 0.1.93 and later increasingly treat the DVs as authoritative. Write
      -- the authentic Gen-2 shiny DV pattern instead of only changing the
      -- temporary boolean returned by shiny.roll.
      if ctx.dvs then
        ctx.dvs.defense=10
        ctx.dvs.speed=10
        ctx.dvs.special=10
        local chosen=chooseAttackDV(ctx.def,ctx.dvs.attack,state.wildGender,true)
        ctx.dvs.attack=chosen or chooseAttackDV(ctx.def,ctx.dvs.attack,"random",true) or 10
        ctx.dvs.hp=hpDV(ctx.dvs)
      end
      return true
    end

    if state.wildShiny=="no" then
      if ctx.dvs and isShinyDVs(ctx.dvs) then
        ctx.dvs.speed=9
        ctx.dvs.hp=hpDV(ctx.dvs)
      end
      return false
    end
    return next(ctx)
  end)

  mod.hooks:wrap("gender.roll", function(next,ctx)
    local p=state.pendingWild
    if not (p and ctx and ctx.species==p.species
       and (p.level==nil or ctx.level==nil or ctx.level==p.level)) then
      return next(ctx)
    end
    local result
    -- 0xff is Gen 2's genderless ratio. Never force male/female onto one.
    if ctx.ratio==nil or ctx.ratio==0xff then
      result="unknown"
    elseif state.wildGender=="male" or state.wildGender=="female" then
      result=state.wildGender
    else
      result=next(ctx)
    end
    return result
  end)

  -- Both Gen 1 and Gen 2 emit battle.move_used after normal PP consumption.
  -- Refill the player's active move immediately, before the move effect
  -- resolves. Called/continuation moves do not need special handling because
  -- the full active move set is restored here.
  mod.events:on("battle.move_used", function(ev)
    if not enabled("infinite_pp") or type(ev)~="table" then return end
    local game=mod.game
    local battle=ev.battle
    local user=ev.user
    local playerSide=(ev.side=="player") or (type(user)=="table" and user.isPlayer==true)
    if not playerSide then return end

    if isGen2(game) then
      refillMonPP(game,user,true)
      if battle then refillMonPP(game,battle.player,true) end
    else
      if type(user)=="table" and type(user.curMoves)=="table" then
        for _,mv in ipairs(user.curMoves) do refillMovePP(game,mv,false) end
      end
      if type(user)=="table" then refillMonPP(game,user.mon,false) end
    end
  end)

  -- Finalize the actual constructed Gold wild Pokemon after Mon.new has
  -- finished. This keeps its stored shiny/gender and DVs in agreement.
  mod.events:on("battle.started", function(ev)
    if not ev or ev.kind~="wild" then return end
    local battle=ev.battle
    local mon=battle and battle.enemy
    if mon then applyPendingWildIdentity(mon) end
  end)

  -- Gen2 Pay Day compatibility for Gen1Recomp builds where EFFECT_PAY_DAY is
  -- not yet implemented in the Gold battle engine. A landed player Pay Day
  -- contributes 2 x the user's level, matching the Gen-2 mechanic.
  mod.events:on("battle.damage_dealt", function(ev)
    if not enabled("payday_fix") then return end
    local game=mod.game
    if not isGen2(game) then return end
    if not ev or ev.moveId~="PAY_DAY" or not ev.battle then return end
    if ev.user~=ev.battle.player then return end
    if (ev.damage or 0)<=0 then return end
    ev.battle._gamesharkPayDay=(ev.battle._gamesharkPayDay or 0)
      + 2*(ev.user.level or 1)
    if type(ev.battle.emit)=="function" then
      ev.battle:emit({kind="message",text="Coins scattered everywhere!"})
    end
  end)

  mod.events:on("battle.ended", function(ev)
    if not enabled("payday_fix") then return end
    local game=mod.game
    if not isGen2(game) then return end
    local battle=ev and ev.battle
    local amount=battle and battle._gamesharkPayDay or 0
    if amount<=0 then return end
    battle._gamesharkPayDay=nil
    if ev.result~="win" then return end
    local save=game and game.save
    if not (save and save.player) then return end
    save.player.money=math.min(999999,(save.player.money or 0)+amount)
  end)

  mod.hooks:wrap("catch.rate", function(next,ball,mon,def,opts)
    -- Gold keeps its working compatibility path here.  Gen 1 trainer
    -- stealing is handled directly by the live battle's catchAttempt wrapper.
    if trainerCatchInProgress then return true,255 end
    return next(ball,mon,def,opts)
  end)
  local function damageTargetsPlayer(ctx)
    if not (ctx and ctx.target) then return false end

    -- Gen 2 uses the active Mon objects directly; Gen 1 uses battler wrappers.
    if ctx.battle and ctx.battle.player then
      if ctx.target == ctx.battle.player then return true end
      if ctx.battle.player.mon and ctx.target == ctx.battle.player.mon then return true end
    end

    return ctx.target.isPlayer == true
      or ctx.target.side == "player"
      or (ctx.target.mon and ctx.target.mon.isPlayer == true)
  end

  mod.hooks:wrap("battle.damage", function(next,ctx)
    local damage,info=next(ctx)

    -- True Infinite HP: stop incoming move damage before the battle engine
    -- subtracts it or queues a faint.  This is more reliable than merely
    -- refilling save.party[1] on a later frame.
    if enabled("party_hp") and damageTargetsPlayer(ctx) then
      damage=0
      return damage,info
    end

    if enabled("enemy_hp") and ctx and ctx.user and ctx.target then
      local userPlayer, targetEnemy = false, false

      -- Gen 2 hands the raw active Mon tables to battle.damage.
      -- Gen 1 hands battler wrappers with isPlayer/mon.
      if ctx.battle and ctx.battle.player and ctx.battle.enemy then
        userPlayer = (ctx.user == ctx.battle.player)
        targetEnemy = (ctx.target == ctx.battle.enemy)
      else
        userPlayer = ctx.user.isPlayer == true or ctx.user.side == "player"
        targetEnemy = ctx.target.isPlayer == false or ctx.target.side == "enemy"
      end

      if userPlayer and targetEnemy then
        local remaining = ctx.target.hp
          or (ctx.target.mon and ctx.target.mon.hp)
          or damage
          or 1
        damage = math.max(1, remaining)
      end
    end
    return damage,info
  end)

  mod.exports.parse=parseCode
  mod.exports.game=function(game)
    local save=game and game.save
    return (save and save.version) or (save and save.generation==2 and "gen2") or "gen1"
  end
  mod.exports.list=function(game)
    local gold=isGen2(game); local out={}
    for _,c in ipairs(CHEATS) do
      local supported=not ((gold and c.gen2==false)
        or ((not gold) and c.gen2only==true))
      out[#out+1]={name=c.name,effect=c.effect,code=gold and c.gold or c.gen1,enabled=enabled(c.effect),supported=supported}
    end
    return out
  end
  mod.exports.setEnabled=function(effectOrCode,value)
    for _,c in ipairs(CHEATS) do
      if c.effect==effectOrCode or cleanCode(c.gen1)==cleanCode(effectOrCode) or (c.gold and cleanCode(c.gold)==cleanCode(effectOrCode)) then setEnabled(c.effect,value); return true end
    end
    return false,"unknown cheat"
  end
  mod.exports.getSelectedSpecies=function() return state.selectedSpecies end
  mod.exports.setSelectedSpecies=function(id)
    if not mod.content.pokemon:get(id) then return false,"unknown Pokemon" end
    state.selectedSpecies=id
    if selectedGenderless() then state.wildGender="random" end
    persist(); return true
  end
  mod.exports.getWildGender=function() return state.wildGender end
  mod.exports.setWildGender=function(value)
    if value~="random" and value~="male" and value~="female" then return false,"invalid gender choice" end
    if selectedGenderless() and value~="random" then return false,"selected Pokemon is genderless" end
    state.wildGender=value; persist(); return true
  end
  mod.exports.getWildShiny=function() return state.wildShiny end
  mod.exports.setWildShiny=function(value)
    if value~="random" and value~="yes" and value~="no" then return false,"invalid shiny choice" end
    state.wildShiny=value; persist(); return true
  end
  mod.exports.getWildLevel=function() return state.wildLevel end
  mod.exports.setWildLevel=function(value)
    if value==nil or value=="auto" then
      state.wildLevel=nil
      persist()
      return true
    end
    local n=tonumber(value)
    if not n or n<1 or n>100 then return false,"level must be AUTO or 1-100" end
    state.wildLevel=math.floor(n)
    persist()
    return true
  end
  mod.exports.startInstantBattle=function(game)
    return startInstantBattle(game or mod.game)
  end

  mod.content.screens:register(PICK_SCREEN,{new=function(game)
    local items={}
    for _,r in ipairs(speciesRows()) do
      items[#items+1]={
        label=r.name,
        right=r.id==state.selectedSpecies and "*" or "",
        value=r.id
      }
    end

    local menu
    menu=mod.ui.ListMenu.new(game,"CHOOSE POKEMON",items,{
      pageJump=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.pickIndex=current.index or uiPos.pickIndex
        uiPos.pickScroll=current.scroll or uiPos.pickScroll
        state.selectedSpecies=item.value
        if selectedGenderless() then state.wildGender="random" end
        persist()
        current:close()
        mod.ui.push(game,WILD_SCREEN)
      end
    })

    menu.index=math.max(1,math.min(uiPos.pickIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.pickScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(LEVEL_SCREEN,{new=function(game)
    local items={{label="AUTO",right=state.wildLevel==nil and "*" or "",value=nil}}
    for level=1,100 do
      items[#items+1]={
        label="LEVEL "..tostring(level),
        right=state.wildLevel==level and "*" or "",
        value=level
      }
    end

    local menu
    menu=mod.ui.ListMenu.new(game,"WILD LEVEL",items,{
      pageJump=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.levelIndex=current.index or uiPos.levelIndex
        uiPos.levelScroll=current.scroll or uiPos.levelScroll
        state.wildLevel=item.value
        persist()
        current:close()
        mod.ui.push(game,WILD_SCREEN)
      end
    })
    menu.index=math.max(1,math.min(uiPos.levelIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.levelScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(WILD_SCREEN,{new=function(game)
    local gold=isGen2(game)
    local def=selectedDef()
    local speciesName=(def and def.name) or state.selectedSpecies

    -- Keep labels deliberately compact. ListMenu right-aligns the value, so
    -- long left labels can collide with the right column on a 160px GB menu.
    local items={
      {
        label="WILD PICK",
        right=enabled("wild_pick") and "ON" or "OFF",
        kind="wild_toggle"
      },
      {
        label="POKEMON",
        right=speciesName,
        kind="picker"
      },
      {
        label="LEVEL",
        right=state.wildLevel and tostring(state.wildLevel) or "AUTO",
        kind="level"
      },
    }

    if gold then
      items[#items+1]={
        label="GENDER",
        -- N/A is clearer here than printing the long GENDERLESS value into
        -- the narrow right column; the Pokemon definition still remains
        -- natively genderless.
        right=selectedGenderless() and "N/A"
          or (state.wildGender=="random" and "RANDOM" or string.upper(state.wildGender)),
        kind="gender"
      }
      items[#items+1]={
        label="SHINY",
        right=state.wildShiny=="random" and "RANDOM" or string.upper(state.wildShiny),
        kind="shiny"
      }
    end

    items[#items+1]={
      label="BATTLE NOW",
      right=state.wildLevel and ">" or "SET LV",
      kind="instant"
    }
    items[#items+1]={label="BACK",kind="back"}

    local menu
    menu=mod.ui.ListMenu.new(game,"WILD POKEMON",items,{
      pageJump=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.wildIndex=current.index or uiPos.wildIndex
        uiPos.wildScroll=current.scroll or uiPos.wildScroll

        if item.kind=="wild_toggle" then
          setEnabled("wild_pick",not enabled("wild_pick"))
          current:close()
          mod.ui.push(game,WILD_SCREEN)
          return
        end

        if item.kind=="picker" then
          current:close()
          mod.ui.push(game,PICK_SCREEN)
          return
        end

        if item.kind=="level" then
          current:close()
          mod.ui.push(game,LEVEL_SCREEN)
          return
        end

        if item.kind=="gender" then
          if not selectedGenderless() then
            state.wildGender=cycleChoice(state.wildGender,GENDER_CHOICES)
            persist()
          end
          current:close()
          mod.ui.push(game,WILD_SCREEN)
          return
        end

        if item.kind=="shiny" then
          state.wildShiny=cycleChoice(state.wildShiny,SHINY_CHOICES)
          persist()
          current:close()
          mod.ui.push(game,WILD_SCREEN)
          return
        end

        if item.kind=="instant" then
          -- AUTO has a specific meaning for ordinary encounters, so don't
          -- silently invent an instant-battle level. Send the user straight
          -- to the level picker the first time instead.
          if not state.wildLevel then
            current:close()
            mod.ui.push(game,LEVEL_SCREEN)
            return
          end

          current:close()
          local ok=startInstantBattle(game)
          if not ok then
            -- A busy world/no healthy party/older engine simply returns to
            -- the setup screen instead of crashing the game.
            mod.ui.push(game,WILD_SCREEN)
          end
          return
        end

        if item.kind=="back" then
          current:close()
          mod.ui.push(game,MAIN_SCREEN)
          return
        end
      end
    })

    menu.index=math.max(1,math.min(uiPos.wildIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.wildScroll,math.max(0,#items-menu.rows)))
    return menu
  end})


  mod.content.screens:register(MOVE_SLOT_SCREEN,{new=function(game)
    local mon=selectedMoveMon(game)
    local newDef=game and game.data and game.data.moves
      and game.data.moves[moveEditor.moveId]
    local newName=(newDef and newDef.name) or moveEditor.moveName
      or moveEditor.moveId or "MOVE"

    local items={}
    for slot=1,4 do
      local mv=mon and mon.moves and mon.moves[slot]
      local def=mv and game.data and game.data.moves and game.data.moves[mv.id]
      items[#items+1]={
        label="SLOT "..tostring(slot),
        right=(def and def.name) or (mv and mv.id) or "EMPTY",
        slot=slot,
      }
    end
    items[#items+1]={label="CANCEL",kind="cancel"}

    local menu
    menu=mod.ui.ListMenu.new(game,"REPLACE MOVE",items,{
      pageJump=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.moveSlotIndex=current.index or uiPos.moveSlotIndex
        uiPos.moveSlotScroll=current.scroll or uiPos.moveSlotScroll

        if item.kind=="cancel" then
          current:close()
          mod.ui.push(game,MOVE_PICK_SCREEN)
          return
        end

        if mon and moveEditor.moveId then
          setMoveSlot(game,mon,item.slot,moveEditor.moveId)
        end
        current:close()
        mod.ui.push(game,MOVE_PARTY_SCREEN)
      end,
      onCancel=function() mod.ui.push(game,MOVE_PICK_SCREEN) end,
      footer="A:REPLACE B:BACK"
    })
    menu.index=math.max(1,math.min(uiPos.moveSlotIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.moveSlotScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(MOVE_PICK_SCREEN,{new=function(game)
    local mon=selectedMoveMon(game)
    local rows=moveRows(game,mon)
    local items={}

    for _,row in ipairs(rows) do
      items[#items+1]={
        label=row.name,
        right=row.known and "KNOWN" or ("PP"..tostring(row.pp)),
        value=row,
      }
    end

    local menu
    menu=mod.ui.ListMenu.new(game,"CHOOSE MOVE",items,{
      pageJump=true,
      keyRepeat=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.movePickIndex=current.index or uiPos.movePickIndex
        uiPos.movePickScroll=current.scroll or uiPos.movePickScroll

        local row=item.value
        if not (type(row)=="table" and type(row.id)=="string") then return end

        moveEditor.moveId=row.id
        moveEditor.moveName=row.name

        local ok,reason=teachMove(game,mon,row.id)
        current:close()

        if ok then
          -- Added to a free slot, or selected a move already known.
          mod.ui.push(game,MOVE_PARTY_SCREEN)
        elseif reason=="full" then
          mod.ui.push(game,MOVE_SLOT_SCREEN)
        else
          mod.ui.push(game,MOVE_PARTY_SCREEN)
        end
      end,
      onCancel=function() mod.ui.push(game,MOVE_PARTY_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.movePickIndex,math.max(1,#items)))
    menu.scroll=math.max(0,math.min(uiPos.movePickScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(MOVE_PARTY_SCREEN,{new=function(game)
    local party=game and game.save and game.save.party or {}
    local items={}

    for i,mon in ipairs(party) do
      local def=editorSpeciesDef(mon,game)
      local name=(mon.nickname and mon.nickname~="" and mon.nickname)
        or (def and def.name) or mon.name or mon.species or ("SLOT "..i)
      items[#items+1]={
        label=tostring(i)..". "..name,
        right="L"..tostring(mon.level or 1),
        slot=i,
      }
    end
    items[#items+1]={label="BACK",kind="back"}

    local menu
    menu=mod.ui.ListMenu.new(game,"TEACH MOVE",items,{
      pageJump=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.movePartyIndex=current.index or uiPos.movePartyIndex
        uiPos.movePartyScroll=current.scroll or uiPos.movePartyScroll

        if item.kind=="back" then
          current:close()
          mod.ui.push(game,MAIN_SCREEN)
          return
        end

        moveEditor.partySlot=item.slot
        current:close()
        mod.ui.push(game,MOVE_PICK_SCREEN)
      end,
      onCancel=function() mod.ui.push(game,MAIN_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.movePartyIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.movePartyScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(ITEM_QTY_SCREEN,{new=function(game)
    local id=giveItemState.itemId
    local name=giveItemState.itemName or id or "ITEM"
    local pocket=giveItemState.pocket or "ITEM"
    local unique = pocket=="KEY_ITEM"
      or (pocket=="TM_HM" and tostring(id):sub(1,3)=="HM_")

    if unique then
      local items={
        {label="ADD 1",value=1},
        {label="BACK",kind="back"},
      }
      return mod.ui.ListMenu.new(game,name,items,{
        onChoose=function(item,current)
          if not item then return end
          if item.kind=="back" then
            current:close()
            mod.ui.push(game,ITEM_PICK_SCREEN)
            return
          end
          addItemToBag(game,id,1)
          current:close()
          mod.ui.push(game,MAIN_SCREEN)
        end,
        onCancel=function() mod.ui.push(game,ITEM_PICK_SCREEN) end
      })
    end

    local items={}
    for qty=1,99 do
      items[#items+1]={label="ADD "..tostring(qty),value=qty}
    end

    local menu
    menu=mod.ui.ListMenu.new(game,name,items,{
      pageJump=true,
      keyRepeat=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.itemQtyIndex=current.index or uiPos.itemQtyIndex
        uiPos.itemQtyScroll=current.scroll or uiPos.itemQtyScroll
        addItemToBag(game,id,item.value)
        current:close()
        mod.ui.push(game,MAIN_SCREEN)
      end,
      onCancel=function() mod.ui.push(game,ITEM_PICK_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.itemQtyIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.itemQtyScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(ITEM_PICK_SCREEN,{new=function(game)
    local rows=itemRows(game)
    local items={}
    for _,row in ipairs(rows) do
      local right=""
      if isGen2(game) then
        if row.pocket=="BALL" then right="BALL"
        elseif row.pocket=="KEY_ITEM" then right="KEY"
        elseif row.pocket=="TM_HM" then right="TM"
        end
      end
      items[#items+1]={
        label=row.name,
        right=right,
        value=row,
      }
    end

    local menu
    menu=mod.ui.ListMenu.new(game,"GIVE ITEM",items,{
      pageJump=true,
      keyRepeat=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.itemPickIndex=current.index or uiPos.itemPickIndex
        uiPos.itemPickScroll=current.scroll or uiPos.itemPickScroll
          local row=item.value
        if not (type(row)=="table" and type(row.id)=="string") then
          current:close()
          mod.ui.push(game,MAIN_SCREEN)
          return
        end
        giveItemState.itemId=row.id
        giveItemState.itemName=tostring(row.name or row.id)
        giveItemState.pocket=type(row.pocket)=="string" and row.pocket or "ITEM"
        current:close()
        mod.ui.push(game,ITEM_QTY_SCREEN)
      end,
      onCancel=function() mod.ui.push(game,MAIN_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.itemPickIndex,math.max(1,#items)))
    menu.scroll=math.max(0,math.min(uiPos.itemPickScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(TELEPORT_SCREEN,{new=function(game)
    local rows=teleportRows(game)
    local items={}
    for _,row in ipairs(rows) do
      items[#items+1]={label=row.label,value=row}
    end

    local menu
    menu=mod.ui.ListMenu.new(game,"TELEPORT",items,{
      pageJump=true,
      keyRepeat=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.teleportIndex=current.index or uiPos.teleportIndex
        uiPos.teleportScroll=current.scroll or uiPos.teleportScroll
        -- Close the GameShark UI first. The actual warp runs on the next
        -- engine frame so Gold cannot carry this ListMenu through the warp.
        pendingTeleport=item.value
        pendingTeleportFrames=1
        current:close()
      end,
      onCancel=function() mod.ui.push(game,MAIN_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.teleportIndex,math.max(1,#items)))
    menu.scroll=math.max(0,math.min(uiPos.teleportScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(PARTY_EDIT_SCREEN,{new=function(game)
    local party=game and game.save and game.save.party or {}
    local items={}
    for i,mon in ipairs(party) do
      local def=editorSpeciesDef(mon,game)
      local name=(mon.nickname and mon.nickname~="" and mon.nickname)
        or (def and def.name) or mon.species or ("SLOT "..i)
      items[#items+1]={
        label=tostring(i)..". "..name,
        right="L"..tostring(mon.level or 1),
        slot=i,
      }
    end

    local menu
    menu=mod.ui.ListMenu.new(game,"DV / EV EDIT",items,{
      pageJump=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.partyEditIndex=current.index or uiPos.partyEditIndex
        uiPos.partyEditScroll=current.scroll or uiPos.partyEditScroll
        editor.partySlot=item.slot
        current:close()
        mod.ui.push(game,MON_EDIT_SCREEN)
      end,
      onCancel=function() mod.ui.push(game,MAIN_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.partyEditIndex,math.max(1,#items)))
    menu.scroll=math.max(0,math.min(uiPos.partyEditScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(DV_PICK_SCREEN,{new=function(game)
    local mon=getPartyMon(game)
    local key=editor.dvKey
    local cur=mon and mon.dvs and mon.dvs[key] or 0
    local items={}
    for v=0,15 do
      items[#items+1]={
        label="DV "..tostring(v),
        right=(v==cur) and "*" or "",
        value=v,
      }
    end

    local menu
    menu=mod.ui.ListMenu.new(game,string.upper(key or "DV"),items,{
      pageJump=true,
      keyRepeat=true,
      onChoose=function(item,current)
        if not (item and mon and key) then return end
        uiPos.dvPickIndex=current.index or uiPos.dvPickIndex
        uiPos.dvPickScroll=current.scroll or uiPos.dvPickScroll
        mon.dvs=mon.dvs or {}
        mon.dvs[key]=item.value
        mon.dvs.hp=hpDv(mon.dvs)
        refreshEditedMon(game,mon)
        current:close()
        mod.ui.push(game,MON_EDIT_SCREEN)
      end,
      onCancel=function() mod.ui.push(game,MON_EDIT_SCREEN) end
    })
    menu.index=math.max(1,math.min((cur or 0)+1,#items))
    menu.scroll=math.max(0,math.min(menu.index-1,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(EV_HEX_SCREEN,{new=function(game)
    local key=editor.evKey
    local value=valueFromHex(editor.hexDigits)
    local items={}
    for i=1,4 do
      items[#items+1]={
        label="HEX "..tostring(i),
        right=hexDigit(editor.hexDigits[i]),
        kind="digit", digit=i,
      }
    end
    items[#items+1]={label="APPLY",right=tostring(value),kind="apply"}
    items[#items+1]={label="CANCEL",kind="cancel"}

    local function reopen(current)
      uiPos.evHexIndex=current.index or uiPos.evHexIndex
      uiPos.evHexScroll=current.scroll or uiPos.evHexScroll
      current:close()
      mod.ui.push(game,EV_HEX_SCREEN)
    end

    local menu
    menu=mod.ui.ListMenu.new(game,string.upper(key or "EV").." EV",items,{
      onChoose=function(item,current)
        if not item then return end
        if item.kind=="digit" then
          local i=item.digit
          editor.hexDigits[i]=((editor.hexDigits[i] or 0)+1)%16
          reopen(current)
          return
        end
        if item.kind=="apply" then
          local mon=getPartyMon(game)
          if mon and key then
            mon.statExp=mon.statExp or {}
            mon.statExp[key]=valueFromHex(editor.hexDigits)
            refreshEditedMon(game,mon)
          end
          current:close()
          mod.ui.push(game,MON_EDIT_SCREEN)
          return
        end
        current:close()
        mod.ui.push(game,MON_EDIT_SCREEN)
      end,
      onSelectKey=function(item,current)
        if item and item.kind=="digit" then
          local i=item.digit
          editor.hexDigits[i]=((editor.hexDigits[i] or 0)+15)%16
          reopen(current)
        end
      end,
      onCancel=function() mod.ui.push(game,MON_EDIT_SCREEN) end,
      footer="A:+  SELECT:-"
    })
    menu.index=math.max(1,math.min(uiPos.evHexIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.evHexScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(MON_EDIT_SCREEN,{new=function(game)
    local mon=getPartyMon(game)
    if not mon then
      return mod.ui.ListMenu.new(game,"DV / EV EDIT",{},{
        onCancel=function() mod.ui.push(game,PARTY_EDIT_SCREEN) end
      })
    end

    mon.dvs=mon.dvs or {}
    mon.statExp=mon.statExp or {}
    mon.dvs.hp=hpDv(mon.dvs)
    refreshEditedMon(game,mon)

    local def=editorSpeciesDef(mon,game)
    local name=(mon.nickname and mon.nickname~="" and mon.nickname)
      or (def and def.name) or mon.species or "POKEMON"

    local items={}
    for _,row in ipairs(DV_KEYS) do
      items[#items+1]={
        label=row.label,
        right=tostring(mon.dvs[row.key] or 0),
        kind="dv", key=row.key
      }
    end
    items[#items+1]={
      label="HP DV",right=tostring(mon.dvs.hp or 0),kind="readonly"
    }
    for _,row in ipairs(EV_KEYS) do
      items[#items+1]={
        label=row.label,
        right=tostring(mon.statExp[row.key] or 0),
        kind="ev", key=row.key
      }
    end

    -- Show the *effective* stats produced by the current DV/Stat EXP values.
    -- This is especially useful in Gen 1 where 65535 Stat EXP is run through
    -- the original sqrt/4 formula and does not mean +65535 visible stat.
    if mon.stats then
      items[#items+1]={label="-- RESULT STATS --",kind="readonly"}
      items[#items+1]={label="HP",right=tostring(mon.stats.hp or mon.maxHp or mon.hp or 0),kind="readonly"}
      items[#items+1]={label="ATK",right=tostring(mon.stats.attack or 0),kind="readonly"}
      items[#items+1]={label="DEF",right=tostring(mon.stats.defense or 0),kind="readonly"}
      items[#items+1]={label="SPD",right=tostring(mon.stats.speed or 0),kind="readonly"}
      if isGen2(game) then
        items[#items+1]={label="SP ATK",right=tostring(mon.stats.specialAttack or 0),kind="readonly"}
        items[#items+1]={label="SP DEF",right=tostring(mon.stats.specialDefense or 0),kind="readonly"}
      else
        items[#items+1]={label="SPC",right=tostring(mon.stats.special or 0),kind="readonly"}
      end
    end

    items[#items+1]={label="MAX ALL DVS",kind="max_dv"}
    items[#items+1]={label="MAX ALL EVS",kind="max_ev"}
    items[#items+1]={label="ZERO ALL EVS",kind="zero_ev"}
    items[#items+1]={label="RECALC STATS",kind="recalc"}
    items[#items+1]={label="BACK",kind="back"}

    local menu
    menu=mod.ui.ListMenu.new(game,name,items,{
      pageJump=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.monEditIndex=current.index or uiPos.monEditIndex
        uiPos.monEditScroll=current.scroll or uiPos.monEditScroll

        if item.kind=="dv" then
          editor.dvKey=item.key
          current:close()
          mod.ui.push(game,DV_PICK_SCREEN)
          return
        end
        if item.kind=="ev" then
          current:close()
          openEvEditor(game,item.key)
          return
        end
        if item.kind=="max_dv" then
          mon.dvs.attack=15; mon.dvs.defense=15
          mon.dvs.speed=15; mon.dvs.special=15
          mon.dvs.hp=hpDv(mon.dvs)
          refreshEditedMon(game,mon)
          current:close(); mod.ui.push(game,MON_EDIT_SCREEN); return
        end
        if item.kind=="max_ev" then
          for _,r in ipairs(EV_KEYS) do mon.statExp[r.key]=65535 end
          refreshEditedMon(game,mon)
          current:close(); mod.ui.push(game,MON_EDIT_SCREEN); return
        end
        if item.kind=="zero_ev" then
          for _,r in ipairs(EV_KEYS) do mon.statExp[r.key]=0 end
          refreshEditedMon(game,mon)
          current:close(); mod.ui.push(game,MON_EDIT_SCREEN); return
        end
        if item.kind=="recalc" then
          refreshEditedMon(game,mon)
          current:close(); mod.ui.push(game,MON_EDIT_SCREEN); return
        end
        if item.kind=="back" then
          current:close(); mod.ui.push(game,PARTY_EDIT_SCREEN); return
        end
      end,
      onCancel=function() mod.ui.push(game,PARTY_EDIT_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.monEditIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.monEditScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(MAIN_SCREEN,{new=function(game)
    local gold=isGen2(game); local items={}
    for _,c in ipairs(CHEATS) do
      local supported=not ((gold and c.gen2==false)
        or ((not gold) and c.gen2only==true))
      -- Wild Pick now has its own self-contained setup screen.
      if supported and c.effect~="wild_pick" then
        items[#items+1]={
          label=c.name,
          right=enabled(c.effect) and "ON" or "OFF",
          value=c.effect,
          kind="toggle"
        }
      end
    end
    items[#items+1]={
      -- Keep the submenu arrow on the left label so ON/OFF stays in the
      -- exact same right-aligned column as every other toggle row. The full
      -- WILD POKEMON wording remains the submenu title.
      label="WILD PKMN >",
      right=enabled("wild_pick") and "ON" or "OFF",
      kind="wild_menu"
    }
    if hasCrystalGsBallEvent(game) then
      items[#items+1]={
        label="CELEBI EVENT",
        right=celebiEventStatus(game),
        kind="celebi_event"
      }
    end
    items[#items+1]={label="TEACH MOVE",right=">",kind="teach_move"}
    items[#items+1]={label="GIVE ITEM",right=">",kind="give_item"}
    items[#items+1]={label="TELEPORT",right=">",kind="teleport"}
    items[#items+1]={label="DV / EV EDITOR",right=">",kind="party_edit"}
    items[#items+1]={label="USE SURFBOARD",kind="surfboard"}
    local menu
    menu=mod.ui.ListMenu.new(game,gold and "GAMESHARK G2" or "GAMESHARK G1",items,{
      pageJump=true,
      onChoose=function(item,current)
      if not item then return end
      uiPos.mainIndex=current.index or uiPos.mainIndex
      uiPos.mainScroll=current.scroll or uiPos.mainScroll
      if item.kind=="wild_menu" then
        current:close()
        mod.ui.push(game,WILD_SCREEN)
        return
      end
      if item.kind=="celebi_event" then
        enableCelebiEvent(game)
        current:close()
        mod.ui.push(game,MAIN_SCREEN)
        return
      end
      if item.kind=="teach_move" then
        current:close()
        mod.ui.push(game,MOVE_PARTY_SCREEN)
        return
      end
      if item.kind=="give_item" then
        current:close()
        mod.ui.push(game,ITEM_PICK_SCREEN)
        return
      end
      if item.kind=="teleport" then
        current:close()
        mod.ui.push(game,TELEPORT_SCREEN)
        return
      end
      if item.kind=="party_edit" then
        current:close()
        mod.ui.push(game,PARTY_EDIT_SCREEN)
        return
      end
      if item.kind=="surfboard" then
        current:close(); local ok=useSurfboard(game); if not ok then mod.ui.push(game,MAIN_SCREEN) end; return
      end
      setEnabled(item.value,not enabled(item.value))
      current:close()
      mod.ui.push(game,MAIN_SCREEN)
      end
    })
    menu.index=math.max(1,math.min(uiPos.mainIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.mainScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.exports.hasCelebiEvent=function(game) return hasCrystalGsBallEvent(game or mod.game) end
  mod.exports.enableCelebiEvent=function(game) return enableCelebiEvent(game or mod.game) end
  mod.exports.moveRows=function(mon,game) return moveRows(game or mod.game,mon) end
  mod.exports.teachMove=function(mon,moveId,game)
    return teachMove(game or mod.game,mon,moveId)
  end
  mod.exports.setMoveSlot=function(mon,slot,moveId,game)
    return setMoveSlot(game or mod.game,mon,slot,moveId)
  end
  mod.exports.itemRows=function(game) return itemRows(game or mod.game) end
  mod.exports.giveItem=function(id,qty,game) return addItemToBag(game or mod.game,id,qty) end
  mod.exports.teleportRows=function(game) return teleportRows(game or mod.game) end
  mod.exports.teleportTo=function(row,game) return teleportTo(game or mod.game,row) end
  mod.exports.refreshEditedMon=function(mon,game) return refreshEditedMon(game or mod.game,mon) end

  mod.hooks:wrap("ui.start_menu.items",function(next,game,items)
    local out=next(game,items); if type(out)~="table" then return out end
    return mod.ui.insertBefore(out,"SAVE",{label="GAMESHARK",onSelect=function() mod.ui.push(game,MAIN_SCREEN) end})
  end)
end
