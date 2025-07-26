-- Stellar Assault - Refactored Main Module
-- A space shooter with modular architecture

-- Core modules
local StateManager   = require("src.StateManager")
local constants      = require("src.constants")
local DebugConsole   = require("src.debugconsole")
local CONFIG         = require("src.config")
local logger         = require("src.logger")
local Persistence    = require("src.persistence")
local UIManager      = require("src.uimanager")
local Game           = require("src.game")

-- Performance optimizations: cache Love2D modules
local lg = love.graphics
local la = love.audio
local lw = love.window
local lt = love.timer
local lf = love.filesystem
local le = love.event

-- Global state manager
Game.stateManager = nil

-- Debug systems
Game.debugConsole = nil      -- Alias stored on Game table
-- `debugConsole` is the variable used throughout the codebase;
-- we initialise/alias it in `initStates` so it’s always defined.
debugConsole = nil           -- Intentionally global for callbacks

-- Global resources (loaded once, shared across states)
Game.titleFont   = nil
Game.menuFont    = nil
Game.uiFont      = nil
Game.smallFont   = nil
Game.mediumFont  = nil
Game.uiManager   = nil

-- Audio resources
Game.laserSound        = nil
Game.explosionSound    = nil
Game.powerupSound      = nil
Game.shieldBreakSound  = nil
Game.gameOverSound     = nil
Game.menuSelectSound   = nil
Game.menuConfirmSound  = nil
Game.backgroundMusic   = nil
Game.bossMusic         = nil
Game.victorySound      = nil

-- Pre‑allocated laser sound clones for concurrent playback
Game.laserClones     = nil
Game.laserCloneIndex = 1

-- Positional audio settings
local soundReferenceDistance = 50
local soundMaxDistance       = 800

-- Audio lists for volume updates
local sfxSources   = {}
local musicSources = {}

-- Settings (persist across sessions)
Game.masterVolume     = constants.audio.defaultMasterVolume
Game.sfxVolume        = constants.audio.defaultSFXVolume
Game.musicVolume      = constants.audio.defaultMusicVolume
Game.displayMode      = "borderless"
Game.currentResolution = 1
Game.highContrast     = false
Game.fontScale        = 1

-- Input tracking
Game.lastInputType = "keyboard"  -- Default to keyboard/mouse
Game.inputHints = {
    keyboard = {
        select   = "Enter",
        back     = "ESC",
        navigate = "Arrow Keys",
        skip     = "SPACE",
        confirm  = "Enter",
        cancel   = "ESC",
        action   = "Space"
    },
    gamepad = {
        select   = "A",
        back     = "B",
        navigate = "D‑Pad",
        skip     = "A",
        confirm  = "A",
        cancel   = "B",
        action   = "X"
    }
}

-- Function to update last input type
function updateInputType(inputType)
    if Game.lastInputType ~= inputType then
        Game.lastInputType = inputType
        logger.debug("Input type changed to: %s", inputType)
    end
end

-- Window initialisation -----------------------------------------------------

local function initWindow()
    lw.setTitle("Stellar Assault")
    lw.setMode(800, 600, {
        fullscreen = false,
        resizable  = true,
        minwidth   = constants.window.minWidth,
        minheight  = constants.window.minHeight
    })

    lg.setDefaultFilter("nearest", "nearest")
    lg.setBackgroundColor(0.05, 0.05, 0.10)
end

-- Font loading --------------------------------------------------------------

local function loadFonts()
    Game.titleFont  = lg.newFont(48)
    Game.menuFont   = lg.newFont(24)
    Game.uiFont     = lg.newFont(18)
    Game.smallFont  = lg.newFont(14)
    Game.mediumFont = lg.newFont(20)
    Game.uiManager  = UIManager:new()

    -- Try to load monospace font, fall back to default
    if lf.getInfo("assets/fonts/monospace.ttf") then
        Game.consoleFont = lg.newFont("assets/fonts/monospace.ttf", 14)
    else
        Game.consoleFont = lg.newFont(14)
    end
end

-- Game state registration ---------------------------------------------------

