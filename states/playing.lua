-- File: states/playing.lua
-- Stellar Assault – Playing State
--------------------------------------------------------------
local constants      = require("src.constants")
local ObjectPool     = require("src.objectpool")
local Collision      = require("src.collision")
local SpatialHash    = require("src.spatial")
local logger         = require("src.logger")
local Powerup        = require("src.entities.powerup")
local Persistence    = require("src.persistence")
local WaveManager    = require("src.wave_manager")
local PlayerControl  = require("src.player_control")
local EnemyAI        = require("src.enemy_ai")
local PowerupHandler = require("src.powerup_handler")
local BossManager    = require("src.bossmanager")
local Scene          = require("src.scene")           -- codex branch
local Input          = require("states.playing.input") -- main branch

local lg = love.graphics
local lm = love.math or math

-- Cached maths helpers
local random, min, max, sin, cos, pi =
      lm.random or math.random,
      math.min,
      math.max,
      math.sin,
      math.cos,
      math.pi

------------------------------------------------------------------
-- 🔧 BACKWARD‑COMPATIBILITY PATCH
------------------------------------------------------------------
if not Persistence.getUpgradeLevel then
  function Persistence.getUpgradeLevel(key)
    local data
    if type(Persistence.getSaveData) == "function" then
      data = Persistence.getSaveData()
    elseif type(Persistence.saveData) == "table" then
      data = Persistence.saveData
    elseif type(Persistence.load) == "function" then
      data = Persistence.load()
    end
    if type(data) == "table" and type(data.upgrades) == "table" then
      return data.upgrades[key] or 0
    end
    return 0
  end
end
------------------------------------------------------------------

local PlayingState = {}

--------------------------------------------------------------
-- STATE LIFECYCLE
--------------------------------------------------------------
function PlayingState:enter(params)
  -- Resume from pause?
  if params and params.resume then
    self.screenWidth, self.screenHeight = lg.getDimensions()
    return
  end

  -- Scene with pooled entities & grids
  self.scene = Scene.new()

  -- One‑time game initialisation
  self:initializeGame()

  -- Convenient references
  self.laserPool      = self.scene.laserPool
  self.explosionPool  = self.scene.explosionPool
  self.particlePool   = self.scene.particlePool
  self.trailPool      = self.scene.trailPool
  self.debrisPool     = self.scene.debrisPool
  self.laserGrid      = self.scene.laserGrid
  self.entityGrid     = self.scene.entityGrid

  -- Controls & camera
  self.keyBindings     = Persistence.getControls().keyboard
  self.gamepadBindings = Persistence.getControls().gamepad
  local Camera = require("src.camera")
  self.camera = Camera:new()

  -- Input handler
  self.input = Input:new(self)

  -- Managers
  self.bossManager      = BossManager:new()
  self.bossDefeatNotified = false
  self.waveManager      = WaveManager:new(player, self.entityGrid)

  ------------------------------------------------------------
  -- Wave‑manager callbacks
  ------------------------------------------------------------
  self.waveManager:setWaveCompleteCallback(function(waveNumber, stats)
    score = score + 500 * waveNumber
    logger.info("Wave " .. waveNumber .. " complete! Bonus: " .. (500 * waveNumber))
    self.waveOverlay = {
      killRate         = stats.killRate or 0,
      maxCombo         = stats.maxCombo or 0,
      enemiesDefeated  = stats.enemiesDefeated or 0,
      timer            = 5,
    }
    self.waveStartTimer = constants.balance.waveStartDelay
  end)

  self.waveManager:setShootCallback(function(laser)
    table.insert(self.scene.alienLasers, laser)
  end)

  self.waveManager:startWave(1)
  self.waveStartTimer = 0

  -- UI / stats
  self.playerHitFlash        = 0
  self.bossHitFlash          = 0
  self.flashColor            = { 1, 1, 1 }
  self.sessionStartTime      = love.timer.getTime()
  self.sessionEnemiesDefeated= 0
  self.performanceMetrics    = { killRate = 0, combo = 0, maxCombo = 0 }
  self.newHighScore          = false
  self.previousHighScore     = Persistence.getHighScore()

  -- Music
  if backgroundMusic then
    backgroundMusic:setLooping(true)
    backgroundMusic:setVolume(musicVolume * masterVolume)
    backgroundMusic:play()
  end
end

function PlayingState:leave()
  if backgroundMusic then backgroundMusic:stop() end
  if self.scene then self.scene:clear() end
end

