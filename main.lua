-- GameShark Compatibility 0.5.3
-- Universal Gen 1 + Gen 2 build for Gen1Recomp 0.1.79+.
-- Author: goofwear
-- Uses only the public mod API and objects handed to hooks.

local MAIN_SCREEN = "GameSharkCompat"
local PICK_SCREEN = "GameSharkPokemonPicker"

local GENDER_CHOICES = { "random", "male", "female" }
local SHINY_CHOICES = { "random", "yes", "no" }

local CHEATS = {
  { name="WALL WALK", effect="walk", gen1="010138CD", gold="010AA3CE" },
  { name="NO BATTLES", effect="no_encounters", gen1="01033CD1", gold="01000BD2" },
  { name="MASTER BALL", effect="master_ball", gen1="01017CCF", gold="0101FDD5" },
  { name="MAX MONEY", effect="cash", gen1="019947D3", gold="019973D5" },
  { name="RARE CANDY", effect="rare_candy", gen1="01287CCF", gold="0120ABD5" },
  { name="SLOT 1 HP", effect="party_hp", gen1="01FF16D0", gold="01FF4CDA" },
  { name="ALL BADGES", effect="badges", gen1="01FF56D3", gold="01FF7CD5" },
  { name="ONE HIT KO", effect="enemy_hp", gen1="0100E7CF", gold="010000D1" },
  { name="BURN FOE", effect="enemy_burn", gen1="0170E9CF", gold="0100ADD7" },
  { name="SAFARI BALL", effect="safari_balls", gen1="016447DA", gen2=false },
  { name="SAFARI TIME", effect="safari_time", gen1="01F00ED7", gen2=false },
  { name="STEAL TRAINER", effect="steal_trainer", gen1="010157D0", gold="010116D1" },
  { name="WILD PICK", effect="wild_pick", gen1="01FF00D0", gold="01??EDD0" },
}

local GEN1_BADGES = {
  "BOULDERBADGE","CASCADEBADGE","THUNDERBADGE","RAINBOWBADGE",
  "SOULBADGE","MARSHBADGE","VOLCANOBADGE","EARTHBADGE",
}
local JOHTO_BADGES = { "ZEPHYR","HIVE","PLAIN","FOG","MINERAL","STORM","GLACIER","RISING" }
local KANTO_BADGES = { "BOULDER","CASCADE","THUNDER","RAINBOW","SOUL","MARSH","VOLCANO","EARTH" }

