local constants = require("src.constants")
local PlayerControl = {}

-- Update player movement and heat system
function PlayerControl.update(state, dt)
    -- Thrust direction based on input
    local dx, dy = 0, 0
    if state.keys.left then dx = dx - 1 end
    if state.keys.right then dx = dx + 1 end
    if state.keys.up then dy = dy - 1 end
    if state.keys.down then dy = dy + 1 end

    -- Add analog stick input
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        local joystick = joysticks[1]
        if joystick:isGamepad() then
            local jx, jy = joystick:getGamepadAxis("leftx"), joystick:getGamepadAxis("lefty")
            if math.abs(jx) > 0.2 then dx = dx + jx end
            if math.abs(jy) > 0.2 then dy = dy + jy end

            -- Right trigger for single shot
            local triggerValue = joystick:getGamepadAxis("triggerright")
            if triggerValue > 0.5 then
                if not state.triggerPressed then
                    PlayerControl.shoot(state)
                    state.triggerPressed = true
                end
            else
                state.triggerPressed = false
            end
        end
    end

    -- Normalize direction
    local len = math.sqrt(dx*dx + dy*dy)
    if len > 0 then
        dx, dy = dx/len, dy/len
        local thrustMult = 1
        if activePowerups.boost then
            thrustMult = 1.75
        elseif state.keys.boost and not activePowerups.timeWarp then
            thrustMult = 1.5
        end
        player.vx = player.vx + dx * player.thrust * thrustMult * dt
        player.vy = player.vy + dy * player.thrust * thrustMult * dt
    end

    local speed = math.sqrt(player.vx^2 + player.vy^2)
    if speed > player.maxSpeed then
        player.vx = (player.vx / speed) * player.maxSpeed
        player.vy = (player.vy / speed) * player.maxSpeed
    end

    player.vx = player.vx * player.drag
    player.vy = player.vy * player.drag

    player.x = player.x + player.vx * dt
    player.y = player.y + player.vy * dt

    if player.x < -player.width/2 then
        player.x = state.screenWidth + player.width/2
    elseif player.x > state.screenWidth + player.width/2 then
        player.x = -player.width/2
    end
    if player.y < -player.height/2 then
        player.y = state.screenHeight + player.height/2
    elseif player.y > state.screenHeight + player.height/2 then
        player.y = -player.height/2
    end

    if player.teleportCooldown > 0 then
        player.teleportCooldown = player.teleportCooldown - dt
        if player.teleportCooldown <= 0 then
            player.canTeleport = true
        end
    end

    if state.shootCooldown and state.shootCooldown > 0 then
        state.shootCooldown = state.shootCooldown - dt
    end

    if not state.keys.shoot and player.heat > 0 then
        local coolMultiplier = activePowerups.coolant and 1.5 or 1
        player.heat = math.max(0, player.heat - player.coolRate * dt * coolMultiplier)
    end

    if player.overheatTimer > 0 then
        player.overheatTimer = player.overheatTimer - dt
        if player.overheatTimer <= 0 then
            player.heat = 0
        end
    end

    local heatPercent = player.heat / player.maxHeat
    if heatPercent > 0.6 then
        local particleChance = (heatPercent - 0.6) * 2.5
        if math.random() < particleChance * dt then
            PlayerControl.createHeatParticle(state)
        end
    end

    if state.keys.shoot then
        PlayerControl.shoot(state)
    end

    for powerup, timer in pairs(activePowerups) do
        activePowerups[powerup] = timer - dt
        if activePowerups[powerup] <= 0 then
            activePowerups[powerup] = nil
        end
    end
end

-- Shoot a laser from the player ship
function PlayerControl.shoot(state)
    if (not state.shootCooldown or state.shootCooldown <= 0) and player.overheatTimer <= 0 then
        if player.heat >= player.maxHeat then
            player.overheatTimer = player.overheatPenalty
            if explosionSound and playPositionalSound then
                playPositionalSound(explosionSound, player.x, player.y)
            end
            return
        end

        local shipConfig = constants.ships[selectedShip] or constants.ships.alpha
        local spread = shipConfig.spread

        local laser = state.laserPool:get()
        laser.x = player.x
        laser.y = player.y - player.height/2
        laser.speed = constants.laser.speed
        laser.isAlien = false
        table.insert(lasers, laser)
        if state.laserGrid then
            state.laserGrid:insert(laser)
        end

        if activePowerups.homingMissile then
            missiles = missiles or {}
            table.insert(missiles, {x = player.x, y = player.y - player.height/2, speed = 200})
        end

        if spread > 0 then
            local leftLaser = state.laserPool:get()
            leftLaser.x = player.x
            leftLaser.y = player.y - player.height/2
            leftLaser.speed = constants.laser.speed
            leftLaser.isAlien = false
            leftLaser.vx = -math.sin(spread) * constants.laser.speed
            leftLaser.vy = -math.cos(spread) * constants.laser.speed
            table.insert(lasers, leftLaser)
            if state.laserGrid then
                state.laserGrid:insert(leftLaser)
            end

            local rightLaser = state.laserPool:get()
            rightLaser.x = player.x
            rightLaser.y = player.y - player.height/2
            rightLaser.speed = constants.laser.speed
            rightLaser.isAlien = false
            rightLaser.vx = math.sin(spread) * constants.laser.speed
            rightLaser.vy = -math.cos(spread) * constants.laser.speed
            table.insert(lasers, rightLaser)
            if state.laserGrid then
                state.laserGrid:insert(rightLaser)
            end
        end

        local isWeaponPowerupActive = activePowerups.rapid or activePowerups.multiShot or activePowerups.spread
        if not isWeaponPowerupActive then
            player.heat = math.min(player.maxHeat, player.heat + player.heatRate)
        end

        if laserSound and playPositionalSound then
            playPositionalSound(laserSound, player.x, player.y)
        end

        local baseCooldown
        if activePowerups.rapid then
            baseCooldown = 0.1 * (player.fireRateMultiplier or 1)
        else
            baseCooldown = shipConfig.fireRate * (player.fireRateMultiplier or 1)
        end

        local heatPercent = player.heat / player.maxHeat
        if heatPercent > 0.75 then
            local penalty = 1 + (heatPercent - 0.75) * 2
            state.shootCooldown = baseCooldown * penalty
        else
            state.shootCooldown = baseCooldown
        end

        if activePowerups.multiShot or activePowerups.spread then
            local leftLaser = state.laserPool:get()
            leftLaser.x = player.x - 15
            leftLaser.y = player.y - player.height/2
            leftLaser.speed = constants.laser.speed
            leftLaser.isAlien = false
            table.insert(lasers, leftLaser)
            if state.laserGrid then
                state.laserGrid:insert(leftLaser)
            end

            local rightLaser = state.laserPool:get()
            rightLaser.x = player.x + 15
            rightLaser.y = player.y - player.height/2
            rightLaser.speed = constants.laser.speed
            rightLaser.isAlien = false
            table.insert(lasers, rightLaser)
            if state.laserGrid then
                state.laserGrid:insert(rightLaser)
            end
        end
    end