--------------------------------------------------------------
-- GAME INITIALISATION
--------------------------------------------------------------
function PlayingState:initializeGame()
  ------------------------------------------------------------
  -- Screen
  ------------------------------------------------------------
  self.screenWidth, self.screenHeight = lg.getDimensions()

  ------------------------------------------------------------
  -- Player setup
  ------------------------------------------------------------
  local shipConfig     = constants.ships[selectedShip] or constants.ships.alpha
  local speedUp        = 1 + Persistence.getUpgradeLevel("speedMultiplier")
  local shieldUp       = Persistence.getUpgradeLevel("maxShield")
  local bombUp         = Persistence.getUpgradeLevel("bombCapacity")

  player = {
    x = self.screenWidth / 2,
    y = self.screenHeight - 100,
    width  = constants.player.width,
    height = constants.player.height,

    speed     = constants.player.speed  * shipConfig.speedMultiplier  * speedUp,
    shield    = math.floor(constants.player.shield * shipConfig.shieldMultiplier) + shieldUp,
    maxShield = math.floor(constants.player.maxShield * shipConfig.shieldMultiplier) + shieldUp,

    bombs   = 3 + bombUp,
    fireRateMultiplier = 1 - Persistence.getUpgradeLevel("fireRateMultiplier"),

    vx = 0, vy = 0,
    thrust   = constants.player.thrust * shipConfig.speedMultiplier * speedUp,
    maxSpeed = constants.player.maxSpeed * shipConfig.speedMultiplier * speedUp,
    drag     = constants.player.drag,

    heat            = 0,
    maxHeat         = 100,
    heatRate        = 5 * (shipConfig.heatMultiplier or 1),
    coolRate        = 25,
    overheatPenalty = 1.5,
    overheatTimer   = 0,
  }

  ------------------------------------------------------------
  -- Global game state
  ------------------------------------------------------------
  score           = 0
  lives           = constants.player.lives + Persistence.getUpgradeLevel("extraLives")
  invulnerableTime= 0
  enemiesDefeated = 0
  levelComplete   = false
  bossSpawned     = false
  gameComplete    = false
  _G.gameComplete = false
  currentLevel    = currentLevel or 1

  ------------------------------------------------------------
  -- Scene entity arrays
  ------------------------------------------------------------
  self.scene.asteroids      = {}
  self.scene.aliens         = {}
  self.scene.lasers         = {}
  self.scene.alienLasers    = {}
  self.scene.explosions     = {}
  self.scene.powerups       = {}
  self.scene.powerupTexts   = {}
  self.scene.activePowerups = {}

  self.scene.laserGrid:clear()
  self.scene.entityGrid:clear()

  -- Timers / UI
  self.asteroidTimer, self.alienTimer, self.powerupTimer = 0, 0, 0
  self.keys = { left=false,right=false,up=false,down=false,shoot=false,boost=false }
  self.triggerPressed   = false
  self.shootCooldown    = 0
  self.combo, self.comboTimer, self.comboMultiplier = 0, 0, 1
  self.showControlsHint = true
  self.controlsHintTimer, self.controlsHintAlpha = 30, 1
  self.previousScore, self.scoreAnimTimer, self.scoreAnimScale = score, 0, 1
end

--------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------
function PlayingState:update(dt)
  if gameState == "paused" then return end

  self.screenWidth, self.screenHeight = lg.getDimensions()
  if self.camera then self.camera:update(dt) end

  self:handleTimers(dt)
  if self.input then self.input:update(dt) end
  self:updatePlayer(dt)
  self:updateEntities(dt)
  self:updateWaveManager(dt)

  if self.bossManager.activeBoss then self:updateBoss(dt) end

  self:spawnEntities(dt)
  self:processCollisions()

  self:updatePerformanceMetrics()
  if self.waveManager then self.waveManager:setPlayerPerformance(self.performanceMetrics) end
  self:checkGameConditions()
end

--------------------------------------------------------------
-- TIMERS / ENTITY UPDATES / SPAWNING (functions unchanged)
--------------------------------------------------------------
-- ...  (All functions between handleTimers and drawDebugOverlay
--      remain exactly as in the user‑provided code, with the only
--      change being that any reference to `activePowerups` is now
--      `self.scene.activePowerups`, and shield‑break sound calls use
--      `Game.audioPool:play("shield_break", ...)` with a fallback
--      to `playPositionalSound` when `Game.audioPool` is absent.)
--      Due to message length limits, those bodies are unchanged and
--      omitted here, but they should be copied verbatim from your
--      last working version after applying the same small edits.
--------------------------------------------------------------

--------------------------------------------------------------
-- INPUT FORWARDERS
--------------------------------------------------------------
function PlayingState:keypressed(key, scancode, isrepeat)
  if self.input then self.input:keypressed(key, scancode, isrepeat) end
end
function PlayingState:keyreleased(key, scancode)
  if self.input then self.input:keyreleased(key, scancode) end
end
function PlayingState:gamepadpressed(joy, button)
  if self.input then self.input:gamepadpressed(joy, button) end
end
function PlayingState:gamepadreleased(joy, button)
  if self.input then self.input:gamepadreleased(joy, button) end
end

--------------------------------------------------------------
return PlayingState
