-- src/constants.lua
-- Constants configuration for Stellar Assault
--  * Attempts to hot‑load data/ships.json and data/levels.json if present
--  * Falls back to the built‑in tables otherwise
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- JSON loading helpers ------------------------------------------------------
-- ---------------------------------------------------------------------------
local ok, json = pcall(require, "lunajson")
if not ok then ok, json = pcall(require, "src.lunajson") end
if not ok then
  ok, json = pcall(require, "src.json")
  if ok then
    print("[Constants] lunajson not found - using bundled json.lua")
  else
    error("[Constants] No JSON library available")
  end
end

local lf = love.filesystem

local function loadJson(path)
  local data = lf.read(path)
  if not data then return {} end
  return json.decode(data)
end

-- ---------------------------------------------------------------------------
-- Constant tables -----------------------------------------------------------
-- ---------------------------------------------------------------------------
local constants = {}

-- Colour‑blind friendly palettes (define each palette in Lua under assets/)
constants.palettes = {
  default      = require("assets.palettes.default"),
  deuteranopia = require("assets.palettes.deuteranopia"),
  tritanopia   = require("assets.palettes.tritanopia"),
}
constants.defaultPalette = "default"

-- ---------------------------------------------------------------------------
-- Player core stats
-- ---------------------------------------------------------------------------
constants.player = {
  speed               = 220,
  boostSpeed          = 330,
  shield              = 3,
  maxShield           = 5,
  lives               = 3,
  maxLives            = 5,
  invulnerabilityTime = 2,
  width               = 30,
  height              = 30,
  -- Inertia physics
  thrust   = 1500,
  maxSpeed = 800,
  drag     = 0.98,
}

-- ---------------------------------------------------------------------------
-- Ship configurations (JSON‑overrideable)
-- ---------------------------------------------------------------------------
local shipsFromFile = loadJson("data/ships.json")

constants.ships = next(shipsFromFile) and shipsFromFile or {
  falcon = {
    name             = "Falcon",
    spread           = 0.00,      -- straight shot
    fireRate         = 0.30,      -- seconds
    speedMultiplier  = 1.0,
    shieldMultiplier = 1.0,
    heatMultiplier   = 1.0,
    coolMultiplier   = 1.0,
    description      = "All‑rounder",
  },
  wraith = {
    name             = "Wraith",
    spread           = 0.20,      -- narrow V
    fireRate         = 0.25,
    speedMultiplier  = 1.3,
    shieldMultiplier = 0.7,
    heatMultiplier   = 1.25,
    coolMultiplier   = 0.95,
    description      = "Glass cannon with spread",
  },
  titan = {
    name             = "Titan",
    spread           = 0.35,      -- wide spray
    fireRate         = 0.40,
    speedMultiplier  = 0.8,
    shieldMultiplier = 1.5,
    heatMultiplier   = 0.9,
    coolMultiplier   = 1.1,
    description      = "Tank with wide spread",
  },
}

-- Back-compat aliases so existing saves/tests using alpha/beta/gamma keep working
constants.ships.alpha = constants.ships.alpha or constants.ships.falcon
constants.ships.beta  = constants.ships.beta  or constants.ships.wraith
constants.ships.gamma = constants.ships.gamma or constants.ships.titan

-- ---------------------------------------------------------------------------
-- Laser
-- ---------------------------------------------------------------------------
constants.laser = {
  speed       = 550,
  damage      = 1,
  width       = 4,
  height      = 12,
  playerColor = { 0, 1, 1 },
  alienColor  = { 1, 0, 0 },
}

-- ---------------------------------------------------------------------------
-- Asteroid
-- ---------------------------------------------------------------------------
constants.asteroid = {
  baseSpeed      = 100,
  speedIncrease  = 20,
  minSize        = 20,
  maxSize        = 50,
  spawnInterval  = 0.5,
}

-- ---------------------------------------------------------------------------
-- Alien
-- ---------------------------------------------------------------------------
constants.alien = {
  speed         = 60,
  shootInterval = 2,
  width         = 40,
  height        = 40,
  spawnInterval = 5,
}

-- ---------------------------------------------------------------------------
-- Bosses
-- ---------------------------------------------------------------------------
constants.boss = {
  annihilator = {
    hp               = 800,
    speed            = 80,
    teleportCooldown = 6,
    beamDuration     = 3,
    beamDamage       = 2,
  },
  frostTitan = {
    hp               = 1200,
    speed            = 60,
    iceBeamCooldown  = 8,
    freezeDuration   = 1.5,
  },
  voidReaper = {
    hp                = 1500,
    speed             = 100,
    blackHoleCooldown = 10,
    voidRiftDuration  = 5,
  },
  stormBringer = {
    hp               = 1000,
    speed            = 120,
    lightningCooldown = 4,
    stormDuration    = 6,
  },
  quantumPhantom = {
    hp                = 1800,
    speed             = 90,
    phaseCooldown     = 3,
    decoyDuration     = 5,
    bulletHellCooldown = 4,
  },
  boss02 = {                -- legacy entry (scales per‑level)
    hp                      = 400,
    speed                   = 80,
    phaseTransitionDuration = 2,
  },
}

