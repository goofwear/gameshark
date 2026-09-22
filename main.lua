-- GameShark Compatibility 0.9.11
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
    shinyDebug="NO HOOK", shinySetupError=nil,
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

  local g3WalkWrapperInstalled=false

  local function installGen3WalkThroughWalls()
    if g3WalkWrapperInstalled then return true end
    if not isGen3(mod.game) then return false end

    local okC,C=pcall(require,"src.core.game3.collision")
    local okP,P=pcall(require,"src.core.game3.player")
    if not (okC and C and type(C.canEnter)=="function" and okP and P) then
      return false
    end

    local original=C.canEnter

    C.canEnter=function(game,tx,ty,opts)
      local allowed,reason=original(game,tx,ty,opts)
      if allowed or not enabled("walk") then
        return allowed,reason
      end

      opts=opts or {}

      -- Only override movement checks that originate at the live player.
      -- Internal NPC/script/pathfinding calls keep normal collision.
      local fromPlayer=(tonumber(opts.fromX)==tonumber(P.cellX)
        and tonumber(opts.fromY)==tonumber(P.cellY))

      if not fromPlayer then
        return allowed,reason
      end

      -- Never bypass the edge of the currently loaded map.  Map connections
      -- and normal warps still need the engine's boundary handling.
      if reason=="bounds" then
        return false,reason
      end

      -- Walls, trees, fences, water, directional blockers, NPCs and temporary
      -- metatile blockers are all passable while the cheat is enabled.
      return true,"gameshark_walk"
    end

    -- Some FireRed movement cases are decided in Player.tryMove before/after
    -- canEnter (ledge/special movement and other field-specific blockers).
    -- Add a final player-only fallback: if native movement returns "blocked",
    -- use Player.scriptStep(), which is the engine's own forced one-cell step
    -- and explicitly skips collision. Native connections/warps are attempted
    -- first; if none exists, Walk Through Walls is allowed to cross the map
    -- boundary as a true full-noclip fallback.
    if type(P.tryMove)=="function" and P._gamesharkTryMoveVersion~="0.9.1" then
      -- Always wrap the currently installed function. This is intentional:
      -- Gen1Recomp keeps engine modules loaded when a mod ZIP is updated, so an
      -- older GameShark wrapper can survive a hot reload. A versioned outer
      -- wrapper guarantees this build's behavior takes precedence immediately.
      local previousTryMove=P.tryMove
      local DIR_DELTA={
        up={0,-1}, down={0,1}, left={-1,0}, right={1,0}
      }

      P.tryMove=function(dir,game,run)
        if not enabled("walk") then
          return previousTryMove(dir,game,run)
        end

        if P.moving then
          return previousTryMove(dir,game,run)
        end

        local d=DIR_DELTA[dir]
        if not d then
          return previousTryMove(dir,game,run)
        end

        local tx=(tonumber(P.cellX) or 0)+d[1]
        local ty=(tonumber(P.cellY) or 0)+d[2]

        -- FULL NOCLIP for ordinary in-map movement. Do not ask normal
        -- collision first: some FireRed blockers return special/non-"blocked"
        -- movement results, which is why v0.8.9/v0.9.0 still felt partial.
        -- scriptStep is the engine's own forced movement primitive and still
        -- runs finishStep(), step events, land-on-warps and camera updates.
        if C.inBounds and C.inBounds(tx,ty) then
          if P.scriptStep and P.scriptStep(dir) then
            return "step","gameshark_full_noclip"
          end
        end

        -- At a real map edge, let FireRed try a legitimate connection first.
        local result,reason=previousTryMove(dir,game,run)
        if result=="connection" or result=="door" or result=="exit_door"
          or result=="stair" or result=="escalator" or result=="arrow_warp" then
          return result,reason
        end

        -- No valid connection: force the boundary step too.
        if P.scriptStep and P.scriptStep(dir) then
          return "step","gameshark_noclip_bounds"
        end
        return result,reason
      end

      P._gamesharkTryMoveWrapped=true
      P._gamesharkTryMoveVersion="0.9.1"
    end

    g3WalkWrapperInstalled=true
    return true
  end

  -- The input callback closes over this function before its implementation
  -- appears below. Declare it here so Lua captures the local, not a nil global.
  local installGen3ShinyBattlePalette
  mod.hooks:wrap("input.step", function(next,game,dt)
    installBattleArtCompat()

    if isGen3(game) then
      -- Keep setup failures visible in the Wild menu: the engine skips a
      -- throwing input hook, otherwise leaving SHINY YES looking effective.
      local okWalk,walk=pcall(installGen3WalkThroughWalls)
      -- FireRed emits battle.started with the live battler. Apply identity
      -- there without wrapping Battle.start, whose early require may fail
      -- before the battle engine has finished loading in packaged builds.
      local okPic,pic=pcall(installGen3ShinyBattlePalette)
      if not okWalk then state.shinyDebug="WALK ERR"; state.shinySetupError=tostring(walk)
      elseif not okPic then state.shinyDebug="PIC ERR"; state.shinySetupError=tostring(pic)
      elseif not pic then state.shinyDebug="NO PIC"; state.shinySetupError="sprite hook unavailable"
      elseif state.shinyDebug=="NO HOOK" or state.shinyDebug=="START ERR"
          or state.shinyDebug=="PIC ERR" or state.shinyDebug=="NO START"
          or state.shinyDebug=="NO PIC" or state.shinyDebug=="WALK ERR" then
        state.shinyDebug="HOOK OK"; state.shinySetupError=nil
      end
      applyGen3ContinuousEffects()
    end

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

  local function gen3NatureId()
    if state.wildNature=="random" then return nil end
    for i,v in ipairs(NATURE_CHOICES) do
      if v==state.wildNature then return i-2 end
    end
    return nil
  end

  local function gen3ForcedPid(species)
    local Runtime=require("src.core.game3.runtime")
    local session=Runtime and Runtime.getSession and Runtime.getSession()
    if not session then return nil end

    local Pokemon=require("src.core.game3.pokemon")
    local Catching=require("src.core.game3.battle.catching")
    local bit=require("bit")
    local Rng=require("src.core.game3.rng")

    local tid=bit.band(tonumber(session.trainerId or session.id or session.playerId) or 0,0xffff)
    local sid=bit.band(tonumber(Catching.playerSecretId(session)) or 0,0xffff)
    local trainerXor=bit.band(bit.bxor(tid,sid),0xffff)

    local targetNature=gen3NatureId()
    local targetGender=nil
    if state.wildGender=="male" then targetGender="M"
    elseif state.wildGender=="female" then targetGender="F" end

    local shinyOffset
    if state.wildShiny=="yes" then
      shinyOffset=0
    elseif state.wildShiny=="no" then
      -- Gen 3 is shiny only when the XOR result is < 8. Eight is the
      -- smallest guaranteed non-shiny value.
      shinyOffset=8
    else
      shinyOffset=(Rng.Random and Rng.Random() or math.random(0,65535)) % 65536
    end
    local targetXor=bit.band(bit.bxor(trainerXor,shinyOffset),0xffff)

    local meta=Pokemon.speciesMeta and Pokemon.speciesMeta(species)
    local ratio=meta and tonumber(meta.genderRatio)

    local validLow={}
    for b0=0,255 do
      local ok=true
      if targetGender and ratio~=nil then
        local g
        if ratio==Pokemon.GENDER_MALE then g="M"
        elseif ratio==Pokemon.GENDER_FEMALE then g="F"
        elseif ratio==Pokemon.GENDER_GENDERLESS then g="U"
        elseif ratio>b0 then g="F" else g="M" end
        if g~=targetGender then ok=false end
      end
      if ok then validLow[#validLow+1]=b0 end
    end
    if #validLow==0 then
      for b0=0,255 do validLow[#validLow+1]=b0 end
    end

    -- Construct a PID whose high/low halves produce the requested shiny
    -- XOR. Search the low two bytes for the requested Nature and Gender.
    for _,b0 in ipairs(validLow) do
      for b1=0,255 do
        local pLow=b1*256+b0
        local pHigh=bit.band(bit.bxor(pLow,targetXor),0xffff)
        local pid=pHigh*65536+pLow
        if targetNature==nil or (pid%25)==targetNature then
          return pid
        end
      end
    end
    return nil
  end

  local g3WildStartWrappedVersion=nil
  -- Normal/shiny BGR555 palettes extracted from the user-supplied, SHA-1
  -- 41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc FireRed ROM.
  -- Palette data only: no ROM, Pokémon pictures, or tile data is bundled.
  local g3PalettePairs={
    [1]={"3957ff7fb0634c534c4e6531bf313b21b71039674208f73b5327af22cb211f7c","3957ff7ff9179403ad026301bf313b21b71039674208072f621ac005e0001f7c"},
    [2]={"3957ff7f2c1aff5aff3d7a45916f2f5f902fee162a4a42086329f91d711db720","3957ff7f2b1aff2b7f07db02b923541b6f13ca02af064208690d3b22160ad109"},
    [3]={"bd7784196c3a2b4bb15ff100b71942083c211f3ad3473b1bbf2b880e2d23ff7f","395742119002560bda1bd000b7194208fe011f17d347bf2bff7f850a2a1fff7f"},
    [4]={"39574208d65aff7f9f4f5f37bc2e9e019f061f335f223b25130d2319883e326f","39574208d65aff7fff5b9f4b1e3b5a05fe05df2f5f1b9b0650092319883e326f"},
    [5]={"3957ff7f104281619f4f5f37bc2ede019f0e1f27bf3abf253a25d20838674208","3957ff7fad358161df5b9e471b373b19dd19bf1ebf2b5f277c0a520d38674208"},
    [6]={"4f4fbe211b43a55ee44943399f4f5e47fe1242081f335f22ba2915015a6bff7f","39579c19f7369c351825931400005b439f2a4208904e0c42682de41c5a6bff7f"},
    [7]={"3957ff7f5a2ab701ac003a679f4f5f37bc2e1a1ed90c7677116b5056c8314208","3957ff7f32176d0ec9113a679f4f5f37bc2e1a1e9200b77b927b0a6ba8454208"},
    [8]={"bf73ff7fbc73586fd800191292312d0dbe471b47371efa7e3576af610a3d4208","3957ff7fb8635353d8005422cc1148017f3bbc2e371e3c77b972345a0a354208"},
    [9]={"3153ff7f5b6b92522d19d51c9b3a5f37bd22371ed32113774e72094a29394208","3957ff7f3a6792520411d51cb622fa1e3d272e0668053b7bda7e5362e7344208"},
    [10]={"3957ff7f7d7fbd3f3a33bf3afd1918218f1df73b53276f328a151f7cce394208","3957ff7fbe3bbc3f3a33bf3afd199831951dff3f7e3bdb1eb1151f7c10424208"},
    [11]={"3957ff7ff73b5327ae1a8a151f7c1f7c1f7c1f7c18634208ff7fff7fff7fff7f","3957ff7f1f475f369c2510111f7c1f7c1f7c1f7c18634208ff7fff7fff7fff7f"},
    [12]={"3957ff7f42081f7cd662ef4d4a39082dff5aff29993592089c7318633363cb46","3957df6b42081f7cf766ef4d6d410c31cc376a37c82e85297f5bde4ede3e1a3e"},
    [13]={"3957ff7f3967104a3f3bbd223a36b1083f5bbc35b900b108bf5bbd3a1f7c630c","3957ff7f3967104adf377f23dc1a930d1e6b9c66d6490e31bf5b1a371f7c630c"},
    [14]={"7b6fff7f9f4f7e2ff92a340ef1011f7c1f7c1f7cce39e71c42081f7c1f7c1f7c","3957ff7fbb2f981bf3064e02a9011f7c1f7c1f7cad35e71c42081f7c1f7c1f7c"},
    [15]={"3957ff7fdf537f27db1ed1019d7f3b7bb76254565f36d92813048c31630c1f7c","3957ff7fdc373723920e69019d7f3b7bb76254562b6e865900388c31630c1f7c"},
    [16]={"7b6fff7f1863df5f9f471b33df56fc3936213932951d6f25eb141f7c42081f7c","3957ff7ff75eff63ff475a2fff131f0357227c03d70232028d011f7c42081f7c"},
    [17]={"1957ff7ff96ade539e371c37bf3a9d211821793ef52d6f25eb141f7c84101f7c","1957ff7f9452ff67be571b43ff235f0fbe02d83e542ed01d0a091f7c84101f7c"},
    [18]={"716bff7f1a6bdf5fbe4f3a3bbf3a9d2118215f5b9f1b793ef52d6f250c194208","1957ff7f9452ff4b9f3b3e2f3f0fbe067d02bf1b3d0bb90a16027201ac004208"},
    [19]={"3957ff7f00003c3bb94a3d2d741c5a6ad6599045cc287b63395bd64a8b314208","3957ff7f00007d3a1932d7594f417d4ff93e752eae197b6f186394528b314208"},
    [20]={"3957ff7f1e4b1b32de537d47fa42763afb2a7822f4192e015a6bd65ace394208","3957ff7f3f4f1b32ff639c4f3943101a7e36bc21771930195a6bd65ace394208"},
    [21]={"3957ff7f7d631a4f753a8d291f3a5e2d18296f00de2e7a1ed5090f015f57630c","3957ff7f7d571a4f753a8d29ff2b7f039d02f0007d3bd82633124c01ff4b630c"},
    [22]={"39571f7c5d57f8524c1942083f4a7e2df9243f3fde2e7a1ed5290f01de2eff7f","39571f7c3b53d8464c1942083f279f02f801df439f2f1a1b96068e01de2eff7f"},
    [23]={"395fff7fde25180db3141f7c9f4f5f379c3a50091f7c42089b62d75133418d2c","395fff7fde25180d53001f7c9f4f5f37bc2e50091f7c42081a33751ed0092b01"},
    [24]={"5a5b9f0b1c0f7b22bf42bc21180d932042089b6217567241ec2c1f7c3967ff7f","5a5bff277d0fb70a16739262ed4d06314208db22360e910dec001f7c3967ff7f"},
    [25]={"395bff7fff3fbf03fd02380250011f7c1f7c1f7c3f251c001600ad3542081f7c","395bff7f9f1b3e137d029901500d1f7c1f7c1f7cdf00f9009600ad3542081f7c"},
    [26]={"7b6fff7f7f3f1f139b2eb3199e677f173b2b1722921951190c0dad354208b914","7b6fff7fff1e5f16dc0def107b4fd93a3426d51950190f112e05ad3542081c00"},
    [27]={"5a5bff7f1f7c7c0bd902150a2e0d90091f7c1f7cf95a5c63bd6f10424a294208","5a5bff7f1f7c7a33152b70166801cc151f7c1f7cd652395fbd6f31464a294208"},
    [28]={"5a5b9e6b7d371b13981e9001ff7f5b5b31464a299926151a910d0b0942081f7c","5a5bbe4f1b3b972654224c01bd6f395f314629259e317a2536194d11c8101f7c"},
    [29]={"7b5ffb7f9877325f8b4a89315f21d72428722a5aa7491f7c1f7c1f7cff7f4208","7b5f5e7fda765666d2550c3d3d1d98082c22a81124011f7c1f7c1f7cff7f4208"},
    [30]={"5a5bff7f5a6b1042097a8259e3387f463d1d9808fb7f987711674b5a67314208","5a5bff7f186310422e2eaa1d05097f463d1d98085f7fde765a667441cd244208"},
    [31]={"5a5bff7f5a6b9d533c47b72e6e157f461c195500fb7f536fcb662d56472d4208","5a5bff7f5a6b5f73dd66585691397f463d1d55003947b53631268d15e8044208"},
    [32]={"5a5bff7f4208bf291b157600234f803a80211f7cfd767c6a975d0c3539671042","5a5bff7f4208bf291b15760016427231cd1c1f7c757ff47e6e6a674d18631042"},
    [33]={"5a5bff7fbf291b157600a75f2953803a1f7c4208bc765b66f55d0d3d18631042","5a5bff7fbf291b15760016427231cd1c1f7c4208757ff47e6e6a674d18631042"},
    [34]={"cf6aff7f9c6b1853ce2d1f7c1f7cd85d085b453e8025dc76fa71744dcd3c4208","963aff7f9c6b1853ce2d1f7c1f7c896e37568f39c920717fcc7ee76947414208"},
    [35]={"5a5fff7f186310427d25f614192a95195311ae041f7c1f537f421c3e73294208","5a5fff7f1863524a7d25f6146f2fca1a250680011f7c7f7bfe5a7c42b5314208"},
    [36]={"7b6fff7f1863524abf561f5b5d4a9b31732d4208bf15fb2caf310a1d09211f7c","7b6fff7f1863524a5f5f7f7bfe5a7c42b5314208bf159b086f2fca1a25061f7c"},
    [37]={"5a5bff7f9f5b7f4b42087d26f91575051f26bb151715d200fe3e5c36d825f000","5a5bff7ffe737a5f4208d81633028e013e07db0236024f01be2b5b03d8022b01"},
    [38]={"7b6fff7fbf159b0856001f7c1f7c1f7c1f7c7d3b7932bf5b9e3b1c37b0154208","7b6fff7fbf159b0856001f7c1f7c1f7c1f7cd95a133e9e6f3c6b9756b0394208"},
    [39]={"5a5bff7ff97e127e8e6dc84cb3110e0d9c73d400fa1842083f63bf52dc393425","5a5bff7f944b8c430b376722b3110e0d9c73d400fa1842087f77fe727b5e5035"},
    [40]={"9c73ff7f7267dc188a466431b3110e0d9c73396742087f671f575e4ab9313325","9c73ff7f8c43dc180b376722b3110e0d9c73396742087f771e73bc6ad6516924"},
    [41]={"9c73ff7f5a6b8c3142081f7c377fd1762d5e093d1e6eda5d564d8e2c1f7c1f7c","9c73ff7f5a6b8c3142081f7cd2322d1e8809e3007d6bd95634424d251f7c1f7c"},
    [42]={"9c73ff7f5a6b8c310000357fd1760c66e73cb959554df23c4c281f7c1f7c1f7c","9c73ff7f5a6b8c310000f41e4f02aa010501df563d42982db1101f7c1f7c1f7c"},
    [43]={"7b6fff7fb6183c21983f5327ae1a69111f7c1f7c1f7cd2624e52a941e5244208","7b6fff7fb6183c21b80b750bf30a0c1a1f7c1f7c1f7c711f0e13881220014208"},
    [44]={"7b6fbe5fff22df01b81576613a5bd925551df00ccc0093660f52693dc2244208","7b6fde7b5f43bf2e1a1ad3005a6bdd32381e9309ee08f642512eac1907054208"},
    [45]={"7b6fff7f9f167816b6119f31dd181829910c3f6bbe5a0e528b412831a3244208","7b6fff7f9f4fbc2e171abf3f3e2f9c16750dff77df67cc264b26c921240d4208"},
    [46]={"5a5bdf7f9c739452df2f5b1fff3dfc1c36041f7cbf323d1a171a50111f7c4208","5a5bdf7f9c739452ff67be3b5f237d1ad1091f7c3c12b8113211ad001f7c4208"},
    [47]={"5a5bdf7f5a6b33525f2b3a1bbf35dd18d81c31041f7c1f2abb1916196d044208","5a5bdf7f9c739452df2f3a1b5f2fbf1a1a0633011f7cff2a5a16b50110014208"},
    [48]={"524fff7fd2515a6bef3ddf56ff295811fd4e37365019345eb14d4d39e8284208","5a5bff7fd2515a6b1042937fcd7e0762fd4e3736711df66152510d3948284208"},
    [49]={"2c47ff7f9c7315635c57b84614364c1d9d335e2b42087e7f1d7fba6e35662c39","184bff7f9c7315635c57b84614364c1d9d335e2b4208537ff176b1720c622639"},
    [50]={"7b6fff7fbf4abf2dfa249c5bb63af0254b11ef3d42087b2ef82174218d001f7c","7b6fff7f6f62ca4d25399c5bb63af0254b11ef3d42089c32f82174118d001f7c"},
    [51]={"5a5bff7fff56bf2d3b319c5bb63af0254b11ad3542089c32f82154210d0d1f7c","5a5bff7f6f62ca4d25399c5bb63af0254b11ef3d42089c32f82174118d001f7c"},
    [52]={"3957ff7fff4b5f039902df297a1d42089c737d1af9091201ff5b9f43dc22b301","3957ff7fff4b5f039902df297a1d42089c73ff455b31b11cbf4b1f377a223001"},
    [53]={"5a5bff7f7b6f4208ff4e5e2154009726f2116e091f7c1f7cff579f43db2a5001","5a5bff7f7b6f4208ff299b191619ff66fc59f2301f7c1f7cff77df635b431416"},
    [54]={"bd77bf5f7e47db2a7001ff7f7b6f524a1f7c1f7c1f7c9f535f279c1a72094208","bd77fd7fda7b35674629ff7f7b6f524a1f7c1f7c1f7cb377526fad5a83354208"},
    [55]={"4c43ff7f5a6bbf567b0c1100ff535a37941ece091f7c147fb16aef5946354208","bd77ff7f1863dd247b0c1100fe62fb4997352f2d1f7c2e7f8972e45dc0344208"},
    [56]={"7b6fff7f7b6f9f5fdd46dd31371942081f439b3af8250e01df677e5bfa4e2d15","7b6fff7f7b6f9f5fdd463c32371942081d477832d31dec009a4b163b71268a09"},
    [57]={"7b6fff7f7b6fef3d08215f2e3719dc46392eb321cb000000ff6b9f5bfc466f15","7b6fff7f7b6fef3d08215f2e371919377422cf0d2a0500007f4fdd3a3826ce00"},
    [58]={"9c73ff7b7b6bad351f7c1f7c1f7cdf5b5c4bd93a8e111f2b3d265811ee084208","9c73ff7b7b6b4a291f7c1f7c1f7cdf5b5c4b96368e11bf2b1c1777026f014208"},
    [59]={"9c73ff7b7b6bb0319f21d8104a08ff63df4b1d3b95117f36dd1958254c004208","9c73ff7b7b6b6b2d9f21d8104a08df77bf631c4fd2299f3bfb2656124e014208"},
    [60]={"9c73ff7f7b6fb65e8c311f7c1f7c1f7cff563f3e7d25d56e305a6a49e5284208","9c73ff7f7b6ff75e8c311f7c1f7c1f7cff563f3e7d252f7f8a6ee559003d4208"},
    [61]={"9c73ff7f7b6ff75e94521f7c1f7c1f7cef3d4a291f7cf6725062ac49e4304208","9c73ff7f7b6ff75e94521f7c1f7c1f7cef3d4a291f7c4d7fa86e035a00394208"},
    [62]={"9c73ff7f9c73f75e94521f7c1f7c1f7cef3d4a294208f36a7056aa49c6341f7c","9c73ff7f7b6ff75e94521f7c1f7c1f7cef3d4a294208f2424d2ea81903051f7c"},
    [63]={"de7b1f7c1f7c1f7c1f7cda2a1516b209cc001f7c1f7cde53bf173b1370094208","0e4b1f7c1f7c1f7c1f7c3c52d94950310c291f7c1f7cdf3b7f2fdd1a2e194208"},
    [64]={"9c73ff7f6b2d3e46fc14da2a151651090d057b6fd65aff5fbf17fb0ab0094208","2d4bff7f6b2d3e461e199c5af9555339cb187b6fd65aff63bf47fe2a8f014208"},
    [65]={"9c73ff7f7b6fd65a6b2dda2a16167005ca041f7c1f7cdf57bf171b0faf094208","9c73ff7f7b6fd65a6b2dfc5d5749b0340a141f7c1f7c3f27ba02d5018f004208"},
    [66]={"5a5bff7f1c3bd81eb71eac091f7cff1c180013005a6b776314574f42261d4208","5a5bff7fdd3b3827b416ac091f7cff1c18001300df5f3b4b9636f1214c0d4208"},
    [67]={"9c73ff7fdd3bf92696222c051f7cdd18180013007b6f197b956af04d08354208","9c73ff7fdd3b3827b4168e011f7c6e6ec959e23c9b57f642512eac1907054208"},
    [68]={"9c73ff7fdd3b5927b4168e01ff1cd7204a291f7c9c73b867555bb04267214208","9c73ff7fdd3b3827b4168e01ff1c13004a291f7c5a6b1643712ecc1927054208"},
    [69]={"5a5bfe5f8a15bf42dd211711bf3b1b3b5816b7435327ae1a7916d3110d014208","5a5bff7f8a15fb5e564ab135df333b1f960a5e2bb91614027916d3110d014208"},
    [70]={"de7bff7f16169f3add2117099f4f5f37dd02f73b5327ae1a8a15f5154e094208","de7bff7f2d0ab85a13466e31ff3b9b27f612fe3fb92b1417a901f5154e094208"},
    [71]={"5a5bff7f16165a6b9f3a3a119f4f5f37bc2ef73b5327ae1a8a15f6190d014208","5a5bff7f50065a6b6b6ec659ff4ffc3757235d3bb82613124d09f6190d014208"},
    [72]={"5a5fff7f1f5f5f25b61050081a4bb63a10224a115a6b527bcd72884a44414208","5a5fff7f0e476932c41d22091a4bb63a10224a115a6b5a7fb572105e29414208"},
    [73]={"5763ff7f1f5f5f25b61050083b4fb63a31226b115a6b327bcd72884e44414208","5a5fff7ff22a4d16a801c1005c53b63a10224a11fb7f767fd16a2c5603314208"},
    [74]={"7b6fff7f39671f7c1f7c1f7c1f7c1f7c1f7c1f7c1f7c5943d5320f2e28094208","7b6fff7f39671f7c1f7c1f7c1f7c1f7c1f7c1f7c1f7cfd1a990ef4010d014208"},
    [75]={"7b6fff7f3967524a4208dd18971c1f7c1f7c1f7c1f7c1f7c5843d43a0e2a2a09","7b6fff7f3967524a4208dd18971c1f7c1f7c1f7c1f7c1f7c5916b4010f016a00"},
    [76]={"0e53ff7f7b6f16005f29f6329232ed2149093d3bda2e331e0a051f7cce394208","7b6fff7f396716005f295a2ab51510018c005f5bbc46173230151f7c10424208"},
    [77]={"9c73ff7fdf5bbf3f3d37510d1f7c1f7c1f7c9f13bf0a9f011a00b5566b2d4208","9c73ff7fff6fdf5f5e4f90151f7c1f7c1f7c917f0c7f077e6661734e6b2d4208"},
    [78]={"5a5fff7fdf5bbf3f3c2b981ab20d1f7c1f7c9f131f0b9f011900734e6b2d4208","5a5fff7fde639d5f194f5322af111f7c1f7c3873935eee494935734e6b2d4208"},
    [79]={"5a6bff7f5b6bff5fdf431c2f50051f7c1e11b6148d31df4a1f327c35d3184208","5a6bff7f3a67ff5fff4b5d3733111f7c1e1191108d313f67dd62384e312d4208"},
    [80]={"546bff7fbf4f7f3ffb2e910ddc5f584fb3328a195c15ff4a3f36bc35f21c4208","5a67ff7fbf4f3f33bc2ed4111c377722d20d0c015c15d86e746acf55093d4208"},
    [81]={"5a6bff7f9c739f21d9182a7b0556d65a31464c29c718da6f565ff24e0b324208","5a6bff7f5a6b2a25c7182a25c718d65a31462a25c718bd5f184b7336ce214208"},
    [82]={"5a6bff7f7b6f9f1dba182a7b4756d65a31462a25c718da6f565ff24e0b324208","5a6bff7f5a6b8d31c7188d31c718d65a31462a25c718df737d63d84e333a4208"},
    [83]={"5a6bff7f5a6b9c5318437f2fbc2ed315f9472f23090ef93e562a71150c014208","5a6bff7f5a6b9c5318439f37bc2eb715f947f11e4c0afe5a5a46b531101d4208"},
    [84]={"5a671f7c1f7c1f7c1f7c9a36372a92210b117d57d942ae191f7c8c314208ff7f","5a671f7c1f7c1f7c1f7c38279312ee014901df533c3fb00d1f7c8c314208ff7f"},
    [85]={"5a63dd325a1ef4252c197d57d8426c213f731e52f31c3a6710424b250000ff7f","5a6338279312ee014901df47fd2a6f015f731e5216213a67104208210000ff7f"},
    [86]={"4f4b9c7b1873935e4a359f5bf946b021ff35d83d120d1f7c1f7c1f7c4208ff7f","5a5bbd6b3a5fb64e113aff63da42ae197f3edd29f2141f7c1f7c1f7c4208ff7f"},
    [87]={"5a5fdc773877d56648417d1df8201f7c1f7c1f7c1f7c1f7c3a67cf394208ff7f","5a5fbd6b3a5fb64e113a7d1df8201f7c1f7c1f7c1f7c1f7c3a67f03d4208ff7f"},
    [88]={"bd775a6fd55e304e282dfc6e785ab24dcb387d771f7c1f7c1f7c1f7c4208ff7f","bd775a6fd55e304e282db84f5647b132ca15db5b1f7c1f7c1f7c1f7c4208ff7f"},
    [89]={"b86f7d77fc6e785ab24dcb385a6fd55e304e282d1f7c1f7c1f7c1f7c4208ff7f","bd77d84f964bf1364c22a70d5a6fd55e304e282d1f7c1f7c1f7c1f7c4208ff7f"},
    [90]={"5a5b3b77da72365eee45eb309f1518258f081f7c1f7c1f7c1f7cad354208ff7f","5a5b5a77df223f0e9a0192009f1518258f081f7c1f7c1f7c1f7cad354208ff7f"},
    [91]={"5a5f1f7cba72f55dec3989281f7c1f7c1f7c1f7c7a63f64e303649214208ff7f","5a5f1f7c8e6ae9554441a02c1f7c1f7c1f7c1f7c1863524a8c3108214208ff7f"},
    [92]={"ff7fff7f7b6f5b1db6081f7c575a91412e35ca2cba66575a91411f7c1f7c4208","ff7fff7f7b6f5b1db6081f7c1572d261eb48aa30737fce6a29561f7c1f7c4208"},
    [93]={"5a5f586eb2594c41eb381f7c1f7c1f7c1f7cdb18760c4c087b6fce394208ff7f","5a5f9a6e18667051ca301f7c1f7c1f7c1f7c6962c44d00355a6bce394208ff7f"},
    [94]={"5a6bff7f7b6fef3ddf3e9d25f9101f7c1f7c1f7c1f7c185ab3416d31cb2c4208","5a6bff7f7b6fef3dbf6a1d5678411f7c1f7c1f7c1f7c945eef494a35a5204208"},
    [95]={"7567ff7f1f7c1f7c1f7c1f7c1f7c1f7c1f7c1f7c9d735b6bd75a0f362a254208","7b6fff7f1f7c1f7c1f7c1f7c1f7c1f7c1f7c1f7c9c4f3943942eef194a054208"},
    [96]={"396bff7f3b771f7c1f7c1f7c1f7c372ab2214d15c908bf4b7f23fb16b2014208","7b67ff7f3b771f7c1f7c1f7c1f7c9735f2204d0c08047e6bfc6657524f314208"},
    [97]={"5a5fbf4f7f33d9362c11772a1a6fae411f7c1f7c1f7c1f7c734e8c314208ff7f","5a5fdf6a3d569841ef1c95355a6fae411f7c1f7c1f7c1f7c734e8c314208ff7f"},
    [98]={"5a63ff7f7b6f1f7c3d4bfc3e56224e091f7c1f7c1f7c7f3a5d11570d910c4208","5a63ff7f7b6f1f7cdf673b53963e8e1d1f7c1f7c1f7c7f27da12350290014208"},
    [99]={"5a5f7f32bd15961dd1105e4ffc46372a2c099a365f7c5f7c5f7c7b7b4208ff7f","5a5ff63e512aac1507159b23f8125302ae01960a5f7c5f7c5f7c7b7b4208ff7f"},
    [100]={"9c73ff7f5b6bb6564b291f7c1f7c1f7c1f7c1f42bf4e5f111c01192150084208","9c73ff7f5b6bb6564b291f7c1f7c1f7c1f7c6665aa750561604c003800244208"},
    [101]={"f272ff7fbd773967744e4b291f7c1f7c1f7c1f7cdf4eff251c01d60050084208","9c73ff7fbd777b73b6564b291f7c1f7c1f7c1f7c0e7f696ac4552441842c4208"},
    [102]={"3967ff7f7b6f3f277c0242081f7c1f7c1f7c1f7c1f7c7f63ff527d421832d208","3967ff7f7b6f3f277c0242081f7c1f7c1f7c1f7c1f7cff53be331c239a1e6f15"},
    [103]={"5a5fbf537f37bc2e500d7626d121eb04f73b5327ae1a8a157b6f8c314208ff7f","5a5fbf537f37bc2eb411fb2a56124d01ff3e5b2ab615ae007b6f8c314208ff7f"},
    [104]={"2947fb367826b219ca0cbd77395b31366b199e675f53dc461f7c1f7ca514ff7f","5a5fd53a1026490de6009c6b185731366b19bf635d4b992e1f7c1f7ca514ff7f"},
    [105]={"3967ff7f9c6b185731364a1d4208f8087f5b1e4b9d36b421fb367826d419ec0c","3967ff7f9c6b185731364a1d4208f8087f5b1e4b5c2ad71d7a47d532301e2801"},
    [106]={"5a5fdc4a9942f42d701dec0c1f7c1f7c9c5ff8528e31bf473d3bee11a514ff7f","5a5fd52630128b01e600a4001f7c1f7c9746f2314d1dfd4b383bee11a514ff7f"},
    [107]={"5a6bff7f3b6fd86254528e395f2e9c1dd70891001f7c5d4fd93e342a4d094208","5a6bff7f3b6fd86254528e394b6aa6550141602c1f7c9d47f832531e6c014208"},
    [108]={"3967ff7fff535c3bf0119f4a1f2a3c0d98081f7c3f5b9f42bd29591952004208","3967ff7fff535c3bf0117f4bff415a2db5181f7cbf3f7e37d922350e70014208"},
    [109]={"3463ff7f7b6fbe4b3a371d2178101f7c1f7c5d37d8163b6af7595349cd304208","3967ff7f7b6fbe4b3a379f25fa101f7c1f7c3952523d7467f25e4d4a45294208"},
    [110]={"314fff7f9c733c1f9f039b119400ff3f5c3bd816bd625a56b6451131ac204208","3967ff7f7b6f754df9559b1194003a62b651113d756bf25e4d4a4529c1184208"},
    [111]={"5a5f9c77f76610566b3d082df5142b001f7c1f7c1f7c1f7c1f7c1f7c4208ff7f","5a5fdd4e383a9325ee104900f5142b001f7c1f7c1f7c1f7c1f7c1f7c4208ff7f"},
    [112]={"546bff7fbf635c57963aaf1d5c1dd4088e081f7c1f7c7b6b185f314a6b314208","5a6bff7fbf635c57963aaf1d5c1dd4088e081f7c1f7cbf635c5bb746d0294208"},
    [113]={"5a6bff7fbe531f7c1f7c1f7c1f7c4208bf561f2e5c199f735f6bbd5ede39f414","5a6bff7fbe531f7c1f7c1f7c1f7c4208b637522bed1aff73bf673e47bc326f09"},
    [114]={"5a5f757bf06ae84904291f421a29b2141f7c1f7c1f7c1f7cd65a4a294208ff7f","5a5f6f1fca0a250220011f427b2db2141f7c1f7c1f7c1f7cd65a4a294208ff7f"},
    [115]={"5a6bff7f5a6bdf475b37770c4208db6ad44df6425132ad29fa429736d32d0a09","5a6bff7f5a6bff4b3d37770c42083d5b7746712acc1527017d5b3a4f953a6c19"},
    [116]={"5a6b1f7c1f7c4c151326777f1477505a4731ff573c27df39b8141f7c4208ff7f","5a6b1f7c1f7c4f15f5292e6b8956e44122291f57bd46df39b8141f7c4208ff7f"},
    [117]={"5a5fba637473f0660d4ea941042dff571b2bf2214d151f7c7b6f734e0000ff7f","5a5fcd568d66c851473da62000285f4bdd42553d4d151f7c7b6f734e0000ff7f"},
    [118]={"5a5f7b73f762314a8c351f3ffd211a09d6005000fd211a09a852a0314208ff7f","5a5f7b73f762314a8c357f0f7f06da0135019000df463a32a852a0314208ff7f"},
    [119]={"5a5f5a6fd55e304e6b311f67fe2df4201f7c9f3efe2d1b11d4104a294208ff7f","5a5fdc53da47901ecb051f67fe2df4201f7cdf433f2f9a1ab3014a294208ff7f"},
    [120]={"5a5f4208ff5b5e2bb80a6e015d57da3ad4190d115f6b7d469c211511782aff7f","5a5f4208ff5b5e2bb80a6e019c67f752523e8c25f37f4d7fa86ec1519546ff7f"},
    [121]={"5a5f5766925110418a30df4b5e2b980a4d011f7cff521e29d92c4f004208ff7f","5a5f327b8d6ae855e0343f4e9f39f82450101f7cee7a49664145a1304208ff7f"},
    [122]={"395b596f1056283dc5245f463d1d371daf149f6f3f639c4e0d1df7354208ff7f","395b596f1056283dc524962bf1164c026501bf773f67bc567129f7354208ff7f"},
    [123]={"5a63ff7f7b6ff75ece399e3f192fff579e3ff91c331af73b7327ae2288114208","5a63ff7f7b6ff75ece39ff2df92dff5fbd4bf91c331a711bec1a480667054208"},
    [124]={"5a5b5a6b8c393a76b56132559f4e1d2136252d00df57bf2b1a1faf0d0000ff7f","5a5b5a6b8c393a76b5613255bf721f5e7a4972289f6ffa5a55466e290000ff7f"},
    [125]={"7b6fff7f7b6fae2d42081f7c1f7cbf3e5f11d7041f7cff6bff579f1ffb2a6e09","7b6fff7f7b6fce3942081f7c1f7cbf3e5f11d7041f7c9f4b3f171d029901b400"},
    [126]={"5a6bff7f5a6bad35a5141f7c1f7cdf335f039b1291059f223f05b92031001f7c","5a6bff7f5a6bad35a5141f7c1f7cbf7f1f6b79562f2d9f56fd415a2db4181f7c"},
    [127]={"5a6bff7fbd675a5bb5426b251f7c1f7c1f7c1f7c353a1c4f9942d12d0b154208","5a6bff7fbf5f1c4f76362c1d1f7c1f7c1f7c1f7c4a492f6eac590735a4284208"},
    [128]={"5057ff7f9c77197fd2564b351f7c772a13226e11c9001e339c26f7194e0d4208","5a6bff7f7d7f197f54662b351f7c2f1bca0ee301260dff339f2bfa1eb0194208"},
    [129]={"eb61ff7f7b73b55ece454208fd435d33b009df4aff2dd818bf3abf113b253100","5a5fff7f7b73b55ece454208fd431b2fb009ff579f1bfe2aff337f139c165315"},
    [130]={"515b9b7bd562ed49f17e6e720f52e7309f4f183fac1d1f3ed91892000000ff7f","39579b7bd562ed491f2f3f227a19ef1cff4b3943ad2d9f1dd91892000000ff7f"},
    [131]={"5257ff7f7c151400bf4b1c37b0197d6b1a5f54464c2d337bce722e622635a514","5a5fff7f7c1514003d6bbb5a51357d6b1a5f54464c2df97a7572905d0a45a514"},
    [132]={"5a5fe07fe07fe07fe07f1e777d6ada515641ae2ce07fe07fe07fe07fc618ff7f","5a5fe07fe07fe07fe07f917f2d7b8972e4612345e07fe07fe07fe07fc618ff7f"},
    [133]={"3153ff7fdf673a4fb736d0251c001f7c1f7c1f7c4208dc3a7a2ed4192b111f7c","3967ff7ffe7f9b7bd56aed499c151f7c1f7c1f7c4208bd6b7b67b5564a291f7c"},
    [134]={"5a6bff7f9c73b566bf3ffc26f1152e5acb4d063d6b39b06b2c5b8746a229a514","5a6bff7f9c73b566ff4f1c27310a7539d64df02c6b391f7bbc7217620f45a514"},
    [135]={"5a5fbe3b7f1bfa1a331e4d111f7cd7180d001f7c1f7c9b6f51528c31a514ff7f","5a5ffb43b81313038f02c9011f7cd7180d001f7c1f7c7b7351528c31a514ff7f"},
    [136]={"3967ff7fbf379f171b13d2051f7c1f7c1f7cce3d42081f7cbf1aff011c019010","3967ff7fff63ff1f3d07b4011f7c1f7c1f7cce3d42081f7cfe229b16d505ec0c"},
    [137]={"5a5f4e7fe76a654661351f535f469b29520c7b731f7c1f7c1f7c1f7ca514ff7f","5a5fbf773d77b9660c39f07ec7794365c04c7b731f7c1f7c1f7c1f7ca514ff7f"},
    [138]={"7b5fff7f9c731f7c1f7c8c314208ff579d47193795266c093063ac52073e6229","7b5fff7f9c731f7c1f7c8c314208df4f7e47fa3a552a8f157a76d5653055ab48"},
    [139]={"7b63bf5b5e33762242081f7c1f7cff579d47193795268d09936f3063ac52822d","7b63bf5b5e33762242081f7c1f7cff6fdd2f7a27d51eac0dbb7e37769265cc50"},
    [140]={"3967ff7fd65a1f633d211f7cff475f1bdb16b4011f7cbc223716930ded044208","3967ff7fd65abf523d211f7cff475f1bdd12b4011f7c9627331f8e12ea094208"},
    [141]={"5a6bff7f7c63f75a734aad351f7c1f7c1f7c1f7c1f7c7e4bfb3a552e2b0d4208","5a6bff7f7b6bf75a734aad351f7c1f7c1f7c1f7c1f7cfb2f7727d216ca014208"},
    [142]={"535b1f7c1f7c1f7c176292592c49c9309b31d11842087c77396fb25a8929ff7f","5a5f1f7c1f7c1f7c4c7ec871425963349b31d11842081e779c6ef659ef40ff7f"},
    [143]={"5a5f8f4a0c3a87294721ff63de4f7d4f31269a36382a770c5a6fad394208ff7f","5a5f6966c85d65416531be5f9e5b5d53732a7b32f61d720d5a6fad394208ff7f"},
    [144]={"5a5fba7f387fd1724c66a75129351f7c1f7cb3622f52cc41b71c9c394208ff7f","5a5fff7fdd7f997ff37a4c6aaa4d1f7c1f7c916acb512935b71c9c394208ff7f"},
    [145]={"503fff7f7b6f734e082142081f7c1f7cff1e9b1a7211ff47bf033c0b35226f15","5a5fff7f7b6f734e6b2d42081f7c1f7cbf211a11f314bf131f0359029301ee00"},
    [146]={"5a5fff7f7b6f16005f4f5f269f011d00bd26f911d000df237f0bbf0257014208","5a5fff7f7b6f16005f4f5f269f01d714df2dd91054107f67bf52dc35f51c4208"},
    [147]={"5a6bff7fbd63394fef291f7c1f7c1f7c1f7cd1555158987214624e49672c4208","5a6bff7fbd63184fef291f7c1f7c1f7c1f7c774151585d62b95114418f2c4208"},
    [148]={"7043ff7fdc7b5a73ad3d0f7b0a660445c32c4208cf3cef7a8a6a0c5224391f7c","7b6fff7f7b73d662ad3ddf53fe263a0a50154208cf3c5c6ad961134deb301f7c"},
    [149]={"fb6a552a9f3f3f2bda2e8e1d0f638a52c635df675a5373365a6fce394208ff7f","7b6fcc29d33e6f32ab21e6187b6ad6592e3ddf675a5373365a6fce394208ff7f"},
    [150]={"5c6b9c7bf76a315a4a35dc7e166a7155ce481f7c1f7c1f7c1f7c1f7c4208ff7f","5c6b9c73d65a524a291db72f32234b1268151f7c1f7c1f7c1f7c1f7c4208ff7f"},
    [151]={"7b6fff7f5a6b6351ca7e1f7c1f7c1f7c1f7c5b425e731f679f4a3a29f31ca514","7b6fff7f5a6b6351496a1f7c1f7c1f7c1f7cd17adc7fb87f547b2a66c959a514"},
    [152]={"3957ff7ffb43b9331307c901ac2607166001e0003967734e8c3142081a2a1200","3957ff7fff4bbe2f191fb009fe367a26940d0b153967734e132642087b3af51c"},
    [153]={"3957ff7fff57be37fb16140e4d010d1b890ae605420918638c3142083a2ad500","3957ff7fbf635f5b7c3e97212f1dfc1a570e8f050a0918638c3142087b3af51c"},
    [154]={"7b6fff7ff73f932bed1a240a2c019e4eff2c991c4f1c3967ad3542087f13bc02","3957ff7fff339e171a0bd005e900df22ff09390131013967ad3542087f13bc02"},
    [155]={"3957ff7f0c5e48450531a328bf533c37762a91117f037f029f011d0031464208","3957ff7f7c369721111dec149f3b1b2b351a510d7f037f029f011d0031464208"},
    [156]={"3957ff7f0c5e48450531a328bf533c37762a91117f037f029f011d00d65a4208","3957ff7f7c369721111dec149f3b1b2b351a510d7f037f029f011d00d65a4208"},
    [157]={"3957ff7f2c5a483de5302024bf4b1a3734262c097f037f029f013d004208ff63","3957ff7fba2d1525b0208d149f3b1b2b351a510d7f037f029f011d004208df4f"},
    [158]={"1953ff7f527fcd7206622941d65a1f3b7f11b9080f007f11b9081f2b15164208","1953ff7fd35f6d5ba84aa42dd65ad07ea96126510635ff25381d1f2b15164208"},
    [159]={"3957ff7f307fab72066229411c110f00bf2e7f11b90c0f009f33dc2ad3054208","3957ff7fd46f4e67895aa6451c110f00cc728761664d04359f33dc2ad3054208"},
    [160]={"3957ff7f307fab72066229411863bf2e7f11b90c0f00ff4f5f2bb922d3054208","3957ff7fae6f2a636952853d18636d7a8669054dc02cff4f7e3bda26d3054208"},
    [161]={"7b6fff7f7d471c2b9922361eb2110e09ab0427001b0d96081f3ace3908214208","3957ff7fdf577d3f9922b9265839b2284a2027001b0d96081f3ace3908214208"},
    [162]={"7b6fff7fff63bf4b1c277822151693250f1d690cd80c13005f32ce3908218414","3957ff7fdf739f6ffb569c45f22d1839942c1020d80c13005f32ce3908218414"},
    [163]={"3957ff7ffe5fdc535b2ff9167512120eaf092b019f57df36fc15ef3d4a294208","3957ff7fff5fbd37bf3b7e1ffc1a5a16181251119f57df36fc15ef3d4a294208"},
    [164]={"3957ff7fff573c339922d31df3356f250c19a90cd80c13001863ce39bf3b4208","3957ff7ffe577a2ff71e53129a26d6014f01ea00d80c13001863ce39dd3b4208"},
    [165]={"3957ff7f7e1a5d0d1615cf0cff5f9e3bd91ef401205160383967d65ace394208","3957ff7f7f179f02f9013009ff67be43f926140a205160385a6bd65aad354208"},
    [166]={"3957ff7f1f437f11f808d008ff5f9e3bd91ef401205160385a6bd65aad354208","3957ff7f7f179f02f9013009ff67be43f926140a205160385a6bd65aad354208"},
    [167]={"3957ff7ff93b9223ec12ea154609ff2f961af2197f2add00d200f75eef3d4208","3957ff7f566fb15eaa4d272dc424bc66753d0d297f2add00d200f75eef3d4208"},
    [168]={"3957ff7fbf1eff15590191000900bf2fdb26d219577e7275cd54f75ead354208","3957ff7f3d5eb951113d4e282a18bf2fdb26d219527f8c724459f75ead354208"},
    [169]={"3957ff7f3c7a7865f3586e481f7c1f7c695ea44922395f035a029452ad354208","3957ff7f5f77de621b4a34351f7c1f7cf112290245015f035a029452ad354208"},
    [170]={"3957ff7f997f347f717eec696855e038df577f3fda2e361eed00910d14004208","3957ff7fb27f6f7fca7e256e6159e340fa3bd4232f27ab1a270e440df2004208"},
    [171]={"3957ff7fb556347fb17e2c72a7654045bf3f9f2bda2e361e50054208df011600","3957ff7fb5567c7e197a946d1061ad44ff37bd23d61631066b054208df01d900"},
    [172]={"3957ff7fff63bf43dc22380250011f7c1f7cdf2518158e043967ce394a294208","3957ff7fff2f7f17db02150250011f7c1f7c5f0118000e003967ce394a294208"},
    [173]={"3957ff7f3f4f9f42db213801cc109a16b4012f01cb001f7c190013004a294208","3957ff7f7f6fff62fd49562984016f2fca1a250680011f7c190013004a294208"},
    [174]={"3957ff7f3f4f5f3adb21380192089f5b1f7c19001300190013000c00ad354208","3957ff7f5f77be62db45f62c7318bf771f7c190013000b0fa90e4501ad354208"},
    [175]={"3957de7fd662ad3d42087800ff67df571b3b5526ed00db3978000d6e20693967","3957de7fd662ad3d42087800ff679f57da3a151eed000d6e2069db3978003967"},
    [176]={"10479c773967b55e104a6b3942081f7c1f7c1f7c1100db3916000d6ea060ff7f","3957ff7b7c57d74632126d1d42081f7c1f7c1f7c11000d6ea060db391600ff73"},
    [177]={"3957ff7f93270a27492286157f23b91e90113f01f900b0003967524a4a29a514","3957ff7ff723941bee06a8017f23571271019f1eba092e013967524a4a29a514"},
    [178]={"3957ff7f93272a27492286157f2357127101fd00d600b0003967524a4a29a514","3957ff7ff723941bee06a8017f23571271019f1eba092e013967524a4a29a514"},
    [179]={"3957ff7fbf431c335816710dc972445e204980347f03bc02f60194524a294208","3957ff7f5f675d5a7b41152dc972445e204980347f03bc02f60194524a294208"},
    [180]={"3957ff7f396f735ace4529251f535f3e7d21f90c1500107f0a6205451f7c4208","3957ff7f7c67d74a122a4d197f771f6b3c4e963512258c0bc602a4011f7c4208"},
    [181]={"3957ff7fbf271f0b5a0232011f7c9c73b556ac3542089f01180191000b001f7c","3957ff7fde6a5a5ad74d51351f7c9c73b556ac354208307ba865044d26451f7c"},
    [182]={"3957ff7f5327ae1a8a159c37d61e100e0a1b27026209be019a00100094524208","3957ff7f7b7ef7710f59da2f14172c062b43463244251f56d934722894524208"},
    [183]={"7b6fff7f9b6f734e8c314208f37e4d7ec97d062d675d1f7c1e023a0172001f7c","7b6fff7f9b6f734e8c314208f34f8f432b37e62186261f7cdf493a39b41c1f7c"},
    [184]={"3957ff7f3967734ead354208307fab72066229411f7c1f7c5c01b8000f001f7c","3957ff7f3967734ead354208bf2b5f1fba0e70151f7c1f7c3d21781c0f001f7c"},
    [185]={"3957ff7f1c37772ad2192c091f7cf147651ba51aa3113f035b02b301d65a4208","3957ff7f7b1ff60e2f0e6a0d1f7c3f57df253919f0143f035b02b301d65a4208"},
    [186]={"3957ff7fff539f2bdc169301f943b31bef0ee601df36bc19f600396710424208","3957ff7f9f773e779a664f3d937f0e7f49666649bf2ebc19f410396710424208"},
    [187]={"7b6fff7f7f3a9f291a0954001f7c901f2c1f881284091f7cff2b1e031f7c4208","3957ff7f3213cd062b1667091f7cd71f701faa0e84091f7cff2b1e031f7c4208"},
    [188]={"3957ff7fb11f2c1fa81283011f7cbf3b5f039e0275011f7c1f7c5a6b94524208","3957ff7f5f6abb5d7549cc281f7cbf3b5f037d0a73091f7c1f7c5a6b94524208"},
    [189]={"39570c058f7e0b6aa86147494208ff6fbe5b7d4bf93a332a3f161a01881f661a","3957ee303f579e52fb4d34354208bf7b5e77bb6a395694513f161a01881f661a"},
    [190]={"3957ff7f1a7e9671f1588a34df63bf531d2f782ab1211f7c5a6bef3d6b2d0000","3957ff7f1f529c45f7348e20bf737f6bfd5afb41572d1f7c5a6bef3d6b2d4208"},
    [191]={"3957e9142a158d19961a961e3a1bff031f7c84098a1e4e17d41f4208ce45ff7f","3957e914ea142d19b411d5199a1a5f2f1f7c84098a1e931bf9334208ce45ff7f"},
    [192]={"395742081f7c7009f8119b0e3d077c2fff53df0bfb001f7c8a15ae1a5327f73b","395742081f7c4c01f201b9127d2b7c2fff53ff53fb001f7c2a01cf01b6167c27"},
    [193]={"3957d2001f7c1a01ff217f4b4208a601ca12b01329291f7c0e46d46afc7f1f7c","395700491f7cc571c97e8e7f4208a601ca12b01329291f7c0e46d46afc7f1f7c"},
    [194]={"39571252a2382641696a117b9873bd7ef8619251ec341f7c1f7c1f7c4208ff7f","39577631ef18732d7a521e679f6b5f575c32982930251f7c1f7c1f7c4208ff7f"},
    [195]={"3957c2200431674d1f7c29668c723577b87b1f7c1f7c4c3d9249df591f7c4208","3957e9202c310b2d1f7c9251f7659c72ff761f7c1f7c4c3d9249df591f7c4208"},
    [196]={"39571f7c1f7c1f7c1f7cf020fa20c618ea344f59d671ba727d7742086048ff7f","39571f7c1f7c1f7c1f7c70019f22c618851569222d27942ffa4f4208aa2cff7f"},
    [197]={"39571f7c1f7ca614e81c4b2912429652910159161f03bf471f7c42087f1dff7f","39571f7c1f7ca614e81c4b29124296522449a571cc7e927f1f7c42085f0bff7f"},
    [198]={"7b6fbf46fd20551005214729aa3591521f7c2d09f311da16ff2b1f7c4208ff7f","7b6fbf46fd205510ac2cf34478511d621f7c2d09f311da16ff2b1f7c4208ff7f"},
    [199]={"39574208ff1d391193003911bc19df3ab201ff1aff474a21523ed6567b67ff7f","395742088c7a665d90247639fa49df62b201fd22ff474a21523ed6567b67ff7f"},
    [200]={"7b6f42082521a9396e4af25a1f78df2b55247d495f638f00970c7f155f5eff7f","7b6f42084c09331a1a339e3f1f7cdf2b0a11fc229f37af04f50c7f151f1bff7f"},
    [201]={"39571f7c1f7c1f7c7b6fff7f42089452ce394a291f7c1f7c1f7c1f7c1f7c1f7c","39571f7c1f7c1f7c2c7fff7f4208c57d044de6341f7c1f7c1f7c1f7c1f7c1f7c"},
    [202]={"7b6f1f7c5400f8005b013f022529c449695eed6e53771f7c42084a291042ff7f","7b6f1f7c5400f8005b013f02ed2c1345795dfd659f6a1f7c42084a291042ff7f"},
    [203]={"3957ff7fc8104b1daf1d542a3a47370add1a7f23df3f4208bd39bf5e56731f7c","3957ff7fc8100b156f19f321b936370a7c161e1f9f2b42088a72547f56731f7c"},
    [204]={"395742081f7c1f7c1f7c1f7c253dc751aa5a506bb67b93523f1d1f7c1f7cff7f","395742081f7c1f7c1f7c1f7c0b217229352a1c379f4393523f1d1f7c1f7cff7f"},
    [205]={"395742081f7cac2c3545185edc727e771f7c1f7c5018b7209e39ff661f7cff7f","395742081f7c4e1976261b379e47df4f1f7c1f7c0a112d1936221b331f7cff7f"},
    [206]={"395742081f7c4445a95e306b77736b2d3146386b6d153712fb1e9c43de63ff7f","395742081f7c1425bb3d9d525d636b2d31465d636d153712fb1e9c43de63ff7f"},
    [207]={"39576b2d524a0b3d6e51166afb7e7e7fc3386249295e0c777a1d5f364208ff7f","39576b2d524a073d8a55706a167fbb7bc330044568596a6e7a1d5f364208ff7f"},
    [208]={"39571f7c1f7c1f7ce728693d705637639b6f1f7c1f7c1f7c1f7c5a214208ff7f","39571f7c1f7c1f7c4c1db129772e1c3b9f471f7c1f7c1f7c1f7c5a214208ff7f"},
    [209]={"7b6fb4141f7cb21c9c35dd523f631f1642080829cc3992522856757b7b6fff7f","7b6fd8201f7c6b45725238637b6f5f264208cf203331b94528561f5b5d63ff7f"},
    [210]={"39571f7c1f7ceb289349da697c76fd7e1f7cf0001c434208e6206a2d944eff7f","39571f7c1f7c4c21d22db9423c577e5f1f7c4b01f9364208e6206a2d944eff7f"},
    [211]={"395742081f7c1f7c1200273169510b62ae764d19d82a7c3bfd535a319f4aff7f","395742081f7c1f7c1200ec2cb2405751db5d0e31375afc6e7f7b5a319f4aff7f"},
    [212]={"3957ff7f1f3b9f09f9008f001f7c3f0b3f1637161f7c1f7c1867524e6b354208","3957ff7f9b33f622cd2149091f7c3f0b3f1637161f7c1f7c18670c2be6114208"},
    [213]={"39574208123a4e0937161d27ff2f1f7c7c423e5b1f7c9000f808de1ddf3eff7f","39574208123a4e0937161d27ff2f1f7cf45e576b1f7c0339865d6876317bff7f"},
    [214]={"3957ff7fd37e2f6eac59e6301f7cff477f2f9816b1011f7c5a6b734ead354208","3957ff7f7d6af95d544dec301f7cff477f2f9816b1011f7c5a6b734ead354208"},
    [215]={"3957ff7fb14eea356725e5143f6bdf35382550103c258d3dd7629f2f19024208","3957ff7fbf663d5a9841cb20ff539f27db32931d3c258d3dd762ff7f79774208"},
    [216]={"3957ff7fdd367a2e141e8f0d0b01df535d4fba2a1f7c1f7c7b6fd65ead3d4208","3957ff7fd73f7437cf264b1a8711df537d3f152f1f7c1f7c7b6fd65ead3d4208"},
    [217]={"3957ff7f1b3b982a141e8f0dc900df535f3fba2a16161f7c7b6fd65eef454208","3957ff7f94233017ac0a28024701df535f3fba2a16161f7c7b6fd65eef454208"},
    [218]={"3957ff7fff361f267b1192005f3bbf4f5f3b9e021f7c1f7c1f7c1f7cad354208","3957ff7f5a6bd65aef3d29259c73bf4f5f3b9e021f7c1f7c1f7c1f7cad354208"},
    [219]={"3957ff7fff361f267b1192005f3bbf4f5f3b1f03b42db55610428c3108214208","3957ff7fdd76596295550d45df769f7fdf76df7631359a25531dcd14a9084208"},
    [220]={"3957ff7f1b3b982a141e8f0d0b01a700ff423b2a96151f7c7b6fd65eef454208","3957ff7f9b7337639252ed41072dc61c5e439b22f9111f7c7b6fd65eef454208"},
    [221]={"3957ff7f1b3b982a141e8f0dea001f7cff423b2a96151f7c7b6fd65eef454208","3957ff7fbe4f5b3bd72e321eea001f7cff423b2a96151f7c7b6fd65eef454208"},
    [222]={"3957ff7f7b6fb55610466b315f6fbf62bc45f72c51081f7c1f7c1f7cf72c4208","3957ff7f997ff46e4f5e894db37f2f7f6972a56101491f7c1f7c1f7c9d314208"},
    [223]={"3957ff7fda7b766bb15e2c52273d11001f7c1f7c1f7c5a6bb55aef416b2da51c","3957ff7f5e7bdb72f5595045ec3411001f7c1f7c1f7c5a6bb55aef416b2da51c"},
    [224]={"3957ff7fdf36be19fa0810001f7cff575f2b7a1672015a6bb55aef416b2d4208","3957ff7ffc2e7822b20d0a191f7cfc57992bb4168c015a6bb55aef416b2d4208"},
    [225]={"3957ff7fff36df091a01d2001f7cdf473f2339160f016b2d5a6bb55a10424208","3957ff7f1d6279511239ab281f7cdf473f2339160f01f129bd633a47322ec618"},
    [226]={"7b6fff7f926aab450531a3241f7c997f367f93629e7b3c73fa665452ad354208","7b6fff7f34776f768961c2481f7c997f367ff36adc7f997f3577916649394208"},
    [227]={"3957ff7f9c7718679456ef414a297f3e9e29f81892007f0359021f7c1f7c4208","3957ff7f9d63f852323ece316a254e27a916a51126117f0359021f7c1f7c4208"},
    [228]={"3957ff7ff13d2a25c71885105f479d2af71d520dbf19d6041f7c1f7c96524208","3957ff7f8f62ea51473906299f63ba4a152e4f21bf19d6041f7c1f7cfb624208"},
    [229]={"3957ff7ff13d2a25c71885105f479d2af71d520dbf19d6041f7c1f7c96524208","3957ff7f6f7289590645282d9f63ba4a152e4f21bf19d6041f7c1f7c1b6b4208"},
    [230]={"3957ff7f777bf37a695e29411f7cbe29f718ff4f9e27bc1eb5015a6bef3d4208","3957ff7f1d77ba72d3590d3d1f7c300f6a0eff4f9e27bc1eb5015a6bef3d4208"},
    [231]={"3957ff7f5577f3764c624a491f7cbf46be29f71810001f7c1f7c5a6b31464208","3957ff7fdb7f977fcd7288591f7c9f3e5f21d81c10001f7c1f7c5a6b31464208"},
    [232]={"9c67ff7f14636f4eca3946297c6b3a679552f03df82df2147b6ff75e6b2d4208","9c67ff7ffe365a2a531d2d197b5b394f733ace29f82df2147b6ff75e6b2d4208"},
    [233]={"3957ff7f5f575f469b2996081f7cb27f2d7f886ee461c04c5a6bd65ead3d4208","3957ff7fcf7ee8794365c04c1f7cbf773d779862b1490c395a6bd65ead3d4208"},
    [234]={"3957ff7f5f3bdc2e161a0f011f7cff577f437f2b9c121a7cd65aef3d29254208","9c73ff7ffb37982fd21a68011f7cff579c477f2b58221a7cff36dc1510154208"},
    [235]={"576bff7f63027b5fb546112a1e0216006d19e9086d23080f80011863524e4208","576bff7f38217d4fb932d6251e0216000d11e9087f42bd29d5141863524e4208"},
    [236]={"3957ff7f7f7fbd7e1966954dd02c3c229915d6000e003c22d6005a6bb5564208","3957ff7f9d67195753428d2d4b21ca7e2872465904413c22d6005a6bb5564208"},
    [237]={"3957ff7fbf4f3c3f972a90091f7c517fac7609666a491f7c3967524e8c354208","3957ff7fdf677c5bb64a70211f7c5e6eb95d3551ce3c1f7c3967524e8c354208"},
    [238]={"3957ff7fb7165f523b3d512c9f2b3b1b120e1f539e571b4311265a6bd65a0000","3957ff7ffa0eff6a3c3e141dff579f27550a7f73de671a47112618631042a51c"},
    [239]={"3257ff7f9f4f1e27bc02b6014f015e0ad3004e001f7c39679452ad35c6204208","3957ff7f9f2b3d23770ed2014f015e0ad3004e001f7c396794528e19c7104208"},
    [240]={"3957ff7f1f43ff315a1dd2101f7cff5b5e1fba0215021f7c1f7c1863ce3d4208","3957ff7fdf3b5f171c1a12111f7cff77df4b3d2ff8211f7c1f7c1863ce3d4208"},
    [241]={"3957ff7f5f6fbf52fa3931259f4f1d3f782ab211407d94526b2dc6186310f630","3957ff7fde77bc77b35e8b41ff7f5b63753ab125407d3a19f1106b08650cbd39"},
    [242]={"3957ff7f7b6fd65aad35e0035f6fbf62fd4d3a319718e003e0033a3155104208","3957ff7fbb7f166fab41e003bf7b5f73be62db453629e003fd4d7b31d5204208"},
    [243]={"3957ff7fbf4b3f237a169109da7ed67daf6c484818001f7c5a6b9452ad354208","3957ff7f5f2b7e1ab8052a09ff4b9d27d7168d0118001f7c7b63f6520f364208"},
    [244]={"3957ff7ffb3256269011ea00ff15bc0013009f4b3f035a025a6bb5568c314208","3957ff7f9d3afa293319ce14b45eee4508255f573f035a025a6bb5568c314208"},
    [245]={"395bff7fb77fef7ecb692749da7eb57dd170ea4414005a6bd65a524aad354208","395bff7ffd7f987f8d72464ded7e276e6159e43014003a73b762f1494c354208"},
    [246]={"3957ff7fb863765baf3e89251f7c9f2e5d15f7108d001f7c1f7c18638c314208","3957ff7fdc2b7927b316cb011f7c7c569741f230ab201f7c1f7c18638c314208"},
    [247]={"3957ff7f977f11776e6265411f7c1601396bb556ef411f7c1f7c1f7c08314208","3957ff7ffe7e7a72b35d0c391f7c1601396bb556ef411f7c1f7c1f7c08314208"},
    [248]={"3957ff7fb86354538e3a471d1f7ccc7e6972e45d20455a01b2001863ce394208","3957ff7f5e4bfb3e352a2d151f7cbd6a5a62944dcd305a01b2001863ce394208"},
    [249]={"7b63ff7f7b73f762735a8c318f7acb7d805d00417d011301735a8c3142084208","7b63ff7f9a7f1573706269453f56be49393d0d297d0113013e467b3192144208"},
    [250]={"3953ff7fbf027f0119015300bf439f03bc02b401d357482b420a1863ad354208","3953ff7f9f1fbf0ef90d3219bd777b6fd65eef45bf023f01b30c5a6faf214208"},
    [251]={"3957ff7ffd6bb8534f3be8222412ff7fb57fee72276680591f7cd65ecd414208","3957ff73bf733f639d4ebb41f520ff7f77774d2fc92245169b6cd65ecd41c618"},
    [252]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [253]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [254]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [255]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [256]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [257]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [258]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [259]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [260]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [261]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [262]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [263]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [264]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [265]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [266]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [267]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [268]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [269]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [270]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [271]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [272]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [273]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [274]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [275]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [276]={"e003ff7f0000ff7f000000000000000000000000000000000000000000000000","e003ff7f0000ff7f000000000000000000000000000000000000000000000000"},
    [277]={"af4d5f3f1f2b7c26e942bf295a1d3419031d292eff7ff73b5327ae1a8a154208","af4d5f3f1f2b7c26bf29bf63fd4e793e13155a1dff7f9577326b894a2a424208"},
    [278]={"58424225cb36914bf75b0722b0181c15df297f2b074a17213a2a8a5e0000bf7f","58423219894a326b9677e839793efd4ebf637f2b5a1d16323a2abf290000bf7f"},
    [279]={"af4d9f371f2b181ebf5bbf295a1d341987118f2dff7ff73b5327ae1aeb114208","af4dbf295a1d3419bf5b9f37df2a181e87118f2dff7fd77f7473cb522a424208"},
    [280]={"862a7f4bfa4a563ecf3d5f331f2b7a1ef12d337fff7f9f1ebf1d7a1deb184208","862adb42f52d6f25cf3d9f1e7d15f70c6f25337fff7fbf577f3b9c26eb184208"},
    [281]={"862a7f4ffa4a563ef31d5f33de2a581eaf2df118ff7f9f1ebf1d7a1deb184208","862aff7fdb42f52d6f25bf575f337d1aaf2dad10ff7fbc193819f118eb184208"},
    [282]={"124bdf7bd95a554ad23dff299b191619a9205d57d94ef22d9f4f5f37bc2e0000","124bdf7bd95a554ad23d5819d0106d0409009d6f5b671619ff7fdf2afb190000"},
    [283]={"862af67ab36e715acf3ddf2a7e221922f42d387fff7f0f7fab72066229414208","862abf4f3f37bc2e7a26df2a7e221922f42ddf63ff7f7b76d86d514dcd3c4208"},
    [284]={"862a7b7f1877b56a104e9f2afe1d9911f42dff7fb577526bed5e4c4e6b394208","862abd7f5a77f76a524e9f4fdf22190ef42dff7f3e7bbc7af971b355cd3c4208"},
    [285]={"862a987ff5729062c5305f277e2219229125332d4741317fab720662aa514208","862adc7f5973367209351f27be299b191619110dcd3c3e7bbc7ad86d514d4208"},
    [286]={"0e533a6f9f439f3e6f297456f0454931c620f8665f2f362e3b21f520ff7f0000","0e539f5b116b9f3e6f29ba26b2212e15aa003f37af7627413b21f520ff7f0000"},
    [287]={"875200000000b55a324e4935c62084149b77386b1f2ff52dfb1c5408ff7f0000","8752000000003f37ba26f429701dec08bf577f3fff7ff52d8955e638ff7f0000"},
    [288]={"f3420915f52d793efd4ebf63e8186d25b8465c57ff7f9400f910543e6f250200","f342091598211b269d26bf63c614ec14b8465c57ff7f9400f910543e501d0200"},
    [289]={"ae3ae8109121353ab9465c630000d02dd84a5b5bdf7b47412f6ebf5a1f67bf7f","ae3ae81098211b269d26bf630000d02dd84a5b5bdf7b371a3f37bf5a1f67bf7f"},
    [290]={"18634c29964eff7f5c77592dfe31fe465c775b53ff6b5202de03182f0000630c","18634c29964eff7f5c77544517529b625c775b53ff6b5202de03182f0000630c"},
    [291]={"d863ad39314ab55a0000f7665b73bd73ff7f420c9e02f8010000fe630000630c","d863b40d59229c2e0000ff2e7f4bdf63ff7f420c0b5e68450000fe630000630c"},
    [292]={"127b6b29313eff7fb5367c3bff1bff63733a183bbd5bff7700005f16137e6300","127b6b201341ff7f5536be4bff6bff63783a1c3bbf5bff7700005f16137e6300"},
    [293]={"d8638d39314ab55a0000755edb725d739d7f0e001e03d7005202fe630000630c","d86386094a0ece1e000031279533fa4bfd570e001e03d7005202fe630000630c"},
    [294]={"527e2b255042d34e0000b6495a621c6b563bf84b572abd1b191b5e195819630c","527e2b259221f52d0000b6495a621c6bbc2e9f4f572abd1b191b5e195819630c"},
    [295]={"862a5f27ba1ed119062d4f27ec1aa91629162611f53fd26e2a66c649ff7f4208","862a5f27ba1ed119062d1267ad5a6b5208464331f53f3a4eb63d322dff7f4208"},
    [296]={"ff7fac214b36321d104b975bfb6339195022d11a551fdf21d92bff7f18673f1c","1867ac214b367515551fd92bfb63ba1d08466b52ad5abf2e1267ff7f18673f1c"},
    [297]={"4c62a9252d2e1333b42ff947de4b5a3fd63aff7f396f183a9e32b129da26a514","4c62c6352a426b4a1267746f9f4f5f37bc2eff7f396f183a9e32b429da26a514"},
    [298]={"ff7f4a11f039ff7f73195a1ada2a4f2a3643bc5b1e33bf57000000000000fe00","ff7f4a11f039ff7ff8145c113f2a3246b6565b6b1e33bf57000000000000fe00"},
    [299]={"467ae9203977ff7f4f2a3643bc5bf34d79321c4b0c43b243c81d4d310000630c","564fe9203977ff7f16199b19ff296e2df33d974e0c43b243c81d4d310000630c"},
    [300]={"4662ca18103aff7f0e257331fb291e437c7fd7620000e915ac3250335f330000","4662ca18b529ff7f4e00d6109b193f32bf4fbb2600000b1a312bf73b7f2a0000"},
    [301]={"d03a5c6b99363532d32910378c362e1dbe73e92df95ab64a333ecf314b29a514","d03abf5399363532d3295327ae1a2e1dbe738a155f37bc2e5922f6157005a514"},
    [302]={"d03aff7f5e2bbb2ab121be09f610f01c3b095a67d55a514aef3d6b3d082d0000","d03aff7f5e2bbb2ab121be09f610f01c3b095f375f37bc2e5922f61570050000"},
    [303]={"862a1a23961e141ad1152a150000000000006e159e33ff7f7b6ff75eef3d4208","862a9f5f1e4f9a3e162eb12500001f7c1f7c4f1ddf73ff7f7d77da62b0414208"},
    [304]={"b032c52c6949ab552f666f2d524a596bff7fd818bc315f46fc26bf2bf0280000","b032421d4632ab4a52676f2d524a596bff7ffa09de1e1f3bfc26bf2bf0280000"},
    [305]={"b032c52c483dab552f666f2d524a596bff7fd818bc315f46bc26bf2bf0280000","b032421d4632ab4a52676f2d524a596bff7ffa09de1e1f3bfc26bf2bf0280000"},
    [306]={"52462c19b2199a2e1d479f57ff6b0b26af361143544b4819154300000000ff7f","52468f25f521fb3e5e53bf5fff7316199b19df25ff36d410bf3200000000ff7f"},
    [307]={"bd77ff7fbf4f5e3fba366a082c1d470d142a5533f2264e1afd25d50800003b15","5246ff7fbf5b9f4bfc366a082c1d470d572adf259b1916197f473d1a0000df2e"},
    [308]={"862a9e575c53d84255363b26bb1d7615f30c0e09152dff03ff038f250b194208","862a9e575c53d8425536162f921e0e0e8a010601152dff03ff038f250b194208"},
    [309]={"337fe71c31465b7ff872be7f46451b02bf1a7109ca718e7e8c31000000003f37","337fe71c70521b7bb972be7fa5151b02bf1a71096b1e2f2f8c31000000003f37"},
    [310]={"f0467021bc2e5f33bf4f4a2d5273675aee6a7b77de7f112d371e00007356843d","f0467021fd2e9f37bf5f4a2db33f6b1e2f2f3c7fde7f112d371e00007356843d"},
    [311]={"ff7f662d8b6a2b5a0f6b5f2fb91aaf09ff7ffd45bc2d350ac449ff7fff7ff94f","377fc520ae3d4931324e5f2fb91aaf09ff7fdf2adf0d350a4931ff7fff7ff94f"},
    [312]={"ff7f082d92623677b8772d11391a7f267b67ff7f4b0410115504fb10ff7f630c","ff7fe625cc32924bf9572a11ad19543a7b17ff174b0410115504fb10ff7f630c"},
    [313]={"b02ec424a64d095a6c66bf675d53d942000033321277473d8d25304ef662ff7f","b02eaa3cb25d366eba7ebf675d53d942000033323e7f2e4d8d25304ef662ff7f"},
    [314]={"12639d7f3a6fb65a7656d041b27e0a7e867d4561e62caf312a250000367f453d","12639d7f3a6fb65a7656d0411c7fba7e156a7055aa3caf312a2500007e7f2e4d"},
    [315]={"5a6bff7fdf4b3f337922b021000000003f5fb8590f340000bf4a1f36581db018","5a6bff7fdf537f3b9a22b02100000000df32bf256e100000ff295d191711d410"},
    [316]={"3547ff7fff4f7f33ff227b222e29de62172e2d4da93c00005b52f8457435f024","3547ff7fff5fff4f7f33be225121df32f91db1550c4d0000ff295d191711d410"},
    [317]={"f37f88212a2ecc424f47b44fff7f311d7721bd25b8261b2fbe3ff12d153f0000","f37f88212a2ecc424f47b44fff7f0662ab720f7f7d26df26ff5bf12d153f0000"},
    [318]={"ff7f4c291032ff7f932218339c571b315e2a000000000000000000000000e003","ff7f4c291032ff7fd91e7e339c57ab36ee56000000000000000000000000e003"},
    [319]={"ff7f4a15ad21723e8c0d535e186bff7f1f53fe2d75015f3b963eff7fff7fed37","ff7f4a15ad21723e8c0d535e186bff7fbe2f3e1f780a5f3b963eff7fff7fed37"},
    [320]={"ff7fe7281863cc3d5052f25a576ff10c790d3e161f53ff7f492900000000630c","b66a2d1d18634d193522db265e3bf70c7c0d3e161f53ff7fea0c00000000630c"},
    [321]={"12637d6b3a63b7527f36fc25581d321910426b2dc6187f021806ff00cb1c0000","1263bf735b67f95a9f4f5f377b267201fa3d762d8f107f021806ff000a000000"},
    [322]={"2c67c9249145f85d5a6a126a787fff7fb8102d39d5662a23647fd45100005f25","2c674e21501d9a3e1e535c2e9f4fff7f4a272d1d9c2e647f9f37f62d0000f24b"},
    [323]={"742e0729ce419456f7625a6fdd7b00007877ff16694dab59cb65916e147fff7f","742e0729ce419456f7625a6fdd7b0000df3fff165001d401580edc1e5f2fff7f"},
    [324]={"742e00008a49cc512e5ad26e9b1e5f27b57f2739b11950561073ed6e707fff7f","742e000007294931ae3d324e9b19ff29b57f2739161950561073ed6e707fff7f"},
    [325]={"2c4bee18b429ff7f3b737c42594a9f3e5e4b8b5d8b450000000000000000630c","2c4bee18b429ff7f3b731e1bbe0a9f2bff438b5d8b450000000000000000630c"},
    [326]={"3957ff7fff097a0555050c19be633c4bb936d2215f2fdd221f23396710420000","3957ff7f5f4aba353625b114ff777f4bff2e5a225f2f3f671f63396710420000"},
    [327]={"3957ff7fbc011701f110be633c4b9832d2219f2fbe1a6a7ac855187303350000","3957ff7f5d02b9013311bd777b6ff65a3042bf471e177b76745d7b760f450000"},
    [328]={"46322b1d963a5a43bd4f8e163433122ab635fc314a39b462797f7c73ff7f630c","46320c25354ab95a3d6b8e163433b139b635fc314a39b462797f7c73ff7fa514"},
    [329]={"de4bee18b429fb4e5f5b9f6bb262117f9a211d2e56211c469f428d3dde770000","de4bee18b429fb4e5f5bbf6f1b039f137266f6768b491c469f428d3dde770000"},
    [330]={"136aa52c157f2c1d264de85d8c6ef71cfe1c1f425916fd163f2bef1c0000ff7f","136aa52c157f2c1d6f0ef31e772f4642ca524e635916fd163f2b80290000ff7f"},
    [331]={"f34f0725883d284af25efa41fb227f33755a3b7b9d7f332ddd0cff7f0000ed24","f34f0c2810385448d858fa41fb227f33755a3b7b9d7f332ddd0cff7f0000ed24"},
    [332]={"374f0e21f9397d26ff3e38191533db3b4f260000000000000819ff7f00008410","374fc3140b3e8f4e135f38191533db3b4f260000000000000819ff7f00008410"},
    [333]={"124bb15b0c4b2632ff535c47d73e7b7ff76e3967cf1d0000945210424a29ff7f","124bdf3efe25580dff535c47d73e7b7ff76e3967cf1d000094521042ad35ff7f"},
    [334]={"124ba90dd3186f22662dfa43753bf332524f8d3a0b2edf5adc39d9180000ff7f","124ba90d51016f226145fa43753bf332ed766966e5551f2b9b1a170a0000ff7f"},
    [335]={"124b7352104a6b39e62c5f2bfd1a792a7f255921532100009f3f6f1d0000ff7f","124b7f2559215321cf109f4f3f339c2a7f25592153210000df5f6f1d0000ff7f"},
    [336]={"8e3a9e635c53b83ab1299d361a2e952130198c49c6305e3bfd2a7922630cff7f","8e3abf573e43fe2a391efb627752b3414e2d8c49c6307f2559215321630cff7f"},
    [337]={"187b48212a2ecd3e7343bf135a0f1523d21cfa18000000000000ff7f386f630c","187b2941e65d6b6a0f7fbf1358331523d21cfa18000000000000ff7f386f630c"},
    [338]={"186307256a410e62b176ff279b371637f1219508000000000000ff7f1873630c","1863a51c0729ae3d324e7f431c33782ef41daa61000000000000ff7f1873630c"},
    [339]={"527a8d117e03d91e3b13de535a4bbf37720fd61b8e1ecb35522a7c77ff7f630c","195b90251d4f7832993ede6b5a577f57ab720f7f0662892d10227c77ff7f630c"},
    [340]={"ad4d630cca0c5715bc0dbd262945105ed75e0000f735bd675a43b52e2911ff7f","ad4da50ca51c0729ae3d324ebb26df3b5b6f0000381eff7ffd4e583a2e19ff7f"},
    [341]={"0c33421c4945ed69937e187fff7f6d1954361a4b5c579e5f7b7f000000000000","0c33421ccb4496655a761e7fff7f6d1954363c4b7d57bf5f7f7f000000000000"},
    [342]={"2a2a4739a8514d6ab17e0000735af76a7b7f773eda4a3d57eb49377f9f5fff7f","2a2acb4496655a761e7f0000735af76a7b7f572afc367f533359bf7fdf63ff7f"},
    [343]={"cc49463dc7552b62d072142e1f337f43ff53d8181d42cf7e386f00009b7fff7f","cc492a3d745d186edc76142e1f337f43ff53d8181d42cf7e386f00009b7fff7f"},
    [344]={"bf32b93b3533b12a2d22fc4f2f37691ec81510424615bf7f5f277722bf4b4208","bf32fd2e791ef50d71017f3fb91d350db10010426900bf7f5f277722bf4b4208"},
    [345]={"bf32563bf332902a2d220c37aa32882e0626cc254715b93b9f27d1394a2d4208","bf32fd2e791ef50d7101b91d350db1002d00ed0069007f3f9f27d1394a2d4208"},
    [346]={"7b6f7b6fff291619d619bf535f37bc2e517f3346486af13d2a25c7188510ff7f","7b6f7b6f3f2b161a9209d57f517fcd6e1f5b3346ff14f13d2a25c7188510ff7f"},
    [347]={"3957ff7f9c7b396f945eef494a35347f8f7229621f7c396b9456ef414a2da51c","3957ff7fdd7f9a771667925689355f2e3c2139141f7c396b9456ef414a2d0000"},
    [348]={"862abf535c4b1a43b83e75361332d1298f252c1dea147d2d3a29f724d4244208","862abf535c4b1a43b83e75361332d1298f252c1dea144c7ec86d445dc04c4208"},
    [349]={"862abf535d3bdb26562a5d1ef919951551118f25a70cbf323a29d1394a2d4208","862abf535d3bdb26562adf351f1d9b0c17008f25a70cbf32207fd1394a2d4208"},
    [350]={"ff7f062d4d7ec97df37eef49fd393721675d9b2dbb7f0b7a6749ff7fff7f0000","f37ea429924bcb3ef9571f7c9b19161968329b2dbb7f2f431f7cff7fff7f0000"},
    [351]={"fa7fb552314acd3dc6149f7f3f5fbc423225382e630c00002925ff7f4c290000","fa7f3f57de46993e2c1db55631464a29c618ad3500000000f535ff7f4c290000"},
    [352]={"124b524aef3d8c312925df6a3d56ba41bc76396ad65d4f4533313e7f0000ff7f","124bb55610424a29e71cdf6a3d56ba417e37fa229716f0013331bf570000ff7f"},
    [353]={"862adf6fbf635d43b742cf297d3a9b2571195d1dc5208c390831524a0000ff7f","862adf6fbf535f37592a51097d19d90452009408c5208c390831524a0000ff7f"},
    [354]={"862adf6fbf635d43b742cf296c7eeb7166415d1dc5208c390831524a0000ff7f","862adf6fbf535f37592a510912672a42c6355d1dc5208c390831524a0000ff7f"},
    [355]={"5a6bff7f39671a569745333500007f471f2f7a26f31d00001863945210424a29","5a6bff7f3967ff299b19161900007f471f2f7a26f31d00007d62f9517441d02c"},
    [356]={"f146ff7f9d731963f23d1f367c1d1619f62cae200000787ff17a4c66c9556939","f146ff7f9e77fa66d43d1f363f1e1619f62cae2000001f367c1d1619f62cae20"},
    [357]={"5147ff7f7f4afc3d79294f2500003436945210429f433f2fbd6b5a63f756313e","5147ff7ff17a4c66c955693900003436945210429f433f2f3d53bc46593a6f25"},
    [358]={"af3ed66e104a6b39a7415a73000073622f7fac724b66fa7f1263957fbd7bff7f","af3ed66e104a6b39b3015a7300007362bf433f33bb22fa7f1263bf43bd7bff7f"},
    [359]={"2e47ff7f104a186b9f429f219004557fce762c62a84ddd7f7b77d562e52c0000","2e47ff7f104a186b9f429f219004bf433f33bb22b301dd7f7b77d5622f010000"},
    [360]={"58322529695eed6e5377d4207b31e81cf03d8d313963ff7fe751af1c0000d953","5832ed2c585dfd659f6ad4207b31e81cf03d8d313963ff7fd62daf1c0000d953"},
    [361]={"8f56e718ad2d313ed64a9d5f5b57ff730921953e9f566b290000312d5d0dff7f","8f560b00b3083719bb299d5f5b57ff730921953e9f562f000000312d5d0dff7f"},
    [362]={"ff7fea186b35ff7f8d2d313ad652123e1a5bb54a000000000000ff031f00630c","ff7f0b1d9100ff7fb3083719bb29123e1a5bb54a000000000000ff031f00630c"},
    [363]={"124b0000b63b5e27796b881970524c262f331563d4247e419f5e65494a6acc7e","124b0000f73b5e27bf578a15ba2eae1a53275f370f459665396ec520ae3d324e"},
    [364]={"51660000ea144e15b1210821734e3967ff7fd1207725fa359f465636d9463c53","51668510c7182a25b3450821734e3967ff7fb30c16199b19ff297341f855fc66"},
    [365]={"e9510a11ce184e15b121082110423967ff7f112dfa189f319c7315326b290000","e9510a11ce184e15b1210821592a5e3bff7f35015c0d9f32bf4f15326b290000"},
    [366]={"6e520b19b1293536b84a3a5bbe6b8b3d3977bd7fff7fd12058391b4a0200ff7f","6e5209198d25f135b84a3a5bbe6b17221f37bf4bff7fd4105a15ff290200ff7f"},
    [367]={"ec42a91d903a744bb85bf3460821ad35734e5526b90a7e2fbf535f3e00000000","ec42a91dec51d076537f4c620821ad35734ed41016199b193f2a5f3e00000000"},
    [368]={"683e6e49b369377eba7eff7fc6184a29ad353967f0215f2fbf00bf4beb340000","ec422839cb4d4c62d076ff7fc6184a29ad35396716199b193f2a5f3e00000000"},
    [369]={"e25d8411a7226f47d74f2d15d419372a9936fd1eff37ff7f0000bc4554350a2f","e25d66014d025513d9232d157b06fe167f27fd1eff37ff7f0000bc455435d102"},
    [370]={"3957ff7f9f765d6abb5d5745f1302e0c5f3fbe1e7a02d40d5a6f73526b350000","3957ff7f3f67bf62fd4d7b39d7202e0cf957924bee3a282e5a6f73526b35a51c"},
    [371]={"3957ff7f746ecf594b45e7347f2f9a0ed30ddf293a19f30ccd0c3967ce390000","3957ff7fdb62175273451035df431f1b1a0adf291819b30cef003d6bce39c620"},
    [372]={"3957ff7ff776746ecf592a457f2fdb26d30ddf293a19f30ccd0c7a7f10420000","3957ff7fba5e7752b13d4e2dbf571e2bbd0e3f2a5a19d40c2e011b6f1042c724"},
    [373]={"d24fff7f596b914a587bf166294205412c7a6665a028ef7e0000ff69da412e2d","d24fff7f596b914a587bf166294205411859323ca0281b6600009f4fbc2e2e2d"},
    [374]={"a65dff7fdd325b02b321b677737b0f6f695a863d00001f4ad949f22c1a6b144a","a65dff7f7f3b7c02d421f557924b0e3b472aa41d00001f4ad949f22c1a6b144a"},
    [375]={"1263ff7f7c6bf9563f67be5e1d569a49322d7041ec34af310000d97db5697255","1263ff7f7c6bf956df5b7f33fe267a16b2117041ec34af310000d97db5697255"},
    [376]={"6f5aff7f7b77186b5256ff39b910af18b56610566b41e51c92520e428a310000","6f5aff7f7d73fb6a785ec67ec05daf18b56610566b41e51cd9315521b00c0000"},
    [377]={"0c63092512469456f562cf3d4d7bea6a5e1bd702cf224d22000000000000630c","0c632629e741ac5a316bc63d4d7bea6a5e1bd702cf224d22000000000000630c"},
    [378]={"9a6bff7fff1b9c0eff1adc18fb1977091015ff1bff1bf7665256ce4529310000","9a6bff7fff1b9c0eff1adc18fb1977091015ff1bff1b3777b1664b56443d0000"},
    [379]={"1263ff7fc7189f2ffb22b158ff567d29191df0218510f13d2a250000d47ccb20","1263ff7fc718f93b752bd634ff560b5a6745ea098510f13d2a2500005a45cb20"},
    [380]={"1263ff7f7c73b75a12466d319f35793511299f4a3a72af311a6700009665ef40","1263ff7f7c73b75a12466d3106622941e738ab72ff29af311a6700009b19d610"},
    [381]={"cc7f7e5bfa4a5636d1254d21975200003442d1358f2d0a1d7e211919df6ff129","cc7f7e5bfa4a5636d1254d21957b0000116b8d5a094a43317e211919df6ff129"},
    [382]={"b24e2921ad353146b556e720af353346b7563b67ff7ff524bb351f42ed7e0000","b24e642de8396b4a1267a90cef2d733ef74e7b63ff7ff524bb351f42ff290000"},
    [383]={"b24e2921ad353146b556e720af353346b7563b67ff7ff524bb351f42ed7e0000","b24e642de8396b4a1267a90cef2d733ef74e7b63ff7ff524bb351f42ff290000"},
    [384]={"b24e2921ad353146b556e720af353346b7563b67ff7ff524bb351f42ed7e0000","b24e642de8396b4a1267a90cef2d733ef74e7b63ff7ff524bb351f42ff290000"},
    [385]={"184b4b29f95e7c6fde770000ff7f7b7b0000000000000000524a4925ff7f630c184bcc147925fd257f220000df375c377f321a2672213a7300006b29ff7f630c184b072dcc5d2e6ad2660000b97b166f316fd0628a411863324a6b29ff7f630c184b451d4f5dd169d2660000d87e736231578e462c399773ca354925ff7f630c","184b6c2d995e1c6f7f7f0000df23dc120000000000000000524a4925ff7f630c184bcc147925fd257f220000df375c377f321a2672213a7300006b29ff7f630c184b072dcc5d2e6ad2660000b97b166f316fd0628a411863324a6b29ff7f630c184b451d4f5dd169d2660000d87e736231578e462c399773ca354925ff7f630c"},
    [386]={"124b7b6f314a292900001e3a5c31f928d1249f2bfb2a2c19d4622f524935ff7f","124b7b6f314a292900000f7fab72066229419f2bfb2a2c19396e545d8828ff7f"},
    [387]={"862a6069ef3d29250000396e9665514da6189f3bdc26132a1577b166ab45ff7f","862a6069ef3d292500009f3bdc26372aa6185f2a7b11d410307fab72c45dff7f"},
    [388]={"39575f479c6ed655113d6c24bf36fd1d9709df3f7f17bc025a6bb55ace390000","39575f47b2672e57aa46e42dbf36fd1d9709df3f7f17bc025a6bb55ace39a51c"},
    [389]={"3957ff7f923fce360a2e67255f57bf3abe11df3f7f17bc025a6bb55a56250000","3957ff7fdf5efb4d773d11215f57bf3abe11df4f9f17bc025a6bb55a56250000"},
    [390]={"3957ff7f3557b1462e3acb2dbe633c4b98325225ff295b117b6fd65ead3d0000","3957ff7f5f57dc465836d425be633c4b983270115f255b117b6fd65ead3da51c"},
    [391]={"3957ff7ff76e315ece556b45be637f37db3207299f25f7007b6fd65ead3d0000","3957ff7f1e5f9a4e163e922dbe637f37db320e1d9f25f7007b6f9b29f6140000"},
    [392]={"932abd7f386fd466505a4f29ae1c7f425c1d307fff7ff957924bee3ae6254208","932abd7ffa6e9666135a4f29ae1c1f2f1c12307fb87b977f0f77aa6ac43d4208"},
    [393]={"932abd7f386fd466505a4f29ae1c7f425c1ded49ff7ff957924bee3ae6254208","932abd7ffa6e9666135a4f29ae1c1f2f1c12ed49b87b977f0f77aa6ac43d4208"},
    [394]={"932abd7f386fd466505a4f29ae1c7f425c1d307fff7ff957924bee3ae6254208","932abd7ffa6e9666135a4f29ae1c1f2f1c12307fb87b977f0f77aa6ac43d4208"},
    [395]={"18332931cf49ef6db57e18325f325f32504a955e5b77ff7f00000000ff7f630c","183382116c360c33924b18325f325f32504a955e5b77ff7f00000000ff7fa514"},
    [396]={"d24b091d6c25ef310000ed1c7711de254a39325a3967bd67de031803d65e630c","d24bc7142a1dad290000ed1c95005e11c021491e375bbb67de031803d352630c"},
    [397]={"753307318a49ef6db57e2f19d725fb295f32504a955e5b77ff7f0000ff17630c","753382116c360d37924b2f19d725fb295f32504a955e5b77ff7f0000ff17630c"},
    [398]={"862a3967b556324aae397b6f3025bf353a29307fff7f8b7e096a8759e6384208","862abd2a391ab50931013f3b1321bf353f29bd7bff7f5a6f9456ae392a294208"},
    [399]={"862a3967b556324aae397b6f3025bf353a29307fff7f8b7e096a8759e6384208","862abd2a391ab50931013f3b1321bf353f29bd7bff7f5a6fb55acf3d2a294208"},
    [400]={"862a3967b556324aae397b6f3025bf353a29307f787f8b7e096a8759e6384208","862abd2a391ab50931013f3b3025bf353a29bd7bff7f5a6fb55a11466c314208"},
    [401]={"0c4b2a15323a19577c579d6fb64a711d171e1d1ebd36000000001601dd1d630c","0c4b6c003211b62139329d42100d711d171e1d1ebd36000000001601dd1d630c"},
    [402]={"d84be62c8b3d936e5777fb7fd059ff7ffd7f000000000000d912ff579f03630c","d84b8061405e497fb57ffc7f887eff7ffa7f000000000000f6119f33ff02630c"},
    [403]={"12334b29103ef75a5b73bd77ce2d1136b53e00000000ff7fba41df527e55630c","12334b29eb35ce527563ba77ce2d1136b53e00000000ff7f1619ff299b19630c"},
    [404]={"862a3f1bf966334a4b354549ae1c3f089714307f7b6f8b7e096a8759e6384208","862a3f1b3b6f334a4b35744cae1c3f0897147f7ede7bff7d7c6df85c103c4208"},
    [405]={"862af9245552f3456f31ff418f149f14b51c3f1b1867ff7fff5eb319e71c4208","862a10065552f3456f319c378c01182794163f1b1867ff7fff47b319e71c4208"},
    [406]={"737e471d0822093aeb46725b00004655695e9e3158325b77ff7f3b03bf03630c","737ee71ce71c4a29ef3d94520000464969569e3158327c7fff7f3b03bf030000"},
    [407]={"862abd7f5a779566cf493f2f9926ae76ab599f3aff7fbf357b2d3929d1204208","862abd7f5a779566cf49d023e60dee7e2b5aff2fff7f3f17bd021d02f7004208"},
    [408]={"862a3967b556324aae397b6f3025bf353a29337fff7f8b7e096a8759e6384208","862ade7b5a6bb656324ade7b5601fc159f22f77fff7fb56f2953843e80214208"},
    [409]={"0e53596f93560539bc7bca7d907ecd3918005d29361a1c2b9f2fdf4bff7f0000","0e53df52935605399f733c19ff358f2d18005d29361a1c2b9f2fdf4bff7f0000"},
    [410]={"397f2e19ba351f26bf424e57aa3e872d000073422d4c8071ce35186bff7f630c","397f6d0df8227f27df474e57aa3e872d000073422d4c8071ce35186bff7f630c"},
    [411]={"124b0000ff491373987f4e5aff7f94529f4b5f2f28353831af207e39fe2ed525","124b0000ff2e924bf957ec32ff7f94529f4b5f2fe625b80d32015f0efe2ed525"},
  }
  local g3ShinyPics={front={},back={}}

  local function gen3MakeShiny(mon, pending)
    if not (type(mon)=="table" and (pending or state.pendingWild)) then return end
    local P=require("src.core.game3.pokemon")
    local Runtime=require("src.core.game3.runtime")
    local Catching=require("src.core.game3.battle.catching")
    local s=Runtime and Runtime.getSession and Runtime.getSession()

    local species=tonumber(mon.species or mon.speciesId)
    if not species then return end

    if state.wildShiny=="yes" then
      -- Recompute the PID against the exact OT IDs the live battle uses.
      local pid=gen3ForcedPid(species)
      if pid then mon.personality=pid end
      if s then
        mon.otId=tonumber(s.trainerId or s.id or s.playerId) or mon.otId
        mon.otSecretId=Catching.playerSecretId(s)
      end
      mon.isShiny=true
    elseif state.wildShiny=="no" then
      local pid=gen3ForcedPid(species)
      if pid then mon.personality=pid end
      if s then
        mon.otId=tonumber(s.trainerId or s.id or s.playerId) or mon.otId
        mon.otSecretId=Catching.playerSecretId(s)
      end
      mon.isShiny=false
    else
      mon.isShiny=nil
    end

    if mon.personality~=nil then
      mon.nature=P.natureId and P.natureId(mon.personality) or mon.nature
      mon.gender=P.gender and P.gender(species,mon.personality) or mon.gender
      mon.ability=P.abilityId and P.abilityId(species,mon.personality) or mon.ability
    end

    if state.wildMaxIVs then
      mon.ivs=mon.ivs or {}
      mon.ivs.hp=31; mon.ivs.atk=31; mon.ivs.def=31
      mon.ivs.spe=31; mon.ivs.spa=31; mon.ivs.spd=31
    end

    if P.applyStats then P.applyStats(mon) end
    if state.wildShiny=="yes" then
      state.shinyDebug="ID OK"
    elseif state.wildShiny=="no" then
      state.shinyDebug="ID NO"
    end
  end

  local function installGen3WildStartWrapper()
    if not isGen3(mod.game) then return false end
    local Battle=require("src.core.game3.battle")
    if not (Battle and type(Battle.start)=="function") then return false end
    if Battle._gamesharkWildStartVersion=="0.9.8" then return true end

    local previousStart=Battle.start
    Battle.start=function(opts)
      -- SHINY/GENDER/NATURE settings apply to any wild Pokémon. WILD PICK
      -- only chooses its species; it is not required for shiny encounters.
      local requested=state.wildShiny~="random" or state.wildGender~="random"
        or state.wildNature~="random" or state.wildMaxIVs
      local pending=type(opts)=="table" and opts.wild
        and (state.pendingWild or (requested and {species=opts.foe and opts.foe.species}))
      if pending then
        local copy={}
        for k,v in pairs(opts) do copy[k]=v end
        local foe={}
        for k,v in pairs(type(opts.foe)=="table" and opts.foe or {}) do foe[k]=v end

        local species=tonumber(foe.species or foe.speciesId or foe.id)
        if species then
          local pid=gen3ForcedPid(species)
          if pid then
            foe.personality=pid
            local P=require("src.core.game3.pokemon")
            foe.nature=P.natureId and P.natureId(pid) or foe.nature
            foe.gender=P.gender and P.gender(species,pid) or foe.gender
          end
          if state.wildShiny~="random" then
            local session=require("src.core.game3.runtime").getSession()
            local Catching=require("src.core.game3.battle.catching")
            if session then
              foe.otId=tonumber(session.trainerId or session.id or session.playerId) or foe.otId
              foe.otSecretId=Catching.playerSecretId(session)
            end
            foe.isShiny=(state.wildShiny=="yes")
          end
          if state.wildMaxIVs then
            foe.ivs={hp=31,atk=31,def=31,spe=31,spa=31,spd=31}
          end
        end
        copy.foe=foe
        -- FireRed emits battle.started inside Battle.start. Its listeners may
        -- clear pendingWild before Battle.start returns, so retain this marker
        -- in the callback and finalize the actual live battler there.
        local originalOnStarted=opts.onStarted
        copy.onStarted=function(st)
          local mon=st and st.enemy and st.enemy.mon
          if mon then gen3MakeShiny(mon,pending) end
          if originalOnStarted then return originalOnStarted(st) end
        end
        opts=copy
      end

      local a,b,c=previousStart(opts)

      -- This is deliberately after the engine constructed State.enemy.mon but
      -- still before the first battle update/render frame. It guarantees the
      -- actual live battler carries the shiny PID/flag even if another engine
      -- path copied or normalized the foe table during construction.
      if pending then
        if a then
          local st=Battle.getState and Battle.getState()
          local mon=st and st.enemy and st.enemy.mon
          if mon then gen3MakeShiny(mon,pending) end
        end
        state.pendingWild=nil
      end

      return a,b,c
    end

    Battle._gamesharkWildStartVersion="0.9.8"
    g3WildStartWrappedVersion="0.9.8"
    return true
  end

  -- Gen1Recomp currently decodes battle Pokémon pictures with the normal
  -- FireRed palette only. The original FireRed ROM has a separate
  -- gMonShinyPaletteTable, so even a logically shiny Pokémon can otherwise
  -- still look normal-coloured in the recomp. Discover that table from the
  -- ROM header and build a shiny battle picture without hard-coding a ROM
  -- address.
  installGen3ShinyBattlePalette=function()
    if not isGen3(mod.game) then return false end
    local Ui=require("src.core.game3.battle.ui")
    if not (Ui and type(Ui.battlerPic)=="function") then return false end
    if Ui._gamesharkShinyPicVersion=="0.9.11" then return true end

    local P=require("src.core.game3.pokemon")
    local Summary=require("src.core.game3.summary_data")
    local Chrome=require("src.ui.game3.summary_chrome")
    local Versions=require("src.import.gba.versions")
    local Lz77=require("src.import.gba.lz77")
    local bit=require("bit")
    local original=Ui.battlerPic
    local originalFront=P.frontPic
    local originalBack=P.backPic
    local SummaryMenu=nil

    -- Some imported caches omit the tiny summary-star texture. Draw the
    -- eight-point icon directly when that asset is unavailable.
    if Chrome and Chrome.drawShinyStar and Chrome._gamesharkStarVersion~="0.9.10" then
      local originalStar=Chrome.drawShinyStar
      Chrome.drawShinyStar=function(x,y)
        if Chrome.shinyStarImage and Chrome.shinyStarImage() then
          return originalStar(x,y)
        end
        if not (love and love.graphics and love.graphics.rectangle) then return end
        love.graphics.setColor(1,0.77,0.15,1)
        for row,width in ipairs({2,2,4,8,8,4,2,2}) do
          love.graphics.rectangle("fill",x+(8-width)/2,y+row-1,width,1)
        end
        love.graphics.setColor(1,1,1,1)
      end
      Chrome._gamesharkStarVersion="0.9.10"
    end

    local function u8(data,off) return data:byte(off+1) or 0 end
    local function u16(data,off) return u8(data,off)+u8(data,off+1)*256 end
    local function u32(data,off)
      return u8(data,off)+u8(data,off+1)*256+u8(data,off+2)*65536+u8(data,off+3)*16777216
    end
    local function pack32(v)
      return string.char(v%256,math.floor(v/256)%256,math.floor(v/65536)%256,math.floor(v/16777216)%256)
    end
    local function bgr(c)
      local r=bit.band(c,31)
      local g=bit.band(bit.rshift(c,5),31)
      local b=bit.band(bit.rshift(c,10),31)
      return r/31,g/31,b/31
    end

    local shinyTable=nil
    local function findShinyTable(data)
      if shinyTable then return shinyTable end
      local normal=(Versions.OAK_SPEECH and Versions.OAK_SPEECH.mon_palette_table) or 0x23730C
      local gba=0x08000000+normal
      local pat=pack32(gba)
      local pos=1
      while true do
        local i=data:find(pat,pos,true)
        if not i then break end
        -- In the GF ROM header the normal and shiny palette pointers are
        -- adjacent. Validate that the following pointer maps into this ROM.
        local nextPtr=u32(data,i-1+4)
        local file=Versions.gbaToFile and Versions.gbaToFile(nextPtr)
        if file and file>0 and file<#data-8 then
          local firstPtr=u32(data,file+8) -- Bulbasaur entry is species 1
          local firstFile=Versions.gbaToFile(firstPtr)
          if firstFile and firstFile>0 and firstFile<#data then
            shinyTable=file
            return shinyTable
          end
        end
        pos=i+1
      end
      -- FireRed US palette-table fallback when the header pointer scan is
      -- unavailable. Validate Bulbasaur's compressed palette before use.
      local fallback=0x2380CC
      local first=Versions.gbaToFile(u32(data,fallback+8))
      if first and first>0 and first<#data and u8(data,first)==0x10 then
        shinyTable=fallback
        return shinyTable
      end
      return nil
    end

    -- The normal sprite is already in the imported cache. Map its RGB pixels
    -- through the two tiny palettes extracted from the user's ROM. This path
    -- does not need the original ROM present when the game is launched.
    local function paletteShinyEntry(species,isBack,form)
      local pair=g3PalettePairs[species]
      if not pair then return nil end
      local Extract=require("src.import.gba.extract_island1")
      local cache=P._cache
      if not (cache and cache.read) then
        local Dataset=require("src.core.game3.dataset")
        cache=Dataset.cache and Dataset.cache()
      end
      local root=(Extract.CACHE_ROOT or "data/generated/gba").."/pokemon/"
      local kind=isBack and "back/" or "front/"
      local suffix=(species==385 and form>0) and ("_"..form) or ""
      local rel=root..kind..species..suffix..".rgba"
      local rgba=cache and cache.read and cache:read(rel)
      if type(rgba)~="string" then
        local CacheFs=require("src.import.CacheFs")
        rgba=CacheFs.readActive and CacheFs.readActive(rel)
      end
      if type(rgba)~="string" or #rgba<64*64*4 then return nil end
      local normal,shiny=pair[1],pair[2]
      local changes={}
      local start=(species==385 and form>0) and form*64+1 or 1
      for i=1,15 do
        local at=start+i*4
        -- BGR555 colors in the ROM are stored low byte first. The palette
        -- strings above preserve that byte order, so decode each 16-bit
        -- color as little-endian before deriving its RGB cache key.
        local nv=(tonumber(normal:sub(at,at+1),16) or 0)
          +(tonumber(normal:sub(at+2,at+3),16) or 0)*256
        local sv=(tonumber(shiny:sub(at,at+1),16) or 0)
          +(tonumber(shiny:sub(at+2,at+3),16) or 0)*256
        if nv and sv then
          local function rgb(v)
            local r=bit.band(v,31);local g=bit.band(bit.rshift(v,5),31)
            local b=bit.band(bit.rshift(v,10),31)
            return string.char(math.floor(r*255/31+0.5),
              math.floor(g*255/31+0.5),math.floor(b*255/31+0.5))
          end
          changes[rgb(nv)]=rgb(sv)
        end
      end
      local pixels={}
      local changed=0
      for i=1,64*64*4,4 do
        local old=rgba:sub(i,i+2)
        local new=changes[old] or old
        if new~=old and (rgba:byte(i+3) or 0)>0 then changed=changed+1 end
        pixels[#pixels+1]=new..rgba:sub(i+3,i+3)
      end
      -- A successfully created image can still be identical to the ordinary
      -- sprite if the cache palette differs. Never report that as COLOR OK.
      if changed==0 then return nil end
      local bytes=table.concat(pixels)
      if not(love and love.image and love.graphics) then return nil end
      local ok,data=pcall(love.image.newImageData,64,64,"rgba8",bytes)
      if not ok or not data then
        data=love.image.newImageData(64,64)
        local i=1
        for y=0,63 do for x=0,63 do
          data:setPixel(x,y,(bytes:byte(i) or 0)/255,(bytes:byte(i+1) or 0)/255,
            (bytes:byte(i+2) or 0)/255,(bytes:byte(i+3) or 0)/255)
          i=i+4
        end end
      end
      local image=love.graphics.newImage(data)
      image:setFilter("nearest","nearest")
      return {image=image,w=64,h=64}
    end

    local function shinyEntry(species,isBack,form)
      species=tonumber(species)
      if not species then return nil end
      form=tonumber(form) or 0
      local store=isBack and g3ShinyPics.back or g3ShinyPics.front
      local key=tostring(species)..":"..tostring(form)
      if store[key] then return store[key] end

      -- Calling the ordinary picture loader first causes Gen1Recomp to cache
      -- the active FireRed ROM bytes in Pokemon._romBytes.
      if not P._romBytes then
        if isBack and originalBack then originalBack(species,form)
        elseif originalFront then originalFront(species,form) end
      end
      local data=P._romBytes
      -- The imported RGBA cache is the same image the game draws. Recolor it
      -- first, before attempting a separate ROM tile decoder.
      local cached=paletteShinyEntry(species,isBack,form)
      if cached then store[key]=cached; return cached end
      if type(data)~="string" then return nil end

      local palTable=findShinyTable(data)
      if not palTable then return nil end
      local picTable
      if isBack then
        picTable=Versions.MON_BACK_PIC_TABLE or 0x23654C
      else
        picTable=(Versions.OAK_SPEECH and Versions.OAK_SPEECH.mon_front_pic_table) or 0x2350AC
      end

      local tilePtr=u32(data,picTable+species*8)
      local palPtr=u32(data,palTable+species*8)
      local tileFile=Versions.gbaToFile(tilePtr)
      local palFile=Versions.gbaToFile(palPtr)
      if not tileFile or not palFile then return nil end

      local function get(i) return u8(data,i) end
      local okT,tiles=pcall(Lz77.decompress,get,tileFile)
      local okP,palBytes=pcall(Lz77.decompress,get,palFile)
      if not(okT and okP and type(tiles)=="table" and type(palBytes)=="table") then return nil end

      local pal={}
      for c=0,15 do
        local lo=palBytes[form*32+c*2+1] or 0
        local hi=palBytes[form*32+c*2+2] or 0
        pal[c]=lo+hi*256
      end

      if not(love and love.image and love.graphics) then return nil end
      local imgData=love.image.newImageData(64,64)
      local ti=0
      for ty=0,7 do
        for tx=0,7 do
          local tileOff=form*2048+ti*32
          for row=0,7 do
            for bx=0,3 do
              local byte=tiles[tileOff+row*4+bx+1] or 0
              local p0=byte%16
              local p1=math.floor(byte/16)%16
              local function put(x,y,idx)
                if idx==0 then imgData:setPixel(x,y,0,0,0,0)
                else
                  local r,g,b=bgr(pal[idx] or 0)
                  imgData:setPixel(x,y,r,g,b,1)
                end
              end
              local x=tx*8+bx*2
              local y=ty*8+row
              put(x,y,p0); put(x+1,y,p1)
            end
          end
          ti=ti+1
        end
      end

      local entry={image=love.graphics.newImage(imgData),w=64,h=64}
      entry.image:setFilter("nearest","nearest")
      store[key]=entry
      return entry
    end

    Ui.battlerPic=function(side,battler,species)
      local entry,form,ghost=original(side,battler,species)
      if ghost then return entry,form,ghost end

      local b=battler
      local mon=type(b)=="table" and (b.mon or b) or nil
      if not mon then
        local st=activeGen3Battle
        if st then
          if side=="player" or side==0 or side==2 then
            mon=st.player and (st.player.mon or st.player)
          else
            mon=st.enemy and (st.enemy.mon or st.enemy)
          end
        end
      end

      if mon and Summary.isShiny(mon) then
        local sp=tonumber(species)
          or tonumber((b and b.species))
          or tonumber(mon.species or mon.speciesId)
        local isBack=(side=="player" or side==0 or side==2)
        local shiny=sp and shinyEntry(sp,isBack,form)
        if shiny then return shiny,form,false end
      end
      return entry,form,ghost
    end

    -- FireRed's main battle renderer calls Pokemon.frontPic/backPic directly
    -- (ui.lua:draw_mon_sprite), bypassing Ui.battlerPic. Cover that actual
    -- render path and the party summary, while keeping nonshiny callers intact.
    local function displayedShiny(species,isBack)
      species=tonumber(species)
      if not species then return false end
      if not SummaryMenu then
        local ok,menu=pcall(require,"src.ui.game3.summary_menu")
        if ok then SummaryMenu=menu end
      end
      local menu=SummaryMenu
      if menu and menu.open then
        local mon=menu._party and menu._party[menu._cursor or 1]
        if mon and tonumber(mon.species or mon.speciesId)==species then
          return Summary.isShiny(mon)
        end
      end
      if activeGen3Battle and not (menu and menu.open) then
        local st=activeGen3Battle
        local b=st and (isBack and st.player or st.enemy)
        local mon=b and (b.mon or b)
        if mon and tonumber(mon.species or mon.speciesId)==species then
          return Summary.isShiny(mon)
        end
      end
      return false
    end
    P.frontPic=function(species,form)
      local normal=originalFront and originalFront(species,form)
      if displayedShiny(species,false) then
        local shiny=shinyEntry(species,false,form)
        if shiny then state.shinyDebug="COLOR OK"
        else state.shinyDebug="NO COLORS" end
        return shiny or normal
      end
      return normal
    end
    P.backPic=function(species,form)
      local normal=originalBack and originalBack(species,form)
      if displayedShiny(species,true) then
        local shiny=shinyEntry(species,true,form)
        if shiny then state.shinyDebug="COLOR OK"
        else state.shinyDebug="NO COLORS" end
        return shiny or normal
      end
      return normal
    end

    Ui._gamesharkShinyPicVersion="0.9.11"
    return true
  end

  local function applyGen3WildOptions(mon)
    if not (isGen3(mod.game) and type(mon)=="table") then return end
    local requested=state.wildShiny~="random" or state.wildGender~="random"
      or state.wildNature~="random" or state.wildMaxIVs
    local pending=state.pendingWild or (requested and {species=mon.species})
    if pending then gen3MakeShiny(mon,pending) end
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
        if raw then
          local ok,err=pcall(applyGen3WildOptions,raw)
          if not ok then
            state.shinyDebug="EVENT ERR"
            state.shinySetupError=tostring(err)
          end
        else
          state.shinyDebug="NO ENEMY"
          state.shinySetupError="battle.started had no live enemy Pokémon"
        end
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
    local R=require("src.core.game3.runtime")
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
        {label="SHINY CHECK",kind="shiny_check",value=state.shinyDebug},
        {label="NATURE",kind="nature",value=string.upper(state.wildNature)},
        {label="MAX IVS",kind="maxivs",value=state.wildMaxIVs and "YES" or "NO"},
        {label="BATTLE NOW",kind="battle",value=">"},
        {label="BACK",kind="back"},
      }
    end
    if G3Menu.mode=="shiny_status" then
      local out={{label="STATUS",value=state.shinyDebug}}
      local msg=tostring(state.shinySetupError or "NO ERROR RECORDED")
      -- Narrow native menu: split the engine error into readable rows.
      for i=1,#msg,22 do
        out[#out+1]={label=msg:sub(i,i+21),kind="info"}
      end
      out[#out+1]={label="BACK",kind="back"}
      return out
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
      elseif row.kind=="shiny_check" then g3Switch("shiny_status")
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

    if G3Menu.mode=="shiny_status" then
      if row.kind=="back" then g3Switch("wild") end
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
