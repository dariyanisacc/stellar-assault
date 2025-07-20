local constants = require("src.constants")
local EnemyAI = {}

function EnemyAI.updateAsteroids(state, dt)
    local baseSpeed = constants.asteroid.baseSpeed
    local speedIncrease = constants.asteroid.speedIncrease
    local levelMultiplier = constants.levels.asteroidSpeedMultiplier[math.min(currentLevel, 5)]

    for i = #asteroids, 1, -1 do
        local asteroid = asteroids[i]
        if asteroid.vx then
            asteroid.x = asteroid.x + asteroid.vx * dt
            asteroid.vx = asteroid.vx * 0.98
            if asteroid.x < -asteroid.size then
                asteroid.x = state.screenWidth + asteroid.size
            elseif asteroid.x > state.screenWidth + asteroid.size then
                asteroid.x = -asteroid.size
            end
        end
        if asteroid.vy then
            asteroid.y = asteroid.y + asteroid.vy * dt
            asteroid.vy = asteroid.vy + (baseSpeed * 0.5) * dt
        else
            asteroid.y = asteroid.y + (baseSpeed + speedIncrease * currentLevel) * levelMultiplier * dt
        end
        asteroid.rotation = asteroid.rotation + asteroid.rotationSpeed * dt
        if asteroid.y > state.screenHeight + asteroid.size then
            table.remove(asteroids, i)
        end
    end
end

function EnemyAI.updateAliens(state, dt)
    for i = #aliens, 1, -1 do
        local alien = aliens[i]
        if alien.vx then
            alien.x = alien.x + alien.vx * dt
        else
            alien.y = alien.y + constants.alien.speed * dt
        end
        if alien.vy then
            alien.vy = math.abs(alien.vy)
            alien.y = alien.y + alien.vy * dt
        end
        alien.waveTimer = alien.waveTimer + dt
        if alien.vx and alien.vx ~= 0 then
            alien.y = alien.y + math.sin(alien.waveTimer * 2) * 30 * dt
        else
            alien.x = alien.x + math.sin(alien.waveTimer * 2) * 50 * dt
        end
        alien.shootTimer = alien.shootTimer - dt
        if alien.shootTimer <= 0 then
            EnemyAI.alienShoot(state, alien)
            alien.shootTimer = constants.alien.shootInterval
        end
        if alien.y > state.screenHeight + alien.height or
           alien.y < -alien.height or
           alien.x > state.screenWidth + alien.width or
           alien.x < -alien.width then
            table.remove(aliens, i)
        end
    end
end

function EnemyAI.alienShoot(state, alien)
    local laser = state.laserPool:get()
    laser.x = alien.x
    laser.y = alien.y + alien.height/2
    laser.speed = constants.laser.speed * 0.7
    laser.isAlien = true
    table.insert(alienLasers, laser)
end

function EnemyAI.spawnEntities(state, dt)
    state.asteroidTimer = state.asteroidTimer + dt
    state.alienTimer = state.alienTimer + dt
    state.powerupTimer = state.powerupTimer + dt

    local asteroidInterval = constants.asteroid.spawnInterval / math.min(currentLevel, 5)
    if state.asteroidTimer >= asteroidInterval then
        EnemyAI.spawnAsteroid(state)
        state.asteroidTimer = 0
    end

    -- WaveManager handles alien spawning now
    if state.powerupTimer >= 10 then
        if math.random() < 0.3 then
            state:spawnPowerup()
        end
        state.powerupTimer = 0
    end

    if not bossSpawned and not boss then
        local enemiesNeeded = constants.levels.enemiesForBoss[math.min(currentLevel, 5)]
        if enemiesDefeated >= enemiesNeeded then
            state:spawnBoss()
        end
    end
end

function EnemyAI.spawnAsteroid(state)
    local size = math.random(constants.asteroid.minSize, constants.asteroid.maxSize)
    local asteroid = {
        x = math.random(size, state.screenWidth - size),
        y = -size,
        size = size,
        rotation = math.random() * math.pi * 2,
        rotationSpeed = math.random() - 0.5
    }
    table.insert(asteroids, asteroid)
end

function EnemyAI.spawnAlien(state)
    local alien = {
        width = constants.alien.width,
        height = constants.alien.height,
        shootTimer = constants.alien.shootInterval,
        waveTimer = math.random() * math.pi * 2
    }
    alien.x = math.random(40, state.screenWidth - 40)
    alien.y = -alien.height
    alien.vy = constants.alien.speed
    alien.vx = 0
    table.insert(aliens, alien)
end

return EnemyAI
