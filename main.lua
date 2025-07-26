-- Stellar Assault - Refactored Main Module
-- A space shooter with modular architecture

-- Core modules
local StateManager = require("src.StateManager")
local constants = require("src.constants")
local DebugConsole = require("src.debugconsole")
local CONFIG = require("src.config")
local logger = require("src.logger")
local Persistence = require("src.persistence")
local UIManager = require("src.uimanager")

-- Performance optimizations: cache Love2D modules
local lg = love.graphics
local la = love.audio
local lw = love.window
local lt = love.timer
local lf = love.filesystem
local le = love.event

-- Global state manager
stateManager = nil

-- Debug systems
debugConsole = nil
consoleFont = nil

-- Global resources (loaded once, shared across states)
titleFont = nil
menuFont = nil
uiFont = nil
smallFont = nil
mediumFont = nil
uiManager = nil

-- Audio resources
laserSound = nil
explosionSound = nil
powerupSound = nil
shieldBreakSound = nil
gameOverSound = nil
menuSelectSound = nil
menuConfirmSound = nil
backgroundMusic = nil
bossMusic = nil
victorySound = nil

-- Preloaded laser sound clones for concurrent playback
laserClones = nil
laserCloneIndex = 1

-- Positional audio settings
local soundReferenceDistance = 50
local soundMaxDistance = 800

-- Audio lists for volume updates
local sfxSources = {}
local musicSources = {}

-- Settings (persist across states)
masterVolume = constants.audio.defaultMasterVolume
sfxVolume = constants.audio.defaultSFXVolume
musicVolume = constants.audio.defaultMusicVolume
displayMode = "borderless"
currentResolution = 1
highContrast = false
fontScale = 1

-- Input tracking
lastInputType = "keyboard"  -- Default to keyboard/mouse
inputHints = {
    keyboard = {
        select = "Enter",
        back = "ESC",
        navigate = "Arrow Keys",
        skip = "SPACE",
        confirm = "Enter",
        cancel = "ESC",
        action = "Space"
    },
    gamepad = {
        select = "A",
        back = "B",
        navigate = "D-Pad",
        skip = "A",
        confirm = "A",
        cancel = "B",
        action = "X"
    }
}

-- Function to update last input type
function updateInputType(inputType)
    if lastInputType ~= inputType then
        lastInputType = inputType
        logger.debug("Input type changed to: %s", inputType)
    end
end

function initWindow()
    lw.setTitle("Stellar Assault")
    lw.setMode(800, 600, {
        fullscreen = false,
        resizable = true,
        minwidth = constants.window.minWidth,
        minheight = constants.window.minHeight
    })

    lg.setDefaultFilter("nearest", "nearest")
    lg.setBackgroundColor(0.05, 0.05, 0.1)
end

function loadFonts()
    titleFont = lg.newFont(48)
    menuFont = lg.newFont(24)
    uiFont = lg.newFont(18)
    smallFont = lg.newFont(14)
    mediumFont = lg.newFont(20)
    uiManager = UIManager:new()
    
    -- Try to load monospace font, fall back to default
    if lf.getInfo("assets/fonts/monospace.ttf") then
        consoleFont = lg.newFont("assets/fonts/monospace.ttf", 14)
    else
        consoleFont = lg.newFont(14)
    end
end

function initStates()
    stateManager = StateManager:new()
    stateManager:register("menu", require("states.menu"))
    stateManager:register("intro", require("states.intro"))
    stateManager:register("playing", require("states.playing"))
    stateManager:register("pause", require("states.pause"))
    stateManager:register("gameover", require("states.gameover"))
    stateManager:register("options", require("states.options"))
    stateManager:register("levelselect", require("states.levelselect"))
    stateManager:register("leaderboard", require("states.leaderboard"))

    if CONFIG.debug then
        debugConsole = DebugConsole:new()
        local debugCommands = require("src.debugcommands")
        debugCommands.register(debugConsole)
    else
        debugConsole = {
            update = function() end,
            draw = function() end,
            keypressed = function() return false end,
            textinput = function() return false end,
        }
    end
