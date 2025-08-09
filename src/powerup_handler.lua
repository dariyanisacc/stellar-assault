local Powerup = require("src.entities.powerup")
local constants = require("src.constants")
local Collision = require("src.collision")
local Game = require("src.game")
local PowerupHandler = {}

function PowerupHandler.update(state, dt)
  local scene = state.scene or state
  local powerups = scene.powerups or _G.powerups
  local powerupTexts = scene.powerupTexts or _G.powerupTexts
  local activePowerups = scene.activePowerups or _G.activePowerups or {}
  for i = #powerups, 1, -1 do
    local powerup = powerups[i]
    powerup:update(dt)
    -- Magnet field: attract powerups toward player while keeping downward drift
    if ((activePowerups.magnet or 0) > 0) and _G.player then
      local dx = player.x - powerup.x
      local dy = player.y - powerup.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > 0 then
        local pull = 140 -- attraction speed in px/s
        powerup.x = powerup.x + (dx / dist) * pull * dt
        powerup.y = powerup.y + (dy / dist) * pull * dt
      end
    end
    if state.entityGrid then
      state.entityGrid:update(powerup)
    end
    if powerup.y > state.screenHeight + powerup.height then
      if state.entityGrid then
        state.entityGrid:remove(powerup)
      end
      table.remove(powerups, i)
    end
  end
  for i = #powerupTexts, 1, -1 do
    local text = powerupTexts[i]
    -- Float text downward as requested
    text.y = text.y + 50 * dt
    text.life = text.life - dt
    if text.life <= 0 then
      table.remove(powerupTexts, i)
    end
  end

  missiles = missiles or {}
  for i = #missiles, 1, -1 do
    local m = missiles[i]
    if not m.target or m.target._remove then
      local closest
      local closestDist = math.huge
      for _, a in ipairs(aliens or {}) do
        local dx = (a.x + (a.width or 0) / 2) - m.x
        local dy = (a.y + (a.height or 0) / 2) - m.y
        local d = dx * dx + dy * dy
        if d < closestDist then
          closestDist = d
          closest = a
        end
      end
      if state.waveManager and state.waveManager.enemies then
        for _, a in ipairs(state.waveManager.enemies) do
          local dx = (a.x + (a.width or 0) / 2) - m.x
          local dy = (a.y + (a.height or 0) / 2) - m.y
          local d = dx * dx + dy * dy
          if d < closestDist then
            closestDist = d
            closest = a
          end
        end
      end
      m.target = closest
    end

    if m.target then
      local dx = (m.target.x + (m.target.width or 0) / 2) - m.x
      local dy = (m.target.y + (m.target.height or 0) / 2) - m.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > 0 then
        m.vx = (dx / dist) * m.speed
        m.vy = (dy / dist) * m.speed
      end
    end

    m.x = m.x + (m.vx or 0) * dt
    m.y = m.y + (m.vy or -m.speed) * dt

    -- Lifetime expiry
    m.ttl = (m.ttl or 4) - dt

    local hit = false
    local function hitAABB(ax, ay, aw, ah, b)
      local bx, by, bw, bh
      if b.tag == "enemy" then
        bx, by, bw, bh = b.x, b.y, b.width, b.height
      else
        bx = (b.x - (b.width or 0) * 0.5)
        by = (b.y - (b.height or 0) * 0.5)
        bw, bh = b.width or 0, b.height or 0
      end
      return Collision.aabb(ax, ay, aw, ah, bx, by, bw, bh)
    end

    -- Missile bounds (center -> top-left)
    local mx, my = m.x - (m.width or 8) * 0.5, m.y - (m.height or 18) * 0.5
    local mw, mh = m.width or 8, m.height or 18

    -- Check aliens first
    if not hit then
      for ai = #scene.aliens, 1, -1 do
        local a = scene.aliens[ai]
        if hitAABB(mx, my, mw, mh, a) then
          -- Destroy alien via state helper
          if state.handleAlienDestruction then
            state:handleAlienDestruction(a, ai)
          else
            table.remove(scene.aliens, ai)
          end
          hit = true
          break
        end
      end
    end

    -- Check wave enemies (top-left coords)
    if not hit and state.waveManager and state.waveManager.enemies then
      for ei = #state.waveManager.enemies, 1, -1 do
        local e = state.waveManager.enemies[ei]
        if hitAABB(mx, my, mw, mh, e) then
          e.health = (e.health or 1) - (m.damage or 1)
          if e.health <= 0 then
            e.active = false
            if state.entityGrid then state.entityGrid:remove(e) end
            if state.findEntityIndex then
              local idx = state:findEntityIndex(state.waveManager.enemies, e) or ei
              -- Explosion + score/music handled similar to lasers
              if state.createExplosion then
                local enemySize = math.max(e.width or 0, e.height or 0)
                state:createExplosion(e.x + (e.width or 0) / 2, e.y + (e.height or 0) / 2, enemySize)
              end
              table.remove(state.waveManager.enemies, idx)
            else
              table.remove(state.waveManager.enemies, ei)
            end
          end
          hit = true
          break
        end
      end
    end

    if hit then
      if state.laserPool and state.laserPool.release then
        -- missiles are not pooled; just remove entry
      end
      if Game and Game.audioPool then Game.audioPool:play("explosion", m.x, m.y) end
      table.remove(missiles, i)
    elseif m.ttl <= 0 or m.x < -40 or m.x > state.screenWidth + 40 or m.y < -40 or m.y > state.screenHeight + 40 then
      table.remove(missiles, i)
    end
  end
