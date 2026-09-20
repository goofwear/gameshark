-- GameShark Compatibility 0.8.6
-- Universal Gen 1 + Gen 2 + Gen 3 build for Gen1Recomp 0.1.79+.
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
local FRIENDSHIP_SCREEN = "GameSharkFriendship"
local FRIENDSHIP_ACTION_SCREEN = "GameSharkFriendshipAction"
local G3_STAT_SCREEN = "GameSharkGen3StatEdit"
local G3_VALUE_SCREEN = "GameSharkGen3ValuePick"

local GENDER_CHOICES = { "random", "male", "female" }
local SHINY_CHOICES = { "random", "yes", "no" }
local NATURE_CHOICES = {
  "random","hardy","lonely","brave","adamant","naughty",
  "bold","docile","relaxed","impish","lax",
  "timid","hasty","serious","jolly","naive",
  "modest","mild","quiet","bashful","rash",
  "calm","gentle","sassy","careful","quirky",
}

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
  { name="SAFARI BALL", effect="safari_balls", gen1="016447DA", gen2=false, gen3=false },
  { name="SAFARI TIME", effect="safari_time", gen1="01F00ED7", gen2=false, gen3=false },
  { name="STEAL TRAINER", effect="steal_trainer", gen1="010157D0", gold="010116D1", gen3=false },
  { name="WILD PICK", effect="wild_pick", gen1="01FF00D0", gold="01??EDD0" },
  { name="PAY DAY FIX", effect="payday_fix", gen1=false, gold=nil, gen2only=true, gen3=false },
  { name="CATCH EASY", effect="catch_easy", gen1=false, gold=false, gen3only=true },
  { name="COMPLETE DEX", effect="complete_dex", gen1=false, gold=false, gen3only=true },
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

local function isGen3(game)
  -- FireRed's native Game3 object is not a Gen 1/2 Game object and does not
  -- reliably expose save.generation.  Detect the active title first, exactly
  -- at the engine-version boundary, then keep the old save-generation fallback
  -- for compatibility with the Gen3 facade used by some mod API paths.
  local ok,Version=pcall(require,"src.core.GameVersion")
  if ok and Version and type(Version.get)=="function" and Version.get()=="firered" then
    return true
  end
  local s=game and game.save
  return s and s.generation==3 or false
end

