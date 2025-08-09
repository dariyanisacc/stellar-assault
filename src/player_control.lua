-- File: src/playercontrol.lua
----------------------------------------------------------------------
-- Stellar Assault - Player Control Module
-- Handles movement, shooting, heat, and input abstraction.
----------------------------------------------------------------------

local constants   = require("src.constants")
local Persistence = require("src.persistence")

local PlayerControl = {}

-- Simple WASD aliases so arrows and WASD both work by default,
-- without interfering with user-remappable bindings.
local KEY_ALIASES = {
  left  = { "a" },
  right = { "d" },
  up    = { "w" },
  down  = { "s" },
}

local function keyIn(list, k)
  if not list then return false end
  for _, v in ipairs(list) do
    if k == v then return true end
  end
  return false
end

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
    local function anyDown(primary, aliases)
      if type(primary) == "string" and primary ~= "" and love.keyboard.isDown(primary) then
        return true
      end
      if aliases then
        for _, k in ipairs(aliases) do
          if love.keyboard.isDown(k) then return true end
        end
      end
      return false
    end
    local function clearIfReleased(action, primary, aliases)
      if state.keys[action] then
        if not anyDown(primary, aliases) then
          state.keys[action] = false
        end
      end
    end
    clearIfReleased("left",  b.left,  KEY_ALIASES.left)
    clearIfReleased("right", b.right, KEY_ALIASES.right)
    clearIfReleased("up",    b.up,    KEY_ALIASES.up)
    clearIfReleased("down",  b.down,  KEY_ALIASES.down)
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
  -- Local soft-cap helper for this shot
  local __maxCapShots = (constants.balance.maxLasers or 100) - (constants.balance.softLaserMargin or 8)
  local function canSpawn()
    return #lasers < __maxCapShots
  end
  -- Soft cap helper: avoid overfilling the laser pool on burst
  local maxCapShots = (constants.balance.maxLasers or 100) - (constants.balance.softLaserMargin or 8)
  local function canSpawn()
    return #lasers < maxCapShots
  end
  local maxCapShots    = (constants.balance.maxLasers or 100) - (constants.balance.softLaserMargin or 8)
  local function canSpawn()
    return #lasers < maxCapShots
  end
  local maxCapShots    = (constants.balance.maxLasers or 100) - (constants.balance.softLaserMargin or 8)
  local function canSpawn()
    return #lasers < maxCapShots
  end

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
    if ((activePowerups.boost or 0) > 0) then thrustMult = thrustMult * 1.5 end
    if state.keys.boost      then thrustMult = thrustMult * 2   end

    player.vx = player.vx + dx * player.thrust * dt * thrustMult
    player.vy = player.vy + dy * player.thrust * dt * thrustMult
  end

  player.vx = player.vx * (1 - player.drag * dt)
  player.vy = player.vy * (1 - player.drag * dt)

  local speed      = math.sqrt(player.vx * player.vx + player.vy * player.vy)
  local baseMaxVel = player.maxSpeed or 300
  local maxVel     = (((activePowerups.boost or 0) > 0) and (baseMaxVel * 1.5)) or baseMaxVel
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
    local coolMult = (((activePowerups.coolant or 0) > 0) and 1.5) or 1
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
  
  -- Predict heat and trigger overheat BEFORE spawning if it would exceed max
  local weaponPU = ((activePowerups.rapid or 0) > 0)
               or ((activePowerups.multiShot or 0) > 0)
               or ((activePowerups.spread or 0) > 0)
  local heatAdd = weaponPU and 0 or (player.heatRate or 5)
  local maxHeat = player.maxHeat or 100
  if (player.heat or 0) + heatAdd >= maxHeat then
    player.overheatTimer = player.overheatPenalty
    if _G.Game and Game.audioPool then Game.audioPool:play("explosion", player.x, player.y) end
    if state.showDebug then print("OVERHEAT! Starting cooldown period") end
    return
  end

  local shipId = (Game and Game.selectedShip) or _G.selectedShip or "falcon"
  local shipCfg = constants.ships[shipId] or constants.ships.falcon
  local spread  = shipCfg.spread or 0
  -- Local soft-cap helper for this shot
  local __maxCapShots = (constants.balance.maxLasers or 100) - (constants.balance.softLaserMargin or 8)
  local function canSpawn()
    return #lasers < __maxCapShots
  end
  if not state.laserPool or not state.laserPool.get then return end
  if not canSpawn() then
    -- Soft-cap reached: apply cooldown but skip spawning
    local baseCDcap = (((activePowerups.rapid or 0) > 0) and 0.1) or (shipCfg.fireRate or 0.3)
    state.shootCooldown = baseCDcap * (player.fireRateMultiplier or 1)
    return
  end
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

  -- Support multiple guns (e.g., Titan twin guns)
  local guns = shipCfg.guns or 1
  if guns > 1 then
    -- Reposition first laser to left barrel and spawn a mirrored one
    -- Offset scales with rendered sprite width when available
    local offset
    do
      local ships = _G.Game and Game.playerShips
      local sid = (Game and Game.selectedShip) or _G.selectedShip
      local scale = (Game and Game.spriteScale) or 0.15
      local spr = ships and sid and ships[sid]
      if spr and spr.getWidth then
        offset = math.max(8, (spr:getWidth() * scale) * 0.22)
      end
    end
    offset = offset or math.max(8, (player.width or 20) * 0.4)
    laser.x = player.x - offset
    if canSpawn() then table.insert(lasers, laser) end
    if state.laserGrid then state.laserGrid:insert(laser) end

    local l2 = state.laserPool:get()
    if l2 then
      l2.x      = player.x + offset
      l2.y      = laser.y
      l2.width  = laser.width
      l2.height = laser.height
      l2.speed  = laser.speed
      l2.vx, l2.vy = nil, nil
      l2._remove, l2.isAlien = false, false
      if canSpawn() then table.insert(lasers, l2) end
      if state.laserGrid then state.laserGrid:insert(l2) end
      -- Angle outward slightly at high lateral speeds (visual flair)
      local spd = l2.speed or constants.laser.speed
      local mv = math.min(1, math.abs(player.vx or 0) / math.max(1, player.maxSpeed or 1))
      local frac = 0.18 * mv
      if frac > 0 then
        local vx2 = spd * frac
        local vy2 = -math.sqrt(math.max(0, spd * spd - vx2 * vx2))
        l2.vx, l2.vy = vx2, vy2
      end
    end
    -- Angle outward for left barrel as well
    do
      local spd = laser.speed or constants.laser.speed
      local mv = math.min(1, math.abs(player.vx or 0) / math.max(1, player.maxSpeed or 1))
      local frac = 0.18 * mv
      if frac > 0 then
        local vx1 = -spd * frac
        local vy1 = -math.sqrt(math.max(0, spd * spd - vx1 * vx1))
        laser.vx, laser.vy = vx1, vy1
      end
    end
  else
    if canSpawn() then table.insert(lasers, laser) end
    if state.laserGrid then state.laserGrid:insert(laser) end
  end

  if ((activePowerups.homingMissile or 0) > 0) then
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
    -- Determine barrel positions to emit spread from
    local barrelXs = { laser.x }
    if guns > 1 then
      -- Recompute right barrel X to mirror
      local off
      do
        local ships = _G.Game and Game.playerShips
        local sid = (Game and Game.selectedShip) or _G.selectedShip
        local scale = (Game and Game.spriteScale) or 0.15
        local spr = ships and sid and ships[sid]
        if spr and spr.getWidth then
          off = math.max(8, (spr:getWidth() * scale) * 0.22)
        end
      end
      off = off or math.max(8, (player.width or 20) * 0.4)
      table.insert(barrelXs, player.x + off)
    end
    for _, bx in ipairs(barrelXs) do
      for dir = -1, 1, 2 do
        if not canSpawn() then break end
        local lz = state.laserPool:get()
        if lz then
          lz.x, lz.y  = bx, laser.y
          lz.width    = laser.width
          lz.height   = laser.height
          lz.speed    = laser.speed
          lz.vx       = dir * math.sin(spread) * lz.speed
          lz.vy       = -math.cos(spread) * lz.speed
          lz._remove, lz.isAlien = false, false
          if canSpawn() then table.insert(lasers, lz) end
          if state.laserGrid then state.laserGrid:insert(lz) end
        end
      end
    end
  end

  -- Heat accrues only on non-rapid/multi/spread powerups; clamp defensively
  if not weaponPU then
    local maxHeat = player.maxHeat or 100
    local heatRate = player.heatRate or 5
    -- heatRate is defined per shot; do not multiply by dt
    player.heat = math.min(maxHeat, math.max(0, (player.heat or 0) + heatRate))
  end

  if _G.Game and Game.audioPool then Game.audioPool:play("laser", player.x, player.y) end

  local baseCD = (((activePowerups.rapid or 0) > 0) and 0.1) or shipCfg.fireRate
  state.shootCooldown = baseCD * (player.fireRateMultiplier or 1)

  if ((activePowerups.multiShot or 0) > 0) or ((activePowerups.spread or 0) > 0) then
    -- Multi-shot around each barrel
    local bases = { laser.x }
    if guns > 1 then
      local off
      do
        local ships = _G.Game and Game.playerShips
        local sid = (Game and Game.selectedShip) or _G.selectedShip
        local scale = (Game and Game.spriteScale) or 0.15
        local spr = ships and sid and ships[sid]
        if spr and spr.getWidth then
          off = math.max(8, (spr:getWidth() * scale) * 0.22)
        end
      end
      off = off or math.max(8, (player.width or 20) * 0.4)
      table.insert(bases, player.x + off)
    end
    for _, baseX in ipairs(bases) do
      for offset = -15, 15, 30 do
        if not canSpawn() then break end
        local lz = state.laserPool:get()
        if lz then
          lz.x      = baseX + offset
          lz.y      = laser.y
          lz.width  = laser.width
          lz.height = laser.height
          lz.speed  = laser.speed
          lz.vx, lz.vy = nil, nil
          lz._remove, lz.isAlien = false, false
          if canSpawn() then table.insert(lasers, lz) end
          if state.laserGrid then state.laserGrid:insert(lz) end
        end
      end
    end
  end
