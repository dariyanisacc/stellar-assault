local constants = require("src.constants")
local PlayerControl = {}

-- Update player movement and heat system
function PlayerControl.update(state, dt)
    -- Thrust direction based on input
    local dx, dy = 0, 0
    if state.keys.left  then dx = dx - 1 end
    if state.keys.right then dx = dx + 1 end
    if state.keys.up    then dy = dy - 1 end
    if state.keys.down  then dy = dy + 1 end

    -- Add analog stick input
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        local joystick = joysticks[1]
        if joystick:isGamepad() then
            local jx, jy = joystick:getGamepadAxis("leftx"), joystick:getGamepadAxis("lefty")
            if math.abs(jx) > 0.2 then dx = dx + jx end
            if math.abs(jy) > 0.2 then dy = dy + jy end

            -- Right trigger for continuous shooting
            local triggerValue = joystick:getGamepadAxis("triggerright")
            if triggerValue and triggerValue > 0.5 then
                PlayerControl.shoot(state, dt)
            end
        end
    end

    -- Normalize direction
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        dx, dy = dx / len, dy / len
        local thrustMult = 1
        if activePowerups.boost then
            thrustMult = 1.5
        end
        if state.keys.boost then
            thrustMult = thrustMult * 2
        end
        player.vx = player.vx + dx * player.thrust * dt * thrustMult
        player.vy = player.vy + dy * player.thrust * dt * thrustMult
    end

    -- Apply drag
    player.vx = player.vx * (1 - player.drag * dt)
    player.vy = player.vy * (1 - player.drag * dt)

    -- Limit speed
    local speed = math.sqrt(player.vx * player.vx + player.vy * player.vy)
    local baseMaxVel = player.maxSpeed or 300  -- Use maxSpeed, not maxVelocity
    local maxVel = activePowerups.boost and baseMaxVel * 1.5 or baseMaxVel
    if speed > maxVel then
        player.vx = (player.vx / speed) * maxVel
        player.vy = (player.vy / speed) * maxVel
    end

    -- Update position
    player.x = player.x + player.vx * dt
    player.y = player.y + player.vy * dt

    -- Clamp to screen with bounce prevention
    local width, height = love.graphics.getDimensions()
    if player.x < player.width / 2 then
        player.x = player.width / 2
        player.vx = math.max(0, player.vx)
    elseif player.x > width - player.width / 2 then
        player.x = width - player.width / 2
        player.vx = math.min(0, player.vx)
    end
    if player.y < player.height / 2 then
        player.y = player.height / 2
        player.vy = math.max(0, player.vy)
    elseif player.y > height - player.height / 2 then
        player.y = height - player.height / 2
        player.vy = math.min(0, player.vy)
    end

    -- Always decrement shoot cooldown
    if state.shootCooldown and state.shootCooldown > 0 then
        state.shootCooldown = math.max(0, state.shootCooldown - dt)
    end

    -- Force free a slot if pool near full
    if state.keys.shoot and state.shootCooldown <= 0 and player.overheatTimer <= 0 and #lasers >= 95 then
        local oldLaser = table.remove(lasers, 1)
        if oldLaser and state.laserGrid then
            state.laserGrid:remove(oldLaser)
        end
        state.laserPool:release(oldLaser)
    end

    -- Always cool down heat, even while shooting
    if player.heat > 0 then
        local coolMultiplier = activePowerups.coolant and 1.5 or 1
        -- Extra cooling during overheat for faster recovery
        if player.overheatTimer > 0 then
            coolMultiplier = coolMultiplier * 2  -- Double cooling rate during overheat
        end
        player.heat = math.max(0, player.heat - player.coolRate * dt * coolMultiplier)
    end

    if player.overheatTimer > 0 then
        player.overheatTimer = player.overheatTimer - dt
        if player.overheatTimer <= 0 then
            player.heat = 0
            if state.showDebug then
                print("Overheat period ended, weapon ready!")
            end
        end
    end

    -- Update heat visual feedback
    local heatPercent = player.heat / player.maxHeat
    if heatPercent > 0.75 then
        player.color = {1, 1 - (heatPercent - 0.75) * 2, 1 - (heatPercent - 0.75) * 2}
    else
        player.color = {1, 1, 1}
    end

    if heatPercent > 0.6 then
        local particleChance = (heatPercent - 0.6) * 2.5
        if math.random() < particleChance * dt then
            PlayerControl.createHeatParticle(state)
        end
    end

    -- Continuous shooting while key is held
    if state.keys.shoot then
        PlayerControl.shoot(state, dt)
    end
end