end

-- Create heat particles for high heat levels
function PlayerControl.createHeatParticle(state)
    local particle = state.particlePool:get()
    particle.x = player.x + math.random(-player.width/4, player.width/4)
    particle.y = player.y + player.height/2
    particle.vx = math.random(-20, 20)
    particle.vy = math.random(-80, -120)
    particle.life = math.random(0.8, 1.2)
    particle.maxLife = particle.life
    particle.size = math.random(3, 5)
    local heatPercent = player.heat / player.maxHeat
    local r = 1
    local g = 1 - heatPercent * 0.7
    particle.color = {r, g, 0, 0.7}
    particle.type = "heat"
    particle.pool = state.particlePool
    table.insert(explosions, particle)
end

-- Input handlers
function PlayerControl.keypressed(state, key)
    if key == state.keyBindings.pause or key == "escape" then
        gameState = "paused"
        stateManager:switch("pause")
    elseif key == "f3" then
        state.showDebug = not state.showDebug
    elseif key == state.keyBindings.shoot then
        state.keys.shoot = true
    elseif key == state.keyBindings.boost or key == "lshift" or key == "rshift" then
        state.keys.boost = true
    elseif key == state.keyBindings.left or key == "left" then
        state.keys.left = true
    elseif key == state.keyBindings.right or key == "right" then
        state.keys.right = true
    elseif key == state.keyBindings.up or key == "up" then
        state.keys.up = true
    elseif key == state.keyBindings.down or key == "down" then
        state.keys.down = true
    elseif key == state.keyBindings.bomb or key == "lctrl" or key == "rctrl" then
        if player.bombs and player.bombs > 0 then
            player.bombs = player.bombs - 1
            state:screenBomb()
        end
    end
end

function PlayerControl.keyreleased(state, key)
    if key == state.keyBindings.shoot then
        state.keys.shoot = false
        state.shootCooldown = 0
    elseif key == state.keyBindings.boost or key == "lshift" or key == "rshift" then
        state.keys.boost = false
    elseif key == state.keyBindings.left or key == "left" then
        state.keys.left = false
    elseif key == state.keyBindings.right or key == "right" then
        state.keys.right = false
    elseif key == state.keyBindings.up or key == "up" then
        state.keys.up = false
    elseif key == state.keyBindings.down or key == "down" then
        state.keys.down = false
    end
end

function PlayerControl.gamepadpressed(state, button)
    if button == "dpup" then
        state.keys.up = true
    elseif button == "dpdown" then
        state.keys.down = true
    elseif button == "dpleft" then
        state.keys.left = true
    elseif button == "dpright" then
        state.keys.right = true
    elseif button == state.gamepadBindings.shoot then
        state.keys.shoot = true
    elseif button == state.gamepadBindings.bomb then
        if player.bombs and player.bombs > 0 then
            player.bombs = player.bombs - 1
            state:screenBomb()
        end
    elseif button == state.gamepadBindings.boost then
        state.keys.boost = true
    elseif button == state.gamepadBindings.pause then
        gameState = "paused"
        stateManager:switch("pause")
    end
end

function PlayerControl.gamepadreleased(state, button)
    if button == "dpup" then
        state.keys.up = false
    elseif button == "dpdown" then
        state.keys.down = false
    elseif button == "dpleft" then
        state.keys.left = false
    elseif button == "dpright" then
        state.keys.right = false
    elseif button == state.gamepadBindings.shoot then
        state.keys.shoot = false
        state.shootCooldown = 0
    elseif button == state.gamepadBindings.boost then
        state.keys.boost = false
    end
end

return PlayerControl
