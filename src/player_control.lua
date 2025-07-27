local constants   = require("src.constants")
local Persistence = require("src.persistence")

local PlayerControl = {}

----------------------------------------------------------------------
-- MOVEMENT, THRUST & HEAT
----------------------------------------------------------------------

function PlayerControl.update(state, dt)
  -- Aggregate keyboard input
  local dx, dy = 0, 0
  if state.keys.left  then dx = dx - 1 end
  if state.keys.right then dx = dx + 1 end
  if state.keys.up    then dy = dy - 1 end
  if state.keys.down  then dy = dy + 1 end

  -- Add analog stick input
  local joysticks = love.joystick.getJoysticks()
  if #joysticks > 0 then
    local js = joysticks[1]
    if js:isGamepad() then
      local jx, jy = js:getGamepadAxis("leftx"), js:getGamepadAxis("lefty")
      if math.abs(jx) > 0.2 then dx = dx + jx end
      if math.abs(jy) > 0.2 then dy = dy + jy end

      -- Right trigger → continuous shooting
      if js:getGamepadAxis("triggerright") > 0.5 then
        PlayerControl.shoot(state, dt)
      end
    end
  end

  -- Normalise and apply thrust
  local len = math.sqrt(dx * dx + dy * dy)
  if len > 0 then
    dx, dy = dx / len, dy / len
    local thrustMult = 1
    if activePowerups.boost then thrustMult = thrustMult * 1.5 end
    if state.keys.boost        then thrustMult = thrustMult * 2   end
    player.vx = player.vx + dx * player.thrust * dt * thrustMult
    player.vy = player.vy + dy * player.thrust * dt * thrustMult
  end

  -- Drag
  player.vx = player.vx * (1 - player.drag * dt)
  player.vy = player.vy * (1 - player.drag * dt)

  -- Clamp speed
  local speed      = math.sqrt(player.vx * player.vx + player.vy * player.vy)
  local baseMaxVel = player.maxSpeed or 300
  local maxVel     = activePowerups.boost and baseMaxVel * 1.5 or baseMaxVel
  if speed > maxVel then
    player.vx = (player.vx / speed) * maxVel
    player.vy = (player.vy / speed) * maxVel
  end

  -- Position update
  player.x = player.x + player.vx * dt
  player.y = player.y + player.vy * dt

  -- Screen clamp (wrapped to satisfy 120‑char limit)
  local w, h = love.graphics.getDimensions()

  if player.x < player.width / 2 then
    player.x = player.width / 2
    player.vx = math.max(0, player.vx)
  elseif player.x > w - player.width / 2 then
    player.x = w - player.width / 2
    player.vx = math.min(0, player.vx)
  end

  if player.y < player.height / 2 then
    player.y = player.height / 2
    player.vy = math.max(0, player.vy)
  elseif player.y > h - player.height / 2 then
    player.y = h - player.height / 2
    player.vy = math.min(0, player.vy)
  end

  -- Cooldowns & heat
  if state.shootCooldown and state.shootCooldown > 0 then
    state.shootCooldown = math.max(0, state.shootCooldown - dt)
  end

  if state.keys.shoot then PlayerControl.shoot(state, dt) end

  -- Force‑free a laser slot if pool nearly full
  if state.keys.shoot and state.shootCooldown <= 0
     and player.overheatTimer <= 0 and #lasers >= 95 then
    local old = table.remove(lasers, 1)
    if old and state.laserGrid then state.laserGrid:remove(old) end
    state.laserPool:release(old)
  end

  -- Heat dissipation
  if player.heat > 0 then
    local cool = activePowerups.coolant and 1.5 or 1
    if player.overheatTimer > 0 then cool = cool * 2 end
    player.heat = math.max(0, player.heat - player.coolRate * dt * cool)
  end

  -- Overheat timer
  if player.overheatTimer > 0 then
    player.overheatTimer = player.overheatTimer - dt
    if player.overheatTimer <= 0 then
      player.heat = 0
      if state.showDebug then print("Overheat period ended, weapon ready!") end
    end
  end

  -- Heat visual feedback
  local hpct = player.heat / player.maxHeat
  if hpct > 0.75 then
    player.color = { 1, 1 - (hpct - 0.75) * 2, 1 - (hpct - 0.75) * 2 }
  else
    player.color = { 1, 1, 1 }
  end

  -- Heat particles
  if hpct > 0.6 and math.random() < (hpct - 0.6) * 2.5 * dt then
    PlayerControl.createHeatParticle(state)
  end
end

----------------------------------------------------------------------
-- SHOOTING
----------------------------------------------------------------------