-- Shoot a laser from the player ship
function PlayerControl.shoot(state, dt)
    dt = dt or 0
    if state.showDebug then
        print(string.format(
            "Shoot: heat=%.1f, cooldown=%.3f, overheat=%.3f, lasers=%d",
            player.heat, state.shootCooldown or 0, player.overheatTimer, #lasers
        ))
    end

    if (not state.shootCooldown or state.shootCooldown <= 0) and player.overheatTimer <= 0 then
        if player.heat >= player.maxHeat then
            player.overheatTimer = player.overheatPenalty
            if explosionSound and playPositionalSound then
                playPositionalSound(explosionSound, player.x, player.y)
            end
            if state.showDebug then
                print("OVERHEAT! Starting cooldown period")
            end
            return
        end

        local shipConfig = constants.ships[selectedShip] or constants.ships.alpha
        local spread = shipConfig.spread

        local laser = state.laserPool:get()
        if not laser then
            if state.showDebug then
                print("WARNING: Laser pool exhausted! Cannot create laser.")
            end
            return
        end

        -- Explicitly reset all properties to defaults
        laser.x = player.x
        laser.y = player.y - player.height / 2
        laser.width = constants.laser.width or 4
        laser.height = constants.laser.height or 12
        laser.speed = constants.laser.speed
        laser.vx = nil
        laser.vy = nil
        laser._remove = false
        laser.isAlien = false
        table.insert(lasers, laser)
        if state.laserGrid then
            state.laserGrid:insert(laser)
        end

        if activePowerups.homingMissile then
            missiles = missiles or {}
            table.insert(missiles, {x = player.x, y = player.y - player.height / 2, speed = 200})
        end

        if spread > 0 then
            local leftLaser = state.laserPool:get()
            if leftLaser then
                leftLaser.x = player.x
                leftLaser.y = player.y - player.height / 2
                leftLaser.width = constants.laser.width or 4
                leftLaser.height = constants.laser.height or 12
                leftLaser.speed = constants.laser.speed
                leftLaser.vx = -math.sin(spread) * constants.laser.speed
                leftLaser.vy = -math.cos(spread) * constants.laser.speed
                leftLaser._remove = false
                leftLaser.isAlien = false
                table.insert(lasers, leftLaser)
                if state.laserGrid then
                    state.laserGrid:insert(leftLaser)
                end
            end

            local rightLaser = state.laserPool:get()
            if rightLaser then
                rightLaser.x = player.x
                rightLaser.y = player.y - player.height / 2
                rightLaser.width = constants.laser.width or 4
                rightLaser.height = constants.laser.height or 12
                rightLaser.speed = constants.laser.speed
                rightLaser.vx = math.sin(spread) * constants.laser.speed
                rightLaser.vy = -math.cos(spread) * constants.laser.speed
                rightLaser._remove = false
                rightLaser.isAlien = false
                table.insert(lasers, rightLaser)
                if state.laserGrid then
                    state.laserGrid:insert(rightLaser)
                end
            end
        end

        local isWeaponPowerupActive = activePowerups.rapid or activePowerups.multiShot or activePowerups.spread
        if not isWeaponPowerupActive then
            player.heat = math.min(player.maxHeat, player.heat + player.heatRate * dt)
        end

        -- Play sound after all spawns
        if laserSound and playPositionalSound then
            playPositionalSound(laserSound, player.x, player.y)
        end

        if state.showDebug then
            print(string.format("Laser created! New heat: %.1f, total lasers: %d", player.heat, #lasers))
        end

        local baseCooldown
        if activePowerups.rapid then
            baseCooldown = 0.1 * (player.fireRateMultiplier or 1)
        else
            baseCooldown = shipConfig.fireRate * (player.fireRateMultiplier or 1)
        end

        -- Removed heat-based penalty entirely - no slowdown, only full overheat cutoff
        state.shootCooldown = baseCooldown

        if activePowerups.multiShot or activePowerups.spread then
            local leftLaser = state.laserPool:get()
            if leftLaser then
                leftLaser.x = player.x - 15
                leftLaser.y = player.y - player.height / 2
                leftLaser.width = constants.laser.width or 4
                leftLaser.height = constants.laser.height or 12
                leftLaser.speed = constants.laser.speed
                leftLaser.vx = nil
                leftLaser.vy = nil
                leftLaser._remove = false
                leftLaser.isAlien = false
                table.insert(lasers, leftLaser)
                if state.laserGrid then
                    state.laserGrid:insert(leftLaser)
                end
            end

            local rightLaser = state.laserPool:get()
            if rightLaser then
                rightLaser.x = player.x + 15
                rightLaser.y = player.y - player.height / 2
                rightLaser.width = constants.laser.width or 4
                rightLaser.height = constants.laser.height or 12
                rightLaser.speed = constants.laser.speed
                rightLaser.vx = nil
                rightLaser.vy = nil
                rightLaser._remove = false
                rightLaser.isAlien = false
                table.insert(lasers, rightLaser)
                if state.laserGrid then
                    state.laserGrid:insert(rightLaser)
                end
            end
        end
    end
end

-- Handle key press (mainly for mobile/UI)
function PlayerControl.handleKeyPress(state, key)
    if     key == "left"  then state.keys.left  = true
    elseif key == "right" then state.keys.right = true
    elseif key == "up"    then state.keys.up    = true
    elseif key == "down"  then state.keys.down  = true
    elseif key == "space" then state.keys.shoot = true
    elseif key == "lshift" or key == "rshift" then
        state.keys.boost = true
    end
end

-- Handle key release
function PlayerControl.handleKeyRelease(state, key)
    if     key == "left"  then state.keys.left  = false
    elseif key == "right" then state.keys.right = false
    elseif key == "up"    then state.keys.up    = false
    elseif key == "down"  then state.keys.down  = false
    elseif key == "space" then state.keys.shoot = false
    elseif key == "lshift" or key == "rshift" then
        state.keys.boost = false
    end
end

-- Handle gamepad press
function PlayerControl.handleGamepadPress(state, button)
    if button == "rightshoulder" then
        -- Single shot from right shoulder
        PlayerControl.shoot(state, 0)
    elseif button == "x" then
        state.keys.boost = true
    end
end

-- Handle gamepad release
function PlayerControl.handleGamepadRelease(state, button)
    if button == "x" then
        state.keys.boost = false
    end
end

-- Create a heat particle
function PlayerControl.createHeatParticle(state)
    if not state or not state.particlePool then return end
    local particle = state.particlePool:get()
    if not particle then return end

    particle.x = player.x + math.random(-player.width / 4, player.width / 4)
    particle.y = player.y + player.height / 2
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

-- Mobile UI helpers
function PlayerControl.update_mobile_ui(buttons, touches)
    -- Existing mobile UI code would go here if implemented
end

return PlayerControl