local function initStates()
    -- Global state manager
    stateManager              = StateManager:new()  -- Intentional global for callbacks
    Game.stateManager         = stateManager

    stateManager:register("menu",        require("states.menu"))
    stateManager:register("intro",       require("states.intro"))
    stateManager:register("playing",     require("states.playing"))
    stateManager:register("pause",       require("states.pause"))
    stateManager:register("gameover",    require("states.gameover"))
    stateManager:register("options",     require("states.options"))
    stateManager:register("levelselect", require("states.levelselect"))
    stateManager:register("leaderboard", require("states.leaderboard"))

    -- Debug console setup (always define `debugConsole`)
    if CONFIG.debug then
        debugConsole = DebugConsole:new()
        local debugCommands = require("src.debugcommands")
        debugCommands.register(debugConsole)
    else
        debugConsole = {
            update     = function() end,
            draw       = function() end,
            keypressed = function() return false end,
            textinput  = function() return false end,
        }
    end
    Game.debugConsole = debugConsole  -- Alias for convenience
end

-- Audio ---------------------------------------------------------------------

local function loadAudio()
    la.setDistanceModel("inverseclamped")

    -- Helper to register SFX
    local function registerSfx(path, baseVolume)
        if not lf.getInfo(path) then return nil end
        local src = la.newSource(path, "static")
        src.baseVolume = baseVolume
        src:setVolume(src.baseVolume * Game.sfxVolume * Game.masterVolume)
        table.insert(sfxSources, src)
        return src
    end

    -- Helper to register Music
    local function registerMusic(path, baseVolume, looping)
        if not lf.getInfo(path) then return nil end
        local src = la.newSource(path, "stream")
        src.baseVolume = baseVolume
        src:setLooping(looping or false)
        src:setVolume(src.baseVolume * Game.musicVolume * Game.masterVolume)
        table.insert(musicSources, src)
        return src
    end

    -- Sound effects
    Game.laserSound       = registerSfx("laser.wav",        0.5)
    Game.explosionSound   = registerSfx("explosion.wav",    0.7)
    Game.powerupSound     = registerSfx("powerup.wav",      0.6)
    Game.shieldBreakSound = registerSfx("shield_break.wav", 0.7)
    Game.gameOverSound    = registerSfx("gameover.ogg",     0.8)
    Game.menuSelectSound  = registerSfx("menu.flac",        0.4)

    if Game.menuSelectSound then
        Game.menuConfirmSound            = Game.menuSelectSound:clone()
        Game.menuConfirmSound.baseVolume = Game.menuSelectSound.baseVolume
        Game.menuConfirmSound:setVolume(
            Game.menuConfirmSound.baseVolume * Game.sfxVolume * Game.masterVolume
        )
        table.insert(sfxSources, Game.menuConfirmSound)
    end

    -- Pre‑load laser clones for rapid firing
    if Game.laserSound then
        Game.laserClones = {}
        for i = 1, 5 do
            local c = Game.laserSound:clone()
            c.baseVolume = Game.laserSound.baseVolume
            c:setVolume(c.baseVolume * Game.sfxVolume * Game.masterVolume)
            table.insert(Game.laserClones, c)
            table.insert(sfxSources, c) -- include clones in volume updates
        end
        Game.laserCloneIndex = 1
    end

    -- Music
    Game.backgroundMusic = registerMusic("background.mp3", 1.0, true)
    Game.bossMusic       = registerMusic("boss.mp3",       0.8, true)
    Game.victorySound    = registerSfx  ("victory.ogg",    0.8) -- victory is SFX
end

-- Font scaling --------------------------------------------------------------

local function applyFontScale()
    Game.titleFont  = lg.newFont(48 * Game.fontScale)
    Game.menuFont   = lg.newFont(24 * Game.fontScale)
    Game.uiFont     = lg.newFont(18 * Game.fontScale)
    Game.smallFont  = lg.newFont(14 * Game.fontScale)
    Game.mediumFont = lg.newFont(20 * Game.fontScale)
end

-- Settings I/O --------------------------------------------------------------

local function loadSettings()
    if not lf.getInfo("settings.dat") then return end

    local lines = {}
    for line in lf.read("settings.dat"):gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    if #lines < 5 then return end

    Game.currentResolution = tonumber(lines[1]) or 1
    Game.displayMode       = lines[2] or "windowed"
    Game.masterVolume      = tonumber(lines[3]) or 1.0
    Game.sfxVolume         = tonumber(lines[4]) or 1.0
    Game.musicVolume       = tonumber(lines[5]) or 0.2

    if lines[6] then
        Game.selectedShip = lines[6]
        -- Validate selection
        local validShip = false
        for _, ship in ipairs(Game.availableShips or {}) do
            if ship == Game.selectedShip then
                validShip = true
                break
            end
        end
        if not validShip then Game.selectedShip = "alpha" end
    end

    if lines[7] then
        Game.highContrast = lines[7] == "true"
    end
    if lines[8] then
        Game.fontScale = tonumber(lines[8]) or 1
    end

    updateAudioVolumes()
    applyFontScale()