function PlayerControl.shoot(state, dt)
  dt = dt or (love.timer and love.timer.getDelta()) or 0.016

  if (state.shootCooldown and state.shootCooldown > 0) or player.overheatTimer > 0 then
    return
  end
  if player.heat >= player.maxHeat then
    player.overheatTimer = player.overheatPenalty
    if explosionSound and playPositionalSound then
      playPositionalSound(explosionSound, player.x, player.y)
    end
    if state.showDebug then print("OVERHEAT! Starting cooldown period") end
    return
  end

  -- Spawn main laser
  local shipCfg = constants.ships[selectedShip] or constants.ships.alpha
  local spread  = shipCfg.spread
  local laser   = state.laserPool:get()
  if not laser then
    if state.showDebug then print("WARNING: Laser pool exhausted!") end
    return
  end

  laser.x, laser.y  = player.x, player.y - player.height / 2
  laser.width       = constants.laser.width or 4
  laser.height      = constants.laser.height or 12
  laser.speed       = constants.laser.speed
  laser.vx, laser.vy= nil, nil
  laser._remove     = false
  laser.isAlien     = false
  table.insert(lasers, laser)
  if state.laserGrid then state.laserGrid:insert(laser) end

  -- Homing missile power‑up
  if activePowerups.homingMissile then
    missiles = missiles or {}
    table.insert(missiles, { x = laser.x, y = laser.y, speed = 200 })
  end

  -- Spread lasers
  if spread > 0 then
    for dir = -1, 1, 2 do
      local lz = state.laserPool:get()
      if lz then
        lz.x, lz.y  = laser.x, laser.y
        lz.width    = laser.width; lz.height = laser.height; lz.speed = laser.speed
        lz.vx       = dir * math.sin(spread) * lz.speed
        lz.vy       = -math.cos(spread)      * lz.speed
        lz._remove  = false; lz.isAlien = false
        table.insert(lasers, lz)
        if state.laserGrid then state.laserGrid:insert(lz) end
      end
    end
  end

  -- Heat increase (unless rapid / multi / spread override)
  local weaponPU = activePowerups.rapid or activePowerups.multiShot or activePowerups.spread
  if not weaponPU then
    player.heat = math.min(player.maxHeat, player.heat + player.heatRate * dt)
  end

  -- Sound
  if laserSound and playPositionalSound then
    playPositionalSound(laserSound, player.x, player.y)
  end

  -- Base cooldown
  local baseCD = activePowerups.rapid and 0.1 or shipCfg.fireRate
  state.shootCooldown = baseCD * (player.fireRateMultiplier or 1)

  -- Extra multi‑shot pair
  if activePowerups.multiShot or activePowerups.spread then
    for offset = -15, 15, 30 do
      local lz = state.laserPool:get()
      if lz then
        lz.x, lz.y = player.x + offset, laser.y
        lz.width, lz.height = laser.width, laser.height
        lz.speed = laser.speed; lz.vx, lz.vy = nil, nil
        lz._remove = false; lz.isAlien = false
        table.insert(lasers, lz)
        if state.laserGrid then state.laserGrid:insert(lz) end
      end
    end
  end
end

----------------------------------------------------------------------
-- INPUT BINDINGS (remappable)
----------------------------------------------------------------------

local function kbd() return Persistence.getControls().keyboard end
local function pad() return Persistence.getControls().gamepad  end

function PlayerControl.handleKeyPress(state, key)
  local b = kbd()
  if     key == b.left   then state.keys.left  = true
  elseif key == b.right  then state.keys.right = true
  elseif key == b.up     then state.keys.up    = true
  elseif key == b.down   then state.keys.down  = true
  elseif key == b.shoot  then state.keys.shoot = true
  elseif key == b.boost  then state.keys.boost = true
  end
end

function PlayerControl.handleKeyRelease(state, key)
  local b = kbd()
  if     key == b.left   then state.keys.left  = false
  elseif key == b.right  then state.keys.right = false
  elseif key == b.up     then state.keys.up    = false
  elseif key == b.down   then state.keys.down  = false
  elseif key == b.shoot  then state.keys.shoot = false
  elseif key == b.boost  then state.keys.boost = false
  end
end

function PlayerControl.handleGamepadPress(state, button)
  local b = pad()
  if     button == b.shoot then PlayerControl.shoot(state, 0)
  elseif button == b.boost then state.keys.boost = true
  end
end

function PlayerControl.handleGamepadRelease(state, button)
  local b = pad()
  if button == b.boost then state.keys.boost = false end
end

----------------------------------------------------------------------
-- HEAT PARTICLES
----------------------------------------------------------------------

function PlayerControl.createHeatParticle(state)
  if not state or not state.particlePool then return end
  local p = state.particlePool:get()
  if not p then return end

  p.x        = player.x + math.random(-player.width/4, player.width/4)
  p.y        = player.y + player.height / 2
  p.vx       = math.random(-20, 20)
  p.vy       = math.random(-80, -120)
  p.life     = math.random(0.8, 1.2)
  p.maxLife  = p.life
  p.size     = math.random(3, 5)

  local hpct = player.heat / player.maxHeat
  p.color    = { 1, 1 - hpct * 0.7, 0, 0.7 }

  p.type     = "heat"
  p.pool     = state.particlePool
  table.insert(explosions, p)
end

----------------------------------------------------------------------
-- MOBILE UI (STUB)
----------------------------------------------------------------------

function PlayerControl.update_mobile_ui(buttons, touches)
  -- Implement touch controls here if needed
end

return PlayerControl
