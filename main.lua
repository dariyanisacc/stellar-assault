-- File: main.lua
------------------------------------------------------------------------------
-- Stellar Assault - Main Module
--   * Adds package.path entries so Lua can locate third-party libs inside src/
--   * Uses AssetManager for all fonts, images and sounds
------------------------------------------------------------------------------

-- Make module resolution robust across environments. We support both
-- `require("src.*")` and plain `require("states.*")` by ensuring the
-- root ("?.lua"/"?/init.lua") is present, as well as the "src/" forms.
local function ensure_path(p)
  if not package.path:find(p, 1, true) then
    package.path = p .. ";" .. package.path
  end
end
ensure_path("?.lua")
ensure_path("?/init.lua")
ensure_path("src/?.lua")
ensure_path("src/?/init.lua")

-- ---------------------------------------------------------------------------
-- Core modules (wrapped in error handler)
-- ---------------------------------------------------------------------------
local function abort(msg)
  local full = (tostring(msg) or "") .. "\n" .. debug.traceback("", 2) .. "\n"
  -- Try to persist an early crash log to the save directory
  local ok, err = pcall(function()
    local stamp = os.date("%Y%m%d_%H%M%S")
    local filename = string.format("crash_%s.log", stamp)
    if love and love.filesystem and love.filesystem.write then
      love.filesystem.write(filename, full)
    end
  end)
  if not ok then
    -- If filesystem write fails, still print to stderr
    full = full .. "\n(log write failed: " .. tostring(err) .. ")\n"
  end
  io.stderr:write(full)
  if love and love.event and love.event.quit then
    love.event.quit(1)
  end
end

xpcall(function()
  StateManager = require("src.core.statemachine")
  Helpers = require("src.core.helpers")
  constants = require("src.constants")
  DebugConsole = require("src.debugconsole")
  CONFIG = require("src.config")
  logger = require("src.logger")
  Persistence = require("src.persistence")
  UIManager = require("src.uimanager")
  AudioPool = require("src.audiopool")
  Mixer = require("src.Mixer")
  Game = require("src.game")
  AssetManager = require("src.asset_manager") -- NEW
end, abort)

-- ---------------------------------------------------------------------------
-- Cached Love2D handles & fixed-timestep vars
-- ---------------------------------------------------------------------------
local lg, la, lw, lt, lf = love.graphics, love.audio, love.window, love.timer, love.filesystem
local FIXED_DT, accumulator = 1 / 60, 0

-- ---------------------------------------------------------------------------
-- Globals stored on the Game table
-- ---------------------------------------------------------------------------
Game.stateManager = nil
Game.debugConsole = nil -- still referenced by some callbacks
debugConsole = nil -- legacy global for quick access

Game.titleFont, Game.menuFont, Game.uiFont = nil, nil, nil
Game.smallFont, Game.mediumFont = nil, nil
Game.uiManager = nil

Game.laserSound, Game.explosionSound = nil, nil
Game.powerupSound, Game.shieldBreakSound = nil, nil
Game.gameOverSound, Game.menuSelectSound = nil, nil
Game.menuConfirmSound = nil
Game.backgroundMusic, Game.bossMusic = nil, nil
Game.victorySound = nil

Game.audioPool = nil
Game.helpers = Helpers

local soundReferenceDistance, soundMaxDistance = 50, 800
Game.soundReferenceDistance = soundReferenceDistance
Game.soundMaxDistance = soundMaxDistance
local sfxSources, musicSources = {}, {}

Game.masterVolume = constants.audio.defaultMasterVolume
Game.sfxVolume = constants.audio.defaultSFXVolume
Game.musicVolume = constants.audio.defaultMusicVolume
Game.displayMode = "borderless"
Game.currentResolution = 1
Game.highContrast = false
Game.fontScale = 1
Game.uiScale = 1
Game.paletteName = constants.defaultPalette
Game.palette = constants.palettes[Game.paletteName]

