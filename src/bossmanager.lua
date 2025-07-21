-- Boss Manager for Stellar Assault
local constants = require("src.constants")
local logger = require("src.logger")

local BossManager = {}
BossManager.__index = BossManager

-- Utility to check if a table contains a value
local function hasValue(t, value)
    for _, v in ipairs(t) do
        if v == value then return true end
    end
    return false
end

-- Boss types and their configurations
local BOSS_TYPES = {
    annihilator = {
        name = "THE ANNIHILATOR",
        health = constants.boss.annihilator.hp,
        speed = constants.boss.annihilator.speed,
        attacks = {"beamSweep", "teleport", "spreadShot"},
        color = {1, 0, 0},
        size = 80
    },
    frostTitan = {
        name = "FROST TITAN",
        health = constants.boss.frostTitan.hp,
        speed = constants.boss.frostTitan.speed,
        attacks = {"iceBeam", "freezeWave", "icicleBarrage"},
        color = {0.5, 0.8, 1},
        size = 100
    },
    voidReaper = {
        name = "VOID REAPER",
        health = constants.boss.voidReaper.hp,
        speed = constants.boss.voidReaper.speed,
        attacks = {"blackHole", "voidRift", "phaseDash"},
        color = {0.5, 0, 0.5},
        size = 90
    },
    stormBringer = {
        name = "STORM BRINGER",
        health = constants.boss.stormBringer.hp,
        speed = constants.boss.stormBringer.speed,
        attacks = {"lightning", "tornado", "thunderStorm"},
        color = {1, 1, 0},
        size = 85
    },
    quantumPhantom = {
        name = "QUANTUM PHANTOM",
        health = constants.boss.quantumPhantom.hp,
        speed = constants.boss.quantumPhantom.speed,
        attacks = {"phaseShift", "decoys", "quantumBlast", "bulletHell"},
        color = {0, 1, 1},
        size = 75
    }
}

function BossManager:new()
    local self = setmetatable({}, BossManager)
    self.activeBoss = nil
    self.attackPatterns = {}
    self:initializeAttackPatterns()
    return self
end

function BossManager:initializeAttackPatterns()
    -- Annihilator attacks
    self.attackPatterns.beamSweep = {
        duration = 3,
        cooldown = constants.boss.annihilator.beamDuration,
        execute = function(boss, dt) self:executeBeamSweep(boss, dt) end
    }
    
    self.attackPatterns.teleport = {
        duration = 0.5,
        cooldown = constants.boss.annihilator.teleportCooldown,
        execute = function(boss, dt) self:executeTeleport(boss, dt) end
    }
    
    self.attackPatterns.spreadShot = {
        duration = 1,
        cooldown = 4,
        execute = function(boss, dt) self:executeSpreadShot(boss, dt) end
    }

    -- Additional attacks introduced in later phases
    self.attackPatterns.laserRing = {
        duration = 1,
        cooldown = 5,
        execute = function(boss, dt) self:executeLaserRing(boss, dt) end
    }

    self.attackPatterns.megaBeam = {
        duration = 2,
        cooldown = 8,
        execute = function(boss, dt) self:executeMegaBeam(boss, dt) end
    }

    self.attackPatterns.bulletHell = {
        duration = 3,
        cooldown = constants.boss.quantumPhantom.bulletHellCooldown,
        execute = function(boss, dt) self:executeBulletHell(boss, dt) end
    }
end

function BossManager:spawnBoss(type, x, y)
    local config = BOSS_TYPES[type] or BOSS_TYPES.annihilator
    
    self.activeBoss = {
        type = type,
        name = config.name,
        x = x or love.graphics.getWidth() / 2,
        y = y or -100,
        width = config.size,
        height = config.size,
        size = config.size,
        health = config.health,
        maxHealth = config.health,
        speed = config.speed,
        color = config.color,
        attacks = config.attacks,
        currentAttack = nil,
        attackTimer = 0,
        attackCooldown = 0,
        phase = 1,
        state = "entering",
        stateTimer = 0,
        rotation = 0,
        shield = 0,
        maxShield = 0,
        scale = 1,
        flashTimer = 0
    }
    
    logger.info("Boss spawned: %s at phase %d", config.name, 1)
    return self.activeBoss
end

function BossManager:update(dt)
    if not self.activeBoss then return end
    
    local boss = self.activeBoss
    
    -- Update state
    self:updateState(boss, dt)
    
    -- Update movement
    self:updateMovement(boss, dt)
    
    -- Update attacks
    self:updateAttacks(boss, dt)
    
    -- Update phase transitions
    self:updatePhase(boss)
    
    -- Update visual effects
    self:updateEffects(boss, dt)
end

