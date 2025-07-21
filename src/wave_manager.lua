-- src/wave_manager.lua
-- WaveManager module for Stellar Assault
-- Handles enemy waves, spawning, and AI behaviors

local constants = require("src.constants")
local logger = require("src.logger")

local WaveManager = {}
WaveManager.__index = WaveManager

-- Enemy prototype
local Enemy = {}
Enemy.__index = Enemy

function Enemy:new(o)
    o = o or {}
    setmetatable(o, Enemy)
    o.x = o.x or 0
    o.y = o.y or 0
    o.speed = o.speed or 100
    o.width = o.width or 40
    o.height = o.height or 40
    o.size = o.size or math.max(o.width or 40, o.height or 40)  -- Add size for compatibility
    o.behavior = o.behavior or "move_left"
    o.health = o.health or 1
    o.active = true
    o.behaviorState = {}
    o.shootTimer = 0
    o.shootInterval = 2.0  -- Default shoot interval
    o.canShoot = false  -- Not all enemies shoot by default
    return o
end

-- AI behaviors
local behaviors = {}

behaviors.move_down = function(enemy, dt, player)
    -- Move downward with side-to-side waving (Galaga-style)
    enemy.y = enemy.y + enemy.speed * dt
    enemy.behaviorState.time = (enemy.behaviorState.time or 0) + dt
    enemy.x = enemy.x + math.sin(enemy.behaviorState.time * 3) * 60 * dt  -- Wave side to side
    return behaviors.move_down
end

-- Keep move_left for compatibility but redirect to move_down
behaviors.move_left = behaviors.move_down

behaviors.move_to_player = function(enemy, dt, player)
    if not player then return behaviors.move_left end
    
    local dx = player.x - enemy.x
    local dy = player.y - enemy.y
    local dist = math.sqrt(dx^2 + dy^2)
    
    if dist > 0 then
        enemy.x = enemy.x + (dx / dist) * enemy.speed * dt * 0.5
        enemy.y = enemy.y + (dy / dist) * enemy.speed * dt * 0.5
    else
        enemy.x = enemy.x - enemy.speed * dt
    end
    
    return behaviors.move_to_player
end

-- Alias for clarity
behaviors.homing = behaviors.move_to_player

behaviors.dive_attack = function(enemy, dt, player)
    enemy.behaviorState.time = (enemy.behaviorState.time or 0) + dt
    
    -- Dive downward with increasing speed and side-to-side movement
    enemy.y = enemy.y + enemy.speed * (1 + enemy.behaviorState.time * 0.5) * dt
    enemy.x = enemy.x + math.sin(enemy.behaviorState.time * 4) * 100 * dt
    
    return behaviors.dive_attack
end

behaviors.zigzag = function(enemy, dt, player)
    enemy.behaviorState.time = (enemy.behaviorState.time or 0) + dt
    
    -- Zigzag pattern moving downward
    enemy.y = enemy.y + enemy.speed * dt
    enemy.x = enemy.x + math.cos(enemy.behaviorState.time * 4) * 200 * dt
    
    return behaviors.zigzag
end

behaviors.formation = function(enemy, dt, player)
    enemy.behaviorState.time = (enemy.behaviorState.time or 0) + dt
    
    if not enemy.behaviorState.inFormation then
        -- Move to formation position at top of screen
        local targetX = enemy.behaviorState.formationX or enemy.x
        local targetY = enemy.behaviorState.formationY or 100  -- Formation at top
        
        local dx = targetX - enemy.x
        local dy = targetY - enemy.y
        
        enemy.x = enemy.x + dx * dt * 2
        enemy.y = enemy.y + dy * dt * 2
        
        -- Check if in formation
        if math.abs(dx) < 5 and math.abs(dy) < 5 then
            enemy.behaviorState.inFormation = true
        end
    else
        -- Once in formation, wave side to side and occasionally dive
        enemy.x = enemy.x + math.sin(enemy.behaviorState.time * 2) * 30 * dt
        
        -- Occasionally break formation and dive
        if math.random() < 0.001 then  -- Small chance each frame
            enemy.behaviorState.inFormation = false
            enemy.behavior = behaviors.dive_attack
            enemy.behaviorState.time = 0
        end
    end
    
    return behaviors.formation
end

