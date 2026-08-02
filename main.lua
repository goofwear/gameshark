
-- GameShark Compatibility 0.4.0
-- Built against Gen1Recomp 0.1.47's public mod API.

local MAIN_SCREEN = "GameSharkCompat"
local PICK_SCREEN = "GameSharkPokemonPicker"

-- Labels are intentionally short so the right-side ON/OFF column does not
-- collide with text on the original 160-pixel Game Boy layout.
local CHEATS = {
  { name = "WALL WALK",       code = "010138CD", effect = "walk" },
  { name = "NO BATTLES",      code = "01033CD1", effect = "no_encounters" },
  { name = "MASTER BALL",     code = "01017CCF", effect = "master_ball" },
  { name = "MAX MONEY",       code = "019947D3", effect = "cash" },
  { name = "RARE CANDY",      code = "01287CCF", effect = "rare_candy" },
  { name = "SLOT 1 HP",       code = "01FF16D0", effect = "party_hp" },
  { name = "ALL BADGES",      code = "01FF56D3", effect = "badges" },
  { name = "ONE HIT KO",      code = "0100E7CF", effect = "enemy_hp" },
  { name = "BURN FOE",        code = "0170E9CF", effect = "enemy_burn" },
  { name = "SAFARI BALL",     code = "016447DA", effect = "safari_balls" },
  { name = "SAFARI TIME",     code = "01F00ED7", effect = "safari_time" },
  { name = "STEAL TRAINER",   code = "010157D0", effect = "steal_trainer" },

  -- Native translation for the classic "wild Pokemon modifier" family.
  -- The chosen species is stored separately and injected through the
  -- confirmed encounter.roll hook.
  { name = "WILD PICK",       code = "01FF00D0", effect = "wild_pick" },
}

local BADGES = {
  "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
  "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
}

local function cleanCode(value)
  return (tostring(value or ""):upper():gsub("[^0-9A-F]", ""))
end

local function parseCode(value)
  local raw = cleanCode(value)
  if #raw ~= 8 then return nil, "eight hexadecimal digits required" end
  if raw:sub(1, 2) ~= "01" then
    return nil, "only 01 constant-write codes are supported"
  end
  return {
    raw = raw,
    value = tonumber(raw:sub(3, 4), 16),
    addressHex = raw:sub(7, 8) .. raw:sub(5, 6),
  }
end

local function findCheat(code)
  local clean = cleanCode(code)
  for _, cheat in ipairs(CHEATS) do
    if cheat.code == clean then return cheat end
  end
end

