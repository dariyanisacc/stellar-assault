-- File: src/playercontrol.lua
----------------------------------------------------------------------
-- Stellar Assault - Player Control Module
-- Handles movement, shooting, heat, and input abstraction.
----------------------------------------------------------------------

local constants   = require("src.constants")
local Persistence = require("src.persistence")

local PlayerControl = {}

----------------------------------------------------------------------
-- INTERNAL HELPERS --------------------------------------------------
----------------------------------------------------------------------

-- Keyboard/game‑pad mappings come from user‑remappable controls stored
-- via Persistence.  Sensible defaults are supplied as a fallback.
local function kbd()
  local c = Persistence.getControls and Persistence.getControls().keyboard
  return c or {
    left  = "left",
    right = "right",
    up    = "up",
    down  = "down",
    shoot = "space",
    boost = "lshift",
  }
end

local function pad()
  local c = Persistence.getControls and Persistence.getControls().gamepad
  return c or {
    shoot = "a",
    bomb  = "b",
    boost = "x",
  }
end

----------------------------------------------------------------------
-- MOVEMENT, THRUST, HEAT -------------------------------------------
----------------------------------------------------------------------

---@param state table  -- current game‑state table
---@param dt    number -- fixed delta‑time from main loop
function PlayerControl.update(state, dt)
  -- Defensive guards so update can be called during partial init
  state = state or {}
  state.keys = state.keys or {}
  if not _G.player then
    return
  end
  
  -- Sticky-key guard: if a key is latched in state.keys but the
  -- physical key isn't held anymore (missed keyreleased or focus
  -- change), clear it to prevent perpetual movement/shooting.
  if love and love.keyboard and love.keyboard.isDown then
    local b = kbd()
    local function clearIfReleased(action, keyname)
      local k = keyname
      if state.keys[action] and type(k) == "string" and k ~= "" then
        if not love.keyboard.isDown(k) then
          state.keys[action] = false
        end
      end
    end
    clearIfReleased("left",  b.left)
    clearIfReleased("right", b.right)
    clearIfReleased("up",    b.up)
    clearIfReleased("down",  b.down)
    -- Do not clear shoot/boost here if gamepad is the active device,
    -- to allow continuous fire while holding A/RT.
    local usingGamepad = _G.Game and Game.lastInputType == "gamepad"
    if not usingGamepad then
      clearIfReleased("shoot", b.shoot)
      clearIfReleased("boost", b.boost)
    end
  end
  -- Optional: treat left mouse as shoot hold as well
  if love and love.mouse and love.mouse.isDown then
    if love.mouse.isDown(1) then
      state.keys.shoot = true
    end
  end
  --------------------------------------------------------------------
  -- Scene‑scoped references (supporting new scene/EC‑style infra) ---
  --------------------------------------------------------------------
  local scene          = state.scene or state
  local lasers         = scene.lasers         or _G.lasers         or {}
  local activePowerups = scene.activePowerups or _G.activePowerups or {}

  --------------------------------------------------------------------
  -- Aggregate input -------------------------------------------------
  --------------------------------------------------------------------
  -- Aggregate keyboard input first
  local dx, dy = 0, 0
  local kb_dx, kb_dy = 0, 0
  if state.keys.left  then kb_dx = kb_dx - 1 end
  if state.keys.right then kb_dx = kb_dx + 1 end
  if state.keys.up    then kb_dy = kb_dy - 1 end
  if state.keys.down  then kb_dy = kb_dy + 1 end

  -- Left‑stick on first connected game‑pad
  -- Only consider analog axes if the gamepad was recently active to avoid drift
  local useGamepad = _G.Game and Game.lastInputType == "gamepad" and ((Game.gamepadActiveTimer or 0) > 0)
  local stick_dx, stick_dy = 0, 0
  if useGamepad and love.joystick and love.joystick.getJoysticks then
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
      local js = joysticks[1]
      if js:isGamepad() then
        local deadzone = (Game and Game.gamepadDeadzone) or 0.3
        local fireThresh = (Game and Game.gamepadTriggerThreshold) or 0.75
        local jx, jy = js:getGamepadAxis("leftx") or 0, js:getGamepadAxis("lefty") or 0
        if math.abs(jx) > deadzone then stick_dx = jx end
        if math.abs(jy) > deadzone then stick_dy = jy end

        -- Hold right trigger for continuous fire (higher threshold to avoid noise)
        local rt = js:getGamepadAxis("triggerright") or 0
        if rt > fireThresh then
          PlayerControl.shoot(state, dt)
        end
      end
    end
  end

  -- Keyboard input has priority when pressed; otherwise use stick
  if kb_dx ~= 0 or kb_dy ~= 0 then
    dx, dy = kb_dx, kb_dy
  else
    dx, dy = stick_dx, stick_dy
  end

  --------------------------------------------------------------------
  -- Apply thrust & physics -----------------------------------------
  --------------------------------------------------------------------
  local len = math.sqrt(dx * dx + dy * dy)
  if len > 0 then
    dx, dy = dx / len, dy / len

    local thrustMult = 1
    if activePowerups.boost then thrustMult = thrustMult * 1.5 end
    if state.keys.boost      then thrustMult = thrustMult * 2   end

    player.vx = player.vx + dx * player.thrust * dt * thrustMult
    player.vy = player.vy + dy * player.thrust * dt * thrustMult
  end

  player.vx = player.vx * (1 - player.drag * dt)
  player.vy = player.vy * (1 - player.drag * dt)

  local speed      = math.sqrt(player.vx * player.vx + player.vy * player.vy)
  local baseMaxVel = player.maxSpeed or 300
  local maxVel     = activePowerups.boost and baseMaxVel * 1.5 or baseMaxVel
  if speed > maxVel then
    player.vx = (player.vx / speed) * maxVel
    player.vy = (player.vy / speed) * maxVel
  end

  player.x = player.x + player.vx * dt
  player.y = player.y + player.vy * dt

  local w, h = love.graphics.getDimensions()
  if player.x < player.width / 2 then
    player.x, player.vx = player.width / 2, math.max(0, player.vx)
  elseif player.x > w - player.width / 2 then
    player.x, player.vx = w - player.width / 2, math.min(0, player.vx)
  end
  if player.y < player.height / 2 then
    player.y, player.vy = player.height / 2, math.max(0, player.vy)
  elseif player.y > h - player.height / 2 then
    player.y, player.vy = h - player.height / 2, math.min(0, player.vy)
  end

  --------------------------------------------------------------------
  -- Cool‑downs & heat ----------------------------------------------
  --------------------------------------------------------------------
  if state.shootCooldown and state.shootCooldown > 0 then
    state.shootCooldown = math.max(0, state.shootCooldown - dt)
  end

  -- Prevent laser pool starvation on extreme burst: proactively recycle
  if state.keys.shoot and (state.shootCooldown or 0) <= 0
     and (player.overheatTimer or 0) <= 0 and #lasers >= (constants.balance.laserWarningThreshold or 90) then
    local old = table.remove(lasers, 1)
    if old and state.laserGrid then state.laserGrid:remove(old) end
    if old and state.laserPool and state.laserPool.release then
      state.laserPool:release(old)
    end
  end

  if player.heat > 0 then
    local coolMult = activePowerups.coolant and 1.5 or 1
    if player.overheatTimer > 0 then coolMult = coolMult * 2 end
    player.heat = math.max(0, player.heat - player.coolRate * dt * coolMult)
  end

  if player.overheatTimer > 0 then
    player.overheatTimer = player.overheatTimer - dt
    if player.overheatTimer <= 0 then
      player.heat = 0
      if state.showDebug then
        print("Overheat period ended - weapon ready!")
      end
    end
  end

  local hpct = player.heat / player.maxHeat
  if hpct > 0.75 then
    player.color = { 1, 1 - (hpct - 0.75) * 2, 1 - (hpct - 0.75) * 2 }
  else
    player.color = { 1, 1, 1 }
  end

  if hpct > 0.6 and math.random() < (hpct - 0.6) * 2.5 * dt then
    PlayerControl.createHeatParticle(state)
  end

  if state.keys.shoot then
    PlayerControl.shoot(state, dt)
  end