behaviors.spiral = function(enemy, dt, player)
    enemy.behaviorState.time = (enemy.behaviorState.time or 0) + dt
    enemy.behaviorState.radius = (enemy.behaviorState.radius or 30) + dt * 15
    
    -- Store initial position
    if not enemy.behaviorState.startX then
        enemy.behaviorState.startX = enemy.x
        enemy.behaviorState.startY = enemy.y
    end
    
    -- Spiral pattern moving downward
    local angle = enemy.behaviorState.time * 3
    local centerX = enemy.behaviorState.startX
    local centerY = enemy.behaviorState.startY + enemy.behaviorState.time * enemy.speed
    
    enemy.x = centerX + math.cos(angle) * enemy.behaviorState.radius
    enemy.y = centerY + math.sin(angle) * enemy.behaviorState.radius * 0.5  -- Flatten spiral vertically
    
    return behaviors.spiral
end

behaviors.strafe = function(enemy, dt, player)
    enemy.behaviorState.time = (enemy.behaviorState.time or 0) + dt
    
    -- Move down slowly while strafing side to side
    enemy.y = enemy.y + enemy.speed * 0.3 * dt
    enemy.x = enemy.x + math.sin(enemy.behaviorState.time * 2) * 100 * dt
    
    -- Shoot more frequently when strafing
    if not enemy.shootInterval then
        enemy.shootInterval = 1.0  -- Faster shooting for strafe enemies
    end
    
    return behaviors.strafe
end

behaviors.kamikaze = function(enemy, dt, player)
    if not player then return behaviors.move_left end
    
    -- Check health threshold for kamikaze mode
    local healthPercent = enemy.health / (enemy.maxHealth or enemy.health)
    
    if healthPercent <= 0.5 or enemy.behaviorState.kamikazeMode then
        -- Enter kamikaze mode - accelerate toward player
        enemy.behaviorState.kamikazeMode = true
        
        local dx = player.x - enemy.x
        local dy = player.y - enemy.y
        local dist = math.sqrt(dx^2 + dy^2)
        
        if dist > 0 then
            -- Accelerate toward player
            enemy.behaviorState.speed = (enemy.behaviorState.speed or enemy.speed) + dt * 200
            enemy.x = enemy.x + (dx / dist) * enemy.behaviorState.speed * dt
            enemy.y = enemy.y + (dy / dist) * enemy.behaviorState.speed * dt
        end
        
        -- Flash red to indicate kamikaze mode
        enemy.color = {1, 0.2, 0.2, 1}
    else
        -- Normal movement until damaged (move down with waving)
        enemy.y = enemy.y + enemy.speed * dt
        enemy.behaviorState.time = (enemy.behaviorState.time or 0) + dt
        enemy.x = enemy.x + math.sin(enemy.behaviorState.time * 2) * 50 * dt
    end
    
    return behaviors.kamikaze
end

-- Wave configurations
local waveConfigs = {
    {
        -- Wave 1: Basic enemies
        enemyCount = 5,
        enemyTypes = {
            {behavior = "move_left", speed = 100, health = 1, weight = 1, canShoot = false}
        }
    },
    {
        -- Wave 2: Mix of basic and homing
        enemyCount = 8,
        enemyTypes = {
            {behavior = "move_left", speed = 120, health = 1, weight = 0.7, canShoot = true, shootInterval = 3.0},
            {behavior = "homing", speed = 80, health = 2, weight = 0.3, canShoot = false}
        }
    },
    {
        -- Wave 3: Dive attackers
        enemyCount = 10,
        enemyTypes = {
            {behavior = "move_left", speed = 130, health = 1, weight = 0.5, canShoot = true, shootInterval = 2.5},
            {behavior = "dive_attack", speed = 100, health = 2, weight = 0.3, canShoot = false},
            {behavior = "homing", speed = 90, health = 2, weight = 0.2, canShoot = true, shootInterval = 2.0}
        }
    },
    {
        -- Wave 4: Formation wave
        enemyCount = 12,
        enemyTypes = {
            {behavior = "formation", speed = 100, health = 2, weight = 0.5, canShoot = true, shootInterval = 2.0},
            {behavior = "zigzag", speed = 120, health = 1, weight = 0.3, canShoot = false},
            {behavior = "homing", speed = 100, health = 3, weight = 0.2, canShoot = true, shootInterval = 1.5}
        }
    },
    {
        -- Wave 5: Advanced patterns wave
        enemyCount = 15,
        enemyTypes = {
            {behavior = "spiral", speed = 110, health = 2, weight = 0.3, canShoot = true, shootInterval = 1.8},
            {behavior = "strafe", speed = 100, health = 2, weight = 0.3, canShoot = true, shootInterval = 1.0},
            {behavior = "kamikaze", speed = 80, health = 3, weight = 0.2, canShoot = false, maxHealth = 3},
            {behavior = "homing", speed = 100, health = 2, weight = 0.2, canShoot = true, shootInterval = 1.5}
        }
    }
}