end

local function saveSettings()
    local data =
        Game.currentResolution .. "\n" ..
        Game.displayMode       .. "\n" ..
        Game.masterVolume      .. "\n" ..
        Game.sfxVolume         .. "\n" ..
        Game.musicVolume       .. "\n" ..
        Game.selectedShip      .. "\n" ..
        tostring(Game.highContrast) .. "\n" ..
        Game.fontScale

    lf.write("settings.dat", data)

    Persistence.updateSettings({
        masterVolume  = Game.masterVolume,
        sfxVolume     = Game.sfxVolume,
        musicVolume   = Game.musicVolume,
        selectedShip  = Game.selectedShip,
        displayMode   = Game.displayMode,
        highContrast  = Game.highContrast,
        fontScale     = Game.fontScale
    })
end

-- Window mode ---------------------------------------------------------------

local function applyWindowMode()
    -- Resolution options (must match states/options.lua)
    local resolutions = {
        {width =  800, height =  600},
        {width = 1024, height =  768},
        {width = 1280, height =  720},
        {width = 1366, height =  768},
        {width = 1920, height = 1080},
        {width = 2560, height = 1440}
    }

    local flags = {
        vsync     = 1,
        minwidth  = constants.window.minWidth,
        minheight = constants.window.minHeight
    }

    if Game.displayMode == "borderless" then
        -- Borderless (desktop) fullscreen
        flags.fullscreen     = true
        flags.fullscreentype = "desktop"
        flags.resizable      = false
        lw.setMode(0, 0, flags)  -- 0,0 => desktop dimensions
    elseif Game.displayMode == "fullscreen" then
        local res = resolutions[Game.currentResolution] or resolutions[1]
        flags.fullscreen     = true
        flags.fullscreentype = "exclusive"
        flags.resizable      = false
        lw.setMode(res.width, res.height, flags)
    else -- "windowed"
        local res = resolutions[Game.currentResolution] or resolutions[1]
        flags.fullscreen = false
        flags.borderless = false
        flags.resizable  = true
        lw.setMode(res.width, res.height, flags)
    end

    -- Re‑initialise starfield for new window size
    initStarfield()
end

-- Audio helper --------------------------------------------------------------

function updateAudioVolumes()
    for _, src in ipairs(sfxSources) do
        local base = src.baseVolume or 1
        src:setVolume(base * Game.sfxVolume * Game.masterVolume)
    end
    for _, src in ipairs(musicSources) do
        local base = src.baseVolume or 1
        src:setVolume(base * Game.musicVolume * Game.masterVolume)
    end
end

-- Positional SFX ------------------------------------------------------------