end

----------------------------------------------------------------------
-- SHOOTING ----------------------------------------------------------
----------------------------------------------------------------------

function PlayerControl.shoot(state, dt)
  dt = dt or (love.timer and love.timer.getDelta()) or 0.016

  local scene          = state.scene or state
  local lasers         = scene.lasers         or _G.lasers         or {}
  local activePowerups = scene.activePowerups or _G.activePowerups or {}

  -- Gating: cooldown and overheat
  if (state.shootCooldown and state.shootCooldown > 0) or (player.overheatTimer or 0) > 0 then
    return
  end
  if (player.heat or 0) >= (player.maxHeat or 100) then
    player.overheatTimer = player.overheatPenalty
    -- Use pooled audio if available; otherwise skip silently
    if _G.Game and Game.audioPool then Game.audioPool:play("explosion", player.x, player.y) end
    if state.showDebug then
      print("OVERHEAT! Starting cooldown period")
    end
    return
  end

  local shipId = (Game and Game.selectedShip) or _G.selectedShip or "alpha"
  local shipCfg = constants.ships[shipId] or constants.ships.alpha
  local spread  = shipCfg.spread or 0
  if not state.laserPool or not state.laserPool.get then return end
  local laser   = state.laserPool:get()
  if not laser then
    if state.showDebug then
      print("WARNING: Laser pool exhausted! Cannot create laser.")
    end
    return
  end

  laser.x      = player.x
  laser.y      = player.y - player.height / 2
  laser.width  = constants.laser.width  or 4
  laser.height = constants.laser.height or 12
  laser.speed  = constants.laser.speed
  laser.vx, laser.vy = nil, nil
  laser._remove, laser.isAlien = false, false

  table.insert(lasers, laser)
  if state.laserGrid then state.laserGrid:insert(laser) end

  if activePowerups.homingMissile then
    missiles = missiles or {}
    table.insert(missiles, {
      x = laser.x,
      y = laser.y,
      width = 8,
      height = 18,
      speed = 240,
      damage = 2,
      ttl = 4.0,
    })
  end

  if spread > 0 then
    for dir = -1, 1, 2 do
      local lz = state.laserPool:get()
      if lz then
        lz.x, lz.y  = laser.x, laser.y
        lz.width    = laser.width
        lz.height   = laser.height
        lz.speed    = laser.speed
        lz.vx       = dir * math.sin(spread) * lz.speed
        lz.vy       = -math.cos(spread) * lz.speed
        lz._remove, lz.isAlien = false, false
        table.insert(lasers, lz)
        if state.laserGrid then state.laserGrid:insert(lz) end
      end
    end
  end

  local weaponPU = activePowerups.rapid or activePowerups.multiShot or activePowerups.spread
  -- Heat accrues only on non-rapid/multi/spread powerups; clamp defensively
  if not weaponPU then
    local maxHeat = player.maxHeat or 100
    local heatRate = player.heatRate or 5
    player.heat = math.min(maxHeat, math.max(0, (player.heat or 0) + heatRate * dt))
  end

  if _G.Game and Game.audioPool then Game.audioPool:play("laser", player.x, player.y) end

  local baseCD = activePowerups.rapid and 0.1 or shipCfg.fireRate
  state.shootCooldown = baseCD * (player.fireRateMultiplier or 1)

  if activePowerups.multiShot or activePowerups.spread then
    for offset = -15, 15, 30 do
      local lz = state.laserPool:get()
      if lz then
        lz.x      = player.x + offset
        lz.y      = laser.y
        lz.width  = laser.width
        lz.height = laser.height
        lz.speed  = laser.speed
        lz.vx, lz.vy = nil, nil
        lz._remove, lz.isAlien = false, false
        table.insert(lasers, lz)
        if state.laserGrid then state.laserGrid:insert(lz) end
      end
    end
  end
