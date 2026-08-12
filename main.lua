-- GameShark Compatibility 0.5.0
-- Universal Gen 1 + Gen 2 build for Gen1Recomp 0.1.79+.
-- Author: goofwear
-- Uses only the public mod API and objects handed to hooks.

local MAIN_SCREEN = "GameSharkCompat"
local PICK_SCREEN = "GameSharkPokemonPicker"

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
  local state = { active={}, selectedSpecies="PIKACHU" }
  if type(mod.save)=="table" then
    if type(mod.save.activeEffects)=="table" then state.active=mod.save.activeEffects end
    if type(mod.save.selectedSpecies)=="string" then state.selectedSpecies=mod.save.selectedSpecies end
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
      save.player=save.player or {}; save.player.badges=save.player.badges or {}; save.player.kantoBadges=save.player.kantoBadges or {}
      for i,b in ipairs(JOHTO_BADGES) do save.player.badges[b]=true; save.player.badges[i]=true end
      for i,b in ipairs(KANTO_BADGES) do save.player.kantoBadges[b]=true; save.player.kantoBadges[i]=true end
    else
      save.inventory=save.inventory or {}; for _,b in ipairs(GEN1_BADGES) do save.inventory[b]=1 end
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
        if mon and not mon.status then mon.status="BRN" end
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

  local function speciesRows()
    local rows={}
    for id,mon in mod.content.pokemon:each() do rows[#rows+1]={id=id,name=mon.name or id,dex=mon.dex or 9999} end
    table.sort(rows,function(a,b) if a.dex~=b.dex then return a.dex<b.dex end return a.id<b.id end)
    return rows
  end

  mod.hooks:wrap("input.step", function(next,game,dt)
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
    if r and enabled("wild_pick") and state.selectedSpecies then r.species=state.selectedSpecies end
    return r
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
      local userPlayer=ctx.user.isPlayer or ctx.user.side=="player"
      local targetEnemy=(ctx.target.isPlayer==false) or ctx.target.side=="enemy"
      if userPlayer and targetEnemy then damage=math.max(1,ctx.target.hp or (ctx.target.mon and ctx.target.mon.hp) or damage or 1) end
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
  mod.exports.setSelectedSpecies=function(id) if not mod.content.pokemon:get(id) then return false,"unknown Pokemon" end state.selectedSpecies=id; persist(); return true end

  mod.content.screens:register(PICK_SCREEN,{new=function(game)
    local items={}; for _,r in ipairs(speciesRows()) do items[#items+1]={label=r.name,right=r.id==state.selectedSpecies and "*" or "",value=r.id} end
    return mod.ui.ListMenu.new(game,"CHOOSE POKEMON",items,{pageJump=true,onChoose=function(item,menu)
      if not item then return end; state.selectedSpecies=item.value; persist(); menu:close(); mod.ui.push(game,MAIN_SCREEN)
    end})
  end})

  mod.content.screens:register(MAIN_SCREEN,{new=function(game)
    local gold=isGold(game); local items={}
    for _,c in ipairs(CHEATS) do
      local supported=not (gold and c.gen2==false)
      if supported then items[#items+1]={label=c.name,right=enabled(c.effect) and "ON" or "OFF",value=c.effect,kind="toggle"} end
    end
    items[#items+1]={label="USE SURFBOARD",kind="surfboard"}
    items[#items+1]={label="PICK POKEMON",kind="picker"}
    return mod.ui.ListMenu.new(game,gold and "GAMESHARK G2" or "GAMESHARK G1",items,{pageJump=true,onChoose=function(item,menu)
      if not item then return end
      if item.kind=="surfboard" then
        menu:close(); local ok=useSurfboard(game); if not ok then mod.ui.push(game,MAIN_SCREEN) end; return
      end
      if item.kind=="picker" then menu:close(); mod.ui.push(game,PICK_SCREEN); return end
      setEnabled(item.value,not enabled(item.value)); menu:close(); mod.ui.push(game,MAIN_SCREEN)
    end})
  end})

  mod.hooks:wrap("ui.start_menu.items",function(next,game,items)
    local out=next(game,items); if type(out)~="table" then return out end
    return mod.ui.insertBefore(out,"SAVE",{label="GAMESHARK",onSelect=function() mod.ui.push(game,MAIN_SCREEN) end})
  end)
end