return function(mod)
  local active = {}
  local selectedSpecies = "PIKACHU"

  if type(mod.save) == "table" then
    if type(mod.save.active) == "table" then active = mod.save.active end
    if type(mod.save.selectedSpecies) == "string" then
      selectedSpecies = mod.save.selectedSpecies
    end
  end

  local function persist()
    if type(mod.save) == "table" then
      mod.save.active = active
      mod.save.selectedSpecies = selectedSpecies
    end
  end

  local function enabled(effect)
    for _, cheat in ipairs(CHEATS) do
      if cheat.effect == effect and active[cheat.code] then return true end
    end
    return false
  end

  local function ensureBagOrder(save, id)
    save.bagOrder = save.bagOrder or {}
    for _, existing in ipairs(save.bagOrder) do
      if existing == id then return end
    end
    table.insert(save.bagOrder, id)
  end

  local function ensureItem(save, id, quantity)
    save.inventory = save.inventory or {}
    if (save.inventory[id] or 0) < quantity then
      save.inventory[id] = quantity
    end
    ensureBagOrder(save, id)
  end

  local function battleStates(game)
    local result = {}
    local stack = game and game.stack and game.stack.states
    if type(stack) ~= "table" then return result end
    for _, state in ipairs(stack) do
      if type(state) == "table"
         and type(state.enemy) == "table"
         and type(state.enemy.mon) == "table" then
        result[#result + 1] = state
      end
    end
    return result
  end

  local function installTrainerCatch(battle)
    if not battle or battle._gamesharkThrowInstalled then return end
    if battle.kind ~= "trainer" then return end
    battle._gamesharkThrowInstalled = true
    battle._gamesharkOriginalThrowBall = battle.throwBall
    battle.throwBall = function(self, ball)
      self._gamesharkStealActive = true
      self._gamesharkOriginalKind = self.kind
      self.kind = "wild"
      return self:_gamesharkOriginalThrowBall(ball)
    end
  end

  local function removeTrainerCatch(battle)
    if not battle or not battle._gamesharkThrowInstalled then return end
    if not battle._gamesharkStealActive then
      battle.throwBall = nil
      battle._gamesharkOriginalThrowBall = nil
      battle._gamesharkThrowInstalled = nil
      battle._gamesharkOriginalKind = nil
    end
  end

  local function useSurfboard(game)
    local ow = game and game.overworld
    local save = game and game.save
    local mon = save and save.party and save.party[1]
    if not (ow and ow.player and mon) then return false end

    mon.moves = mon.moves or {}
    local temporaryMove
    local knowsSurf = false
    for _, move in ipairs(mon.moves) do
      if move.id == "SURF" then knowsSurf = true break end
    end
    if not knowsSurf then
      local def = game.data and game.data.moves and game.data.moves.SURF
      temporaryMove = { id = "SURF", pp = (def and def.pp) or 15 }
      table.insert(mon.moves, temporaryMove)
    end

    local reason = ow:useSurfFieldMove()
    if reason == "ok" then
      local fx, fy = ow.player:facingCell()
      ow:trySurf(fx, fy)
    end

    if temporaryMove then
      for i = #mon.moves, 1, -1 do
        if mon.moves[i] == temporaryMove then
          table.remove(mon.moves, i)
          break
        end
      end
    end
    return reason == "ok"
  end

  local function speciesRows()
    local rows = {}
    for id, mon in mod.content.pokemon:each() do
      rows[#rows + 1] = {
        id = id,
        name = mon.name or id,
        dex = mon.dex or 9999,
      }
    end
    table.sort(rows, function(a, b)
      if a.dex ~= b.dex then return a.dex < b.dex end
      return a.id < b.id
    end)
    return rows
  end

  -- Continuous GameShark-style effects.
  mod.hooks:wrap("input.step", function(next, game, dt)
    local save = game and game.save

    for _, battle in ipairs(battleStates(game)) do
      if enabled("steal_trainer") then
        installTrainerCatch(battle)
      else
        removeTrainerCatch(battle)
      end
    end

    if save then
      if enabled("cash") then save.money = 999999 end
      if enabled("master_ball") then ensureItem(save, "MASTER_BALL", 99) end
      if enabled("rare_candy") then ensureItem(save, "RARE_CANDY", 99) end

      if enabled("badges") then
        save.inventory = save.inventory or {}
        for _, badge in ipairs(BADGES) do save.inventory[badge] = 1 end
      end

      if enabled("party_hp") then
        local mon = save.party and save.party[1]
        if mon and mon.stats and mon.stats.hp then
          mon.hp = mon.stats.hp
        end
      end

      if save.safari then
        if enabled("safari_balls") then save.safari.balls = 99 end
        if enabled("safari_time") then save.safari.steps = 240 end
      end

      if enabled("enemy_burn") then
        for _, battle in ipairs(battleStates(game)) do
          local enemy = battle.enemy
          if enemy and enemy.mon and not enemy.mon.status then
            enemy.mon.status = "BRN"
            enemy.shownStatus = "BRN"
          end
        end
      end
    end
    return next(game, dt)
  end)

  mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
    local result = next(allowed, ctx)
    if enabled("walk") and ctx and ctx.reason ~= "bounds" then
      ctx.reason = "gameshark"
      return true
    end
    return result
  end)

  -- Preserve normal encounter timing and level. Only replace the species
  -- after the vanilla roll succeeds.
  mod.hooks:wrap("encounter.roll", function(next, encounterDef, ctx)
    if enabled("no_encounters") then return nil end
    local result = next(encounterDef, ctx)
    if result and enabled("wild_pick") and selectedSpecies then
      result.species = selectedSpecies
    end
    return result
  end)

  mod.hooks:wrap("catch.rate", function(next, ball, mon, def, opts)
    local battle = opts and opts.battle
    if enabled("steal_trainer")
       and battle and battle._gamesharkStealActive then
      return true, 3
    end
    return next(ball, mon, def, opts)
  end)

  mod.hooks:wrap("battle.damage", function(next, ctx)
    local damage, details = next(ctx)
    if enabled("enemy_hp")
       and ctx and ctx.user and ctx.user.isPlayer
       and ctx.target and not ctx.target.isPlayer
       and ctx.target.mon then
      damage = math.max(1, ctx.target.mon.hp or damage or 1)
    end
    return damage, details
  end)

  mod.exports.parse = parseCode
  mod.exports.list = function()
    local out = {}
    for _, cheat in ipairs(CHEATS) do
      out[#out + 1] = {
        name = cheat.name,
        code = cheat.code,
        enabled = active[cheat.code] == true,
        working = true,
      }
    end
    return out
  end

  mod.exports.setEnabled = function(code, value)
    local parsed, err = parseCode(code)
    if not parsed then return false, err end
    local cheat = findCheat(parsed.raw)
    if not cheat then return false, "code is not translated in this build" end
    active[cheat.code] = value == true
    persist()
    return true
  end

  mod.exports.getSelectedSpecies = function()
    return selectedSpecies
  end

  mod.exports.setSelectedSpecies = function(id)
    if not mod.content.pokemon:get(id) then
      return false, "unknown Pokemon id: " .. tostring(id)
    end
    selectedSpecies = id
    persist()
    return true
  end

  mod.content.screens:register(PICK_SCREEN, {
    new = function(game)
      local items = {}
      for _, row in ipairs(speciesRows()) do
        items[#items + 1] = {
          label = row.name,
          right = row.id == selectedSpecies and "*" or "",
          value = row.id,
        }
      end

      return mod.ui.ListMenu.new(game, "CHOOSE POKEMON", items, {
        pageJump = true,
        onChoose = function(item, menu)
          if not item or not item.value then return end
          selectedSpecies = item.value
          persist()
          menu:close()
          mod.ui.push(game, MAIN_SCREEN)
        end,
      })
    end,
  })

  mod.content.screens:register(MAIN_SCREEN, {
    new = function(game)
      local items = {}

      for _, cheat in ipairs(CHEATS) do
        items[#items + 1] = {
          label = cheat.name,
          right = active[cheat.code] and "ON" or "OFF",
          value = cheat.code,
          kind = "toggle",
        }
      end

      items[#items + 1] = {
        label = "USE SURFBOARD",
        right = "",
        value = "surfboard",
        kind = "surfboard",
      }

      items[#items + 1] = {
        label = "PICK POKEMON",
        right = "",
        value = "picker",
        kind = "picker",
      }

      return mod.ui.ListMenu.new(game, "GAMESHARK", items, {
        pageJump = true,
        onChoose = function(item, menu)
          if not item then return end

          if item.kind == "surfboard" then
            menu:close()
            local mounted = useSurfboard(game)
            if not mounted then mod.ui.push(game, MAIN_SCREEN) end
            return
          end

          if item.kind == "picker" then
            menu:close()
            mod.ui.push(game, PICK_SCREEN)
            return
          end

          local cheat = findCheat(item.value)
          if not cheat then return end
          active[cheat.code] = not active[cheat.code]
          persist()
          menu:close()
          mod.ui.push(game, MAIN_SCREEN)
        end,
      })
    end,
  })

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "GAMESHARK",
      onSelect = function() mod.ui.push(game, MAIN_SCREEN) end,
    })
  end)
end