end

function PowerupHandler.spawn(state, x, y, forceType)
  local scene = state.scene or state
  local powerups = scene.powerups or _G.powerups
  x = x or math.random(30, state.screenWidth - 30)
  y = y or -30
  local types = { "shield", "rapid", "spread" }
  if currentLevel >= 2 then
    table.insert(types, "boost")
    table.insert(types, "coolant")
    table.insert(types, "magnet")
  end
  if currentLevel >= 3 then
    table.insert(types, "bomb")
  end
  if currentLevel >= 4 then
    table.insert(types, "health")
  end
  local isEnhanced = math.random() < constants.balance.enhancedPowerupChance

  local powerupType = forceType
  if not powerupType then
    if math.random() < constants.balance.specialPowerupChance then
      powerupType = "homingMissile"
    else
      powerupType = types[math.random(#types)]
    end
  end

  local powerup = Powerup.new(x, y, powerupType)
  if isEnhanced then
    powerup.enhanced = true
    powerup.color = { powerup.color[1], powerup.color[2], powerup.color[3], 1 }
  end
  powerup.tag = "powerup"
  table.insert(powerups, powerup)
  if state.entityGrid then
    state.entityGrid:insert(powerup)
  end
end

function PowerupHandler.checkCollisions(state)
  local scene = state.scene or state
  local powerups = scene.powerups or _G.powerups
  local powerupTexts = scene.powerupTexts or _G.powerupTexts
  local activePowerups = scene.activePowerups or _G.activePowerups
  for i = #powerups, 1, -1 do
    local powerup = powerups[i]
    if Collision.checkAABB(player, powerup) then
      local result = powerup:collect(player)
      local enhancementMultiplier = powerup.enhanced and 2 or 1
      if result == "bomb" then
        player.bombs = (player.bombs or 0) + (1 * enhancementMultiplier)
        if powerup.enhanced then
          state:createPowerupText("DOUBLE BOMB!", powerup.x, powerup.y, { 1, 1, 0 })
        end
      elseif type(result) == "table" then
        local duration = result.duration * enhancementMultiplier
        activePowerups[result.type] = duration
        if result.type == "rapid" and powerup.enhanced then
          state:createPowerupText("SUPER RAPID FIRE!", powerup.x, powerup.y, { 1, 1, 0 })
        elseif result.type == "spread" then
          activePowerups.multiShot = duration
          if powerup.enhanced then
            state:createPowerupText("MEGA SPREAD!", powerup.x, powerup.y, { 1, 0.5, 0 })
          end
        elseif result.type == "boost" and powerup.enhanced then
          state:createPowerupText("HYPER BOOST!", powerup.x, powerup.y, { 0, 1, 0 })
        elseif result.type == "coolant" then
          player.heat = 0
          if powerup.enhanced then
            state:createPowerupText("SUPER COOLANT!", powerup.x, powerup.y, { 0, 0.7, 1 })
          else
            state:createPowerupText("HEAT RESET!", powerup.x, powerup.y, { 0, 0.5, 1 })
          end
        end
      elseif result == true and powerup.type == "shield" and powerup.enhanced then
        player.shield = math.min(player.shield + 1, player.maxShield)
        state:createPowerupText("DOUBLE SHIELD!", powerup.x, powerup.y, { 0, 1, 1 })
      elseif result == true and powerup.type == "health" and powerup.enhanced then
        lives = lives + 1
        state:createPowerupText("EXTRA LIFE!", powerup.x, powerup.y, { 1, 0.2, 0.2 })
      end
      score = score + constants.score.powerup
      if score > state.previousHighScore and not state.newHighScore then
        state.newHighScore = true
        state:showNewHighScoreNotification()
      end
      if powerupSound then
        powerupSound:stop()
        powerupSound:play()
      end
      state:createPowerupText(powerup.description, powerup.x, powerup.y, powerup.color)
      if state.entityGrid then
        state.entityGrid:remove(powerup)
      end
      table.remove(powerups, i)
    end
  end
end

function PowerupHandler.createText(state, text, x, y, color)
  local scene = state.scene or state
  local powerupTexts = scene.powerupTexts or _G.powerupTexts
  table.insert(powerupTexts, { text = text, x = x, y = y, color = color, life = 1.5 })
end

return PowerupHandler
