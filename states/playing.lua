-- Playing State for Stellar Assault
local constants = require("src.constants")
local ObjectPool = require("src.objectpool")
local Collision = require("src.collision")
local logger = require("src.logger")
local Powerup = require("src.entities.powerup")
local Persistence = require("src.persistence")
local WaveManager = require("src.wave_manager")
local lg = love.graphics
local la = love.audio
local lm = love.math or math

local PlayingState = {}

-- Cached globals
local random = lm.random or math.random
local min = math.min
local max = math.max
local abs = math.abs
local sin = math.sin
local cos = math.cos
local pi = math.pi

function PlayingState:enter(params)
    -- Check if we're resuming from pause
    if params and params.resume then
        -- Just update screen dimensions when resuming
        self.screenWidth = lg.getWidth()
        self.screenHeight = lg.getHeight()
        return  -- Skip initialization
    end
    
    -- Initialize game objects (only on fresh start)
    self:initializeGame()
    
    -- Load control bindings
    self.keyBindings = Persistence.getControls().keyboard
    self.gamepadBindings = Persistence.getControls().gamepad
    
    -- Create camera
    local Camera = require("src.camera")
    self.camera = Camera:new()
    
    -- Create object pools
    self.laserPool = ObjectPool.createLaserPool()
    self.explosionPool = ObjectPool.createExplosionPool()
    self.particlePool = ObjectPool.createParticlePool()
    
    -- Initialize WaveManager
    self.waveManager = WaveManager:new(player)
    self.waveManager:setWaveCompleteCallback(function(waveNumber)
        -- Handle wave completion
        score = score + 500 * waveNumber
        logger.info("Wave " .. waveNumber .. " complete! Bonus: " .. (500 * waveNumber))
        
        -- Start next wave after a delay
        self.waveStartTimer = 2.0  -- 2 second delay between waves
    end)
    
    -- Set shoot callback to integrate with existing laser system
    self.waveManager:setShootCallback(function(laser)
        -- Add enemy laser to the alienLasers array
        table.insert(alienLasers, laser)
    end)
    
    -- Start first wave
    self.waveManager:startWave(1)
    self.waveStartTimer = 0
    
    -- Initialize flash effects
    self.playerHitFlash = 0
    self.bossHitFlash = 0
    self.flashColor = {1, 1, 1}  -- White flash
    
    -- Track statistics
    self.sessionStartTime = love.timer.getTime()
    self.sessionEnemiesDefeated = 0
    
    -- New high score tracking
    self.newHighScore = false
    self.previousHighScore = Persistence.getHighScore()
    
    -- Start background music
    if backgroundMusic then
        backgroundMusic:setLooping(true)
        backgroundMusic:setVolume(musicVolume * masterVolume)
        backgroundMusic:play()
    end
end

function PlayingState:leave()
    -- Clean up
    if backgroundMusic then
        backgroundMusic:stop()
    end
    
    -- Release all pooled objects
    self.laserPool:releaseAll()
    self.explosionPool:releaseAll()
    self.particlePool:releaseAll()
end

function PlayingState:initializeGame()
    -- Screen dimensions
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
    
    -- Player initialization with ship-specific stats
    local shipConfig = constants.ships[selectedShip] or constants.ships.alpha
    
    -- Apply shop upgrades
    local speedUpgrade = 1 + (Persistence.getUpgradeLevel("speedMultiplier") or 0)
    local shieldUpgrade = Persistence.getUpgradeLevel("maxShield") or 0
    local bombUpgrade = Persistence.getUpgradeLevel("bombCapacity") or 0
    
    player = {
        x = self.screenWidth / 2,
        y = self.screenHeight - 100,
        width = constants.player.width,
        height = constants.player.height,
        speed = constants.player.speed * shipConfig.speedMultiplier * speedUpgrade,
        shield = math.floor(constants.player.shield * shipConfig.shieldMultiplier) + shieldUpgrade,
        maxShield = math.floor(constants.player.maxShield * shipConfig.shieldMultiplier) + shieldUpgrade,
        teleportCooldown = 0,
        canTeleport = true,
        isTeleporting = false,
        teleportX = 0,
        teleportY = 0,
        bombs = 3 + bombUpgrade,  -- Starting bomb count + upgrades
        fireRateMultiplier = 1 - (Persistence.getUpgradeLevel("fireRateMultiplier") or 0),  -- Lower is faster
        -- Inertia physics
        vx = 0,
        vy = 0,
        thrust = constants.player.thrust * shipConfig.speedMultiplier * speedUpgrade,
        maxSpeed = constants.player.maxSpeed * shipConfig.speedMultiplier * speedUpgrade,
        drag = constants.player.drag,
        -- Heat system
        heat = 0,                -- Current heat level (0-100)
        maxHeat = 100,           -- Max before overheat
        heatRate = 4 * (shipConfig.heatMultiplier or 1),  -- Heat added per shot (adjusted by ship type) - reduced from 10 to 4
        coolRate = 30,           -- Cooling per second when not shooting - increased from 20 to 30
        overheatPenalty = 2,     -- Seconds unable to shoot on overheat
        overheatTimer = 0        -- Timer when overheated
    }
    
    -- Game state
    score = 0
    lives = constants.player.lives + (Persistence.getUpgradeLevel("extraLives") or 0)
    invulnerableTime = 0
    enemiesDefeated = 0
    levelComplete = false
    bossSpawned = false
    gameComplete = false
    
    -- Make gameComplete global for gameover state
    _G.gameComplete = false
    
    -- Initialize currentLevel if not set
    if not currentLevel then
        currentLevel = 1
    end
    
    -- Entity arrays
    asteroids = {}
    aliens = {}
    lasers = {}
    alienLasers = {}
    explosions = {}
    powerups = {}
    powerupTexts = {}
    activePowerups = {}
    
    -- Boss
    boss = nil
    
    -- Timers
    self.asteroidTimer = 0
    self.alienTimer = 0
    self.powerupTimer = 0
    
    -- Input state
    self.keys = {
        left = false,
        right = false,
        up = false,
        down = false,
        shoot = false,
        boost = false
    }
    
    -- Trigger state
    self.triggerPressed = false
    
    -- Combo system
    self.combo = 0
    self.comboTimer = 0
    self.comboMultiplier = 1
    
    -- UI state
    self.showControlsHint = true
    self.controlsHintTimer = 30  -- Show for 30 seconds
    self.controlsHintAlpha = 1
    self.previousScore = score  -- For score animation
    self.scoreAnimTimer = 0
    self.scoreAnimScale = 1
end

function PlayingState:update(dt)
    if gameState == "paused" then return end
    
    -- Update screen dimensions
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
    
    -- Update camera
    if self.camera then
        self.camera:update(dt)
    end
    
    -- Update combo timer
    if self.comboTimer > 0 then
        self.comboTimer = self.comboTimer - dt
        if self.comboTimer <= 0 then
            self.combo = 0
            self.comboMultiplier = 1
        end
    end
    
    -- Update UI timers
    if self.showControlsHint and self.controlsHintTimer > 0 then
        self.controlsHintTimer = self.controlsHintTimer - dt
        if self.controlsHintTimer <= 3 then  -- Fade out in last 3 seconds
            self.controlsHintAlpha = self.controlsHintTimer / 3
        end
        if self.controlsHintTimer <= 0 then
            self.showControlsHint = false
        end
    end
    
    -- Update score animation
    if score ~= self.previousScore then
        self.scoreAnimTimer = 0.3
        self.scoreAnimScale = 1.2
        self.previousScore = score
    end
    if self.scoreAnimTimer > 0 then
        self.scoreAnimTimer = self.scoreAnimTimer - dt
        self.scoreAnimScale = 1 + (self.scoreAnimTimer / 0.3) * 0.2
    end
    
    -- Update timers
    if invulnerableTime > 0 then
        invulnerableTime = invulnerableTime - dt
    end
    
    -- Update flash effects
    if self.playerHitFlash > 0 then
        self.playerHitFlash = self.playerHitFlash - dt * 4  -- Fade out quickly
    end
    if self.bossHitFlash > 0 then
        self.bossHitFlash = self.bossHitFlash - dt * 6  -- Boss flash fades faster
    end
    
    -- Update player
    self:updatePlayer(dt)
    
    -- Update entities
    self:updateAsteroids(dt)
    self:updateAliens(dt)
    self:updateLasers(dt)
    self:updateExplosions(dt)
    self:updatePowerups(dt)
    self:updatePowerupTexts(dt)
    
    -- Update WaveManager
    if self.waveManager then
        self.waveManager:update(dt)
        
        -- Handle wave start timer
        if self.waveStartTimer and self.waveStartTimer > 0 then
            self.waveStartTimer = self.waveStartTimer - dt
            if self.waveStartTimer <= 0 and not self.waveManager:isActive() then
                self.waveManager:startWave()
            end
        end
        
        -- Safety check: Force all enemies to spawn from top (in case any spawn from bottom)
        for _, enemy in ipairs(self.waveManager.enemies) do
            if enemy.y > self.screenHeight - 50 then  -- If spawned near bottom
                enemy.y = -enemy.height  -- Reset to top
                enemy.vy = nil  -- Clear any upward velocity
            end
        end
    end
    
    -- Update boss if exists
    if boss then
        self:updateBoss(dt)
    end
    
    -- Spawn entities
    self:spawnEntities(dt)
    
    -- Check collisions
    self:checkCollisions()
    
    -- Check win/lose conditions
    self:checkGameConditions()
end

function PlayingState:updatePlayer(dt)
    -- Thrust direction based on input
    local dx, dy = 0, 0
    if self.keys.left then dx = dx - 1 end
    if self.keys.right then dx = dx + 1 end
    if self.keys.up then dy = dy - 1 end
    if self.keys.down then dy = dy + 1 end
    
    -- Add analog stick input
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        local joystick = joysticks[1]
        if joystick:isGamepad() then
            local jx, jy = joystick:getGamepadAxis("leftx"), joystick:getGamepadAxis("lefty")
            -- Dead zone of 0.2
            if abs(jx) > 0.2 then dx = dx + jx end
            if abs(jy) > 0.2 then dy = dy + jy end
            
            -- Right trigger for shooting (single shot on press)
            local triggerValue = joystick:getGamepadAxis("triggerright")
            if triggerValue > 0.5 then
                if not self.triggerPressed then
                    self:shootLaser()
                    self.triggerPressed = true
                end
            else
                self.triggerPressed = false
            end
        end
    end
    
    -- Normalize direction vector
    local len = math.sqrt(dx*dx + dy*dy)
    if len > 0 then
        dx, dy = dx/len, dy/len
        
        -- Apply thrust (with boost modifier)
        local thrustMult = 1
        if activePowerups.boost then
            thrustMult = 1.75
        elseif self.keys.boost and not activePowerups.timeWarp then
            thrustMult = 1.5
        end
        
        player.vx = player.vx + dx * player.thrust * thrustMult * dt
        player.vy = player.vy + dy * player.thrust * thrustMult * dt
    end
    
    -- Cap speed
    local speed = math.sqrt(player.vx^2 + player.vy^2)
    if speed > player.maxSpeed then
        player.vx = (player.vx / speed) * player.maxSpeed
        player.vy = (player.vy / speed) * player.maxSpeed
    end
    
    -- Apply drag
    player.vx = player.vx * player.drag
    player.vy = player.vy * player.drag
    
    -- Update position
    player.x = player.x + player.vx * dt
    player.y = player.y + player.vy * dt
    
    -- Screen wrapping
    if player.x < -player.width/2 then
        player.x = self.screenWidth + player.width/2
    elseif player.x > self.screenWidth + player.width/2 then
        player.x = -player.width/2
    end
    
    if player.y < -player.height/2 then
        player.y = self.screenHeight + player.height/2
    elseif player.y > self.screenHeight + player.height/2 then
        player.y = -player.height/2
    end
    
    -- Update teleport cooldown
    if player.teleportCooldown > 0 then
        player.teleportCooldown = player.teleportCooldown - dt
        if player.teleportCooldown <= 0 then
            player.canTeleport = true
        end
    end
    
    -- Update shoot cooldown
    if self.shootCooldown and self.shootCooldown > 0 then
        self.shootCooldown = self.shootCooldown - dt
    end
    
    -- Cool down heat when not shooting
    if not self.keys.shoot and player.heat > 0 then
        -- Apply coolant boost if active
        local coolMultiplier = activePowerups.coolant and 1.5 or 1
        player.heat = math.max(0, player.heat - player.coolRate * dt * coolMultiplier)
    end
    
    -- Handle overheat timer
    if player.overheatTimer > 0 then
        player.overheatTimer = player.overheatTimer - dt
        if player.overheatTimer <= 0 then
            player.heat = 0  -- Reset heat after penalty
        end
    end
    
    -- Create heat particles when heat is high
    local heatPercent = player.heat / player.maxHeat
    if heatPercent > 0.6 then
        -- More particles at higher heat
        local particleChance = (heatPercent - 0.6) * 2.5  -- 0 to 1 chance
        if random() < particleChance * dt then
            self:createHeatParticle()
        end
    end
    
    -- Handle shooting
    if self.keys.shoot then
        self:shootLaser()
    end
    
    -- Update powerup effects
    for powerup, timer in pairs(activePowerups) do
        activePowerups[powerup] = timer - dt
        if activePowerups[powerup] <= 0 then
            activePowerups[powerup] = nil
            -- Shield powerup is instant, no timer to track
        end
    end