function BossManager:updateState(boss, dt)
    boss.stateTimer = boss.stateTimer + dt
    
    if boss.state == "entering" then
        -- Boss entrance animation
        boss.y = boss.y + 100 * dt
        if boss.y >= 150 then
            boss.state = "active"
            boss.stateTimer = 0
        end
    elseif boss.state == "phaseTransition" then
        -- Phase transition effects
        if boss.stateTimer > 2 then
            boss.state = "active"
            boss.stateTimer = 0
        end
    elseif boss.state == "dying" then
        -- Death animation
        if boss.stateTimer > 3 then
            self.activeBoss = nil
        end
    end
end

function BossManager:updateMovement(boss, dt)
    if boss.state ~= "active" then return end
    
    -- Basic movement pattern (can be overridden per boss type)
    if boss.type == "annihilator" then
        -- Hover and move side to side
        boss.x = boss.x + math.sin(boss.stateTimer * 0.5) * boss.speed * dt
    elseif boss.type == "frostTitan" then
        -- Slow, deliberate movements
        local targetX = player and player.x or boss.x
        local dx = targetX - boss.x
        boss.x = boss.x + math.min(math.max(dx * 0.5, -boss.speed), boss.speed) * dt
    end
    
    -- Keep boss on screen
    local margin = boss.size / 2
    boss.x = math.max(margin, math.min(love.graphics.getWidth() - margin, boss.x))
end

function BossManager:updateAttacks(boss, dt)
    if boss.state ~= "active" then return end
    
    -- Update cooldowns
    if boss.attackCooldown > 0 then
        boss.attackCooldown = boss.attackCooldown - dt
    end
    
    -- Execute current attack
    if boss.currentAttack then
        boss.attackTimer = boss.attackTimer + dt
        local pattern = self.attackPatterns[boss.currentAttack]
        
        if pattern then
            pattern.execute(boss, dt)
            
            if boss.attackTimer >= pattern.duration then
                boss.currentAttack = nil
                boss.attackTimer = 0
                boss.attackCooldown = pattern.cooldown
            end
        end
    elseif boss.attackCooldown <= 0 then
        -- Choose new attack
        self:selectAttack(boss)
    end
end

