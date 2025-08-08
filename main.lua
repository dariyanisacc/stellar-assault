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
  if mode == "borderless" then
    local dw, dh = lw.getDesktopDimensions()
    lw.setMode(dw, dh, {
      fullscreen = false,
      borderless = true,
      resizable = false,
      vsync = 1,
      display = 1,
      minwidth = minw,
      minheight = minh,
    })
    lw.setPosition(0, 0)
    lw.maximize()
  elseif mode == "fullscreen" then
    local idx = math.max(1, math.min(#RES_LIST, Game.currentResolution or 3))
    local rw, rh = RES_LIST[idx][1], RES_LIST[idx][2]
    lw.setMode(rw, rh, {
      fullscreen = true,
      fullscreentype = "exclusive",
      resizable = false,
      minwidth = minw,
      minheight = minh,
    })
  else -- windowed
    local idx = math.max(1, math.min(#RES_LIST, Game.currentResolution or 3))
    local rw, rh = RES_LIST[idx][1], RES_LIST[idx][2]
    lw.setMode(rw, rh, {
      fullscreen = false,
      borderless = false,
      resizable = true,
      minwidth = minw,
      minheight = minh,
    })
  end
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
  Game.displayMode  = settings.displayMode or Game.displayMode or "fullscreen"
  Game.selectedShip = settings.selectedShip or Game.selectedShip or "alpha"
  _G.selectedShip   = Game.selectedShip
  Game.fontScale    = settings.fontScale or Game.fontScale or 1
  Game.highContrast = settings.highContrast or false
  Game.paletteName  = settings.palette or Game.paletteName or constants.defaultPalette
  Game.currentResolution = settings.resolutionIndex or Game.currentResolution or 3

  lg.setDefaultFilter("nearest", "nearest")
  lg.setBackgroundColor(0.05, 0.05, 0.10)
  setWindowFromGame()
end

-- ---------------------------------------------------------------------------
-- Font loading (now via AssetManager)
-- ---------------------------------------------------------------------------
local function loadFonts()
  Game.titleFont = AssetManager.getFont(48)
  Game.menuFont = AssetManager.getFont(24)
  Game.uiFont = AssetManager.getFont(18)
  Game.smallFont = AssetManager.getFont(14)
  Game.mediumFont = AssetManager.getFont(20)
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
local function registerSfx(path, base)
  local src = AssetManager.getSound(path, "static")
  if not src then
    return nil
  end
  src.baseVolume = base
  src:setVolume(base * Game.sfxVolume * Game.masterVolume)
  table.insert(sfxSources, src)
  return src
end

local function registerMusic(path, base, loop)
  local src = AssetManager.getSound(path, "stream")
  if not src then
    return nil
  end
  src.baseVolume = base
  src:setLooping(loop)
  src:setVolume(base * Game.musicVolume * Game.masterVolume)
  table.insert(musicSources, src)
  return src
end

local function loadAudio()
  la.setDistanceModel("inverseclamped")

  local sounds = constants.sounds or {}
  if sounds.laser then
    Game.laserSound = registerSfx(sounds.laser, 0.5)
  end
  if sounds.explosion then
    Game.explosionSound = registerSfx(sounds.explosion, 0.7)
  end
  if sounds.powerup then
    Game.powerupSound = registerSfx(sounds.powerup, 0.6)
  end
  if sounds.shield_break then
    Game.shieldBreakSound = registerSfx(sounds.shield_break, 0.7)
  end
  if sounds.gameover then
    Game.gameOverSound = registerSfx(sounds.gameover, 0.8)
  end
  if sounds.menu then
    Game.menuSelectSound = registerSfx(sounds.menu, 0.4)
  end
  if sounds.victory then
    Game.victorySound = registerSfx(sounds.victory, 0.8)
  end

  if Game.menuSelectSound then
    Game.menuConfirmSound = Game.menuSelectSound:clone()
    Game.menuConfirmSound.baseVolume = Game.menuSelectSound.baseVolume
    Game.menuConfirmSound:setVolume(
      Game.menuConfirmSound.baseVolume * Game.sfxVolume * Game.masterVolume
    )
    table.insert(sfxSources, Game.menuConfirmSound)
  end

  Game.audioPool = AudioPool:new(8, sfxSources)
  Game.audioPool:register("laser", Game.laserSound)
  Game.audioPool:register("explosion", Game.explosionSound)
  Game.audioPool:register("powerup", Game.powerupSound)
  Game.audioPool:register("shield_break", Game.shieldBreakSound)
  Game.audioPool:register("gameover", Game.gameOverSound)
  Game.audioPool:register("menu_select", Game.menuSelectSound)
  Game.audioPool:register("menu_confirm", Game.menuConfirmSound)
  Game.audioPool:register("victory", Game.victorySound)

  if sounds.background then
    Game.backgroundMusic = registerMusic(sounds.background, 1.0, true)
  end
  if sounds.boss then
    Game.bossMusic = registerMusic(sounds.boss, 0.8, true)
  end
end

-- ---------------------------------------------------------------------------
-- Settings helpers (font scaling, palette, saving, etc.)
-- ---------------------------------------------------------------------------
local function applyFontScale()
  Game.titleFont = AssetManager.getFont(48 * Game.fontScale)
  Game.menuFont = AssetManager.getFont(24 * Game.fontScale)
  Game.uiFont = AssetManager.getFont(18 * Game.fontScale)
  Game.smallFont = AssetManager.getFont(14 * Game.fontScale)
  Game.mediumFont = AssetManager.getFont(20 * Game.fontScale)
end
_G.applyFontScale = applyFontScale

local function applyPalette()
  Game.palette = constants.palettes[Game.paletteName]
    or constants.palettes[constants.defaultPalette]
end
_G.applyPalette = applyPalette

local function updateAudioVolumes()
  for _, s in ipairs(sfxSources) do
    s:setVolume((s.baseVolume or 1) * Game.sfxVolume * Game.masterVolume)
  end
  for _, s in ipairs(musicSources) do
    s:setVolume((s.baseVolume or 1) * Game.musicVolume * Game.masterVolume)
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
  -- Background
  if initStarfield then
    initStarfield()
  end

  -- Images / sprites: scan assets/gfx and populate Game sprite tables
  local lf = love.filesystem
  local function keyForPng(filename)
    local base = filename:gsub("%.png$", "")
    local k = base:lower():gsub("%s+", "_")
    if k:find("^player_ship_") then
      k = k:gsub("^player_ship_", "player_")
    elseif k:find("^ship_alpha") then
      k = "player_alpha"
    end
    return k
  end

  Game.playerShips, Game.enemyShips, Game.bossSprites = {}, {}, {}
  Game.spriteByKey = {}
  if lf.getInfo("assets/gfx", "directory") then
    for _, name in ipairs(lf.getDirectoryItems("assets/gfx")) do
      if name:lower():sub(-4) == ".png" then
        local key = keyForPng(name)
        local img = AssetManager.getImage("assets/gfx/" .. name)
        if img then
          Game.spriteByKey[key] = img
          if key:find("^player_") then
            local ship = key:match("^player_(.+)$")
            if ship then Game.playerShips[ship] = img end
          elseif key:find("^enemy_") then
            local etype = key:match("^enemy_(.+)$")
            if etype then Game.enemyShips[etype] = img end
          elseif key:find("^boss_") then
            local id = tonumber(key:match("^boss_(%d+)$") or "")
            if id then Game.bossSprites[id] = img end
          end
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

  Game.availableShips = { "alpha", "beta", "gamma" }
  Game.selectedShip = Game.selectedShip or "alpha"
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
end

-- Clear held inputs on focus loss to avoid sticky movement/shoot
function love.focus(f)
  if not f and stateManager and stateManager.current and stateManager.current.keys then
    local keys = stateManager.current.keys
    for k in pairs(keys) do keys[k] = false end
  end
end