function WaveManager:new(player)
    local self = setmetatable({}, WaveManager)
    self.player = player
    self.enemies = {}
    self.pool = {}
    self.waveNumber = 0
    self.spawnTimer = 0
    self.spawnInterval = 0.5
    self.waveActive = false
    self.remainingToSpawn = 0
    self.enemiesSpawned = 0
    self.playerPerformance = {killRate = 0, combo = 0}
    self.difficultyMultiplier = 1
    self.waveCompleteCallback = nil
    self.enemyLasers = {}  -- Store enemy lasers
    self.shootCallback = nil  -- Callback for when enemy shoots
    return self
end

function WaveManager:startWave(waveNumber)
    if waveNumber then
        self.waveNumber = waveNumber
    else
        self.waveNumber = self.waveNumber + 1
    end

    -- Calculate performance based difficulty for this wave
    local killRate = self.playerPerformance.killRate or 0
    local increase = killRate > 0.5 and 0.10 or 0.05
    -- Difficulty starts at 1 and increases per wave based on performance
    self.waveDifficulty = 1 + (self.waveNumber - 1) * increase
    
    -- Get wave config (cycle through configs if wave number exceeds available configs)
    local configIndex = ((self.waveNumber - 1) % #waveConfigs) + 1
    local config = waveConfigs[configIndex]
    
    -- Scale difficulty for higher waves
    local waveScale = 1 + (self.waveNumber - 1) * 0.1
    
    self.waveActive = true
    self.remainingToSpawn = math.floor(config.enemyCount * waveScale)
    self.enemiesSpawned = 0
    self.currentWaveConfig = config
    self.spawnTimer = 0
    
    logger.info("Starting wave " .. self.waveNumber .. " with " .. self.remainingToSpawn .. " enemies")
end

function WaveManager:getRandomEnemyType()
    local config = self.currentWaveConfig
    if not config then return nil end
    
    -- Calculate total weight
    local totalWeight = 0
    for _, enemyType in ipairs(config.enemyTypes) do
        totalWeight = totalWeight + enemyType.weight
    end
    
    -- Select based on weight
    local random = love.math.random() * totalWeight
    local currentWeight = 0
    
    for _, enemyType in ipairs(config.enemyTypes) do
        currentWeight = currentWeight + enemyType.weight
        if random <= currentWeight then
            return enemyType
        end
    end
    
    return config.enemyTypes[1]
end

function WaveManager:spawnEnemy()
    local enemyType = self:getRandomEnemyType()
    if not enemyType then return end
    
    local enemy = self:getFromPool() or Enemy:new()
    
    -- Position at top of screen (Galaga-style)
    enemy.x = love.math.random(50, love.graphics.getWidth() - 50)
    enemy.y = -enemy.height
    
    -- Apply type configuration
    enemy.speed = enemyType.speed * (self.waveDifficulty or 1)
    enemy.behavior = behaviors[enemyType.behavior] or behaviors.move_left
    enemy.behaviorName = enemyType.behavior
    enemy.health = math.ceil((enemyType.health + math.floor(self.waveNumber / 5)) * self.difficultyMultiplier * (self.waveDifficulty or 1))
    enemy.maxHealth = enemy.health
    enemy.active = true
    enemy.behaviorState = {}
    
    -- Apply shooting configuration
    enemy.canShoot = enemyType.canShoot or false
    if enemy.canShoot then
        enemy.shootInterval = enemyType.shootInterval or 2.0
        enemy.shootTimer = enemy.shootInterval * love.math.random()  -- Randomize initial shoot time
    end
    
    -- Special setup for formation enemies
    if enemyType.behavior == "formation" then
        -- Calculate formation position (grid at top of screen)
        local formationIndex = self.enemiesSpawned % 10  -- 10 enemies per row
        local row = math.floor(self.enemiesSpawned / 10)
        enemy.behaviorState.formationX = 100 + formationIndex * 60  -- 60 pixels apart
        enemy.behaviorState.formationY = 50 + row * 50  -- 50 pixels between rows
        enemy.behaviorState.time = 0
        enemy.behaviorState.inFormation = false
    end
    
    table.insert(self.enemies, enemy)
    self.enemiesSpawned = self.enemiesSpawned + 1
end

function WaveManager:update(dt)
    if not self.waveActive then return end
    
    -- Spawn enemies
    if self.remainingToSpawn > 0 then
        self.spawnTimer = self.spawnTimer - dt
        if self.spawnTimer <= 0 then
            self:spawnEnemy()
            self.remainingToSpawn = self.remainingToSpawn - 1
            local interval = self.spawnInterval / ((1 + self.waveNumber * 0.1) * self.difficultyMultiplier)
            self.spawnTimer = math.max(interval, 0.1)
        end
    end
    
    -- Update enemies
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        
        -- Update AI behavior
        if enemy.behavior then
            enemy.behavior = enemy.behavior(enemy, dt, self.player)
        end
        
        -- Update shooting
        if enemy.canShoot and enemy.shootTimer then
            enemy.shootTimer = enemy.shootTimer - dt
            if enemy.shootTimer <= 0 then
                self:enemyShoot(enemy)
                enemy.shootTimer = enemy.shootInterval
            end
        end
        
        -- Remove if off bottom of screen or dead
        if enemy.y > love.graphics.getHeight() + enemy.height or not enemy.active then
            enemy.active = false
            table.insert(self.pool, enemy)
            table.remove(self.enemies, i)
        end
    end
    
    -- Check wave completion
    if self.remainingToSpawn <= 0 and #self.enemies == 0 then
        self.waveActive = false
        logger.info("Wave " .. self.waveNumber .. " completed")
        if self.waveCompleteCallback then
            local stats = {
                killRate = self.playerPerformance.killRate,
                maxCombo = self.playerPerformance.maxCombo,
                enemiesDefeated = self.enemiesSpawned
            }
            self.waveCompleteCallback(self.waveNumber, stats)
        end
    end
end

function WaveManager:draw()
    for _, enemy in ipairs(self.enemies) do
        -- Get appropriate sprite based on behavior
        local sprite = nil
        if enemyShips then
            if enemy.behaviorName == "homing" or enemy.behaviorName == "move_to_player" then
                sprite = enemyShips.homing
            elseif enemy.behaviorName == "dive_attack" then
                sprite = enemyShips.dive
            elseif enemy.behaviorName == "zigzag" then
                sprite = enemyShips.zigzag
            elseif enemy.behaviorName == "formation" then
                sprite = enemyShips.formation
            else
                sprite = enemyShips.basic
            end
        end
        
        -- Draw sprite if available, otherwise fall back to rectangles
        if sprite then
            love.graphics.setColor(1, 1, 1, 1)
            -- Calculate scale to fit enemy dimensions * 4
            local scaleX = (enemy.width / sprite:getWidth()) * 4
            local scaleY = (enemy.height / sprite:getHeight()) * 4
            -- Draw centered at enemy position
            love.graphics.draw(sprite, enemy.x + enemy.width/2, enemy.y + enemy.height/2, 
                              0, scaleX, scaleY, sprite:getWidth()/2, sprite:getHeight()/2)
        else
            -- Fallback to colored rectangles if sprites not loaded
            if enemy.behaviorName == "homing" or enemy.behaviorName == "move_to_player" then
                love.graphics.setColor(1, 0.5, 0.5) -- Reddish for homing enemies
            elseif enemy.behaviorName == "dive_attack" then
                love.graphics.setColor(1, 1, 0.5) -- Yellowish for dive attackers
            elseif enemy.behaviorName == "zigzag" then
                love.graphics.setColor(0.5, 1, 0.5) -- Greenish for zigzag
            elseif enemy.behaviorName == "formation" then
                love.graphics.setColor(0.5, 0.5, 1) -- Bluish for formation
            else
                love.graphics.setColor(0.8, 0.8, 0.8) -- Gray for basic
            end
            
            love.graphics.rectangle("fill", enemy.x, enemy.y, enemy.width, enemy.height)
        end
        
        -- Health bar if damaged
        if enemy.health < enemy.maxHealth then
            local healthPercent = enemy.health / enemy.maxHealth
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("fill", enemy.x, enemy.y - 10, enemy.width, 4)
            love.graphics.setColor(0, 1, 0)
            love.graphics.rectangle("fill", enemy.x, enemy.y - 10, enemy.width * healthPercent, 4)
        end
        
        love.graphics.setColor(1, 1, 1)
    end
end

function WaveManager:getFromPool()
    if #self.pool > 0 then
        return table.remove(self.pool)
    end
    return nil
end

function WaveManager:checkCollisionsWithLasers(lasers, grid)
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        for _, laser in ipairs(grid:getNearby(enemy)) do
            if not laser._remove and self:checkCollision(enemy, laser) then
                enemy.health = enemy.health - 1
                laser._remove = true
                if enemy.health <= 0 then
                    enemy.active = false
                    return enemy, i
                end
                break
            end
        end
    end
    return nil
end

function WaveManager:checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function WaveManager:setWaveCompleteCallback(callback)
    -- Callback signature: function(waveNumber, stats)
    -- stats contains killRate, maxCombo, and enemiesDefeated
    self.waveCompleteCallback = callback
end

function WaveManager:clear()
    self.enemies = {}
    self.waveActive = false
    self.remainingToSpawn = 0
end

function WaveManager:getEnemyCount()
    return #self.enemies
end

function WaveManager:isActive()
    return self.waveActive
end

function WaveManager:enemyShoot(enemy)
    if not self.player then return end
    
    -- Calculate direction to player
    local dx = self.player.x + self.player.width/2 - (enemy.x + enemy.width/2)
    local dy = self.player.y + self.player.height/2 - (enemy.y + enemy.height/2)
    local dist = math.sqrt(dx*dx + dy*dy)
    
    -- Create laser
    local laser = {
        x = enemy.x + enemy.width/2 - 2,
        y = enemy.y + enemy.height,
        width = 4,
        height = 12,
        speed = 300,
        isEnemy = true
    }
    
    -- Set laser velocity based on enemy type
    if enemy.behaviorName == "homing" or enemy.behaviorName == "move_to_player" then
        -- Homing enemies shoot directly at player
        if dist > 0 then
            laser.vx = (dx / dist) * laser.speed
            laser.vy = (dy / dist) * laser.speed
        else
            laser.vx = 0
            laser.vy = laser.speed
        end
    else
        -- Other enemies shoot straight down
        laser.vx = 0
        laser.vy = laser.speed
    end
    
    -- Use callback if provided (for integration with playing state)
    if self.shootCallback then
        self.shootCallback(laser)
    else
        -- Store locally if no callback
        table.insert(self.enemyLasers, laser)
    end
end

function WaveManager:setShootCallback(callback)
    self.shootCallback = callback
end

function WaveManager:setPlayerPerformance(perf)
    self.playerPerformance = perf or self.playerPerformance
    self:updateDifficulty()
end

function WaveManager:updateDifficulty()
    local comboFactor = math.min((self.playerPerformance.combo or 0) / 10, 1)
    local killFactor = math.min((self.playerPerformance.killRate or 0) / 2, 1)
    local diff = 1 + (comboFactor + killFactor) * 0.5
    self.difficultyMultiplier = math.min(diff, 2)
end

function WaveManager:updateLasers(dt)
    -- Update locally stored lasers if any
    for i = #self.enemyLasers, 1, -1 do
        local laser = self.enemyLasers[i]
        laser.x = laser.x + (laser.vx or 0) * dt
        laser.y = laser.y + (laser.vy or laser.speed) * dt
        
        -- Remove if off screen
        if laser.y > love.graphics.getHeight() + laser.height or
           laser.x < -laser.width or
           laser.x > love.graphics.getWidth() + laser.width then
            table.remove(self.enemyLasers, i)
        end
    end
end

function WaveManager:drawLasers()
    -- Draw locally stored lasers if any
    love.graphics.setColor(1, 0, 0, 1)  -- Red for enemy lasers
    for _, laser in ipairs(self.enemyLasers) do
        love.graphics.rectangle("fill", laser.x, laser.y, laser.width, laser.height)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return WaveManager