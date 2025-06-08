-- Stellar Assault Game
-- A simple endless runner where you dodge falling asteroids and fight alien UFOs
-- Sound files: laser.wav, explosion.wav, gameover.ogg, powerup.wav, menu.flac, background.mp3
-- Controller support: Xbox/PlayStation/Generic gamepads with vibration feedback

-- Declare global variables (don't use local for these)
activePowerups = nil
gameState = nil
powerupTexts = nil
aliens = nil
alienLasers = nil

function love.load()
    -- Window setup
    love.window.setTitle("Stellar Assault")
    -- Start in windowed mode initially, will apply saved settings later
    love.window.setMode(800, 600, {resizable = true})
    
    -- Set up scaling
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Game variables (initialize before anything else)
    gameState = "menu" -- Start in menu state
    enemiesDefeated = 0 -- Counter for boss spawning
    enemiesForBoss = 150 -- Enemies needed to spawn boss (will vary by level)
    lives = 3 -- Start with 3 lives
    maxLives = 5 -- Maximum lives you can have
    invulnerableTime = 0 -- Invulnerability timer after losing a life
    currentLevel = 1 -- Current game level/zone
    levelComplete = false -- Flag for level completion
    
    -- Boss variables
    boss = nil
    bossSpawned = false
    bossWarningTime = 0
    bossLasers = {}
    bossAttackPattern = 1
    bossAttackTimer = 0
    levelCompleteTimer = 0
    
    -- Menu variables
    menuSelection = 1 -- 1 = Play, 2 = Level Select, 3 = Options, 4 = Quit
    loadedSaveLevel = nil -- For displaying save info in menu
    pauseSelection = 1 -- 1 = Resume, 2 = Menu
    optionsSelection = 1 -- 1 = Resolution, 2 = Fullscreen, 3 = Master Volume, 4 = SFX Volume, 5 = Music Volume, 6 = Back
    gameOverSelection = 1 -- 1 = Restart Level, 2 = Main Menu
    levelAtDeath = 1 -- Level when player died
    
    -- Save system variables
    saveSlots = {nil, nil, nil} -- 3 save slots
    currentSaveSlot = 1 -- Currently selected save slot
    menuState = "main" -- "main", "saves", "levelselect"
    selectedSaveSlot = 1 -- For save slot menu
    selectedLevel = 1 -- For level select menu
    
    -- Options settings
    displayMode = "fullscreen" -- "windowed", "fullscreen"
    masterVolume = 1.0
    sfxVolume = 1.0
    musicVolume = 0.2  -- Default 20% for background music
    
    -- Resolution settings
    resolutions = {
        {width = 800, height = 600, name = "800x600 (4:3)"},
        {width = 1024, height = 768, name = "1024x768 (4:3)"},
        {width = 1280, height = 720, name = "1280x720 (16:9)"},
        {width = 1366, height = 768, name = "1366x768 (16:9)"},
        {width = 1920, height = 1080, name = "1920x1080 (16:9)"},
        {width = 2560, height = 1080, name = "2560x1080 (21:9)"},
        {width = 2560, height = 1440, name = "2560x1440 (16:9)"},
        {width = 3440, height = 1440, name = "3440x1440 (21:9)"},
        {width = 3840, height = 1600, name = "3840x1600 (21:9)"},
        {width = 3840, height = 2160, name = "3840x2160 (16:9)"},
        {width = 5120, height = 1440, name = "5120x1440 (32:9)"},
        {width = 5120, height = 2160, name = "5120x2160 (21:9)"}
    }
    currentResolution = 1 -- Default to 800x600
    baseWidth = 800  -- Base game width
    baseHeight = 600 -- Base game height
    
    -- Screen scaling for fullscreen
    screenScale = 1
    screenOffsetX = 0
    screenOffsetY = 0
    
    -- Player setup
    player = {
        x = baseWidth/2 - 14,  -- Center player (adjusted for new width)
        y = 500,
        width = 28,  -- Smaller hitbox for more forgiving gameplay
        height = 34, -- Smaller hitbox for more forgiving gameplay
        speed = 450,  -- Increased speed for better maneuverability
        health = 3,
        maxHealth = 3
    }
    
    -- Asteroids table
    asteroids = {}
    asteroidTimer = 0
    asteroidSpawnTime = 1.8 -- Spawn every 1.8 seconds (increased from 2.5)
    
    -- Aliens setup
    aliens = {}
    alienTimer = 0
    alienSpawnTime = 2.5 -- Spawn every 2.5 seconds (increased from 4.0)
    alienLasers = {}
    
    -- Lasers setup
    lasers = {}
    laserCooldown = 0
    laserCooldownTime = 0.5 -- Can shoot every 0.5 seconds (was 0.3)
    
    -- Explosions setup
    explosions = {}
    
    -- Active powerup effects
    activePowerups = {
        tripleShot = 0,
        rapidFire = 0,
        shield = 0,
        slowTime = 0,
        homing = 0,
        pierce = 0,
        freeze = 0,
        vampire = 0
    }
    
    -- Powerups setup
    powerups = {}
    powerupTexts = {}
    powerupChance = 15 -- 15% chance to drop from destroyed asteroids
    
    -- Wave system for extra challenge
    waveTimer = 0
    waveSpawnTime = 10 -- Spawn a wave every 10 seconds (reduced from 15)
    waveActive = false
    
    -- Stars setup
    stars = {}
    createStarfield()
    
    -- Colors
    backgroundColor = {0.1, 0.1, 0.2}
    laserColor = {0, 1, 0.5} -- Bright green laser
    
    -- Level-specific configurations
    levelBackgrounds = {
        {0.1, 0.1, 0.2},    -- Level 1: Space
        {0.15, 0.05, 0.2},  -- Level 2: Nebula (purple)
        {0.7, 0.8, 0.9},    -- Level 3: Ice Moon (icy blue-white)
        {0.1, 0.2, 0.1},    -- Level 4: Mothership (green-organic)
        {0.3, 0.1, 0.05}    -- Level 5: Solar (orange-red)
    }
    
    -- Level 3 - Ground vehicle variables
    vehicleMode = "ship"  -- "ship" or "tank"
    gravity = 0
    iceGeysers = {}
    groundY = 500  -- Ground level for tank mode
    
    -- Level 4 - Mothership interior variables
    leftWall = 100
    rightWall = 700
    corridorWidth = 600
    doors = {}
    energyBarriers = {}
    alienSpawners = {}
    
    -- Level 5 - Solar corona variables
    heatMeter = 0
    maxHeat = 100
    solarFlares = {}
    shadeZones = {}
    plasmaStorms = {}
    
    -- Developer cheats (for debugging)
    cheatsEnabled = false
    debugMode = false
    godMode = false
    infinitePowerups = false
    rapidFireCheat = false
    showHitboxes = false
    showFPS = false
    noclipMode = false
    
    -- Fonts
    font = love.graphics.newFont(32)  -- Bigger main font
    smallFont = love.graphics.newFont(18)  -- Bigger small font
    love.graphics.setFont(font)
    
    -- Sound setup with your actual sound files
    sounds = {}
    
    -- Load laser sound
    if love.filesystem.getInfo("laser.wav") then
        sounds.laser = love.audio.newSource("laser.wav", "static")
        sounds.laser:setVolume(0.3 * sfxVolume * masterVolume)
    end
    
    -- Load explosion sound
    if love.filesystem.getInfo("explosion.wav") then
        sounds.explosion = love.audio.newSource("explosion.wav", "static")
        sounds.explosion:setVolume(0.5 * sfxVolume * masterVolume)
    end
    
    -- Load gameover sound
    if love.filesystem.getInfo("gameover.ogg") then
        sounds.gameover = love.audio.newSource("gameover.ogg", "static")
        sounds.gameover:setVolume(sfxVolume * masterVolume)
    end
    
    -- Load powerup sound
    if love.filesystem.getInfo("powerup.wav") then
        sounds.powerup = love.audio.newSource("powerup.wav", "static")
        sounds.powerup:setVolume(0.4 * sfxVolume * masterVolume)
    end
    
    -- Load menu sound
    if love.filesystem.getInfo("menu.flac") then
        sounds.menu = love.audio.newSource("menu.flac", "static")
        sounds.menu:setVolume(0.3 * sfxVolume * masterVolume)
    end
    
    -- Load background music
    if love.filesystem.getInfo("background.mp3") then
        sounds.music = love.audio.newSource("background.mp3", "stream")
        sounds.music:setLooping(true)
        sounds.music:setVolume(musicVolume * masterVolume)
        sounds.music:play()
    end
    
    -- Game statistics
    score = 0
    highScore = 0
    totalAsteroidsDestroyed = 0
    totalShotsFired = 0
    currentCombo = 0
    maxCombo = 0
    nextLifeScore = 5000
    
    -- Load high score if it exists
    if love.filesystem.getInfo("highscore.txt") then
        local data = love.filesystem.read("highscore.txt")
        highScore = tonumber(data) or 0
    end
    
    -- Load all save slots
    loadAllSaveSlots()
    
    -- Controller setup
    gamepad = nil
    deadzone = 0.25  -- Analog stick deadzone
    menuCooldown = 0  -- Prevent rapid menu navigation with analog stick
    
    -- Check for connected gamepads
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        for _, joystick in ipairs(joysticks) do
            if joystick:isGamepad() then
                gamepad = joystick
                print("Gamepad detected: " .. gamepad:getName())
                break
            end
        end
    end
    
    -- Apply saved display mode
    applyDisplayMode()
    
    -- Debug output to confirm state
    print("Game initialized with ultrawide support!")
    print("Sound files loaded:")
    for name, _ in pairs(sounds) do
        print("  - " .. name)
    end
end  -- End of love.load()

function love.update(dt)
    -- Update stars (always update, even in game over or paused)
    updateStars(dt)
    
    -- Update menu cooldown for analog stick navigation
    if menuCooldown > 0 then
        menuCooldown = menuCooldown - dt
    end
    
    -- Handle analog stick menu navigation
    if gamepad and gamepad:isGamepad() and menuCooldown <= 0 then
        local leftY = gamepad:getGamepadAxis("lefty")
        local leftX = gamepad:getGamepadAxis("leftx")
        
        if gameState == "menu" or gameState == "paused" then
            if leftY < -deadzone then -- Up
                if gameState == "menu" then
                    menuSelection = menuSelection - 1
                    if menuSelection < 1 then menuSelection = 3 end
                else
                    pauseSelection = 1
                end
                playMenuSound()
                menuCooldown = 0.2
            elseif leftY > deadzone then -- Down
                if gameState == "menu" then
                    menuSelection = menuSelection + 1
                    if menuSelection > 3 then menuSelection = 1 end
                else
                    pauseSelection = 2
                end
                playMenuSound()
                menuCooldown = 0.2
            end
        elseif gameState == "options" then
            if leftY < -deadzone then -- Up
                optionsSelection = optionsSelection - 1
                if optionsSelection < 1 then optionsSelection = 6 end
                playMenuSound()
                menuCooldown = 0.2
            elseif leftY > deadzone then -- Down
                optionsSelection = optionsSelection + 1
                if optionsSelection > 6 then optionsSelection = 1 end
                playMenuSound()
                menuCooldown = 0.2
            end
            
            -- Handle left/right for options adjustment
            if leftX < -deadzone then -- Left
                if optionsSelection == 1 then
                    -- Previous resolution
                    currentResolution = currentResolution - 1
                    if currentResolution < 1 then currentResolution = #resolutions end
                    if displayMode == "windowed" then
                        love.window.setMode(resolutions[currentResolution].width, resolutions[currentResolution].height, {resizable = true})
                    end
                    playMenuSound()
                    menuCooldown = 0.2
                elseif optionsSelection == 2 then
                    -- Cycle display mode left
                    if displayMode == "windowed" then
                        displayMode = "fullscreen"
                    else
                        displayMode = "windowed"
                    end
                    applyDisplayMode()
                    playMenuSound()
                    menuCooldown = 0.2
                elseif optionsSelection == 3 then
                    -- Decrease master volume
                    masterVolume = math.max(0, masterVolume - 0.01 * dt * 60) -- Frame-independent smooth control
                    updateAllVolumes()
                elseif optionsSelection == 4 then
                    -- Decrease SFX volume
                    sfxVolume = math.max(0, sfxVolume - 0.01 * dt * 60)
                    updateAllVolumes()
                elseif optionsSelection == 5 then
                    -- Decrease music volume
                    musicVolume = math.max(0, musicVolume - 0.01 * dt * 60)
                    updateAllVolumes()
                end
            elseif leftX > deadzone then -- Right
                if optionsSelection == 1 then
                    -- Next resolution
                    currentResolution = currentResolution + 1
                    if currentResolution > #resolutions then currentResolution = 1 end
                    if displayMode == "windowed" then
                        love.window.setMode(resolutions[currentResolution].width, resolutions[currentResolution].height, {resizable = true})
                    end
                    playMenuSound()
                    menuCooldown = 0.2
                elseif optionsSelection == 2 then
                    -- Cycle display mode right
                    if displayMode == "windowed" then
                        displayMode = "fullscreen"
                    else
                        displayMode = "windowed"
                    end
                    applyDisplayMode()
                    playMenuSound()
                    menuCooldown = 0.2
                elseif optionsSelection == 3 then
                    -- Increase master volume
                    masterVolume = math.min(1, masterVolume + 0.01 * dt * 60)
                    updateAllVolumes()
                elseif optionsSelection == 4 then
                    -- Increase SFX volume
                    sfxVolume = math.min(1, sfxVolume + 0.01 * dt * 60)
                    updateAllVolumes()
                elseif optionsSelection == 5 then
                    -- Increase music volume
                    musicVolume = math.min(1, musicVolume + 0.01 * dt * 60)
                    updateAllVolumes()
                end
            end
        elseif gameState == "gameover" then
            if leftY < -deadzone then -- Up
                gameOverSelection = gameOverSelection - 1
                if gameOverSelection < 1 then gameOverSelection = 2 end
                playMenuSound()
                menuCooldown = 0.2
            elseif leftY > deadzone then -- Down
                gameOverSelection = gameOverSelection + 1
                if gameOverSelection > 2 then gameOverSelection = 1 end
                playMenuSound()
                menuCooldown = 0.2
            end
        end
    end
    
    if gameState == "menu" then
        -- Menu doesn't need updates, just waiting for input
    elseif gameState == "options" then
        -- Options menu doesn't need updates
    elseif gameState == "paused" then
        -- Game is paused, don't update gameplay
    elseif gameState == "playing" then
        -- Player movement with keyboard (omnidirectional)
        if love.keyboard.isDown("left") and player.x > 0 then
            player.x = player.x - player.speed * dt
        end
        if love.keyboard.isDown("right") and player.x < (baseWidth - player.width) then
            player.x = player.x + player.speed * dt
        end
        -- Vertical movement depends on vehicle mode
        if vehicleMode == "tank" then
            -- Tank can only move slightly up/down on ground
            if love.keyboard.isDown("up") and player.y > groundY - player.height - 20 then
                player.y = player.y - player.speed * 0.3 * dt
            end
            if love.keyboard.isDown("down") and player.y < groundY - player.height then
                player.y = player.y + player.speed * 0.3 * dt
            end
        else
            -- Normal ship movement
            if love.keyboard.isDown("up") and player.y > 200 then
                player.y = player.y - player.speed * dt
            end
            if love.keyboard.isDown("down") and player.y < (baseHeight - player.height - 10) then
                player.y = player.y + player.speed * dt
            end
        end
        
        -- Player movement with gamepad (omnidirectional)
        if gamepad and gamepad:isGamepad() then
            local leftX = gamepad:getGamepadAxis("leftx")
            local leftY = gamepad:getGamepadAxis("lefty")
            
            -- Apply deadzone for X axis
            if math.abs(leftX) > deadzone then
                player.x = player.x + leftX * player.speed * dt
                -- Clamp to screen bounds
                player.x = math.max(0, math.min(baseWidth - player.width, player.x))
            end
            
            -- Apply deadzone for Y axis
            if math.abs(leftY) > deadzone then
                player.y = player.y + leftY * player.speed * dt
                -- Clamp to screen bounds (can't go too far forward)
                player.y = math.max(200, math.min(baseHeight - player.height - 10, player.y))
            end
        end
        
        -- Shooting with keyboard
        laserCooldown = laserCooldown - dt
        local currentCooldown = laserCooldownTime
        if activePowerups.rapidFire > 0 then
            currentCooldown = 0.1 -- Much faster shooting
        end
        
        local shouldShoot = love.keyboard.isDown("space")
        
        -- Shooting with gamepad (A button or right trigger)
        if gamepad and gamepad:isGamepad() then
            shouldShoot = shouldShoot or gamepad:isGamepadDown("a") or gamepad:getGamepadAxis("triggerright") > 0.5
        end
        
        if shouldShoot and laserCooldown <= 0 then
            shootLaser()
            laserCooldown = currentCooldown
        end
        
        -- Update lasers
        for i = #lasers, 1, -1 do
            local laser = lasers[i]
            if not laser then
                goto continue_laser
            end
            
            -- Homing behavior
            if laser.homing then
                local closestEnemy = nil
                local closestDist = 200 -- Max homing range
                
                -- Find closest enemy
                for _, asteroid in ipairs(asteroids) do
                    local dist = math.sqrt((asteroid.x + asteroid.width/2 - laser.x)^2 + 
                                         (asteroid.y + asteroid.height/2 - laser.y)^2)
                    if dist < closestDist then
                        closestDist = dist
                        closestEnemy = asteroid
                    end
                end
                
                for _, alien in ipairs(aliens) do
                    local dist = math.sqrt((alien.x + alien.width/2 - laser.x)^2 + 
                                         (alien.y + alien.height/2 - laser.y)^2)
                    if dist < closestDist then
                        closestDist = dist
                        closestEnemy = alien
                    end
                end
                
                -- Adjust velocity toward closest enemy
                if closestEnemy then
                    local dx = closestEnemy.x + closestEnemy.width/2 - laser.x
                    local dy = closestEnemy.y + closestEnemy.height/2 - laser.y
                    local angle = math.atan2(dy, dx)
                    laser.vx = math.cos(angle) * 300
                    laser.speed = 500 - math.sin(angle) * 300
                end
            end
            
            laser.y = laser.y - laser.speed * dt
            if laser.vx then
                laser.x = laser.x + laser.vx * dt
            end
            
            -- Check collision with doors in level 4
            local hitDoor = false
            if currentLevel == 4 then
                for _, door in ipairs(doors) do
                    -- Check if laser hits the left part of the door
                    if laser.x >= leftWall and laser.x <= door.gapX and 
                       laser.y >= door.y and laser.y <= door.y + door.height then
                        hitDoor = true
                        break
                    end
                    -- Check if laser hits the right part of the door
                    if laser.x >= door.gapX + door.gapWidth and laser.x <= rightWall and
                       laser.y >= door.y and laser.y <= door.y + door.height then
                        hitDoor = true
                        break
                    end
                end
            end
            
            -- Remove lasers that go off screen or hit doors
            if laser.y < -laser.height or laser.x < 0 or laser.x > baseWidth or hitDoor then
                table.remove(lasers, i)
            end
            ::continue_laser::
        end
        
        -- Update invulnerability timer
        if invulnerableTime > 0 then
            invulnerableTime = invulnerableTime - dt
        end
        
        -- Check for boss spawn based on enemies defeated
        if enemiesDefeated >= enemiesForBoss and not bossSpawned and not boss and not levelComplete then
            -- Start boss warning
            if bossWarningTime == 0 then
                bossWarningTime = 3 -- 3 second warning
                createPowerupText("WARNING: BOSS APPROACHING!", baseWidth/2, 200, {1, 0, 0})
                -- Stop spawning regular enemies
                asteroidSpawnTime = 999999
                alienSpawnTime = 999999
            end
            
            bossWarningTime = bossWarningTime - dt
            if bossWarningTime <= 0 then
                spawnBoss()
                bossSpawned = true
            end
        end
        
        -- Update boss warning effect
        if bossWarningTime > 0 then
            -- Clear some enemies during warning
            if #asteroids > 5 then
                table.remove(asteroids, 1)
            end
            if #aliens > 2 then
                table.remove(aliens, 1)
            end
        end
        
        -- Spawn enemies based on level
        if not boss and (not bossWarningTime or bossWarningTime <= 0) then
            -- Level-specific spawning for ALL levels
            spawnLevelEnemies(dt)
            
            -- Wave spawning system for all levels
            if currentLevel >= 1 then
                waveTimer = waveTimer + dt
                if waveTimer >= waveSpawnTime and not waveActive then
                    -- Spawn a wave of enemies
                    waveActive = true
                    waveTimer = 0
                    
                    -- Wave announcement
                    createPowerupText("ENEMY WAVE INCOMING!", baseWidth/2, 100, {1, 0.5, 0})
                    
                    -- Spawn wave based on level
                    if currentLevel == 1 then
                        -- Level 1 wave: 3-4 asteroids + 1-2 aliens
                        for i = 1, math.random(3, 4) do
                            spawnAsteroid()
                        end
                        for i = 1, math.random(1, 2) do
                            spawnAlien()
                        end
                    elseif currentLevel == 2 then
                        -- Level 2 wave: 5-7 asteroids + 3-4 aliens
                        for i = 1, math.random(5, 7) do
                            spawnAsteroid()
                        end
                        for i = 1, math.random(3, 4) do
                            spawnAlien()
                        end
                    elseif currentLevel >= 3 then
                        -- Level 3+ wave: 6-8 asteroids + 4-6 aliens
                        for i = 1, math.random(6, 8) do
                            spawnAsteroid()
                        end
                        for i = 1, math.random(4, 6) do
                            spawnAlien()
                        end
                    end
                end
                
                -- Reset wave after 5 seconds
                if waveActive and waveTimer >= 5 then
                    waveActive = false
                end
            end
        end
        
        -- Update asteroids
        for i = #asteroids, 1, -1 do
            local asteroid = asteroids[i]
            if not asteroid then
                goto continue
            end
            
            local speedMultiplier = 1
            if activePowerups.slowTime > 0 then
                speedMultiplier = 0.3 -- Slow down to 30% speed
            end
            
            -- Update freeze timer
            if asteroid.frozen and asteroid.freezeTime then
                asteroid.freezeTime = asteroid.freezeTime - dt
                if asteroid.freezeTime <= 0 then
                    asteroid.frozen = false
                    asteroid.freezeTime = nil
                end
                speedMultiplier = 0 -- Frozen asteroids don't move
            end
            
            -- Update position with velocity
            if asteroid.vx then
                asteroid.x = asteroid.x + (asteroid.vx * speedMultiplier) * dt
            end
            if asteroid.vy then
                asteroid.y = asteroid.y + (asteroid.vy * speedMultiplier) * dt
            else
                -- Fallback for old movement system
                asteroid.y = asteroid.y + (asteroid.speed * speedMultiplier) * dt
            end
            
            -- Update rotation
            if asteroid.rotation and asteroid.rotationSpeed then
                asteroid.rotation = asteroid.rotation + asteroid.rotationSpeed * dt
            end
            
            -- Update damage timer for nebula clouds
            if asteroid.damageTimer and asteroid.damageTimer > 0 then
                asteroid.damageTimer = asteroid.damageTimer - dt
            end
            
            -- Bounce off screen edges for fragments
            if asteroid.type == "fragment" then
                if asteroid.x <= 0 or asteroid.x >= baseWidth - asteroid.width then
                    asteroid.vx = -asteroid.vx * 0.8 -- Lose some energy on bounce
                    asteroid.x = math.max(0, math.min(baseWidth - asteroid.width, asteroid.x))
                end
            end
            
            -- Check laser collisions
            local destroyed = false
            for j = #lasers, 1, -1 do
                local laser = lasers[j]
                if checkCollision(laser, asteroid) then
                    -- Special handling for nebula clouds
                    if asteroid.type == "nebulacloud" then
                        -- Piercing shots pass through nebula clouds
                        if not laser.pierce then
                            -- Non-piercing shots are absorbed by nebula
                            table.remove(lasers, j)
                        end
                        -- Skip damage calculation for nebula clouds
                        goto nextLaser
                    end
                    
                    -- Handle pierce powerup for normal asteroids
                    if laser.pierce and laser.pierceCount < 3 then
                        laser.pierceCount = laser.pierceCount + 1
                    else
                        table.remove(lasers, j)
                    end
                    
                    -- Only damage objects that have health
                    if asteroid.health then
                        asteroid.health = asteroid.health - 1
                        
                        -- Freeze powerup - freeze asteroid
                        if activePowerups.freeze > 0 and not asteroid.frozen then
                            asteroid.frozen = true
                            asteroid.freezeTime = 2 -- Freeze for 2 seconds
                        end
                        
                        -- Vampire powerup - heal on hit
                        if activePowerups.vampire > 0 and player.health < player.maxHealth then
                            player.health = math.min(player.health + 1, player.maxHealth)
                            createPowerupText("+1 HP", player.x + player.width/2, player.y - 20, {0.8, 0.2, 0.8})
                        end
                        
                        if asteroid.health <= 0 then
                        destroyed = true
                        enemiesDefeated = enemiesDefeated + 1
                        totalAsteroidsDestroyed = totalAsteroidsDestroyed + 1
                        currentCombo = currentCombo + 1
                        if currentCombo > maxCombo then
                            maxCombo = currentCombo
                        end
                        
                        -- Check if asteroid should break apart
                        if asteroid.canBreakApart and math.random() < 0.7 then -- 70% chance to break apart
                            spawnAsteroidFragments(asteroid)
                        else
                            -- Normal explosion
                            createExplosion(
                                asteroid.x + asteroid.width/2, 
                                asteroid.y + asteroid.height/2,
                                asteroid.width/2
                            )
                        end
                        
                        -- Chance to spawn powerup
                        local dropChance = powerupChance
                        -- Higher chance for larger asteroids
                        if asteroid.type == "large" then
                            dropChance = 50
                        elseif asteroid.type == "metal" then
                            dropChance = 40
                        end
                        
                        if math.random(100) <= dropChance then
                            spawnPowerup(asteroid.x + asteroid.width/2, asteroid.y + asteroid.height/2)
                        end
                    else
                        -- Hit but not destroyed - smaller explosion effect
                        createHitEffect(
                            asteroid.x + asteroid.width/2,
                            asteroid.y + asteroid.height/2
                        )
                        
                        -- Add some knockback to the asteroid
                        if asteroid.vx then
                            asteroid.vx = asteroid.vx + math.random(-50, 50)
                        end
                    end
                    end  -- End of if asteroid.health check
                    break
                end
                ::nextLaser::
            end
            
            if destroyed then
                table.remove(asteroids, i)
            elseif asteroid.y > baseHeight then
                -- Remove asteroids that go off screen
                table.remove(asteroids, i)
                -- Reset combo when asteroid escapes
                currentCombo = 0
            else
                -- Check collision with player
                if checkCollision(player, asteroid) and invulnerableTime <= 0 then
                    -- Handle different collision types
                    if asteroid.type == "nebulacloud" then
                        -- Nebula clouds do damage over time, not instant destruction
                        if not asteroid.damageTimer or asteroid.damageTimer <= 0 then
                            if activePowerups.shield > 0 then
                                activePowerups.shield = activePowerups.shield - 1
                                createPowerupText("SHIELD DAMAGED!", player.x, player.y - 30, {1, 0.5, 0})
                            else
                                loseLife()
                            end
                            asteroid.damageTimer = 1.0  -- Can only damage once per second
                        end
                    else
                        -- Regular asteroid collision
                        if activePowerups.shield > 0 then
                            -- Shield absorbs hit
                            activePowerups.shield = 0
                            -- Shield break effect
                            createShieldBreakEffect(
                                player.x + player.width/2,
                                player.y + player.height/2
                            )
                            createExplosion(
                                asteroid.x + asteroid.width/2, 
                                asteroid.y + asteroid.height/2,
                                asteroid.width/2
                            )
                            -- Remove the asteroid that hit the shield
                            table.remove(asteroids, i)
                            -- Medium rumble for shield break
                            if gamepad and gamepad:isGamepad() then
                                gamepad:setVibration(0.6, 0.6, 0.3)
                            end
                        else
                            -- Lose a life
                            loseLife()
                            -- Destroy the asteroid that hit us
                            createExplosion(
                                asteroid.x + asteroid.width/2, 
                                asteroid.y + asteroid.height/2,
                            asteroid.width/2
                        )
                        table.remove(asteroids, i)
                        end
                    end
                end
            end
            ::continue::
        end  -- This closes the for loop for asteroids
        
        -- Update aliens
        for i = #aliens, 1, -1 do
            local alien = aliens[i]
            
            -- Skip if alien is nil
            if not alien then
                table.remove(aliens, i)
                goto continueAlien
            end
            
            local speedMultiplier = 1
            if activePowerups.slowTime > 0 then
                speedMultiplier = 0.3 -- Slow down aliens too
            end
            
            -- Update freeze timer
            if alien.frozen and alien.freezeTime then
                alien.freezeTime = alien.freezeTime - dt
                if alien.freezeTime <= 0 then
                    alien.frozen = false
                    alien.freezeTime = nil
                end
                speedMultiplier = 0 -- Frozen aliens don't move
            end
            
            -- Update movement (only if alien has velocity)
            if alien.vx and alien.vy then
                alien.x = alien.x + (alien.vx * speedMultiplier) * dt
                alien.y = alien.y + (alien.vy * speedMultiplier) * dt
                
                -- Change direction at screen edges
                if alien.x <= 0 or alien.x >= baseWidth - alien.width then
                    alien.vx = -alien.vx
                    alien.x = math.max(0, math.min(baseWidth - alien.width, alien.x))
                end
            end
            
            -- Update shooting cooldown (if alien can shoot)
            if alien.shootCooldown then
                alien.shootCooldown = alien.shootCooldown - dt
                
                -- Shoot at player if in range and cooldown is ready (don't shoot at invulnerable player)
                if alien.shootCooldown <= 0 and alien.y > 50 and alien.y < 400 and invulnerableTime <= 0 then
                -- Calculate angle to player
                local dx = (player.x + player.width/2) - (alien.x + alien.width/2)
                local dy = (player.y + player.height/2) - (alien.y + alien.height/2)
                local distance = math.sqrt(dx*dx + dy*dy)
                
                if distance > 0 then
                    -- Normalize and create laser
                    local laserSpeed = 250
                    local alienLaser = {
                        x = alien.x + alien.width/2 - 2,
                        y = alien.y + alien.height,
                        width = 4,
                        height = 12,
                        vx = (dx / distance) * laserSpeed * 0.5, -- Some horizontal tracking
                        vy = laserSpeed, -- Mostly downward
                        damage = 1
                    }
                    table.insert(alienLasers, alienLaser)
                    alien.shootCooldown = alien.shootInterval or 2.0  -- Default to 2 seconds if not defined
                    
                    -- Play alien laser sound (higher pitched)
                    if sounds.laser then
                        local alienLaserSound = sounds.laser:clone()
                        alienLaserSound:setPitch(1.5) -- Higher pitch for alien lasers
                        alienLaserSound:setVolume(0.2 * sfxVolume * masterVolume)
                        alienLaserSound:play()
                    end
                end
            end
            end  -- Close the shootCooldown if block
            
            -- Check laser collisions with alien
            local destroyed = false
            for j = #lasers, 1, -1 do
                local laser = lasers[j]
                if checkCollision(laser, alien) then
                    -- Handle pierce powerup
                    if laser.pierce and laser.pierceCount < 3 then
                        laser.pierceCount = laser.pierceCount + 1
                    else
                        table.remove(lasers, j)
                    end
                    -- Ensure alien has health property
                    if alien.health then
                        alien.health = alien.health - 1
                    else
                        -- If no health, remove alien immediately
                        destroyed = true
                    end
                    
                    -- Freeze powerup - freeze alien
                    if activePowerups.freeze > 0 and not alien.frozen then
                        alien.frozen = true
                        alien.freezeTime = 2 -- Freeze for 2 seconds
                    end
                    
                    -- Vampire powerup - heal on hit
                    if activePowerups.vampire > 0 and player.health < player.maxHealth then
                        player.health = math.min(player.health + 1, player.maxHealth)
                        createPowerupText("+1 HP", player.x + player.width/2, player.y - 20, {0.8, 0.2, 0.8})
                    end
                    
                    if alien.health and alien.health <= 0 then
                        destroyed = true
                        enemiesDefeated = enemiesDefeated + 1
                        totalAsteroidsDestroyed = totalAsteroidsDestroyed + 1 -- Count aliens too
                        currentCombo = currentCombo + 1
                        if currentCombo > maxCombo then
                            maxCombo = currentCombo
                        end
                        
                        -- Explosion effect
                        createExplosion(
                            alien.x + alien.width/2, 
                            alien.y + alien.height/2,
                            alien.width/2
                        )
                        
                        -- Higher chance to spawn powerup from aliens
                        if math.random(100) <= 60 then
                            spawnPowerup(alien.x + alien.width/2, alien.y + alien.height/2)
                        end
                    else
                        -- Hit but not destroyed
                        createHitEffect(
                            alien.x + alien.width/2,
                            alien.y + alien.height/2
                        )
                    end
                    break
                end
            end
            
            if destroyed then
                table.remove(aliens, i)
            elseif alien.y > baseHeight + 50 then
                -- Remove aliens that go off screen
                table.remove(aliens, i)
            else
                -- Check collision with player
                if checkCollision(player, alien) and invulnerableTime <= 0 then
                    if activePowerups.shield > 0 then
                        -- Shield absorbs hit
                        activePowerups.shield = 0
                        createShieldBreakEffect(
                            player.x + player.width/2,
                            player.y + player.height/2
                        )
                        createExplosion(
                            alien.x + alien.width/2, 
                            alien.y + alien.height/2,
                            alien.width/2
                        )
                        table.remove(aliens, i)
                        -- Medium rumble for shield break
                        if gamepad and gamepad:isGamepad() then
                            gamepad:setVibration(0.6, 0.6, 0.3)
                        end
                    else
                        -- Lose a life
                        loseLife()
                        -- Destroy the alien
                        createExplosion(
                            alien.x + alien.width/2, 
                            alien.y + alien.height/2,
                            alien.width/2
                        )
                        table.remove(aliens, i)
                    end
                end
            end
            ::continueAlien::
        end
        
        -- Update alien lasers
        for i = #alienLasers, 1, -1 do
            local laser = alienLasers[i]
            if not laser then
                goto continue
            end
            
            -- Handle special laser types
            if laser.type == "freezeWave" or laser.type == "psychicWave" then
                -- Expanding freeze wave
                laser.radius = (laser.radius or 10) + (laser.speed or 200) * dt
                if laser.radius > (laser.maxRadius or 300) then
                    table.remove(alienLasers, i)
                    goto continue
                end
                
                -- Check collision with player using radius
                local dx = (player.x + player.width/2) - laser.x
                local dy = (player.y + player.height/2) - laser.y
                local distance = math.sqrt(dx*dx + dy*dy)
                
                if distance < laser.radius and invulnerableTime <= 0 then
                    if activePowerups.shield > 0 then
                        activePowerups.shield = 0
                        createShieldBreakEffect(player.x + player.width/2, player.y + player.height/2)
                    else
                        loseLife()
                    end
                end
                goto continue
            end
            
            -- Normal projectile movement
            if laser.vx and laser.vy then
                laser.x = laser.x + laser.vx * dt
                laser.y = laser.y + laser.vy * dt
            end
            
            -- Check collision with doors in level 4
            local hitDoor = false
            if currentLevel == 4 and laser.vx and laser.vy then -- Only check for normal projectiles
                for _, door in ipairs(doors) do
                    -- Check if laser hits the left part of the door
                    if laser.x >= leftWall and laser.x <= door.gapX and 
                       laser.y >= door.y and laser.y <= door.y + door.height then
                        hitDoor = true
                        break
                    end
                    -- Check if laser hits the right part of the door
                    if laser.x >= door.gapX + door.gapWidth and laser.x <= rightWall and
                       laser.y >= door.y and laser.y <= door.y + door.height then
                        hitDoor = true
                        break
                    end
                end
            end
            
            -- Remove lasers that go off screen or hit doors
            if laser.y > baseHeight or laser.x < -10 or laser.x > baseWidth + 10 or hitDoor then
                table.remove(alienLasers, i)
            else
                -- Check collision with nebula clouds first (only in level 2)
                if currentLevel == 2 then
                    local hitNebula = false
                    for _, asteroid in ipairs(asteroids) do
                        if asteroid.type == "nebulacloud" and checkCollision(laser, asteroid) then
                            -- Nebula clouds block alien lasers
                            table.remove(alienLasers, i)
                            hitNebula = true
                            break
                        end
                    end
                    if hitNebula then
                        goto continue
                    end
                end
                
                -- Check collision with player
                if checkCollision(player, laser) and invulnerableTime <= 0 then
                    if activePowerups.shield > 0 then
                        -- Shield absorbs hit
                        activePowerups.shield = 0
                        createShieldBreakEffect(
                            player.x + player.width/2,
                            player.y + player.height/2
                        )
                        table.remove(alienLasers, i)
                        if gamepad and gamepad:isGamepad() then
                            gamepad:setVibration(0.6, 0.6, 0.3)
                        end
                    else
                        -- Lose a life
                        loseLife()
                        table.remove(alienLasers, i)
                    end
                end
            end
            ::continue::
        end
        
        -- Update boss
        if boss then
            updateBoss(dt)
        end
        
        -- Update boss lasers
        for i = #bossLasers, 1, -1 do
            local laser = bossLasers[i]
            if not laser then
                table.remove(bossLasers, i)
            else
                -- Handle delayed lasers
                if laser.delay and laser.delay > 0 then
                    laser.delay = laser.delay - dt
                    if laser.delay > 0 then
                        goto continueBossLaser
                    end
                end
                
                -- Ensure vx and vy exist
                if not laser.vx then laser.vx = 0 end
                if not laser.vy then laser.vy = 0 end
                
                laser.x = laser.x + laser.vx * dt
                laser.y = laser.y + laser.vy * dt
            
            -- Update homing lasers
            if laser.homing and laser.homingTime > 0 then
                laser.homingTime = laser.homingTime - dt
                local dx = (player.x + player.width/2) - laser.x
                local dy = (player.y + player.height/2) - laser.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist > 0 then
                    -- Calculate desired direction
                    local targetVx = (dx/dist) * 80  -- Target speed of 80
                    local targetVy = (dy/dist) * 80
                    
                    -- Limit turn rate - can only adjust velocity by a small amount each frame
                    local turnRate = 0.02  -- Very limited turning
                    laser.vx = laser.vx * (1 - turnRate) + targetVx * turnRate
                    laser.vy = laser.vy * (1 - turnRate) + targetVy * turnRate
                    
                    -- Limit maximum speed
                    local currentSpeed = math.sqrt(laser.vx*laser.vx + laser.vy*laser.vy)
                    if currentSpeed > 100 then  -- Max speed of 100
                        laser.vx = (laser.vx / currentSpeed) * 100
                        laser.vy = (laser.vy / currentSpeed) * 100
                    end
                    
                    -- Prevent backwards movement (can't turn more than 90 degrees from initial direction)
                    if laser.vy < 10 then  -- Always move at least slightly downward
                        laser.vy = 10
                    end
                end
            end
            
            -- Update spiral lasers
            if laser.spiral then
                laser.spiralAngle = laser.spiralAngle + laser.spiralSpeed * dt
                local radius = 100 + love.timer.getTime() * 50
                laser.vx = math.cos(laser.spiralAngle) * radius
                laser.vy = math.sin(laser.spiralAngle) * radius + 100
            end
            
            -- Update wave lasers
            if laser.wave then
                if not laser.waveTime then laser.waveTime = 0 end
                laser.waveTime = laser.waveTime + dt
                laser.vx = math.sin(laser.waveTime * 3 + laser.waveOffset) * 50
            end
            
            -- Check collision with doors in level 4
            local hitDoor = false
            if currentLevel == 4 then
                for _, door in ipairs(doors) do
                    -- Check if laser hits the left part of the door
                    if laser.x >= leftWall and laser.x <= door.gapX and 
                       laser.y >= door.y and laser.y <= door.y + door.height then
                        hitDoor = true
                        break
                    end
                    -- Check if laser hits the right part of the door
                    if laser.x >= door.gapX + door.gapWidth and laser.x <= rightWall and
                       laser.y >= door.y and laser.y <= door.y + door.height then
                        hitDoor = true
                        break
                    end
                end
            end
            
            -- Remove lasers that go off screen or hit doors
            if laser.y > baseHeight or laser.x < -50 or laser.x > baseWidth + 50 or laser.y < -50 or hitDoor then
                table.remove(bossLasers, i)
            else
                -- Check collision with player
                if checkCollision(player, laser) and invulnerableTime <= 0 then
                    if activePowerups.shield > 0 then
                        -- Shield absorbs hit
                        activePowerups.shield = 0
                        createShieldBreakEffect(
                            player.x + player.width/2,
                            player.y + player.height/2
                        )
                        table.remove(bossLasers, i)
                        if gamepad and gamepad:isGamepad() then
                            gamepad:setVibration(0.6, 0.6, 0.3)
                        end
                    else
                        -- Lose a life
                        loseLife()
                        table.remove(bossLasers, i)
                    end
                end
            end
            ::continueBossLaser::
            end
        end
        
        -- Update explosions
        updateExplosions(dt)
        
        -- Update powerups
        updatePowerups(dt)
        
        -- Update powerup texts
        updatePowerupTexts(dt)
        
        -- Update active powerup timers
        for powerup, time in pairs(activePowerups) do
            if time > 0 then
                -- Don't decrease timer if infinite powerups is on
                if not infinitePowerups then
                    activePowerups[powerup] = time - dt
                end
            end
        end
        
        -- Level-specific updates
        if currentLevel == 3 then
            -- updateIceGeysers(dt) -- Removed ice geysers
            -- Apply gravity to lasers if in tank mode
            if vehicleMode == "tank" then
                for _, laser in ipairs(lasers) do
                    laser.vy = (laser.vy or -500) + gravity * dt
                end
            end
        elseif currentLevel == 4 then
            updateMothershipDoors(dt)
            -- Constrain player to corridor
            player.x = math.max(leftWall, math.min(player.x, rightWall - player.width))
        elseif currentLevel == 5 then
            updateHeatMeter(dt)
            updateSolarFlares(dt)
        end
        
        -- Handle level complete transition
        if levelComplete and levelCompleteTimer > 0 then
            levelCompleteTimer = levelCompleteTimer - dt
            if levelCompleteTimer <= 0 then
                gameState = "levelcomplete"
            end
        end
    elseif gameState == "levelcomplete" then
        -- Level complete state doesn't need updates
    elseif gameState == "gameover" then
        -- Game over state doesn't need updates
    end -- This closes the 'if gameState' block
end  -- This closes love.update()

function love.draw()
    -- Handle scaling
    love.graphics.push()
    if displayMode ~= "windowed" then
        local windowWidth, windowHeight = love.graphics.getDimensions()
        -- For fullscreen, scale to fit while maintaining aspect ratio
        screenScale = math.min(windowWidth / baseWidth, windowHeight / baseHeight)
        screenOffsetX = (windowWidth - baseWidth * screenScale) / 2
        screenOffsetY = (windowHeight - baseHeight * screenScale) / 2
        love.graphics.translate(screenOffsetX, screenOffsetY)
        love.graphics.scale(screenScale, screenScale)
    else
        -- For windowed mode, calculate scale based on current resolution
        local windowWidth = resolutions[currentResolution].width
        local windowHeight = resolutions[currentResolution].height
        
        -- Calculate how to best fit the game in the window
        if windowWidth / windowHeight > baseWidth / baseHeight then
            -- Window is wider than base aspect ratio - scale based on height
            screenScale = windowHeight / baseHeight
            screenOffsetX = (windowWidth - baseWidth * screenScale) / 2
            screenOffsetY = 0
        else
            -- Window is taller than base aspect ratio - scale based on width
            screenScale = windowWidth / baseWidth
            screenOffsetX = 0
            screenOffsetY = (windowHeight - baseHeight * screenScale) / 2
        end
        
        love.graphics.translate(screenOffsetX, screenOffsetY)
        love.graphics.scale(screenScale, screenScale)
    end
    
    -- Draw extended background for ultrawide displays
    local extendedWidth = math.max(baseWidth, love.graphics.getWidth() / screenScale)
    local extendedX = -(extendedWidth - baseWidth) / 2
    
    -- Draw background with level-specific color
    local levelBg = levelBackgrounds[math.min(currentLevel, #levelBackgrounds)] or backgroundColor
    love.graphics.setColor(levelBg)
    love.graphics.rectangle("fill", extendedX, 0, extendedWidth, baseHeight)
    
    -- Draw extended starfield for ultrawide
    drawStarsExtended(extendedX, extendedWidth)
    
    -- Draw side panels only for true ultrawide displays (21:9 or wider)
    local aspectRatio = love.graphics.getWidth() / love.graphics.getHeight()
    if aspectRatio >= 2.33 then -- 21:9 = 2.33, only show panels for ultrawide or wider
        drawSidePanels(extendedX, extendedWidth)
    end
    
    -- Visual effect for slow time (purple tint over background)
    if gameState == "playing" and activePowerups and activePowerups.slowTime and activePowerups.slowTime > 0 then
        love.graphics.setColor(0.8, 0.5, 1, 0.15)
        love.graphics.rectangle("fill", extendedX, 0, extendedWidth, baseHeight)
    end
    
    -- Draw based on game state
    if gameState == "menu" then
        -- Main menu
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(font)
        
        -- Draw menu based on current menu state
        if menuState == "main" then
            -- Title with animated glow (only on main menu)
            local titleGlow = 0.7 + math.sin(love.timer.getTime() * 2) * 0.3
            love.graphics.setColor(titleGlow, titleGlow, 1)
            love.graphics.printf("STELLAR ASSAULT", 0, 120, 800, "center")
            
            -- Subtitle
            if smallFont then love.graphics.setFont(smallFont) end
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("An Endless Space Adventure", 0, 170, 800, "center")
            love.graphics.setFont(font)
            
            drawMainMenu()
        elseif menuState == "saves" then
            drawSaveSlotMenu()
        elseif menuState == "levelselect" then
            drawLevelSelectMenu()
        end
        
        -- Instructions
        love.graphics.setColor(0.5, 0.5, 0.5)
        if smallFont then love.graphics.setFont(smallFont) end
        love.graphics.printf("Arrow Keys/D-Pad: Navigate | Enter/A: Select", 0, 520, 800, "center")
        love.graphics.printf("Dodge asteroids and alien UFOs! Watch out - aliens shoot back!", 0, 540, 800, "center")
        if gamepad and gamepad:isGamepad() then
            love.graphics.setColor(0.3, 0.8, 0.3)
            local controllerName = gamepad:getName()
            if string.len(controllerName) > 30 then
                controllerName = string.sub(controllerName, 1, 27) .. "..."
            end
            love.graphics.printf("Controller: " .. controllerName, 0, 570, 800, "center")
        end
        love.graphics.setFont(font)
        
    elseif gameState == "options" then
        -- Options menu with improved visuals
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("OPTIONS", 0, 50, 800, "center")
        
        local optY = 150
        local optSpacing = 70  -- Reduced spacing to fit more options
        
        -- Resolution option
        if optionsSelection == 1 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> RESOLUTION: " .. resolutions[currentResolution].name .. " <", 0, optY, 800, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("RESOLUTION: " .. resolutions[currentResolution].name, 0, optY, 800, "center")
        end
        
        -- Fullscreen/Display Mode option
        if optionsSelection == 2 then
            love.graphics.setColor(1, 1, 0)
            local modeText = displayMode == "fullscreen" and "FULLSCREEN" or "WINDOWED"
            love.graphics.printf("> DISPLAY MODE: " .. modeText .. " <", 0, optY + optSpacing, 800, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            local modeText = displayMode == "fullscreen" and "FULLSCREEN" or "WINDOWED"
            love.graphics.printf("DISPLAY MODE: " .. modeText, 0, optY + optSpacing, 800, "center")
        end
        
        -- Master Volume with visual slider
        if optionsSelection == 3 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> MASTER VOLUME <", 0, optY + optSpacing * 2, 800, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("MASTER VOLUME", 0, optY + optSpacing * 2, 800, "center")
        end
        
        -- Draw Master volume slider
        local sliderX = 200
        local sliderY = optY + optSpacing * 2 + 40  -- Offset by more than font size (32px)
        local sliderWidth = 250
        
        -- Background bar
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", sliderX, sliderY, sliderWidth, 15)
        
        -- Filled portion
        love.graphics.setColor(1, 1, 0)
        love.graphics.rectangle("fill", sliderX, sliderY, sliderWidth * masterVolume, 15)
        
        -- Slider handle
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", sliderX + sliderWidth * masterVolume, sliderY + 7.5, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("line", sliderX + sliderWidth * masterVolume, sliderY + 7.5, 10)
        
        -- Percentage (on the left side)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(math.floor(masterVolume * 100 + 0.5) .. "%", sliderX - 60, sliderY - 2, 50, "right")
        
        -- SFX Volume with visual slider
        if optionsSelection == 4 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> SFX VOLUME <", 0, optY + optSpacing * 3, 800, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("SFX VOLUME", 0, optY + optSpacing * 3, 800, "center")
        end
        
        -- Draw SFX volume slider
        sliderY = optY + optSpacing * 3 + 40  -- Offset by more than font size
        
        -- Background bar
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", sliderX, sliderY, sliderWidth, 15)
        
        -- Filled portion
        love.graphics.setColor(0, 1, 0.5)
        love.graphics.rectangle("fill", sliderX, sliderY, sliderWidth * sfxVolume, 15)
        
        -- Slider handle
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", sliderX + sliderWidth * sfxVolume, sliderY + 7.5, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("line", sliderX + sliderWidth * sfxVolume, sliderY + 7.5, 10)
        
        -- Percentage (on the left side)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(math.floor(sfxVolume * 100 + 0.5) .. "%", sliderX - 60, sliderY - 2, 50, "right")
        
        -- Music Volume with visual slider
        if optionsSelection == 5 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> MUSIC VOLUME <", 0, optY + optSpacing * 4, 800, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("MUSIC VOLUME", 0, optY + optSpacing * 4, 800, "center")
        end
        
        -- Draw Music volume slider
        sliderY = optY + optSpacing * 4 + 40  -- Offset by more than font size
        
        -- Background bar
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", sliderX, sliderY, sliderWidth, 15)
        
        -- Filled portion
        love.graphics.setColor(0.8, 0.5, 1)
        love.graphics.rectangle("fill", sliderX, sliderY, sliderWidth * musicVolume, 15)
        
        -- Slider handle
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", sliderX + sliderWidth * musicVolume, sliderY + 7.5, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("line", sliderX + sliderWidth * musicVolume, sliderY + 7.5, 10)
        
        -- Percentage (on the left side)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(math.floor(musicVolume * 100 + 0.5) .. "%", sliderX - 60, sliderY - 2, 50, "right")
        
        -- Back option
        if optionsSelection == 6 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> BACK TO MENU <", 0, optY + optSpacing * 5, 800, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("BACK TO MENU", 0, optY + optSpacing * 5, 800, "center")
        end
        
        -- Instructions
        love.graphics.setColor(0.5, 0.5, 0.5)
        if smallFont then love.graphics.setFont(smallFont) end
        love.graphics.printf("Up/Down/D-Pad: Navigate | Left/Right/D-Pad: Adjust | Enter/A: Select | ESC/B: Back", 0, 540, 800, "center")
        love.graphics.printf("F11/Y: Quick Display Mode Toggle | F9: Refresh Audio", 0, 560, 800, "center")
        if gamepad and gamepad:isGamepad() then
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.printf("Controller vibration enabled", 0, 580, 800, "center")
        end
        if font then love.graphics.setFont(font) end
        
    elseif gameState == "playing" then
        drawGame()
    elseif gameState == "levelcomplete" then
        drawLevelComplete()
    elseif gameState == "paused" then
        drawPaused()
    elseif gameState == "gameover" then
        drawGameOver()
    end
    
    -- Draw controller indicator (consistent across all game states)
    if gamepad and gamepad:isGamepad() then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.circle("fill", 770, 20, 5)
        love.graphics.setColor(0.5, 0.5, 0.5)
        if smallFont then 
            love.graphics.setFont(smallFont)
            love.graphics.print("Gamepad", 710, 30)
            love.graphics.setFont(font)
        end
    end
    
    -- Always pop at the end
    love.graphics.pop()
end

function drawGame()
    -- Health indicator (show lives left for dramatic effect)
    if lives == 1 then
        love.graphics.setColor(1, 0.2, 0.2, 0.3 + math.sin(love.timer.getTime() * 4) * 0.3)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
    end
    
    -- Level-specific atmosphere effects
    if currentLevel == 2 then
        -- Purple nebula glow
        love.graphics.setColor(0.5, 0.2, 0.8, 0.1)
        love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    elseif currentLevel == 3 then
        -- Ice moon surface - draw ground
        drawIceMoonTerrain()
    elseif currentLevel == 4 then
        -- Mothership interior walls
        drawMothershipInterior()
    elseif currentLevel == 5 then
        -- Solar corona effects
        drawSolarEffects()
    end
    
    -- Draw forward boundary line
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, 200, baseWidth, 200)
    love.graphics.setLineWidth(1)
    
    -- Draw powerups
    drawPowerups()
        
        -- Draw lasers
        for _, laser in ipairs(lasers) do
            -- Different visual effects based on powerups
            if laser.homing then
                -- Homing lasers - Red with trail
                love.graphics.setColor(1, 0.3, 0.3, 0.3)
                love.graphics.rectangle("fill", laser.x - 4, laser.y, laser.width + 8, laser.height + 10)
                love.graphics.setColor(1, 0.3, 0.3)
                love.graphics.rectangle("fill", laser.x, laser.y, laser.width, laser.height)
            elseif laser.pierce then
                -- Piercing lasers - Green with core
                love.graphics.setColor(0.5, 1, 0.5, 0.5)
                love.graphics.rectangle("fill", laser.x - 3, laser.y, laser.width + 6, laser.height)
                love.graphics.setColor(0.8, 1, 0.8)
                love.graphics.rectangle("fill", laser.x, laser.y, laser.width, laser.height)
                love.graphics.setColor(1, 1, 1)
                love.graphics.rectangle("fill", laser.x + 1, laser.y + 2, laser.width - 2, laser.height - 4)
            elseif activePowerups.rapidFire > 0 then
                love.graphics.setColor(1, 1, 0, 0.5) -- Yellow glow
                love.graphics.rectangle("fill", laser.x - 2, laser.y, laser.width + 4, laser.height)
                love.graphics.setColor(1, 1, 0) -- Yellow laser
                love.graphics.rectangle("fill", laser.x, laser.y, laser.width, laser.height)
            else
                -- Normal green laser
                love.graphics.setColor(laserColor[1], laserColor[2], laserColor[3], 0.5)
                love.graphics.rectangle("fill", laser.x - 2, laser.y, laser.width + 4, laser.height)
                love.graphics.setColor(laserColor)
                love.graphics.rectangle("fill", laser.x, laser.y, laser.width, laser.height)
            end
        end
        
        -- Draw alien lasers
        for _, laser in ipairs(alienLasers) do
            if laser.type == "freezeWave" then
                -- Draw expanding freeze wave
                local alpha = 0.5 * (1 - (laser.radius / laser.maxRadius))
                love.graphics.setColor(0.5, 0.8, 1, alpha)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", laser.x, laser.y, laser.radius)
                love.graphics.setColor(0.3, 0.6, 1, alpha * 0.5)
                love.graphics.circle("line", laser.x, laser.y, laser.radius - 5)
                love.graphics.setLineWidth(1)
            elseif laser.type == "psychicWave" then
                -- Draw expanding psychic wave
                local alpha = 0.6 * (1 - (laser.radius / laser.maxRadius))
                love.graphics.setColor(0.8, 0.4, 0.8, alpha)
                love.graphics.setLineWidth(4)
                love.graphics.circle("line", laser.x, laser.y, laser.radius)
                love.graphics.setColor(1, 0.6, 1, alpha * 0.7)
                love.graphics.circle("line", laser.x, laser.y, laser.radius - 8)
                love.graphics.setLineWidth(1)
            else
                -- Normal alien lasers
                love.graphics.setColor(1, 0.2, 0.2, 0.5) -- Red glow
                love.graphics.rectangle("fill", laser.x - 2, laser.y, laser.width + 4, laser.height)
                love.graphics.setColor(1, 0, 0) -- Red laser
                love.graphics.rectangle("fill", laser.x, laser.y, laser.width, laser.height)
            end
        end
        
        -- Draw boss lasers
        for _, laser in ipairs(bossLasers) do
            -- Skip delayed lasers
            if laser.delay and laser.delay > 0 then
                goto skipBossLaserDraw
            end
            
            if laser.color then
                -- Custom colored lasers (for annihilator)
                local r, g, b = laser.color[1], laser.color[2], laser.color[3]
                love.graphics.setColor(r, g, b, 0.5) -- Glow
                love.graphics.rectangle("fill", laser.x - 3, laser.y - 3, laser.width + 6, laser.height + 6)
                love.graphics.setColor(r * 0.8, g * 0.8, b * 0.8) -- Main laser
                love.graphics.rectangle("fill", laser.x, laser.y, laser.width, laser.height)
            elseif laser.homing then
                -- Purple homing lasers
                love.graphics.setColor(1, 0, 1, 0.5) -- Purple glow
                love.graphics.rectangle("fill", laser.x - 3, laser.y - 3, laser.width + 6, laser.height + 6)
                love.graphics.setColor(0.8, 0, 0.8) -- Purple
                love.graphics.rectangle("fill", laser.x, laser.y, laser.width, laser.height)
            elseif laser.spiral then
                -- Spiral lasers - pink/purple
                love.graphics.setColor(1, 0.5, 1, 0.5) -- Pink glow
                love.graphics.circle("fill", laser.x, laser.y, laser.width/2 + 3)
                love.graphics.setColor(1, 0.3, 0.8) -- Pink
                love.graphics.circle("fill", laser.x, laser.y, laser.width/2)
            elseif laser.wave then
                -- Wave lasers - cyan
                love.graphics.setColor(0, 1, 1, 0.5) -- Cyan glow
                love.graphics.rectangle("fill", laser.x - 2, laser.y - 2, laser.width + 4, laser.height + 4)
                love.graphics.setColor(0, 0.8, 1) -- Cyan
                love.graphics.rectangle("fill", laser.x, laser.y, laser.width, laser.height)
            else
                -- Orange spread lasers
                love.graphics.setColor(1, 0.5, 0, 0.5) -- Orange glow
                love.graphics.rectangle("fill", laser.x - 2, laser.y - 2, laser.width + 4, laser.height + 4)
                love.graphics.setColor(1, 0.4, 0) -- Orange
                love.graphics.rectangle("fill", laser.x, laser.y, laser.width, laser.height)
            end
            ::skipBossLaserDraw::
        end
        
        -- Draw explosions
        drawExplosions()
        
        -- Draw powerup texts (after explosions but before UI)
        drawPowerupTexts()
        
        -- Draw player (spaceship)
        -- Blink when invulnerable
        local shouldDrawPlayer = true
        if invulnerableTime > 0 then
            -- Blink faster as invulnerability wears off
            local blinkSpeed = invulnerableTime < 0.5 and 20 or 10
            shouldDrawPlayer = math.floor(love.timer.getTime() * blinkSpeed) % 2 == 0
        end
        
        if shouldDrawPlayer then
            love.graphics.push()
            love.graphics.translate(player.x + player.width/2, player.y + player.height/2)
            
            -- Player glow effect for offensive powerups
            if activePowerups.tripleShot > 0 or activePowerups.rapidFire > 0 then
                local glowColor = activePowerups.rapidFire > 0 and {1, 1, 0, 0.3} or {1, 0.5, 0, 0.3}
                love.graphics.setColor(glowColor)
                love.graphics.circle("fill", 0, 0, 30)
            end
            
            -- Shield effect (more visible)
            if activePowerups.shield > 0 then
                -- Flash faster when about to expire
                local flashSpeed = 4
                if activePowerups.shield < 2 then
                    flashSpeed = 10 -- Fast flashing in last 2 seconds
                end
                
                -- Outer glow
                love.graphics.setColor(0, 0.8, 1, 0.2)
                love.graphics.circle("fill", 0, 0, 40)
                
                -- Main shield bubble
                local pulse = math.sin(love.timer.getTime() * flashSpeed) * 0.15
                love.graphics.setColor(0, 1, 1, 0.4 + pulse)
                love.graphics.circle("fill", 0, 0, 35)
                
                -- Shield outline (brighter)
                love.graphics.setColor(0, 1, 1, 0.8)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", 0, 0, 35)
                
                -- Energy sparkles
                for i = 1, 6 do
                    local angle = (i / 6) * math.pi * 2 + love.timer.getTime() * 2
                    local sparkX = math.cos(angle) * 35
                    local sparkY = math.sin(angle) * 35
                    love.graphics.setColor(1, 1, 1, 0.6)
                    love.graphics.circle("fill", sparkX, sparkY, 2)
                end
                love.graphics.setLineWidth(1)
            end
            
            -- Ship scale
            local scale = 0.8
            
            -- Draw different vehicles based on level/mode
            if vehicleMode == "fighter" or not vehicleMode then
                -- Level 1: Standard space fighter
                love.graphics.setColor(0.2, 0.4, 0.7)
                love.graphics.polygon("fill",
                    0 * scale, -30 * scale,      -- nose
                    -12 * scale, -10 * scale,    -- left front
                    -12 * scale, 10 * scale,     -- left mid
                    -8 * scale, 25 * scale,      -- left back
                    8 * scale, 25 * scale,       -- right back
                    12 * scale, 10 * scale,      -- right mid
                    12 * scale, -10 * scale,     -- right front
                    0 * scale, -30 * scale       -- nose
                )
                
                -- Wings
                love.graphics.setColor(0.3, 0.6, 0.8)
                love.graphics.polygon("fill",
                    -12 * scale, -5 * scale,
                    -25 * scale, 5 * scale,
                    -25 * scale, 20 * scale,
                    -12 * scale, 15 * scale
                )
                love.graphics.polygon("fill",
                    12 * scale, -5 * scale,
                    25 * scale, 5 * scale,
                    25 * scale, 20 * scale,
                    12 * scale, 15 * scale
                )
                
                -- Cockpit
                love.graphics.setColor(0.5, 0.8, 1)
                love.graphics.polygon("fill",
                    0 * scale, -25 * scale,
                    -5 * scale, -15 * scale,
                    -5 * scale, -5 * scale,
                    0 * scale, -8 * scale,
                    5 * scale, -5 * scale,
                    5 * scale, -15 * scale
                )
                
            elseif vehicleMode == "energyship" then
                -- Level 2: Energy ship (sleek and ethereal)
                local pulse = math.sin(love.timer.getTime() * 3) * 0.1 + 0.9
                love.graphics.setColor(0.6, 0.4, 0.8) -- Purple energy
                
                -- Main hull (diamond shape)
                love.graphics.polygon("fill",
                    0, -player.height/2,
                    -player.width/2, 0,
                    0, player.height/2,
                    player.width/2, 0
                )
                
                -- Energy wings
                love.graphics.setColor(0.8, 0.6, 1, 0.7 * pulse)
                love.graphics.polygon("fill",
                    -player.width/2, 0,
                    -player.width, -5,
                    -player.width, 5
                )
                love.graphics.polygon("fill",
                    player.width/2, 0,
                    player.width, -5,
                    player.width, 5
                )
                
                -- Core
                love.graphics.setColor(1, 0.8, 1)
                love.graphics.circle("fill", 0, 0, 5)
                
            elseif vehicleMode == "tank" then
                -- Level 3: Ground tank
                love.graphics.setColor(0.4, 0.4, 0.5) -- Dark metal
                love.graphics.rectangle("fill", -player.width/2, -player.height/3, player.width, player.height * 0.6)
                
                -- Turret
                love.graphics.setColor(0.3, 0.3, 0.4)
                love.graphics.rectangle("fill", -8, -player.height/2, 16, 20)
                
                -- Barrel
                love.graphics.setColor(0.2, 0.2, 0.3)
                love.graphics.rectangle("fill", -3, -player.height/2 - 10, 6, 15)
                
                -- Treads
                love.graphics.setColor(0.2, 0.2, 0.2)
                love.graphics.rectangle("fill", -player.width/2 - 4, -player.height/3 + 5, player.width + 8, 8)
                love.graphics.rectangle("fill", -player.width/2 - 4, player.height/3 - 13, player.width + 8, 8)
                
            elseif vehicleMode == "morphship" then
                -- Level 4: Organic morphing ship
                local morph = math.sin(love.timer.getTime() * 2) * 0.2
                love.graphics.setColor(0.4, 0.7, 0.4) -- Organic green
                
                -- Main body (organic shape)
                love.graphics.ellipse("fill", 0, 0, player.width/2 + morph * 5, player.height/2)
                
                -- Tentacle-like appendages
                for i = 1, 4 do
                    local angle = (i / 4) * math.pi * 2 + love.timer.getTime()
                    local x2 = math.cos(angle) * (player.width/2 + 10)
                    local y2 = math.sin(angle) * (player.height/2 + 10)
                    love.graphics.setColor(0.3, 0.6, 0.3, 0.8)
                    love.graphics.line(0, 0, x2, y2)
                    love.graphics.circle("fill", x2, y2, 3)
                end
                
                -- Eye/cockpit
                love.graphics.setColor(0.8, 1, 0.8)
                love.graphics.ellipse("fill", 0, -5, 8, 12)
                
            elseif vehicleMode == "solarship" then
                -- Level 5: Heat-resistant solar ship
                love.graphics.setColor(0.9, 0.6, 0.2) -- Orange heat-resistant
                
                -- Angular heat-deflecting hull
                love.graphics.polygon("fill",
                    0, -player.height/2,
                    -player.width/3, -player.height/4,
                    -player.width/2, 0,
                    -player.width/3, player.height/3,
                    0, player.height/2,
                    player.width/3, player.height/3,
                    player.width/2, 0,
                    player.width/3, -player.height/4
                )
                
                -- Heat shields
                love.graphics.setColor(1, 0.8, 0.4, 0.6)
                love.graphics.circle("line", 0, 0, player.width/1.5)
                love.graphics.circle("line", 0, 0, player.width/1.3)
                
                -- Cooling vents
                love.graphics.setColor(0, 0.8, 1)
                love.graphics.rectangle("fill", -15, -5, 5, 10)
                love.graphics.rectangle("fill", 10, -5, 5, 10)
            end
            
            -- Engine details (change color based on powerups)
            if activePowerups.rapidFire > 0 then
                love.graphics.setColor(1, 1, 0) -- Yellow engines for rapid fire
            elseif activePowerups.tripleShot > 0 then
                love.graphics.setColor(1, 0.5, 0) -- Orange engines for triple shot
            else
                love.graphics.setColor(1, 0.6, 0.2) -- Normal orange
            end
            
            -- Main engine
            love.graphics.rectangle("fill", -3 * scale, 20 * scale, 6 * scale, 8 * scale)
            -- Wing engines
            love.graphics.circle("fill", -20 * scale, 22 * scale, 3 * scale)
            love.graphics.circle("fill", 20 * scale, 22 * scale, 3 * scale)
            
            -- Engine flame effect when powered up
            if activePowerups.rapidFire > 0 or activePowerups.tripleShot > 0 then
                -- Bigger flames when powered up
                love.graphics.setColor(1, 0.8, 0, 0.8)
                love.graphics.circle("fill", -3 * scale, 28 * scale, 5 * scale)
                love.graphics.circle("fill", 3 * scale, 28 * scale, 5 * scale)
                love.graphics.circle("fill", -20 * scale, 26 * scale, 4 * scale)
                love.graphics.circle("fill", 20 * scale, 26 * scale, 4 * scale)
            end
            
            -- Center detail line (dark blue)
            love.graphics.setColor(0.1, 0.3, 0.5)
            love.graphics.rectangle("fill", -1 * scale, -25 * scale, 2 * scale, 45 * scale)
            
            -- Outline (black)
            love.graphics.setColor(0, 0, 0)
            love.graphics.setLineWidth(2)
            -- Main body outline
            love.graphics.polygon("line",
                0 * scale, -30 * scale,
                -12 * scale, -10 * scale,
                -12 * scale, 10 * scale,
                -8 * scale, 25 * scale,
                8 * scale, 25 * scale,
                12 * scale, 10 * scale,
                12 * scale, -10 * scale
            )
            -- Wing outlines
            love.graphics.polygon("line",
                -12 * scale, -5 * scale,
                -25 * scale, 5 * scale,
                -25 * scale, 20 * scale,
                -12 * scale, 15 * scale
            )
            love.graphics.polygon("line",
                12 * scale, -5 * scale,
                25 * scale, 5 * scale,
                25 * scale, 20 * scale,
                12 * scale, 15 * scale
            )
            love.graphics.setLineWidth(1)
            
            love.graphics.pop()
            
            -- Draw hitbox if enabled
            if showHitboxes then
                love.graphics.setColor(0, 1, 0, 0.5)
                love.graphics.rectangle("line", player.x, player.y, player.width, player.height)
            end
        end
        
        -- Draw boss
        if boss then
            drawBoss()
        end
        
        -- Draw boss warning
        if bossWarningTime > 0 then
            love.graphics.setColor(1, 0, 0, 0.5 + math.sin(love.timer.getTime() * 10) * 0.5)
            love.graphics.setFont(font)
            love.graphics.printf("WARNING: BOSS APPROACHING!", 0, 200, baseWidth, "center")
            love.graphics.setFont(smallFont)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("Prepare for battle!", 0, 240, baseWidth, "center")
        end
        
        -- Draw asteroids
        for _, asteroid in ipairs(asteroids) do
            love.graphics.push()
            love.graphics.translate(asteroid.x + asteroid.width/2, asteroid.y + asteroid.height/2)
            
            -- Add rotation for visual interest
            if asteroid.rotation then
                love.graphics.rotate(asteroid.rotation)
            end
            
            -- Draw frozen effect
            if asteroid.frozen then
                love.graphics.setColor(0.5, 0.8, 1, 0.5) -- Ice blue overlay
                love.graphics.circle("fill", 0, 0, math.max(asteroid.width, asteroid.height) * 0.6)
            end
            
            -- Draw different types of objects in the asteroids array
            if asteroid.type == "nebulacloud" then
                -- Draw nebula cloud
                love.graphics.setColor(0.8, 0.5, 1, asteroid.opacity or 0.3)
                love.graphics.ellipse("fill", 0, 0, asteroid.width/2, asteroid.height/2)
                -- Inner glow
                love.graphics.setColor(1, 0.8, 1, (asteroid.opacity or 0.3) * 0.5)
                love.graphics.ellipse("fill", 0, 0, asteroid.width/3, asteroid.height/3)
            elseif asteroid.type == "iceshard" then
                -- Draw ice shard
                love.graphics.setColor(0.7, 0.9, 1, 0.9)
                love.graphics.polygon("fill",
                    0, -asteroid.height/2,
                    -asteroid.width/3, 0,
                    0, asteroid.height/2,
                    asteroid.width/3, 0
                )
                -- Shine effect
                love.graphics.setColor(1, 1, 1, 0.5)
                love.graphics.polygon("fill",
                    0, -asteroid.height/3,
                    -asteroid.width/4, -asteroid.height/4,
                    0, 0
                )
            else
                -- Regular asteroids
                if asteroid.type == "metal" then
                    love.graphics.setColor(0.6, 0.6, 0.7)
                elseif asteroid.type == "large" then
                    love.graphics.setColor(0.4, 0.3, 0.3)
                else
                    love.graphics.setColor(0.5, 0.4, 0.3)
                end
                love.graphics.circle("fill", 0, 0, asteroid.width/2)
            end
            
            -- Draw cracks/details on asteroids
            if asteroid.type == "large" or asteroid.type == "metal" then
                love.graphics.setColor(0, 0, 0, 0.3)
                love.graphics.setLineWidth(2)
                -- Draw some cracks
                for i = 1, 3 do
                    local angle = (i / 3) * math.pi * 2
                    local x1 = math.cos(angle) * asteroid.width/4
                    local y1 = math.sin(angle) * asteroid.width/4
                    local x2 = math.cos(angle + 0.3) * asteroid.width/2
                    local y2 = math.sin(angle + 0.3) * asteroid.width/2
                    love.graphics.line(x1, y1, x2, y2)
                end
                love.graphics.setLineWidth(1)
            end
            
            -- Draw damage indicator for damaged asteroids
            if asteroid.health then
                local maxHealth = asteroid.maxHealth or asteroid.health
                if asteroid.health < maxHealth and asteroid.health > 0 then
                love.graphics.setColor(1, 1, 1, 0.5)
                love.graphics.circle("line", 0, 0, asteroid.width/2 - 2)
                
                -- Show cracks when damaged
                love.graphics.setColor(1, 0.5, 0, 0.7)
                love.graphics.setLineWidth(2)
                local crackCount = maxHealth - asteroid.health
                for i = 1, crackCount do
                    local angle = (i / crackCount) * math.pi * 2 + asteroid.rotation
                    local x1 = math.cos(angle) * asteroid.width/6
                    local y1 = math.sin(angle) * asteroid.width/6
                    local x2 = math.cos(angle) * asteroid.width/2.5
                    local y2 = math.sin(angle) * asteroid.width/2.5
                    love.graphics.line(x1, y1, x2, y2)
                end
                love.graphics.setLineWidth(1)
                end
            end
            
            -- Special effect for metal asteroids
            if asteroid.type == "metal" then
                love.graphics.setColor(0.9, 0.9, 1, 0.3)
                love.graphics.circle("line", 0, 0, asteroid.width/2 + 2)
            end
            
            -- Fragment trail effect
            if asteroid.type == "fragment" and asteroid.vy and asteroid.vy < 100 then
                love.graphics.setColor(0.5, 0.4, 0.3, 0.3)  -- Use default asteroid color with transparency
                love.graphics.circle("fill", -asteroid.vx * 0.05, -asteroid.vy * 0.05, asteroid.width/3)
            end
            
            love.graphics.pop()
            
            -- Draw hitbox if enabled
            if showHitboxes then
                love.graphics.setColor(1, 0, 0, 0.5)
                love.graphics.rectangle("line", asteroid.x, asteroid.y, asteroid.width, asteroid.height)
            end
        end
        
        -- Draw aliens
        for _, alien in ipairs(aliens) do
            love.graphics.push()
            love.graphics.translate(alien.x + alien.width/2, alien.y + alien.height/2)
            
            -- Draw frozen effect
            if alien.frozen then
                love.graphics.setColor(0.5, 0.8, 1, 0.5) -- Ice blue overlay
                love.graphics.circle("fill", 0, 0, math.max(alien.width, alien.height) * 0.6)
            end
            
            -- Draw different alien types
            if alien.type == "basic" or alien.type == "scout" or alien.type == "heavy" then
                -- Classic UFO for level 1
                love.graphics.setColor(0.5, 0.5, 0.6) -- Gray metallic
                love.graphics.ellipse("fill", 0, 2, alien.width/2, alien.height/3)
                
                -- UFO dome
                love.graphics.setColor(0.3, 0.8, 0.3, 0.8) -- Green glass dome
                love.graphics.arc("fill", 0, -2, alien.width/3, -math.pi, 0)
                
                -- Rim lights
                love.graphics.setColor(1, 0, 0) -- Red lights
                local lightCount = 6
                for i = 1, lightCount do
                    local angle = (i / lightCount) * math.pi * 2 + love.timer.getTime() * 2
                    local lightX = math.cos(angle) * (alien.width/2 - 3)
                    local lightY = math.sin(angle) * (alien.height/4) + 2
                    love.graphics.circle("fill", lightX, lightY, 2)
                end
                
            elseif alien.type == "nebulawraith" then
                -- Ethereal ghostly enemy
                local alpha = 0.6 + math.sin(love.timer.getTime() * 3 + alien.phaseShift) * 0.3
                love.graphics.setColor(0.8, 0.5, 1, alpha) -- Purple ethereal
                love.graphics.circle("fill", 0, 0, alien.width/2)
                
                -- Inner core
                love.graphics.setColor(1, 0.8, 1, alpha * 1.5)
                love.graphics.circle("fill", 0, 0, alien.width/4)
                
                -- Wispy tendrils
                for i = 1, 5 do
                    local angle = (i / 5) * math.pi * 2 + love.timer.getTime()
                    local x2 = math.cos(angle) * alien.width
                    local y2 = math.sin(angle) * alien.width/2
                    love.graphics.setColor(0.8, 0.5, 1, alpha * 0.5)
                    love.graphics.line(0, 0, x2, y2)
                end
                
            elseif alien.type == "energymine" then
                -- Pulsing energy mine
                local pulse = 1 + math.sin(love.timer.getTime() * 5) * 0.3
                love.graphics.setColor(1, 1, 0) -- Yellow energy
                love.graphics.circle("fill", 0, 0, alien.width/2 * pulse)
                
                -- Warning rings
                love.graphics.setColor(1, 0.5, 0, 0.5)
                love.graphics.circle("line", 0, 0, alien.explodeRadius/3)
                love.graphics.circle("line", 0, 0, alien.explodeRadius/2)
                
            elseif alien.type == "turret" then
                -- Ice turret
                love.graphics.setColor(0.7, 0.8, 0.9) -- Ice blue
                love.graphics.rectangle("fill", -alien.width/2, -alien.height/2, alien.width, alien.height)
                
                -- Barrel
                love.graphics.setColor(0.5, 0.6, 0.7)
                love.graphics.rectangle("fill", -5, -alien.height/2 - 10, 10, 15)
                
            elseif alien.type == "hovertank" then
                -- Hovering tank
                love.graphics.setColor(0.4, 0.5, 0.6) -- Dark metal
                love.graphics.rectangle("fill", -alien.width/2, -alien.height/2, alien.width, alien.height * 0.7)
                
                -- Hover jets
                love.graphics.setColor(0, 0.8, 1, 0.7)
                love.graphics.ellipse("fill", -alien.width/3, alien.height/3, 10, 5)
                love.graphics.ellipse("fill", alien.width/3, alien.height/3, 10, 5)
                
            elseif alien.type == "cryodrone" then
                -- Flying ice drone
                love.graphics.setColor(0.6, 0.8, 1) -- Ice blue
                love.graphics.circle("fill", 0, 0, alien.width/2)
                
                -- Ice crystals
                for i = 1, 6 do
                    local angle = (i / 6) * math.pi * 2
                    local x = math.cos(angle) * alien.width/2.5
                    local y = math.sin(angle) * alien.width/2.5
                    love.graphics.setColor(0.8, 0.9, 1)
                    love.graphics.polygon("fill", x-3, y, x, y-6, x+3, y, x, y+6)
                end
                
            elseif alien.type == "organicpod" then
                -- Organic alien pod
                love.graphics.setColor(0.6, 0.8, 0.6) -- Organic green
                love.graphics.ellipse("fill", 0, 0, alien.width/2, alien.height/2)
                
                -- Pulsing veins
                love.graphics.setColor(0.8, 0.4, 0.4, 0.7)
                for i = 1, 4 do
                    local angle = (i / 4) * math.pi * 2
                    local x2 = math.cos(angle) * alien.width/2.5
                    local y2 = math.sin(angle) * alien.height/2.5
                    love.graphics.line(0, 0, x2, y2)
                end
                
            elseif alien.type == "securitydrone" then
                -- Mechanical security drone
                love.graphics.setColor(0.8, 0.2, 0.2) -- Red security
                love.graphics.rectangle("fill", -alien.width/2, -alien.height/2, alien.width, alien.height)
                
                -- Scanner light
                local scan = math.sin(love.timer.getTime() * 4) * 0.5 + 0.5
                love.graphics.setColor(1, 0, 0, scan)
                love.graphics.circle("fill", 0, 0, 8)
                
            elseif alien.type == "repairbot" then
                -- Repair bot
                love.graphics.setColor(0.2, 0.8, 0.2) -- Green healer
                love.graphics.circle("fill", 0, 0, alien.width/2)
                
                -- Cross symbol
                love.graphics.setColor(1, 1, 1)
                love.graphics.rectangle("fill", -2, -10, 4, 20)
                love.graphics.rectangle("fill", -10, -2, 20, 4)
                
            elseif alien.type == "tentacle" then
                -- Wall tentacle
                love.graphics.setColor(0.6, 0.3, 0.6) -- Purple organic
                -- Draw segmented tentacle
                for i = 1, 5 do
                    local segY = -alien.height/2 + (i-1) * alien.height/5
                    local wiggle = math.sin(love.timer.getTime() * 3 + i) * 5
                    love.graphics.circle("fill", wiggle, segY, alien.width/2 * (1 - i/10))
                end
                
            elseif alien.type == "plasmaorb" then
                -- Plasma orb
                local glow = 0.7 + math.sin(love.timer.getTime() * 4) * 0.3
                love.graphics.setColor(1, 0.5, 0, glow) -- Orange plasma
                love.graphics.circle("fill", 0, 0, alien.width/2)
                
                -- Inner core
                love.graphics.setColor(1, 1, 0.5)
                love.graphics.circle("fill", 0, 0, alien.width/3)
                
            elseif alien.type == "solarfighter" then
                -- Solar fighter
                love.graphics.setColor(1, 0.7, 0.2) -- Solar orange
                love.graphics.polygon("fill",
                    0, -alien.height/2,
                    -alien.width/2, alien.height/2,
                    0, alien.height/3,
                    alien.width/2, alien.height/2
                )
                
                -- Heat shimmer
                love.graphics.setColor(1, 0.9, 0.5, 0.5)
                love.graphics.circle("line", 0, 0, alien.width/1.5)
                
            elseif alien.type == "fireelemental" then
                -- Fire elemental
                local flicker = 0.8 + math.sin(love.timer.getTime() * 10) * 0.2
                love.graphics.setColor(1, 0.3 * flicker, 0) -- Fire red
                love.graphics.circle("fill", 0, 0, alien.width/2)
                
                -- Flames
                for i = 1, 8 do
                    local angle = (i / 8) * math.pi * 2 + love.timer.getTime() * 2
                    local flameX = math.cos(angle) * alien.width/2
                    local flameY = math.sin(angle) * alien.width/2
                    love.graphics.setColor(1, 0.6, 0, flicker)
                    love.graphics.polygon("fill",
                        flameX, flameY,
                        flameX - 5, flameY - 10,
                        flameX + 5, flameY - 10
                    )
                end
            end
            
            -- Health indicator for damaged aliens
            if alien.maxHealth and alien.health < alien.maxHealth and alien.health > 0 then
                love.graphics.setColor(1, 0, 0, 0.8)
                love.graphics.rectangle("fill", -15, -alien.height/2 - 10, 30 * (alien.health / alien.maxHealth), 3)
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.rectangle("line", -15, -alien.height/2 - 10, 30, 3)
            end
            
            love.graphics.pop()
            
            -- Draw hitbox if enabled
            if showHitboxes then
                love.graphics.setColor(1, 1, 0, 0.5)
                love.graphics.rectangle("line", alien.x, alien.y, alien.width, alien.height)
            end
        end
        
    -- Draw score and instructions
    love.graphics.setColor(1, 1, 1)
    if smallFont then love.graphics.setFont(smallFont) end
    
    -- Draw zone/level
    love.graphics.setColor(0.7, 0.7, 1)
    love.graphics.print("Zone " .. currentLevel, 10, 10)
    
    -- Draw lives
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.print("Lives:", 10, 30)
    -- Draw life indicators as small ships
    for i = 1, lives do
        local lifeX = 60 + (i - 1) * 30
        local lifeY = 38
        love.graphics.push()
        love.graphics.translate(lifeX, lifeY)
        love.graphics.scale(0.35, 0.35) -- Small ships
        
        -- Main body (dark blue)
        love.graphics.setColor(0.2, 0.4, 0.7)
        love.graphics.polygon("fill",
            0, -15,      -- nose
            -6, -5,      -- left front
            -6, 5,       -- left mid
            -4, 12,      -- left back
            4, 12,       -- right back
            6, 5,        -- right mid
            6, -5,       -- right front
            0, -15       -- nose
        )
        
        -- Wings (medium blue)
        love.graphics.setColor(0.3, 0.6, 0.8)
        -- Left wing
        love.graphics.polygon("fill",
            -6, -2,
            -12, 2,
            -12, 10,
            -6, 7
        )
        -- Right wing
        love.graphics.polygon("fill",
            6, -2,
            12, 2,
            12, 10,
            6, 7
        )
        
        -- Cockpit (light blue)
        love.graphics.setColor(0.5, 0.8, 1)
        love.graphics.polygon("fill",
            0, -12,
            -3, -7,
            -3, -2,
            0, -4,
            3, -2,
            3, -7
        )
        
        -- Engine (orange)
        love.graphics.setColor(1, 0.6, 0.2)
        love.graphics.rectangle("fill", -2, 10, 4, 4)
        
        love.graphics.pop()
    end
    
    -- Draw boss progress
    if not boss and not levelComplete then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Boss Progress:", 10, 60)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(enemiesDefeated .. "/" .. enemiesForBoss, 120, 60)
        
        -- Progress bar
        local progressBarX = 10
        local progressBarY = 80
        local progressBarWidth = 150
        local progressBarHeight = 8
        local progress = enemiesDefeated / enemiesForBoss
        
        -- Background
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", progressBarX, progressBarY, progressBarWidth, progressBarHeight)
        
        -- Fill
        love.graphics.setColor(1, 1 - progress, 0)
        love.graphics.rectangle("fill", progressBarX, progressBarY, progressBarWidth * progress, progressBarHeight)
        
        -- Border
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle("line", progressBarX, progressBarY, progressBarWidth, progressBarHeight)
    end
    
        
    -- Draw enemy legend (compact)
    if smallFont then love.graphics.setFont(smallFont) end
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("Enemies:", 680, 105)
    
    -- Asteroids column
    love.graphics.setColor(0.8, 0.5, 0.3)
    love.graphics.circle("fill", 690, 125, 4)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("15", 700, 118)
    
    love.graphics.setColor(0.9, 0.7, 0.4)
    love.graphics.circle("fill", 690, 140, 3)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("30", 700, 133)
    
    love.graphics.setColor(0.6, 0.3, 0.2)
    love.graphics.circle("fill", 690, 155, 5)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("45", 700, 148)
    
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.circle("fill", 690, 170, 4)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("40", 700, 163)
    
    -- UFOs column
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.ellipse("fill", 735, 125, 6, 2)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("60", 745, 118)
    
    love.graphics.setColor(0.4, 0.6, 0.8)
    love.graphics.ellipse("fill", 735, 140, 5, 2)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("75", 745, 133)
    
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.ellipse("fill", 735, 155, 7, 3)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("120", 740, 148)
    
    -- Warning
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.print("⚠ UFOs shoot!", 675, 180)
        
        -- Draw active powerups
        local powerupY = 420
        if smallFont then love.graphics.setFont(smallFont) end
        
        if activePowerups.tripleShot > 0 or activePowerups.rapidFire > 0 or 
           activePowerups.shield > 0 or activePowerups.slowTime > 0 or
           activePowerups.homing > 0 or activePowerups.pierce > 0 or
           activePowerups.freeze > 0 or activePowerups.vampire > 0 then
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Active:", 10, powerupY)
            powerupY = powerupY + 15
        end
        
        if activePowerups.tripleShot > 0 then
            love.graphics.setColor(1, 0.5, 0)
            love.graphics.print("Triple Shot: " .. math.ceil(activePowerups.tripleShot) .. "s", 10, powerupY)
            powerupY = powerupY + 15
        end
        
        if activePowerups.rapidFire > 0 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("Rapid Fire: " .. math.ceil(activePowerups.rapidFire) .. "s", 10, powerupY)
            powerupY = powerupY + 15
        end
        
        if activePowerups.shield > 0 then
            love.graphics.setColor(0, 1, 1)
            love.graphics.print("Shield: " .. math.ceil(activePowerups.shield) .. "s", 10, powerupY)
            powerupY = powerupY + 15
        end
        
        if activePowerups.slowTime > 0 then
            love.graphics.setColor(0.8, 0.5, 1)
            love.graphics.print("Slow Time: " .. math.ceil(activePowerups.slowTime) .. "s", 10, powerupY)
            powerupY = powerupY + 15
        end
        
        if activePowerups.homing > 0 then
            love.graphics.setColor(1, 0.3, 0.3)
            love.graphics.print("Homing: " .. math.ceil(activePowerups.homing) .. "s", 10, powerupY)
            powerupY = powerupY + 15
        end
        
        if activePowerups.pierce > 0 then
            love.graphics.setColor(0.5, 1, 0.5)
            love.graphics.print("Pierce: " .. math.ceil(activePowerups.pierce) .. "s", 10, powerupY)
            powerupY = powerupY + 15
        end
        
        if activePowerups.freeze > 0 then
            love.graphics.setColor(0.5, 0.8, 1)
            love.graphics.print("Freeze: " .. math.ceil(activePowerups.freeze) .. "s", 10, powerupY)
            powerupY = powerupY + 15
        end
        
        if activePowerups.vampire > 0 then
            love.graphics.setColor(0.8, 0.2, 0.8)
            love.graphics.print("Vampire: " .. math.ceil(activePowerups.vampire) .. "s", 10, powerupY)
            powerupY = powerupY + 15
        end
        
        -- Mini radar
        love.graphics.setColor(0, 1, 1)
        if smallFont then love.graphics.setFont(smallFont) end
        love.graphics.print("RADAR", 10, 480)
        
        -- Radar background
        local radarCenterX = 60
        local radarCenterY = 540
        local radarRadius = 40
        
        love.graphics.setColor(0, 0.3, 0.3, 0.5)
        love.graphics.circle("fill", radarCenterX, radarCenterY, radarRadius)
        
        -- Radar rings
        love.graphics.setColor(0, 0.8, 0.8, 0.3)
        love.graphics.circle("line", radarCenterX, radarCenterY, radarRadius)
        love.graphics.circle("line", radarCenterX, radarCenterY, radarRadius * 0.66)
        love.graphics.circle("line", radarCenterX, radarCenterY, radarRadius * 0.33)
        
        -- Radar sweep
        local sweepAngle = love.timer.getTime() * 2
        love.graphics.setColor(0, 1, 1, 0.5)
        love.graphics.arc("fill", radarCenterX, radarCenterY, radarRadius, sweepAngle - 0.5, sweepAngle)
        
        -- Show asteroids on radar
        for _, asteroid in ipairs(asteroids) do
            if asteroid.y < baseHeight and asteroid.y > -100 then
                local relX = (asteroid.x - baseWidth/2) / (baseWidth/2)
                local relY = (asteroid.y - baseHeight/2) / (baseHeight/2)
                local blipX = radarCenterX + relX * radarRadius * 0.8
                local blipY = radarCenterY + relY * radarRadius * 0.8
                
                -- Color based on asteroid type
                if asteroid.type == "large" then
                    love.graphics.setColor(1, 0.5, 0)
                elseif asteroid.type == "metal" then
                    love.graphics.setColor(0.8, 0.8, 1)
                elseif asteroid.type == "fragment" then
                    love.graphics.setColor(0.9, 0.6, 0.3)
                else
                    love.graphics.setColor(1, 1, 0)
                end
                
                love.graphics.circle("fill", blipX, blipY, 2)
            end
        end
        
        -- Show aliens on radar (as triangles)
        for _, alien in ipairs(aliens) do
            if alien.y < baseHeight and alien.y > -100 then
                local relX = (alien.x - baseWidth/2) / (baseWidth/2)
                local relY = (alien.y - baseHeight/2) / (baseHeight/2)
                local blipX = radarCenterX + relX * radarRadius * 0.8
                local blipY = radarCenterY + relY * radarRadius * 0.8
                
                -- Red triangles for aliens
                love.graphics.setColor(1, 0.2, 0.2)
                love.graphics.polygon("fill", 
                    blipX, blipY - 3,
                    blipX - 3, blipY + 3,
                    blipX + 3, blipY + 3
                )
            end
        end
        
        -- Show boss on radar
        if boss then
            local relX = ((boss.x + boss.width/2) - baseWidth/2) / (baseWidth/2)
            local relY = ((boss.y + boss.height/2) - baseHeight/2) / (baseHeight/2)
            local blipX = radarCenterX + relX * radarRadius * 0.8
            local blipY = radarCenterY + relY * radarRadius * 0.8
            
            -- Flashing red square for boss
            local flash = math.sin(love.timer.getTime() * 5) * 0.5 + 0.5
            love.graphics.setColor(1, flash, flash)
            love.graphics.rectangle("fill", blipX - 5, blipY - 5, 10, 10)
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle("line", blipX - 5, blipY - 5, 10, 10)
        end
        
        -- Player position on radar
        love.graphics.setColor(0, 1, 0)
        love.graphics.circle("fill", radarCenterX, radarCenterY + radarRadius * 0.7, 3)
        
        love.graphics.setFont(font)
        
        -- Debug info display
        if debugMode then
            love.graphics.setFont(smallFont)
            local debugX = baseWidth - 200
            local debugY = 10
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("DEBUG MODE", debugX, debugY)
            debugY = debugY + 15
            
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Enemies: " .. #asteroids + #aliens, debugX, debugY)
            debugY = debugY + 15
            love.graphics.print("Lasers: " .. #lasers, debugX, debugY)
            debugY = debugY + 15
            love.graphics.print("Enemy Lasers: " .. #alienLasers + #bossLasers, debugX, debugY)
            debugY = debugY + 15
            love.graphics.print("Powerups: " .. #powerups, debugX, debugY)
            debugY = debugY + 15
            love.graphics.print("Enemies Defeated: " .. enemiesDefeated .. "/" .. enemiesForBoss, debugX, debugY)
            debugY = debugY + 15
            
            if boss then
                love.graphics.print("Boss HP: " .. boss.health .. "/" .. boss.maxHealth, debugX, debugY)
                debugY = debugY + 15
                love.graphics.print("Boss Phase: " .. boss.phase, debugX, debugY)
                debugY = debugY + 15
            end
            
            love.graphics.print("Invuln Time: " .. string.format("%.1f", invulnerableTime), debugX, debugY)
            debugY = debugY + 15
            
            love.graphics.setFont(font)
        end
        
        -- FPS display
        if showFPS then
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0, 1, 0)
            love.graphics.print("FPS: " .. love.timer.getFPS(), baseWidth - 80, baseHeight - 30)
            love.graphics.setFont(font)
        end
        
        -- Cheat mode indicator
        if cheatsEnabled then
            love.graphics.setFont(smallFont)
            love.graphics.setColor(1, 1, 0, 0.7)
            love.graphics.print("CHEATS ENABLED", baseWidth/2 - 50, baseHeight - 20)
            love.graphics.setFont(font)
        end
end

function drawPowerupBar(x, y, width, current, max, color)
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, width, 8)
    
    -- Fill
    local fillWidth = (current / max) * width
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, fillWidth, 8)
    
    -- Border
    love.graphics.setColor(color[1] * 0.8, color[2] * 0.8, color[3] * 0.8)
    love.graphics.rectangle("line", x, y, width, 8)
    
    -- Flash effect when low
    if current < 2 then
        local flash = math.sin(love.timer.getTime() * 10) * 0.5 + 0.5
        love.graphics.setColor(1, 0, 0, flash * 0.5)
        love.graphics.rectangle("fill", x, y, width, 8)
    end
end

function drawCircuitPattern(x, width, isLeft)
    local time = love.timer.getTime()
    love.graphics.setColor(0, 0.8, 1, 0.1)
    
    -- Vertical energy lines
    for i = 1, 3 do
        local lineX = isLeft and (x + 20 + i * 15) or (x + width - 20 - i * 15)
        local alpha = math.sin(time * 3 + i) * 0.1 + 0.1
        love.graphics.setColor(0, 0.8, 1, alpha)
        love.graphics.line(lineX, 0, lineX, baseHeight)
    end
    
    -- Random blinking nodes
    math.randomseed(math.floor(time * 2))
    for i = 1, 8 do
        local nodeX = x + math.random(20, width - 20)
        local nodeY = math.random(50, baseHeight - 50)
        local brightness = math.random() > 0.7 and 1 or 0.3
        love.graphics.setColor(0, brightness, brightness, 0.5)
        love.graphics.circle("fill", nodeX, nodeY, 2)
    end
    math.randomseed(os.time())
end

-- Laser functions
function shootLaser()
    totalShotsFired = totalShotsFired + 1 -- Track shots fired
    
    if activePowerups.tripleShot > 0 then
        -- Triple shot counts as one shot action
        for i = -1, 1 do
            local laser = {
                x = player.x + player.width/2 - 2 + (i * 15), -- More spread
                y = player.y - 5,
                width = 4,
                height = 20,
                speed = 500,
                vx = i * 80, -- More angle
                homing = activePowerups.homing > 0,
                pierce = activePowerups.pierce > 0,
                pierceCount = 0
            }
            table.insert(lasers, laser)
        end
    else
        -- Single shot
        local laser = {
            x = player.x + player.width/2 - 2,
            y = player.y - 5,
            width = 4,
            height = 20,
            speed = 500,
            vx = 0,
            homing = activePowerups.homing > 0,
            pierce = activePowerups.pierce > 0,
            pierceCount = 0
        }
        table.insert(lasers, laser)
    end
    
    -- Play laser sound
    if sounds.laser then
        local laserSound = sounds.laser:clone()
        laserSound:setVolume(0.3 * sfxVolume * masterVolume)
        laserSound:play()
    end
    
    -- Light controller rumble for shooting
    if gamepad and gamepad:isGamepad() then
        local intensity = activePowerups.tripleShot > 0 and 0.2 or 0.1
        gamepad:setVibration(intensity, intensity, 0.05) -- Very short, light rumble
    end
end

-- Explosion functions
function createExplosion(x, y, size)
    -- Handle string size parameter (for special effects like "teleport")
    local numericSize = size
    if type(size) == "string" then
        -- Set default sizes for special explosion types
        if size == "teleport" then
            numericSize = 30
        else
            numericSize = 20 -- Default size
        end
    elseif type(size) ~= "number" or size == nil then
        -- Default size for nil or invalid values
        numericSize = 20
    end
    
    local explosion = {
        x = x,
        y = y,
        particles = {}
    }
    
    -- Create particles
    local particleCount = math.random(15, 25)
    for i = 1, particleCount do
        local angle = (i / particleCount) * math.pi * 2
        local speed = math.random(50, 200)
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            size = math.random(2, 6),
            life = 1, -- Starts at 1, fades to 0
            color = {
                math.random(0.8, 1),    -- Red
                math.random(0.4, 0.8),  -- Green  
                math.random(0, 0.3)     -- Blue
            }
        }
        table.insert(explosion.particles, particle)
    end
    
    table.insert(explosions, explosion)
    
    -- Play explosion sound
    if sounds.explosion then
        local explosionSound = sounds.explosion:clone()
        explosionSound:setVolume(0.5 * sfxVolume * masterVolume)
        explosionSound:play()
    end
    
    -- Controller rumble for explosions
    if gamepad and gamepad:isGamepad() then
        local strength = math.min(1, numericSize / 50) -- Scale rumble based on explosion size
        gamepad:setVibration(strength * 0.8, strength * 0.6, 0.3) -- Left motor, right motor, duration
    end
end

function updateExplosions(dt)
    for i = #explosions, 1, -1 do
        local explosion = explosions[i]
        local allDead = true
        
        for j, particle in ipairs(explosion.particles) do
            -- Update position
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            
            -- Apply friction
            particle.vx = particle.vx * 0.95
            particle.vy = particle.vy * 0.95
            
            -- Fade out
            particle.life = particle.life - dt * 2
            
            if particle.life > 0 then
                allDead = false
            end
        end
        
        -- Remove explosion when all particles are dead
        if allDead then
            table.remove(explosions, i)
        end
    end
end

function drawExplosions()
    for _, explosion in ipairs(explosions) do
        for _, particle in ipairs(explosion.particles) do
            if particle.life > 0 then
                -- Set color with alpha based on life
                love.graphics.setColor(
                    particle.color[1], 
                    particle.color[2], 
                    particle.color[3], 
                    particle.life
                )
                
                -- Draw particle (smaller as it fades)
                local size = particle.size * particle.life
                love.graphics.circle("fill", particle.x, particle.y, size)
            end
        end
    end
end

-- Create smaller hit effect for damaged asteroids
function createHitEffect(x, y)
    local explosion = {
        x = x,
        y = y,
        particles = {}
    }
    
    -- Fewer particles for hit effect
    local particleCount = math.random(5, 10)
    for i = 1, particleCount do
        local angle = (i / particleCount) * math.pi * 2
        local speed = math.random(30, 100)
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            size = math.random(1, 3),
            life = 0.5, -- Shorter life
            color = {1, 1, 0.5} -- Yellow sparks
        }
        table.insert(explosion.particles, particle)
    end
    
    table.insert(explosions, explosion)
end

-- Powerup functions
function spawnPowerup(x, y)
    -- Make sure spawn position is within screen bounds
    x = math.max(20, math.min(baseWidth - 20, x))
    y = math.max(20, y) -- Don't spawn above screen
    
    local types = {"triple", "rapid", "shield", "slow"}
    
    -- Add level-specific powerups
    if currentLevel == 1 and math.random(100) <= 20 then -- 20% chance for level powerup
        table.insert(types, "homing")  -- Level 1: Homing missiles
    elseif currentLevel == 2 and math.random(100) <= 20 then
        table.insert(types, "pierce")  -- Level 2: Piercing shots
    elseif currentLevel == 3 and math.random(100) <= 20 then
        table.insert(types, "freeze")  -- Level 3: Freeze enemies
    elseif currentLevel == 4 and math.random(100) <= 20 then
        table.insert(types, "vampire")  -- Level 4: Life steal
    elseif currentLevel >= 5 and math.random(100) <= 20 then
        table.insert(types, "bomb")  -- Level 5+: Screen bomb
    end
    
    -- Rare chance for extra life powerup
    if math.random(100) <= 5 and lives < maxLives then -- 5% chance
        types = {"life"}
    end
    
    local powerupType = types[math.random(#types)]
    
    local powerup = {
        x = x - 12, -- Center the powerup
        y = y,
        type = powerupType,
        width = 30,  -- Larger hitbox
        height = 30,
        speed = 40,  -- Slightly slower falling
        time = 0
    }
    
    table.insert(powerups, powerup)
end

function updatePowerups(dt)
    for i = #powerups, 1, -1 do
        local powerup = powerups[i]
        if not powerup then
            goto continue_powerup
        end
        
        -- Powerups move slower than asteroids so they're easier to catch
        powerup.y = powerup.y + powerup.speed * dt
        powerup.time = powerup.time + dt
        
        -- Remove if off screen
        if powerup.y > baseHeight + 20 then
            table.remove(powerups, i)
        else
            -- Check collision with player
            if checkCollision(player, powerup) then
                collectPowerup(powerup)
                table.remove(powerups, i)
            end
        end
        ::continue_powerup::
    end
end

function collectPowerup(powerup)
    if powerup.type == "triple" then
        activePowerups.tripleShot = 8 -- 8 seconds
        createPowerupText("TRIPLE SHOT!", player.x + player.width/2, player.y - 20, {1, 0.5, 0})
        -- Triple rumble pattern
        if gamepad and gamepad:isGamepad() then
            gamepad:setVibration(0.3, 0.7, 0.1)
        end
    elseif powerup.type == "rapid" then
        activePowerups.rapidFire = 6 -- 6 seconds
        createPowerupText("RAPID FIRE!", player.x + player.width/2, player.y - 20, {1, 1, 0})
        -- Rapid rumble pattern
        if gamepad and gamepad:isGamepad() then
            gamepad:setVibration(0.5, 0.5, 0.15)
        end
    elseif powerup.type == "shield" then
        activePowerups.shield = 10 -- 10 seconds
        createPowerupText("SHIELD!", player.x + player.width/2, player.y - 20, {0, 1, 1})
        -- Create shield activation effect
        createShieldEffect(player.x + player.width/2, player.y + player.height/2)
        -- Shield rumble pattern (strong then fade)
        if gamepad and gamepad:isGamepad() then
            gamepad:setVibration(0.8, 0.8, 0.3)
        end
    elseif powerup.type == "slow" then
        activePowerups.slowTime = 5 -- 5 seconds
        createPowerupText("TIME SLOW!", player.x + player.width/2, player.y - 20, {0.8, 0.5, 1})
        -- Slow rumble pattern (long, low intensity)
        if gamepad and gamepad:isGamepad() then
            gamepad:setVibration(0.2, 0.2, 0.4)
        end
    elseif powerup.type == "life" then
        if lives < maxLives then
            lives = lives + 1
            createPowerupText("EXTRA LIFE!", player.x + player.width/2, player.y - 20, {1, 0.2, 0.2})
            -- Life rumble pattern (strong pulse)
            if gamepad and gamepad:isGamepad() then
                gamepad:setVibration(1, 1, 0.2)
            end
        end
    elseif powerup.type == "homing" then
        activePowerups.homing = 8 -- 8 seconds
        createPowerupText("HOMING MISSILES!", player.x + player.width/2, player.y - 20, {1, 0.3, 0.3})
        if gamepad and gamepad:isGamepad() then
            gamepad:setVibration(0.6, 0.4, 0.2)
        end
    elseif powerup.type == "pierce" then
        activePowerups.pierce = 7 -- 7 seconds
        createPowerupText("PIERCING SHOTS!", player.x + player.width/2, player.y - 20, {0.5, 1, 0.5})
        if gamepad and gamepad:isGamepad() then
            gamepad:setVibration(0.7, 0.3, 0.2)
        end
    elseif powerup.type == "freeze" then
        activePowerups.freeze = 6 -- 6 seconds
        createPowerupText("FREEZE BEAM!", player.x + player.width/2, player.y - 20, {0.5, 0.8, 1})
        if gamepad and gamepad:isGamepad() then
            gamepad:setVibration(0.3, 0.6, 0.3)
        end
    elseif powerup.type == "vampire" then
        activePowerups.vampire = 10 -- 10 seconds
        createPowerupText("LIFE STEAL!", player.x + player.width/2, player.y - 20, {0.8, 0.2, 0.8})
        if gamepad and gamepad:isGamepad() then
            gamepad:setVibration(0.5, 0.5, 0.25)
        end
    elseif powerup.type == "bomb" then
        -- Bomb is instant use, not a duration powerup
        createPowerupText("SCREEN BOMB!", player.x + player.width/2, player.y - 20, {1, 1, 1})
        -- Destroy all enemies on screen
        for i = #asteroids, 1, -1 do
            createExplosion(asteroids[i].x + asteroids[i].width/2, asteroids[i].y + asteroids[i].height/2, asteroids[i].width/2)
            -- score = score + asteroids[i].points or 20
            table.remove(asteroids, i)
        end
        for i = #aliens, 1, -1 do
            createExplosion(aliens[i].x + aliens[i].width/2, aliens[i].y + aliens[i].height/2, aliens[i].width/2)
            -- score = score + aliens[i].points or 50
            table.remove(aliens, i)
        end
        -- Big rumble for bomb
        if gamepad and gamepad:isGamepad() then
            gamepad:setVibration(1, 1, 0.5)
        end
    end
    
    -- Play powerup sound
    if sounds.powerup then
        local powerupSound = sounds.powerup:clone()
        powerupSound:setVolume(0.4 * sfxVolume * masterVolume)
        powerupSound:play()
    elseif sounds.explosion then
        -- Fallback to explosion sound with higher pitch
        local sound = sounds.explosion:clone()
        sound:setVolume(0.3 * sfxVolume * masterVolume)
        sound:setPitch(1.5)
        sound:play()
    end
end

function drawPowerups()
    for _, powerup in ipairs(powerups) do
        love.graphics.push()
        love.graphics.translate(powerup.x, powerup.y)
        
        -- Floating animation
        local float = math.sin(powerup.time * 3) * 2
        love.graphics.translate(0, float)
        
        -- Glow effect
        local glow = 0.5 + math.sin(powerup.time * 5) * 0.3
        
        -- Draw a small arrow pointing down above powerup
        love.graphics.setColor(1, 1, 1, glow * 0.7)
        love.graphics.polygon("fill", 0, -18, -4, -22, 4, -22)
        
        if powerup.type == "triple" then
            -- Triple shot - Orange
            love.graphics.setColor(1, 0.5, 0, glow)
            love.graphics.circle("fill", 0, 0, 12)
            love.graphics.setColor(1, 0.5, 0)
            love.graphics.circle("line", 0, 0, 10)
            -- Icon: three lines
            love.graphics.setColor(1, 1, 1)
            for i = -4, 4, 4 do
                love.graphics.rectangle("fill", i - 1, -6, 2, 12)
            end
            
        elseif powerup.type == "rapid" then
            -- Rapid fire - Yellow
            love.graphics.setColor(1, 1, 0, glow)
            love.graphics.circle("fill", 0, 0, 12)
            love.graphics.setColor(1, 1, 0)
            love.graphics.circle("line", 0, 0, 10)
            -- Icon: lightning bolt
            love.graphics.setColor(0, 0, 0)
            love.graphics.polygon("fill", -3, -6, 3, -2, 0, 0, 4, 6, -2, 2, 1, 0)
            
        elseif powerup.type == "shield" then
            -- Shield - Cyan
            love.graphics.setColor(0, 1, 1, glow)
            love.graphics.circle("fill", 0, 0, 12)
            love.graphics.setColor(0, 1, 1)
            love.graphics.circle("line", 0, 0, 10)
            -- Icon: shield shape
            love.graphics.setColor(1, 1, 1)
            love.graphics.polygon("fill", 0, -6, -5, -3, -5, 3, 0, 6, 5, 3, 5, -3)
            
        elseif powerup.type == "slow" then
            -- Slow time - Purple
            love.graphics.setColor(0.8, 0.5, 1, glow)
            love.graphics.circle("fill", 0, 0, 12)
            love.graphics.setColor(0.8, 0.5, 1)
            love.graphics.circle("line", 0, 0, 10)
            -- Icon: clock
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", 0, 0, 6)
            love.graphics.line(0, 0, 0, -4)
            love.graphics.line(0, 0, 3, 0)
            
        elseif powerup.type == "life" then
            -- Extra life - Red/Pink
            love.graphics.setColor(1, 0.2, 0.2, glow)
            love.graphics.circle("fill", 0, 0, 12)
            love.graphics.setColor(1, 0, 0)
            love.graphics.circle("line", 0, 0, 10)
            -- Icon: heart
            love.graphics.setColor(1, 1, 1)
            love.graphics.push()
            love.graphics.scale(0.8, 0.8)
            -- Draw a simple heart shape
            love.graphics.polygon("fill",
                0, -2,     -- bottom point
                -4, -6,    -- left curve bottom
                -6, -7,    -- left curve top
                -5, -9,    -- left top
                -3, -9,    -- left inner
                0, -6,     -- center dip
                3, -9,     -- right inner
                5, -9,     -- right top
                6, -7,     -- right curve top
                4, -6,     -- right curve bottom
                0, -2      -- back to bottom
            )
            love.graphics.pop()
            
        elseif powerup.type == "homing" then
            -- Homing - Dark red
            love.graphics.setColor(1, 0.3, 0.3, glow)
            love.graphics.circle("fill", 0, 0, 12)
            love.graphics.setColor(0.8, 0.2, 0.2)
            love.graphics.circle("line", 0, 0, 10)
            -- Icon: target
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", 0, 0, 6)
            love.graphics.circle("fill", 0, 0, 2)
            love.graphics.line(-8, 0, -4, 0)
            love.graphics.line(4, 0, 8, 0)
            love.graphics.line(0, -8, 0, -4)
            love.graphics.line(0, 4, 0, 8)
            
        elseif powerup.type == "pierce" then
            -- Pierce - Green
            love.graphics.setColor(0.5, 1, 0.5, glow)
            love.graphics.circle("fill", 0, 0, 12)
            love.graphics.setColor(0.3, 0.8, 0.3)
            love.graphics.circle("line", 0, 0, 10)
            -- Icon: arrow through
            love.graphics.setColor(1, 1, 1)
            love.graphics.polygon("fill", -6, 0, -2, -3, -2, -1, 4, -1, 4, -3, 8, 0, 4, 3, 4, 1, -2, 1, -2, 3)
            
        elseif powerup.type == "freeze" then
            -- Freeze - Light blue
            love.graphics.setColor(0.5, 0.8, 1, glow)
            love.graphics.circle("fill", 0, 0, 12)
            love.graphics.setColor(0.3, 0.6, 1)
            love.graphics.circle("line", 0, 0, 10)
            -- Icon: snowflake
            love.graphics.setColor(1, 1, 1)
            love.graphics.line(-6, 0, 6, 0)
            love.graphics.line(-3, -5, 3, 5)
            love.graphics.line(-3, 5, 3, -5)
            for i = -4, 4, 8 do
                love.graphics.line(i, -2, i, 2)
            end
            
        elseif powerup.type == "vampire" then
            -- Vampire - Purple
            love.graphics.setColor(0.8, 0.2, 0.8, glow)
            love.graphics.circle("fill", 0, 0, 12)
            love.graphics.setColor(0.6, 0.1, 0.6)
            love.graphics.circle("line", 0, 0, 10)
            -- Icon: fangs
            love.graphics.setColor(1, 1, 1)
            love.graphics.polygon("fill", -3, -6, -1, 0, -3, 0)
            love.graphics.polygon("fill", 3, -6, 1, 0, 3, 0)
            
        elseif powerup.type == "bomb" then
            -- Bomb - White/bright
            love.graphics.setColor(1, 1, 1, glow)
            love.graphics.circle("fill", 0, 0, 12)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.circle("line", 0, 0, 10)
            -- Icon: explosion
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.circle("fill", 0, 0, 5)
            love.graphics.setColor(1, 0.5, 0)
            for i = 0, 7 do
                local angle = (i / 8) * math.pi * 2
                love.graphics.line(0, 0, math.cos(angle) * 8, math.sin(angle) * 8)
            end
        end
        
        love.graphics.pop()
    end
end

-- Shield activation effect
function createShieldEffect(x, y)
    local explosion = {
        x = x,
        y = y,
        particles = {}
    }
    
    -- Create expanding ring effect
    local particleCount = 20
    for i = 1, particleCount do
        local angle = (i / particleCount) * math.pi * 2
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * 150,
            vy = math.sin(angle) * 150,
            size = 4,
            life = 0.8,
            color = {0, 1, 1} -- Cyan color
        }
        table.insert(explosion.particles, particle)
    end
    
    table.insert(explosions, explosion)
end

-- Shield break effect
function createShieldBreakEffect(x, y)
    local explosion = {
        x = x,
        y = y,
        particles = {}
    }
    
    -- Create shattering glass effect
    local particleCount = 30
    for i = 1, particleCount do
        local angle = (i / particleCount) * math.pi * 2
        local speed = math.random(100, 250)
        local particle = {
            x = x + math.cos(angle) * 35, -- Start at shield edge
            y = y + math.sin(angle) * 35,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            size = math.random(2, 5),
            life = 1,
            color = {0.5, 1, 1} -- Light cyan shards
        }
        table.insert(explosion.particles, particle)
    end
    
    table.insert(explosions, explosion)
end

-- Floating text effect
function createPowerupText(text, x, y, color)
    table.insert(powerupTexts, {
        text = text,
        x = x,
        y = y,
        color = color,
        life = 1
    })
end

function updatePowerupTexts(dt)
    for i = #powerupTexts, 1, -1 do
        local text = powerupTexts[i]
        text.y = text.y - 50 * dt
        text.life = text.life - dt
        
        if text.life <= 0 then
            table.remove(powerupTexts, i)
        end
    end
end

function drawPowerupTexts()
    for _, text in ipairs(powerupTexts) do
        love.graphics.setColor(text.color[1], text.color[2], text.color[3], text.life)
        if smallFont then love.graphics.setFont(smallFont) end
        love.graphics.printf(text.text, text.x - 80, text.y, 160, "center")
        love.graphics.setFont(font)
    end
end

-- Alien functions
function spawnSpaceFighter()
    local alienType = math.random(1, 100)
    local alien
    
    -- Level 2 modifications
    local speedBoost = currentLevel == 2 and 1.25 or 1.0 -- 25% faster in level 2
    local healthBonus = currentLevel == 2 and 1 or 0
    local fireRateBoost = currentLevel == 2 and 0.8 or 1.0 -- Shoot 20% faster in level 2
    
    if alienType <= 60 then
        -- Basic UFO - moves side to side
        alien = {
            x = math.random(50, baseWidth - 100),
            y = -40,
            width = 50,
            height = 30,
            vx = math.random(80, 120) * speedBoost * (math.random() > 0.5 and 1 or -1),
            vy = math.random(30, 50) * speedBoost,
            health = 2 + healthBonus,
            maxHealth = 2 + healthBonus,
            points = currentLevel == 2 and 80 or 60,
            shootInterval = 2.5 * fireRateBoost,
            shootCooldown = math.random(1, 2),
            type = "basic"
        }
    elseif alienType <= 85 then
        -- Fast scout - moves quickly in diagonal patterns
        alien = {
            x = math.random(50, baseWidth - 80),
            y = -30,
            width = 40,
            height = 25,
            vx = math.random(150, 200) * speedBoost * (math.random() > 0.5 and 1 or -1),
            vy = math.random(60, 80) * speedBoost,
            health = 1 + healthBonus,
            maxHealth = 1 + healthBonus,
            points = currentLevel == 2 and 100 or 75,
            shootInterval = 3.0 * fireRateBoost,
            shootCooldown = math.random(1.5, 3),
            type = "scout"
        }
    else
        -- Heavy UFO - slow but tough
        alien = {
            x = math.random(100, baseWidth - 150),
            y = -50,
            width = 70,
            height = 40,
            vx = math.random(40, 60) * speedBoost * (math.random() > 0.5 and 1 or -1),
            vy = math.random(20, 30) * speedBoost,
            health = 4 + healthBonus * 2,
            maxHealth = 4 + healthBonus * 2,
            points = currentLevel == 2 and 150 or 120,
            shootInterval = 1.8 * fireRateBoost,
            shootCooldown = math.random(0.5, 1.5),
            type = "heavy"
        }
    end
    
    table.insert(aliens, alien)
end

-- Generic alien spawn function that calls the appropriate spawner
function spawnAlien()
    spawnSpaceFighter()
end

-- Boss functions
-- This function is replaced by the more complete version at line 4451

function updateBoss(dt)
    if not boss then return end
    
    -- Boss entry
    local entryY = boss.targetY or 50  -- Use targetY if set (for frost titan), otherwise 50
    if boss.y < entryY then
        boss.y = boss.y + boss.vy * dt
        if boss.y >= entryY then
            boss.y = entryY  -- Snap to exact position
        end
    else
        -- Boss movement pattern
        boss.x = boss.x + boss.vx * dt
        if boss.x <= 0 or boss.x >= baseWidth - boss.width then
            boss.vx = -boss.vx
            boss.x = math.max(0, math.min(baseWidth - boss.width, boss.x))
        end
        
        -- Update rotation for Annihilator
        if boss.type == "annihilator" then
            boss.rotationAngle = boss.rotationAngle + dt * 0.5
            
            -- Update beam sweep if active
            if boss.beamActive then
                boss.beamAngle = boss.beamAngle + dt * 0.8  -- Sweep speed
                boss.beamDuration = boss.beamDuration - dt
                
                -- Check beam collision with player
                local beamX = boss.x + boss.width/2
                local beamY = boss.y + boss.height
                local beamEndX = beamX + math.cos(boss.beamAngle) * 1000
                local beamEndY = beamY + math.sin(boss.beamAngle) * 1000
                
                -- Simple line-box collision for beam
                if lineBoxCollision(beamX, beamY, beamEndX, beamEndY, 
                                   player.x, player.y, player.width, player.height) then
                    if invulnerableTime <= 0 and activePowerups.shield <= 0 then
                        loseLife()
                    elseif activePowerups.shield > 0 then
                        activePowerups.shield = 0
                        createShieldBreakEffect(player.x + player.width/2, player.y + player.height/2)
                    end
                end
                
                if boss.beamDuration <= 0 or boss.beamAngle > math.pi/4 then
                    boss.beamActive = false
                end
            end
        end
        
        -- Update invulnerability
        if boss.invulnerableTimer and boss.invulnerableTimer > 0 then
            boss.invulnerableTimer = boss.invulnerableTimer - dt
            if boss.invulnerableTimer <= 0 then
                boss.invulnerable = false
            end
        end
        
        -- Boss attack patterns
        boss.shootTimer = boss.shootTimer + dt
        boss.specialTimer = (boss.specialTimer or 0) + dt
        
        if boss.type == "destroyer" then
            -- Level 1 Boss patterns
            if boss.phase == 1 then
                if boss.shootTimer > 1.5 then  -- Slowed from 0.8
                    bossSpreadShot()
                    boss.shootTimer = 0
                end
                
                if boss.specialTimer > 6 then  -- Slowed from 4
                    bossHomingAttack()
                    boss.specialTimer = 0
                end
                
                if boss.health <= boss.maxHealth * 0.5 then
                    boss.phase = 2
                    boss.vx = boss.vx * 1.5
                    createPowerupText("BOSS ENRAGED!", boss.x + boss.width/2, boss.y + boss.height + 20, {1, 0, 0})
                end
                
            elseif boss.phase == 2 then
                if boss.shootTimer > 1.0 then  -- Slowed from 0.5
                    bossSpreadShot()
                    boss.shootTimer = 0
                end
                
                if boss.specialTimer > 4.5 then  -- Slowed from 3
                    bossLaserBarrage()
                    boss.specialTimer = 0
                end
            end
            
        elseif boss.type == "annihilator" then
            -- Level 2 Boss patterns - unique mechanics
            if boss.phase == 1 then
                -- Activate shield periodically
                if not boss.shieldActive and boss.shieldHealth <= 0 and boss.specialTimer > 10 then
                    boss.shieldActive = true
                    boss.shieldHealth = 100
                    createPowerupText("SHIELD ACTIVATED!", boss.x + boss.width/2, boss.y + boss.height + 20, {0, 1, 1})
                end
                
                -- Teleport attack pattern
                if boss.shootTimer > 1.5 then
                    annihilatorTeleportAttack()
                    boss.shootTimer = 0
                end
                
                -- Special attacks rotation
                if boss.specialTimer > 6 then
                    local attack = math.random(1, 3)
                    if attack == 1 then
                        annihilatorBeamSweep()
                    elseif attack == 2 then
                        annihilatorMineField()
                    else
                        annihilatorShieldBurst()
                    end
                    boss.specialTimer = 0
                end
                
                if boss.health <= boss.maxHealth * 0.5 then
                    boss.phase = 2
                    boss.vx = boss.vx * 1.5
                    createPowerupText("OVERDRIVE MODE!", boss.x + boss.width/2, boss.y + boss.height + 20, {1, 0, 1})
                    -- Clear mines when entering phase 2
                    for i = #aliens, 1, -1 do
                        if aliens[i].type == "energyMine" then
                            createExplosion(aliens[i].x + aliens[i].width/2, aliens[i].y + aliens[i].height/2, 20)
                            table.remove(aliens, i)
                        end
                    end
                end
                
            elseif boss.phase == 2 then
                -- More aggressive patterns with teleportation
                if boss.shootTimer > 0.8 then
                    annihilatorTeleportAttack()
                    boss.shootTimer = 0
                end
                
                -- Rapid special attacks
                if boss.specialTimer > 3 then
                    local attack = math.random(1, 2)
                    if attack == 1 then
                        annihilatorBeamSweep()
                    else
                        annihilatorShieldBurst()
                        annihilatorMineField()  -- Double attack!
                    end
                    boss.specialTimer = 0
                end
                
                -- Desperation attack at low health
                if boss.health <= boss.maxHealth * 0.2 and not boss.desperationMode then
                    boss.desperationMode = true
                    createPowerupText("MAXIMUM POWER!", boss.x + boss.width/2, boss.y + boss.height + 20, {1, 1, 0})
                    boss.shootTimer = 0
                    boss.specialTimer = 0
                end
            end
        elseif boss.type == "frosttitan" then
            -- Level 3 Boss patterns - Frost Titan
            -- Update leg animation
            for i, leg in ipairs(boss.legs) do
                leg.raised = (math.sin(love.timer.getTime() * 2 + i) > 0.5)
            end
            
            if boss.phase == 1 then
                -- Ice shard barrage
                if boss.shootTimer > 1.8 then
                    frostTitanIceShards()
                    boss.shootTimer = 0
                end
                
                -- Special attacks
                if boss.specialTimer > 5 then
                    local attack = math.random(1, 3)
                    if attack == 1 then
                        frostTitanFreezingWave()
                    elseif attack == 2 then
                        frostTitanIceBeam()
                    else
                        frostTitanSummonGeysers()
                    end
                    boss.specialTimer = 0
                end
                
                if boss.health <= boss.maxHealth * 0.5 then
                    boss.phase = 2
                    boss.vx = boss.vx * 1.3
                    createPowerupText("BLIZZARD MODE!", boss.x + boss.width/2, boss.y + boss.height + 20, {0.5, 0.8, 1})
                end
                
            elseif boss.phase == 2 then
                -- More aggressive ice attacks
                if boss.shootTimer > 1.2 then
                    frostTitanIceShards()
                    boss.shootTimer = 0
                end
                
                -- Rapid special attacks
                if boss.specialTimer > 3 then
                    local attack = math.random(1, 2)
                    if attack == 1 then
                        frostTitanIceBeam()
                        frostTitanFreezingWave() -- Double attack!
                    else
                        frostTitanSummonGeysers()
                    end
                    boss.specialTimer = 0
                end
            end
        elseif boss.type == "hivemind" then
            -- Level 4 Boss patterns - Hivemind
            -- Update tentacle movement
            if boss.tentacles then
                for i, tentacle in ipairs(boss.tentacles) do
                    tentacle.angle = tentacle.angle + dt * 0.5
                end
            end
            
            if boss.phase == 1 then
                -- Organic projectiles
                if boss.shootTimer > 1.5 then
                    hivemindOrganicBarrage()
                    boss.shootTimer = 0
                end
                
                -- Special attacks
                if boss.specialTimer > 5 then
                    local attack = math.random(1, 3)
                    if attack == 1 then
                        hivemindTentacleSwipe()
                    elseif attack == 2 then
                        hivemindSpawnMinions()
                    else
                        hivemindPsychicWave()
                    end
                    boss.specialTimer = 0
                end
                
                if boss.health <= boss.maxHealth * 0.5 then
                    boss.phase = 2
                    boss.vx = boss.vx * 1.4
                    createPowerupText("RAGE MODE!", boss.x + boss.width/2, boss.y + boss.height + 20, {0.8, 0.2, 0.2})
                end
                
            elseif boss.phase == 2 then
                -- More aggressive patterns
                if boss.shootTimer > 1.0 then
                    hivemindOrganicBarrage()
                    boss.shootTimer = 0
                end
                
                -- Rapid attacks
                if boss.specialTimer > 3 then
                    hivemindTentacleSwipe()
                    if math.random() > 0.5 then
                        hivemindSpawnMinions() -- Extra minions
                    end
                    boss.specialTimer = 0
                end
            end
        end
        
        -- Check laser collisions with boss
        for i = #lasers, 1, -1 do
            local laser = lasers[i]
            if checkCollision(laser, boss) and not boss.invulnerable then
                table.remove(lasers, i)
                
                -- Check shield for Annihilator
                if boss.type == "annihilator" and boss.shieldActive and boss.shieldHealth > 0 then
                    boss.shieldHealth = boss.shieldHealth - 1
                    createHitEffect(laser.x + laser.width/2, laser.y + laser.height/2)
                    
                    if boss.shieldHealth <= 0 then
                        boss.shieldActive = false
                        createShieldBreakEffect(boss.x + boss.width/2, boss.y + boss.height/2)
                        createPowerupText("SHIELD BROKEN!", boss.x + boss.width/2, boss.y + boss.height + 20, {1, 1, 0})
                    end
                else
                    -- Normal damage
                    boss.health = boss.health - 1
                    createHitEffect(laser.x + laser.width/2, laser.y + laser.height/2)
                    
                    if boss.health <= 0 then
                        defeatBoss()
                        return  -- Exit updateBoss since boss is now nil
                    end
                end
            end
        end
        
        -- Check collision with player (boss might be nil after defeat)
        if boss and checkCollision(player, boss) and invulnerableTime <= 0 then
            if activePowerups.shield > 0 then
                activePowerups.shield = 0
                createShieldBreakEffect(
                    player.x + player.width/2,
                    player.y + player.height/2
                )
                if gamepad and gamepad:isGamepad() then
                    gamepad:setVibration(0.8, 0.8, 0.4)
                end
            else
                loseLife()
            end
        end
    end
end

function bossSpreadShot()
    local centerX = boss.x + boss.width/2
    local centerY = boss.y + boss.height
    
    -- Shoot 5 lasers in a spread
    for i = -2, 2 do
        local angle = (i * 25) * math.pi / 180 -- Increased from 15 to 25 degree spread
        local speed = 150  -- Slowed from 200
        
        local laser = {
            x = centerX - 4,
            y = centerY,
            width = 8,
            height = 16,
            vx = math.sin(angle) * speed,
            vy = math.cos(angle) * speed,
            damage = 1
        }
        table.insert(bossLasers, laser)
    end
    
    -- Play sound
    if sounds.laser then
        local bossLaser = sounds.laser:clone()
        bossLaser:setPitch(0.7) -- Lower pitch for boss
        bossLaser:setVolume(0.4 * sfxVolume * masterVolume)
        bossLaser:play()
    end
end

function bossHomingAttack()
    local centerX = boss.x + boss.width/2
    local centerY = boss.y + boss.height
    
    -- Shoot 2 homing missiles
    for i = -1, 1, 2 do
        local laser = {
            x = centerX + i * 40,
            y = centerY,
            width = 10,
            height = 10,
            vx = i * 20,  -- Even slower initial sideways velocity
            vy = 40,      -- Even slower initial downward velocity
            homing = true,
            homingTime = 4, -- Homes for 4 seconds (longer but slower)
            damage = 1
        }
        table.insert(bossLasers, laser)
    end
    
    createPowerupText("HOMING!", boss.x + boss.width/2, boss.y + boss.height + 20, {1, 0, 1})
end

function bossLaserBarrage()
    -- Rapid fire laser barrage
    local centerX = boss.x + boss.width/2
    local centerY = boss.y + boss.height
    
    -- Fire in a sweeping pattern
    for i = 1, 8 do
        local angle = (i - 4) * 10 * math.pi / 180
        local speed = 300
        
        local laser = {
            x = centerX - 5,
            y = centerY,
            width = 10,
            height = 20,
            vx = math.sin(angle) * speed * 0.7,
            vy = math.cos(angle) * speed,
            damage = 1
        }
        table.insert(bossLasers, laser)
    end
    
    createPowerupText("BARRAGE!", boss.x + boss.width/2, boss.y + boss.height + 20, {1, 0.5, 0})
end

-- New attack patterns for Level 2 Boss
function bossCircularShot()
    local centerX = boss.x + boss.width/2
    local centerY = boss.y + boss.height/2
    
    -- Shoot lasers in a circle
    local numShots = boss.phase == 2 and 12 or 8
    for i = 1, numShots do
        local angle = (i / numShots) * math.pi * 2 + boss.rotationAngle
        local speed = 150
        
        local laser = {
            x = centerX + math.cos(angle) * 50,
            y = centerY + math.sin(angle) * 50,
            width = 8,
            height = 8,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            damage = 1
        }
        table.insert(bossLasers, laser)
    end
    
    -- Play sound
    if sounds.laser then
        local circleSound = sounds.laser:clone()
        circleSound:setPitch(0.8)
        circleSound:setVolume(0.3 * sfxVolume * masterVolume)
        circleSound:play()
    end
end

function bossSpiralAttack()
    local centerX = boss.x + boss.width/2
    local centerY = boss.y + boss.height
    
    -- Create spiral pattern
    createPowerupText("SPIRAL!", boss.x + boss.width/2, boss.y + boss.height + 20, {1, 0, 1})
    
    for i = 1, 3 do
        local baseAngle = (i / 3) * math.pi * 2
        local laser = {
            x = centerX,
            y = centerY,
            width = 12,
            height = 12,
            vx = math.cos(baseAngle) * 100,
            vy = math.sin(baseAngle) * 100 + 50,
            spiral = true,
            spiralAngle = baseAngle,
            spiralSpeed = 3,
            damage = 1
        }
        table.insert(bossLasers, laser)
    end
end

function bossLaserWave()
    local centerX = boss.x + boss.width/2
    local startY = boss.y + boss.height
    
    -- Create a wave of lasers
    createPowerupText("WAVE!", boss.x + boss.width/2, boss.y + boss.height + 20, {0, 1, 1})
    
    for i = -5, 5 do
        local laser = {
            x = centerX + i * 30,
            y = startY,
            width = 15,
            height = 30,
            vx = 0,
            vy = 250,
            wave = true,
            waveOffset = i,
            waveTime = 0,
            damage = 1
        }
        table.insert(bossLasers, laser)
    end
    
    -- Heavy rumble for wave attack
    if gamepad and gamepad:isGamepad() then
        gamepad:setVibration(0.5, 0.5, 0.5)
    end
end

-- Annihilator-specific attacks
function annihilatorBeamSweep()
    if not boss.beamActive then
        boss.beamActive = true
        boss.beamAngle = -math.pi/4  -- Start from left
        boss.beamDuration = 3
        createPowerupText("BEAM SWEEP!", boss.x + boss.width/2, boss.y + boss.height + 20, {1, 0, 1})
    end
end

function annihilatorTeleportAttack()
    -- Teleport to random position and fire burst
    local oldX = boss.x
    boss.x = math.random(50, baseWidth - boss.width - 50)
    
    -- Create teleport effect at old position
    createExplosion(oldX + boss.width/2, boss.y + boss.height/2, "teleport")
    
    -- Fire burst from new position
    createPowerupText("TELEPORT!", boss.x + boss.width/2, boss.y - 20, {1, 0, 1})
    
    -- Fire omnidirectional burst
    for i = 1, 16 do
        local angle = (i / 16) * math.pi * 2
        local laser = {
            x = boss.x + boss.width/2,
            y = boss.y + boss.height/2,
            width = 10,
            height = 20,
            vx = math.cos(angle) * 300,
            vy = math.sin(angle) * 300,
            damage = 1,
            color = {1, 0, 1}  -- Purple lasers
        }
        table.insert(bossLasers, laser)
    end
end

function annihilatorMineField()
    createPowerupText("MINES!", boss.x + boss.width/2, boss.y + boss.height + 20, {1, 0, 0.5})
    
    -- Deploy stationary mines
    for i = 1, 8 do
        local mine = {
            x = math.random(50, baseWidth - 50),
            y = math.random(100, baseHeight - 200),
            width = 30,
            height = 30,
            vx = 0,
            vy = 0,
            health = 1,  -- Added health property
            maxHealth = 1,
            lifeTime = 10,
            type = "energyMine",
            damage = 1,
            pulseTimer = 0,
            armed = false,
            armTimer = 1  -- 1 second to arm
        }
        table.insert(aliens, mine)
    end
end

function annihilatorShieldBurst()
    if boss.shieldActive and boss.shieldHealth > 0 then
        -- Shield releases energy burst when active
        createPowerupText("SHIELD BURST!", boss.x + boss.width/2, boss.y + boss.height + 20, {0, 1, 1})
        
        for i = 1, 12 do
            local angle = (i / 12) * math.pi * 2
            local laser = {
                x = boss.x + boss.width/2,
                y = boss.y + boss.height/2,
                width = 15,
                height = 15,
                vx = math.cos(angle) * 200,
                vy = math.sin(angle) * 200,
                damage = 1,
                color = {0, 1, 1},  -- Cyan shield lasers
                homing = true,
                homingStrength = 50
            }
            table.insert(bossLasers, laser)
        end
        
        -- Damage shield slightly
        boss.shieldHealth = boss.shieldHealth - 10
    end
end

-- Frost Titan attack functions
function frostTitanIceShards()
    createPowerupText("ICE BARRAGE!", boss.x + boss.width/2, boss.y + boss.height + 20, {0.5, 0.8, 1})
    
    -- Fire ice shards in a spread pattern
    local shardCount = boss.phase == 2 and 7 or 5
    local spreadAngle = math.pi / 3  -- 60 degree spread
    
    for i = 1, shardCount do
        local angle = math.pi/2 + (i - (shardCount + 1)/2) * (spreadAngle / shardCount)
        local shard = {
            x = boss.x + boss.width/2,
            y = boss.y + boss.height,
            width = 12,
            height = 20,
            vx = math.cos(angle) * 250,
            vy = math.sin(angle) * 250,
            damage = 1,
            color = {0.6, 0.8, 1},  -- Ice blue
            type = "iceShard"
        }
        table.insert(bossLasers, shard)
    end
end

function frostTitanFreezingWave()
    createPowerupText("FREEZE WAVE!", boss.x + boss.width/2, boss.y + boss.height + 20, {0.3, 0.6, 1})
    
    -- Create expanding freeze wave
    local wave = {
        x = boss.x + boss.width/2,
        y = boss.y + boss.height/2,
        width = 10,
        height = 10,
        radius = 10,
        maxRadius = 300,
        speed = 200,
        damage = 1,
        type = "freezeWave",
        color = {0.5, 0.8, 1, 0.5}
    }
    table.insert(alienLasers, wave)
end

function frostTitanIceBeam()
    createPowerupText("ICE BEAM!", boss.x + boss.width/2, boss.y + boss.height + 20, {0, 0.5, 1})
    
    -- Calculate angle to player
    local dx = player.x + player.width/2 - (boss.x + boss.width/2)
    local dy = player.y + player.height/2 - (boss.y + boss.height/2)
    local angle = math.atan2(dy, dx)
    
    -- Create continuous ice beam (multiple projectiles)
    for i = 1, 10 do
        local delay = i * 0.1
        local beam = {
            x = boss.x + boss.width/2,
            y = boss.y + boss.height/2,
            width = 20,
            height = 20,
            vx = math.cos(angle) * 400,
            vy = math.sin(angle) * 400,
            damage = 1,
            color = {0.3, 0.6, 1},
            type = "iceBeam",
            delay = delay  -- Staggered firing
        }
        table.insert(bossLasers, beam)
    end
end

function frostTitanSummonGeysers()
    createPowerupText("ICE GEYSERS!", boss.x + boss.width/2, boss.y + boss.height + 20, {0.7, 0.9, 1})
    
    -- Spawn ice geysers at random positions
    local geyserCount = boss.phase == 2 and 5 or 3
    
    for i = 1, geyserCount do
        local geyser = {
            x = math.random(50, baseWidth - 50),
            y = groundY,
            width = 40,
            height = 10,
            warningTime = 1,  -- Warning before eruption
            activeTime = 0,
            maxActiveTime = 2,
            damage = 1,
            type = "iceGeyser",
            erupted = false
        }
        table.insert(iceGeysers, geyser)
    end
end

-- Hivemind attack functions
function hivemindOrganicBarrage()
    createPowerupText("ORGANIC BARRAGE!", boss.x + boss.width/2, boss.y + boss.height + 20, {0.5, 1, 0.5})
    
    -- Fire organic projectiles in a spread
    local projectileCount = boss.phase == 2 and 7 or 5
    local spreadAngle = math.pi / 2
    
    for i = 1, projectileCount do
        local angle = math.pi/2 + (i - (projectileCount + 1)/2) * (spreadAngle / projectileCount)
        local projectile = {
            x = boss.x + boss.width/2,
            y = boss.y + boss.height,
            width = 16,
            height = 16,
            vx = math.cos(angle) * 200,
            vy = math.sin(angle) * 200,
            damage = 1,
            color = {0.6, 0.8, 0.6},
            type = "organic"
        }
        table.insert(bossLasers, projectile)
    end
end

function hivemindTentacleSwipe()
    createPowerupText("TENTACLE SWIPE!", boss.x + boss.width/2, boss.y + boss.height + 20, {0.3, 0.6, 0.3})
    
    -- Create sweeping tentacle projectiles
    if boss.tentacles then
        for i, tentacle in ipairs(boss.tentacles) do
            local baseX = boss.x + boss.width/2 + math.cos(tentacle.angle) * boss.width/3
            local baseY = boss.y + boss.height/2 + math.sin(tentacle.angle) * boss.height/3
            
            -- Launch projectile from tentacle tip
            local projectile = {
                x = baseX,
                y = baseY,
                width = 20,
                height = 20,
                vx = math.cos(tentacle.angle) * 300,
                vy = math.sin(tentacle.angle) * 300,
                damage = 1,
                color = {0.4, 0.6, 0.4},
                type = "tentacle"
            }
            table.insert(bossLasers, projectile)
        end
    end
end

function hivemindSpawnMinions()
    createPowerupText("SPAWN MINIONS!", boss.x + boss.width/2, boss.y + boss.height + 20, {0.8, 0.8, 0.4})
    
    -- Spawn small organic pods as minions
    local minionCount = boss.phase == 2 and 3 or 2
    
    for i = 1, minionCount do
        local minion = {
            x = boss.x + boss.width/2 + math.random(-100, 100),
            y = boss.y + boss.height,
            width = 30,
            height = 30,
            vy = 100,
            vx = math.random(-50, 50),
            health = 1,
            maxHealth = 1,
            type = "organicminion",
            shootTimer = 0
        }
        table.insert(aliens, minion)
    end
end

function hivemindPsychicWave()
    createPowerupText("PSYCHIC WAVE!", boss.x + boss.width/2, boss.y + boss.height + 20, {0.8, 0.4, 0.8})
    
    -- Create expanding psychic wave
    local wave = {
        x = boss.x + boss.width/2,
        y = boss.y + boss.height/2,
        width = 10,
        height = 10,
        radius = 10,
        maxRadius = 350,
        speed = 250,
        damage = 1,
        type = "psychicWave",
        color = {0.8, 0.4, 0.8, 0.5}
    }
    table.insert(alienLasers, wave)
end

function defeatBoss()
    -- Create massive explosion
    for i = 1, 10 do
        createExplosion(
            boss.x + math.random(0, boss.width),
            boss.y + math.random(0, boss.height),
            40
        )
    end
    
    -- Drop multiple powerups
    local powerupCount = boss.type == "annihilator" and 7 or 5
    for i = 1, powerupCount do
        spawnPowerup(
            boss.x + boss.width/2 + math.random(-50, 50),
            boss.y + boss.height/2
        )
    end
    
    -- Victory message
    createPowerupText("BOSS DEFEATED!", baseWidth/2, 200, {0, 1, 0})
    createPowerupText("ZONE COMPLETE!", baseWidth/2, 250, {1, 1, 0})
    
    -- Mark level as complete
    levelComplete = true
    boss = nil
    bossLasers = {}
    
    -- Strong victory rumble
    if gamepad and gamepad:isGamepad() then
        gamepad:setVibration(1, 1, 1)
    end
    
    -- Transition to level complete after 2 seconds
    levelCompleteTimer = 2
end

function drawBoss()
    if not boss then return end
    
    love.graphics.push()
    love.graphics.translate(boss.x + boss.width/2, boss.y + boss.height/2)
    
    -- Boss invulnerability flash
    if boss.invulnerable then
        local flash = math.sin(love.timer.getTime() * 20) * 0.5 + 0.5
        love.graphics.setColor(1, flash, flash)
    end
    
    if boss.type == "destroyer" then
        -- Level 1 Boss appearance
        -- Main body (dark metallic)
        love.graphics.setColor(0.3, 0.3, 0.4)
        love.graphics.rectangle("fill", -boss.width/2, -boss.height/2, boss.width, boss.height)
        
        -- Armor plating
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", -boss.width/2 + 20, -boss.height/2 + 10, boss.width - 40, 30)
        love.graphics.rectangle("fill", -boss.width/2 + 10, -boss.height/2 + 50, 30, boss.height - 100)
        love.graphics.rectangle("fill", boss.width/2 - 40, -boss.height/2 + 50, 30, boss.height - 100)
        
        -- Core (changes color with phase)
        local coreColor = boss.phase == 1 and {0, 0.8, 1} or {1, 0.2, 0.2}
        love.graphics.setColor(coreColor)
        local pulse = math.sin(love.timer.getTime() * 4) * 0.2 + 0.8
        love.graphics.circle("fill", 0, 0, 20 * pulse)
        
        -- Weapon ports
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle("fill", -60, 30, 8)
        love.graphics.circle("fill", -30, 40, 8)
        love.graphics.circle("fill", 0, 45, 8)
        love.graphics.circle("fill", 30, 40, 8)
        love.graphics.circle("fill", 60, 30, 8)
        
    elseif boss.type == "annihilator" then
        -- Level 2 Boss appearance - more menacing
        love.graphics.push()
        love.graphics.rotate(boss.rotationAngle * 0.1) -- Slight rotation
        
        -- Main body (dark purple metallic)
        love.graphics.setColor(0.4, 0.2, 0.5)
        love.graphics.polygon("fill",
            -boss.width/2, -boss.height/3,
            -boss.width/3, -boss.height/2,
            boss.width/3, -boss.height/2,
            boss.width/2, -boss.height/3,
            boss.width/2, boss.height/3,
            boss.width/3, boss.height/2,
            -boss.width/3, boss.height/2,
            -boss.width/2, boss.height/3
        )
        
        -- Shield effect
        if boss.shieldActive and boss.shieldHealth > 0 then
            local shieldAlpha = 0.3 + math.sin(love.timer.getTime() * 3) * 0.1
            love.graphics.setColor(0, 1, 1, shieldAlpha)
            love.graphics.circle("line", 0, 0, boss.width/2 + 20)
            love.graphics.circle("line", 0, 0, boss.width/2 + 15)
            
            -- Shield health indicator
            love.graphics.setColor(0, 1, 1, 0.8)
            local shieldPercent = boss.shieldHealth / 100
            love.graphics.arc("line", "open", 0, 0, boss.width/2 + 25, 
                -math.pi/2, -math.pi/2 + (math.pi * 2 * shieldPercent), 32)
        end
        
        -- Armor segments
        love.graphics.setColor(0.6, 0.4, 0.7)
        local segments = 8
        for i = 1, segments do
            local angle = (i / segments) * math.pi * 2
            local x = math.cos(angle) * boss.width/3
            local y = math.sin(angle) * boss.height/3
            love.graphics.polygon("fill",
                x - 20, y - 10,
                x + 20, y - 10,
                x + 15, y + 10,
                x - 15, y + 10
            )
        end
        
        -- Core (pulsing purple/red)
        local coreColor = boss.phase == 1 and {0.8, 0.2, 0.8} or {1, 0, 0.5}
        love.graphics.setColor(coreColor)
        local pulse = math.sin(love.timer.getTime() * 5) * 0.3 + 0.7
        love.graphics.circle("fill", 0, 0, 30 * pulse)
        
        -- Energy rings
        love.graphics.setColor(1, 0, 1, 0.5)
        love.graphics.circle("line", 0, 0, 40 + math.sin(love.timer.getTime() * 2) * 5)
        love.graphics.circle("line", 0, 0, 50 + math.cos(love.timer.getTime() * 3) * 5)
        
        -- Weapon arrays
        love.graphics.setColor(1, 0, 0.5)
        for i = 1, 8 do
            local angle = (i / 8) * math.pi * 2 + boss.rotationAngle
            local wx = math.cos(angle) * (boss.width/2 - 20)
            local wy = math.sin(angle) * (boss.height/2 - 20)
            love.graphics.circle("fill", wx, wy, 6)
        end
        
        love.graphics.pop()
    elseif boss.type == "frosttitan" then
        -- Level 3 Boss - Frost Titan (mechanical ice spider)
        -- Main body (icy blue metallic)
        love.graphics.setColor(0.5, 0.7, 0.9)
        love.graphics.circle("fill", 0, 0, boss.width/3)
        
        -- Ice armor plating
        love.graphics.setColor(0.7, 0.8, 0.95)
        local plates = 8
        for i = 1, plates do
            local angle = (i / plates) * math.pi * 2
            local x = math.cos(angle) * boss.width/4
            local y = math.sin(angle) * boss.height/4
            love.graphics.polygon("fill",
                x - 15, y - 10,
                x + 15, y - 10,
                x + 10, y + 10,
                x - 10, y + 10
            )
        end
        
        -- Draw legs
        love.graphics.setColor(0.4, 0.6, 0.8)
        for i, leg in ipairs(boss.legs) do
            local legAngle = leg.angle
            local legLength = 80
            local segmentLength = legLength / 2
            
            -- First segment
            local x1 = math.cos(legAngle) * boss.width/3
            local y1 = math.sin(legAngle) * boss.height/3
            local x2 = x1 + math.cos(legAngle + (leg.raised and -0.5 or 0.5)) * segmentLength
            local y2 = y1 + math.sin(legAngle + (leg.raised and -0.5 or 0.5)) * segmentLength
            
            love.graphics.setLineWidth(8)
            love.graphics.line(x1, y1, x2, y2)
            
            -- Second segment
            local x3 = x2 + math.cos(legAngle + (leg.raised and 0.5 or 1)) * segmentLength
            local y3 = y2 + math.sin(legAngle + (leg.raised and 0.5 or 1)) * segmentLength
            love.graphics.line(x2, y2, x3, y3)
            
            -- Leg tip
            love.graphics.setColor(0.3, 0.5, 0.7)
            love.graphics.circle("fill", x3, y3, 5)
            love.graphics.setColor(0.4, 0.6, 0.8)
        end
        love.graphics.setLineWidth(1)
        
        -- Core (icy blue pulsing)
        local coreColor = boss.phase == 1 and {0.3, 0.6, 1} or {0, 0.8, 1}
        love.graphics.setColor(coreColor)
        local pulse = math.sin(love.timer.getTime() * 3) * 0.2 + 0.8
        love.graphics.circle("fill", 0, 0, 25 * pulse)
        
        -- Ice crystal formations
        love.graphics.setColor(0.8, 0.9, 1, 0.7)
        for i = 1, 6 do
            local angle = (i / 6) * math.pi * 2 + love.timer.getTime() * 0.2
            local dist = 40 + math.sin(love.timer.getTime() * 2 + i) * 10
            local cx = math.cos(angle) * dist
            local cy = math.sin(angle) * dist
            love.graphics.polygon("fill",
                cx, cy - 10,
                cx + 5, cy,
                cx, cy + 10,
                cx - 5, cy
            )
        end
        
        -- Frost aura
        love.graphics.setColor(0.5, 0.8, 1, 0.3)
        love.graphics.circle("line", 0, 0, boss.width/2 + 10)
        love.graphics.circle("line", 0, 0, boss.width/2 + 20)
    elseif boss.type == "hivemind" then
        -- Level 4 Boss - Organic hivemind
        -- Main organic body
        love.graphics.setColor(0.4, 0.6, 0.4)
        love.graphics.ellipse("fill", 0, 0, boss.width/2, boss.height/2)
        
        -- Pulsing organic tissue
        local pulse = math.sin(love.timer.getTime() * 2) * 0.1 + 0.9
        love.graphics.setColor(0.5, 0.7, 0.5, pulse)
        love.graphics.ellipse("fill", 0, 0, boss.width/2.5, boss.height/2.5)
        
        -- Tentacles
        if boss.tentacles then
            love.graphics.setColor(0.3, 0.5, 0.3)
            for i, tentacle in ipairs(boss.tentacles) do
                local baseX = math.cos(tentacle.angle) * boss.width/3
                local baseY = math.sin(tentacle.angle) * boss.height/3
                
                -- Draw tentacle segments
                love.graphics.setLineWidth(15)
                for j = 1, 5 do
                    local segmentAngle = tentacle.angle + math.sin(love.timer.getTime() * 2 + i + j * 0.5) * 0.3
                    local segX = baseX + math.cos(segmentAngle) * j * 20
                    local segY = baseY + math.sin(segmentAngle) * j * 20
                    love.graphics.circle("fill", segX, segY, 15 - j * 2)
                end
                love.graphics.setLineWidth(1)
            end
        end
        
        -- Eyes/nodes
        love.graphics.setColor(0.8, 0.2, 0.2)
        for i = 1, 6 do
            local angle = (i / 6) * math.pi * 2 + love.timer.getTime() * 0.3
            local eyeX = math.cos(angle) * boss.width/4
            local eyeY = math.sin(angle) * boss.height/4
            love.graphics.circle("fill", eyeX, eyeY, 8)
            
            -- Eye glow
            love.graphics.setColor(1, 0.4, 0.4, 0.5)
            love.graphics.circle("fill", eyeX, eyeY, 12)
        end
        
        -- Central core
        love.graphics.setColor(0.6, 0.9, 0.6)
        love.graphics.circle("fill", 0, 0, 20)
        love.graphics.setColor(0.8, 1, 0.8, 0.5)
        love.graphics.circle("fill", 0, 0, 25)
    end
    
    -- Engine glow (only for flying bosses)
    if boss.type ~= "frosttitan" then
        love.graphics.setColor(1, 0.5, 0, 0.8)
        local enginePositions = boss.type == "destroyer" and 
            {{-80, -boss.height/2 - 10}, {-40, -boss.height/2 - 10}, {20, -boss.height/2 - 10}, {60, -boss.height/2 - 10}} or
            {{-100, -boss.height/2 - 10}, {-50, -boss.height/2 - 10}, {0, -boss.height/2 - 10}, {50, -boss.height/2 - 10}, {100, -boss.height/2 - 10}}
        
        for _, pos in ipairs(enginePositions) do
            love.graphics.rectangle("fill", pos[1], pos[2], 20, 15)
        end
    end
    
    -- Boss health bar
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", -boss.width/2, boss.height/2 + 10, boss.width, 10)
    
    -- Health fill
    local healthPercent = boss.health / boss.maxHealth
    if healthPercent > 0.5 then
        love.graphics.setColor(0, 1, 0)
    elseif healthPercent > 0.25 then
        love.graphics.setColor(1, 1, 0)
    else
        love.graphics.setColor(1, 0, 0)
    end
    love.graphics.rectangle("fill", -boss.width/2, boss.height/2 + 10, boss.width * healthPercent, 10)
    
    -- Health bar border
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", -boss.width/2, boss.height/2 + 10, boss.width, 10)
    
    love.graphics.pop()
    
    -- Boss name
    local nameColor = {1, 0, 0} -- default red
    local bossName = "BOSS"
    if boss.type == "destroyer" then
        nameColor = {1, 0, 0}
        bossName = "DESTROYER"
    elseif boss.type == "annihilator" then
        nameColor = {1, 0, 1}
        bossName = "ANNIHILATOR"
    elseif boss.type == "frosttitan" then
        nameColor = {0.5, 0.8, 1}
        bossName = "FROST TITAN"
    elseif boss.type == "hivemind" then
        nameColor = {0.5, 1, 0.5}
        bossName = "HIVEMIND"
    end
    love.graphics.setColor(nameColor)
    love.graphics.setFont(smallFont)
    love.graphics.printf(bossName, boss.x, boss.y - 30, boss.width, "center")
    
    -- Draw beam sweep for Annihilator
    if boss.type == "annihilator" and boss.beamActive then
        local beamX = boss.x + boss.width/2
        local beamY = boss.y + boss.height
        local beamEndX = beamX + math.cos(boss.beamAngle) * 1000
        local beamEndY = beamY + math.sin(boss.beamAngle) * 1000
        
        -- Beam warning/charging effect
        local chargeAlpha = math.sin(love.timer.getTime() * 10) * 0.3 + 0.7
        love.graphics.setColor(1, 0, 1, chargeAlpha * 0.3)
        love.graphics.setLineWidth(20)
        love.graphics.line(beamX, beamY, beamEndX, beamEndY)
        
        -- Main beam
        love.graphics.setColor(1, 0, 0.8, chargeAlpha)
        love.graphics.setLineWidth(10)
        love.graphics.line(beamX, beamY, beamEndX, beamEndY)
        
        -- Core beam
        love.graphics.setColor(1, 0.5, 1, 1)
        love.graphics.setLineWidth(4)
        love.graphics.line(beamX, beamY, beamEndX, beamEndY)
        
        -- Beam impact particles
        for i = 1, 5 do
            local particlePos = i / 5
            local px = beamX + (beamEndX - beamX) * particlePos
            local py = beamY + (beamEndY - beamY) * particlePos
            love.graphics.setColor(1, 0, 1, math.random() * 0.5 + 0.5)
            love.graphics.circle("fill", px + math.random(-10, 10), py + math.random(-10, 10), math.random(2, 5))
        end
        
        love.graphics.setLineWidth(1)
    end
end

-- Reset game function
function resetGame()
    score = 0
    lives = 3
    nextLifeScore = 5000
    invulnerableTime = 0
    currentLevel = 1
    levelComplete = false
    boss = nil
    bossSpawned = false
    bossWarningTime = 0
    bossLasers = {}
    bossAttackPattern = 1
    bossAttackTimer = 0
    levelCompleteTimer = 0
    asteroids = {}
    aliens = {}
    alienLasers = {}
    lasers = {}
    explosions = {}
    powerups = {}
    powerupTexts = {}
    asteroidTimer = 0
    alienTimer = 0
    asteroidSpawnTime = 2.5
    alienSpawnTime = 4.0
    laserCooldown = 0
    player.x = baseWidth/2 - 14
    player.y = 500
    totalAsteroidsDestroyed = 0
    totalShotsFired = 0
    currentCombo = 0
    maxCombo = 0
    -- Reset active powerups
    activePowerups = {
        tripleShot = 0,
        rapidFire = 0,
        shield = 0,
        slowTime = 0,
        homing = 0,
        pierce = 0,
        freeze = 0,
        vampire = 0
    }
    -- Reset background color
    backgroundColor = {0.1, 0.1, 0.2}
    powerupChance = 15
    -- Recreate starfield for variety
    stars = {}
    createStarfield()
    
    -- Restart music if it exists
    if sounds.music and not sounds.music:isPlaying() then
        sounds.music:play()
    end
end

-- Function to handle losing a life
function loseLife()
    -- Check for god mode
    if godMode then
        invulnerableTime = 2  -- Still give invulnerability frames
        createPowerupText("GOD MODE ACTIVE", player.x + player.width/2, player.y - 20, {1, 1, 0})
        return
    end
    
    lives = lives - 1
    currentCombo = 0 -- Reset combo
    
    if lives <= 0 then
        -- Game over
        gameState = "gameover"
        levelAtDeath = currentLevel -- Store the level where player died
        gameOverSelection = 1 -- Reset selection to "Restart Level"
        
        -- Save progress before game over
        if currentSaveSlot then
            saveToSlot(currentSaveSlot)
        end
        
        if sounds.gameover then
            sounds.gameover:setVolume(sfxVolume * masterVolume)
            sounds.gameover:play()
        end
        -- Strong rumble on game over
        if gamepad and gamepad:isGamepad() then
            gamepad:setVibration(1, 1, 0.5)
        end
    else
        -- Still have lives left
        createPowerupText("LIFE LOST!", player.x + player.width/2, player.y - 20, {1, 0, 0})
        
        -- Make player invulnerable for 2 seconds
        invulnerableTime = 2.0
        
        -- Clear nearby threats
        clearNearbyThreats()
        
        -- Play a hit sound (use explosion at lower volume)
        if sounds.explosion then
            local hitSound = sounds.explosion:clone()
            hitSound:setVolume(0.3 * sfxVolume * masterVolume)
            hitSound:setPitch(0.8)
            hitSound:play()
        end
        
        -- Medium rumble for life lost
        if gamepad and gamepad:isGamepad() then
            gamepad:setVibration(0.7, 0.7, 0.4)
        end
    end
end

-- Function to reload all audio sources (for audio device switching)
function reloadAudioSystem()
    -- Store current playing states
    local musicWasPlaying = sounds.music and sounds.music:isPlaying()
    local menuMusicWasPlaying = sounds.menuMusic and sounds.menuMusic:isPlaying()
    
    -- Stop all sounds
    love.audio.stop()
    
    -- Reload all sound effects
    if love.filesystem.getInfo("laser.wav") then
        sounds.laser = love.audio.newSource("laser.wav", "static")
        sounds.laser:setVolume(0.3 * sfxVolume * masterVolume)
    end
    
    if love.filesystem.getInfo("explosion.wav") then
        sounds.explosion = love.audio.newSource("explosion.wav", "static")
        sounds.explosion:setVolume(0.5 * sfxVolume * masterVolume)
    end
    
    if love.filesystem.getInfo("gameover.ogg") then
        sounds.gameover = love.audio.newSource("gameover.ogg", "static")
        sounds.gameover:setVolume(sfxVolume * masterVolume)
    end
    
    if love.filesystem.getInfo("powerup.wav") then
        sounds.powerup = love.audio.newSource("powerup.wav", "static")
        sounds.powerup:setVolume(0.4 * sfxVolume * masterVolume)
    end
    
    if love.filesystem.getInfo("menu.flac") then
        sounds.menu = love.audio.newSource("menu.flac", "static")
        sounds.menu:setVolume(0.3 * sfxVolume * masterVolume)
    end
    
    -- Reload music
    if love.filesystem.getInfo("background.mp3") then
        sounds.music = love.audio.newSource("background.mp3", "stream")
        sounds.music:setLooping(true)
        sounds.music:setVolume(musicVolume * masterVolume)
        if musicWasPlaying then
            sounds.music:play()
        end
    end
    
    if love.filesystem.getInfo("menu.flac") then
        sounds.menuMusic = love.audio.newSource("menu.flac", "stream")
        sounds.menuMusic:setLooping(true)
        sounds.menuMusic:setVolume(musicVolume * masterVolume * 0.8)
        if menuMusicWasPlaying then
            sounds.menuMusic:play()
        end
    end
    
    -- Show notification about limitation
    createPowerupText("Audio Refreshed", baseWidth/2, baseHeight/2 - 20, {1, 1, 0})
    createPowerupText("Restart game for device change", baseWidth/2, baseHeight/2 + 20, {1, 0.7, 0})
end

-- Start next level function
function startNextLevel()
    currentLevel = currentLevel + 1
    
    -- Save progress to current slot
    if currentSaveSlot then
        saveToSlot(currentSaveSlot)
    end
    
    gameState = "playing"
    levelComplete = false
    boss = nil
    bossSpawned = false
    bossWarningTime = 0
    bossLasers = {}
    asteroids = {}
    aliens = {}
    alienLasers = {}
    lasers = {}
    explosions = {}
    powerups = {}
    powerupTexts = {}
    asteroidTimer = 0
    alienTimer = 0
    levelCompleteTimer = 0
    
    -- Reset enemy counter and adjust for new level
    enemiesDefeated = 0
    
    -- Set enemies needed for boss based on level
    if currentLevel == 1 then
        enemiesForBoss = 150
    elseif currentLevel == 2 then
        enemiesForBoss = 200
        asteroidSpawnTime = 2.0 -- Faster than level 1
        alienSpawnTime = 3.0 -- More aliens
        powerupChance = 12 -- Slightly less powerups
        -- Change background color for level 2
        backgroundColor = {0.15, 0.05, 0.2} -- Purple tint
    elseif currentLevel == 3 then
        enemiesForBoss = 250
    elseif currentLevel == 4 then
        enemiesForBoss = 300
    else
        enemiesForBoss = 400 -- Level 5+
    end
    
    -- Reset player position but keep powerups active
    player.x = baseWidth/2 - 14
    player.y = 500
    invulnerableTime = 2.0 -- Brief invulnerability at start
    
    -- Zone announcement
    createPowerupText("ZONE " .. currentLevel, baseWidth/2, 200, {0, 1, 1})
    createPowerupText("GET READY!", baseWidth/2, 250, {1, 1, 0})
    
    -- Bonus life for reaching new zone
    if lives < maxLives then
        lives = lives + 1
        createPowerupText("BONUS LIFE!", baseWidth/2, 300, {0, 1, 0})
    end
    
    -- Play powerup sound for new level
    if sounds.powerup then
        local levelSound = sounds.powerup:clone()
        levelSound:setVolume(0.5 * sfxVolume * masterVolume)
        levelSound:play()
    end
end
function clearNearbyThreats()
    local clearRadius = 150
    
    -- Clear nearby asteroids
    for i = #asteroids, 1, -1 do
        local asteroid = asteroids[i]
        local dx = (asteroid.x + asteroid.width/2) - (player.x + player.width/2)
        local dy = (asteroid.y + asteroid.height/2) - (player.y + player.height/2)
        local distance = math.sqrt(dx*dx + dy*dy)
        
        if distance < clearRadius then
            createExplosion(
                asteroid.x + asteroid.width/2,
                asteroid.y + asteroid.height/2,
                asteroid.width/2
            )
            table.remove(asteroids, i)
        end
    end
    
    -- Clear nearby aliens
    for i = #aliens, 1, -1 do
        local alien = aliens[i]
        local dx = (alien.x + alien.width/2) - (player.x + player.width/2)
        local dy = (alien.y + alien.height/2) - (player.y + player.height/2)
        local distance = math.sqrt(dx*dx + dy*dy)
        
        if distance < clearRadius then
            createExplosion(
                alien.x + alien.width/2,
                alien.y + alien.height/2,
                alien.width/2
            )
            table.remove(aliens, i)
        end
    end
    
    -- Clear all alien lasers
    alienLasers = {}
    
    -- Clear all boss lasers if boss fight
    if boss then
        bossLasers = {}
    end
end

-- Star functions
function createStarfield()
    stars = {}
    for i = 1, 200 do
        local star = {
            x = math.random(0, baseWidth),
            y = math.random(0, baseHeight),
            speed = math.random(20, 100),
            brightness = math.random(),
            size = math.random(1, 2)
        }
        table.insert(stars, star)
    end
end

function updateStars(dt)
    for _, star in ipairs(stars) do
        star.y = star.y + star.speed * dt
        if star.y > baseHeight then
            star.y = 0
            star.x = math.random(0, baseWidth)
        end
    end
end

function drawStarsExtended(x, width)
    for _, star in ipairs(stars) do
        love.graphics.setColor(1, 1, 1, star.brightness * 0.7)
        love.graphics.circle("fill", x + (star.x / baseWidth) * width, star.y, star.size)
    end
end

function drawSidePanels(x, width)
    -- Draw decorative side panels for ultrawide displays
    love.graphics.setColor(0.1, 0.1, 0.2, 0.8)
    love.graphics.rectangle("fill", x, 0, 50, baseHeight)
    love.graphics.rectangle("fill", x + width - 50, 0, 50, baseHeight)
    
    -- Draw panel borders
    love.graphics.setColor(0.3, 0.3, 0.5, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + 50, 0, x + 50, baseHeight)
    love.graphics.line(x + width - 50, 0, x + width - 50, baseHeight)
    
    -- Draw decorative elements
    love.graphics.setColor(0.4, 0.4, 0.6, 0.5)
    for i = 0, 10 do
        local y = i * baseHeight / 10
        love.graphics.line(x, y, x + 50, y)
        love.graphics.line(x + width - 50, y, x + width, y)
    end
    
    love.graphics.setLineWidth(1)
end

-- Input handling functions
function love.keypressed(key)
    -- Developer cheats (F1-F8 keys)
    if key == "f1" then
        -- Toggle cheat mode
        cheatsEnabled = not cheatsEnabled
        if cheatsEnabled then
            createPowerupText("CHEATS ENABLED", baseWidth/2, baseHeight/2, {1, 1, 0})
        else
            createPowerupText("CHEATS DISABLED", baseWidth/2, baseHeight/2, {1, 0, 0})
        end
        return
    end
    
    -- Only process other cheats if cheats are enabled
    if cheatsEnabled then
        if key == "f2" then
            -- God mode (infinite lives)
            godMode = not godMode
            if godMode then
                lives = 999
                createPowerupText("GOD MODE ON", baseWidth/2, baseHeight/2, {0, 1, 0})
            else
                lives = 3
                createPowerupText("GOD MODE OFF", baseWidth/2, baseHeight/2, {1, 0, 0})
            end
        elseif key == "f3" then
            -- Infinite powerups
            infinitePowerups = not infinitePowerups
            if infinitePowerups then
                -- Activate all powerups
                activePowerups.tripleShot = 9999
                activePowerups.rapidFire = 9999
                activePowerups.shield = 9999
                activePowerups.slowTime = 9999
                activePowerups.homing = 9999
                activePowerups.pierce = 9999
                activePowerups.freeze = 9999
                activePowerups.vampire = 9999
                createPowerupText("INFINITE POWERUPS ON", baseWidth/2, baseHeight/2, {0, 1, 1})
            else
                -- Reset powerups
                for k, v in pairs(activePowerups) do
                    activePowerups[k] = 0
                end
                createPowerupText("INFINITE POWERUPS OFF", baseWidth/2, baseHeight/2, {1, 0, 0})
            end
        elseif key == "f4" then
            -- Skip to next level
            if gameState == "playing" then
                currentLevel = currentLevel + 1
                score = score + 5000
                enemiesDefeated = 0
                boss = nil
                bossSpawned = false
                asteroids = {}
                aliens = {}
                alienLasers = {}
                bossLasers = {}
                createPowerupText("SKIPPED TO LEVEL " .. currentLevel, baseWidth/2, baseHeight/2, {1, 1, 0})
            end
        elseif key == "f5" then
            -- Spawn boss immediately
            if gameState == "playing" and not boss then
                enemiesDefeated = enemiesForBoss
                createPowerupText("SPAWNING BOSS", baseWidth/2, baseHeight/2, {1, 0, 1})
            end
        elseif key == "f6" then
            -- Toggle hitboxes
            showHitboxes = not showHitboxes
            createPowerupText(showHitboxes and "HITBOXES ON" or "HITBOXES OFF", baseWidth/2, baseHeight/2, {1, 1, 0})
        elseif key == "f7" then
            -- Toggle FPS display
            showFPS = not showFPS
            createPowerupText(showFPS and "FPS ON" or "FPS OFF", baseWidth/2, baseHeight/2, {1, 1, 0})
        elseif key == "f8" then
            -- Toggle debug mode (shows extra info)
            debugMode = not debugMode
            createPowerupText(debugMode and "DEBUG MODE ON" or "DEBUG MODE OFF", baseWidth/2, baseHeight/2, {1, 1, 0})
        elseif key == "1" then
            -- Give extra life
            if gameState == "playing" then
                lives = math.min(lives + 1, 99)
                createPowerupText("+1 LIFE", baseWidth/2, baseHeight/2, {0, 1, 0})
            end
        elseif key == "2" then
            -- Clear screen of enemies
            if gameState == "playing" then
                asteroids = {}
                aliens = {}
                alienLasers = {}
                bossLasers = {}
                createPowerupText("SCREEN CLEARED", baseWidth/2, baseHeight/2, {0, 1, 1})
            end
        elseif key == "3" then
            -- Max score
            if gameState == "playing" then
                score = 999999
                createPowerupText("MAX SCORE", baseWidth/2, baseHeight/2, {1, 1, 0})
            end
        end
    end
    
    -- Global hotkeys
    if key == "f9" then
        reloadAudioSystem()
        return
    end
    
    if gameState == "menu" then
        if menuState == "main" then
            -- Main menu navigation
            if key == "up" then
                menuSelection = menuSelection - 1
                if menuSelection < 1 then menuSelection = 4 end
                playMenuSound()
            elseif key == "down" then
                menuSelection = menuSelection + 1
                if menuSelection > 4 then menuSelection = 1 end
                playMenuSound()
            elseif key == "return" or key == "space" then
                if menuSelection == 1 then
                    -- Play - go to save slots
                    menuState = "saves"
                    selectedSaveSlot = 1
                    playMenuSound()
                elseif menuSelection == 2 then
                    -- Level Select
                    menuState = "levelselect"
                    selectedLevel = 1
                    playMenuSound()
                elseif menuSelection == 3 then
                    -- Options
                    gameState = "options"
                    playMenuSound()
                elseif menuSelection == 4 then
                    -- Quit
                    love.event.quit()
                end
            end
        elseif menuState == "saves" then
            -- Save slot menu navigation
            if key == "up" then
                selectedSaveSlot = selectedSaveSlot - 1
                if selectedSaveSlot < 1 then selectedSaveSlot = 4 end
                playMenuSound()
            elseif key == "down" then
                selectedSaveSlot = selectedSaveSlot + 1
                if selectedSaveSlot > 4 then selectedSaveSlot = 1 end
                playMenuSound()
            elseif key == "return" or key == "space" then
                if selectedSaveSlot == 4 then
                    -- Back
                    menuState = "main"
                    playMenuSound()
                else
                    -- Load or create save
                    currentSaveSlot = selectedSaveSlot
                    if saveSlots[selectedSaveSlot] then
                        -- Load existing save
                        if loadFromSlot(selectedSaveSlot) then
                            startGame(currentLevel)  -- Use loaded level
                        end
                    else
                        -- Create new save
                        currentLevel = 1
                        lives = 3
                        startGame(1)  -- Start at level 1 for new save
                    end
                end
            elseif key == "delete" or key == "backspace" then
                if selectedSaveSlot < 4 and saveSlots[selectedSaveSlot] then
                    deleteSaveSlot(selectedSaveSlot)
                    playMenuSound()
                end
            elseif key == "escape" then
                menuState = "main"
                playMenuSound()
            end
        elseif menuState == "levelselect" then
            -- Level select navigation
            local maxUnlockedLevel = 1
            for i = 1, 3 do
                if saveSlots[i] then
                    maxUnlockedLevel = math.max(maxUnlockedLevel, saveSlots[i].highestLevel)
                end
            end
            
            if key == "left" then
                if selectedLevel > 1 and selectedLevel <= 5 then
                    selectedLevel = selectedLevel - 1
                    playMenuSound()
                elseif selectedLevel == 6 then
                    selectedLevel = 5
                    playMenuSound()
                end
            elseif key == "right" then
                if selectedLevel < 5 then
                    selectedLevel = selectedLevel + 1
                    playMenuSound()
                elseif selectedLevel == 5 then
                    selectedLevel = 6 -- Jump to back
                    playMenuSound()
                end
            elseif key == "up" then
                if selectedLevel == 6 then
                    selectedLevel = 3 -- Jump to middle of level grid
                    playMenuSound()
                end
            elseif key == "down" then
                if selectedLevel <= 5 then
                    selectedLevel = 6 -- Jump to back
                    playMenuSound()
                end
            elseif key == "return" or key == "space" then
                if selectedLevel == 6 then
                    -- Back
                    menuState = "main"
                    playMenuSound()
                elseif selectedLevel <= maxUnlockedLevel then
                    -- Start selected level
                    lives = 3
                    startGame(selectedLevel)  -- Pass the selected level
                end
            elseif key == "escape" then
                menuState = "main"
                playMenuSound()
            end
        end
    elseif gameState == "options" then
        if key == "up" then
            optionsSelection = optionsSelection - 1
            if optionsSelection < 1 then optionsSelection = 6 end
            playMenuSound()
        elseif key == "down" then
            optionsSelection = optionsSelection + 1
            if optionsSelection > 6 then optionsSelection = 1 end
            playMenuSound()
        elseif key == "left" then
            handleOptionsLeft()
        elseif key == "right" then
            handleOptionsRight()
        elseif key == "return" or key == "space" then
            if optionsSelection == 6 then
                gameState = "menu"
                playMenuSound()
            end
        elseif key == "escape" then
            gameState = "menu"
            playMenuSound()
        end
    elseif gameState == "playing" then
        if key == "escape" then
            gameState = "paused"
            playMenuSound()
        end
    elseif gameState == "paused" then
        if key == "up" or key == "down" then
            pauseSelection = pauseSelection == 1 and 2 or 1
            playMenuSound()
        elseif key == "return" or key == "space" then
            if pauseSelection == 1 then
                gameState = "playing"
                playMenuSound()
            else
                -- Return to menu
                gameState = "menu"
                menuState = "main"  -- Reset to main menu
                menuSelection = 1
                
                -- Save progress before returning to menu
                if currentSaveSlot then
                    saveToSlot(currentSaveSlot)
                end
                
                stopAllSounds()
                if sounds.menuMusic then
                    sounds.menuMusic:play()
                end
            end
        elseif key == "escape" then
            gameState = "playing"
            playMenuSound()
        end
    elseif gameState == "gameover" then
        if key == "up" then
            gameOverSelection = gameOverSelection - 1
            if gameOverSelection < 1 then gameOverSelection = 2 end
            playMenuSound()
        elseif key == "down" then
            gameOverSelection = gameOverSelection + 1
            if gameOverSelection > 2 then gameOverSelection = 1 end
            playMenuSound()
        elseif key == "return" or key == "space" then
            if gameOverSelection == 1 then
                -- Restart at the level where they died
                startGame(levelAtDeath)
            else
                -- Return to main menu
                gameState = "menu"
                menuState = "main"
                stopAllSounds()
                if sounds.menuMusic then
                    sounds.menuMusic:play()
                end
            end
        elseif key == "escape" then
            -- Quick return to menu
            gameState = "menu"
            menuState = "main"
            stopAllSounds()
            if sounds.menuMusic then
                sounds.menuMusic:play()
            end
        end
    elseif gameState == "levelcomplete" then
        if key == "return" or key == "space" then
            nextLevel()
        end
    end
end

function love.keyreleased(key)
    -- Currently no key release handling needed
end

function love.gamepadpressed(joystick, button)
    if button == "a" then
        -- Simulate Enter key
        love.keypressed("return")
    elseif button == "b" then
        -- Simulate Escape key
        love.keypressed("escape")
    elseif button == "dpup" then
        love.keypressed("up")
    elseif button == "dpdown" then
        love.keypressed("down")
    elseif button == "dpleft" then
        love.keypressed("left")
    elseif button == "dpright" then
        love.keypressed("right")
    elseif button == "start" then
        if gameState == "playing" then
            gameState = "paused"
            playMenuSound()
        elseif gameState == "paused" then
            gameState = "playing"
            playMenuSound()
        end
    end
end

function love.gamepadreleased(joystick, button)
    -- Currently no gamepad release handling needed
end

-- Helper functions for options menu
function handleOptionsLeft()
    if optionsSelection == 1 then
        -- Previous resolution
        currentResolution = currentResolution - 1
        if currentResolution < 1 then currentResolution = #resolutions end
        if displayMode == "windowed" then
            love.window.setMode(resolutions[currentResolution].width, resolutions[currentResolution].height, {resizable = true})
        end
        playMenuSound()
    elseif optionsSelection == 2 then
        -- Cycle display mode left
        if displayMode == "windowed" then
            displayMode = "fullscreen"
        else
            displayMode = "windowed"
        end
        applyDisplayMode()
        playMenuSound()
    elseif optionsSelection == 3 then
        -- Decrease master volume
        masterVolume = math.max(0, masterVolume - 0.1)
        updateAllVolumes()
        playMenuSound()
    elseif optionsSelection == 4 then
        -- Decrease SFX volume
        sfxVolume = math.max(0, sfxVolume - 0.1)
        updateAllVolumes()
        playMenuSound()
    elseif optionsSelection == 5 then
        -- Decrease music volume
        musicVolume = math.max(0, musicVolume - 0.1)
        updateAllVolumes()
        playMenuSound()
    end
end

function handleOptionsRight()
    if optionsSelection == 1 then
        -- Next resolution
        currentResolution = currentResolution + 1
        if currentResolution > #resolutions then currentResolution = 1 end
        if displayMode == "windowed" then
            love.window.setMode(resolutions[currentResolution].width, resolutions[currentResolution].height, {resizable = true})
        end
        playMenuSound()
    elseif optionsSelection == 2 then
        -- Cycle display mode right
        if displayMode == "windowed" then
            displayMode = "fullscreen"
        else
            displayMode = "windowed"
        end
        applyDisplayMode()
        playMenuSound()
    elseif optionsSelection == 3 then
        -- Increase master volume
        masterVolume = math.min(1, masterVolume + 0.1)
        updateAllVolumes()
        playMenuSound()
    elseif optionsSelection == 4 then
        -- Increase SFX volume
        sfxVolume = math.min(1, sfxVolume + 0.1)
        updateAllVolumes()
        playMenuSound()
    elseif optionsSelection == 5 then
        -- Increase music volume
        musicVolume = math.min(1, musicVolume + 0.1)
        updateAllVolumes()
        playMenuSound()
    end
end

-- Sound helper functions
function playMenuSound()
    if sounds.menu then
        sounds.menu:stop()
        sounds.menu:play()
    end
end

function stopAllSounds()
    if sounds.music then sounds.music:stop() end
    if sounds.menuMusic then sounds.menuMusic:stop() end
    if sounds.gameover then sounds.gameover:stop() end
end

function updateAllVolumes()
    if sounds.laser then sounds.laser:setVolume(0.3 * sfxVolume * masterVolume) end
    if sounds.explosion then sounds.explosion:setVolume(0.5 * sfxVolume * masterVolume) end
    if sounds.gameover then sounds.gameover:setVolume(sfxVolume * masterVolume) end
    if sounds.powerup then sounds.powerup:setVolume(0.4 * sfxVolume * masterVolume) end
    if sounds.menu then sounds.menu:setVolume(0.3 * sfxVolume * masterVolume) end
    if sounds.music then sounds.music:setVolume(musicVolume * masterVolume) end
    if sounds.menuMusic then sounds.menuMusic:setVolume(musicVolume * masterVolume) end
end

-- Display helper functions
function applyDisplayMode()
    local width, height = love.graphics.getDimensions()
    
    if displayMode == "fullscreen" then
        love.window.setFullscreen(true, "exclusive")
    else -- windowed
        love.window.setFullscreen(false)
        love.window.setMode(resolutions[currentResolution].width, resolutions[currentResolution].height, {resizable = true})
    end
    
    updateScaling()
end

function updateScaling()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    
    -- Calculate scale to maintain aspect ratio
    local scaleX = windowWidth / baseWidth
    local scaleY = windowHeight / baseHeight
    screenScale = math.min(scaleX, scaleY)
    
    -- Calculate offsets to center the game
    screenOffsetX = (windowWidth - baseWidth * screenScale) / 2
    screenOffsetY = (windowHeight - baseHeight * screenScale) / 2
end

-- Game state functions
function startGame(startLevel)
    gameState = "playing"
    enemiesDefeated = 0
    lives = 3
    currentLevel = startLevel or 1  -- Use provided level or default to 1
    levelComplete = false
    invulnerableTime = 0
    
    -- Set boss requirements based on starting level
    if currentLevel == 1 then
        enemiesForBoss = 150  -- Tripled from 50
    elseif currentLevel == 2 then
        enemiesForBoss = 200  -- More than tripled
    elseif currentLevel == 3 then
        enemiesForBoss = 250  -- More than tripled
    elseif currentLevel == 4 then
        enemiesForBoss = 300  -- More than tripled
    elseif currentLevel == 5 then
        enemiesForBoss = 400  -- Much harder
    else
        enemiesForBoss = 400 + (currentLevel - 5) * 50
    end
    
    -- Reset player position
    player.x = baseWidth/2 - player.width/2
    player.y = 500
    
    -- Clear all game objects
    asteroids = {}
    aliens = {}
    lasers = {}
    alienLasers = {}
    powerups = {}
    powerupTexts = {}
    explosions = {}
    iceGeysers = {} -- Clear ice geysers
    
    -- Reset powerups
    activePowerups = {
        tripleShot = 0,
        rapidFire = 0,
        shield = 0,
        slowTime = 0,
        homing = 0,
        pierce = 0,
        freeze = 0,
        vampire = 0
    }
    
    -- Reset boss
    boss = nil
    bossSpawned = false
    bossWarningTime = 0
    bossLasers = {}
    
    -- Reset timers
    asteroidTimer = 0
    alienTimer = 0
    laserCooldown = 0
    waveTimer = 0
    
    -- Set background color based on starting level
    if currentLevel <= 5 and levelBackgrounds then
        backgroundColor = levelBackgrounds[currentLevel]
    elseif levelBackgrounds then
        backgroundColor = levelBackgrounds[5] -- Default to solar for levels > 5
    end
    
    -- Set spawn rates based on level
    asteroidSpawnTime = 2.0 - (currentLevel - 1) * 0.3
    asteroidSpawnTime = math.max(0.8, asteroidSpawnTime)
    alienSpawnTime = 3.0 - (currentLevel - 1) * 0.4
    alienSpawnTime = math.max(1.2, alienSpawnTime)
    
    -- Stop menu music and start game music
    stopAllSounds()
    if sounds.music then
        sounds.music:play()
    end
end

function nextLevel()
    currentLevel = currentLevel + 1
    levelComplete = false
    levelCompleteTimer = 0
    
    -- Clear remaining enemies
    asteroids = {}
    aliens = {}
    alienLasers = {}
    
    -- Reset boss for next level
    boss = nil
    bossSpawned = false
    bossWarningTime = 0
    bossLasers = {}
    
    -- Reset enemy counters for next boss
    enemiesDefeated = 0
    
    -- Set boss requirements based on level
    if currentLevel == 2 then
        enemiesForBoss = 200
    elseif currentLevel == 3 then
        enemiesForBoss = 250
    elseif currentLevel == 4 then
        enemiesForBoss = 300
    elseif currentLevel == 5 then
        enemiesForBoss = 400
    else
        enemiesForBoss = 400 + (currentLevel - 5) * 50 -- Progressively harder
    end
    
    -- Reset spawn timers (IMPORTANT: Fix the 999999 issue from boss warning)
    asteroidSpawnTime = 2.0 - (currentLevel - 1) * 0.3 -- Faster spawning each level
    asteroidSpawnTime = math.max(0.8, asteroidSpawnTime) -- Minimum 0.8 seconds
    alienSpawnTime = 3.0 - (currentLevel - 1) * 0.4 -- Aliens spawn faster too
    alienSpawnTime = math.max(1.2, alienSpawnTime) -- Minimum 1.2 seconds
    
    -- Reset spawn timers to ensure enemies spawn
    asteroidTimer = 0
    alienTimer = 0
    
    -- Level-specific transitions and vehicle changes
    if currentLevel == 1 then
        -- Standard space fighter
        vehicleMode = "fighter"
        player.speed = 450
        gravity = 0
    elseif currentLevel == 2 then
        -- Transform to energy ship for nebula
        vehicleMode = "energyship"
        player.speed = 500  -- Faster to avoid energy clouds
        gravity = 0
        createPowerupText("ENTERING NEBULA FIELD", baseWidth/2, 100, {0.8, 0.5, 1})
    elseif currentLevel == 3 then
        -- Transform to tank for ice moon
        transformToTank()
        createPowerupText("ENTERING ICE MOON ATMOSPHERE", baseWidth/2, 100, {0.7, 0.9, 1})
    elseif currentLevel == 4 then
        -- Morphing ship for mothership interior
        vehicleMode = "morphship"
        gravity = 0
        player.y = baseHeight/2
        player.speed = 400  -- Slower in tight corridors
        createPowerupText("SWALLOWED BY MOTHERSHIP", baseWidth/2, 100, {0.5, 1, 0.5})
        
        -- Spawn initial doors
        for i = 1, 2 do
            spawnDoor()
            doors[i].y = -200 * i
        end
    elseif currentLevel == 5 then
        -- Heat-resistant solar ship
        vehicleMode = "solarship"
        player.speed = 550  -- Fast to escape solar flares
        gravity = 0
        createPowerupText("APPROACHING SOLAR CORONA", baseWidth/2, 100, {1, 0.5, 0})
        
        -- Create shade zones
        for i = 1, 3 do
            local zone = {
                x = math.random(100, baseWidth - 200),
                y = math.random(100, baseHeight - 200),
                width = 150,
                height = 150
            }
            table.insert(shadeZones, zone)
        end
    end
    
    gameState = "playing"
end

-- Spawn functions
function spawnAsteroid()
    local asteroidType = "normal"
    local rand = math.random()
    
    -- Different asteroid types based on level
    if currentLevel >= 2 then
        if rand < 0.25 then
            asteroidType = "metal"
        elseif rand < 0.35 then
            asteroidType = "large"
        end
    end
    if currentLevel >= 3 then
        if rand < 0.3 then
            asteroidType = "metal"
        elseif rand < 0.5 then
            asteroidType = "large"
        end
    end
    
    local asteroid = {
        x = math.random(0, baseWidth - 50),
        y = -50,
        width = 50,
        height = 50,
        speed = math.random(100 + currentLevel * 20, 200 + currentLevel * 30), -- Faster at higher levels
        type = asteroidType,
        health = 1,
        rotation = 0,
        rotationSpeed = math.random(-2, 2)
    }
    
    -- Adjust properties based on type
    if asteroidType == "large" then
        asteroid.width = 80
        asteroid.height = 80
        asteroid.health = 3
        asteroid.speed = math.random(80, 150)
        asteroid.canBreakApart = true
    elseif asteroidType == "metal" then
        asteroid.health = 2
        asteroid.speed = math.random(120, 220)
        asteroid.canBreakApart = false
    else
        asteroid.canBreakApart = true
    end
    
    table.insert(asteroids, asteroid)
end


function spawnBoss()
    boss = {
        x = baseWidth/2 - 100,
        y = -200,
        width = 200,
        height = 150,
        speed = 50,
        health = 50 + (currentLevel * 10),
        maxHealth = 50 + (currentLevel * 10),
        moveDirection = 1,
        shootTimer = 0,
        phase = 1,
        vx = 100,
        vy = 50,
        specialTimer = 0,
        invulnerableTimer = 0,
        invulnerable = false,
        type = "destroyer"  -- Default boss type
    }
    
    -- Set boss type based on specific level
    if currentLevel == 1 then
        boss.type = "destroyer"
    elseif currentLevel == 2 then
        boss.type = "annihilator"
        boss.rotationAngle = 0
        boss.shieldActive = false
        boss.shieldHealth = 100
        boss.beamActive = false
        boss.beamAngle = 0
        boss.beamDuration = 0
    elseif currentLevel == 3 then
        boss.type = "frosttitan"
        boss.y = -200  -- Start off screen like other bosses
        boss.targetY = groundY - 200  -- Where boss should end up
        boss.legs = {}
        for i = 1, 8 do
            boss.legs[i] = {angle = (i / 8) * math.pi * 2, raised = false}
        end
    elseif currentLevel == 4 then
        boss.type = "hivemind"
        boss.tentacles = {}
        for i = 1, 4 do
            boss.tentacles[i] = {
                angle = (i / 4) * math.pi * 2,
                length = 100,
                targetX = 0,
                targetY = 0
            }
        end
    elseif currentLevel == 5 then
        boss.type = "solaroverlord"
        boss.phases = 4
        boss.currentPhase = 1
        boss.solarFlareTimer = 0
    end
    
    bossSpawned = true
    bossWarningTime = 0
    
    -- Clear regular enemies when boss spawns
    asteroids = {}
    aliens = {}
    
    -- Clear all powerups on screen
    powerups = {}
    
    -- Clear all active powerups for increased difficulty
    if activePowerups.shield > 0 then
        createShieldBreakEffect(player.x + player.width/2, player.y + player.height/2)
    end
    
    activePowerups.tripleShot = 0
    activePowerups.rapidFire = 0
    activePowerups.shield = 0
    activePowerups.slowTime = 0
    activePowerups.homing = 0
    activePowerups.pierce = 0
    activePowerups.freeze = 0
    activePowerups.vampire = 0
    
    -- Visual feedback for powerup removal
    createPowerupText("POWERUPS DISABLED!", baseWidth/2, baseHeight/2 + 100, {1, 0, 0})
    
    -- Boss announcement
    if currentLevel == 1 then
        createPowerupText("ZONE 1 BOSS: DESTROYER", baseWidth/2, 100, {1, 0, 0})
    elseif currentLevel == 2 then
        createPowerupText("ZONE 2 BOSS: ANNIHILATOR", baseWidth/2, 100, {1, 0, 1})
    elseif currentLevel == 3 then
        createPowerupText("ZONE 3 BOSS: FROST TITAN", baseWidth/2, 100, {0.5, 0.8, 1})
    elseif currentLevel == 4 then
        createPowerupText("ZONE 4 BOSS: HIVEMIND", baseWidth/2, 100, {0.5, 1, 0.5})
    elseif currentLevel == 5 then
        createPowerupText("ZONE 5 BOSS: SOLAR OVERLORD", baseWidth/2, 100, {1, 0.5, 0})
    else
        -- For levels beyond 5, just show a generic boss
        createPowerupText("BOSS INCOMING!", baseWidth/2, 100, {1, 0, 0})
    end
    
    -- Play boss music
    if sounds.gameover then
        local bossSound = sounds.gameover:clone()
        bossSound:setVolume(0.3 * sfxVolume * masterVolume)
        bossSound:setPitch(0.5 - (math.min(currentLevel, 5) * 0.05)) -- Lower pitch for higher level bosses
        bossSound:play()
    end
end

-- Collision detection function
function checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function lineBoxCollision(x1, y1, x2, y2, boxX, boxY, boxW, boxH)
    -- Check if line segment intersects with box
    -- Using line-rectangle intersection algorithm
    local dx = x2 - x1
    local dy = y2 - y1
    
    -- Check intersection with each edge of the box
    local tmin = 0
    local tmax = 1
    
    -- Check X bounds
    if dx ~= 0 then
        local tx1 = (boxX - x1) / dx
        local tx2 = (boxX + boxW - x1) / dx
        tmin = math.max(tmin, math.min(tx1, tx2))
        tmax = math.min(tmax, math.max(tx1, tx2))
    elseif x1 < boxX or x1 > boxX + boxW then
        return false
    end
    
    -- Check Y bounds
    if dy ~= 0 then
        local ty1 = (boxY - y1) / dy
        local ty2 = (boxY + boxH - y1) / dy
        tmin = math.max(tmin, math.min(ty1, ty2))
        tmax = math.min(tmax, math.max(ty1, ty2))
    elseif y1 < boxY or y1 > boxY + boxH then
        return false
    end
    
    return tmin <= tmax
end

-- UI Draw Functions
function drawGameOver()
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    
    -- Game Over text
    love.graphics.setColor(1, 0, 0)
    if font then love.graphics.setFont(font) end
    love.graphics.printf("GAME OVER", 0, baseHeight/2 - 150, baseWidth, "center")
    
    -- Stats
    love.graphics.setColor(1, 1, 1)
    if smallFont then love.graphics.setFont(smallFont) end
    love.graphics.printf("Level " .. levelAtDeath .. " Failed", 0, baseHeight/2 - 80, baseWidth, "center")
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Enemies Defeated: " .. totalAsteroidsDestroyed, 0, baseHeight/2 - 50, baseWidth, "center")
    
    -- Menu options
    if font then love.graphics.setFont(font) end
    
    -- Restart Level option
    if gameOverSelection == 1 then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> RESTART LEVEL " .. levelAtDeath .. " <", 0, baseHeight/2 + 40, baseWidth, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("RESTART LEVEL " .. levelAtDeath, 0, baseHeight/2 + 40, baseWidth, "center")
    end
    
    -- Main Menu option
    if gameOverSelection == 2 then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> MAIN MENU <", 0, baseHeight/2 + 80, baseWidth, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("MAIN MENU", 0, baseHeight/2 + 80, baseWidth, "center")
    end
    
    -- Instructions
    if smallFont then love.graphics.setFont(smallFont) end
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Arrow Keys/D-Pad: Navigate | Enter/A: Select | ESC/B: Quick to Menu", 0, baseHeight/2 + 150, baseWidth, "center")
    
    if font then love.graphics.setFont(font) end
end

function drawPaused()
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    
    -- Paused text
    love.graphics.setColor(1, 1, 1)
    if font then love.graphics.setFont(font) end
    love.graphics.printf("PAUSED", 0, baseHeight/2 - 100, baseWidth, "center")
    
    -- Menu options
    if smallFont then love.graphics.setFont(smallFont) end
    
    -- Resume option
    if pauseSelection == 1 then
        love.graphics.setColor(1, 1, 0)
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
    end
    love.graphics.printf("Resume", 0, baseHeight/2, baseWidth, "center")
    
    -- Menu option
    if pauseSelection == 2 then
        love.graphics.setColor(1, 1, 0)
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
    end
    love.graphics.printf("Return to Menu", 0, baseHeight/2 + 30, baseWidth, "center")
    
    if font then love.graphics.setFont(font) end
end

function drawLevelComplete()
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    
    -- Level complete text
    love.graphics.setColor(0, 1, 0)
    if font then love.graphics.setFont(font) end
    love.graphics.printf("LEVEL " .. currentLevel .. " COMPLETE!", 0, baseHeight/2 - 100, baseWidth, "center")
    
    -- Score
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Zone " .. currentLevel .. " Clear!", 0, baseHeight/2 - 50, baseWidth, "center")
    
    -- Next level preview
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Next: Level " .. (currentLevel + 1), 0, baseHeight/2, baseWidth, "center")
    
    -- Boss warning if next level has boss
    if (currentLevel + 1) % 5 == 0 then
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.printf("WARNING: Boss Fight Incoming!", 0, baseHeight/2 + 50, baseWidth, "center")
    end
    
    -- Instructions
    if smallFont then love.graphics.setFont(smallFont) end
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Press ENTER to continue", 0, baseHeight/2 + 100, baseWidth, "center")
    
    if font then love.graphics.setFont(font) end
end

function drawMenu()
    -- Background
    love.graphics.setColor(backgroundColor)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    
    -- Title
    love.graphics.setColor(1, 1, 1)
    if font then love.graphics.setFont(font) end
    love.graphics.printf("STELLAR ASSAULT", 0, 100, baseWidth, "center")
    
    -- Menu options
    if smallFont then love.graphics.setFont(smallFont) end
    
    local yPos = 250
    local hasASave = hasSaveGame()
    
    if hasASave then
        -- Continue option (only show if save exists)
        if menuSelection == 1 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> Continue (Level " .. (loadedSaveLevel or "?") .. ") <", 0, yPos, baseWidth, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("Continue (Level " .. (loadedSaveLevel or "?") .. ")", 0, yPos, baseWidth, "center")
        end
        yPos = yPos + 30
        
        -- New Game option
        if menuSelection == 2 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> New Game <", 0, yPos, baseWidth, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("New Game", 0, yPos, baseWidth, "center")
        end
        yPos = yPos + 30
        
        -- Options
        if menuSelection == 3 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> Options <", 0, yPos, baseWidth, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("Options", 0, yPos, baseWidth, "center")
        end
        yPos = yPos + 30
        
        -- Quit
        if menuSelection == 4 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> Quit <", 0, yPos, baseWidth, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("Quit", 0, yPos, baseWidth, "center")
        end
    else
        -- Start Game (no save exists)
        if menuSelection == 1 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> Start Game <", 0, yPos, baseWidth, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("Start Game", 0, yPos, baseWidth, "center")
        end
        yPos = yPos + 30
        
        -- Options
        if menuSelection == 2 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> Options <", 0, yPos, baseWidth, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("Options", 0, yPos, baseWidth, "center")
        end
        yPos = yPos + 30
        
        -- Quit
        if menuSelection == 3 then
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("> Quit <", 0, yPos, baseWidth, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("Quit", 0, yPos, baseWidth, "center")
        end
    end
    
    
    -- Controls hint
    love.graphics.printf("Arrow Keys/D-Pad: Navigate | Enter/A: Select", 0, 500, baseWidth, "center")
    
    if font then love.graphics.setFont(font) end
end

-- Function to spawn asteroid fragments when a large asteroid is destroyed
function spawnAsteroidFragments(parentAsteroid)
    local fragmentCount = math.random(2, 4)
    
    for i = 1, fragmentCount do
        local fragment = {
            x = parentAsteroid.x + math.random(-20, 20),
            y = parentAsteroid.y + math.random(-20, 20),
            width = math.random(20, 30),
            height = math.random(20, 30),
            speed = math.random(150, 250),
            type = "fragment",
            health = 1,
            rotation = math.random() * math.pi * 2,
            rotationSpeed = math.random(-4, 4),
            vx = math.random(-100, 100),
            vy = math.random(-50, 50),
            canBreakApart = false
        }
        
        table.insert(asteroids, fragment)
    end
    
    -- Create explosion at parent location
    createExplosion(
        parentAsteroid.x + parentAsteroid.width/2,
        parentAsteroid.y + parentAsteroid.height/2,
        parentAsteroid.width/30
    )
end

-- Level 3 - Ice Moon functions
function transformToTank()
    vehicleMode = "tank"
    player.speed = 350  -- Slower on ground
    player.y = groundY - player.height  -- Place on ground
    gravity = 150  -- Projectiles arc
    
    -- Clear flying enemies
    aliens = {}
    asteroids = {}
    
    createPowerupText("TRANSFORMATION COMPLETE", baseWidth/2, baseHeight/2, {0, 1, 1})
end

function drawIceMoonTerrain()
    -- Draw ground
    love.graphics.setColor(0.8, 0.9, 1, 1)
    love.graphics.rectangle("fill", 0, groundY, baseWidth, baseHeight - groundY)
    
    -- Draw ice formations (removed per user request)
    -- love.graphics.setColor(0.6, 0.7, 0.9, 0.8)
    -- for i = 0, baseWidth, 100 do
    --     local height = math.sin(i * 0.02 + love.timer.getTime() * 0.1) * 30 + 40
    --     love.graphics.polygon("fill",
    --         i - 20, groundY,
    --         i, groundY - height,
    --         i + 20, groundY
    --     )
    -- end
    
    -- Draw snow particles
    love.graphics.setColor(1, 1, 1, 0.6)
    for _, star in ipairs(stars) do
        if math.random() > 0.7 then
            love.graphics.circle("fill", star.x, star.y, 1)
        end
    end
    
    -- Draw ice geysers (removed)
    -- for _, geyser in ipairs(iceGeysers) do
    --     love.graphics.setColor(0.7, 0.9, 1, geyser.alpha)
    --     love.graphics.rectangle("fill", geyser.x - 15, geyser.y, 30, geyser.height)
    -- end
end

-- Level 4 - Mothership functions
function drawMothershipInterior()
    -- Draw corridor walls
    love.graphics.setColor(0.2, 0.4, 0.2)
    love.graphics.rectangle("fill", 0, 0, leftWall, baseHeight)
    love.graphics.rectangle("fill", rightWall, 0, baseWidth - rightWall, baseHeight)
    
    -- Draw organic patterns on walls
    love.graphics.setColor(0.3, 0.5, 0.3, 0.5)
    for i = 0, baseHeight, 50 do
        local pulse = math.sin(love.timer.getTime() * 2 + i * 0.1) * 10
        love.graphics.circle("fill", leftWall/2, i, 20 + pulse)
        love.graphics.circle("fill", rightWall + (baseWidth - rightWall)/2, i, 20 + pulse)
    end
    
    -- Draw moving doors
    for _, door in ipairs(doors) do
        love.graphics.setColor(0.1, 0.3, 0.1)
        -- Left part of door
        love.graphics.rectangle("fill", leftWall, door.y, door.gapX - leftWall, door.height)
        -- Right part of door
        love.graphics.rectangle("fill", door.gapX + door.gapWidth, door.y, rightWall - door.gapX - door.gapWidth, door.height)
    end
    
    -- Draw energy barriers
    for _, barrier in ipairs(energyBarriers) do
        love.graphics.setColor(0, 1, 0, 0.5 + math.sin(love.timer.getTime() * 5) * 0.2)
        love.graphics.rectangle("fill", barrier.x, barrier.y, barrier.width, barrier.height)
    end
end

-- Level 5 - Solar Corona functions
function drawSolarEffects()
    -- Solar atmosphere
    local solarGlow = math.sin(love.timer.getTime()) * 0.1 + 0.9
    love.graphics.setColor(1, 0.5, 0, 0.1 * solarGlow)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    
    -- Solar flares
    for _, flare in ipairs(solarFlares) do
        love.graphics.setColor(1, 0.7, 0, flare.alpha)
        love.graphics.rectangle("fill", 0, flare.y - flare.height/2, baseWidth, flare.height)
    end
    
    -- Shade zones
    love.graphics.setColor(0, 0, 0, 0.3)
    for _, zone in ipairs(shadeZones) do
        love.graphics.rectangle("fill", zone.x, zone.y, zone.width, zone.height)
    end
    
    -- Heat meter UI
    if heatMeter > 0 then
        local heatPercent = heatMeter / maxHeat
        local heatColor = {1, 1 - heatPercent, 0}
        love.graphics.setColor(heatColor)
        love.graphics.rectangle("fill", 10, 10, 200 * heatPercent, 20)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", 10, 10, 200, 20)
        love.graphics.print("HEAT", 220, 10)
    end
    
    -- Plasma storms
    for _, storm in ipairs(plasmaStorms) do
        love.graphics.setColor(1, 0.5, 0, 0.3)
        love.graphics.circle("fill", storm.x, storm.y, storm.radius)
    end
end

-- Update functions for level-specific mechanics
function updateIceGeysers(dt)
    -- Spawn new geysers
    if math.random() < 0.01 then
        local geyser = {
            x = math.random(50, baseWidth - 50),
            y = groundY,
            height = 0,
            maxHeight = math.random(100, 200),
            alpha = 1,
            active = true,
            erupting = true
        }
        table.insert(iceGeysers, geyser)
    end
    
    -- Update existing geysers
    for i = #iceGeysers, 1, -1 do
        local geyser = iceGeysers[i]
        
        if geyser.erupting then
            geyser.height = math.min(geyser.height + 300 * dt, geyser.maxHeight)
            geyser.y = groundY - geyser.height
            
            if geyser.height >= geyser.maxHeight then
                geyser.erupting = false
            end
        else
            geyser.alpha = geyser.alpha - dt
            if geyser.alpha <= 0 then
                table.remove(iceGeysers, i)
            end
        end
        
        -- Check collision with player
        if geyser.active and checkCollision(player, {x = geyser.x - 15, y = geyser.y, width = 30, height = geyser.height}) then
            if invulnerableTime <= 0 then
                loseLife()
            end
        end
    end
end

function updateMothershipDoors(dt)
    -- Spawn new doors
    if #doors < 3 and math.random() < 0.01 then
        spawnDoor()
    end
    
    -- Update doors
    for i = #doors, 1, -1 do
        local door = doors[i]
        door.y = door.y + door.speed * dt
        
        if door.y > baseHeight then
            table.remove(doors, i)
        else
            -- Check collision with door
            if player.x < door.gapX or player.x + player.width > door.gapX + door.gapWidth then
                if checkCollision(player, {x = leftWall, y = door.y, width = corridorWidth, height = door.height}) then
                    if invulnerableTime <= 0 then
                        loseLife()
                    end
                end
            end
        end
    end
end

function spawnDoor()
    -- Ensure gap is wide enough and well-positioned
    local minGapWidth = 180  -- Increased from 150 for easier passage
    local margin = 80  -- Minimum distance from walls
    
    -- Calculate valid range for gap placement
    local minGapX = leftWall + margin
    local maxGapX = rightWall - minGapWidth - margin
    
    -- Ensure we have valid range
    if maxGapX <= minGapX then
        -- Corridor too narrow, center the gap
        local corridorCenter = (leftWall + rightWall) / 2
        gapX = corridorCenter - minGapWidth / 2
    else
        gapX = math.random(minGapX, maxGapX)
    end
    
    local door = {
        y = -100,
        height = 50,
        gapX = gapX,
        gapWidth = minGapWidth,
        speed = 100 + currentLevel * 10
    }
    table.insert(doors, door)
end

function updateHeatMeter(dt)
    if currentLevel == 5 then
        -- Increase heat over time
        heatMeter = math.min(heatMeter + dt * 5, maxHeat)
        
        -- Check if player is in shade zone
        local inShade = false
        for _, zone in ipairs(shadeZones) do
            if checkCollision(player, zone) then
                inShade = true
                break
            end
        end
        
        -- Cool down in shade
        if inShade then
            heatMeter = math.max(0, heatMeter - dt * 20)
        end
        
        -- Take damage if overheated
        if heatMeter >= maxHeat then
            if invulnerableTime <= 0 then
                loseLife()
                heatMeter = maxHeat * 0.5
            end
        end
    end
end

function updateSolarFlares(dt)
    -- Spawn solar flares
    if math.random() < 0.005 then
        local flare = {
            y = math.random(100, baseHeight - 100),
            height = 50,
            alpha = 0,
            growing = true,
            damage = 1
        }
        table.insert(solarFlares, flare)
        
        -- Warning sound
        if sounds.powerup then
            sounds.powerup:stop()
            sounds.powerup:play()
        end
    end
    
    -- Update flares
    for i = #solarFlares, 1, -1 do
        local flare = solarFlares[i]
        
        -- Ensure alpha exists
        if not flare.alpha then
            flare.alpha = 0
        end
        
        if flare.growing then
            flare.alpha = math.min(flare.alpha + dt * 2, 1)
            flare.height = math.min(flare.height + dt * 100, 150)
            
            if flare.alpha >= 1 then
                flare.growing = false
                -- Damage player if in flare
                if not inShadeZone(player) and 
                   player.y > flare.y - flare.height/2 and 
                   player.y < flare.y + flare.height/2 then
                    if invulnerableTime <= 0 then
                        loseLife()
                    end
                end
            end
        else
            flare.alpha = flare.alpha - dt
            if flare.alpha <= 0 then
                table.remove(solarFlares, i)
            end
        end
    end
end

function inShadeZone(obj)
    for _, zone in ipairs(shadeZones) do
        if checkCollision(obj, zone) then
            return true
        end
    end
    return false
end

-- Level-specific enemy spawn functions
function spawnIceTurret()
    local turret = {
        x = math.random(100, baseWidth - 100),
        y = groundY - 40,
        width = 60,
        height = 40,
        vx = 0,  -- Static turret doesn't move
        vy = 0,
        health = 3,
        maxHealth = 3,
        shootTimer = 0,
        shootCooldown = 3.5,  -- Increased from 2
        shootInterval = 3.5,  -- Increased from 2
        type = "turret",
        static = true
    }
    table.insert(aliens, turret)
end

function spawnHoverTank()
    local startX = math.random() > 0.5 and -50 or baseWidth + 50
    local tank = {
        x = startX,
        y = groundY - 60,
        width = 80,
        height = 60,
        vx = math.random(60, 100) * (startX < 0 and 1 or -1),
        vy = 0,
        health = 4,
        maxHealth = 4,
        shootTimer = 0,
        shootCooldown = 2.5,
        shootInterval = 2.5,
        type = "hovertank"
    }
    table.insert(aliens, tank)
end

function spawnIceShard()
    local shard = {
        x = math.random(50, baseWidth - 50),
        y = -30,
        width = 20,
        height = 40,
        speed = math.random(150, 250),
        rotation = math.random() * math.pi * 2,
        rotationSpeed = math.random(-3, 3),
        type = "iceshard",
        health = 1
    }
    table.insert(asteroids, shard)
end

function spawnOrganicPod()
    local pod = {
        x = math.random(leftWall + 50, rightWall - 50),
        y = -50,
        width = 60,
        height = 60,
        vy = 50,
        vx = 0,
        health = 3,  -- Reduced from 5
        maxHealth = 3,  -- Reduced from 5
        spawnTimer = 0,
        spawnCooldown = 5,  -- Increased from 3 (spawns less frequently)
        type = "organicpod"
    }
    table.insert(aliens, pod)
end

function spawnSecurityDrone()
    local drone = {
        x = math.random(leftWall, rightWall - 40),
        y = math.random(50, 200),
        width = 40,
        height = 40,
        vx = math.random(60, 90) * (math.random() > 0.5 and 1 or -1),  -- Reduced speed from 80-120
        vy = 0,
        health = 2,
        maxHealth = 2,
        shootTimer = 0,
        shootCooldown = 2.5,  -- Increased from 1.5
        shootInterval = 2.5,  -- Increased from 1.5
        type = "securitydrone",
        patrolling = true
    }
    table.insert(aliens, drone)
end

function spawnPlasmaOrb()
    local orb = {
        x = math.random(50, baseWidth - 50),
        y = -40,
        width = 30,
        height = 30,
        vx = 0,
        vy = math.random(60, 100),
        health = 2,
        maxHealth = 2,
        homing = true,
        homingStrength = 50,
        type = "plasmaorb"
    }
    table.insert(aliens, orb)
end

function spawnSolarFighter()
    local fighter = {
        x = math.random(50, baseWidth - 50),
        y = -50,
        width = 45,
        height = 45,
        vx = 0,
        vy = math.random(80, 120),
        health = 3,
        maxHealth = 3,
        teleportTimer = 0,
        teleportCooldown = 3,
        shootTimer = 0,
        shootCooldown = 1.5,
        shootInterval = 1.5,
        type = "solarfighter"
    }
    table.insert(aliens, fighter)
end

-- Level 2 enemy spawn functions
function spawnNebulaWraith()
    local wraith = {
        x = math.random(50, baseWidth - 50),
        y = -50,
        width = 50,
        height = 50,
        vx = 0,
        vy = math.random(40, 80),
        health = 2,
        maxHealth = 2,
        phaseShift = 0,  -- Makes it semi-transparent
        shootTimer = 0,
        shootCooldown = 3,
        shootInterval = 3,
        type = "nebulawraith"
    }
    table.insert(aliens, wraith)
end

function spawnEnergyMine()
    local mine = {
        x = math.random(100, baseWidth - 100),
        y = -30,
        width = 30,
        height = 30,
        vx = 0,
        vy = math.random(20, 40),
        health = 1,
        maxHealth = 1,
        pulseRadius = 0,
        type = "energymine",
        static = false,
        explodeRadius = 100
    }
    table.insert(aliens, mine)
end

function spawnNebulaCloud()
    -- Create smaller clouds with gaps between them
    local cloud = {
        x = math.random(0, baseWidth - 120),  -- Keep within screen bounds
        y = -150,
        width = 120,  -- Reduced from 200 to 120
        height = 100,  -- Reduced from 150 to 100
        vx = math.random(-10, 10),  -- Reduced horizontal movement
        vy = math.random(40, 60),  -- Slightly faster to clear screen quicker
        type = "nebulacloud",
        damage = 1,
        opacity = 0.3
    }
    
    -- Ensure there's space to navigate by not spawning if there's already a cloud nearby
    for _, existingCloud in ipairs(asteroids) do
        if existingCloud.type == "nebulacloud" and 
           math.abs(existingCloud.y - cloud.y) < 200 then  -- Don't spawn if another cloud is within 200 pixels vertically
            return  -- Skip spawning this cloud
        end
    end
    
    table.insert(asteroids, cloud)  -- Use asteroids table for environmental hazards
end

-- Level 3 enemy spawn functions
function spawnCryoDrone()
    local drone = {
        x = math.random(50, baseWidth - 50),
        y = -40,
        width = 45,
        height = 45,
        vx = math.random(-60, 60),
        vy = math.random(40, 60),
        health = 3,
        maxHealth = 3,
        freezeTimer = 0,
        freezeCooldown = 4,
        shootTimer = 0,
        shootCooldown = 2,
        shootInterval = 2,
        type = "cryodrone"
    }
    table.insert(aliens, drone)
end

-- Level 4 enemy spawn functions
function spawnRepairBot()
    local bot = {
        x = math.random(leftWall + 50, rightWall - 50),
        y = -40,
        width = 35,
        height = 35,
        vx = 0,
        vy = math.random(30, 50),
        health = 1,  -- Reduced from 2
        maxHealth = 1,  -- Reduced from 2
        healRadius = 100,  -- Reduced from 150
        healTimer = 0,
        healCooldown = 3,  -- Increased from 2
        type = "repairbot"
    }
    table.insert(aliens, bot)
end

function spawnTentacle()
    local side = math.random() > 0.5 and "left" or "right"
    local tentacle = {
        x = side == "left" and leftWall or rightWall - 40,
        y = math.random(100, 400),
        width = 40,
        height = 120,
        vx = 0,
        vy = 0,
        health = 2,  -- Reduced from 4
        maxHealth = 2,  -- Reduced from 4
        attackTimer = 0,
        attackCooldown = 3.5,  -- Increased from 2.5
        side = side,
        type = "tentacle",
        static = true
    }
    table.insert(aliens, tentacle)
end

-- Level 5 enemy spawn functions
function spawnFireElemental()
    local elemental = {
        x = math.random(50, baseWidth - 50),
        y = -60,
        width = 60,
        height = 60,
        vx = 0,
        vy = math.random(30, 60),
        health = 5,
        maxHealth = 5,
        fireTimer = 0,
        fireCooldown = 1.5,
        shootTimer = 0,
        shootCooldown = 2,
        shootInterval = 2,
        type = "fireelemental"
    }
    table.insert(aliens, elemental)
end

function createSolarFlare()
    -- Create a horizontal moving flare (different from vertical warning flares)
    local flare = {
        x = math.random() > 0.5 and -100 or baseWidth,
        y = math.random(100, baseHeight - 100),
        width = 150,
        height = 80,
        vx = math.random() > 0.5 and math.random(100, 200) or math.random(-200, -100),
        vy = 0,
        type = "solarflare",
        damage = 2,
        lifeTime = 5,
        alpha = 1,  -- Add alpha for consistency
        growing = false  -- Not a growing flare
    }
    table.insert(aliens, flare)  -- Add to aliens instead of solarFlares
end

-- Update spawn logic based on level
function spawnLevelEnemies(dt)
    if currentLevel == 1 then
        -- Level 1: Deep Space - Classic asteroids and basic aliens
        asteroidTimer = asteroidTimer + dt
        if asteroidTimer >= asteroidSpawnTime then
            for i = 1, math.random(1, 2) do
                spawnAsteroid()
            end
            asteroidTimer = 0
            asteroidSpawnTime = math.max(0.8, asteroidSpawnTime - 0.02)
        end
        
        alienTimer = alienTimer + dt
        if alienTimer >= alienSpawnTime then
            spawnSpaceFighter()  -- Basic space fighters
            alienTimer = 0
            alienSpawnTime = math.max(1.2, alienSpawnTime - 0.03)
        end
        
    elseif currentLevel == 2 then
        -- Level 2: Nebula - No asteroids, energy beings and nebula clouds
        alienTimer = alienTimer + dt
        if alienTimer >= alienSpawnTime * 0.8 then
            if math.random() < 0.6 then
                spawnNebulaWraith()  -- Ethereal enemies
            else
                spawnEnergyMine()    -- Stationary hazards
            end
            alienTimer = 0
        end
        
        -- Spawn nebula clouds that damage player
        if math.random() < 0.005 then  -- Reduced from 0.02 to 0.005 (75% less frequent)
            spawnNebulaCloud()
        end
        
    elseif currentLevel == 3 then
        -- Level 3: Ice Moon - Ground combat, no asteroids
        -- Ice turrets removed per user request
        -- if math.random() < 0.015 then  -- Reduced from 0.03
        --     spawnIceTurret()
        -- end
        if math.random() < 0.01 then   -- Reduced from 0.02
            spawnHoverTank()
        end
        if math.random() < 0.02 then  -- Reduced from 0.04
            spawnIceShard()  -- Environmental hazard, not asteroid
        end
        if math.random() < 0.01 then
            spawnCryoDrone()  -- Flying ice enemy
        end
        
    elseif currentLevel == 4 then
        -- Level 4: Mothership Interior - Organic/mechanical enemies
        if math.random() < 0.008 then  -- Reduced from 0.02 (60% less)
            spawnOrganicPod()
        end
        if math.random() < 0.012 then  -- Reduced from 0.03 (60% less)
            spawnSecurityDrone()
        end
        if math.random() < 0.005 then  -- Reduced from 0.01 (50% less)
            spawnRepairBot()  -- Heals other enemies
        end
        if math.random() < 0.007 then  -- Reduced from 0.015 (53% less)
            spawnTentacle()  -- Wall-mounted enemy
        end
        
    elseif currentLevel == 5 then
        -- Level 5: Solar Corona - Heat-based enemies
        if math.random() < 0.03 then
            spawnPlasmaOrb()
        end
        if math.random() < 0.02 then
            spawnSolarFighter()
        end
        if math.random() < 0.01 then
            spawnFireElemental()  -- New enemy type
        end
        -- Solar flares as environmental hazard
        if math.random() < 0.005 then
            createSolarFlare()
        end
        
    else
        -- Level 6+: Mixed chaos from all zones
        local enemyType = math.random(1, 5)
        if enemyType == 1 then
            spawnAsteroid()
            spawnSpaceFighter()
        elseif enemyType == 2 then
            spawnNebulaWraith()
        elseif enemyType == 3 then
            spawnCryoDrone()
        elseif enemyType == 4 then
            spawnSecurityDrone()
        else
            spawnPlasmaOrb()
        end
    end
end

-- Save/Load System
function saveGame()
    local saveData = {
        -- Game progress
        currentLevel = currentLevel,
        lives = lives,
        
        -- Player stats
        totalAsteroidsDestroyed = totalAsteroidsDestroyed,
        totalShotsFired = totalShotsFired,
        maxCombo = maxCombo,
        
        -- Difficulty settings
        asteroidSpawnTime = asteroidSpawnTime,
        alienSpawnTime = alienSpawnTime,
        
        -- Timestamp
        saveTime = os.time(),
        version = "1.0"
    }
    
    -- Convert to string
    local saveString = ""
    for key, value in pairs(saveData) do
        saveString = saveString .. key .. "=" .. tostring(value) .. "\n"
    end
    
    -- Save to file
    local success = love.filesystem.write("autosave.dat", saveString)
    
    if success then
        createPowerupText("GAME SAVED", baseWidth/2, baseHeight/2, {0, 1, 0})
    end
    
    return success
end

function loadGame()
    -- Check if save file exists
    if not love.filesystem.getInfo("autosave.dat") then
        return false
    end
    
    -- Read save file
    local saveString = love.filesystem.read("autosave.dat")
    if not saveString then
        return false
    end
    
    -- Parse save data
    local saveData = {}
    for line in saveString:gmatch("[^\n]+") do
        local key, value = line:match("(.+)=(.+)")
        if key and value then
            -- Convert to appropriate type
            if value == "true" then
                saveData[key] = true
            elseif value == "false" then
                saveData[key] = false
            elseif tonumber(value) then
                saveData[key] = tonumber(value)
            else
                saveData[key] = value
            end
        end
    end
    
    -- Apply saved data
    if saveData.currentLevel then
        currentLevel = saveData.currentLevel
        score = saveData.score or 0
        lives = saveData.lives or 3
        highScore = saveData.highScore or 0
        
        totalAsteroidsDestroyed = saveData.totalAsteroidsDestroyed or 0
        totalShotsFired = saveData.totalShotsFired or 0
        maxCombo = saveData.maxCombo or 0
        
        asteroidSpawnTime = saveData.asteroidSpawnTime or 2.5
        alienSpawnTime = saveData.alienSpawnTime or 4.0
        
        return true
    end
    
    return false
end

function hasSaveGame()
    return love.filesystem.getInfo("autosave.dat") ~= nil
end

function deleteSaveGame()
    love.filesystem.remove("autosave.dat")
end

-- New save system functions
function loadAllSaveSlots()
    for i = 1, 3 do
        local filename = "save" .. i .. ".dat"
        if love.filesystem.getInfo(filename) then
            local saveString = love.filesystem.read(filename)
            if saveString then
                local saveData = {}
                for line in saveString:gmatch("[^\r\n]+") do
                    local key, value = line:match("(.+)=(.+)")
                    if key and value then
                        saveData[key] = value
                    end
                end
                saveSlots[i] = {
                    level = tonumber(saveData.currentLevel) or 1,
                    lives = tonumber(saveData.lives) or 3,
                    highestLevel = tonumber(saveData.highestLevel) or 1
                }
            end
        end
    end
end

function saveToSlot(slot)
    local filename = "save" .. slot .. ".dat"
    local saveString = string.format(
        "currentLevel=%d\nlives=%d\nhighestLevel=%d\n",
        currentLevel,
        lives,
        math.max(currentLevel, saveSlots[slot] and saveSlots[slot].highestLevel or 1)
    )
    
    love.filesystem.write(filename, saveString)
    
    -- Update the save slot data
    saveSlots[slot] = {
        level = currentLevel,
        lives = lives,
        highestLevel = math.max(currentLevel, saveSlots[slot] and saveSlots[slot].highestLevel or 1)
    }
end

function loadFromSlot(slot)
    local filename = "save" .. slot .. ".dat"
    if love.filesystem.getInfo(filename) then
        local saveString = love.filesystem.read(filename)
        if saveString then
            local saveData = {}
            for line in saveString:gmatch("[^\r\n]+") do
                local key, value = line:match("(.+)=(.+)")
                if key and value then
                    saveData[key] = value
                end
            end
            
            currentLevel = tonumber(saveData.currentLevel) or 1
            lives = tonumber(saveData.lives) or 3
            currentSaveSlot = slot
            
            return true
        end
    end
    return false
end

function deleteSaveSlot(slot)
    local filename = "save" .. slot .. ".dat"
    love.filesystem.remove(filename)
    saveSlots[slot] = nil
end

-- Menu drawing functions
function drawMainMenu()
    local menuY = 250
    local menuSpacing = 60
    
    -- Play option
    if menuSelection == 1 then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> PLAY <", 0, menuY, 800, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("PLAY", 0, menuY, 800, "center")
    end
    
    -- Level Select option
    if menuSelection == 2 then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> LEVEL SELECT <", 0, menuY + menuSpacing, 800, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("LEVEL SELECT", 0, menuY + menuSpacing, 800, "center")
    end
    
    -- Options option
    if menuSelection == 3 then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> OPTIONS <", 0, menuY + menuSpacing * 2, 800, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("OPTIONS", 0, menuY + menuSpacing * 2, 800, "center")
    end
    
    -- Quit option
    if menuSelection == 4 then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> QUIT <", 0, menuY + menuSpacing * 3, 800, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("QUIT", 0, menuY + menuSpacing * 3, 800, "center")
    end
end

function drawSaveSlotMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SELECT SAVE SLOT", 0, 200, 800, "center")
    
    local slotY = 280
    local slotSpacing = 100
    
    for i = 1, 3 do
        local isSelected = (selectedSaveSlot == i)
        
        -- Draw slot box
        if isSelected then
            love.graphics.setColor(1, 1, 0, 0.3)
            love.graphics.rectangle("fill", 200, slotY + (i-1) * slotSpacing - 10, 400, 80)
            love.graphics.setColor(1, 1, 0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", 200, slotY + (i-1) * slotSpacing - 10, 400, 80)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 0.2)
            love.graphics.rectangle("fill", 200, slotY + (i-1) * slotSpacing - 10, 400, 80)
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.rectangle("line", 200, slotY + (i-1) * slotSpacing - 10, 400, 80)
        end
        
        -- Draw slot info
        if saveSlots[i] then
            love.graphics.setColor(isSelected and 1 or 0.8, isSelected and 1 or 0.8, isSelected and 1 or 0.8)
            love.graphics.printf("SLOT " .. i, 220, slotY + (i-1) * slotSpacing, 360, "left")
            
            if smallFont then love.graphics.setFont(smallFont) end
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("Level: " .. saveSlots[i].level, 220, slotY + (i-1) * slotSpacing + 25, 180, "left")
            love.graphics.printf("Lives: " .. saveSlots[i].lives, 220, slotY + (i-1) * slotSpacing + 45, 180, "left")
            love.graphics.printf("Max Level: " .. saveSlots[i].highestLevel, 400, slotY + (i-1) * slotSpacing + 35, 180, "left")
            love.graphics.setFont(font)
        else
            love.graphics.setColor(isSelected and 0.7 or 0.5, isSelected and 0.7 or 0.5, isSelected and 0.7 or 0.5)
            love.graphics.printf("SLOT " .. i .. " - EMPTY", 220, slotY + (i-1) * slotSpacing + 20, 360, "center")
        end
    end
    
    -- Back option
    local backY = slotY + 3 * slotSpacing + 20
    if selectedSaveSlot == 4 then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> BACK <", 0, backY, 800, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("BACK", 0, backY, 800, "center")
    end
    
    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    if smallFont then love.graphics.setFont(smallFont) end
    love.graphics.printf("Enter: Load/Create | Delete: Clear Slot", 0, 550, 800, "center")
    love.graphics.setFont(font)
end

function drawLevelSelectMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SELECT LEVEL", 0, 120, 800, "center")
    
    -- Get the highest level reached across all saves
    local maxUnlockedLevel = 1
    for i = 1, 3 do
        if saveSlots[i] then
            maxUnlockedLevel = math.max(maxUnlockedLevel, saveSlots[i].highestLevel)
        end
    end
    
    -- Draw level grid
    local cols = 5
    local rows = 1
    local startX = 150
    local startY = 250
    local boxSize = 80
    local spacing = 20
    
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local level = row * cols + col + 1
            if level <= 5 then -- Show only 5 levels
                local x = startX + col * (boxSize + spacing)
                local y = startY + row * (boxSize + spacing)
                local isUnlocked = level <= maxUnlockedLevel
                local isSelected = (level == selectedLevel)
                
                -- Draw level box
                if isSelected and isUnlocked then
                    love.graphics.setColor(1, 1, 0, 0.3)
                    love.graphics.rectangle("fill", x, y, boxSize, boxSize)
                    love.graphics.setColor(1, 1, 0)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", x, y, boxSize, boxSize)
                    love.graphics.setLineWidth(1)
                elseif isUnlocked then
                    love.graphics.setColor(0.2, 0.4, 0.6, 0.3)
                    love.graphics.rectangle("fill", x, y, boxSize, boxSize)
                    love.graphics.setColor(0.4, 0.6, 0.8)
                    love.graphics.rectangle("line", x, y, boxSize, boxSize)
                else
                    love.graphics.setColor(0.2, 0.2, 0.2, 0.3)
                    love.graphics.rectangle("fill", x, y, boxSize, boxSize)
                    love.graphics.setColor(0.3, 0.3, 0.3)
                    love.graphics.rectangle("line", x, y, boxSize, boxSize)
                end
                
                -- Draw level number
                if isUnlocked then
                    love.graphics.setColor(isSelected and 1 or 0.8, isSelected and 1 or 0.8, isSelected and 1 or 0.8)
                else
                    love.graphics.setColor(0.4, 0.4, 0.4)
                end
                love.graphics.printf(tostring(level), x, y + boxSize/2 - 10, boxSize, "center")
                
                -- Draw lock icon for locked levels
                if not isUnlocked then
                    love.graphics.setColor(0.5, 0.5, 0.5)
                    love.graphics.circle("line", x + boxSize/2, y + boxSize - 15, 8)
                    love.graphics.rectangle("fill", x + boxSize/2 - 5, y + boxSize - 15, 10, 6)
                end
            end
        end
    end
    
    -- Back option
    if selectedLevel == 6 then -- 6 is the back option
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> BACK <", 0, 380, 800, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("BACK", 0, 380, 800, "center")
    end
    
    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    if smallFont then love.graphics.setFont(smallFont) end
    love.graphics.printf("Arrow Keys: Navigate | Enter: Start Level", 0, 460, 800, "center")
    love.graphics.setFont(font)
end

-- Gamepad hot-plugging support
function love.joystickadded(joystick)
    if not gamepad and joystick:isGamepad() then
        gamepad = joystick
        print("Gamepad connected: " .. gamepad:getName())
    end
end

function love.joystickremoved(joystick)
    if gamepad and gamepad == joystick then
        gamepad = nil
        print("Gamepad disconnected")
        -- Check if another gamepad is available
        local joysticks = love.joystick.getJoysticks()
        for _, j in ipairs(joysticks) do
            if j:isGamepad() then
                gamepad = j
                print("Switched to gamepad: " .. gamepad:getName())
                break
            end
        end
    end
end