-- ---------------------------------------------------------------------------
-- Power‑ups
-- ---------------------------------------------------------------------------
constants.powerup = {
  duration = {
    shield      = 10,
    rapidFire   = 8,
    multiShot   = 10,
    timeWarp    = 6,
    magnetField = 12,
    vampire     = 10,
    freeze      = 8,
  },
  fallSpeed          = 50,
  size               = 20,
  vampireHealRate    = 3,    -- HP / sec
  freezeSlowFactor   = 0.3,  -- enemy speed multiplier
}

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
constants.ui = {
  margin            = 10,
  healthBarWidth    = 200,
  healthBarHeight   = 20,
  powerupBarWidth   = 100,
  powerupBarHeight  = 10,
  fontSize = {
    small  = 14,
    medium = 18,
    large  = 24,
    huge   = 48,
  },
}

-- ---------------------------------------------------------------------------
-- Scoring
-- ---------------------------------------------------------------------------
constants.score = {
  asteroid       = 10,
  alien          = 25,
  powerup        = 50,
  boss           = 500,
  levelComplete  = 1000,
}

-- ---------------------------------------------------------------------------
-- Level progression (JSON‑overrideable)
-- ---------------------------------------------------------------------------
local levelsFromFile = loadJson("data/levels.json")

constants.levels = next(levelsFromFile) and levelsFromFile or {
  enemiesForBoss          = { 150, 175, 200, 225, 250 },
  asteroidSpeedMultiplier = { 1.0, 1.2, 1.4, 1.6, 1.8 },
  alienSpawnMultiplier    = { 1.0, 0.9, 0.8, 0.7, 0.6 },
  bossFrequency           = 4,  -- every 4th wave (legacy; kept for reference)
}

-- ---------------------------------------------------------------------------
-- Balance & pacing
-- ---------------------------------------------------------------------------
constants.balance = {
  timedPowerupChance        = 0.30,
  powerupInterval           = 10,   -- seconds
  waveEnemyPowerupChance    = 0.15,
  alienPowerupChance        = 0.20,
  asteroidSmallPowerupChance= 0.15,
  asteroidLargePowerupChance= 0.05,
  comboBonusChance          = 0.05,

  waveStartDelay            = 2.0,
  maxLasers                 = 100,
  laserWarningThreshold     = 90,

  enhancedPowerupChance     = 0.10,
  specialPowerupChance      = 0.10,
  alienLaserSpeedMultiplier = 0.7,
  bossSpawnRate             = 4,
  -- Heat system defaults (override via data/balance.json)
  heatPerShot               = 8,    -- heat added per shot (base)
  coolRate                  = 10,   -- cooling per second (base)
  softLaserMargin           = 8,    -- safety margin below maxLasers for per-trigger soft cap
}

-- Attempt to override balance from data/balance.json if provided
local balanceFromFile = loadJson("data/balance.json")
if next(balanceFromFile) then
  for k, v in pairs(balanceFromFile) do
    constants.balance[k] = v
  end
end

-- ---------------------------------------------------------------------------
-- Audio defaults
-- ---------------------------------------------------------------------------
constants.audio = {
  defaultMasterVolume = 1.0,
  defaultSFXVolume    = 1.0,
  defaultMusicVolume  = 0.2,
  volumeAdjustRate    = 0.5,   -- change per second when adjusting
}

-- ---------------------------------------------------------------------------
-- Sound effect paths (JSON‑overrideable)
-- ---------------------------------------------------------------------------
local soundsFromFile = loadJson("data/sounds.json")

constants.sounds = next(soundsFromFile) and soundsFromFile or {
  laser        = "assets/kenny assets/Sci-Fi Sounds/Audio/laserLarge_000.ogg",
  explosion    = "assets/kenny assets/Sci-Fi Sounds/Audio/explosionCrunch_000.ogg",
  powerup      = "assets/kenny assets/Sci-Fi Sounds/Audio/slime_000.ogg",
  shield_break = "assets/kenny assets/Sci-Fi Sounds/Audio/impactMetal_000.ogg",
  gameover     = "assets/kenny assets/Sci-Fi Sounds/Audio/computerNoise_001.ogg",
  menu         = "assets/kenny assets/Sci-Fi Sounds/Audio/computerNoise_000.ogg",
  victory      = "assets/kenny assets/Sci-Fi Sounds/Audio/computerNoise_003.ogg",
  background   = "assets/kenny assets/Sci-Fi Sounds/Audio/spaceEngine_001.ogg",
  boss         = "assets/kenny assets/Sci-Fi Sounds/Audio/engineCircular_003.ogg",
}

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------
constants.window = {
  defaultWidth  = 800,
  defaultHeight = 600,
  minWidth      = 800,
  minHeight     = 600,
}

return constants