local function cheatSupported(c,game)
  local g2=isGen2(game)
  local g3=isGen3(game)
  if g3 then return c.gen3~=false and c.gen2only~=true end
  if g2 then return c.gen2~=false and c.gen3only~=true end
  return c.gen2only~=true and c.gen3only~=true and c.gen1~=false
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
    wildGender="random", wildShiny="random", wildNature="random",
    wildMaxIVs=false,
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
    friendshipIndex = 1, friendshipScroll = 0,
    friendshipActionIndex = 1, friendshipActionScroll = 0,
    g3StatIndex = 1, g3StatScroll = 0,
    g3ValueIndex = 1, g3ValueScroll = 0,
  }

  local friendshipEditor = {
    partySlot = nil,
    yellowPikachu = false,
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
    g3Kind = nil,
    g3Key = nil,
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
    if type(mod.save.wildNature)=="string" then state.wildNature=mod.save.wildNature end
    if type(mod.save.wildMaxIVs)=="boolean" then state.wildMaxIVs=mod.save.wildMaxIVs end
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
      mod.save.wildNature=state.wildNature
      mod.save.wildMaxIVs=state.wildMaxIVs
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

  -- Friendship support is capability-based rather than version allow-listed.
  -- Every Gen 2 party mon carries `happiness`; Yellow alone carries the
  -- starter Pikachu byte on save.pikachuHappiness. Red/Blue have neither.
  local function hasFriendshipFeature(game)
    local save=game and game.save
    if not save then return false end
    if save.generation==2 or save.generation==3 then return true end
    return save.pikachuHappiness ~= nil
  end

  local function isYellowFriendship(game)
    local save=game and game.save
    return save and save.generation~=2 and save.pikachuHappiness ~= nil or false
  end

  local function friendshipValue(game,mon)
    local save=game and game.save
    if not save then return nil end
    if isYellowFriendship(game) then
      return math.max(0,math.min(255,math.floor(tonumber(save.pikachuHappiness) or 90)))
    end
    if (save.generation==2 or save.generation==3) and type(mon)=="table" and mon.isEgg~=true then
      return math.max(0,math.min(255,math.floor(tonumber(mon.happiness or mon.friendship) or 70)))
    end
    return nil
  end

  local function setFriendship(game,mon,value)
    local save=game and game.save
    if not save then return false,"save unavailable" end
    value=math.max(0,math.min(255,math.floor(tonumber(value) or 0)))

    if isYellowFriendship(game) then
      -- Yellow stores friendship once for the starter Pikachu, not on each
      -- party mon. Keep mood separate; the original game also treats it as a
      -- different byte and chooses reactions from both values.
      save.pikachuHappiness=value
      return true,value
    end

    if save.generation==2 or save.generation==3 then
      if type(mon)~="table" then return false,"Pokemon unavailable" end
      if mon.isEgg==true then return false,"Eggs do not use friendship" end
      mon.happiness=value
      if save.generation==3 then mon.friendship=value end
      return true,value
    end
    return false,"friendship unsupported"
  end

  local function friendshipTarget(game)
    if isYellowFriendship(game) then return nil end
    local party=game and game.save and game.save.party
    local slot=friendshipEditor.partySlot
    return party and slot and party[slot] or nil
  end

  local function ensureItem(save,id,qty)
    if not (save and save.inventory) then return end
    if (save.inventory[id] or 0)<qty then save.inventory[id]=qty end

    -- FireRed's inventory is a live Bag proxy with its own pocket/order logic.
    if save.generation==3 then return end

    save.bagOrder=save.bagOrder or {}
    local found=false
    for _,v in ipairs(save.bagOrder) do
      if v==id then found=true break end
    end
    if not found then table.insert(save.bagOrder,id) end
  end

  local function addItemToBag(game,id,qty)
    local save=game and game.save
    if not (save and save.inventory and id) then return false,"save unavailable" end
    local def=game and game.data and game.data.items and game.data.items[id]
    local pocket=(def and def.pocket) or "ITEM"
    local add=math.max(1,math.min(99,math.floor(tonumber(qty) or 1)))
    local cur=tonumber(save.inventory[id]) or 0

    if isGen3(game) then
      local unique = pocket=="KEY_ITEMS"
      local target=unique and 1 or math.min(999,cur+add)
      save.inventory[id]=target
      return true,target
    end

    local unique = pocket=="KEY_ITEM" or pocket=="KEY_ITEMS"
      or (pocket=="TM_HM" and tostring(id):sub(1,3)=="HM_")
    local target=unique and 1 or math.min(99,cur+add)
    save.inventory[id]=target
    save.bagOrder=save.bagOrder or {}
    local found=false
    for _,v in ipairs(save.bagOrder) do if v==id then found=true break end end
    if not found then table.insert(save.bagOrder,id) end
    return true,target
  end

  local function itemRows(game)
    local rows={}
    local items=game and game.data and game.data.items or {}

    if isGen3(game) then
      -- Gen3Compat data tables are lookup proxies; pairs() intentionally does
      -- not enumerate them. FireRed item ids are numeric, so scan the legal
      -- range through the public lookup facade.
      for id=1,512 do
        local def=items[id]
        if type(def)=="table" and type(def.name)=="string" and def.name~=""
           and not tostring(def.name):upper():find("ITEM ",1,true) then
          rows[#rows+1]={id=id,name=def.name,index=id,pocket=def.pocket or "ITEMS"}
        end
      end
    else
      for id,def in pairs(items) do
        if type(id)=="string" and type(def)=="table" then
          local name=def.name
          local index=def.index
          local pocket=def.pocket or "ITEM"
          local upper=id:upper()
          local giveable = type(name)=="string" and name~=""
            and upper~="NO_ITEM" and upper~="TERU_SAMA"
            and not upper:find("BADGE",1,true)
          if giveable then rows[#rows+1]={
            id=id,name=name,index=type(index)=="number" and index or 99999,
            pocket=type(pocket)=="string" and pocket or "ITEM"}
          end
        end
      end
    end

    table.sort(rows,function(a,b)
      local ai=tonumber(a.index) or 99999; local bi=tonumber(b.index) or 99999
      if ai~=bi then return ai<bi end
      local an=tostring(a.name or a.id or ""); local bn=tostring(b.name or b.id or "")
      if an~=bn then return an<bn end
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
    if isGen3(game) then
      for _,id in ipairs((mon and mon.moves) or {}) do if type(id)=="number" then known[id]=true end end
      for id=1,512 do
        local def=moves[id]
        if type(def)=="table" and type(def.name)=="string" and def.name~="" then
          rows[#rows+1]={id=id,name=def.name,index=id,pp=tonumber(def.pp) or 0,known=known[id]==true}
        end
      end
    else
      for _,mv in ipairs((mon and mon.moves) or {}) do
        if type(mv)=="table" and type(mv.id)=="string" then known[mv.id]=true end
      end
      for id,def in pairs(moves) do
        if type(id)=="string" and type(def)=="table" and type(def.name)=="string" and def.name~="" then
          local upper=id:upper()
          if upper~="NO_MOVE" and upper~="NONE" and not upper:find("UNUSED",1,true) then
            rows[#rows+1]={id=id,name=def.name,index=type(def.index)=="number" and def.index or 99999,
              pp=tonumber(def.pp) or 0,known=known[id]==true}
          end
        end
      end
    end
    table.sort(rows,function(a,b)
      local ai=tonumber(a.index) or 99999; local bi=tonumber(b.index) or 99999
      if ai~=bi then return ai<bi end
      return tostring(a.name or a.id)<tostring(b.name or b.id)
    end)
    return rows
  end

  local function selectedMoveMon(game)
    local party=game and game.save and game.save.party
    return party and party[moveEditor.partySlot] or nil
  end

  local function setMoveSlot(game,mon,slot,moveId)
    if not (game and mon and type(slot)=="number" and slot>=1 and slot<=4) then return false,"invalid slot" end
    local def=game.data and game.data.moves and game.data.moves[moveId]
    if type(def)~="table" then return false,"unknown move" end
    local base=math.max(0,math.floor(tonumber(def.pp) or 0))

    if isGen3(game) then
      mon.moves=mon.moves or {}; mon.pp=mon.pp or {}; mon.maxPp=mon.maxPp or {}
      mon.moves[slot]=tonumber(moveId) or moveId
      mon.pp[slot]=base; mon.maxPp[slot]=base
      return true
    end

    mon.moves=mon.moves or {}
    local entry={id=moveId,pp=base}
    if isGen2(game) then entry.maxPp=base end
    mon.moves[slot]=entry
    local compact={}
    for i=1,4 do local mv=mon.moves[i]; if type(mv)=="table" and mv.id then compact[#compact+1]=mv end end
    mon.moves=compact
    return true
  end

  local function teachMove(game,mon,moveId)
    if not (game and mon and moveId) then return false,"missing target" end
    mon.moves=mon.moves or {}
    if isGen3(game) then
      local id=tonumber(moveId)
      for i,mv in ipairs(mon.moves) do
        if tonumber(mv)==id then
          local def=game.data.moves[id]; local base=def and tonumber(def.pp) or 0
          mon.pp=mon.pp or {}; mon.maxPp=mon.maxPp or {}; mon.pp[i]=base; mon.maxPp[i]=base
          return true,"known"
        end
      end
      if #mon.moves<4 then return setMoveSlot(game,mon,#mon.moves+1,id) end
      return false,"full"
    end

    for _,mv in ipairs(mon.moves) do
      if mv.id==moveId then
        local def=game.data and game.data.moves and game.data.moves[moveId]
        local base=def and tonumber(def.pp) or 0
        local bonus=math.floor((base or 0)/5)*(mv.ppUps or 0)
        local max=math.max(0,(base or 0)+bonus); mv.pp=max
        if isGen2(game) then mv.maxPp=max end
        return true,"known"
      end
    end
    if #mon.moves<4 then return setMoveSlot(game,mon,#mon.moves+1,moveId) end
    return false,"full"
  end

  local function refillMovePP(game,mv,gold)
    if type(mv)~="table" or not mv.id then return end
    local maxPP
    if gold then
      maxPP=mv.maxPp
      if not maxPP then
        local def=game and game.data and game.data.moves and game.data.moves[mv.id]
        if def and def.pp then local bonus=math.min(math.floor(def.pp/5),7); maxPP=def.pp+(mv.ppUps or 0)*bonus; mv.maxPp=maxPP end
      end
    else
      local def=game and game.data and game.data.moves and game.data.moves[mv.id]
      if def and def.pp then maxPP=def.pp+(mv.ppUps or 0)*math.floor(def.pp/5) end
    end
    if maxPP and maxPP>0 then mv.pp=maxPP end
  end

  local function refillMonPP(game,mon,gold)
    if type(mon)~="table" or type(mon.moves)~="table" then return end
    if isGen3(game) then
      mon.pp=mon.pp or {}; mon.maxPp=mon.maxPp or {}
      for i,id in ipairs(mon.moves) do
        local def=game.data and game.data.moves and game.data.moves[id]
        local max=tonumber(mon.maxPp[i]) or (def and tonumber(def.pp)) or 0
        if max>0 then mon.maxPp[i]=max; mon.pp[i]=max end
      end
      return
    end
    for _,mv in ipairs(mon.moves) do refillMovePP(game,mv,gold) end
  end

  local activeGen3Battle=nil

  local function refillPlayerPP(game)
    if not game then return end
    local gold=isGen2(game)
    local save=game.save
    if save and type(save.party)=="table" then
      for _,mon in ipairs(save.party) do refillMonPP(game,mon,gold) end
    end

    if isGen3(game) then
      local active=activeGen3Battle and activeGen3Battle.player and activeGen3Battle.player.mon
      if active then refillMonPP(game,active,false) end
    elseif gold then
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
    if save.generation==3 then
      local flags=save.flags
      if flags then for i=1,8 do flags[string.format("FLAG_BADGE%02d_GET",i)]=true end end
    elseif save.generation==2 then
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
        self.afterQueue="finish"
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
    if isGen3(game) then
      local b=activeGen3Battle and activeGen3Battle.enemy
      if b and not b.status then b.status="BRN" end
      if b and b.mon and not b.mon.status then b.mon.status="BRN" end
    elseif isGen2(game) then
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

    -- Gen 2 finalizes DVs through its constructor; Gen 3 identity options are
    -- finalized against the live enemy mon when battle.started fires.
    -- Gold Mon constructor  runs shiny.roll/gender.roll while the Gen-2
    -- start_battle script verb constructs the enemy. Reuse the same pending
    -- identity marker as normal Wild Pick so Gender/Shiny apply here too.
    if (gold or isGen3(game)) and (state.wildGender~="random" or state.wildShiny~="random"
       or state.wildNature~="random" or state.wildMaxIVs) then
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
    if isGen3(game) then
      local g3={
        {"PALLET TOWN","FR_PLAYERS_HOUSE_1F",8,5},
        {"VIRIDIAN CITY","FR_VIRIDIAN_CITY_POKEMON_CENTER_1F",7,4},
        {"PEWTER CITY","FR_PEWTER_CITY_POKEMON_CENTER_1F",7,4},
        {"CERULEAN CITY","FR_CERULEAN_CITY_POKEMON_CENTER_1F",7,4},
        {"LAVENDER TOWN","FR_LAVENDER_TOWN_POKEMON_CENTER_1F",7,4},
        {"VERMILION CITY","FR_VERMILION_CITY_POKEMON_CENTER_1F",7,4},
        {"CELADON CITY","FR_CELADON_CITY_POKEMON_CENTER_1F",7,4},
        {"FUCHSIA CITY","FR_FUCHSIA_CITY_POKEMON_CENTER_1F",7,4},
        {"CINNABAR ISLAND","FR_CINNABAR_ISLAND_POKEMON_CENTER_1F",7,4},
        {"SAFFRON CITY","FR_SAFFRON_CITY_POKEMON_CENTER_1F",7,4},
        {"INDIGO PLATEAU","FR_INDIGO_PLATEAU_POKEMON_CENTER_1F",13,12},
        {"ONE ISLAND","SEVII_ONE_ISLAND_POKECENTER",5,4},
        {"TWO ISLAND","SEVII_TWO_ISLAND_POKECENTER",7,4},
        {"THREE ISLAND","SEVII_THREE_ISLAND_POKECENTER",7,4},
        {"FOUR ISLAND","SEVII_FOUR_ISLAND_POKECENTER",7,4},
        {"FIVE ISLAND","SEVII_FIVE_ISLAND_POKECENTER",7,4},
        {"SIX ISLAND","SEVII_SIX_ISLAND_POKECENTER",7,4},
        {"SEVEN ISLAND","SEVII_SEVEN_ISLAND_POKECENTER",7,4},
      }
      for _,r in ipairs(g3) do rows[#rows+1]={label=r[1],mapId=r[2],x=r[3],y=r[4],facing="down"} end
    elseif isGen2(game) then
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
    if isGen3(game) then
      local def=editorSpeciesDef(mon,game)
      local b=def and def.baseStats
      if not b then return false end
      mon.ivs=mon.ivs or {}; mon.evs=mon.evs or {}
      local iv,ev=mon.ivs,mon.evs
      local level=math.max(1,tonumber(mon.level) or 1)
      local nature=math.floor(tonumber(mon.personality) or 0)%25
      local natureMods = {
        [0]={}, [1]={attack=1,defense=-1}, [2]={attack=1,speed=-1}, [3]={attack=1,specialAttack=-1}, [4]={attack=1,specialDefense=-1},
        [5]={defense=1,attack=-1}, [6]={}, [7]={defense=1,speed=-1}, [8]={defense=1,specialAttack=-1}, [9]={defense=1,specialDefense=-1},
        [10]={speed=1,attack=-1}, [11]={speed=1,defense=-1}, [12]={}, [13]={speed=1,specialAttack=-1}, [14]={speed=1,specialDefense=-1},
        [15]={specialAttack=1,attack=-1}, [16]={specialAttack=1,defense=-1}, [17]={specialAttack=1,speed=-1}, [18]={}, [19]={specialAttack=1,specialDefense=-1},
        [20]={specialDefense=1,attack=-1}, [21]={specialDefense=1,defense=-1}, [22]={specialDefense=1,speed=-1}, [23]={specialDefense=1,specialAttack=-1}, [24]={},
      }
      local mods=natureMods[nature] or {}
      local function calc(base,ivv,evv,key,hp)
        local core=math.floor(((2*(tonumber(base) or 1)+(tonumber(ivv) or 0)+math.floor((tonumber(evv) or 0)/4))*level)/100)
        if hp then return core+level+10 end
        local v=core+5
        if mods[key]==1 then v=math.floor(v*1.1) elseif mods[key]==-1 then v=math.floor(v*0.9) end
        return v
      end
      local oldMax=tonumber(mon.maxHp) or tonumber(mon.hp) or 1
      local oldHp=tonumber(mon.hp) or oldMax
      local wasFull=oldHp>=oldMax
      local hp=calc(b.hp,iv.hp,ev.hp,"hp",true)
      mon.maxHp=hp; mon.hp=wasFull and hp or math.max(0,math.min(oldHp,hp))
      mon.attack=calc(b.attack,iv.atk,ev.atk,"attack",false); mon.atk=mon.attack
      mon.defense=calc(b.defense,iv.def,ev.def,"defense",false); mon.def=mon.defense
      mon.speed=calc(b.speed,iv.spe,ev.spe,"speed",false); mon.spe=mon.speed
      mon.spAtk=calc(b.specialAttack,iv.spa,ev.spa,"specialAttack",false); mon.spa=mon.spAtk
      mon.spDef=calc(b.specialDefense,iv.spd,ev.spd,"specialDefense",false); mon.spd=mon.spDef
      if mon.happiness~=nil and mon.friendship==nil then mon.friendship=mon.happiness end
      return true
    end
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

  -- FireRed uses a completely separate 240x160 modal UI stack.  The ordinary
  -- mod.ui ListMenu objects are Gen 1/2 screens, so pushing one directly onto
  -- FireRed's stack either fails during screen resolution or leaves a legacy
  -- 160x144 menu that Game3 cannot drive.  For Gen 3 we still let each
  -- registered GameShark screen build its normal ListMenu data, but host that
  -- data inside a small native FireRed menu adapter.
  local gen3MenuSerial=0

  local function pushGen3Screen(game,id,...)
    local factory=mod.content.screens:get(id)
    if type(factory)=="function" then factory={new=factory} end
    if type(factory)~="table" or type(factory.new)~="function" then
      return nil
    end

    -- IMPORTANT: do NOT construct a legacy ListMenu on FireRed.
    --
    -- The registered GameShark screen factories were originally written for
    -- Gen 1/2 and call mod.ui.ListMenu.new().  Calling the real constructor
    -- here is exactly why v0.8.1-v0.8.3 could add a GAMESHARK row but pressing
    -- A appeared to do nothing: FireRed's start menu wraps onSelect in pcall,
    -- the legacy constructor throws on the Game3 object, and StartMenu prints
    -- the error to the log while leaving the menu onscreen.
    --
    -- Build the factory against a tiny capture constructor instead.  It keeps
    -- the existing GameShark screen definitions/handlers, but no legacy UI
    -- object is ever created.  The captured rows are then rendered/controlled
    -- by the native Game3 host below.
    local listApi=mod.ui and mod.ui.ListMenu
    local realNew=listApi and listApi.new
    if type(realNew)~="function" then return nil end

    local function captureNew(_game,title,items,opts)
      opts=opts or {}
      return {
        title=title,
        items=items or {},
        index=1,
        scroll=0,
        rows=8,
        pageJump=opts.pageJump==true,
        footer=opts.footer,
        onChoose=opts.onChoose,
        onCancel=opts.onCancel,
        onSelectKey=opts.onSelectKey,
      }
    end

    listApi.new=captureNew
    local packed={pcall(factory.new,game,...)}
    listApi.new=realNew

    local ok=table.remove(packed,1)
    if not ok then
      if mod.log and mod.log.error then
        mod.log:error("FireRed GameShark screen "..tostring(id)..
          " failed to build: "..tostring(packed[1]))
      end
      return nil
    end

    local inst=packed[1]
    if type(inst)~="table" then return nil end

    -- FireRed does not use Game.stack/StateStack.  Its UI is owned by the
    -- dedicated Game3 modal stack module.  Requiring that module directly is
    -- the native path used by FireRed menus.
    local Stack=require("src.ui.game3.stack")
    if type(Stack)~="table" or type(Stack.push)~="function"
       or type(Stack.pop)~="function" or type(Stack.top)~="function" then
      return nil
    end

    local Window=require("src.ui.game3.window")
    local FrlgFont=require("src.ui.game3.frlg_font")

    gen3MenuSerial=gen3MenuSerial+1
    local layerId="gameshark:"..tostring(id)..":"..tostring(gen3MenuSerial)
    local host={}
    local ROWS=8

    inst.rows=ROWS
    inst.index=math.max(1,math.min(tonumber(inst.index) or 1,
      math.max(1,#(inst.items or {}))))
    inst.scroll=math.max(0,tonumber(inst.scroll) or 0)

    local function syncScroll()
      local n=#(inst.items or {})
      if n<1 then inst.index=1; inst.scroll=0; return end
      inst.index=math.max(1,math.min(inst.index,n))
      if inst.index-inst.scroll>ROWS then
        inst.scroll=inst.index-ROWS
      elseif inst.index-inst.scroll<1 then
        inst.scroll=inst.index-1
      end
      inst.scroll=math.max(0,math.min(inst.scroll,math.max(0,n-ROWS)))
    end

    local function popSelf()
      local top=Stack.top()
      if top and top.id==layerId then
        return Stack.pop(layerId)
      end
      return Stack.pop(layerId)
    end

    -- Every GameShark callback already calls current:close() before opening
    -- its next submenu.  Make that operation remove this native Game3 layer.
    inst.close=function() return popSelf() end

    local function move(delta)
      local n=#(inst.items or {})
      if n<1 then return end
      inst.index=math.max(1,math.min(n,inst.index+delta))
      syncScroll()
    end

    function host.handleInput(input)
      if not input then return true end

      if input:wasPressed("up") then
        move(-1)
      elseif input:wasPressed("down") then
        move(1)
      elseif input:wasPressed("left") and inst.pageJump then
        move(-ROWS)
      elseif input:wasPressed("right") and inst.pageJump then
        move(ROWS)
      elseif input:wasPressed("select") and inst.onSelectKey then
        local item=(inst.items or {})[inst.index]
        inst.onSelectKey(item,inst)
      elseif input:wasPressed("b") then
        popSelf()
        if inst.onCancel then inst.onCancel() end
      elseif input:wasPressed("a") then
        local item=(inst.items or {})[inst.index]
        if item and inst.onChoose then
          inst.onChoose(item,inst)
        end
      end
      return true
    end

    function host.update(_dt)
      -- Input is intentionally handled by handleInput().  Game3's HUD calls
      -- that only for the top modal layer, preventing the START menu underneath
      -- from receiving the same A/B/D-pad edge.
    end

    function host.draw()
      local items=inst.items or {}
      syncScroll()

      local tpl=Window.template(1,1,28,18)
      Window.stdFrame(tpl)

      local title=tostring(inst.title or "GAMESHARK G3")
      Window.printPx(title,16,10,{maxWidth=208})

      local firstY=30
      local rightEdge=222
      for row=1,ROWS do
        local i=inst.scroll+row
        local item=items[i]
        if not item then break end
        local y=firstY+(row-1)*15
        if i==inst.index then Window.cursorPx(14,y) end

        local label=tostring(item.label or "")
        Window.printPx(label,24,y,{maxWidth=150})

        if item.right~=nil then
          local right=tostring(item.right)
          local w=FrlgFont.measure and FrlgFont.measure(right) or (#right*6)
          Window.printPx(right,math.max(174,rightEdge-w),y,{maxWidth=48})
        end
      end

      if inst.scroll>0 then
        Window.printPx("▲",226,28,{maxWidth=10})
      end
      if inst.scroll+ROWS<#items then
        Window.printPx("▼",226,134,{maxWidth=10})
      end

      if inst.footer then
        Window.printPx(tostring(inst.footer),16,145,{maxWidth=208})
      end
    end

    Stack.push(layerId,host,{hideBelow=true})
    return inst
  end

  local function pushScreen(game,id,...)
    if isGen3(game) then
      return pushGen3Screen(game,id,...)
    end
    return mod.ui.push(game,id,...)
  end

  local function openEvEditor(game,key)
    local mon=getPartyMon(game)
    if not mon then return false end
    mon.statExp=mon.statExp or {}
    editor.evKey=key
    editor.hexDigits=hexFromValue(mon.statExp[key] or 0)
    pushScreen(game,EV_HEX_SCREEN)
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

  -- FireRed gameplay lives in Runtime.getSession().  Game3.save is a
  -- persistence snapshot, so continuous cheats must write the live session.
  local function liveGen3Session()
    if not isGen3(mod.game) then return nil end
    local ok,R=pcall(require,"src.core.game3.runtime")
    if not (ok and R and R.getSession) then return nil end
    return R.getSession()
  end

  local function gen3EnsureItem(name,qty)
    local s=liveGen3Session()
    if not (s and s.bag) then return false end
    local Bag=require("src.core.game3.bag")
    local Items=require("src.core.game3.items_data")
    local id=Items.toNumericId and Items.toNumericId(name)
    if not id and Items.BY_HOST and Items.BY_HOST[name] then id=Items.BY_HOST[name].frlg end
    if not id then return false end
    Bag.set(s.bag,id,math.max(Bag.get(s.bag,id) or 0,qty))
    return true
  end

  local function gen3FillPP(mon)
    if type(mon)~="table" then return end
    local P=require("src.core.game3.pokemon")
    mon.moves=mon.moves or {}
    mon.pp=mon.pp or {}
    mon.maxPp=mon.maxPp or {}
    for i=1,4 do
      local move=mon.moves[i]
      if move and move~=0 then
        local max=tonumber(mon.maxPp[i])
        if not max then
          local def=P.battleMove and P.battleMove(move)
          max=tonumber(def and def.pp) or 5
          mon.maxPp[i]=max
        end
        mon.pp[i]=max
      end
    end
  end

  local function gen3GrantBadges(s)
    if not s then return end
    s.badges=255
    s.flags=s.flags or {}
    local okS,Space=pcall(require,"src.core.game3.scripting.space")
    local okF,Flags=pcall(require,"src.core.game3.scripting.flags")
    local store=okS and Space and ((Space.getStore and Space.getStore()) or Space.store) or nil
    for i=1,8 do
      local id=0x820+i-1
      local name=string.format("FLAG_BADGE0%d_GET",i)
      s.flags[id]=true
      s.flags[tostring(id)]=true
      s.flags[name]=true
      if store and okF and Flags and Flags.setFlag then Flags.setFlag(store,nil,id,true) end
    end
  end

  local function gen3CompleteDex(s)
    if not s then return end
    local Dex=require("src.core.game3.dex")
    s.dex=s.dex or Dex.new()
    for sp=1,386 do Dex.setCaught(s.dex,sp) end
  end

  local function applyGen3ContinuousEffects()
    local s=liveGen3Session()
    if not s then return end

    if enabled("cash") then s.money=999999 end
    if enabled("coins") then s.coins=9999 end
    if enabled("master_ball") then gen3EnsureItem("MASTER_BALL",99) end
    if enabled("rare_candy") then gen3EnsureItem("RARE_CANDY",99) end
    if enabled("pp_up") then gen3EnsureItem("PP_UP",99) end
    if enabled("badges") then gen3GrantBadges(s) end
    if enabled("complete_dex") then gen3CompleteDex(s) end

    if type(s.party)=="table" then
      for _,mon in ipairs(s.party) do
        if type(mon)=="table" then
          if enabled("party_hp") then
            if not mon.maxHp then
              local P=require("src.core.game3.pokemon")
              if P.applyStats then P.applyStats(mon) end
            end
            if mon.maxHp then mon.hp=mon.maxHp end
          end
          if enabled("infinite_pp") then gen3FillPP(mon) end
        end
      end
    end

    local b=activeGen3Battle
    if b then
      local p=b.player and (b.player.mon or b.player)
      if p and enabled("party_hp") then p.hp=tonumber(p.maxHp) or tonumber(p.hp) or 1 end
      if p and enabled("infinite_pp") then gen3FillPP(p) end
      local e=b.enemy and (b.enemy.mon or b.enemy)
      if e and enabled("enemy_burn") and not e.status then
        e.status="BRN"
        if b.enemy then b.enemy.status="BRN" end
      end
    end
  end

  mod.hooks:wrap("input.step", function(next,game,dt)
    installBattleArtCompat()

    if isGen3(game) then applyGen3ContinuousEffects() end

    local save=(not isGen3(game)) and game and game.save or nil
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
      if enabled("complete_dex") and isGen3(game) and save.pokedex then
        for sp=1,386 do save.pokedex.seen[sp]=true; save.pokedex.caught[sp]=true end
      end
      if enabled("party_hp") then
        -- Keep slot 1 full outside battle for compatibility with the original
        -- GameShark-style cheat, then also heal the live active battler below.
        local mon=save.party and save.party[1]
        if mon then
          mon.hp=mon.maxHp or (mon.stats and mon.stats.hp) or mon.hp
        end

        if isGen3(game) then
          local active=activeGen3Battle and activeGen3Battle.player and activeGen3Battle.player.mon
          if active then active.hp=active.maxHp or active.hp end
        elseif isGen2(game) then
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
      if not isGen2(game) and not isGen3(game) and save.safari then
        if enabled("safari_balls") then save.safari.balls=99 end
        -- Gen 1 starts the Safari Game at 502 internally and reaches 500
        -- after the two gate steps.  Keep a generous full-session value here
        -- before the engine advances so the game-over branch can never fire.
        if enabled("safari_time") then save.safari.steps=500 end
      end
    end
    if isGen2(game) then
      for _,s in ipairs(goldBattleScreens(game)) do if enabled("steal_trainer") and not s.battle.wild then patchGoldTrainer(s) else unpatchGoldTrainer(s) end end
    elseif not isGen3(game) then
      for _,b in ipairs(gen1BattleStates(game)) do
        if enabled("steal_trainer") then patchGen1Trainer(b) else unpatchGen1Trainer(b) end
      end
    end
    if enabled("enemy_burn") then burnEnemy(game) end

    local result=next(game,dt)

    if isGen3(game) then applyGen3ContinuousEffects() end

    -- Re-apply Safari cheats AFTER the engine update too.  A completed player
    -- step decrements save.safari.steps and a thrown Safari Ball decrements
    -- save.safari.balls during next(game,dt).  Refilling only before `next`
    -- made Red visibly count down and could make the cheats appear broken on
    -- builds that render the post-step value.  The post-update write keeps the
    -- counters stable for Red, Blue and Yellow.
    do
      local postSave=game and game.save
      local safari=postSave and postSave.safari
      if safari and not isGen2(game) and not isGen3(game) then
        if enabled("safari_balls") then safari.balls=99 end
        if enabled("safari_time") then safari.steps=500 end
      end
    end

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
          pushScreen(game,MAIN_SCREEN)
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
      if isGen3(game) then
        local active=activeGen3Battle and activeGen3Battle.player and activeGen3Battle.player.mon
        if active then active.hp=active.maxHp or active.hp end
      elseif isGen2(game) then
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
      if isGen3(game) then
        state.pendingWild={species=state.selectedSpecies,level=r.level}
      elseif isGen2(game) and (state.wildGender~="random" or state.wildShiny~="random") then
        state.pendingWild={species=state.selectedSpecies,level=r.level}
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

    if isGen3(game) then
      local mon=(type(user)=="table" and user.mon) or (battle and battle.player and battle.player.mon)
      if mon then refillMonPP(game,mon,false) end
    elseif isGen2(game) then
      refillMonPP(game,user,true)
      if battle then refillMonPP(game,battle.player,true) end
    else
      if type(user)=="table" and type(user.curMoves)=="table" then
        for _,mv in ipairs(user.curMoves) do refillMovePP(game,mv,false) end
      end
      if type(user)=="table" then refillMonPP(game,user.mon,false) end
    end
  end)

  local function applyGen3WildOptions(mon)
    if not (isGen3(mod.game) and type(mon)=="table") then return end
    local p=state.pendingWild
    if not p then return end

    if state.wildMaxIVs then
      mon.ivs=mon.ivs or {}
      mon.ivs.hp=31; mon.ivs.atk=31; mon.ivs.def=31
      mon.ivs.spe=31; mon.ivs.spa=31; mon.ivs.spd=31
    end

    if state.wildNature~="random" then
      local want=0
      for i,v in ipairs(NATURE_CHOICES) do if v==state.wildNature then want=i-2 break end end
      if want>=0 then
        local pid=math.floor(tonumber(mon.personality) or 0)
        pid=pid - (pid % 25) + want
        mon.personality=pid; mon.nature=want
      end
    end

    -- FireRed's presentation layer honors isShiny explicitly when present.
    if state.wildShiny=="yes" then mon.isShiny=true
    elseif state.wildShiny=="no" then mon.isShiny=false end

    if state.wildGender=="male" or state.wildGender=="female" then
      local wanted=state.wildGender=="female" and "F" or "M"
      local def=selectedDef()
      local ratio=def and def.genderRatio
      if ratio~=nil and ratio~=0xff then
        local pid=math.floor(tonumber(mon.personality) or 0)
        -- Search a small PID window so nature stays fixed while gender changes.
        local nature=pid%25
        for d=0,6400 do
          local cand=pid+d
          if cand%25==nature then
            local low=cand%256
            local g=(ratio>low) and "F" or "M"
            if g==wanted then mon.personality=cand; mon.gender=wanted; break end
          end
        end
      end
    end
  end

  -- battle.started is the authoritative live-battle entry point.  Do not
  -- rely only on scanning game.stack.states: some Gen1Recomp builds/forks
  -- expose the Red battle screen through a different stack shape even though
  -- the battle event still carries the real BattleState.
  mod.events:on("battle.started", function(ev)
    if not ev then return end
    if isGen3(mod.game) then activeGen3Battle=ev.battle end

    if ev.kind=="wild" then
      -- Finalize the actual constructed Gold wild Pokemon after Mon.new has
      -- finished. This keeps its stored shiny/gender and DVs in agreement.
      local battle=ev.battle
      local mon=battle and battle.enemy
      if isGen3(mod.game) then
        local raw=mon and (mon.mon or mon)
        if raw then applyGen3WildOptions(raw) end
        state.pendingWild=nil
      elseif mon then
        applyPendingWildIdentity(mon)
      end
      return
    end

    -- Install the Gen 1 steal-trainer wrapper immediately when the trainer
    -- battle starts.  This fixes Red builds where the later stack scan never
    -- discovers the live BattleState.  Gen 2 keeps its separate screen/model
    -- path below.
    if ev.kind=="trainer" and enabled("steal_trainer")
       and not isGen2(mod.game) and not isGen3(mod.game) then
      patchGen1Trainer(ev.battle)
    end
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
    if isGen3(mod.game) then activeGen3Battle=nil end
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
    if enabled("catch_easy") and isGen3(mod.game) then return true,4 end
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

    if isGen3(mod.game) and ctx then
      local userSide=ctx.user and ctx.user.side
      local targetSide=ctx.target and ctx.target.side
      if enabled("party_hp") and targetSide=="player" then
        return 0,info
      end
      if enabled("enemy_hp") and userSide=="player" and targetSide=="enemy" then
        local remaining=tonumber(ctx.target.hp)
          or tonumber(ctx.target.mon and ctx.target.mon.hp)
          or tonumber(damage) or 1
        return math.max(1,remaining),info
      end
    end

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
    return (save and save.version) or (save and save.generation==3 and "gen3")
      or (save and save.generation==2 and "gen2") or "gen1"
  end
  mod.exports.list=function(game)
    local gold=isGen2(game); local out={}
    for _,c in ipairs(CHEATS) do
      local supported=cheatSupported(c,game)
      local code=gold and c.gold or c.gen1
      out[#out+1]={name=c.name,effect=c.effect,code=code,enabled=enabled(c.effect),supported=supported}
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
  mod.exports.getWildNature=function() return state.wildNature end
  mod.exports.getWildMaxIVs=function() return state.wildMaxIVs end
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
        pushScreen(game,WILD_SCREEN)
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
        pushScreen(game,WILD_SCREEN)
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

    if gold or isGen3(game) then
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
    if isGen3(game) then
      items[#items+1]={label="NATURE",right=string.upper(state.wildNature),kind="nature"}
      items[#items+1]={label="MAX IVS",right=state.wildMaxIVs and "YES" or "NO",kind="max_ivs"}
    end
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
          pushScreen(game,WILD_SCREEN)
          return
        end

        if item.kind=="picker" then
          current:close()
          pushScreen(game,PICK_SCREEN)
          return
        end

        if item.kind=="level" then
          current:close()
          pushScreen(game,LEVEL_SCREEN)
          return
        end

        if item.kind=="gender" then
          if not selectedGenderless() then
            state.wildGender=cycleChoice(state.wildGender,GENDER_CHOICES)
            persist()
          end
          current:close()
          pushScreen(game,WILD_SCREEN)
          return
        end

        if item.kind=="shiny" then
          state.wildShiny=cycleChoice(state.wildShiny,SHINY_CHOICES)
          persist()
          current:close()
          pushScreen(game,WILD_SCREEN)
          return
        end

        if item.kind=="nature" then
          state.wildNature=cycleChoice(state.wildNature,NATURE_CHOICES); persist()
          current:close(); pushScreen(game,WILD_SCREEN); return
        end
        if item.kind=="max_ivs" then
          state.wildMaxIVs=not state.wildMaxIVs; persist()
          current:close(); pushScreen(game,WILD_SCREEN); return
        end

        if item.kind=="instant" then
          -- AUTO has a specific meaning for ordinary encounters, so don't
          -- silently invent an instant-battle level. Send the user straight
          -- to the level picker the first time instead.
          if not state.wildLevel then
            current:close()
            pushScreen(game,LEVEL_SCREEN)
            return
          end

          current:close()
          local ok=startInstantBattle(game)
          if not ok then
            -- A busy world/no healthy party/older engine simply returns to
            -- the setup screen instead of crashing the game.
            pushScreen(game,WILD_SCREEN)
          end
          return
        end

        if item.kind=="back" then
          current:close()
          pushScreen(game,MAIN_SCREEN)
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
      local moveId=isGen3(game) and mv or (type(mv)=="table" and mv.id)
      local def=moveId and game.data and game.data.moves and game.data.moves[moveId]
      items[#items+1]={
        label="SLOT "..tostring(slot),
        right=(def and def.name) or tostring(moveId or "EMPTY"),
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
          pushScreen(game,MOVE_PICK_SCREEN)
          return
        end

        if mon and moveEditor.moveId then
          setMoveSlot(game,mon,item.slot,moveEditor.moveId)
        end
        current:close()
        pushScreen(game,MOVE_PARTY_SCREEN)
      end,
      onCancel=function() pushScreen(game,MOVE_PICK_SCREEN) end,
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
        if not (type(row)=="table" and (type(row.id)=="string" or type(row.id)=="number")) then return end

        moveEditor.moveId=row.id
        moveEditor.moveName=row.name

        local ok,reason=teachMove(game,mon,row.id)
        current:close()

        if ok then
          -- Added to a free slot, or selected a move already known.
          pushScreen(game,MOVE_PARTY_SCREEN)
        elseif reason=="full" then
          pushScreen(game,MOVE_SLOT_SCREEN)
        else
          pushScreen(game,MOVE_PARTY_SCREEN)
        end
      end,
      onCancel=function() pushScreen(game,MOVE_PARTY_SCREEN) end
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
          pushScreen(game,MAIN_SCREEN)
          return
        end

        moveEditor.partySlot=item.slot
        current:close()
        pushScreen(game,MOVE_PICK_SCREEN)
      end,
      onCancel=function() pushScreen(game,MAIN_SCREEN) end
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
            pushScreen(game,ITEM_PICK_SCREEN)
            return
          end
          addItemToBag(game,id,1)
          current:close()
          pushScreen(game,MAIN_SCREEN)
        end,
        onCancel=function() pushScreen(game,ITEM_PICK_SCREEN) end
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
        pushScreen(game,MAIN_SCREEN)
      end,
      onCancel=function() pushScreen(game,ITEM_PICK_SCREEN) end
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
      if isGen3(game) then
        if row.pocket=="POKE_BALLS" then right="BALL"
        elseif row.pocket=="KEY_ITEMS" then right="KEY"
        elseif row.pocket=="TM_CASE" then right="TM"
        elseif row.pocket=="BERRY_POUCH" then right="BERRY" end
      elseif isGen2(game) then
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
        if not (type(row)=="table" and (type(row.id)=="string" or type(row.id)=="number")) then
          current:close()
          pushScreen(game,MAIN_SCREEN)
          return
        end
        giveItemState.itemId=row.id
        giveItemState.itemName=tostring(row.name or row.id)
        giveItemState.pocket=type(row.pocket)=="string" and row.pocket or "ITEM"
        current:close()
        pushScreen(game,ITEM_QTY_SCREEN)
      end,
      onCancel=function() pushScreen(game,MAIN_SCREEN) end
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
      onCancel=function() pushScreen(game,MAIN_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.teleportIndex,math.max(1,#items)))
    menu.scroll=math.max(0,math.min(uiPos.teleportScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(FRIENDSHIP_ACTION_SCREEN,{new=function(game)
    local mon=friendshipTarget(game)
    local current=friendshipValue(game,mon)
    local name="PIKACHU"

    if not isYellowFriendship(game) and mon then
      local def=editorSpeciesDef(mon,game)
      name=(mon.nickname and mon.nickname~="" and mon.nickname)
        or (def and def.name) or mon.species or "POKEMON"
    end

    local items={
      {label="CURRENT",right=tostring(current or "N/A"),kind="readonly"},
      {label="MAX FRIENDSHIP",right="255",kind="max"},
      {label="ZERO FRIENDSHIP",right="0",kind="zero"},
      {label="BACK",kind="back"},
    }

    local menu
    menu=mod.ui.ListMenu.new(game,name,items,{
      onChoose=function(item,currentMenu)
        if not item then return end
        uiPos.friendshipActionIndex=currentMenu.index or uiPos.friendshipActionIndex
        uiPos.friendshipActionScroll=currentMenu.scroll or uiPos.friendshipActionScroll

        if item.kind=="max" then
          setFriendship(game,mon,255)
          currentMenu:close()
          pushScreen(game,FRIENDSHIP_ACTION_SCREEN)
          return
        end
        if item.kind=="zero" then
          setFriendship(game,mon,0)
          currentMenu:close()
          pushScreen(game,FRIENDSHIP_ACTION_SCREEN)
          return
        end
        if item.kind=="back" then
          currentMenu:close()
          pushScreen(game,FRIENDSHIP_SCREEN)
          return
        end
      end,
      onCancel=function() pushScreen(game,FRIENDSHIP_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.friendshipActionIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.friendshipActionScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(FRIENDSHIP_SCREEN,{new=function(game)
    local save=game and game.save
    local items={}

    if isYellowFriendship(game) then
      local pika=nil
      for _,mon in ipairs((save and save.party) or {}) do
        if mon.species=="PIKACHU" then pika=mon break end
      end
      local def=pika and editorSpeciesDef(pika,game) or nil
      local name=(pika and pika.nickname and pika.nickname~="" and pika.nickname)
        or (def and def.name) or "PIKACHU"
      items[#items+1]={
        label=name,
        right=tostring(friendshipValue(game,nil) or 90),
        kind="starter_pika",
      }
    else
      for i,mon in ipairs((save and save.party) or {}) do
        local def=editorSpeciesDef(mon,game)
        local name=(mon.nickname and mon.nickname~="" and mon.nickname)
          or (def and def.name) or mon.species or ("SLOT "..i)
        local isEgg=mon.isEgg==true
        items[#items+1]={
          label=tostring(i)..". "..name,
          right=isEgg and "EGG" or tostring(friendshipValue(game,mon) or 70),
          slot=i,
          disabledEgg=isEgg,
        }
      end
    end

    items[#items+1]={label="BACK",kind="back"}

    local menu
    menu=mod.ui.ListMenu.new(game,"FRIENDSHIP",items,{
      pageJump=true,
      onChoose=function(item,current)
        if not item then return end
        uiPos.friendshipIndex=current.index or uiPos.friendshipIndex
        uiPos.friendshipScroll=current.scroll or uiPos.friendshipScroll

        if item.kind=="back" then
          current:close()
          pushScreen(game,MAIN_SCREEN)
          return
        end
        if item.disabledEgg then
          return
        end

        friendshipEditor.partySlot=item.slot
        friendshipEditor.yellowPikachu=(item.kind=="starter_pika")
        current:close()
        pushScreen(game,FRIENDSHIP_ACTION_SCREEN)
      end,
      onCancel=function() pushScreen(game,MAIN_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.friendshipIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.friendshipScroll,math.max(0,#items-menu.rows)))
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
        pushScreen(game,isGen3(game) and G3_STAT_SCREEN or MON_EDIT_SCREEN)
      end,
      onCancel=function() pushScreen(game,MAIN_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.partyEditIndex,math.max(1,#items)))
    menu.scroll=math.max(0,math.min(uiPos.partyEditScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  local G3_STATS = {
    {key="hp",label="HP"},{key="atk",label="ATK"},{key="def",label="DEF"},
    {key="spe",label="SPD"},{key="spa",label="SP ATK"},{key="spd",label="SP DEF"},
  }

  mod.content.screens:register(G3_VALUE_SCREEN,{new=function(game)
    local mon=getPartyMon(game)
    local kind=editor.g3Kind; local key=editor.g3Key
    local max=(kind=="iv") and 31 or 255
    local tbl=mon and ((kind=="iv") and mon.ivs or mon.evs) or {}
    local cur=tonumber(tbl and tbl[key]) or 0
    local items={}
    for v=0,max do items[#items+1]={label=tostring(v),right=(v==cur) and "*" or "",value=v} end
    local menu
    menu=mod.ui.ListMenu.new(game,string.upper(kind or "STAT").." "..string.upper(key or ""),items,{
      pageJump=true,keyRepeat=true,
      onChoose=function(item,current)
        if not (item and mon and key) then return end
        if kind=="iv" then mon.ivs=mon.ivs or {}; mon.ivs[key]=item.value
        else mon.evs=mon.evs or {}; mon.evs[key]=item.value end
        refreshEditedMon(game,mon)
        current:close(); pushScreen(game,G3_STAT_SCREEN)
      end,
      onCancel=function() pushScreen(game,G3_STAT_SCREEN) end
    })
    menu.index=math.max(1,math.min(cur+1,#items)); menu.scroll=math.max(0,math.min(menu.index-1,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(G3_STAT_SCREEN,{new=function(game)
    local mon=getPartyMon(game)
    if not mon then return mod.ui.ListMenu.new(game,"IV / EV EDIT",{},{onCancel=function() pushScreen(game,PARTY_EDIT_SCREEN) end}) end
    mon.ivs=mon.ivs or {}; mon.evs=mon.evs or {}
    local def=editorSpeciesDef(mon,game)
    local name=(mon.nickname and mon.nickname~="" and mon.nickname) or (def and def.name) or mon.name or tostring(mon.species)
    local items={}
    for _,r in ipairs(G3_STATS) do items[#items+1]={label=r.label.." IV",right=tostring(mon.ivs[r.key] or 0),kind="iv",key=r.key} end
    for _,r in ipairs(G3_STATS) do items[#items+1]={label=r.label.." EV",right=tostring(mon.evs[r.key] or 0),kind="ev",key=r.key} end
    items[#items+1]={label="MAX ALL IVS",kind="max_iv"}
    items[#items+1]={label="MAX ALL EVS",kind="max_ev"}
    items[#items+1]={label="ZERO ALL EVS",kind="zero_ev"}
    items[#items+1]={label="BACK",kind="back"}
    local menu
    menu=mod.ui.ListMenu.new(game,name,items,{pageJump=true,onChoose=function(item,current)
      if not item then return end
      if item.kind=="iv" or item.kind=="ev" then editor.g3Kind=item.kind; editor.g3Key=item.key; current:close(); pushScreen(game,G3_VALUE_SCREEN); return end
      if item.kind=="max_iv" then for _,r in ipairs(G3_STATS) do mon.ivs[r.key]=31 end; refreshEditedMon(game,mon); current:close(); pushScreen(game,G3_STAT_SCREEN); return end
      if item.kind=="max_ev" then for _,r in ipairs(G3_STATS) do mon.evs[r.key]=255 end; refreshEditedMon(game,mon); current:close(); pushScreen(game,G3_STAT_SCREEN); return end
      if item.kind=="zero_ev" then for _,r in ipairs(G3_STATS) do mon.evs[r.key]=0 end; refreshEditedMon(game,mon); current:close(); pushScreen(game,G3_STAT_SCREEN); return end
      if item.kind=="back" then current:close(); pushScreen(game,PARTY_EDIT_SCREEN); return end
    end,onCancel=function() pushScreen(game,PARTY_EDIT_SCREEN) end})
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
        pushScreen(game,MON_EDIT_SCREEN)
      end,
      onCancel=function() pushScreen(game,MON_EDIT_SCREEN) end
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
      pushScreen(game,EV_HEX_SCREEN)
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
          pushScreen(game,MON_EDIT_SCREEN)
          return
        end
        current:close()
        pushScreen(game,MON_EDIT_SCREEN)
      end,
      onSelectKey=function(item,current)
        if item and item.kind=="digit" then
          local i=item.digit
          editor.hexDigits[i]=((editor.hexDigits[i] or 0)+15)%16
          reopen(current)
        end
      end,
      onCancel=function() pushScreen(game,MON_EDIT_SCREEN) end,
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
        onCancel=function() pushScreen(game,PARTY_EDIT_SCREEN) end
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
          pushScreen(game,DV_PICK_SCREEN)
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
          current:close(); pushScreen(game,MON_EDIT_SCREEN); return
        end
        if item.kind=="max_ev" then
          for _,r in ipairs(EV_KEYS) do mon.statExp[r.key]=65535 end
          refreshEditedMon(game,mon)
          current:close(); pushScreen(game,MON_EDIT_SCREEN); return
        end
        if item.kind=="zero_ev" then
          for _,r in ipairs(EV_KEYS) do mon.statExp[r.key]=0 end
          refreshEditedMon(game,mon)
          current:close(); pushScreen(game,MON_EDIT_SCREEN); return
        end
        if item.kind=="recalc" then
          refreshEditedMon(game,mon)
          current:close(); pushScreen(game,MON_EDIT_SCREEN); return
        end
        if item.kind=="back" then
          current:close(); pushScreen(game,PARTY_EDIT_SCREEN); return
        end
      end,
      onCancel=function() pushScreen(game,PARTY_EDIT_SCREEN) end
    })
    menu.index=math.max(1,math.min(uiPos.monEditIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.monEditScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(MAIN_SCREEN,{new=function(game)
    local gold=isGen2(game); local g3=isGen3(game); local items={}
    for _,c in ipairs(CHEATS) do
      local supported=cheatSupported(c,game)
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
    if hasFriendshipFeature(game) then
      items[#items+1]={label="FRIENDSHIP",right=">",kind="friendship"}
    end
    items[#items+1]={label="TEACH MOVE",right=">",kind="teach_move"}
    items[#items+1]={label="GIVE ITEM",right=">",kind="give_item"}
    items[#items+1]={label="TELEPORT",right=">",kind="teleport"}
    items[#items+1]={label=g3 and "IV / EV EDITOR" or "DV / EV EDITOR",right=">",kind="party_edit"}
    if not g3 then items[#items+1]={label="USE SURFBOARD",kind="surfboard"} end
    local menu
    local title=g3 and "GAMESHARK G3" or (gold and "GAMESHARK G2" or "GAMESHARK G1")
    menu=mod.ui.ListMenu.new(game,title,items,{
      pageJump=true,
      onChoose=function(item,current)
      if not item then return end
      uiPos.mainIndex=current.index or uiPos.mainIndex
      uiPos.mainScroll=current.scroll or uiPos.mainScroll
      if item.kind=="wild_menu" then
        current:close()
        pushScreen(game,WILD_SCREEN)
        return
      end
      if item.kind=="celebi_event" then
        enableCelebiEvent(game)
        current:close()
        pushScreen(game,MAIN_SCREEN)
        return
      end
      if item.kind=="friendship" then
        current:close()
        pushScreen(game,FRIENDSHIP_SCREEN)
        return
      end
      if item.kind=="teach_move" then
        current:close()
        pushScreen(game,MOVE_PARTY_SCREEN)
        return
      end
      if item.kind=="give_item" then
        current:close()
        pushScreen(game,ITEM_PICK_SCREEN)
        return
      end
      if item.kind=="teleport" then
        current:close()
        pushScreen(game,TELEPORT_SCREEN)
        return
      end
      if item.kind=="party_edit" then
        current:close()
        pushScreen(game,PARTY_EDIT_SCREEN)
        return
      end
      if item.kind=="surfboard" then
        current:close(); local ok=useSurfboard(game); if not ok then pushScreen(game,MAIN_SCREEN) end; return
      end
      setEnabled(item.value,not enabled(item.value))
      current:close()
      pushScreen(game,MAIN_SCREEN)
      end
    })
    menu.index=math.max(1,math.min(uiPos.mainIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.mainScroll,math.max(0,#items-menu.rows)))
    return menu
  end})


  ---------------------------------------------------------------------------
  -- FireRed native menu
  --
  -- FireRed's UI does not instantiate Gen 1/2 ListMenu screens.  Keep a
  -- completely separate native Game3 menu object for FireRed, using the same
  -- GameShark state and cheat handlers.  This deliberately does NOT depend on
  -- the registered legacy screen factories at all.
  ---------------------------------------------------------------------------

  local G3Menu={open=false,mode="main",cursor=1,scroll=0,game=nil,session=nil,
    selectedNational=25,selectedItem=1,itemQty=1,selectedParty=1,selectedMove=1}

  local function g3RuntimeSession()
    local R=package.loaded["src.core.game3.runtime"] or require("src.core.game3.runtime")
    local s=R and R.getSession and R.getSession() or nil
    return s,R
  end

  local function g3Pokemon()
    return require("src.core.game3.pokemon")
  end

  local function g3Party()
    local s=g3RuntimeSession()
    return s and s.party or {}
  end

  local function g3MonName(mon)
    if not mon then return "EMPTY" end
    local P=g3Pokemon()
    local ok,name=pcall(function()
      if P.displayName then return P.displayName(mon) end
      if P.displayMonName then return P.displayMonName(mon) end
    end)
    return (ok and name) or tostring(mon.nickname or mon.species or "POKEMON")
  end

  local function g3SpeciesLimit()
    local P=g3Pokemon()
    for n=386,1,-1 do
      local ok,v=pcall(P.speciesFromNational,n)
      if ok and v then return n end
    end
    return 386
  end

  local function g3SelectedSpecies()
    local P=g3Pokemon()
    local n=math.max(1,math.min(g3SpeciesLimit(),G3Menu.selectedNational or 25))
    local ok,slot=pcall(P.speciesFromNational,n)
    return ok and slot or nil
  end

  local function g3GiveItem(id,qty)
    local s=g3RuntimeSession()
    if not (s and s.bag) then return false end
    local Bag=require("src.core.game3.bag")
    local D=require("src.core.game3.items_data")
    local info=D.info and D.info(id) or nil
    local q=math.max(1,math.min(999,math.floor(tonumber(qty) or 1)))
    if info and (info.pocket=="KEY_ITEMS" or (id>=339 and id<=346)) then q=1 end
    local cur=Bag.get(s.bag,id) or 0
    Bag.set(s.bag,id,math.min(999,cur+q))
    return true
  end

  local function g3Teach(mon,moveId,slot)
    if not mon then return false end
    local P=g3Pokemon()
    if P.knowsMove and P.knowsMove(mon,moveId) then return true end
    if slot and P.replaceMove then return P.replaceMove(mon,slot,moveId)~=nil end
    if P.teachMove then return P.teachMove(mon,moveId)==true end
    return false
  end

  local function g3Recalc(mon)
    if mon and g3Pokemon().applyStats then g3Pokemon().applyStats(mon) end
  end

  local function g3StartBattle()
    local slot=g3SelectedSpecies()
    if not slot then return false end
    local level=state.wildLevel or 5
    local ok,err=require("src.core.game3.battle_bridge").start(
      mod,G3Menu.game,{species=slot,speciesId=slot,level=level},{wild=true})
    return ok,err
  end

  local function g3Teleport(row)
    if not row or not row.loc then return false end
    G3Menu.open=false
    local Stack=require("src.ui.game3.stack")
    Stack.pop("gameshark")
    local Start=require("src.ui.game3.start_menu")
    if Start.isOpen and Start.isOpen() then Start.close() end
    return require("src.core.game3.map").load(
      mod,G3Menu.game,row.loc.map,{x=row.loc.x,y=row.loc.y,facing="down"})
  end

  local function g3ItemRows()
    local pack=require("src.core.game3.items_data").ensureLoaded() or {}
    local out={}
    for id,d in pairs(pack) do
      id=tonumber(id)
      if id and id>0 and type(d)=="table" and d.name and d.name~=""
         and d.name~="????????" then
        out[#out+1]={label=d.name,id=id}
      end
    end
    table.sort(out,function(a,b) return a.id<b.id end)
    return out
  end

  local function g3MoveRows()
    local P=g3Pokemon()
    local out={}
    for id=1,354 do
      if P.battleMove and P.battleMove(id) then
        out[#out+1]={label=(P.moveName and P.moveName(id)) or ("MOVE "..id),id=id}
      end
    end
    return out
  end

  local function g3PartyRows()
    local out={}
    for i,m in ipairs(g3Party()) do
      out[#out+1]={label=tostring(i)..". "..g3MonName(m),slot=i,
        value="L"..tostring(m.level or 1)}
    end
    if #out==0 then out[1]={label="NO POKEMON",disabled=true} end
    return out
  end

  local function g3MainRows()
    local out={}
    for _,c in ipairs(CHEATS) do
      if cheatSupported(c,G3Menu.game) and c.effect~="wild_pick" then
        out[#out+1]={label=c.name,effect=c.effect,
          value=enabled(c.effect) and "ON" or "OFF"}
      end
    end
    out[#out+1]={label="WILD POKEMON >",kind="wild"}
    out[#out+1]={label="FRIENDSHIP >",kind="friend_party"}
    out[#out+1]={label="TEACH MOVE >",kind="move_party"}
    out[#out+1]={label="GIVE ITEM >",kind="item"}
    out[#out+1]={label="TELEPORT >",kind="teleport"}
    out[#out+1]={label="IV / EV EDITOR >",kind="stats_party"}
    return out
  end

  local function g3Rows()
    if G3Menu.mode=="main" then return g3MainRows() end
    if G3Menu.mode=="wild" then
      local P=g3Pokemon()
      local slot=g3SelectedSpecies()
      local name=slot and ((P.name and P.name(slot)) or ("#"..G3Menu.selectedNational)) or "UNKNOWN"
      return {
        {label="WILD PICK",kind="wild_toggle",value=enabled("wild_pick") and "ON" or "OFF"},
        {label="POKEMON",kind="species",value=tostring(name)},
        {label="LEVEL",kind="level",value=state.wildLevel and tostring(state.wildLevel) or "AUTO"},
        {label="GENDER",kind="gender",value=string.upper(state.wildGender)},
        {label="SHINY",kind="shiny",value=string.upper(state.wildShiny)},
        {label="NATURE",kind="nature",value=string.upper(state.wildNature)},
        {label="MAX IVS",kind="maxivs",value=state.wildMaxIVs and "YES" or "NO"},
        {label="BATTLE NOW",kind="battle",value=">"},
        {label="BACK",kind="back"},
      }
    end
    if G3Menu.mode=="species" then
      local P=g3Pokemon(); local out={}
      for n=1,g3SpeciesLimit() do
        local s=P.speciesFromNational(n)
        out[#out+1]={label=string.format("#%03d %s",n,(s and P.name and P.name(s)) or "POKEMON"),nat=n}
      end
      return out
    end
    if G3Menu.mode=="teleport" then
      local H=require("src.core.game3.heal_locations")
      local names={"PALLET TOWN","VIRIDIAN CITY","PEWTER CITY","CERULEAN CITY",
        "LAVENDER TOWN","VERMILION CITY","CELADON CITY","FUCHSIA CITY",
        "CINNABAR ISLAND","INDIGO PLATEAU","SAFFRON CITY","ROUTE 4","ROUTE 10",
        "ONE ISLAND","TWO ISLAND","THREE ISLAND","FOUR ISLAND","FIVE ISLAND",
        "SEVEN ISLAND","SIX ISLAND"}
      local out={}
      for i,name in ipairs(names) do
        local loc=H.get(i)
        if loc then out[#out+1]={label=name,loc=loc} end
      end
      return out
    end
    if G3Menu.mode=="item" then return g3ItemRows() end
    if G3Menu.mode=="item_qty" then
      return {
        {label="QUANTITY",kind="qty",value=tostring(G3Menu.itemQty)},
        {label="GIVE ITEM",kind="give",value=">"},
        {label="BACK",kind="back"},
      }
    end
    if G3Menu.mode=="move_party" or G3Menu.mode=="stats_party" or G3Menu.mode=="friend_party" then
      return g3PartyRows()
    end
    if G3Menu.mode=="move" then return g3MoveRows() end
    if G3Menu.mode=="move_slot" then
      local m=g3Party()[G3Menu.selectedParty]; local P=g3Pokemon(); local out={}
      for i=1,4 do
        local id=P.moveIdAt and P.moveIdAt(m,i) or nil
        out[#out+1]={label="SLOT "..i,slot=i,
          value=(id and P.moveName and P.moveName(id)) or "EMPTY"}
      end
      out[#out+1]={label="BACK",kind="back"}
      return out
    end
    if G3Menu.mode=="friend" then
      local m=g3Party()[G3Menu.selectedParty]
      local v=m and tonumber(m.happiness or m.friendship) or 0
      return {
        {label="CURRENT",kind="readonly",value=tostring(v)},
        {label="MAX FRIENDSHIP",kind="friend_max",value="255"},
        {label="ZERO FRIENDSHIP",kind="friend_zero",value="0"},
        {label="BACK",kind="back"},
      }
    end
    if G3Menu.mode=="stats" then
      local m=g3Party()[G3Menu.selectedParty]
      if not m then return {{label="BACK",kind="back"}} end
      m.ivs=m.ivs or {}; m.evs=m.evs or {}
      local out={}
      local keys={{"HP","hp"},{"ATK","atk"},{"DEF","def"},{"SPD","spe"},{"SP ATK","spa"},{"SP DEF","spd"}}
      for _,k in ipairs(keys) do out[#out+1]={label=k[1].." IV",kind="iv",key=k[2],value=tostring(m.ivs[k[2]] or 0)} end
      for _,k in ipairs(keys) do out[#out+1]={label=k[1].." EV",kind="ev",key=k[2],value=tostring(m.evs[k[2]] or 0)} end
      out[#out+1]={label="MAX ALL IVS",kind="max_iv"}
      out[#out+1]={label="MAX ALL EVS",kind="max_ev"}
      out[#out+1]={label="ZERO ALL EVS",kind="zero_ev"}
      out[#out+1]={label="BACK",kind="back"}
      return out
    end
    return {}
  end

  local function g3Clamp()
    local list=g3Rows()
    local n=math.max(1,#list)
    G3Menu.cursor=math.max(1,math.min(n,G3Menu.cursor))
    local visible=7
    if G3Menu.cursor<=G3Menu.scroll then G3Menu.scroll=G3Menu.cursor-1 end
    if G3Menu.cursor>G3Menu.scroll+visible then G3Menu.scroll=G3Menu.cursor-visible end
    G3Menu.scroll=math.max(0,math.min(G3Menu.scroll,math.max(0,n-visible)))
  end

  local function g3Switch(mode)
    G3Menu.mode=mode
    G3Menu.cursor=1
    G3Menu.scroll=0
    g3Clamp()
  end

  function G3Menu.show(game,session)
    G3Menu.game=game
    G3Menu.session=session
    G3Menu.open=true
    G3Menu.mode="main"
    G3Menu.cursor=1
    G3Menu.scroll=0
    require("src.ui.game3.stack").push("gameshark",G3Menu,{hideBelow=true})
  end

  function G3Menu.close()
    G3Menu.open=false
    require("src.ui.game3.stack").pop("gameshark")
  end

  local function g3Activate()
    local row=g3Rows()[G3Menu.cursor]
    if not row or row.disabled then return end

    if G3Menu.mode=="main" then
      if row.effect then
        setEnabled(row.effect,not enabled(row.effect))
        applyGen3ContinuousEffects()
      elseif row.kind then
        g3Switch(row.kind)
      end
      return
    end

    if G3Menu.mode=="wild" then
      if row.kind=="wild_toggle" then setEnabled("wild_pick",not enabled("wild_pick"))
      elseif row.kind=="species" then g3Switch("species")
      elseif row.kind=="level" then
        state.wildLevel=state.wildLevel and ((state.wildLevel%100)+1) or 1; persist()
      elseif row.kind=="gender" then state.wildGender=cycleChoice(state.wildGender,GENDER_CHOICES); persist()
      elseif row.kind=="shiny" then state.wildShiny=cycleChoice(state.wildShiny,SHINY_CHOICES); persist()
      elseif row.kind=="nature" then state.wildNature=cycleChoice(state.wildNature,NATURE_CHOICES); persist()
      elseif row.kind=="maxivs" then state.wildMaxIVs=not state.wildMaxIVs; persist()
      elseif row.kind=="battle" then
        local slot=g3SelectedSpecies()
        if slot then
          state.selectedSpecies=slot
          state.pendingWild={species=slot,level=state.wildLevel or 5}
          G3Menu.close()
          local Start=require("src.ui.game3.start_menu")
          if Start.isOpen and Start.isOpen() then Start.close() end
          g3StartBattle()
        end
      elseif row.kind=="back" then g3Switch("main") end
      return
    end

    if G3Menu.mode=="species" then
      G3Menu.selectedNational=row.nat
      state.selectedSpecies=g3SelectedSpecies() or state.selectedSpecies
      persist()
      g3Switch("wild")
      return
    end

    if G3Menu.mode=="teleport" then g3Teleport(row); return end

    if G3Menu.mode=="item" then
      G3Menu.selectedItem=row.id; G3Menu.itemQty=1; g3Switch("item_qty"); return
    end
    if G3Menu.mode=="item_qty" then
      if row.kind=="qty" then G3Menu.itemQty=(G3Menu.itemQty%999)+1
      elseif row.kind=="give" then g3GiveItem(G3Menu.selectedItem,G3Menu.itemQty)
      elseif row.kind=="back" then g3Switch("item") end
      return
    end

    if G3Menu.mode=="move_party" then
      G3Menu.selectedParty=row.slot; g3Switch("move"); return
    end
    if G3Menu.mode=="move" then
      G3Menu.selectedMove=row.id
      local m=g3Party()[G3Menu.selectedParty]
      local P=g3Pokemon()
      local count=P.moveSlotCount and P.moveSlotCount(m) or #(m and m.moves or {})
      if (P.knowsMove and P.knowsMove(m,row.id)) or count<4 then
        g3Teach(m,row.id,nil); g3Switch("move_party")
      else
        g3Switch("move_slot")
      end
      return
    end
    if G3Menu.mode=="move_slot" then
      if row.kind=="back" then g3Switch("move")
      else
        g3Teach(g3Party()[G3Menu.selectedParty],G3Menu.selectedMove,row.slot)
        g3Switch("move_party")
      end
      return
    end

    if G3Menu.mode=="friend_party" then
      G3Menu.selectedParty=row.slot; g3Switch("friend"); return
    end
    if G3Menu.mode=="friend" then
      local m=g3Party()[G3Menu.selectedParty]
      if row.kind=="friend_max" and m then m.happiness=255; m.friendship=255
      elseif row.kind=="friend_zero" and m then m.happiness=0; m.friendship=0
      elseif row.kind=="back" then g3Switch("friend_party") end
      return
    end

    if G3Menu.mode=="stats_party" then
      G3Menu.selectedParty=row.slot; g3Switch("stats"); return
    end
    if G3Menu.mode=="stats" then
      local m=g3Party()[G3Menu.selectedParty]
      if not m then return end
      m.ivs=m.ivs or {}; m.evs=m.evs or {}
      if row.kind=="iv" then m.ivs[row.key]=((tonumber(m.ivs[row.key]) or 0)+1)%32; g3Recalc(m)
      elseif row.kind=="ev" then m.evs[row.key]=((tonumber(m.evs[row.key]) or 0)+1)%256; g3Recalc(m)
      elseif row.kind=="max_iv" then for _,k in ipairs({"hp","atk","def","spe","spa","spd"}) do m.ivs[k]=31 end; g3Recalc(m)
      elseif row.kind=="max_ev" then for _,k in ipairs({"hp","atk","def","spe","spa","spd"}) do m.evs[k]=255 end; g3Recalc(m)
      elseif row.kind=="zero_ev" then for _,k in ipairs({"hp","atk","def","spe","spa","spd"}) do m.evs[k]=0 end; g3Recalc(m)
      elseif row.kind=="back" then g3Switch("stats_party") end
      return
    end
  end

  local function g3Back()
    local back={wild="main",species="wild",teleport="main",item="main",item_qty="item",
      move_party="main",move="move_party",move_slot="move",friend_party="main",
      friend="friend_party",stats_party="main",stats="stats_party"}
    if back[G3Menu.mode] then g3Switch(back[G3Menu.mode]) else G3Menu.close() end
  end

  function G3Menu.handleInput(input)
    local row=g3Rows()[G3Menu.cursor]
    if input:wasPressed("up") then G3Menu.cursor=G3Menu.cursor-1
    elseif input:wasPressed("down") then G3Menu.cursor=G3Menu.cursor+1
    elseif G3Menu.mode=="species" and input:wasPressed("left") then G3Menu.cursor=G3Menu.cursor-10
    elseif G3Menu.mode=="species" and input:wasPressed("right") then G3Menu.cursor=G3Menu.cursor+10
    elseif G3Menu.mode=="item_qty" and row and row.kind=="qty" and input:wasPressed("left") then G3Menu.itemQty=(G3Menu.itemQty+997)%999+1
    elseif G3Menu.mode=="item_qty" and row and row.kind=="qty" and input:wasPressed("right") then G3Menu.itemQty=G3Menu.itemQty%999+1
    elseif G3Menu.mode=="stats" and row and row.kind=="iv" and input:wasPressed("left") then
      local m=g3Party()[G3Menu.selectedParty]; m.ivs[row.key]=((tonumber(m.ivs[row.key]) or 0)+31)%32; g3Recalc(m)
    elseif G3Menu.mode=="stats" and row and row.kind=="ev" and input:wasPressed("left") then
      local m=g3Party()[G3Menu.selectedParty]; m.evs[row.key]=((tonumber(m.evs[row.key]) or 0)+255)%256; g3Recalc(m)
    elseif input:wasPressed("a") then g3Activate()
    elseif input:wasPressed("b") or input:wasPressed("start") then g3Back() end
    g3Clamp()
  end

  local G3_TITLES={main="GAMESHARK G3",wild="WILD POKEMON",species="CHOOSE POKEMON",
    teleport="TELEPORT",item="GIVE ITEM",item_qty="ITEM QUANTITY",
    move_party="CHOOSE POKEMON",move="TEACH MOVE",move_slot="REPLACE MOVE",
    friend_party="CHOOSE POKEMON",friend="FRIENDSHIP",
    stats_party="CHOOSE POKEMON",stats="IV / EV EDITOR"}

  function G3Menu.draw()
    if not G3Menu.open then return end
    local Window=require("src.ui.game3.window")
    local Font=require("src.ui.game3.frlg_font")
    local Chrome=require("src.ui.game3.chrome")
    love.graphics.setColor(0,0,0,1)
    love.graphics.rectangle("fill",0,0,240,160)
    love.graphics.setColor(1,1,1,1)
    Chrome.fixedStdFrame(1,1,28,3)
    Window.printPx(G3_TITLES[G3Menu.mode] or "GAMESHARK G3",16,12,{colors=Font.COLOR.NORMAL})
    Window.userFrame(Window.template(1,5,28,14),0)

    g3Clamp()
    local list=g3Rows()
    for slot=1,7 do
      local i=G3Menu.scroll+slot
      local row=list[i]
      if not row then break end
      local y=45+(slot-1)*14
      if i==G3Menu.cursor then Window.cursorPx(10,y) end
      Window.printPx(row.label or "",18,y,{colors=Font.COLOR.NORMAL,maxWidth=156})
      local value=row.value or ""
      if value~="" then Window.printPx(tostring(value),180,y,{colors=Font.COLOR.NORMAL,maxWidth=48}) end
    end
  end

  mod.exports.hasFriendship=function(game) return hasFriendshipFeature(game or mod.game) end
  mod.exports.getFriendship=function(mon,game) return friendshipValue(game or mod.game,mon) end
  mod.exports.setFriendship=function(mon,value,game) return setFriendship(game or mod.game,mon,value) end
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

    -- Avoid duplicate rows if the hook is rebuilt/re-entered.
    for _,row in ipairs(out) do
      if row.id=="gameshark" then return out end
    end

    local entry={
      id="gameshark",
      label="GAMESHARK",
      onSelect=function(liveGame,session)
        if isGen3(liveGame or game) then
          G3Menu.show(liveGame or game,session)
        else
          pushScreen(liveGame or game,MAIN_SCREEN)
        end
      end
    }

    -- FireRed's native rows have stable ids ("save", "option", ...).  Gen 1/2
    -- still use the label helper.  Supporting both keeps one hook portable.
    if isGen3(game) then
      local at=#out+1
      for i,row in ipairs(out) do
        if row.id=="save" then at=i; break end
      end
      table.insert(out,at,entry)
      return out
    end

    return mod.ui.insertBefore(out,"SAVE",entry)
  end,500)
end