end

function PlayingState:updateAsteroids(dt)
    local baseSpeed = constants.asteroid.baseSpeed
    local speedIncrease = constants.asteroid.speedIncrease
    local levelMultiplier = constants.levels.asteroidSpeedMultiplier[min(currentLevel, 5)]
    
    for i = #asteroids, 1, -1 do
        local asteroid = asteroids[i]
        
        -- Handle fragment movement (from splitting)
        if asteroid.vx then
            asteroid.x = asteroid.x + asteroid.vx * dt
            asteroid.vx = asteroid.vx * 0.98  -- Slight friction
            
            -- Wrap horizontally
            if asteroid.x < -asteroid.size then
                asteroid.x = self.screenWidth + asteroid.size
            elseif asteroid.x > self.screenWidth + asteroid.size then
                asteroid.x = -asteroid.size
            end
        end
        
        if asteroid.vy then
            asteroid.y = asteroid.y + asteroid.vy * dt
            -- Fragments still fall but with their initial velocity
            asteroid.vy = asteroid.vy + (baseSpeed * 0.5) * dt  -- Add gravity effect
        else
            -- Normal asteroid falling
            asteroid.y = asteroid.y + (baseSpeed + speedIncrease * currentLevel) * levelMultiplier * dt
        end
        
        asteroid.rotation = asteroid.rotation + asteroid.rotationSpeed * dt
        
        -- Remove if off screen (bottom only)
        if asteroid.y > self.screenHeight + asteroid.size then
            table.remove(asteroids, i)
        end
    end
end

function PlayingState:updateAliens(dt)
    -- Update original aliens (for backward compatibility)
    for i = #aliens, 1, -1 do
        local alien = aliens[i]
        
        -- Movement based on velocity
        if alien.vx then
            alien.x = alien.x + alien.vx * dt
        else
            -- Legacy movement for old aliens
            alien.y = alien.y + constants.alien.speed * dt
        end
        
        if alien.vy then
            -- Force downward movement
            alien.vy = math.abs(alien.vy)
            alien.y = alien.y + alien.vy * dt
        end
        
        -- Simple side-to-side or up-down wave movement
        alien.waveTimer = alien.waveTimer + dt
        if alien.vx and alien.vx ~= 0 then
            -- Moving horizontally, wave vertically
            alien.y = alien.y + sin(alien.waveTimer * 2) * 30 * dt
        else
            -- Moving vertically, wave horizontally
            alien.x = alien.x + sin(alien.waveTimer * 2) * 50 * dt
        end
        
        -- Shooting
        alien.shootTimer = alien.shootTimer - dt
        if alien.shootTimer <= 0 then
            self:alienShoot(alien)
            alien.shootTimer = constants.alien.shootInterval
        end
        
        -- Remove if off screen in any direction
        if alien.y > self.screenHeight + alien.height or 
           alien.y < -alien.height or
           alien.x > self.screenWidth + alien.width or 
           alien.x < -alien.width then
            table.remove(aliens, i)
        end
    end
end