end

function love.load()
    initWindow()
    loadFonts()

    -- Load all sprites dynamically and categorize them
    local SpriteManager = require("src.sprite_manager")
    spriteManager = SpriteManager.load("assets/sprites")

    -- Categories are determined by filename patterns
    playerShips = spriteManager:getCategory("player")
    enemyShips  = spriteManager:getCategory("enemy")

    bossSprites = {}
    local bossCategory = spriteManager:getCategory("boss")
    for name, sprite in pairs(bossCategory) do
        local idx = tonumber(name:match("%d+")) or (#bossSprites + 1)
        bossSprites[idx] = sprite
    end
    bossSprite = bossSprites[1]
    boss2Sprite = bossSprites[2]
    
    -- Game configuration
    availableShips = { "alpha", "beta", "gamma" }
    selectedShip = "alpha"
    
    -- Global sprite scale factor (adjust as needed; 4 makes sprites 4x larger)
    spriteScale = 0.15  -- Adjust this value lower (e.g., 0.1) if still too large, or higher if too small
    
    loadAudio()
    
    -- Apply saved settings
    loadSettings()
    
    -- Apply the loaded window mode
    applyWindowMode()
    
    Persistence.init()
    local psettings = Persistence.getSettings()
    highContrast = psettings.highContrast or false
    fontScale = psettings.fontScale or 1
    applyFontScale()

    initStates()
    
    logger.info("Stellar Assault started")
    logger.info("Love2D version: %d.%d.%d", love.getVersion())
    logger.info("Resolution: %dx%d", lg.getWidth(), lg.getHeight())
    
    -- Start with menu
    stateManager:switch("menu")
end

function loadAudio()
    la.setDistanceModel("inverseclamped")
    -- Sound effects
    if lf.getInfo("laser.wav") then
        laserSound = la.newSource("laser.wav", "static")
        laserSound.baseVolume = 0.5
        laserSound:setVolume(laserSound.baseVolume * sfxVolume * masterVolume)
        table.insert(sfxSources, laserSound)

        -- Preload clones for rapid firing
        laserClones = {}
        for i = 1, 5 do
            local c = laserSound:clone()
            c.baseVolume = laserSound.baseVolume
            c:setVolume(c.baseVolume * sfxVolume * masterVolume)
            table.insert(laserClones, c)
            table.insert(sfxSources, c)  -- Add clones to sfxSources for volume updates
        end
        laserCloneIndex = 1
    end
    
    if lf.getInfo("explosion.wav") then
        explosionSound = la.newSource("explosion.wav", "static")
        explosionSound.baseVolume = 0.7
        explosionSound:setVolume(explosionSound.baseVolume * sfxVolume * masterVolume)
        table.insert(sfxSources, explosionSound)
    end

    if lf.getInfo("powerup.wav") then
        powerupSound = la.newSource("powerup.wav", "static")
        powerupSound.baseVolume = 0.6
        powerupSound:setVolume(powerupSound.baseVolume * sfxVolume * masterVolume)
        table.insert(sfxSources, powerupSound)
    end

    if lf.getInfo("shield_break.wav") then
        shieldBreakSound = la.newSource("shield_break.wav", "static")
        shieldBreakSound.baseVolume = 0.7
        shieldBreakSound:setVolume(shieldBreakSound.baseVolume * sfxVolume * masterVolume)
        table.insert(sfxSources, shieldBreakSound)
    end

    if lf.getInfo("gameover.ogg") then
        gameOverSound = la.newSource("gameover.ogg", "static")
        gameOverSound.baseVolume = 0.8
        gameOverSound:setVolume(gameOverSound.baseVolume * sfxVolume * masterVolume)
        table.insert(sfxSources, gameOverSound)
    end

    if lf.getInfo("menu.flac") then
        menuSelectSound = la.newSource("menu.flac", "static")
        menuSelectSound.baseVolume = 0.4
        menuSelectSound:setVolume(menuSelectSound.baseVolume * sfxVolume * masterVolume)
        table.insert(sfxSources, menuSelectSound)
        menuConfirmSound = menuSelectSound:clone()
        menuConfirmSound.baseVolume = menuSelectSound.baseVolume
        menuConfirmSound:setVolume(menuConfirmSound.baseVolume * sfxVolume * masterVolume)
        table.insert(sfxSources, menuConfirmSound)
    end
    
    -- Background music
    if lf.getInfo("background.mp3") then
        backgroundMusic = la.newSource("background.mp3", "stream")
        backgroundMusic.baseVolume = 1.0
        backgroundMusic:setLooping(true)
        backgroundMusic:setVolume(backgroundMusic.baseVolume * musicVolume * masterVolume)
        table.insert(musicSources, backgroundMusic)
    end

    if lf.getInfo("boss.mp3") then
        bossMusic = la.newSource("boss.mp3", "stream")
        bossMusic.baseVolume = 0.8
        bossMusic:setLooping(true)
        bossMusic:setVolume(bossMusic.baseVolume * musicVolume * masterVolume)
        table.insert(musicSources, bossMusic)
    end

    if lf.getInfo("victory.ogg") then
        victorySound = la.newSource("victory.ogg", "static")
        victorySound.baseVolume = 0.8
        victorySound:setVolume(victorySound.baseVolume * sfxVolume * masterVolume)
        table.insert(sfxSources, victorySound)
    end
end

function applyFontScale()
    titleFont = lg.newFont(48 * fontScale)
    menuFont = lg.newFont(24 * fontScale)
    uiFont = lg.newFont(18 * fontScale)
    smallFont = lg.newFont(14 * fontScale)
    mediumFont = lg.newFont(20 * fontScale)
end

function loadSettings()
    if lf.getInfo("settings.dat") then
        local data = lf.read("settings.dat")
        local lines = {}
        for line in data:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
        
        if #lines >= 5 then
            currentResolution = tonumber(lines[1]) or 1
            displayMode = lines[2] or "windowed"
            masterVolume = tonumber(lines[3]) or 1.0
            sfxVolume = tonumber(lines[4]) or 1.0
            musicVolume = tonumber(lines[5]) or 0.2
            
            -- Load selected ship if available
            if #lines >= 6 and lines[6] then
                selectedShip = lines[6]
                -- Validate ship selection
                local validShip = false
                for _, ship in ipairs(availableShips) do
                    if ship == selectedShip then
                        validShip = true
                        break
                    end
                end
                if not validShip then
                    selectedShip = "alpha"
                end
            end
            
            if #lines >= 7 then
                highContrast = lines[7] == "true"
            end
            if #lines >= 8 then
                fontScale = tonumber(lines[8]) or 1
            end

            -- Apply audio settings
            updateAudioVolumes()
            applyFontScale()
        end
    end
end

function saveSettings()
    local data = currentResolution .. "\n" ..
                displayMode .. "\n" ..
                masterVolume .. "\n" ..
                sfxVolume .. "\n" ..
                musicVolume .. "\n" ..
                selectedShip .. "\n" ..
                tostring(highContrast) .. "\n" ..
                fontScale

    lf.write("settings.dat", data)

    Persistence.updateSettings({
        masterVolume = masterVolume,
        sfxVolume = sfxVolume,
        musicVolume = musicVolume,
        selectedShip = selectedShip,
        displayMode = displayMode,
        highContrast = highContrast,
        fontScale = fontScale
    })
end

function applyWindowMode()
    -- Resolution options (matching options.lua)
    local resolutions = {
        {width = 800, height = 600},
        {width = 1024, height = 768},
        {width = 1280, height = 720},
        {width = 1366, height = 768},
        {width = 1920, height = 1080},
        {width = 2560, height = 1440}
    }
    
    local flags = {
        vsync = 1,
        minwidth = constants.window.minWidth,
        minheight = constants.window.minHeight
    }
    
    -- Apply window settings based on display mode
    if displayMode == "borderless" then
        -- Borderless fullscreen (desktop mode)
        flags.fullscreen = true
        flags.fullscreentype = "desktop"
        flags.resizable = false
        lw.setMode(0, 0, flags)  -- 0,0 uses desktop dimensions automatically
        
    elseif displayMode == "fullscreen" then
        -- Exclusive fullscreen
        local resolution = resolutions[currentResolution] or resolutions[1]
        flags.fullscreen = true
        flags.fullscreentype = "exclusive"
        flags.resizable = false
        lw.setMode(resolution.width, resolution.height, flags)
        
    else  -- windowed
        local resolution = resolutions[currentResolution] or resolutions[1]
        flags.fullscreen = false
        flags.borderless = false
        flags.resizable = true
        lw.setMode(resolution.width, resolution.height, flags)
    end
    
    -- Reinitialize starfield for new window size
    initStarfield()
end

function updateAudioVolumes()
    -- Update all SFX sources with new volume settings
    for _, source in ipairs(sfxSources) do
        if source then
            local base = source.baseVolume or 1
            source:setVolume(base * sfxVolume * masterVolume)
        end
    end

    -- Update all music sources
    for _, source in ipairs(musicSources) do
        if source then
            local base = source.baseVolume or 1
            source:setVolume(base * musicVolume * masterVolume)
        end
    end
end

-- Play a sound at a given world position with distance-based attenuation
function playPositionalSound(source, x, y)
    if not source or not player then return end
    local clone

    -- Use preloaded clones for laser to allow overlapping sounds
    if source == laserSound and laserClones then
        clone = laserClones[laserCloneIndex]
        laserCloneIndex = (laserCloneIndex % #laserClones) + 1
    else
        clone = source:clone()
        clone.baseVolume = source.baseVolume
    end

    local dx, dy = x - player.x, y - player.y
    if clone:getChannelCount() == 1 then
        clone:setRelative(true)
        clone:setPosition(dx, dy, 0)
        clone:setAttenuationDistances(soundReferenceDistance, soundMaxDistance)
    end
    local base = clone.baseVolume or source.baseVolume or 1
    clone:setVolume(base * sfxVolume * masterVolume)
    clone:play()
end

-- Starfield background (shared across states)
local stars = {}
local starCount = 200

function initStarfield()
    stars = {}
    for i = 1, starCount do
        table.insert(stars, {
            x = love.math.random() * lg.getWidth(),
            y = love.math.random() * lg.getHeight(),
            speed = love.math.random() * 50 + 20,
            size = love.math.random() * 2
        })
    end
end

function updateStarfield(dt)
    local height = lg.getHeight()
    for _, star in ipairs(stars) do
        star.y = star.y + star.speed * dt
        if star.y > height then
            star.y = -star.size
            star.x = love.math.random() * lg.getWidth()
        end
    end
end

function drawStarfield()
    for _, star in ipairs(stars) do
        local brightness = star.size / 2
        lg.setColor(brightness, brightness, brightness)
        lg.circle("fill", star.x, star.y, star.size)
    end
end

-- Make starfield functions global for states to use
_G.initStarfield = initStarfield
_G.updateStarfield = updateStarfield
_G.drawStarfield = drawStarfield

-- Initialize starfield
initStarfield()

-- Love2D callbacks
function love.update(dt)
    -- Cap delta time to prevent large jumps
    dt = math.min(dt, 1/30)
    
    -- Apply time scale if set
    if _G.timeScale then
        dt = dt * _G.timeScale
    end
    
    -- Update starfield
    updateStarfield(dt)
    
    -- Update debug console
    debugConsole:update(dt)
    
    -- Update config reload notification
    if _G.configReloadNotification then
        _G.configReloadNotification.timer = _G.configReloadNotification.timer - dt
        if _G.configReloadNotification.timer <= 0 then
            _G.configReloadNotification = nil
        end
    end
    
    -- Update current state
    stateManager:update(dt)
end

function love.draw()
    stateManager:draw()
    
    -- Debug info (press F3 to toggle)
    if debugMode then
        drawDebugInfo()
    end
    
    -- Debug overlay (press F9 to toggle)
    if debugOverlay then
        drawDebugOverlay()
    end
    
    -- Config reload notification
    if _G.configReloadNotification then
        local notif = _G.configReloadNotification
        lg.setFont(menuFont)
        lg.setColor(notif.color[1], notif.color[2], notif.color[3], notif.timer)
        lg.printf(notif.text, 0, lg.getHeight() / 2 - 50, lg.getWidth(), "center")
        lg.setColor(1, 1, 1, 1)
    end
    
    -- Log overlay (toggle with 'showlog' command)
    if _G.showLogOverlay then
        logger.drawOverlay(10, lg.getHeight() - 200, 10)
    end
    
    -- Debug console (press ~ to toggle)
    debugConsole:draw()
end

function love.keypressed(key, scancode, isrepeat)
    updateInputType("keyboard")
    
    -- Check debug console first
    if debugConsole:keypressed(key) then
        return -- Console handled the key
    end
    
    -- Global keys
    if key == "f3" then
        debugMode = not debugMode
        logger.info("Debug mode: %s", debugMode and "enabled" or "disabled")
    elseif key == "f5" then
        -- Hot-reload config (dev only)
        local success, newConstants = pcall(function()
            -- Clear the require cache
            package.loaded["src.constants"] = nil
            return require("src.constants")
        end)
        
        if success then
            -- Update global constants
            constants = newConstants
            logger.info("Config reloaded successfully")
            
            -- Visual feedback
            _G.configReloadNotification = {
                text = "Config Reloaded!",
                timer = 2,
                color = {0, 1, 0}
            }
        else
            logger.error("Failed to reload config: " .. tostring(newConstants))
            _G.configReloadNotification = {
                text = "Config Reload Failed!",
                timer = 2,
                color = {1, 0, 0}
            }
        end
    elseif key == "f9" then
        -- Toggle debug overlay
        debugOverlay = not debugOverlay
        logger.info("Debug overlay: %s", debugOverlay and "enabled" or "disabled")
    end
    
    -- Pass to state
    stateManager:keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    stateManager:keyreleased(key, scancode)
end

function love.mousepressed(x, y, button, istouch, presses)
    updateInputType("keyboard")  -- Treat mouse as keyboard context
    stateManager:mousepressed(x, y, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
    updateInputType("keyboard")  -- Treat mouse as keyboard context
end

function love.gamepadaxis(joystick, axis, value)
    if math.abs(value) > 0.2 then  -- Deadzone to avoid noise
        updateInputType("gamepad")
    end
end

function love.gamepadpressed(joystick, button)
    updateInputType("gamepad")
    stateManager:gamepadpressed(joystick, button)
end

function love.gamepadreleased(joystick, button)
    stateManager:gamepadreleased(joystick, button)
end

function love.resize(w, h)
    -- Reinitialize starfield for new dimensions
    initStarfield()
    
    -- Optional: Make scale relative to screen height for consistency across resolutions
    -- spriteScale = (h / 600) * 4  -- Bases on 600px height; uncomment if fixed scale feels inconsistent
    
    -- Notify current state
    stateManager:resize(w, h)
    
    logger.info("Window resized to %dx%d", w, h)
end

function love.textinput(text)
    -- Pass to debug console
    if debugConsole:textinput(text) then
        return
    end
end

-- Debug information
debugMode = false
debugOverlay = false
frameTimeHistory = {}
maxFrameTimeHistory = 60

function drawDebugInfo()
    lg.setFont(smallFont)
    lg.setColor(1, 1, 1, 0.8)
    
    -- Track frame time history
    table.insert(frameTimeHistory, lt.getDelta())
    if #frameTimeHistory > maxFrameTimeHistory then
        table.remove(frameTimeHistory, 1)
    end
    
    -- Calculate average and max frame time
    local avgFrameTime = 0
    local maxFrameTime = 0
    for _, frameTime in ipairs(frameTimeHistory) do
        avgFrameTime = avgFrameTime + frameTime
        maxFrameTime = math.max(maxFrameTime, frameTime)
    end
    avgFrameTime = avgFrameTime / #frameTimeHistory
    
    local info = {
        "FPS: " .. tostring(lt.getFPS()),
        "Memory: " .. string.format("%.2f MB", collectgarbage("count") / 1024),
        "Delta: " .. string.format("%.3f ms", lt.getAverageDelta() * 1000),
        "Avg Frame: " .. string.format("%.3f ms", avgFrameTime * 1000),
        "Max Frame: " .. string.format("%.3f ms", maxFrameTime * 1000),
        "State: " .. (stateManager.currentName or "none"),
        "Resolution: " .. lg.getWidth() .. "x" .. lg.getHeight()
    }
    
    local y = 10
    for _, line in ipairs(info) do
        lg.print(line, lg.getWidth() - 150, y)
        y = y + 15
    end
end

function drawDebugOverlay()
    lg.setFont(smallFont)
    
    -- Semi-transparent background
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", lg.getWidth() - 250, 10, 240, 180, 5)
    
    -- Performance metrics
    lg.setColor(1, 1, 1, 1)
    local x = lg.getWidth() - 240
    local y = 20
    local lineHeight = 18
    
    -- Memory usage
    local memUsage = collectgarbage("count") / 1024
    lg.print(string.format("Memory: %.2f MB", memUsage), x, y)
    y = y + lineHeight
    
    -- Entity counts (if in playing state)
    if stateManager.currentState == stateManager.states.playing then
        lg.print("Entities:", x, y)
        y = y + lineHeight
        
        lg.print(string.format("  Asteroids: %d", asteroids and #asteroids or 0), x, y)
        y = y + lineHeight
        
        lg.print(string.format("  Aliens: %d", aliens and #aliens or 0), x, y)
        y = y + lineHeight
        
        lg.print(string.format("  Lasers: %d", lasers and #lasers or 0), x, y)
        y = y + lineHeight
        
        lg.print(string.format("  Explosions: %d", explosions and #explosions or 0), x, y)
        y = y + lineHeight
        
        lg.print(string.format("  Powerups: %d", powerups and #powerups or 0), x, y)
        y = y + lineHeight
    end
    
    -- Controls hint
    y = y + lineHeight
    lg.setColor(0.7, 0.7, 0.7, 1)
    lg.print("F3: Debug Info", x, y)
    y = y + lineHeight
    lg.print("F5: Reload Config", x, y)
    y = y + lineHeight
    lg.print("F9: Toggle Overlay", x, y)
    
    lg.setColor(1, 1, 1, 1)
end

-- Utility functions available globally
function saveGame(slot, level, score, lives)
    local data = level .. "," .. score .. "," .. lives
    lf.write("save" .. slot .. ".dat", data)
end

function checkCollision(a, b)
    local aLeft = a.x - (a.width or a.size) / 2
    local aRight = a.x + (a.width or a.size) / 2
    local aTop = a.y - (a.height or a.size) / 2
    local aBottom = a.y + (a.height or a.size) / 2
    
    local bLeft = b.x - (b.width or b.size) / 2
    local bRight = b.x + (b.width or b.size) / 2
    local bTop = b.y - (b.height or b.size) / 2
    local bBottom = b.y + (b.height or b.size) / 2
    
    return aLeft < bRight and aRight > bLeft and 
           aTop < bBottom and aBottom > bTop
end

function love.quit()
    if spriteManager and spriteManager.reportUsage then
        spriteManager:reportUsage()
    end
end