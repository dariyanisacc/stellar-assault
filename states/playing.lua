-- Playing State for Stellar Assault
local constants = require("src.constants")
local ObjectPool = require("src.objectpool")
local Collision = require("src.collision")
local SpatialHash = require("src.spatial")
local logger = require("src.logger")
local Powerup = require("src.entities.powerup")
local Persistence = require("src.persistence")
local WaveManager = require("src.wave_manager")
local PlayerControl = require("src.player_control")
local EnemyAI = require("src.enemy_ai")
local PowerupHandler = require("src.powerup_handler")
local BossManager = require("src.bossmanager")
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
self.trailPool = ObjectPool.createTrailPool()
self.debrisPool = ObjectPool.createDebrisPool()

-- Boss manager handles boss lifecycle
self.bossManager = BossManager:new()
self.bossDefeatNotified = false

-- Initialize WaveManager
self.waveManager = WaveManager:new(player, self.entityGrid)
self.waveManager:setWaveCompleteCallback(function(waveNumber, stats)
    -- Handle wave completion
    score = score + 500 * waveNumber
    logger.info("Wave " .. waveNumber .. " complete! Bonus: " .. (500 * waveNumber))

    -- Show wave statistics overlay
    self.waveOverlay = {
        killRate = stats.killRate or 0,
        maxCombo = stats.maxCombo or 0,
        enemiesDefeated = stats.enemiesDefeated or 0,
        timer = 5
    }

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
self.performanceMetrics = {killRate = 0, combo = 0, maxCombo = 0}

 -- Wave completion overlay
 self.waveOverlay = nil

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
    self.trailPool:releaseAll()
    self.debrisPool:releaseAll()
    if self.laserGrid then
        self.laserGrid:clear()
    end
    if self.entityGrid then
        self.entityGrid:clear()
    end
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
heatRate = 5 * (shipConfig.heatMultiplier or 1),   -- Heat added per shot (adjusted by ship type)
coolRate = 25,           -- Cooling per second (continuous)
overheatPenalty = 1.5,   -- Seconds unable to shoot on overheat (reduced for faster recovery)
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

-- Spatial grid for lasers
self.laserGrid = SpatialHash:new(100)
 -- Spatial grid for entities (asteroids, aliens, powerups, etc.)
 self.entityGrid = SpatialHash:new(100)

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

-- Shooting cooldown
self.shootCooldown = 0

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

 -- Fade out wave completion overlay
 if self.waveOverlay then
     self.waveOverlay.timer = self.waveOverlay.timer - dt
     if self.waveOverlay.timer <= 0 then
         self.waveOverlay = nil
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
if self.bossManager.activeBoss then
self:updateBoss(dt)
end

-- Spawn entities
self:spawnEntities(dt)

-- Check collisions
self:checkCollisions()

-- Update performance metrics for dynamic difficulty
self:updatePerformanceMetrics()
if self.waveManager then
self.waveManager:setPlayerPerformance(self.performanceMetrics)
end

-- Check win/lose conditions
self:checkGameConditions()
end

function PlayingState:updatePlayer(dt)
PlayerControl.update(self, dt)
end

function PlayingState:updateAsteroids(dt)
EnemyAI.updateAsteroids(self, dt)
end

function PlayingState:updateAliens(dt)
EnemyAI.updateAliens(self, dt)
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

if self.laserGrid then
self.laserGrid:update(laser)
end

-- Remove if off screen (vertical only)
if laser.y < -laser.height or laser.y > self.screenHeight + laser.height then
if self.laserGrid then
self.laserGrid:remove(laser)
end
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
        local e = table.remove(explosions, 1)
        e.pool:release(e)
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
        explosion.pool:release(explosion)
        table.remove(explosions, i)
end
else
-- It's a regular explosion
explosion.radius = explosion.radius + explosion.speed * dt
explosion.alpha = explosion.alpha - dt

        if explosion.alpha <= 0 then
        explosion.pool:release(explosion)
        table.remove(explosions, i)
end
end
end
end

function PlayingState:updatePowerups(dt)
PowerupHandler.update(self, dt)
end

-- handled by PowerupHandler.update

function PlayingState:shootLaser()
PlayerControl.shoot(self)
end

function PlayingState:alienShoot(alien)
EnemyAI.alienShoot(self, alien)
end

function PlayingState:spawnEntities(dt)
EnemyAI.spawnEntities(self, dt)
end

function PlayingState:spawnAsteroid()
EnemyAI.spawnAsteroid(self)
end

function PlayingState:spawnAlien()
local choices = {nil, "homing", "zigzag"}
local behavior = choices[love.math.random(#choices)]
EnemyAI.spawnAlien(self, behavior)
end

function PlayingState:spawnPowerup(x, y, powerupType)
    PowerupHandler.spawn(self, x, y, powerupType)
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

if self.bossManager.activeBoss then
self:checkBossCollisions()
end
end

function PlayingState:checkPlayerCollisions()
if invulnerableTime > 0 then return end

    local grid = self.entityGrid
    for _, entity in ipairs(grid:getNearby(player)) do
        if entity.tag == "asteroid" then
            if Collision.checkAABB(player, entity) then
                local idx = self:findEntityIndex(asteroids, entity)
                if activePowerups.shield then
                    self:handleShieldHit(entity, idx or 1)
                else
                    self:handlePlayerHit(entity, idx or 1)
                end
            end
        elseif entity.tag == "alien" then
            if Collision.checkAABB(player, entity) then
                local idx = self:findEntityIndex(aliens, entity)
                if activePowerups.shield then
                    self:handleShieldHit(entity, idx or 1, aliens)
                else
                    self:handlePlayerHit(entity, idx or 1, aliens)
                end
            end
        elseif entity.tag == "enemy" and self.waveManager then
            if Collision.checkAABB(player, entity) then
                if activePowerups.shield then
                    local enemySize = math.max(entity.width, entity.height)
                    self:createExplosion(entity.x + entity.width/2, entity.y + entity.height/2, enemySize)
                    entity.active = false
                    self.entityGrid:remove(entity)
                    local _ = self:findEntityIndex(self.waveManager.enemies, entity)
                    activePowerups.shield = nil
                    if shieldBreakSound and playPositionalSound then
                        playPositionalSound(shieldBreakSound, entity.x + entity.width/2, entity.y + entity.height/2)
                    end
                else
                    self:playerHit()
                    local enemySize = math.max(entity.width, entity.height)
                    self:createExplosion(entity.x + entity.width/2, entity.y + entity.height/2, enemySize)
                    entity.active = false
                    self.entityGrid:remove(entity)
                    local _ = self:findEntityIndex(self.waveManager.enemies, entity)
                end
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
if shieldBreakSound and playPositionalSound then
playPositionalSound(shieldBreakSound,
enemy.x + enemy.width/2,
enemy.y + enemy.height/2)
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
    local grid = self.laserGrid
    local entityGrid = self.entityGrid

    for i = #lasers, 1, -1 do
        local laser = lasers[i]
        for _, entity in ipairs(entityGrid:getNearby(laser)) do
            if entity.tag == "asteroid" and not laser._remove and Collision.checkAABB(laser, entity) then
                self:createHitEffect(laser.x, laser.y)
                local idx = self:findEntityIndex(asteroids, entity)
                self:handleAsteroidDestruction(entity, idx or 1)
                laser._remove = true
                break
            elseif entity.tag == "alien" and not laser._remove and Collision.checkAABB(laser, entity) then
                self:createHitEffect(laser.x, laser.y)
                local idx = self:findEntityIndex(aliens, entity)
                self:handleAlienDestruction(entity, idx or 1)
                laser._remove = true
                break
            elseif entity.tag == "enemy" and not laser._remove and Collision.checkAABB(laser, entity) then
                entity.health = entity.health - 1
                laser._remove = true
                if entity.health <= 0 then
                    entity.active = false
                    self.entityGrid:remove(entity)
                    local idx = self:findEntityIndex(self.waveManager.enemies, entity)
                    if idx then
                        local enemySize = math.max(entity.width, entity.height)
                        self:createExplosion(entity.x + entity.width/2, entity.y + entity.height/2, enemySize)
                        if explosionSound and playPositionalSound then
                            playPositionalSound(explosionSound, entity.x + entity.width/2, entity.y + entity.height/2)
                        end
                        local enemyScore = 50 * currentLevel
                        score = score + enemyScore
                        Persistence.addScore(enemyScore)
                        enemiesDefeated = enemiesDefeated + 1
                        self.sessionEnemiesDefeated = self.sessionEnemiesDefeated + 1
                        if score > self.previousHighScore and not self.newHighScore then
                            self.newHighScore = true
                            self:showNewHighScoreNotification()
                        end
                        if random() < 0.15 then
                            self:spawnPowerup(entity.x + entity.width/2, entity.y + entity.height/2)
                        end
                    end
                end
                break
            end
        end
        if laser._remove then
            if self.laserGrid then
                self.laserGrid:remove(laser)
            end
            self.laserPool:release(laser)
            table.remove(lasers, i)
        end
    end

end

function PlayingState:checkPowerupCollisions()
local grid = self.entityGrid
for _, powerup in ipairs(grid:getNearby(player)) do
if powerup.tag == "powerup" and Collision.checkAABB(player, powerup) then
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

if powerupSound and playPositionalSound then
playPositionalSound(powerupSound, powerup.x, powerup.y)
end

-- Create floating text
self:createPowerupText(powerup.description, powerup.x, powerup.y, powerup.color)

 if self.entityGrid then
     self.entityGrid:remove(powerup)
 end
 local _ = self:findEntityIndex(powerups, powerup)
end
end
end

function PlayingState:checkAlienCollisions()
-- Aliens vs Player Lasers handled in checkLaserCollisions
-- This function reserved for future alien-specific collision logic
end

function PlayingState:checkBossCollisions()
local bossEntity = self.bossManager.activeBoss
if not bossEntity then return end

-- Boss vs Player
if Collision.checkAABB(player, bossEntity) and invulnerableTime <= 0 then
if not activePowerups.shield then
self:playerHit()
end
end

-- Boss vs Player Lasers
for i = #lasers, 1, -1 do
local laser = lasers[i]
if Collision.checkAABB(laser, bossEntity) then
self:createHitEffect(laser.x, laser.y)  -- Add hit spark effect
self:handleBossHit(laser)
self.laserPool:release(laser)
table.remove(lasers, i)
end
end
end

function PlayingState:findEntityIndex(list, entity)
    for i = #list, 1, -1 do
        if list[i] == entity then
            return i
        end
    end
    return nil
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

    if self.combo >= 10 and random() < 0.05 then
        self:spawnPowerup(asteroid.x, asteroid.y, "coolant")
        self:createPowerupText("COMBO BONUS!", asteroid.x, asteroid.y, {0, 0.5, 1})
    end

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
if self.entityGrid then
    self.entityGrid:remove(asteroid)
end
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

    if self.combo >= 10 and random() < 0.05 then
        self:spawnPowerup(alien.x, alien.y, "coolant")
        self:createPowerupText("COMBO BONUS!", alien.x, alien.y, {0, 0.5, 1})
    end

score = score + math.floor(constants.score.alien * self.comboMultiplier)
Persistence.addScore(math.floor(constants.score.alien * self.comboMultiplier))  -- Add score to persistent storage
self:createExplosion(alien.x, alien.y, 40)
if self.entityGrid then
    self.entityGrid:remove(alien)
end
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
self.bossManager:takeDamage(laser.damage or 1)

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

function PlayingState:onBossDefeated()
score = score + constants.score.boss
Persistence.addScore(constants.score.boss)
logger.info("Boss defeated! Level %d complete", currentLevel)

if score > self.previousHighScore and not self.newHighScore then
self.newHighScore = true
self:showNewHighScoreNotification()
end

if Persistence then
Persistence.incrementBossesDefeated()
if currentLevel < 20 then
Persistence.unlockLevel(currentLevel + 1)
logger.info("Unlocked level %d", currentLevel + 1)
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
end
end

function PlayingState:onBossRemoved()
bossSpawned = false
levelComplete = true
for i = 1, 5 do
local offsetX = random(-50, 50)
local offsetY = random(-50, 50)
self:createExplosion(self.screenWidth/2 + offsetX, 150 + offsetY, 60)
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
    explosion.pool = self.explosionPool
    explosion.debrisSpawned = 0

table.insert(explosions, explosion)

    -- Create explosion ring particles with a maximum cap
    local maxCount = math.min(10, math.floor(size / 8))
    explosion.debrisMax = maxCount
    local particleCount = maxCount
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
particle.pool = self.particlePool
table.insert(explosions, particle)
end

    -- Add debris particles (rock fragments) with a maximum cap
    local debrisCount = maxCount
    for i = 1, debrisCount do
local angle = random() * pi * 2
local speed = random(50, 150)
local particle = self.debrisPool:get()
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
        particle.pool = self.debrisPool
        table.insert(explosions, particle)
        explosion.debrisSpawned = explosion.debrisSpawned + 1
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
particle.pool = self.particlePool
table.insert(explosions, particle)
end

if explosionSound and playPositionalSound then
playPositionalSound(explosionSound, x, y)
end
end

function PlayingState:createHitEffect(x, y)
-- Create a small hit effect using an explosion ring
local explosion = self.explosionPool:get()
explosion.x = x
explosion.y = y
explosion.radius = 10
explosion.maxRadius = 30
explosion.speed = 60
explosion.alpha = 0.8
explosion.pool = self.explosionPool

table.insert(explosions, explosion)
end

function PlayingState:createHeatParticle()
PlayerControl.createHeatParticle(self)
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
if gameOverSound and playPositionalSound then
playPositionalSound(gameOverSound, player.x, player.y)
end
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

if explosionSound and playPositionalSound then
playPositionalSound(explosionSound, player.x, player.y)
end
end

function PlayingState:createPowerupText(text, x, y, color)
PowerupHandler.createText(self, text, x, y, color)
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

if self.bossManager.activeBoss then
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

 -- Wave completion overlay
 if self.waveOverlay then
     local alpha = math.min(self.waveOverlay.timer / 5, 1)
     local w, h = 220, 60
     local x = self.screenWidth/2 - w/2
     local y = 40
     lg.setColor(0, 0, 0, 0.6 * alpha)
     lg.rectangle("fill", x, y, w, h, 4)
     lg.setColor(1, 1, 1, alpha)
     lg.setFont(smallFont or lg.newFont(12))
     lg.print(string.format("Kill Rate: %.1f/s", self.waveOverlay.killRate), x + 10, y + 8)
     lg.print("Max Combo: " .. self.waveOverlay.maxCombo, x + 10, y + 22)
     lg.print("Enemies: " .. self.waveOverlay.enemiesDefeated, x + 10, y + 36)
 end

-- Draw heat distortion effect
local heatPercent = player.heat / player.maxHeat
if heatPercent > 0.7 then
-- Red vignette effect
local vignetteAlpha = (heatPercent - 0.7) * 0.5  -- 0 to 0.15 alpha
lg.setColor(1, 0, 0, vignetteAlpha)
-- Draw gradient vignette
local vignetteSize = 50  -- Reduced from 100 for better performance
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
    lg.draw(sprite,
        player.x - sprite:getWidth() * spriteScale / 2,
        player.y - sprite:getHeight() * spriteScale / 2,
        0,
        spriteScale,
        spriteScale)
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
        local sprite = enemyShips and enemyShips[alien.type or "basic"]
        if sprite then
            lg.setColor(1, 1, 1, 1)
            lg.draw(sprite,
                alien.x - sprite:getWidth() * spriteScale / 2,
                alien.y - sprite:getHeight() * spriteScale / 2,
                0,
                spriteScale,
                spriteScale)
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

-- Emit trail particle
local t = self.trailPool:get()
t.x = laser.x
t.y = laser.y + laser.height / 2
t.vx = 0
t.vy = 30
t.life = 0.3
t.maxLife = 0.3
t.size = 2
t.color = {1, 1, 1, 1}
t.isTrail = true
t.pool = self.trailPool
table.insert(explosions, t)
end

for _, laser in ipairs(alienLasers) do
lg.setColor(constants.laser.alienColor)
lg.rectangle("fill", laser.x - laser.width/2, laser.y - laser.height/2,
laser.width, laser.height)

-- Emit trail particle for alien lasers
local t = self.trailPool:get()
t.x = laser.x
t.y = laser.y - laser.height / 2
t.vx = 0
t.vy = -30
t.life = 0.3
t.maxLife = 0.3
t.size = 2
t.color = {1, 0, 0, 1}
t.isTrail = true
t.pool = self.trailPool
table.insert(explosions, t)
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

    -- Emit debris as the ring expands, respecting the maximum cap
    if explosion.alpha > 0.5 and explosion.debrisSpawned < (explosion.debrisMax or 0) then
    local d = self.debrisPool:get()
local ang = random() * pi * 2
local speed = random(30, 60)
d.x = explosion.x
d.y = explosion.y
d.vx = cos(ang) * speed
d.vy = sin(ang) * speed
d.life = 0.5
d.maxLife = 0.5
d.size = 2
d.rotation = random() * pi * 2
d.rotationSpeed = (random() - 0.5) * 5
d.isDebris = true
d.color = {1, random(0.5, 1), 0}
d.pool = self.debrisPool
    table.insert(explosions, d)
    explosion.debrisSpawned = explosion.debrisSpawned + 1
    end
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
PlayerControl.handleKeyPress(self, key)
end

function PlayingState:keyreleased(key, scancode)
PlayerControl.handleKeyRelease(self, key)
end

function PlayingState:gamepadpressed(joystick, button)
PlayerControl.handleGamepadPress(self, button)
end

function PlayingState:gamepadreleased(joystick, button)
PlayerControl.handleGamepadRelease(self, button)
end

-- Boss-related methods
function PlayingState:spawnBoss()
if bossSpawned or self.bossManager.activeBoss then return end

-- Clear remaining enemies
asteroids = {}
aliens = {}
alienLasers = {}

-- Determine boss type based on level
local bossType
if currentLevel % 15 == 0 then
bossType = "quantumPhantom"
elseif currentLevel % 10 == 0 then
bossType = "voidReaper"
elseif currentLevel % 5 == 0 then
bossType = "annihilator"
else
local bossTypes = {"annihilator", "frostTitan", "stormBringer"}
bossType = bossTypes[random(#bossTypes)]
end

boss = self.bossManager:spawnBoss(bossType, self.screenWidth / 2, -100)
-- Assign sprite based on level index if available
if boss then
    if bossSprites and bossSprites[currentLevel] then
        boss.sprite = bossSprites[currentLevel]
    elseif currentLevel == 2 and boss2Sprite then
        boss.sprite = boss2Sprite
    else
        boss.sprite = bossSprite
    end
end
bossSpawned = true
self.bossDefeatNotified = false
logger.info("Boss spawned: %s at level %d", bossType, currentLevel)

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
if not self.bossManager.activeBoss then return end

local prev = self.bossManager.activeBoss
self.bossManager:update(dt)
boss = self.bossManager.activeBoss

-- Check for defeat
if boss and boss.state == "dying" and not self.bossDefeatNotified then
self:onBossDefeated()
self.bossDefeatNotified = true
end

if prev and not self.bossManager.activeBoss then
self:onBossRemoved()
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
if laserSound and playPositionalSound then
playPositionalSound(laserSound, boss.x, boss.y + boss.size/2)
end
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

elseif attackType == "bulletHell" then
local total = 20
boss.bulletHellCount = boss.bulletHellCount or 0
local spawnRate = total / 3
local expected = math.floor(boss.attackTimer * spawnRate)
while boss.bulletHellCount < expected and boss.bulletHellCount < total do
local angle = boss.bulletHellCount * 0.3
self:createBossLaser(boss.x, boss.y + boss.size/2, angle)
boss.bulletHellCount = boss.bulletHellCount + 1
end
if boss.attackTimer > 3 then
boss.bulletHellCount = nil
self:endBossAttack(4)
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
    if not self.bossManager.activeBoss then return end

    local b = self.bossManager.activeBoss
    if b.sprite then
        lg.setColor(1, 1, 1, 1)
        lg.draw(b.sprite,
            b.x - b.sprite:getWidth() * spriteScale / 2,
            b.y - b.sprite:getHeight() * spriteScale / 2,
            0,
            spriteScale,
            spriteScale)
        -- Draw any attack effects from the boss manager
        if self.bossManager.drawAttackEffects then
            self.bossManager:drawAttackEffects(b)
        end
    else
        self.bossManager:draw()
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
if victorySound and playPositionalSound then
playPositionalSound(victorySound, player.x, player.y)
end
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
local isNewHighScore = Persistence.setHighScore(score, "Player")

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
if powerupSound and playPositionalSound then
playPositionalSound(powerupSound, self.screenWidth / 2, 200)
end
end

function PlayingState:updatePerformanceMetrics()
local elapsed = love.timer.getTime() - self.sessionStartTime
if elapsed > 0 then
self.performanceMetrics.killRate = self.sessionEnemiesDefeated / elapsed
else
self.performanceMetrics.killRate = 0
end

self.performanceMetrics.combo = self.combo
if self.combo > (self.performanceMetrics.maxCombo or 0) then
self.performanceMetrics.maxCombo = self.combo
end
end

return PlayingState