local function isGold(game)
  local s=game and game.save
  return s and (s.version=="gold" or s.generation==2) or false
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
    pendingWild=nil,
  }

  local uiPos = {
    mainIndex = 1, mainScroll = 0,
    pickIndex = 1, pickScroll = 0,
  }
  if type(mod.save)=="table" then
    if type(mod.save.activeEffects)=="table" then state.active=mod.save.activeEffects end
    if type(mod.save.selectedSpecies)=="string" then state.selectedSpecies=mod.save.selectedSpecies end
    if mod.save.wildGender=="male" or mod.save.wildGender=="female" or mod.save.wildGender=="random" then
      state.wildGender=mod.save.wildGender
    end
    if mod.save.wildShiny=="yes" or mod.save.wildShiny=="no" or mod.save.wildShiny=="random" then
      state.wildShiny=mod.save.wildShiny
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
  local function persist()
    if type(mod.save)=="table" then
      mod.save.activeEffects=state.active
      mod.save.selectedSpecies=state.selectedSpecies
      mod.save.wildGender=state.wildGender
      mod.save.wildShiny=state.wildShiny
    end
  end
  local function enabled(effect) return state.active[effect]==true end
  local function setEnabled(effect,value) state.active[effect]=value==true; persist() end

  local function ensureItem(save,id,qty)
    save.inventory=save.inventory or {}
    if (save.inventory[id] or 0)<qty then save.inventory[id]=qty end
    if save.version~="gold" and save.generation~=2 then
      save.bagOrder=save.bagOrder or {}
      local found=false; for _,v in ipairs(save.bagOrder) do if v==id then found=true break end end
      if not found then table.insert(save.bagOrder,id) end
    end
  end

  local function grantBadges(save)
    if save.version=="gold" or save.generation==2 then
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
    b._gamesharkThrowInstalled=true; b._gamesharkOriginalThrowBall=b.throwBall
    b.throwBall=function(self,ball)
      self._gamesharkStealActive=true; self._gamesharkOriginalKind=self.kind; self.kind="wild"
      return self:_gamesharkOriginalThrowBall(ball)
    end
  end

  local function unpatchGen1Trainer(b)
    if b and b._gamesharkThrowInstalled and not b._gamesharkStealActive then
      b.throwBall=nil; b._gamesharkOriginalThrowBall=nil
      b._gamesharkThrowInstalled=nil; b._gamesharkOriginalKind=nil
    end
  end

  local function burnEnemy(game)
    if isGold(game) then
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
    if isGold(game) then
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
      if enabled("cash") then if isGold(game) then save.player.money=999999 else save.money=999999 end end
      if enabled("master_ball") then ensureItem(save,"MASTER_BALL",99) end
      if enabled("rare_candy") then ensureItem(save,"RARE_CANDY",99) end
      if enabled("badges") then grantBadges(save) end
      if enabled("party_hp") then
        local mon=save.party and save.party[1]
        if mon then mon.hp=mon.maxHp or (mon.stats and mon.stats.hp) or mon.hp end
      end
      if not isGold(game) and save.safari then
        if enabled("safari_balls") then save.safari.balls=99 end
        if enabled("safari_time") then save.safari.steps=240 end
      end
    end
    if isGold(game) then
      for _,s in ipairs(goldBattleScreens(game)) do if enabled("steal_trainer") and not s.battle.wild then patchGoldTrainer(s) else unpatchGoldTrainer(s) end end
    else
      for _,b in ipairs(gen1BattleStates(game)) do
        if enabled("steal_trainer") then patchGen1Trainer(b) else unpatchGen1Trainer(b) end
      end
    end
    if enabled("enemy_burn") then burnEnemy(game) end
    return next(game,dt)
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
      -- Gold constructs the actual Mon after the encounter roll. Carry these
      -- choices only into that next matching build; shiny.roll runs before
      -- gender.roll, which clears the marker after both have had their say.
      local game=mod.game
      if isGold(game) and (state.wildGender~="random" or state.wildShiny~="random") then
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
    if state.wildShiny=="yes" then return true end
    if state.wildShiny=="no" then return false end
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
    state.pendingWild=nil
    return result
  end)
  mod.hooks:wrap("catch.rate", function(next,ball,mon,def,opts)
    if trainerCatchInProgress then return true,255 end
    local battle=opts and opts.battle
    if enabled("steal_trainer") and battle and battle._gamesharkStealActive then return true,255 end
    return next(ball,mon,def,opts)
  end)
  mod.hooks:wrap("battle.damage", function(next,ctx)
    local damage,info=next(ctx)
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
  mod.exports.game=function(game) return isGold(game) and "gold" or ((game and game.save and game.save.version) or "gen1") end
  mod.exports.list=function(game)
    local gold=isGold(game); local out={}
    for _,c in ipairs(CHEATS) do
      local supported=not (gold and c.gen2==false)
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
        mod.ui.push(game,MAIN_SCREEN)
      end
    })

    menu.index=math.max(1,math.min(uiPos.pickIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.pickScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.content.screens:register(MAIN_SCREEN,{new=function(game)
    local gold=isGold(game); local items={}
    for _,c in ipairs(CHEATS) do
      local supported=not (gold and c.gen2==false)
      if supported then items[#items+1]={label=c.name,right=enabled(c.effect) and "ON" or "OFF",value=c.effect,kind="toggle"} end
    end
    items[#items+1]={label="PICK POKEMON",kind="picker"}
    if gold then
      items[#items+1]={
        label="WILD GENDER",
        right=selectedGenderless() and "N/A" or (state.wildGender=="random" and "RND" or string.upper(state.wildGender:sub(1,1))),
        kind="gender"
      }
      items[#items+1]={
        label="WILD SHINY",
        right=state.wildShiny=="random" and "RND" or string.upper(state.wildShiny),
        kind="shiny"
      }
    end
    items[#items+1]={label="USE SURFBOARD",kind="surfboard"}
    local menu
    menu=mod.ui.ListMenu.new(game,gold and "GAMESHARK G2" or "GAMESHARK G1",items,{
      pageJump=true,
      onChoose=function(item,current)
      if not item then return end
      uiPos.mainIndex=current.index or uiPos.mainIndex
      uiPos.mainScroll=current.scroll or uiPos.mainScroll
      if item.kind=="gender" then
        if not selectedGenderless() then
          state.wildGender=cycleChoice(state.wildGender,GENDER_CHOICES)
          persist()
        end
        current:close(); mod.ui.push(game,MAIN_SCREEN); return
      end
      if item.kind=="shiny" then
        state.wildShiny=cycleChoice(state.wildShiny,SHINY_CHOICES)
        persist(); current:close(); mod.ui.push(game,MAIN_SCREEN); return
      end
      if item.kind=="surfboard" then
        current:close(); local ok=useSurfboard(game); if not ok then mod.ui.push(game,MAIN_SCREEN) end; return
      end
      if item.kind=="picker" then current:close(); mod.ui.push(game,PICK_SCREEN); return end
      setEnabled(item.value,not enabled(item.value))
      current:close()
      mod.ui.push(game,MAIN_SCREEN)
      end
    })
    menu.index=math.max(1,math.min(uiPos.mainIndex,#items))
    menu.scroll=math.max(0,math.min(uiPos.mainScroll,math.max(0,#items-menu.rows)))
    return menu
  end})

  mod.hooks:wrap("ui.start_menu.items",function(next,game,items)
    local out=next(game,items); if type(out)~="table" then return out end
    return mod.ui.insertBefore(out,"SAVE",{label="GAMESHARK",onSelect=function() mod.ui.push(game,MAIN_SCREEN) end})
  end)
end