end

----------------------------------------------------------------------
-- INPUT BINDINGS ----------------------------------------------------
----------------------------------------------------------------------

function PlayerControl.handleKeyPress(state, key)
  local b = kbd()
  if     key == b.left  or keyIn(KEY_ALIASES.left,  key) then state.keys.left  = true
  elseif key == b.right or keyIn(KEY_ALIASES.right, key) then state.keys.right = true
  elseif key == b.up    or keyIn(KEY_ALIASES.up,    key) then state.keys.up    = true
  elseif key == b.down  or keyIn(KEY_ALIASES.down,  key) then state.keys.down  = true
  elseif key == b.shoot then state.keys.shoot = true
  elseif key == b.boost then state.keys.boost = true
  elseif key == b.bomb  then
    PlayerControl.useBomb(state)
  end
end

function PlayerControl.handleKeyRelease(state, key)
  local b = kbd()
  local function stillHeld(primary, aliases)
    if love and love.keyboard and love.keyboard.isDown then
      if type(primary) == "string" and primary ~= "" and love.keyboard.isDown(primary) then return true end
      if aliases then
        for _, k in ipairs(aliases) do if love.keyboard.isDown(k) then return true end end
      end
    end
    return false
  end
  if key == b.left or keyIn(KEY_ALIASES.left, key) then
    if not stillHeld(b.left, KEY_ALIASES.left) then state.keys.left = false end
  elseif key == b.right or keyIn(KEY_ALIASES.right, key) then
    if not stillHeld(b.right, KEY_ALIASES.right) then state.keys.right = false end
  elseif key == b.up or keyIn(KEY_ALIASES.up, key) then
    if not stillHeld(b.up, KEY_ALIASES.up) then state.keys.up = false end
  elseif key == b.down or keyIn(KEY_ALIASES.down, key) then
    if not stillHeld(b.down, KEY_ALIASES.down) then state.keys.down = false end
  elseif key == b.shoot then
    state.keys.shoot = false
  elseif key == b.boost then
    state.keys.boost = false
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
