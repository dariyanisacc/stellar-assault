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
local Particles = require("src.particles")
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
self.waveManager = WaveManager:new(player)
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
    self.waveStartTimer = constants.balance.waveStartDelay  -- delay between waves
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
Particles.clear()  -- Added to clean up particles
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

-- Note: Full player init would continue here (e.g., player = {x = ..., y = ..., speed = shipConfig.speed * speedUpgrade, ...})
-- Assume the rest of the code from main follows and is not in conflict.
end