end

----------------------------------------------------------------------
-- INPUT BINDINGS ----------------------------------------------------
----------------------------------------------------------------------

function PlayerControl.handleKeyPress(state, key)
  local b = kbd()
  if     key == b.left  then state.keys.left  = true
  elseif key == b.right then state.keys.right = true
  elseif key == b.up    then state.keys.up    = true
  elseif key == b.down  then state.keys.down  = true
  elseif key == b.shoot then state.keys.shoot = true
  elseif key == b.boost then state.keys.boost = true
  elseif key == b.bomb  then
    PlayerControl.useBomb(state)
  end
end

function PlayerControl.handleKeyRelease(state, key)
  local b = kbd()
  if     key == b.left  then state.keys.left  = false
  elseif key == b.right then state.keys.right = false
  elseif key == b.up    then state.keys.up    = false
  elseif key == b.down  then state.keys.down  = false
  elseif key == b.shoot then state.keys.shoot = false
  elseif key == b.boost then state.keys.boost = false
  end
end

function PlayerControl.handleGamepadPress(state, button)
  local b = pad()
  if     button == b.shoot then
    -- Fire immediately and latch for continuous fire while held
    PlayerControl.shoot(state, 0)
    state.keys.shoot = true
  elseif button == b.bomb then
    PlayerControl.useBomb(state)
  elseif button == b.boost then state.keys.boost = true
  end
end

function PlayerControl.handleGamepadRelease(state, button)
  local b = pad()
  if button == b.boost then state.keys.boost = false end
  if button == b.shoot then state.keys.shoot = false end
end

----------------------------------------------------------------------
-- BOMB ACTION -------------------------------------------------------
----------------------------------------------------------------------

function PlayerControl.useBomb(state)
  if not _G.player then return end
  if not state or not state.screenBomb then return end
  if player.bombs and player.bombs > 0 then
    player.bombs = player.bombs - 1
    state:screenBomb()
  end
end

----------------------------------------------------------------------
-- HEAT PARTICLES ----------------------------------------------------
----------------------------------------------------------------------

function PlayerControl.createHeatParticle(state)
  if not state or not state.particlePool then return end
  local p = state.particlePool:get()
  if not p then return end

  p.x       = player.x + math.random(-player.width / 4, player.width / 4)
  p.y       = player.y + player.height / 2
  p.vx      = math.random(-20, 20)
  p.vy      = math.random(-80, -120)
  p.life    = math.random(0.8, 1.2)
  p.maxLife = p.life
  p.size    = math.random(3, 5)

  local hpct = player.heat / player.maxHeat
  p.color = { 1, 1 - hpct * 0.7, 0, 0.7 }

  p.type = "heat"
  p.pool = state.particlePool
  local scene = state.scene or state
  table.insert(scene.explosions or _G.explosions, p)
end

----------------------------------------------------------------------
-- MOBILE UI (stub) --------------------------------------------------
----------------------------------------------------------------------

function PlayerControl.update_mobile_ui(_buttons, _touches)
  -- Implement touch controls here if needed
end

return PlayerControl