function BossManager:selectAttack(boss)
    local availableAttacks = {}
    
    for _, attackName in ipairs(boss.attacks) do
        if self.attackPatterns[attackName] then
            table.insert(availableAttacks, attackName)
        end
    end
    
    if #availableAttacks > 0 then
        boss.currentAttack = availableAttacks[math.random(#availableAttacks)]
        boss.attackTimer = 0
        logger.debug("Boss selected attack: %s", boss.currentAttack)
    end
end

function BossManager:updatePhase(boss)
    if boss.state == "phaseTransition" or boss.state == "dying" then return end

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
        boss.flashTimer = 0
        logger.info("Boss entered phase %d", newPhase)
        
        -- Phase-specific changes
        self:onPhaseChange(boss, newPhase)
    end
end

function BossManager:onPhaseChange(boss, phase)
    -- Add new attacks or modify behavior based on phase
    if boss.type == "annihilator" then
        if phase >= 2 and not hasValue(boss.attacks, "laserRing") then
            table.insert(boss.attacks, "laserRing")
        end
        if phase >= 3 and not hasValue(boss.attacks, "megaBeam") then
            table.insert(boss.attacks, "megaBeam")
        end
    end

    -- Increase speed in later phases
    boss.speed = boss.speed * (1 + (phase - 1) * 0.2)
end

function BossManager:updateEffects(boss, dt)
    -- Visual flash during phase transitions
    if boss.state == "phaseTransition" then
        boss.flashTimer = (boss.flashTimer or 0) + dt
        boss.flashAlpha = 0.5 + math.sin(boss.flashTimer * 8) * 0.5
        boss.scale = 1 + math.sin(boss.flashTimer * 8) * 0.1
    else
        boss.flashAlpha = nil
        boss.scale = 1
    end

    -- Rotation effect
    if boss.currentAttack == "teleport" then
        boss.rotation = boss.rotation + dt * 10
    else
        boss.rotation = boss.rotation * 0.9
    end
end

-- Attack pattern implementations
function BossManager:executeBeamSweep(boss, dt)
    -- Implementation for beam sweep attack
    if boss.attackTimer < 0.5 then
        -- Charging phase
        boss.chargingBeam = true
    else
        -- Sweeping phase
        boss.beamAngle = (boss.beamAngle or 0) + dt * 2
        -- Create beam projectiles or damage zone
    end
end

function BossManager:executeTeleport(boss, dt)
    if boss.attackTimer < 0.25 then
        -- Fade out
        boss.alpha = 1 - (boss.attackTimer / 0.25)
    elseif boss.attackTimer < 0.35 then
        -- Teleport
        boss.x = math.random(100, love.graphics.getWidth() - 100)
        boss.y = math.random(100, 300)
    else
        -- Fade in
        boss.alpha = (boss.attackTimer - 0.35) / 0.15
    end
end

function BossManager:executeSpreadShot(boss, dt)
    if boss.attackTimer == dt then -- First frame of attack
        local baseCount = 4 + boss.phase * 2
        local angleStep = math.pi / baseCount
        for i = -baseCount/2, baseCount/2 do
            local angle = i * angleStep - math.pi / 2
            self:createBossProjectile(boss.x, boss.y, angle, 300 + boss.phase * 40)
        end
    end
end

function BossManager:executeLaserRing(boss, dt)
    if boss.attackTimer == dt then -- spawn once at start
        local count = 12 + boss.phase * 2
        for i = 0, count - 1 do
            local angle = (i / count) * math.pi * 2
            self:createBossProjectile(boss.x, boss.y, angle, 250 + boss.phase * 30)
        end
    end
end

function BossManager:executeMegaBeam(boss, dt)
    if boss.attackTimer < 1 then
        boss.chargingBeam = true
    elseif boss.attackTimer >= 1 and boss.attackTimer < 1 + dt then
        boss.chargingBeam = false
        for i = -1, 1 do
            local angle = -math.pi / 2 + i * 0.05
            self:createBossProjectile(boss.x + i * 15, boss.y, angle, 400 + boss.phase * 50)
        end
    end
end

function BossManager:executeBulletHell(boss, dt)
    local total = 20
    local spawnRate = total / 3
    boss.bulletHellCount = boss.bulletHellCount or 0
    local expected = math.floor(boss.attackTimer * spawnRate)
    while boss.bulletHellCount < expected and boss.bulletHellCount < total do
        local angle = boss.bulletHellCount * 0.3
        self:createBossProjectile(boss.x, boss.y, angle, 300 + boss.phase * 40)
        boss.bulletHellCount = boss.bulletHellCount + 1
    end
    if boss.attackTimer >= 3 then
        boss.bulletHellCount = nil
    end
end

function BossManager:createBossProjectile(x, y, angle, speed)
    -- This should integrate with the main game's projectile system
    if bossLasers then
        table.insert(bossLasers, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            width = 8,
            height = 8,
            damage = 1
        })
    end
end

function BossManager:takeDamage(damage)
    if not self.activeBoss then return end
    
    local boss = self.activeBoss
    
    if boss.shield > 0 then
        boss.shield = math.max(0, boss.shield - damage)
    else
        boss.health = math.max(0, boss.health - damage)
        
        if boss.health <= 0 then
            self:defeatBoss()
        end
    end
end

function BossManager:defeatBoss()
    if not self.activeBoss then return end
    
    self.activeBoss.state = "dying"
    self.activeBoss.stateTimer = 0
    logger.info("Boss defeated: %s", self.activeBoss.name)
end

function BossManager:draw()
    if not self.activeBoss then return end
    
    local boss = self.activeBoss
    local lg = love.graphics
    
    lg.push()
    lg.translate(boss.x, boss.y)
    lg.rotate(boss.rotation)
    lg.scale(boss.scale or 1, boss.scale or 1)
    
    -- Draw based on state
    local alpha = boss.alpha or 1
    if boss.state == "phaseTransition" and boss.flashAlpha then
        alpha = boss.flashAlpha
    elseif boss.state == "phaseTransition" then
        alpha = 0.5 + math.sin(boss.stateTimer * 10) * 0.5
    elseif boss.state == "dying" then
        alpha = 1 - (boss.stateTimer / 3)
    end
    
    lg.setColor(boss.color[1], boss.color[2], boss.color[3], alpha)
    
    -- Draw boss shape (customize per type)
    if boss.type == "annihilator" then
        self:drawAnnihilator(boss)
    else
        -- Default boss drawing
        lg.rectangle("fill", -boss.width/2, -boss.height/2, boss.width, boss.height)
    end
    
    lg.pop()
    
    -- Draw attack effects
    if boss.currentAttack then
        self:drawAttackEffects(boss)
    end
end

function BossManager:drawAnnihilator(boss)
    local lg = love.graphics
    local size = boss.size
    
    -- Draw main body
    lg.circle("fill", 0, 0, size/2)
    
    -- Draw energy core
    lg.setColor(1, 0.5, 0, 0.8)
    lg.circle("fill", 0, 0, size/4)
    
    -- Draw armor plates
    lg.setColor(0.3, 0.3, 0.3)
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2
        local x = math.cos(angle) * size/3
        local y = math.sin(angle) * size/3
        lg.circle("fill", x, y, size/8)
    end
end

function BossManager:drawAttackEffects(boss)
    if boss.currentAttack == "beamSweep" and boss.chargingBeam then
        -- Draw charging effect
        local lg = love.graphics
        local pulse = math.sin(boss.attackTimer * 20) * 0.3 + 0.7
        lg.setColor(1, 0, 0, pulse)
        lg.circle("line", boss.x, boss.y, boss.size * 0.6)
    end
end

return BossManager