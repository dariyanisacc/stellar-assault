-- Constants configuration for Stellar Assault
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
    drag = 0.98
}

-- Ship-specific configurations
constants.ships = {
    alpha = {
        name = "Alpha",
        spread = 0,           -- no spread, straight shot
        fireRate = 0.3,       -- normal fire rate
        speedMultiplier = 1.0,
        shieldMultiplier = 1.0,
        description = "Balanced fighter"
    },
    beta = {
        name = "Beta", 
        spread = 0.20,        -- small V pattern
        fireRate = 0.25,      -- faster fire rate
        speedMultiplier = 1.3,
        shieldMultiplier = 0.7,
        description = "Fast interceptor with spread shot"
    },
    gamma = {
        name = "Gamma",
        spread = 0.35,        -- wide shot
        fireRate = 0.4,       -- slower fire rate
        speedMultiplier = 0.8,
        shieldMultiplier = 1.5,
        description = "Heavy tank with wide spread"
    }
}

-- Laser settings
constants.laser = {
    speed = 550,
    damage = 1,
    width = 4,
    height = 12,
    playerColor = {0, 1, 1},
    alienColor = {1, 0, 0}
}

-- Asteroid settings
constants.asteroid = {
    baseSpeed = 100,
    speedIncrease = 20,
    minSize = 20,
    maxSize = 50,
    spawnInterval = 0.5
}

-- Alien settings
constants.alien = {
    speed = 60,
    shootInterval = 2,
    width = 40,
    height = 40,
    spawnInterval = 5
}

-- Boss settings
constants.boss = {
    annihilator = {
        hp = 800,
        speed = 80,
        teleportCooldown = 6,
        beamDuration = 3,
        beamDamage = 2
    },
    frostTitan = {
        hp = 1200,
        speed = 60,
        iceBeamCooldown = 8,
        freezeDuration = 1.5
    },
    voidReaper = {
        hp = 1500,
        speed = 100,
        blackHoleCooldown = 10,
        voidRiftDuration = 5
    },
    stormBringer = {
        hp = 1000,
        speed = 120,
        lightningCooldown = 4,
        stormDuration = 6
    },
    quantumPhantom = {
        hp = 1800,
        speed = 90,
        phaseCooldown = 3,
        decoyDuration = 5,
        bulletHellCooldown = 4
    },
    boss02 = {
        hp = 400,  -- Base HP, will scale with level
        speed = 80,
        phaseTransitionDuration = 2
    }
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
        freeze = 8
    },
    fallSpeed = 50,
    size = 20,
    vampireHealRate = 3, -- Health per second when vampire is active
    freezeSlowFactor = 0.3 -- Enemy speed multiplier when frozen
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
        huge = 48
    }
}

-- Score settings
constants.score = {
    asteroid = 10,
    alien = 25,
    powerup = 50,
    boss = 500,
    levelComplete = 1000
}

-- Level progression
constants.levels = {
    enemiesForBoss = {150, 175, 200, 225, 250}, -- Per level
    asteroidSpeedMultiplier = {1, 1.2, 1.4, 1.6, 1.8},
    alienSpawnMultiplier = {1, 0.9, 0.8, 0.7, 0.6},
    bossFrequency = 4 -- Every 4th wave → boss (as per the plan, though currently using enemiesForBoss)
}

-- Audio settings
constants.audio = {
    defaultMasterVolume = 1.0,
    defaultSFXVolume = 1.0,
    defaultMusicVolume = 0.2,
    volumeAdjustRate = 0.5 -- Volume change per second when adjusting
}

-- Window settings
constants.window = {
    defaultWidth = 800,
    defaultHeight = 600,
    minWidth = 800,
    minHeight = 600
}

return constants