function playPositionalSound(source, x, y)
    if not source or not player then return end
    local clone

    -- Use pre‑loaded clones for laser
    if source == Game.laserSound and Game.laserClones then
        clone                   = Game.laserClones[Game.laserCloneIndex]
        Game.laserCloneIndex    = (Game.laserCloneIndex % #Game.laserClones) + 1
    else
        clone                   = source:clone()
        clone.baseVolume        = source.baseVolume
    end

    local dx, dy = x - player.x, y - player.y
    if clone:getChannelCount() == 1 then
        clone:setRelative(true)
        clone:setPosition(dx, dy, 0)
        clone:setAttenuationDistances(soundReferenceDistance, soundMaxDistance)
    end

    local base = clone.baseVolume or 1
    clone:setVolume(base * Game.sfxVolume * Game.masterVolume)
    clone:play()
end

-- Starfield -----------------------------------------------------------------

local stars      = {}
local starCount  = 200

function initStarfield()
    stars = {}
    for i = 1, starCount do
        table.insert(stars, {
            x     = love.math.random() * lg.getWidth(),
            y     = love.math.random() * lg.getHeight(),
            speed = love.math.random() * 50 + 20,
            size  = love.math.random() * 2
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
        local b = star.size / 2
        lg.setColor(b, b, b)
        lg.circle("fill", star.x, star.y, star.size)
    end
end

-- Make starfield helpers globally accessible to states
_G.initStarfield  = initStarfield
_G.updateStarfield = updateStarfield
_G.drawStarfield  = drawStarfield

-- Initial starfield
initStarfield()

-------------------------------------------------------------------------------
-- Love2D lifecycle                                                          --
-------------------------------------------------------------------------------

function love.load()
    initWindow()
    loadFonts()

    -- Load all sprites dynamically and categorise them
    local SpriteManager   = require("src.sprite_manager")
    Game.spriteManager    = SpriteManager.load("assets/sprites")

    -- Categorise by filename patterns
    Game.playerShips = Game.spriteManager:getCategory("player")
    Game.enemyShips  = Game.spriteManager:getCategory("enemy")

    -- Boss sprites handled as an ordered array
    Game.bossSprites = {}
    for name, sprite in pairs(Game.spriteManager:getCategory("boss")) do
        local idx = tonumber(name:match("%d+")) or (#Game.bossSprites + 1)
        Game.bossSprites[idx] = sprite
    end
    Game.bossSprite  = Game.bossSprites[1]
    Game.boss2Sprite = Game.bossSprites[2]

    -- Game configuration
    Game.availableShips = { "alpha", "beta", "gamma" }
    Game.selectedShip   = "alpha"

    -- Global sprite scale factor
    Game.spriteScale = 0.15

    -- Audio
    loadAudio()

    -- Persisted settings
    loadSettings()

    -- Apply window mode & fonts
    applyWindowMode()

    -- Persistence
    Persistence.init()
    local psettings   = Persistence.getSettings()
    Game.highContrast = psettings.highContrast or false
    Game.fontScale    = psettings.fontScale    or 1
    applyFontScale()

    -- States / debug console
    initStates()

    logger.info("Stellar Assault started")
    logger.info("Love2D version: %d.%d.%d", love.getVersion())
    logger.info("Resolution: %dx%d", lg.getWidth(), lg.getHeight())

    -- Start with main menu
    stateManager:switch("menu")
end

function love.update(dt)
    -- Cap delta to prevent giant jumps
    dt = math.min(dt, 1/30)

    -- Optional time scale
    if _G.timeScale then dt = dt * _G.timeScale end

    -- Background
    updateStarfield(dt)

    -- Debug console
    debugConsole:update(dt)

    -- Config reload notification
    if _G.configReloadNotification then
        _G.configReloadNotification.timer =
            _G.configReloadNotification.timer - dt
        if _G.configReloadNotification.timer <= 0 then
            _G.configReloadNotification = nil
        end
    end

    -- Current state
    stateManager:update(dt)
end

function love.draw()
    stateManager:draw()

    -- Debug info / overlay
    if debugMode   then drawDebugInfo()   end
    if debugOverlay then drawDebugOverlay() end

    -- Config reload notification
    if _G.configReloadNotification then
        local n = _G.configReloadNotification
        lg.setFont(Game.menuFont)
        lg.setColor(n.color[1], n.color[2], n.color[3], n.timer)
        lg.printf(n.text, 0, lg.getHeight()/2 - 50, lg.getWidth(), "center")
        lg.setColor(1,1,1,1)
    end

    -- Logger overlay
    if _G.showLogOverlay then
        logger.drawOverlay(10, lg.getHeight() - 200, 10)
    end

    -- Debug console
    debugConsole:draw()
end

function love.keypressed(key, scancode, isrepeat)
    updateInputType("keyboard")

    -- Debug console gets first dibs
    if debugConsole:keypressed(key) then return end

    if key == "f3" then
        debugMode = not debugMode
        logger.info("Debug mode: %s", debugMode and "enabled" or "disabled")
    elseif key == "f5" then
        -- Hot‑reload constants
        local ok, newConstants = pcall(function()
            package.loaded["src.constants"] = nil
            return require("src.constants")
        end)
        if ok then
            constants = newConstants
            logger.info("Config reloaded successfully")
            _G.configReloadNotification = {
                text  = "Config Reloaded!",
                timer = 2,
                color = {0,1,0}
            }
        else
            logger.error("Failed to reload config: %s", tostring(newConstants))
            _G.configReloadNotification = {
                text  = "Config Reload Failed!",
                timer = 2,
                color = {1,0,0}
            }
        end
    elseif key == "f9" then
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
    updateInputType("keyboard") -- Mouse counts as KB context
    stateManager:mousepressed(x, y, button, istouch, presses)
end

function love.mousemoved()
    updateInputType("keyboard")
end

function love.gamepadaxis(_, _, value)
    if math.abs(value) > 0.2 then updateInputType("gamepad") end
end

function love.gamepadpressed(joystick, button)
    updateInputType("gamepad")
    stateManager:gamepadpressed(joystick, button)
end

function love.gamepadreleased(joystick, button)
    stateManager:gamepadreleased(joystick, button)
end

function love.resize(w, h)
    initStarfield()
    stateManager:resize(w, h)
    logger.info("Window resized to %dx%d", w, h)
end

function love.textinput(text)
    debugConsole:textinput(text)
end

-------------------------------------------------------------------------------
-- Debug helpers                                                             --
-------------------------------------------------------------------------------

debugMode      = false
debugOverlay   = false
frameTimeHistory      = {}
maxFrameTimeHistory   = 60

local function drawDebugInfo()
    lg.setFont(Game.smallFont)
    lg.setColor(1,1,1,0.8)

    table.insert(frameTimeHistory, lt.getDelta())
    if #frameTimeHistory > maxFrameTimeHistory then
        table.remove(frameTimeHistory, 1)
    end

    local avg, max = 0, 0
    for _, dt in ipairs(frameTimeHistory) do
        avg = avg + dt
        if dt > max then max = dt end
    end
    avg = avg / #frameTimeHistory

    local info = {
        "FPS: "      .. lt.getFPS(),
        string.format("Memory: %.2f MB", collectgarbage("count")/1024),
        string.format("Delta: %.3f ms", lt.getAverageDelta()*1000),
        string.format("Avg Frame: %.3f ms", avg*1000),
        string.format("Max Frame: %.3f ms", max*1000),
        "State: "    .. (stateManager.currentName or "none"),
        string.format("Res: %dx%d", lg.getWidth(), lg.getHeight())
    }

    local y = 10
    for _, line in ipairs(info) do
        lg.print(line, lg.getWidth() - 150, y)
        y = y + 15
    end
end

local function drawDebugOverlay()
    lg.setFont(Game.smallFont)

    -- Semi‑transparent panel
    lg.setColor(0,0,0,0.7)
    lg.rectangle("fill", lg.getWidth()-250, 10, 240, 180, 5)

    lg.setColor(1,1,1,1)
    local x, y, lh = lg.getWidth()-240, 20, 18

    lg.print(string.format("Memory: %.2f MB", collectgarbage("count")/1024), x, y)
    y = y + lh

    if stateManager.currentState == stateManager.states.playing then
        lg.print("Entities:", x, y); y = y + lh
        lg.print(string.format("  Asteroids:  %d", asteroids and #asteroids or 0), x, y); y = y + lh
        lg.print(string.format("  Aliens:     %d", aliens    and #aliens    or 0), x, y); y = y + lh
        lg.print(string.format("  Lasers:     %d", lasers    and #lasers    or 0), x, y); y = y + lh
        lg.print(string.format("  Explosions: %d", explosions and #explosions or 0), x, y); y = y + lh
        lg.print(string.format("  Powerups:   %d", powerups  and #powerups  or 0), x, y); y = y + lh
    end

    y = y + lh
    lg.setColor(0.7,0.7,0.7,1)
    lg.print("F3: Debug Info",   x, y); y = y + lh
    lg.print("F5: Reload Config",x, y); y = y + lh
    lg.print("F9: Toggle Overlay",x,y)

    lg.setColor(1,1,1,1)
end

-------------------------------------------------------------------------------
-- Utility helpers                                                           --
-------------------------------------------------------------------------------

function saveGame(slot, level, score, lives)
    lf.write("save"..slot..".dat", table.concat({level,score,lives}, ","))
end

function checkCollision(a, b)
    local aw, ah = a.width  or a.size,  a.height  or a.size
    local bw, bh = b.width  or b.size,  b.height  or b.size

    return (a.x - aw/2) < (b.x + bw/2) and
           (a.x + aw/2) > (b.x - bw/2) and
           (a.y - ah/2) < (b.y + bh/2) and
           (a.y + ah/2) > (b.y - bh/2)
end

function love.quit()
    if Game.spriteManager and Game.spriteManager.reportUsage then
        Game.spriteManager:reportUsage()
    end
end