Game.lastInputType = "keyboard"
Game.inputHints = {
  keyboard = {
    select = "Enter",
    back = "ESC",
    navigate = "Arrow Keys",
    skip = "SPACE",
    confirm = "Enter",
    cancel = "ESC",
    action = "Space",
  },
  gamepad = {
    select = "A",
    back = "B",
    navigate = "D-Pad",
    skip = "A",
    confirm = "A",
    cancel = "B",
    action = "X",
  },
}

-- Common resolution list used by window helpers
local RES_LIST = {
  { 800, 600 },
  { 1024, 768 },
  { 1280, 720 },
  { 1366, 768 },
  { 1920, 1080 },
  { 2560, 1440 },
}

-- Helper: apply Game.displayMode and Game.currentResolution to window
local function setWindowFromGame()
  local minw, minh = constants.window.minWidth, constants.window.minHeight
  local mode = Game.displayMode or "fullscreen"
  local function trySet(w, h, opts)
    local ok, err = pcall(lw.setMode, w, h, opts)
    if not ok then
      io.stderr:write("[Window] setMode failed: " .. tostring(err) .. "\n")
    end
    return ok
  end
  if mode == "borderless" then
    local dw, dh = lw.getDesktopDimensions()
    if not trySet(dw, dh, {
      fullscreen = false,
      borderless = true,
      resizable = false,
      vsync = 1,
      display = 1,
      minwidth = minw,
      minheight = minh,
    }) then
      -- Fallback to windowed 1280x720
      trySet(1280, 720, {
        fullscreen = false,
        borderless = false,
        resizable = true,
        minwidth = minw,
        minheight = minh,
      })
    end
    lw.setPosition(0, 0)
    lw.maximize()
  elseif mode == "fullscreen" then
    local idx = math.max(1, math.min(#RES_LIST, Game.currentResolution or 3))
    local rw, rh = RES_LIST[idx][1], RES_LIST[idx][2]
    if not trySet(rw, rh, {
      fullscreen = true,
      fullscreentype = "desktop",
      resizable = false,
      minwidth = minw,
      minheight = minh,
    }) then
      -- Fallback to borderless at desktop size
      local dw, dh = lw.getDesktopDimensions()
      if not trySet(dw, dh, {
        fullscreen = false,
        borderless = true,
        resizable = false,
        vsync = 1,
        display = 1,
        minwidth = minw,
        minheight = minh,
      }) then
        -- Final fallback to windowed 1280x720
        trySet(1280, 720, {
          fullscreen = false,
          borderless = false,
          resizable = true,
          minwidth = minw,
          minheight = minh,
        })
      end
      Game.displayMode = "borderless"
    end
  else -- windowed
    local idx = math.max(1, math.min(#RES_LIST, Game.currentResolution or 3))
    local rw, rh = RES_LIST[idx][1], RES_LIST[idx][2]
    if not trySet(rw, rh, {
      fullscreen = false,
      borderless = false,
      resizable = true,
      minwidth = minw,
      minheight = minh,
    }) then
      trySet(1280, 720, {
        fullscreen = false,
        borderless = false,
        resizable = true,
        minwidth = minw,
        minheight = minh,
      })
    end
  end
end

-- Compute UI scale based on window size to keep UI readable
local function updateUiScale()
  local w, h = lg.getWidth(), lg.getHeight()
  local sx = w / 1280
  local sy = h / 720
  Game.uiScale = math.max(0.75, math.min(1.35, math.min(sx, sy)))
end

-- Toggle between fullscreen and windowed, then persist settings
local function toggleFullscreen()
  if Game.displayMode == "windowed" then
    Game.displayMode = "fullscreen"
  else
    -- Treat both fullscreen and borderless as fullscreen for toggling
    Game.displayMode = "windowed"
  end
  setWindowFromGame()
  if Persistence and Persistence.updateSettings then
    Persistence.updateSettings({
      displayMode = Game.displayMode,
      resolutionIndex = Game.currentResolution,
    })
  end
end
_G.toggleFullscreen = toggleFullscreen

-- ---------------------------------------------------------------------------
-- Helper: track last input device
-- ---------------------------------------------------------------------------
local function updateInputType(t)
  if Game.lastInputType ~= t then
    Game.lastInputType = t
    logger.debug("Input type changed to: %s", t)
  end
end

-- ---------------------------------------------------------------------------
-- Window creation
-- ---------------------------------------------------------------------------
local function initWindow()
  lw.setTitle("Stellar Assault")

  -- Load saved settings to decide display mode
  local settings = Persistence and Persistence.getSettings and Persistence.getSettings() or {}
  Game.masterVolume = settings.masterVolume or Game.masterVolume
  Game.sfxVolume    = settings.sfxVolume or Game.sfxVolume
  Game.musicVolume  = settings.musicVolume or Game.musicVolume
  Game.displayMode  = settings.displayMode or Game.displayMode or "borderless"
  Game.selectedShip = settings.selectedShip or Game.selectedShip or "falcon"
  -- Back-compat migration for saved ids
  do
    local migrate = { alpha = "falcon", beta = "wraith", gamma = "titan" }
    if migrate[Game.selectedShip] then
      Game.selectedShip = migrate[Game.selectedShip]
    end
  end
  _G.selectedShip   = Game.selectedShip
  Game.fontScale    = settings.fontScale or Game.fontScale or 1
  Game.highContrast = settings.highContrast or false
  Game.paletteName  = settings.palette or Game.paletteName or constants.defaultPalette
  Game.currentResolution = settings.resolutionIndex or Game.currentResolution or 3
  -- Background visual toggles
  Game.bgParallax   = (settings.bgParallax == nil) and true or settings.bgParallax
  Game.bgDim        = (settings.bgDim == nil) and true or settings.bgDim

  lg.setDefaultFilter("nearest", "nearest")
  lg.setBackgroundColor(0.05, 0.05, 0.10)
  setWindowFromGame()
  updateUiScale()
end

-- ---------------------------------------------------------------------------
-- Font loading (now via AssetManager)
-- ---------------------------------------------------------------------------
local function loadFonts()
  -- Prefer Kenney Sci‑Fi font if available
  local kenney = "assets/kenny assets/UI Pack - Sci-fi/Fonts/kenvector_future.ttf"
  if lf.getInfo(kenney, "file") then
    Game.fontPath = kenney
    Game.titleFont = AssetManager.getFont(kenney, 48)
    Game.menuFont  = AssetManager.getFont(kenney, 24)
    Game.uiFont    = AssetManager.getFont(kenney, 18)
    Game.smallFont = AssetManager.getFont(kenney, 14)
  else
    Game.fontPath = nil
    Game.titleFont = AssetManager.getFont(48)
    Game.menuFont  = AssetManager.getFont(24)
    Game.uiFont    = AssetManager.getFont(18)
    Game.smallFont = AssetManager.getFont(14)
  end
  if Game.fontPath then
    Game.mediumFont = AssetManager.getFont(Game.fontPath, 20)
  else
    Game.mediumFont = AssetManager.getFont(20)
  end

  Game.uiManager = UIManager:new()

  -- Optional console font
  if lf.getInfo("assets/fonts/monospace.ttf") then
    Game.consoleFont = AssetManager.getFont("assets/fonts/monospace.ttf", 14)
  else
    Game.consoleFont = AssetManager.getFont(14)
  end
end

-- ---------------------------------------------------------------------------
-- Game-state registration
-- ---------------------------------------------------------------------------
local function initStates()
  stateManager = StateManager:new()
  Game.stateManager = stateManager

  stateManager:register("loading", require("states.loading")) -- NEW
  stateManager:register("menu", require("states.menu"))
  stateManager:register("intro", require("states.intro"))
  stateManager:register("playing", require("states.playing"))
  stateManager:register("pause", require("states.pause"))
  stateManager:register("gameover", require("states.gameover"))
  stateManager:register("options", require("states.options"))
  stateManager:register("options_controls", require("states.options_controls"))
  stateManager:register("levelselect", require("states.levelselect"))
  stateManager:register("leaderboard", require("states.leaderboard"))

  -- Console setup
  if CONFIG.debug then
    debugConsole = DebugConsole:new()
    require("src.debugcommands").register(debugConsole)
  else
    debugConsole = {
      update = function() end,
      draw = function() end,
      keypressed = function()
        return false
      end,
      textinput = function()
        return false
      end,
    }
  end
  Game.debugConsole = debugConsole
end

-- ---------------------------------------------------------------------------
-- Audio helpers (using AssetManager for sources)
-- ---------------------------------------------------------------------------
local AudioUtils = require("src.audioutils")

local function registerSfx(path, base)
  local src = AssetManager.getSound(path, "static")
  if not src then
    return nil
  end
  AudioUtils.setBaseVolume(src, base)
  src:setVolume((AudioUtils.getBaseVolume(src) or 1) * Game.sfxVolume * Game.masterVolume)
  table.insert(sfxSources, src)
  return src
end

local function registerMusic(path, base, loop)
  local src = AssetManager.getSound(path, "stream")
  if not src then
    return nil
  end
  AudioUtils.setBaseVolume(src, base)
  src:setLooping(loop)
  src:setVolume((AudioUtils.getBaseVolume(src) or 1) * Game.musicVolume * Game.masterVolume)
  table.insert(musicSources, src)
  return src
end

local function loadAudio()
  la.setDistanceModel("inverseclamped")

  -- Mixer groups for live volume control
  Game.mixer = Mixer.new()

  local sounds = constants.sounds or {}
  local function findKenneySound(keyword)
    local baseDir = "assets/kenny assets/Sci-Fi Sounds/Audio"
    if not lf.getInfo(baseDir, "directory") then return nil end
    local best
    for _, f in ipairs(lf.getDirectoryItems(baseDir)) do
      local lower = f:lower()
      if lower:find(keyword:lower(), 1, true) and lower:sub(-4) == ".ogg" then
        best = baseDir .. "/" .. f
        if lower:find("000", 1, true) then break end -- prefer _000 if found
      end
    end
    return best
  end
  if sounds.laser then
    Game.laserSound = registerSfx(sounds.laser, 0.5) or (function()
      local p = findKenneySound("laser")
      if p then return registerSfx(p, 0.5) end
    end)()
  end
  if sounds.explosion then
    Game.explosionSound = registerSfx(sounds.explosion, 0.7) or (function()
      local p = findKenneySound("explosion")
      if p then return registerSfx(p, 0.7) end
    end)()
  end
  if sounds.powerup then
    Game.powerupSound = registerSfx(sounds.powerup, 0.6) or (function()
      local p = findKenneySound("powerup") or findKenneySound("powerUp")
      if p then return registerSfx(p, 0.6) end
    end)()
  end
  if sounds.shield_break then
    Game.shieldBreakSound = registerSfx(sounds.shield_break, 0.7) or (function()
      local p = findKenneySound("impact") or findKenneySound("metal")
      if p then return registerSfx(p, 0.7) end
    end)()
  end
  if sounds.gameover then
    Game.gameOverSound = registerSfx(sounds.gameover, 0.8) or (function()
      local p = findKenneySound("computerNoise_001") or findKenneySound("computerNoise")
      if p then return registerSfx(p, 0.8) end
    end)()
  end
  if sounds.menu then
    Game.menuSelectSound = registerSfx(sounds.menu, 0.4) or (function()
      local p = findKenneySound("computerNoise_000") or findKenneySound("computerNoise")
      if p then return registerSfx(p, 0.4) end
    end)()
  end
  if sounds.victory then
    Game.victorySound = registerSfx(sounds.victory, 0.8) or (function()
      local p = findKenneySound("computerNoise_003") or findKenneySound("computerNoise")
      if p then return registerSfx(p, 0.8) end
    end)()
  end

  if Game.menuSelectSound then
    Game.menuConfirmSound = Game.menuSelectSound:clone()
    AudioUtils.setBaseVolume(Game.menuConfirmSound, AudioUtils.getBaseVolume(Game.menuSelectSound))
    Game.menuConfirmSound:setVolume(
      (AudioUtils.getBaseVolume(Game.menuConfirmSound) or 1) * Game.sfxVolume * Game.masterVolume
    )
    table.insert(sfxSources, Game.menuConfirmSound)
  end

  -- Helper to gather sibling variants (e.g., laser_1.ogg, laser2.ogg)
  local function collectVariants(basePath)
    local dir = basePath:match("^(.*)/[^/]+$") or "."
    local base = basePath:match("([^/]+)%.%w+$") or basePath
    local ext = basePath:match("%.(%w+)$") or "ogg"
    local variants = {}
    if lf.getInfo(dir, "directory") then
      for _, f in ipairs(lf.getDirectoryItems(dir)) do
        if f:lower() ~= (base .. "." .. ext):lower() then
          local name = f:lower()
          if name:match("^" .. base:lower():gsub("%s","%%s") .. "[_%-]?%d+")
            or name:match("^" .. base:lower():gsub("%s","%%s") .. ".-%." .. ext:lower() .. "$")
          then
            if name:sub(-(#ext + 1)) == "." .. ext:lower() then
              local full = dir .. "/" .. f
              local s = AssetManager.getSound(full, "static")
              if s then
                local bv = (Game.laserSound and AudioUtils.getBaseVolume(Game.laserSound)) or 0.6
                AudioUtils.setBaseVolume(s, bv)
                table.insert(variants, s)
              end
            end
          end
        end
      end
    end
    return variants
  end

  Game.audioPool = AudioPool:new(8, sfxSources)
  -- Laser
  local laserVariants = {}
  if constants.sounds.laser then
    laserVariants = collectVariants(constants.sounds.laser)
  end
  if #laserVariants > 0 and Game.laserSound then
    table.insert(laserVariants, 1, Game.laserSound)
    Game.audioPool:registerVariants("laser", laserVariants)
  else
    Game.audioPool:register("laser", Game.laserSound)
  end
  -- Explosion
  local explosionVariants = {}
  if constants.sounds.explosion then
    explosionVariants = collectVariants(constants.sounds.explosion)
  end
  if #explosionVariants > 0 and Game.explosionSound then
    table.insert(explosionVariants, 1, Game.explosionSound)
    Game.audioPool:registerVariants("explosion", explosionVariants)
  else
    Game.audioPool:register("explosion", Game.explosionSound)
  end
  -- Others
  Game.audioPool:register("powerup", Game.powerupSound)
  Game.audioPool:register("shield_break", Game.shieldBreakSound)
  Game.audioPool:register("gameover", Game.gameOverSound)
  Game.audioPool:register("menu_select", Game.menuSelectSound)
  Game.audioPool:register("menu_confirm", Game.menuConfirmSound)
  Game.audioPool:register("victory", Game.victorySound)

  -- Back-compat: expose commonly used menu SFX as globals for legacy states
  _G.menuSelectSound  = Game.menuSelectSound
  _G.menuConfirmSound = Game.menuConfirmSound

  if sounds.background then
    Game.backgroundMusic = registerMusic(sounds.background, 1.0, true)
      or (function() local p = findKenneySound("computerNoise_004") or findKenneySound("computerNoise"); if p then return registerMusic(p, 1.0, true) end end)()
  end
  if sounds.boss then
    Game.bossMusic = registerMusic(sounds.boss, 0.8, true)
      or (function() local p = findKenneySound("computerNoise_002") or findKenneySound("computerNoise"); if p then return registerMusic(p, 0.8, true) end end)()
  end

  -- Register all sources with Mixer groups (after AudioPool created clones)
  for _, s in ipairs(sfxSources) do
    Game.mixer:register(s, "sfx")
  end
  for _, m in ipairs(musicSources) do
    Game.mixer:register(m, "music")
  end
end

-- ---------------------------------------------------------------------------
-- Settings helpers (font scaling, palette, saving, etc.)
-- ---------------------------------------------------------------------------
local function applyFontScale()
  local path = Game.fontPath -- may be nil
  local function gf(sz)
    if path then return AssetManager.getFont(path, sz) else return AssetManager.getFont(sz) end
  end
  Game.titleFont = gf(48 * Game.fontScale)
  Game.menuFont  = gf(24 * Game.fontScale)
  Game.uiFont    = gf(18 * Game.fontScale)
  Game.smallFont = gf(14 * Game.fontScale)
  Game.mediumFont = gf(20 * Game.fontScale)
end
_G.applyFontScale = applyFontScale

local function applyPalette()
  Game.palette = constants.palettes[Game.paletteName]
    or constants.palettes[constants.defaultPalette]
end
_G.applyPalette = applyPalette

local function updateAudioVolumes()
  for _, s in ipairs(sfxSources) do
    local bv = (AudioUtils.getBaseVolume(s) or 1)
    s:setVolume(bv * Game.sfxVolume * Game.masterVolume)
  end
  for _, s in ipairs(musicSources) do
    local bv = (AudioUtils.getBaseVolume(s) or 1)
    s:setVolume(bv * Game.musicVolume * Game.masterVolume)
  end
end
_G.updateAudioVolumes = updateAudioVolumes

-- … (all existing settings-load / save code remains unchanged) …

-- ---------------------------------------------------------------------------
-- Starfield helpers (unchanged except for tidy formatting)
-- ---------------------------------------------------------------------------
local Starfield = require("src.starfield")
local starfield
local function initStarfield()
  starfield = Starfield.new(200)
end
local function updateStarfield(dt)
  if starfield then
    starfield:update(dt)
  end
end
local function drawStarfield()
  if starfield then
    starfield:draw()
  end
end
_G.initStarfield, _G.updateStarfield, _G.drawStarfield =
  initStarfield, updateStarfield, drawStarfield

-- ---------------------------------------------------------------------------
-- Expose init helpers (for hot-reload convenience)
-- ---------------------------------------------------------------------------
_G.initWindow, _G.loadFonts, _G.loadAudio, _G.initStates =
  initWindow, loadFonts, loadAudio, initStates

-- ---------------------------------------------------------------------------
-- Love2D callbacks
-- ---------------------------------------------------------------------------
function love.load()
  initWindow()

  -- Make AssetManager globally reachable for other systems that hot-reload
  Game.assetManager = AssetManager
  -- Optional sprite manager for audits
  local SpriteManager = require("src.sprite_manager")
  Game.sprites = SpriteManager.load("assets/gfx")
  _G.reportUnusedSprites = function()
    if Game and Game.sprites and Game.sprites.reportUsage then
      Game.sprites:reportUsage()
    end
  end

  loadFonts()
  loadAudio()
  -- Apply saved preferences to fonts, palette, and audio volumes
  if applyFontScale then applyFontScale() end
  if applyPalette then applyPalette() end
  if updateAudioVolumes then updateAudioVolumes() end
  updateUiScale()
  -- Background
  if initStarfield then
    initStarfield()
  end

  -- Lightweight boot: only load a minimal set of sprites needed for menus;
  -- gameplay will fall back to simple shapes if sprites are absent.
  local lf = love.filesystem
  Game.playerShips, Game.enemyShips, Game.bossSprites = {}, {}, {}
  Game.spriteByKey = {}
  local function tryImg(path)
    if lf.getInfo(path, "file") then
      local ok, img = pcall(function() return AssetManager.getImage(path) end)
      if ok and img and img.setFilter then img:setFilter("linear", "linear") end
      return ok and img or nil
    end
    return nil
  end
  -- Attempt to load the three player ships by known filenames
  -- Legacy names (alpha/beta/gamma)
  Game.playerShips.alpha = tryImg("assets/gfx/ship_alpha@1024x1024.png")
  Game.playerShips.beta  = tryImg("assets/gfx/Player Ship Beta.png")
  Game.playerShips.gamma = tryImg("assets/gfx/Player Ship Gamma.png")
  -- New canonical ids (falcon/wraith/titan) map to legacy sprites if present
  Game.playerShips.falcon = Game.playerShips.alpha or Game.playerShips.falcon
  Game.playerShips.wraith = Game.playerShips.beta  or Game.playerShips.wraith
  Game.playerShips.titan  = Game.playerShips.gamma or Game.playerShips.titan

  -- Load enemy ship sprites by known filenames (fallback to rectangles if missing)
  -- Keys match behavior/type used by WaveManager and PlayingState (basic, homing, zigzag, dive, formation)
  Game.enemyShips.basic     = tryImg("assets/gfx/Enemy Basic.png")
  Game.enemyShips.homing    = tryImg("assets/gfx/Enemy Homing.png")
  Game.enemyShips.zigzag    = tryImg("assets/gfx/Enemy ZigZag.png")
  Game.enemyShips.dive      = tryImg("assets/gfx/Enemy Dive.png")
  Game.enemyShips.formation = tryImg("assets/gfx/Enemy Formation.png")

  -- Kenny assets: load nicer laser sprites if available
  do
    local function tryLaser(path)
      if lf.getInfo(path, "file") then
        local ok, img = pcall(function() return AssetManager.getImage(path) end)
        if ok and img and img.setFilter then img:setFilter("linear", "linear") end
        return ok and img or nil
      end
      return nil
    end
    Game.laserSpritePlayer =
      tryLaser("assets/kenny assets/Lasers/laserBlue2.png")
      or tryLaser("assets/kenny assets/Lasers/laserBlue3.png")
      or nil
    Game.laserSpriteAlien =
      tryLaser("assets/kenny assets/Lasers/laserPink2.png")
      or tryLaser("assets/kenny assets/Lasers/laserPink3.png")
      or tryLaser("assets/kenny assets/Lasers/laserGreen2.png")
      or nil
    -- Use a yellow laser as a missile sprite stand-in if available
    Game.missileSprite =
      tryLaser("assets/kenny assets/Lasers/laserYellow3.png")
      or tryLaser("assets/kenny assets/Lasers/laserYellow2.png")
      or nil
  end

  -- Asteroids: load up to three variant sprites if available
  do
    local paths = {
      "assets/gfx/asteroid 1.png",
      "assets/gfx/asteroid 2.png",
      "assets/gfx/asteroid 3.png",
    }
    Game.asteroidSprites = {}
    for _, p in ipairs(paths) do
      if lf.getInfo(p, "file") then
        local ok, img = pcall(function() return AssetManager.getImage(p) end)
        if ok and img then
          if img.setFilter then img:setFilter("linear", "linear") end
          table.insert(Game.asteroidSprites, img)
        end
      end
    end
  end

  -- Debris shards: load Kenny burst sprites for explosion particles
  do
    Game.debrisSprites = {}
    local names = {
      "laserBlue_burst.png",
      "laserPink_burst.png",
      "laserGreen_burst.png",
      "laserYellow_burst.png",
      "laserBeige_burst.png",
    }
    for _, n in ipairs(names) do
      local p = "assets/kenny assets/Lasers/" .. n
      if lf.getInfo(p, "file") then
        local ok, img = pcall(function() return AssetManager.getImage(p) end)
        if ok and img then
          if img.setFilter then img:setFilter("linear", "linear") end
          table.insert(Game.debrisSprites, img)
        end
      end
    end
  end

  -- Back-compat globals for modules expecting these names
  _G.playerShips = Game.playerShips
  _G.enemyShips  = Game.enemyShips
  _G.bossSprites = Game.bossSprites
  _G.bossSprite  = Game.bossSprites[1]
  _G.boss2Sprite = Game.bossSprites[2]

  Game.availableShips = { "falcon", "titan", "wraith" }
  -- Back-compat: migrate old ids to new ids
  local migrate = { alpha = "falcon", beta = "wraith", gamma = "titan" }
  if Game.selectedShip and migrate[Game.selectedShip] then
    Game.selectedShip = migrate[Game.selectedShip]
  end
  Game.selectedShip = Game.selectedShip or "falcon"
  _G.selectedShip = Game.selectedShip
  Game.spriteScale = 0.15

  initStates()
  logger.info("Stellar Assault started")
  stateManager:switch("loading", { nextState = "menu" }) -- NEW bootstrap flow
end

-- ---------------------------------------------------------------------------
-- Crash-log wrapper for love.run
-- ---------------------------------------------------------------------------
do
  local originalRun = love.run
  ---@diagnostic disable-next-line: duplicate-set-field
  function love.run(...)
    local ok, res = xpcall(originalRun, debug.traceback, ...)
    if not ok then
      local stamp = os.date("%Y%m%d_%H%M%S")
      love.filesystem.write(string.format("crash_%s.log", stamp), res)
      -- Exit cleanly after logging instead of returning nil
      return function()
        return 1
      end
    end
    -- On success, return the function that Love expects and provided
    return res
  end
end

-- ---------------------------------------------------------------------------
-- Frame loop and input routing
-- ---------------------------------------------------------------------------
function love.update(dt)
  -- Fixed timestep update for deterministic simulation
  -- Also decay any recent gamepad axis activity timer
  if Game and Game.gamepadActiveTimer and Game.gamepadActiveTimer > 0 then
    Game.gamepadActiveTimer = math.max(0, Game.gamepadActiveTimer - dt)
  end
  accumulator = accumulator + dt
  while accumulator >= FIXED_DT do
    if stateManager and stateManager.update then
      stateManager:update(FIXED_DT)
    end
    if updateStarfield then
      updateStarfield(FIXED_DT)
    end
    if Game and Game.debugConsole and Game.debugConsole.update then
      Game.debugConsole:update(FIXED_DT)
    end
    if updateUiScale then updateUiScale() end
    accumulator = accumulator - FIXED_DT
  end
end

function love.draw()
  if drawStarfield then
    drawStarfield()
  end
  if stateManager and stateManager.draw then
    stateManager:draw()
  end
  if Game and Game.debugConsole and Game.debugConsole.draw then
    Game.debugConsole:draw()
  end
  -- Minimal input hint bar in menus and overlays
  local allowed = {
    menu = true, pause = true, options = true, options_controls = true,
    levelselect = true, leaderboard = true, gameover = true,
  }
  if Game and Game.uiManager and (allowed[(stateManager and stateManager.currentName) or ""] == true) then
    Game.uiManager:drawInputHints()
  end
end

function love.keypressed(key, scancode, isrepeat)
  updateInputType("keyboard")
  -- Global fullscreen toggle
  if key == "f11" then
    toggleFullscreen()
    return
  end
  local consumed = false
  if Game and Game.debugConsole and Game.debugConsole.keypressed then
    consumed = Game.debugConsole:keypressed(key, scancode, isrepeat) or false
  end
  if not consumed and stateManager and stateManager.keypressed then
    stateManager:keypressed(key, scancode, isrepeat)
  end
end

-- Key release routing was missing, causing "stuck" inputs.
function love.keyreleased(key, scancode)
  updateInputType("keyboard")
  -- Debug console typically ignores key releases, but keep the hook symmetrical.
  local consumed = false
  if Game and Game.debugConsole and Game.debugConsole.keyreleased then
    consumed = Game.debugConsole:keyreleased(key, scancode) or false
  end
  if not consumed and stateManager and stateManager.keyreleased then
    stateManager:keyreleased(key, scancode)
  end
end

function love.textinput(t)
  if Game and Game.debugConsole and Game.debugConsole.textinput then
    Game.debugConsole:textinput(t)
  end
end

function love.gamepadpressed(joystick, button)
  updateInputType("gamepad")
  if stateManager and stateManager.gamepadpressed then
    stateManager:gamepadpressed(joystick, button)
  end
end

function love.gamepadreleased(joystick, button)
  if stateManager and stateManager.gamepadreleased then
    stateManager:gamepadreleased(joystick, button)
  end
end

-- Track analog stick activity to suppress drift unless there is recent input
function love.gamepadaxis(joystick, axis, value)
  local dz = (Game and Game.gamepadDeadzone) or 0.35
  if math.abs(value or 0) > dz then
    updateInputType("gamepad")
    if Game then
      Game.gamepadActiveTimer = (Game.gamepadActiveTimeout or 1.0)
    end
  end
end

function love.mousepressed(x, y, button, istouch, presses)
  if stateManager and stateManager.mousepressed then
    stateManager:mousepressed(x, y, button, istouch, presses)
  end
end

function love.resize(w, h)
  if stateManager and stateManager.resize then
    stateManager:resize(w, h)
  end
  updateUiScale()
end

-- Clear held inputs on focus loss to avoid sticky movement/shoot
function love.focus(f)
  if not f and stateManager and stateManager.current and stateManager.current.keys then
    local keys = stateManager.current.keys
    for k in pairs(keys) do keys[k] = false end
  end
end