function PlayingState:updateLasers(dt)
    -- Limit laser count for performance
    local maxLasers = 100
    if #lasers > maxLasers then
        -- Remove oldest lasers
        for i = 1, #lasers - maxLasers do
            self.laserPool:release(lasers[1])
            table.remove(lasers, 1)
        end
    end
    
    -- Log warning if approaching capacity
    if #lasers > 90 then
        logger.warn("Laser pool near capacity: %d / %d", #lasers, maxLasers)
    end
    
    -- Update player lasers
    for i = #lasers, 1, -1 do
        local laser = lasers[i]
        
        -- Update position based on velocity if it exists (for spread shots)
        if laser.vx and laser.vy then
            laser.x = laser.x + laser.vx * dt
            laser.y = laser.y + laser.vy * dt
        else
            -- Regular straight laser movement
            laser.y = laser.y - constants.laser.speed * dt
        end
        
        -- Screen wrapping for lasers (horizontal only)
        if laser.x < -laser.width then
            laser.x = self.screenWidth + laser.width
        elseif laser.x > self.screenWidth + laser.width then
            laser.x = -laser.width
        end
        
        -- Remove if off screen (vertical only)
        if laser.y < -laser.height or laser.y > self.screenHeight + laser.height then
            self.laserPool:release(laser)
            table.remove(lasers, i)
        end
    end
    
    -- Update alien lasers
    for i = #alienLasers, 1, -1 do
        local laser = alienLasers[i]
        
        -- Update position based on velocity if it exists (for boss lasers)
        if laser.vx and laser.vy then
            laser.x = laser.x + laser.vx * dt
            laser.y = laser.y + laser.vy * dt
        else
            -- Regular alien laser movement
            laser.y = laser.y + constants.laser.speed * 0.7 * dt
        end
        
        -- Remove if off screen
        if laser.y > self.screenHeight + laser.height or
           laser.y < -laser.height or
           laser.x < -laser.width or
           laser.x > self.screenWidth + laser.width then
            self.laserPool:release(laser)
            table.remove(alienLasers, i)
        end
    end
end

function PlayingState:updateExplosions(dt)
    -- Limit explosion/particle count for performance
    local maxExplosions = 200
    if #explosions > maxExplosions then
        -- Remove oldest explosions/particles
        for i = 1, #explosions - maxExplosions do
            if explosions[1].vx then
                self.particlePool:release(explosions[1])
            else
                self.explosionPool:release(explosions[1])
            end
            table.remove(explosions, 1)
        end
    end
    
    for i = #explosions, 1, -1 do
        local explosion = explosions[i]
        
        -- Check if it's a particle or explosion
        if explosion.vx then
            -- It's a particle
            explosion.x = explosion.x + explosion.vx * dt
            explosion.y = explosion.y + explosion.vy * dt
            explosion.life = explosion.life - dt
            
            -- Apply gravity and drag
            explosion.vy = explosion.vy + 100 * dt  -- Gravity
            explosion.vx = explosion.vx * (1 - dt)  -- Drag
            explosion.vy = explosion.vy * (1 - dt)  -- Drag
            
            -- Rotate debris particles
            if explosion.rotation then
                explosion.rotation = explosion.rotation + (explosion.rotationSpeed or 0) * dt
            end
            
            -- Fade out particles
            if explosion.color and explosion.life < 0.3 then
                explosion.color[4] = explosion.life / 0.3
            end
            
            if explosion.life <= 0 then
                self.particlePool:release(explosion)
                table.remove(explosions, i)
            end
        else
            -- It's a regular explosion
            explosion.radius = explosion.radius + explosion.speed * dt
            explosion.alpha = explosion.alpha - dt
            
            if explosion.alpha <= 0 then
                self.explosionPool:release(explosion)
                table.remove(explosions, i)
            end
        end
    end
end

function PlayingState:updatePowerups(dt)
    for i = #powerups, 1, -1 do
        local powerup = powerups[i]
        powerup:update(dt)
        
        if powerup.y > self.screenHeight + powerup.height then
            table.remove(powerups, i)
        end
    end
end

function PlayingState:updatePowerupTexts(dt)
    for i = #powerupTexts, 1, -1 do
        local text = powerupTexts[i]
        text.y = text.y - 50 * dt
        text.life = text.life - dt
        
        if text.life <= 0 then
            table.remove(powerupTexts, i)
        end
    end
end

function PlayingState:shootLaser()
    if (not self.shootCooldown or self.shootCooldown <= 0) and player.overheatTimer <= 0 then
        -- Check if overheated
        if player.heat >= player.maxHeat then
            player.overheatTimer = player.overheatPenalty
            -- Play overheat sound effect
            if explosionSound then 
                explosionSound:stop()
                explosionSound:play() 
            end
            return
        end
        
        -- Get ship configuration
        local shipConfig = constants.ships[selectedShip] or constants.ships.alpha
        local spread = shipConfig.spread
        
        -- Create center laser
        local laser = self.laserPool:get()
        laser.x = player.x
        laser.y = player.y - player.height/2
        laser.speed = constants.laser.speed
        laser.isAlien = false
        
        table.insert(lasers, laser)
        
        -- Add spread shots based on ship type
        if spread > 0 then
            -- Left spread shot
            local leftLaser = self.laserPool:get()
            leftLaser.x = player.x
            leftLaser.y = player.y - player.height/2
            leftLaser.speed = constants.laser.speed
            leftLaser.isAlien = false
            -- Apply spread angle for velocity
            leftLaser.vx = -sin(spread) * constants.laser.speed
            leftLaser.vy = -cos(spread) * constants.laser.speed
            table.insert(lasers, leftLaser)
            
            -- Right spread shot
            local rightLaser = self.laserPool:get()
            rightLaser.x = player.x
            rightLaser.y = player.y - player.height/2
            rightLaser.speed = constants.laser.speed
            rightLaser.isAlien = false
            -- Apply spread angle for velocity
            rightLaser.vx = sin(spread) * constants.laser.speed
            rightLaser.vy = -cos(spread) * constants.laser.speed
            table.insert(lasers, rightLaser)
        end
        
        -- NEW: Skip heat addition during weapon powerups
        local isWeaponPowerupActive = activePowerups.rapid or activePowerups.multiShot or activePowerups.spread
        if not isWeaponPowerupActive then
            -- Add heat (reduced rate for balance)
            player.heat = math.min(player.maxHeat, player.heat + player.heatRate)
        end
        
        if laserSound then
            laserSound:stop()
            laserSound:play()
        end
        
        -- Set cooldown based on ship fireRate and powerups
        local baseCooldown
        if activePowerups.rapid then
            baseCooldown = 0.1 * (player.fireRateMultiplier or 1)
        else
            baseCooldown = shipConfig.fireRate * (player.fireRateMultiplier or 1)
        end
        
        -- Apply graduated heat penalty to fire rate
        local heatPercent = player.heat / player.maxHeat
        if heatPercent > 0.75 then
            -- Gradually slow fire rate as heat increases above 75%
            -- At 75% heat: no penalty, at 100% heat: 50% slower fire rate
            local penalty = 1 + (heatPercent - 0.75) * 2
            self.shootCooldown = baseCooldown * penalty
        else
            self.shootCooldown = baseCooldown
        end
        
        -- Multi-shot powerup (adds additional shots to the sides)
        -- Check both for backward compatibility
        if activePowerups.multiShot or activePowerups.spread then
            local leftLaser = self.laserPool:get()
            leftLaser.x = player.x - 15
            leftLaser.y = player.y - player.height/2
            leftLaser.speed = constants.laser.speed
            leftLaser.isAlien = false
            table.insert(lasers, leftLaser)
            
            local rightLaser = self.laserPool:get()
            rightLaser.x = player.x + 15
            rightLaser.y = player.y - player.height/2
            rightLaser.speed = constants.laser.speed
            rightLaser.isAlien = false
            table.insert(lasers, rightLaser)
        end
    end
end

function PlayingState:alienShoot(alien)
    local laser = self.laserPool:get()
    laser.x = alien.x
    laser.y = alien.y + alien.height/2
    laser.speed = constants.laser.speed * 0.7
    laser.isAlien = true
    
    table.insert(alienLasers, laser)
end

function PlayingState:spawnEntities(dt)
    -- Update spawn timers
    self.asteroidTimer = self.asteroidTimer + dt
    self.alienTimer = self.alienTimer + dt
    self.powerupTimer = self.powerupTimer + dt
    
    -- Spawn asteroids
    local asteroidInterval = constants.asteroid.spawnInterval / min(currentLevel, 5)
    if self.asteroidTimer >= asteroidInterval then
        self:spawnAsteroid()
        self.asteroidTimer = 0
    end
    
    -- Note: Alien spawning is now handled by WaveManager
    -- The old alien spawning logic has been replaced
    
    -- Spawn powerups
    if self.powerupTimer >= 10 then
        if random() < 0.3 then
            self:spawnPowerup()
        end
        self.powerupTimer = 0
    end
    
    -- Check for boss spawn
    if not bossSpawned and not boss then
        local enemiesNeeded = constants.levels.enemiesForBoss[min(currentLevel, 5)]
        if enemiesDefeated >= enemiesNeeded then
            self:spawnBoss()
        end
    end
end

function PlayingState:spawnAsteroid()
    local size = random(constants.asteroid.minSize, constants.asteroid.maxSize)
    local asteroid = {
        x = random(size, self.screenWidth - size),
        y = -size,
        size = size,
        rotation = random() * pi * 2,
        rotationSpeed = random() - 0.5
    }
    table.insert(asteroids, asteroid)
end

function PlayingState:spawnAlien()
    local direction = "top"  -- Force top-only spawning (Galaga-style)

    local alien = {
        width = constants.alien.width,
        height = constants.alien.height,
        shootTimer = constants.alien.shootInterval,
        waveTimer = random() * pi * 2
    }
    
    -- Only top spawning: start above screen, move downward with horizontal waving
    alien.x = random(40, self.screenWidth - 40)
    alien.y = -alien.height
    alien.vy = constants.alien.speed  -- Move downward
    alien.vx = 0  -- No initial horizontal velocity (waving handled in update)
    
    table.insert(aliens, alien)
end

function PlayingState:spawnPowerup(x, y)
    -- Use provided coordinates or random position
    x = x or random(30, self.screenWidth - 30)
    y = y or -30
    
    -- Use the new powerup entity with new types
    local types = {"shield", "rapid", "spread"}
    if currentLevel >= 2 then
        table.insert(types, "boost")
        table.insert(types, "coolant")  -- Add coolant powerup from level 2
    end
    if currentLevel >= 3 then
        table.insert(types, "bomb")
    end
    if currentLevel >= 4 then
        table.insert(types, "health")
    end
    
    -- Roguelike variation: rare chance for enhanced powerups
    local isEnhanced = random() < 0.1  -- 10% chance for enhanced version
    
    local powerupType = types[random(#types)]
    local powerup = Powerup.new(x, y, powerupType)
    
    -- Apply roguelike enhancements
    if isEnhanced then
        powerup.enhanced = true
        powerup.color = {powerup.color[1], powerup.color[2], powerup.color[3], 1}  -- Brighter color
        -- Enhanced effects will be handled in collision
    end
    
    table.insert(powerups, powerup)
end

-- Make spawn functions globally accessible for debug console
_G.spawnAsteroid = function() 
    if stateManager.currentName == "playing" then
        stateManager.current:spawnAsteroid()
    end
end

_G.spawnAlien = function()
    if stateManager.currentName == "playing" then
        stateManager.current:spawnAlien()
    end
end

_G.spawnPowerup = function()
    if stateManager.currentName == "playing" then
        stateManager.current:spawnPowerup()
    end
end

_G.spawnBoss = function()
    if stateManager.currentName == "playing" then
        stateManager.current:spawnBoss()
    end
end

function PlayingState:checkCollisions()
    self:checkPlayerCollisions()
    self:checkLaserCollisions()
    self:checkPowerupCollisions()
    self:checkAlienCollisions()
    
    if boss then
        self:checkBossCollisions()
    end
end

function PlayingState:checkPlayerCollisions()
    if invulnerableTime > 0 then return end
    
    -- Player vs Asteroids
    for i = #asteroids, 1, -1 do
        local asteroid = asteroids[i]
        if Collision.checkAABB(player, asteroid) then
            if activePowerups.shield then
                self:handleShieldHit(asteroid, i)
            else
                self:handlePlayerHit(asteroid, i)
            end
        end
    end
    
    -- Player vs Aliens
    for i = #aliens, 1, -1 do
        local alien = aliens[i]
        if Collision.checkAABB(player, alien) then
            if activePowerups.shield then
                self:handleShieldHit(alien, i, aliens)
            else
                self:handlePlayerHit(alien, i, aliens)
            end
        end
    end
    
    -- Player vs Alien Lasers
    for i = #alienLasers, 1, -1 do
        local laser = alienLasers[i]
        if Collision.checkAABB(player, laser) then
            if not activePowerups.shield then
                self:playerHit()
            end
            self.laserPool:release(laser)
            table.remove(alienLasers, i)
        end
    end
    
    -- Player vs WaveManager enemies
    if self.waveManager then
        for i = #self.waveManager.enemies, 1, -1 do
            local enemy = self.waveManager.enemies[i]
            if Collision.checkAABB(player, enemy) then
                if activePowerups.shield then
                    -- Destroy enemy and break shield
                    local enemySize = math.max(enemy.width, enemy.height)
                    self:createExplosion(enemy.x + enemy.width/2, enemy.y + enemy.height/2, enemySize)
                    enemy.active = false
                    table.remove(self.waveManager.enemies, i)
                    activePowerups.shield = nil
                    if shieldBreakSound then
                        shieldBreakSound:play()
                    end
                else
                    -- Player takes damage
                    self:playerHit()
                    -- Destroy enemy
                    local enemySize = math.max(enemy.width, enemy.height)
                    self:createExplosion(enemy.x + enemy.width/2, enemy.y + enemy.height/2, enemySize)
                    enemy.active = false
                    table.remove(self.waveManager.enemies, i)
                end
            end
        end
    end
end

function PlayingState:checkLaserCollisions()
    -- Player lasers vs Asteroids
    for i = #lasers, 1, -1 do
        local laser = lasers[i]
        local hit = false
        
        -- Check asteroids
        for j = #asteroids, 1, -1 do
            local asteroid = asteroids[j]
            if Collision.checkAABB(laser, asteroid) then
                self:createHitEffect(laser.x, laser.y)  -- Add hit spark effect
                self:handleAsteroidDestruction(asteroid, j)
                self.laserPool:release(laser)
                table.remove(lasers, i)
                hit = true
                break
            end
        end
        
        if not hit then
            -- Check aliens
            for j = #aliens, 1, -1 do
                local alien = aliens[j]
                if Collision.checkAABB(laser, alien) then
                    self:createHitEffect(laser.x, laser.y)  -- Add hit spark effect
                    self:handleAlienDestruction(alien, j)
                    self.laserPool:release(laser)
                    table.remove(lasers, i)
                    hit = true
                    break
                end
            end
        end
        
        -- Check WaveManager enemies
        if not hit and self.waveManager then
            local destroyedEnemy, enemyIndex = self.waveManager:checkCollisionsWithLasers(lasers)
            if destroyedEnemy then
                -- Handle enemy destruction
                local enemySize = math.max(destroyedEnemy.width, destroyedEnemy.height)
                self:createExplosion(destroyedEnemy.x + destroyedEnemy.width/2, 
                                   destroyedEnemy.y + destroyedEnemy.height/2, enemySize)
                if explosionSound then
                    explosionSound:clone():play()
                end
                local enemyScore = 50 * currentLevel
                score = score + enemyScore
                Persistence.addScore(enemyScore)  -- Add score to persistent storage
                enemiesDefeated = enemiesDefeated + 1
                self.sessionEnemiesDefeated = self.sessionEnemiesDefeated + 1
                
                -- Check for new high score
                if score > self.previousHighScore and not self.newHighScore then
                    self.newHighScore = true
                    self:showNewHighScoreNotification()
                end
                
                -- 15% chance to spawn powerup (increased from 10%)
                if random() < 0.15 then
                    self:spawnPowerup(destroyedEnemy.x + destroyedEnemy.width/2, 
                                     destroyedEnemy.y + destroyedEnemy.height/2)
                end
            end
        end
    end
end

function PlayingState:checkPowerupCollisions()
    for i = #powerups, 1, -1 do
        local powerup = powerups[i]
        if Collision.checkAABB(player, powerup) then
            local result = powerup:collect(player)
            
            -- Handle enhanced powerups with roguelike variations
            local enhancementMultiplier = powerup.enhanced and 2 or 1
            
            -- Handle the result
            if result == "bomb" then
                -- Add bomb to inventory instead of using immediately
                player.bombs = (player.bombs or 0) + (1 * enhancementMultiplier)
                if powerup.enhanced then
                    self:createPowerupText("DOUBLE BOMB!", powerup.x, powerup.y, {1, 1, 0})
                end
            elseif type(result) == "table" then
                -- Timed powerup with enhanced duration
                local duration = result.duration * enhancementMultiplier
                activePowerups[result.type] = duration
                
                -- Apply immediate effects
                if result.type == "rapid" then
                    -- Rapid fire will be handled in shootLaser
                    if powerup.enhanced then
                        self:createPowerupText("SUPER RAPID FIRE!", powerup.x, powerup.y, {1, 1, 0})
                    end
                elseif result.type == "spread" then
                    -- Spread shot will be handled in shootLaser
                    activePowerups.multiShot = duration  -- Map to existing multiShot
                    if powerup.enhanced then
                        self:createPowerupText("MEGA SPREAD!", powerup.x, powerup.y, {1, 0.5, 0})
                    end
                elseif result.type == "boost" then
                    -- Speed boost will be handled in updatePlayer
                    if powerup.enhanced then
                        self:createPowerupText("HYPER BOOST!", powerup.x, powerup.y, {0, 1, 0})
                    end
                elseif result.type == "coolant" then
                    -- Reset heat immediately and boost cooling
                    player.heat = 0
                    if powerup.enhanced then
                        self:createPowerupText("SUPER COOLANT!", powerup.x, powerup.y, {0, 0.7, 1})
                    else
                        self:createPowerupText("HEAT RESET!", powerup.x, powerup.y, {0, 0.5, 1})
                    end
                end
            elseif result == true and powerup.type == "shield" then
                -- Enhanced shield gives more shield points
                if powerup.enhanced then
                    player.shield = math.min(player.shield + 1, player.maxShield)
                    self:createPowerupText("DOUBLE SHIELD!", powerup.x, powerup.y, {0, 1, 1})
                end
            elseif result == true and powerup.type == "health" then
                -- Enhanced health gives extra life
                if powerup.enhanced then
                    lives = lives + 1
                    self:createPowerupText("EXTRA LIFE!", powerup.x, powerup.y, {1, 0.2, 0.2})
                end
            end
            -- If result is true, it was an instant effect (shield)
            
            score = score + constants.score.powerup
            
            -- Check for new high score
            if score > self.previousHighScore and not self.newHighScore then
                self.newHighScore = true
                self:showNewHighScoreNotification()
            end
            
            if powerupSound then
                powerupSound:stop()
                powerupSound:play()
            end
            
            -- Create floating text
            self:createPowerupText(powerup.description, powerup.x, powerup.y, powerup.color)
            
            table.remove(powerups, i)
        end
    end
end

function PlayingState:checkAlienCollisions()
    -- Aliens vs Player Lasers handled in checkLaserCollisions
    -- This function reserved for future alien-specific collision logic
end

function PlayingState:checkBossCollisions()
    -- Boss vs Player
    if Collision.checkAABB(player, boss) and invulnerableTime <= 0 then
        if not activePowerups.shield then
            self:playerHit()
        end
    end
    
    -- Boss vs Player Lasers
    for i = #lasers, 1, -1 do
        local laser = lasers[i]
        if Collision.checkAABB(laser, boss) then
            self:createHitEffect(laser.x, laser.y)  -- Add hit spark effect
            self:handleBossHit(laser)
            self.laserPool:release(laser)
            table.remove(lasers, i)
        end
    end
end

-- Helper functions for collision handling
function PlayingState:handleShieldHit(entity, index, array)
    activePowerups.shield = nil
    self:createExplosion(entity.x, entity.y, entity.size or 40)
    table.remove(array or asteroids, index)
    if shieldBreakSound then shieldBreakSound:play() end
end

function PlayingState:handlePlayerHit(entity, index, array)
    self:playerHit()
    self:createExplosion(entity.x, entity.y, entity.size or 40)
    table.remove(array or asteroids, index)
end

function PlayingState:handleAsteroidDestruction(asteroid, index)
    -- Update combo
    self.combo = self.combo + 1
    self.comboTimer = 2.0  -- Reset combo timer
    self.comboMultiplier = 1 + (self.combo - 1) * 0.1  -- 10% bonus per combo
    
    -- Award more points for smaller asteroids (they're harder to hit)
    local sizeMultiplier = asteroid.size <= 25 and 2 or 1
    score = score + math.floor(constants.score.asteroid * self.comboMultiplier * sizeMultiplier)
    Persistence.addScore(math.floor(constants.score.asteroid * self.comboMultiplier * sizeMultiplier))
    
    -- Create explosion
    self:createExplosion(asteroid.x, asteroid.y, asteroid.size)
    
    -- Split larger asteroids into smaller ones
    if asteroid.size > 30 then  -- Only split medium and large asteroids
        local fragments = asteroid.size > 40 and 3 or 2  -- Large asteroids split into 3, medium into 2
        
        for i = 1, fragments do
            local angle = (2 * math.pi / fragments) * i + random() * 0.5
            local speed = random(50, 150)
            local newSize = asteroid.size * 0.6  -- Make fragments 60% of original size
            
            local fragment = {
                x = asteroid.x + math.cos(angle) * 10,
                y = asteroid.y + math.sin(angle) * 10,
                size = math.max(20, newSize),  -- Minimum size of 20
                rotation = random() * pi * 2,
                rotationSpeed = (random() - 0.5) * 2,  -- Faster rotation for fragments
                -- Add velocity to make fragments fly apart
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                isFragment = true  -- Mark as fragment for special handling
            }
            table.insert(asteroids, fragment)
        end
        
        -- Extra screen shake for splitting
        if self.camera then
            self.camera:shake(0.15, 3)
        end
    else
        -- Small asteroids get normal shake
        if self.camera then
            self.camera:shake(0.1, 2)
        end
    end
    
    -- Remove the destroyed asteroid
    table.remove(asteroids, index)
    enemiesDefeated = enemiesDefeated + 1
    self.sessionEnemiesDefeated = self.sessionEnemiesDefeated + 1
    
    -- Check for new high score
    if score > self.previousHighScore and not self.newHighScore then
        self.newHighScore = true
        self:showNewHighScoreNotification()
    end
    
    -- Higher chance for smaller asteroids to drop powerups (they're the reward for dealing with splits)
    local powerupChance = asteroid.size <= 25 and 0.15 or 0.05
    if random() < powerupChance then
        self:spawnPowerup(asteroid.x, asteroid.y)
    end
    
    logger.debug("Asteroid destroyed (size: %d), score: %d", asteroid.size, score)
end

function PlayingState:handleAlienDestruction(alien, index)
    -- Update combo
    self.combo = self.combo + 1
    self.comboTimer = 2.0  -- Reset combo timer
    self.comboMultiplier = 1 + (self.combo - 1) * 0.1  -- 10% bonus per combo
    
    score = score + math.floor(constants.score.alien * self.comboMultiplier)
    Persistence.addScore(math.floor(constants.score.alien * self.comboMultiplier))  -- Add score to persistent storage
    self:createExplosion(alien.x, alien.y, 40)
    table.remove(aliens, index)
    enemiesDefeated = enemiesDefeated + 1
    self.sessionEnemiesDefeated = self.sessionEnemiesDefeated + 1
    
    -- Add light camera shake
    if self.camera then
        self.camera:shake(0.1, 2)  -- Light shake for alien destruction
    end
    
    -- Check for new high score
    if score > self.previousHighScore and not self.newHighScore then
        self.newHighScore = true
        self:showNewHighScoreNotification()
    end
    
    -- 20% chance to drop powerup (increased from 10%)
    if random() < 0.2 then
        -- Select a random powerup type
        local powerupTypes = {"shield", "rapidFire", "multiShot"}
        if currentLevel >= 2 then
            table.insert(powerupTypes, "boost")
        end
        if currentLevel >= 3 then
            table.insert(powerupTypes, "bomb")
        end
        if currentLevel >= 4 then
            table.insert(powerupTypes, "health")
        end
        
        -- Map old types to new ones
        local typeMapping = {
            shield = "shield",
            rapidFire = "rapid",
            multiShot = "spread",
            boost = "boost",
            bomb = "bomb",
            health = "health"
        }
        
        local oldType = powerupTypes[random(#powerupTypes)]
        local newType = typeMapping[oldType] or oldType
        
        local powerup = Powerup.new(alien.x, alien.y, newType)
        table.insert(powerups, powerup)
        
        logger.debug("Powerup spawned: %s at (%d, %d)", powerup.type, powerup.x, powerup.y)
    end
    
    logger.debug("Alien destroyed, score: %d", score)
end

function PlayingState:handleBossHit(laser)
    -- Handle Boss02 entities differently
    if boss.isBoss02 then
        boss.hp = boss.hp - 1
        boss.health = boss.hp  -- Keep synced
        
        if boss.hp <= 0 then
            self:handleBossDefeat()
        end
    else
        -- Original boss hit logic
        if boss.shield and boss.shield > 0 then
            boss.shield = boss.shield - 1
            -- Shield hit effect
        else
            boss.health = boss.health - 1
            if boss.health <= 0 then
                self:handleBossDefeat()
            end
        end
    end
    
    -- Add stronger camera shake for boss hits
    if self.camera then
        self.camera:shake(0.2, 3)  -- Stronger shake for boss
    end
    
    -- Trigger boss hit flash
    self.bossHitFlash = 0.8
    
    score = score + 10
    Persistence.addScore(10)  -- Add score to persistent storage
    
    -- Check for new high score
    if score > self.previousHighScore and not self.newHighScore then
        self.newHighScore = true
        self:showNewHighScoreNotification()
    end
    
    self:createHitEffect(laser.x, laser.y)
end

function PlayingState:handleBossDefeat()
    if boss.state ~= "dying" then
        -- Only add score and set state once
        score = score + constants.score.boss
        Persistence.addScore(constants.score.boss)  -- Add score to persistent storage
        boss.state = "dying"
        boss.stateTimer = 0
        logger.info("Boss defeated! Level %d complete", currentLevel)
        
        -- Check for new high score
        if score > self.previousHighScore and not self.newHighScore then
            self.newHighScore = true
            self:showNewHighScoreNotification()
        end
        
        -- Increment boss defeat counter
        if Persistence then
            Persistence.incrementBossesDefeated()
        end
        
        -- Unlock next level
        if Persistence and currentLevel < 20 then
            Persistence.unlockLevel(currentLevel + 1)
            logger.info("Unlocked level %d", currentLevel + 1)
            
            -- Show level unlock notification
            table.insert(powerupTexts, {
                text = "LEVEL " .. (currentLevel + 1) .. " UNLOCKED!",
                x = self.screenWidth / 2,
                y = 300,
                color = {0, 1, 1},
                life = 3.0,
                scale = 1.2,
                pulse = true
            })
        end
    else
        -- Final cleanup after death animation
        boss = nil
        bossSpawned = false
        levelComplete = true
        
        -- Create final explosion
        for i = 1, 5 do
            local offsetX = random(-50, 50)
            local offsetY = random(-50, 50)
            self:createExplosion(self.screenWidth/2 + offsetX, 150 + offsetY, 60)
        end
    end
end


function PlayingState:createExplosion(x, y, size)
    local explosion = self.explosionPool:get()
    explosion.x = x
    explosion.y = y
    explosion.radius = size / 4
    explosion.maxRadius = size
    explosion.speed = size * 2
    explosion.alpha = 1
    
    table.insert(explosions, explosion)
    
    -- Create explosion ring particles
    local particleCount = math.floor(size / 5)
    for i = 1, particleCount do
        local angle = (i / particleCount) * pi * 2
        local speed = random(100, 200)
        local particle = self.particlePool:get()
        particle.x = x
        particle.y = y
        particle.vx = cos(angle) * speed
        particle.vy = sin(angle) * speed
        particle.life = random(0.5, 1.0)
        particle.maxLife = particle.life
        particle.size = random(2, 4)
        particle.color = {
            1,
            random(0.5, 1),
            random(0, 0.3),
            1
        }
        table.insert(explosions, particle)
    end
    
    -- Add debris particles (rock fragments)
    local debrisCount = math.floor(size / 8)
    for i = 1, debrisCount do
        local angle = random() * pi * 2
        local speed = random(50, 150)
        local particle = self.particlePool:get()
        particle.x = x + random(-5, 5)
        particle.y = y + random(-5, 5)
        particle.vx = cos(angle) * speed
        particle.vy = sin(angle) * speed
        particle.life = random(0.8, 1.5)
        particle.maxLife = particle.life
        particle.size = random(3, 6)
        particle.rotation = random() * pi * 2
        particle.rotationSpeed = (random() - 0.5) * 5
        particle.isDebris = true  -- Mark as debris for special rendering
        particle.color = {
            random(0.4, 0.7),  -- Grayish colors for rock debris
            random(0.4, 0.7),
            random(0.4, 0.7),
            1
        }
        table.insert(explosions, particle)
    end
    
    -- Add sparks for extra effect
    local sparkCount = math.floor(size / 10)
    for i = 1, sparkCount do
        local angle = random() * pi * 2
        local speed = random(200, 400)  -- Faster than debris
        local particle = self.particlePool:get()
        particle.x = x
        particle.y = y
        particle.vx = cos(angle) * speed
        particle.vy = sin(angle) * speed
        particle.life = random(0.2, 0.4)  -- Short lived
        particle.maxLife = particle.life
        particle.size = random(1, 2)  -- Small
        particle.isSpark = true
        particle.color = {
            1,
            random(0.8, 1),
            random(0, 0.5),
            1
        }
        table.insert(explosions, particle)
    end
    
    if explosionSound then
        explosionSound:stop()
        explosionSound:play()
    end
end

function PlayingState:createHitEffect(x, y)
    -- Create spark particles for hit effects
    for i = 1, 5 do  -- Add 5 sparks
        local particle = self.particlePool:get()
        particle.x = x
        particle.y = y
        local angle = random() * pi * 2
        local speed = random(100, 200)
        particle.vx = cos(angle) * speed
        particle.vy = sin(angle) * speed
        particle.life = 0.3
        particle.maxLife = 0.3
        particle.size = 2
        particle.color = {1, 1, 0, 1}  -- Yellow sparks
        particle.type = "spark"  -- Mark as spark for special rendering if needed
        table.insert(explosions, particle)
    end
end

function PlayingState:createHeatParticle()
    -- Create heat steam particles from ship engines
    local particle = self.particlePool:get()
    -- Spawn from ship engine area
    particle.x = player.x + random(-player.width/4, player.width/4)
    particle.y = player.y + player.height/2
    
    -- Upward drift with slight horizontal variation
    particle.vx = random(-20, 20)
    particle.vy = random(-80, -120)  -- Upward
    
    -- Heat particles live longer and are larger
    particle.life = random(0.8, 1.2)
    particle.maxLife = particle.life
    particle.size = random(3, 5)
    
    -- Color based on heat level - orange to red
    local heatPercent = player.heat / player.maxHeat
    local r = 1
    local g = 1 - heatPercent * 0.7  -- Orange to red
    local b = 0
    particle.color = {r, g, b, 0.7}
    particle.type = "heat"
    
    table.insert(explosions, particle)
end

function PlayingState:playerHit()
    lives = lives - 1
    invulnerableTime = constants.player.invulnerabilityTime
    player.shield = constants.player.shield
    
    -- Trigger player hit flash
    self.playerHitFlash = 1.0
    
    -- Add camera shake on hit
    if self.camera then
        self.camera:shake(0.3, 5)  -- Duration, intensity
    end
    
    if lives <= 0 then
        -- Save game stats before transitioning
        self:saveGameStats()
        
        gameState = "gameOver"
        levelAtDeath = currentLevel
        if gameOverSound then gameOverSound:play() end
        if backgroundMusic then backgroundMusic:stop() end
        
        -- Switch to game over state with new high score flag
        if stateManager then
            stateManager:switch("gameover", self.newHighScore)
        end
    end
end

-- Add screen bomb effect function
function PlayingState:screenBomb()
    -- Count enemies before clearing
    local enemiesCleared = #asteroids + #aliens
    
    -- Create explosions for all enemies
    for _, asteroid in ipairs(asteroids) do
        self:createExplosion(asteroid.x, asteroid.y, asteroid.size)
        score = score + constants.score.asteroid
    end
    
    for _, alien in ipairs(aliens) do
        self:createExplosion(alien.x, alien.y, 40)
        score = score + constants.score.alien
    end
    
    -- Update statistics
    self.sessionEnemiesDefeated = self.sessionEnemiesDefeated + enemiesCleared
    
    -- Check for new high score
    if score > self.previousHighScore and not self.newHighScore then
        self.newHighScore = true
        self:showNewHighScoreNotification()
    end
    
    -- Clear all enemies and enemy projectiles
    asteroids = {}
    aliens = {}
    alienLasers = {}
    
    -- Don't affect boss
    if boss then
        -- Maybe damage boss slightly
        if boss.isBoss02 then
            boss.hp = max(1, boss.hp - 5)
            boss.health = boss.hp
        else
            boss.health = max(1, boss.health - 5)
        end
        self:createHitEffect(boss.x, boss.y)
    end
    
    -- Screen flash effect
    self.bombFlash = 1.0
    
    -- Big camera shake for bomb
    self.camera:shake(0.5, 10)
    
    if explosionSound then
        explosionSound:play()
    end
end

function PlayingState:createPowerupText(text, x, y, color)
    table.insert(powerupTexts, {
        text = text,
        x = x,
        y = y,
        color = color,
        life = 1.5
    })
end

function PlayingState:draw()
    -- Apply camera shake
    if self.camera then
        self.camera:apply()
    end
    
    -- Draw game elements
    self:drawBackground()
    self:drawAsteroids()
    self:drawAliens()
    
    -- Draw WaveManager enemies
    if self.waveManager then
        self.waveManager:draw()
    end
    
    self:drawLasers()
    self:drawPlayer()
    self:drawExplosions()
    self:drawPowerups()
    self:drawPowerupTexts()
    
    if boss then
        self:drawBoss()
    end
    
    -- Release camera (before UI)
    if self.camera then
        self.camera:release()
    end
    
    -- Draw UI (not affected by camera shake)
    self:drawUI()
    
    -- Draw combo counter
    if self.combo > 1 then
        lg.setFont(menuFont or lg.newFont(28))
        local pulse = sin(love.timer.getTime() * 5) * 0.2 + 0.8
        
        -- Color based on combo level
        if self.combo >= 10 then
            lg.setColor(1, 0, 0, pulse)  -- Red for high combos
        elseif self.combo >= 5 then
            lg.setColor(1, 0.5, 0, pulse)  -- Orange for medium combos
        else
            lg.setColor(1, 1, 0, pulse)  -- Yellow for low combos
        end
        
        local comboText = "x" .. self.combo
        local comboWidth = lg.getFont():getWidth(comboText)
        lg.print(comboText, self.screenWidth - comboWidth - 20, 100)
        
        -- Combo timer bar
        lg.setColor(1, 1, 1, 0.5)
        lg.rectangle("fill", self.screenWidth - 100, 135, 80 * (self.comboTimer / 2.0), 4)
        lg.setColor(1, 1, 1, 1)
        lg.rectangle("line", self.screenWidth - 100, 135, 80, 4)
    end
    
    -- Draw heat distortion effect
    local heatPercent = player.heat / player.maxHeat
    if heatPercent > 0.7 then
        -- Red vignette effect
        local vignetteAlpha = (heatPercent - 0.7) * 0.5  -- 0 to 0.15 alpha
        lg.setColor(1, 0, 0, vignetteAlpha)
        -- Draw gradient vignette
        local vignetteSize = 100
        for i = 0, vignetteSize do
            local alpha = vignetteAlpha * (1 - i / vignetteSize)
            lg.setColor(1, 0, 0, alpha)
            lg.rectangle("line", i, i, self.screenWidth - i*2, self.screenHeight - i*2)
        end
    end
    
    -- Draw overheat warning
    if heatPercent > 0.8 then
        local flash = sin(love.timer.getTime() * 10) * 0.5 + 0.5
        lg.setFont(menuFont or lg.newFont(24))
        lg.setColor(1, 0, 0, flash)
        local warningText = "WARNING: OVERHEAT!"
        local warningWidth = lg.getFont():getWidth(warningText)
        lg.print(warningText, self.screenWidth/2 - warningWidth/2, 150)
        
        -- Additional flashing indicators
        lg.setColor(1, 0.3, 0, flash * 0.8)
        lg.print("▲", self.screenWidth/2 - warningWidth/2 - 30, 150)
        lg.print("▲", self.screenWidth/2 + warningWidth/2 + 20, 150)
    end
    
    -- Draw hit flash overlay (player damage)
    if self.playerHitFlash > 0 then
        lg.setColor(1, 0.2, 0.2, self.playerHitFlash * 0.5)
        lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    end
    
    -- Draw bomb flash effect
    if self.bombFlash and self.bombFlash > 0 then
        lg.setColor(1, 1, 1, self.bombFlash)
        lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
        self.bombFlash = self.bombFlash - love.timer.getDelta() * 3
    end
    
    -- Draw debug overlay if enabled (press F3 to toggle)
    if self.showDebug then
        self:drawDebugOverlay()
    end
end

-- Helper function to draw bars with labels
function PlayingState:drawBar(x, y, w, h, percent, color, label)
    -- Background
    lg.setColor(0.2, 0.2, 0.2, 0.8)
    lg.rectangle("fill", x, y, w, h, 2)  -- Rounded corners
    
    -- Fill with gradient effect
    if percent > 0 then
        lg.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 1)
        lg.rectangle("fill", x, y, w * percent, h, 2)
        
        -- Inner highlight for depth
        lg.setColor(color[1], color[2], color[3], 1)
        lg.rectangle("fill", x + 1, y + 1, (w - 2) * percent, h - 2, 1)
    end
    
    -- Glow effect if high percent
    if percent > 0.8 then
        local glow = sin(love.timer.getTime() * 5) * 0.3 + 0.7
        lg.setColor(color[1], color[2], color[3], glow * 0.3)
        lg.setLineWidth(2)
        lg.rectangle("line", x - 2, y - 2, w + 4, h + 4, 3)
        lg.setLineWidth(1)
    end
    
    -- Border
    lg.setColor(1, 1, 1, 0.8)
    lg.rectangle("line", x, y, w, h, 2)
    
    -- Label
    if label then
        lg.setFont(smallFont or lg.newFont(12))
        lg.setColor(0.8, 0.8, 0.8, 1)
        local labelWidth = lg.getFont():getWidth(label)
        lg.print(label, x + w/2 - labelWidth/2, y - 14)
    end
end

-- Helper function to draw life icons
function PlayingState:drawLifeIcons(x, y, count, size)
    for i = 1, count do
        local iconX = x + (i-1) * (size + 5)
        
        if playerShips and playerShips[selectedShip] then
            -- Draw ship sprite
            lg.setColor(1, 1, 1, 1)
            local sprite = playerShips[selectedShip]
            local scale = size / max(sprite:getWidth(), sprite:getHeight())
            lg.draw(sprite, iconX, y, 0, scale, scale, 
                    sprite:getWidth()/2, sprite:getHeight()/2)
        else
            -- Fallback triangle
            lg.setColor(0, 1, 1, 1)
            lg.push()
            lg.translate(iconX, y)
            lg.polygon("fill", 0, -size/2, -size/3, size/2, size/3, size/2)
            lg.pop()
        end
    end
end

-- Helper function to draw bomb icons
function PlayingState:drawBombIcons(x, y, count, size)
    for i = 1, count do
        local iconX = x + (i-1) * (size * 2 + 5)
        
        -- Bomb body
        lg.setColor(1, 0.2, 0.2, 1)
        lg.circle("fill", iconX, y, size)
        
        -- Highlight
        lg.setColor(1, 0.5, 0.5, 0.5)
        lg.circle("fill", iconX - size/3, y - size/3, size/3)
        
        -- Border
        lg.setColor(1, 1, 0, 1)
        lg.circle("line", iconX, y, size)
        
        -- Fuse
        lg.setColor(1, 0.5, 0, 1)
        lg.setLineWidth(2)
        lg.line(iconX, y - size, iconX, y - size - 3)
        lg.setColor(1, 1, 0, 1)
        lg.circle("fill", iconX, y - size - 4, 2)
        lg.setLineWidth(1)
    end
end

function PlayingState:drawDebugOverlay()
    lg.setFont(smallFont or lg.newFont(12))
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 5, 100, 200, 150)
    
    lg.setColor(1, 1, 1, 1)
    local y = 105
    local lineHeight = 15
    
    -- FPS
    lg.print("FPS: " .. tostring(love.timer.getFPS()), 10, y)
    y = y + lineHeight
    
    -- Entity counts
    lg.print("Lasers: " .. #lasers .. " / 100", 10, y)
    y = y + lineHeight
    lg.print("Aliens: " .. #aliens, 10, y)
    y = y + lineHeight
    lg.print("Asteroids: " .. #asteroids, 10, y)
    y = y + lineHeight
    lg.print("Explosions: " .. #explosions .. " / 200", 10, y)
    y = y + lineHeight
    lg.print("Powerups: " .. #powerups, 10, y)
    y = y + lineHeight
    
    -- Wave info
    if self.waveManager then
        lg.print("Wave Enemies: " .. #self.waveManager.enemies, 10, y)
        y = y + lineHeight
    end
    
    -- Player heat
    lg.print("Heat: " .. string.format("%.1f%%", (player.heat / player.maxHeat) * 100), 10, y)
    y = y + lineHeight
    
    -- Pool capacity warnings
    if #lasers > 80 then
        lg.setColor(1, 1, 0, 1)  -- Yellow warning
        lg.print("! LASER POOL HIGH !", 10, y)
        y = y + lineHeight
    end
    if #explosions > 150 then
        lg.setColor(1, 0.5, 0, 1)  -- Orange warning
        lg.print("! PARTICLE POOL HIGH !", 10, y)
    end
end

function PlayingState:drawBackground()
    -- This would normally draw the starfield
    lg.setColor(0.1, 0.1, 0.2)
    lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
end

function PlayingState:drawPlayer()
    if invulnerableTime > 0 and sin(invulnerableTime * 20) > 0 then
        return -- Flashing effect
    end
    
    -- Draw player ship sprite if available, otherwise fall back to rectangle
    if playerShips and playerShips[selectedShip] then
        lg.setColor(1, 1, 1)
        local sprite = playerShips[selectedShip]
        local scale = (player.width / sprite:getWidth()) * 4  -- Scale to match player width * 4
        lg.draw(sprite, player.x, player.y, 0, scale, scale, 
                sprite:getWidth()/2, sprite:getHeight()/2)
    else
        -- Fallback to rectangle if no sprite
        lg.setColor(0, 1, 1)
        lg.rectangle("fill", player.x - player.width/2, player.y - player.height/2,
                     player.width, player.height)
    end
    
    -- Draw shield if active
    if activePowerups.shield then
        lg.setColor(0, 1, 1, 0.3)
        lg.circle("line", player.x, player.y, player.width)
    end
end

function PlayingState:drawAsteroids()
    lg.setColor(0.7, 0.5, 0.3)
    for _, asteroid in ipairs(asteroids) do
        lg.push()
        lg.translate(asteroid.x, asteroid.y)
        lg.rotate(asteroid.rotation)
        lg.circle("fill", 0, 0, asteroid.size)
        lg.pop()
    end
end

function PlayingState:drawAliens()
    for _, alien in ipairs(aliens) do
        -- Use homing enemy sprite for legacy aliens if available
        if enemyShips and enemyShips.homing then
            lg.setColor(1, 1, 1, 1)
            local sprite = enemyShips.homing
            -- Calculate scale to fit alien dimensions * 4
            local scaleX = (alien.width / sprite:getWidth()) * 4
            local scaleY = (alien.height / sprite:getHeight()) * 4
            -- Draw centered at alien position
            lg.draw(sprite, alien.x, alien.y, 0, scaleX, scaleY, sprite:getWidth()/2, sprite:getHeight()/2)
        else
            -- Fallback to pink rectangle if sprite not loaded
            lg.setColor(1, 0, 0.5)
            lg.rectangle("fill", alien.x - alien.width/2, alien.y - alien.height/2,
                         alien.width, alien.height)
        end
    end
    lg.setColor(1, 1, 1)
end

function PlayingState:drawLasers()
    for _, laser in ipairs(lasers) do
        if laser.isAlien then
            lg.setColor(constants.laser.alienColor)
        else
            lg.setColor(constants.laser.playerColor)
        end
        lg.rectangle("fill", laser.x - laser.width/2, laser.y - laser.height/2,
                     laser.width, laser.height)
    end
    
    for _, laser in ipairs(alienLasers) do
        lg.setColor(constants.laser.alienColor)
        lg.rectangle("fill", laser.x - laser.width/2, laser.y - laser.height/2,
                     laser.width, laser.height)
    end
end

function PlayingState:drawExplosions()
    for _, explosion in ipairs(explosions) do
        if explosion.vx then
            -- It's a particle
            local alpha = explosion.color and explosion.color[4] or (explosion.life / explosion.maxLife)
            
            if explosion.isDebris then
                -- Draw debris as rotating rectangles
                lg.push()
                lg.translate(explosion.x, explosion.y)
                lg.rotate(explosion.rotation or 0)
                lg.setColor(explosion.color[1], explosion.color[2], explosion.color[3], alpha)
                lg.rectangle("fill", -explosion.size/2, -explosion.size/2, explosion.size, explosion.size)
                lg.pop()
            elseif explosion.isSpark then
                -- Draw sparks as lines showing motion
                lg.setColor(explosion.color[1], explosion.color[2], explosion.color[3], alpha)
                local trailLength = 10
                local vx = explosion.vx / 10
                local vy = explosion.vy / 10
                lg.setLineWidth(explosion.size)
                lg.line(explosion.x, explosion.y, explosion.x - vx, explosion.y - vy)
                lg.setLineWidth(1)
            else
                -- Regular particles
                lg.setColor(explosion.color[1], explosion.color[2], explosion.color[3], alpha)
                lg.circle("fill", explosion.x, explosion.y, explosion.size * alpha)
            end
        else
            -- It's a regular explosion ring
            lg.setColor(1, 0.5, 0, explosion.alpha)
            lg.setLineWidth(2)
            lg.circle("line", explosion.x, explosion.y, explosion.radius)
            lg.setColor(1, 1, 0, explosion.alpha * 0.5)
            lg.circle("fill", explosion.x, explosion.y, explosion.radius * 0.7)
            lg.setLineWidth(1)
        end
    end
end

function PlayingState:drawPowerups()
    for _, powerup in ipairs(powerups) do
        powerup:draw()
    end
end

function PlayingState:drawPowerupTexts()
    for _, text in ipairs(powerupTexts) do
        lg.push()
        
        -- Apply scale if present
        if text.scale then
            lg.translate(text.x, text.y)
            lg.scale(text.scale, text.scale)
            lg.translate(-text.x, -text.y)
        end
        
        -- Apply pulse effect if present
        local alpha = text.life
        if text.pulse then
            alpha = alpha * (sin(love.timer.getTime() * 10) * 0.2 + 0.8)
        end
        
        lg.setColor(text.color[1], text.color[2], text.color[3], alpha)
        lg.setFont(smallFont or lg.newFont(14))
        local w = lg.getFont():getWidth(text.text)
        lg.print(text.text, text.x - w/2, text.y)
        
        lg.pop()
    end
end

function PlayingState:drawUI()
    -- Bento Grid Layout with reduced height
    local hudHeight = 60  -- Reduced from 80
    local panelPadding = 10
    
    -- Top HUD Panel with gradient
    lg.setColor(0, 0, 0, 0.6)  -- Softer alpha
    lg.rectangle("fill", 0, 0, self.screenWidth, hudHeight)
    
    -- Subtle gradient line
    for i = 0, 2 do
        lg.setColor(0.2, 0.2, 0.4, 1 - i * 0.3)
        lg.rectangle("fill", 0, hudHeight + i, self.screenWidth, 1)
    end
    
    -- === LEFT SECTION: Level/Wave/Enemies ===
    lg.setFont(mediumFont or lg.newFont(18))
    lg.setColor(0.8, 0.8, 1, 1)
    lg.print("LEVEL " .. currentLevel, panelPadding, 5)
    
    if self.waveManager then
        lg.setFont(smallFont or lg.newFont(12))
        lg.setColor(0.7, 1, 0.7, 1)
        lg.print("WAVE " .. self.waveManager.waveNumber, panelPadding, 25)
        
        local enemyCount = (self.waveManager.getEnemyCount and self.waveManager:getEnemyCount()) or #self.waveManager.enemies
        lg.setColor(1, 0.7, 0.5, 1)
        lg.print("ENEMIES: " .. enemyCount, panelPadding, 40)
    end
    
    -- === CENTER SECTION: Score with animation ===
    lg.push()
    lg.translate(self.screenWidth/2, 15)
    lg.scale(self.scoreAnimScale, self.scoreAnimScale)
    
    lg.setFont(menuFont or lg.newFont(26))
    lg.setColor(1, 1, 1, 1)
    local scoreText = tostring(score)  -- No leading zeros
    local scoreWidth = lg.getFont():getWidth(scoreText)
    lg.print(scoreText, -scoreWidth/2, -13)
    
    lg.pop()
    
    -- Compact bars below score
    local barWidth = 150  -- Reduced from 200
    local barHeight = 6   -- Slimmer
    local barX = self.screenWidth/2 - barWidth/2
    
    -- Shield bar
    if player.shield > 0 or player.maxShield > 0 then
        local shieldPercent = player.shield / player.maxShield
        self:drawBar(barX, 32, barWidth, barHeight, shieldPercent, {0, 1, 1}, nil)  -- No label for cleaner look
    end
    
    -- Heat bar
    local heatPercent = player.heat / player.maxHeat
    self:drawBar(barX, 42, barWidth, barHeight, heatPercent, {1, heatPercent, 0}, nil)
    
    -- === RIGHT SECTION: High Score/Lives/Bombs ===
    lg.setFont(uiFont or lg.newFont(16))
    
    -- High score with subtle animation
    local highScore = self.newHighScore and score or (Persistence and Persistence.getHighScore() or 0)
    if self.newHighScore then
        local flash = sin(love.timer.getTime() * 5) * 0.3 + 0.7
        lg.setColor(1, flash, 0, 1)
    else
        lg.setColor(1, 0.8, 0, 1)
    end
    
    local highScoreText = "HIGH: " .. tostring(highScore)
    local highScoreWidth = lg.getFont():getWidth(highScoreText)
    lg.print(highScoreText, self.screenWidth - highScoreWidth - panelPadding, 5)
    
    -- Lives (compact icons)
    self:drawLifeIcons(self.screenWidth - 80, 30, lives, 12)
    
    -- Bombs (smaller icons)
    if player.bombs and player.bombs > 0 then
        self:drawBombIcons(self.screenWidth - 80, 48, player.bombs, 5)
    end
    
    -- === ACTIVE POWERUPS PANEL (Left side, fade when empty) ===
    local activePowerupCount = 0
    for _ in pairs(activePowerups) do
        activePowerupCount = activePowerupCount + 1
    end
    
    if activePowerupCount > 0 then
        local powerupPanelY = 70
        local powerupPanelHeight = min(activePowerupCount * 20 + 15, 120)  -- Cap height
        
        -- Semi-transparent background
        lg.setColor(0, 0, 0, 0.5)
        lg.rectangle("fill", 0, powerupPanelY, 180, powerupPanelHeight, 4)
        
        -- Powerup list with mini bars
        local powerupY = powerupPanelY + 5
        lg.setFont(smallFont or lg.newFont(12))
        
        for powerup, timer in pairs(activePowerups) do
            local colors = {
                shield = {0, 1, 1},
                rapid = {1, 1, 0},
                spread = {1, 0.5, 0},
                multiShot = {1, 0.5, 0},
                boost = {0, 1, 0},
                coolant = {0, 0.5, 1}
            }
            
            local color = colors[powerup] or {1, 1, 1}
            
            -- Mini progress bar
            lg.setColor(color[1] * 0.3, color[2] * 0.3, color[3] * 0.3, 0.5)
            lg.rectangle("fill", 5, powerupY, 170, 16, 2)
            
            lg.setColor(color[1], color[2], color[3], 0.8)
            local duration = constants.powerup and constants.powerup.duration and constants.powerup.duration[powerup] or 10
            lg.rectangle("fill", 5, powerupY, 170 * (timer / duration), 16, 2)
            
            -- Text
            lg.setColor(1, 1, 1, 1)
            local displayName = powerup:upper() .. " " .. string.format("%.1fs", timer)
            lg.print(displayName, 8, powerupY + 1)
            
            powerupY = powerupY + 18
            if powerupY > powerupPanelY + powerupPanelHeight - 5 then break end  -- Prevent overflow
        end
    end
    
    -- === CONTROLS HINT (Bottom, fades out) ===
    if self.showControlsHint then
        lg.setFont(smallFont or lg.newFont(12))
        lg.setColor(0.4, 0.4, 0.4, self.controlsHintAlpha * 0.6)
        
        local controlsY = self.screenHeight - 60
        local controlsX = self.screenWidth - 180
        
        -- Semi-transparent background
        lg.setColor(0, 0, 0, self.controlsHintAlpha * 0.3)
        lg.rectangle("fill", controlsX - 5, controlsY - 5, 175, 55, 3)
        
        -- Control hints
        lg.setColor(0.6, 0.6, 0.6, self.controlsHintAlpha)
        lg.print("MOVE: Arrows/" .. (self.keyBindings.up or "W"):upper() .. (self.keyBindings.left or "A"):upper() .. (self.keyBindings.down or "S"):upper() .. (self.keyBindings.right or "D"):upper(), controlsX, controlsY)
        lg.print("SHOOT: " .. (self.keyBindings.shoot or "Space"):upper(), controlsX, controlsY + 12)
        lg.print("BOMB: " .. (self.keyBindings.bomb or "B"):upper() .. " | BOOST: " .. (self.keyBindings.boost or "Shift"):upper(), controlsX, controlsY + 24)
        lg.print("PAUSE: ESC", controlsX, controlsY + 36)
    end
end

function PlayingState:keypressed(key, scancode, isrepeat)
    if key == self.keyBindings.pause or key == "escape" then
        gameState = "paused"
        stateManager:switch("pause")
    elseif key == "f3" then
        -- Toggle debug overlay
        self.showDebug = not self.showDebug
    elseif key == self.keyBindings.shoot then
        self.keys.shoot = true
    elseif key == self.keyBindings.boost or key == "lshift" or key == "rshift" then
        self.keys.boost = true
    elseif key == self.keyBindings.left or key == "left" then
        self.keys.left = true
    elseif key == self.keyBindings.right or key == "right" then
        self.keys.right = true
    elseif key == self.keyBindings.up or key == "up" then
        self.keys.up = true
    elseif key == self.keyBindings.down or key == "down" then
        self.keys.down = true
    elseif key == self.keyBindings.bomb or key == "lctrl" or key == "rctrl" then
        -- Use bomb if available
        if player.bombs and player.bombs > 0 then
            player.bombs = player.bombs - 1
            self:screenBomb()
        end
    end
end

function PlayingState:keyreleased(key, scancode)
    if key == self.keyBindings.shoot then
        self.keys.shoot = false
        self.shootCooldown = 0
    elseif key == self.keyBindings.boost or key == "lshift" or key == "rshift" then
        self.keys.boost = false
    elseif key == self.keyBindings.left or key == "left" then
        self.keys.left = false
    elseif key == self.keyBindings.right or key == "right" then
        self.keys.right = false
    elseif key == self.keyBindings.up or key == "up" then
        self.keys.up = false
    elseif key == self.keyBindings.down or key == "down" then
        self.keys.down = false
    end
end

function PlayingState:gamepadpressed(joystick, button)
    if button == "dpup" then
        self.keys.up = true
    elseif button == "dpdown" then
        self.keys.down = true
    elseif button == "dpleft" then
        self.keys.left = true
    elseif button == "dpright" then
        self.keys.right = true
    elseif button == self.gamepadBindings.shoot then
        self.keys.shoot = true
    elseif button == self.gamepadBindings.bomb then
        -- Use bomb if available
        if player.bombs and player.bombs > 0 then
            player.bombs = player.bombs - 1
            self:screenBomb()
        end
    elseif button == self.gamepadBindings.boost then
        self.keys.boost = true
    elseif button == self.gamepadBindings.pause then
        gameState = "paused"
        stateManager:switch("pause")
    end
end

function PlayingState:gamepadreleased(joystick, button)
    if button == "dpup" then
        self.keys.up = false
    elseif button == "dpdown" then
        self.keys.down = false
    elseif button == "dpleft" then
        self.keys.left = false
    elseif button == "dpright" then
        self.keys.right = false
    elseif button == self.gamepadBindings.shoot then
        self.keys.shoot = false
        self.shootCooldown = 0
    elseif button == self.gamepadBindings.boost then
        self.keys.boost = false
    end
end

-- Boss-related methods
function PlayingState:spawnBoss()
    if bossSpawned or boss then return end
    
    -- Clear remaining enemies
    asteroids = {}
    aliens = {}
    alienLasers = {}
    
    -- Determine if we should use Boss02 for certain levels
    local useBoss02 = false
    if currentLevel == 3 or currentLevel == 7 or currentLevel == 12 or currentLevel == 17 then
        useBoss02 = true
    end
    
    if useBoss02 then
        -- Use the new Boss02 entity
        local Boss02 = require("src.entities.boss02")
        boss = Boss02.new(currentLevel)
        
        -- Add compatibility properties for the existing boss system
        boss.type = "boss02"
        boss.width = 100
        boss.height = 100
        boss.size = 100
        boss.health = boss.hp
        boss.maxHealth = boss.maxHP
        boss.speed = 80
        boss.state = "entering"
        boss.stateTimer = 0
        boss.attackTimer = 0
        boss.attackCooldown = 0
        boss.currentAttack = nil
        boss.phase = boss.currentPhase or 1
        boss.alpha = 1
        -- Initialize beam shot timer to prevent nil errors
        boss.lastBeamShot = love.timer.getTime()
        boss.shield = 0
        boss.maxShield = 0
        boss.movePattern = "sine"
        boss.moveTimer = 0
        boss.targetX = self.screenWidth / 2
        boss.attacks = {"spiral", "ringBurst", "lastStand"}
        boss.lastAttack = nil
        
        -- Flag to indicate this is a Boss02 entity
        boss.isBoss02 = true
    else
        -- Use the original boss system
        -- Determine boss type based on level
        local bossType
        if currentLevel % 15 == 0 then
            bossType = "quantumPhantom"
        elseif currentLevel % 10 == 0 then
            bossType = "voidReaper"
        elseif currentLevel % 5 == 0 then
            bossType = "annihilator"
        else
            -- Random boss for other levels
            local bossTypes = {"annihilator", "frostTitan", "stormBringer"}
            bossType = bossTypes[random(#bossTypes)]
        end
        
        -- Create boss
        boss = {
            type = bossType,
            x = self.screenWidth / 2,
            y = -100,
            width = 100,
            height = 100,
            size = 100,
            health = constants.boss[bossType].hp,
            maxHealth = constants.boss[bossType].hp,
            speed = constants.boss[bossType].speed,
            state = "entering",
            stateTimer = 0,
            attackTimer = 0,
            attackCooldown = 0,
            currentAttack = nil,
            phase = 1,
            rotation = 0,
            alpha = 1,
            shield = 0,
            maxShield = 0,
            -- Movement pattern
            movePattern = "sine",
            moveTimer = 0,
            targetX = self.screenWidth / 2,
            -- Attack patterns
            attacks = self:getBossAttacks(bossType),
            lastAttack = nil,
            -- Initialize beam shot timer to prevent nil errors
            lastBeamShot = love.timer.getTime()
        }
    end
    
    bossSpawned = true
    logger.info("Boss spawned: %s at level %d", boss.type or "boss02", currentLevel)
    
    -- Play boss music if available
    if bossMusic then
        if backgroundMusic then backgroundMusic:stop() end
        bossMusic:setLooping(true)
        bossMusic:setVolume(musicVolume * masterVolume)
        bossMusic:play()
    end
end

function PlayingState:getBossAttacks(bossType)
    local attacks = {
        annihilator = {"spreadShot", "beamSweep", "teleport"},
        frostTitan = {"iceBeam", "freezeWave", "icicleBarrage"},
        voidReaper = {"blackHole", "voidRift", "phaseDash"},
        stormBringer = {"lightning", "tornado", "thunderStorm"},
        quantumPhantom = {"phaseShift", "decoys", "quantumBlast"}
    }
    return attacks[bossType] or {"spreadShot"}
end

function PlayingState:updateBoss(dt)
    if not boss then return end
    
    -- If this is a Boss02 entity, use its own update method
    if boss.isBoss02 and boss.update then
        -- Create a bullets object that Boss02 expects
        local bullets = {
            spawn = function(bullets_self, x, y, angle, speed)
                -- Convert Boss02 bullet spawn to the game's alien laser system
                local laser = self.laserPool:get()
                laser.x = x
                laser.y = y
                laser.vx = cos(angle) * speed
                laser.vy = sin(angle) * speed
                laser.width = 6
                laser.height = 12
                laser.isAlien = true
                laser.isBoss = true
                laser.damage = 1
                
                table.insert(alienLasers, laser)
            end
        }
        
        boss:update(dt, bullets)
        
        -- Sync health values
        boss.health = boss.hp
        
        -- Handle death state
        if boss.hp <= 0 and boss.state ~= "dying" then
            boss.state = "dying"
            boss.stateTimer = 0
        end
        
        -- Check if Boss02 is ready to enter active state
        if boss.y >= 120 and boss.state == "entering" then
            boss.state = "active"
        end
        
        return
    end
    
    -- Original boss update code
    -- Update state timer
    boss.stateTimer = boss.stateTimer + dt
    
    -- State machine
    if boss.state == "entering" then
        -- Boss entrance
        boss.y = boss.y + 100 * dt
        if boss.y >= 150 then
            boss.state = "active"
            boss.stateTimer = 0
        end
    elseif boss.state == "active" then
        -- Update movement
        self:updateBossMovement(dt)
        
        -- Update attacks
        self:updateBossAttacks(dt)
        
        -- Update phase based on health
        self:updateBossPhase()
    elseif boss.state == "phaseTransition" then
        -- Phase transition effects
        boss.alpha = 0.5 + sin(boss.stateTimer * 10) * 0.5
        if boss.stateTimer > 2 then
            boss.state = "active"
            boss.stateTimer = 0
            boss.alpha = 1
        end
    elseif boss.state == "dying" then
        -- Death animation
        boss.rotation = boss.rotation + dt * 5
        boss.alpha = boss.alpha - dt * 0.3
        
        -- Create explosion effects
        if random() < 0.3 then
            local offsetX = random(-boss.size/2, boss.size/2)
            local offsetY = random(-boss.size/2, boss.size/2)
            self:createExplosion(boss.x + offsetX, boss.y + offsetY, 40)
        end
        
        if boss.stateTimer > 3 then
            self:handleBossDefeat()
        end
    end
end

function PlayingState:updateBossMovement(dt)
    boss.moveTimer = boss.moveTimer + dt
    
    -- Add rotation animation based on boss type
    if boss.type == "annihilator" then
        boss.rotation = boss.rotation + dt * 0.3  -- Slow menacing rotation
    elseif boss.type == "frostTitan" then
        boss.rotation = boss.rotation + sin(boss.moveTimer * 2) * dt  -- Oscillating rotation
    else
        boss.rotation = boss.rotation + dt * 0.5  -- Default rotation
    end
    
    if boss.movePattern == "sine" then
        -- Sinusoidal movement
        boss.x = self.screenWidth/2 + sin(boss.moveTimer * 0.5) * 200
    elseif boss.movePattern == "chase" then
        -- Chase player slowly
        local dx = player.x - boss.x
        boss.x = boss.x + min(max(dx * 0.5, -boss.speed), boss.speed) * dt
    elseif boss.movePattern == "teleport" then
        -- Handled in attack pattern
    end
    
    -- Keep boss on screen
    local margin = boss.size / 2
    boss.x = max(margin, min(self.screenWidth - margin, boss.x))
end

function PlayingState:updateBossAttacks(dt)
    -- Update cooldowns
    if boss.attackCooldown > 0 then
        boss.attackCooldown = boss.attackCooldown - dt
        return
    end
    
    -- Update current attack
    if boss.currentAttack then
        boss.attackTimer = boss.attackTimer + dt
        self:executeBossAttack(boss.currentAttack, dt)
    else
        -- Select new attack
        self:selectBossAttack()
    end
end

function PlayingState:selectBossAttack()
    if #boss.attacks == 0 then return end
    
    -- Avoid repeating the same attack
    local availableAttacks = {}
    for _, attack in ipairs(boss.attacks) do
        if attack ~= boss.lastAttack then
            table.insert(availableAttacks, attack)
        end
    end
    
    if #availableAttacks == 0 then
        availableAttacks = boss.attacks
    end
    
    boss.currentAttack = availableAttacks[random(#availableAttacks)]
    boss.lastAttack = boss.currentAttack
    boss.attackTimer = 0
    logger.debug("Boss selected attack: %s", boss.currentAttack)
end

function PlayingState:executeBossAttack(attackType, dt)
    -- Safety check for lastBeamShot initialization
    if boss.lastBeamShot == nil then
        boss.lastBeamShot = love.timer.getTime()
        logger.warning("lastBeamShot was nil; initialized to current time")
    end
    
    if attackType == "spreadShot" then
        if boss.attackTimer == dt then -- First frame
            local numShots = 8 + boss.phase * 2
            local angleStep = (pi * 2) / numShots
            for i = 0, numShots - 1 do
                local angle = i * angleStep
                self:createBossLaser(boss.x, boss.y + boss.size/2, angle)
            end
            if laserSound then laserSound:play() end
        end
        if boss.attackTimer > 0.5 then
            self:endBossAttack(2)
        end
        
    elseif attackType == "beamSweep" then
        if boss.attackTimer < 0.5 then
            -- Charging
            boss.chargingBeam = true
        else
            -- Sweeping
            boss.beamAngle = (boss.beamAngle or -pi/2) + dt * 2
            if boss.attackTimer - boss.lastBeamShot > 0.1 then
                self:createBossLaser(boss.x, boss.y + boss.size/2, boss.beamAngle, true)
                boss.lastBeamShot = boss.attackTimer
            end
        end
        if boss.attackTimer > 3 then
            boss.chargingBeam = false
            boss.beamAngle = nil
            boss.lastBeamShot = nil
            self:endBossAttack(3)
        end
        
    elseif attackType == "teleport" then
        if boss.attackTimer < 0.25 then
            boss.alpha = 1 - (boss.attackTimer / 0.25)
        elseif boss.attackTimer < 0.35 then
            boss.x = random(100, self.screenWidth - 100)
            boss.y = random(100, 300)
        else
            boss.alpha = min(1, (boss.attackTimer - 0.35) / 0.15)
        end
        if boss.attackTimer > 0.5 then
            boss.alpha = 1
            self:endBossAttack(1)
        end
        
    elseif attackType == "iceBeam" then
        -- Similar pattern to beamSweep but slower and creates ice zones
        if boss.attackTimer > 2 then
            self:endBossAttack(4)
        end
        
    else
        -- Default attack pattern
        if boss.attackTimer > 1 then
            self:endBossAttack(2)
        end
    end
end

function PlayingState:endBossAttack(cooldown)
    boss.currentAttack = nil
    boss.attackTimer = 0
    boss.attackCooldown = cooldown or 2
end

function PlayingState:createBossLaser(x, y, angle, isBeam)
    local speed = isBeam and 400 or 300
    local laser = self.laserPool:get()
    laser.x = x
    laser.y = y
    laser.vx = cos(angle) * speed
    laser.vy = sin(angle) * speed
    laser.width = isBeam and 8 or 6
    laser.height = isBeam and 16 or 12
    laser.isAlien = true
    laser.isBoss = true
    laser.damage = isBeam and 2 or 1
    
    -- Add to alienLasers array
    table.insert(alienLasers, laser)
end

function PlayingState:updateBossPhase()
    local healthPercent = boss.health / boss.maxHealth
    local newPhase = 1
    
    if healthPercent <= 0.25 then
        newPhase = 4
    elseif healthPercent <= 0.5 then
        newPhase = 3
    elseif healthPercent <= 0.75 then
        newPhase = 2
    end
    
    if newPhase > boss.phase then
        boss.phase = newPhase
        boss.state = "phaseTransition"
        boss.stateTimer = 0
        boss.currentAttack = nil
        boss.movePattern = newPhase >= 3 and "chase" or "sine"
        logger.info("Boss entered phase %d", newPhase)
    end
end

function PlayingState:drawBoss()
    if not boss then return end
    
    -- If this is a Boss02 entity, use its own draw method
    if boss.isBoss02 and boss.draw then
        -- Apply flash effect
        if self.bossHitFlash > 0 then
            lg.push()
            lg.setColor(1, 1, 1, self.bossHitFlash)
        end
        
        boss:draw()
        
        if self.bossHitFlash > 0 then
            lg.pop()
        end
        
        -- Still draw the health bar for consistency
        if boss.state == "active" or boss.state == "phaseTransition" then
            local barWidth = 200
            local barHeight = 10
            local barX = self.screenWidth/2 - barWidth/2
            local barY = 30
            
            -- Background
            lg.setColor(0.3, 0.3, 0.3, boss.alpha or 1)
            lg.rectangle("fill", barX, barY, barWidth, barHeight)
            
            -- Health fill
            local healthPercent = boss.hp / boss.maxHP
            lg.setColor(1 - healthPercent, healthPercent, 0, boss.alpha or 1)
            lg.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
            
            -- Border
            lg.setColor(1, 1, 1, boss.alpha or 1)
            lg.rectangle("line", barX, barY, barWidth, barHeight)
            
            -- Boss name
            lg.setFont(mediumFont or lg.newFont(18))
            local bossName = "BOSS02 - PHASE " .. (boss.currentPhase or 1)
            local nameWidth = lg.getFont():getWidth(bossName)
            lg.print(bossName, self.screenWidth/2 - nameWidth/2, barY - 25)
        end
        
        return
    end
    
    -- Original boss drawing code
    lg.push()
    lg.translate(boss.x, boss.y)
    lg.rotate(boss.rotation)
    
    -- Set alpha
    lg.setColor(1, 1, 1, boss.alpha)
    
    -- Apply hit flash to boss
    local flashIntensity = self.bossHitFlash or 0
    
    -- Draw based on boss type
    if boss.type == "annihilator" then  -- Borg-like cube
        local cubeSize = boss.size / 2
        -- Base cube structure
        lg.setColor(0.2 + flashIntensity, 0.2 + flashIntensity, 0.2 + flashIntensity, boss.alpha)  -- Dark metallic
        lg.rectangle("fill", -cubeSize, -cubeSize, boss.size, boss.size)
        
        -- Intricate armor plates (inspired by Borg cube: grid-like modules)
        lg.setColor(0.4 + flashIntensity * 0.5, 0.4 + flashIntensity * 0.5, 0.4 + flashIntensity * 0.5, boss.alpha)
        local plateSize = boss.size / 5
        for row = 0, 4 do
            for col = 0, 4 do
                local px = -cubeSize + col * plateSize + random(-2, 2)  -- Slight offset for irregularity
                local py = -cubeSize + row * plateSize + random(-2, 2)
                lg.rectangle("fill", px, py, plateSize - 2, plateSize - 2)  -- Gaps for detail
            end
        end
        
        -- Glowing edges/tron lines (Borg energy conduits)
        lg.setColor(0, 1, 0.5 + flashIntensity, boss.alpha * 0.8)  -- Green glow
        lg.setLineWidth(2)
        for i = 0, 5 do
            -- Horizontal lines
            lg.line(-cubeSize, -cubeSize + i * (boss.size / 5), cubeSize, -cubeSize + i * (boss.size / 5))
            -- Vertical lines
            lg.line(-cubeSize + i * (boss.size / 5), -cubeSize, -cubeSize + i * (boss.size / 5), cubeSize)
        end
        lg.setLineWidth(1)
        
        -- Asymmetrical protrusions (e.g., weapons or sensors)
        lg.setColor(0.3 + flashIntensity, 0.3 + flashIntensity, 0.3 + flashIntensity, boss.alpha)
        lg.polygon("fill", cubeSize, 0, cubeSize + 20, -10, cubeSize + 20, 10)  -- Right spike
        lg.polygon("fill", -cubeSize, cubeSize / 2, -cubeSize - 15, cubeSize / 2 - 10, -cubeSize - 15, cubeSize / 2 + 10)  -- Left antenna
        
    elseif boss.type == "frostTitan" then  -- Ice crystalline alien ship
        -- Organic, asymmetrical body
        lg.setColor(0.5 + flashIntensity * 0.5, 0.8 + flashIntensity * 0.2, 1, boss.alpha)  -- Ice blue
        lg.polygon("fill", -boss.size/2, boss.size/2, 0, -boss.size/2, boss.size/2, boss.size/2)  -- Triangular base
        
        -- Ice spikes/protrusions
        for i = 1, 6 do
            local angle = i * (pi * 2 / 6) + random() * 0.2  -- Random offset
            local len = boss.size * (0.3 + random() * 0.2)  -- Varying length
            local spikeX = cos(angle) * len
            local spikeY = sin(angle) * len
            lg.setColor(0.8, 0.9, 1, boss.alpha * 0.7)  -- Lighter ice tips
            lg.setLineWidth(3)
            lg.line(0, 0, spikeX, spikeY)
            lg.setLineWidth(1)
            lg.circle("fill", spikeX, spikeY, 5)  -- Pointy ends
        end
        
        -- Glowing core
        lg.setColor(0, 0.8, 1, boss.alpha * (0.5 + sin(lt.getTime() * 2) * 0.3))  -- Pulsing
        lg.circle("fill", 0, 0, boss.size / 4)
        
    else
        -- Default: Generic alien ship (curved, with wings/engines)
        lg.setColor(0.8 + flashIntensity * 0.2, 0.2 + flashIntensity * 0.8, 0.8 + flashIntensity * 0.2, boss.alpha)
        -- Hull
        lg.ellipse("fill", 0, 0, boss.size / 2, boss.size / 3)  -- Oval body
        
        -- Wings
        lg.polygon("fill", -boss.size/2, 0, -boss.size/2 - 30, -40, -boss.size/2 - 30, 40)  -- Left wing
        lg.polygon("fill", boss.size/2, 0, boss.size/2 + 30, -40, boss.size/2 + 30, 40)  -- Right wing
        
        -- Engines/glow
        lg.setColor(1, 0.5, 0, boss.alpha * 0.8)
        lg.circle("fill", -boss.size/2 + 10, 0, 15)  -- Rear thruster
        lg.circle("fill", boss.size/2 - 10, 0, 15)  -- Rear thruster
    end
    
    lg.pop()
    
    -- Draw attack effects
    if boss.chargingBeam then
        local pulse = sin(boss.stateTimer * 20) * 0.3 + 0.7
        lg.setColor(1, 0, 0, pulse * boss.alpha)
        lg.circle("line", boss.x, boss.y, boss.size * 0.6)
        lg.circle("line", boss.x, boss.y, boss.size * 0.7)
    end
    
    -- Draw health bar
    if boss.state == "active" or boss.state == "phaseTransition" then
        local barWidth = 200
        local barHeight = 10
        local barX = self.screenWidth/2 - barWidth/2
        local barY = 30
        
        -- Background
        lg.setColor(0.3, 0.3, 0.3, boss.alpha)
        lg.rectangle("fill", barX, barY, barWidth, barHeight)
        
        -- Health fill
        local healthPercent = boss.health / boss.maxHealth
        lg.setColor(1 - healthPercent, healthPercent, 0, boss.alpha)
        lg.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
        
        -- Border
        lg.setColor(1, 1, 1, boss.alpha)
        lg.rectangle("line", barX, barY, barWidth, barHeight)
        
        -- Boss name
        lg.setFont(mediumFont or lg.newFont(18))
        local bossName = boss.type:upper()
        local nameWidth = lg.getFont():getWidth(bossName)
        lg.print(bossName, self.screenWidth/2 - nameWidth/2, barY - 25)
    end
end

function PlayingState:checkGameConditions()
    -- Check for level completion
    if levelComplete and not boss then
        currentLevel = currentLevel + 1
        levelComplete = false
        bossSpawned = false
        enemiesDefeated = 0
        
        -- Add bonus score
        score = score + constants.score.levelComplete
        
        -- Check for new high score
        if score > self.previousHighScore and not self.newHighScore then
            self.newHighScore = true
            self:showNewHighScoreNotification()
        end
        
        -- Heal player slightly
        player.shield = min(player.shield + 1, player.maxShield)
        
        logger.info("Level %d started", currentLevel)
        
        -- Return to normal music
        if bossMusic and backgroundMusic then
            bossMusic:stop()
            backgroundMusic:play()
        end
    end
    
    -- Check for final level completion
    if currentLevel > 20 and not gameComplete then
        gameComplete = true
        _G.gameComplete = true  -- Set global for gameover state
        
        -- Save game stats before ending
        self:saveGameStats()
        
        gameState = "gameOver"
        if victorySound then victorySound:play() end
        if backgroundMusic then backgroundMusic:stop() end
        
        -- Switch to game over state with new high score flag
        if stateManager then
            stateManager:switch("gameover", self.newHighScore)
        end
    end
end

-- New helper functions
function PlayingState:saveGameStats()
    -- Update high score
    if Persistence then
        local isNewHighScore = Persistence.setHighScore(score)
        
        -- Update statistics
        local sessionTime = love.timer.getTime() - self.sessionStartTime
        local stats = {
            totalPlayTime = sessionTime,
            totalEnemiesDefeated = self.sessionEnemiesDefeated,
            favoriteShip = selectedShip
        }
        
        -- Only increment deaths if the game wasn't completed
        if not gameComplete then
            stats.totalDeaths = 1
        end
        
        Persistence.updateStatistics(stats)
    end
end

function PlayingState:showNewHighScoreNotification()
    -- Create a special notification for new high score
    table.insert(powerupTexts, {
        text = "NEW HIGH SCORE!",
        x = self.screenWidth / 2,
        y = 200,
        color = {1, 1, 0},
        life = 3.0,  -- Longer duration
        scale = 1.5,  -- Larger text
        pulse = true  -- Special effect
    })
    
    -- Play a special sound if available
    if powerupSound then
        powerupSound:stop()
        powerupSound:play()
    end
end

function PlayingState:createHitEffect(x, y)
    -- Create a small hit effect
    local explosion = self.explosionPool:get()
    explosion.x = x
    explosion.y = y
    explosion.radius = 10
    explosion.maxRadius = 30
    explosion.speed = 60
    explosion.alpha = 0.8
    
    table.insert(explosions, explosion)
end

return PlayingState