-- Constants configuration for Stellar Assault

-- ---------------------------------------------------------------------------
-- JSON loading
-- ---------------------------------------------------------------------------
local ok, json = pcall(require, "lunajson")
if not ok then
  ok, json = pcall(require, "src.lunajson")
end
if not ok then
  error("lunajson module not found")
end

local lf = love.filesystem

local function loadJson(path)
  local data = lf.read(path)
  if not data then
    return {}
  end
  return json.decode(data)
end

local constants = {}

-- Player settings
constants.player = {
  speed = 220,
  boostSpeed = 330,
  shield = 3,
  maxShield = 5,
  lives = 3,
  maxLives = 5,
  invulnerabilityTime = 2,
  width = 30,
  height = 30,
  -- Inertia physics
  thrust = 1500,
  maxSpeed = 800,
  drag = 0.98,
}

constants.ships = loadJson("data/ships.json")

-- Laser settings
constants.laser = {
  speed = 550,
  damage = 1,
  width = 4,
  height = 12,
  playerColor = { 0, 1, 1 },
  alienColor = { 1, 0, 0 },
}

-- Asteroid settings
constants.asteroid = {
  baseSpeed = 100,
  speedIncrease = 20,
  minSize = 20,
  maxSize = 50,
  spawnInterval = 0.5,
}

-- Alien settings
constants.alien = {
  speed = 60,
  shootInterval = 2,
  width = 40,
  height = 40,
  spawnInterval = 5,
}

-- Boss settings
constants.boss = {
  annihilator = {
    hp = 800,
    speed = 80,
    teleportCooldown = 6,
    beamDuration = 3,
    beamDamage = 2,
  },
  frostTitan = {
    hp = 1200,
    speed = 60,
    iceBeamCooldown = 8,
    freezeDuration = 1.5,
  },
  voidReaper = {
    hp = 1500,
    speed = 100,
    blackHoleCooldown = 10,
    voidRiftDuration = 5,
  },
  stormBringer = {
    hp = 1000,
    speed = 120,
    lightningCooldown = 4,
    stormDuration = 6,
  },
  quantumPhantom = {
    hp = 1800,
    speed = 90,
    phaseCooldown = 3,
    decoyDuration = 5,
    bulletHellCooldown = 4,
  },
  boss02 = {
    hp = 400, -- Base HP, will scale with level
    speed = 80,
    phaseTransitionDuration = 2,
  },
}

-- Powerup settings
constants.powerup = {
  duration = {
    shield = 10,
    rapidFire = 8,
    multiShot = 10,
    timeWarp = 6,
    magnetField = 12,
    vampire = 10,
    freeze = 8,
  },
  fallSpeed = 50,
  size = 20,
  vampireHealRate = 3, -- Health per second when vampire is active
  freezeSlowFactor = 0.3, -- Enemy speed multiplier when frozen
}

-- UI settings
constants.ui = {
  margin = 10,
  healthBarWidth = 200,
  healthBarHeight = 20,
  powerupBarWidth = 100,
  powerupBarHeight = 10,
  fontSize = {
    small = 14,
    medium = 18,
    large = 24,
    huge = 48,
  },
}

-- Score settings
constants.score = {
  asteroid = 10,
  alien = 25,
  powerup = 50,
  boss = 500,
  levelComplete = 1000,
}

-- Level progression
constants.levels = loadJson("data/levels.json")

-- Balance tuning values
constants.balance = {
  -- Chance for timed powerup spawns
  timedPowerupChance = 0.3,
  -- Seconds between timed powerup checks
  powerupInterval = 10,

  -- Enemy drop chances
  waveEnemyPowerupChance = 0.15,
  alienPowerupChance = 0.2,
  asteroidSmallPowerupChance = 0.15,
  asteroidLargePowerupChance = 0.05,
  comboBonusChance = 0.05,

  -- Gameplay pacing
  waveStartDelay = 2.0,
  maxLasers = 100,
  laserWarningThreshold = 90,

  -- Misc
  enhancedPowerupChance = 0.1,
  specialPowerupChance = 0.1,
  alienLaserSpeedMultiplier = 0.7,
  bossSpawnRate = 4,
}

-- Audio settings
constants.audio = {
  defaultMasterVolume = 1.0,
  defaultSFXVolume = 1.0,
  defaultMusicVolume = 0.2,
  volumeAdjustRate = 0.5, -- Volume change per second when adjusting
}

-- Window settings
constants.window = {
  defaultWidth = 800,
  defaultHeight = 600,
  minWidth = 800,
  minHeight = 600,
}

return constants
