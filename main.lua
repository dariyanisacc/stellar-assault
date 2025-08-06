-- File: main.lua
------------------------------------------------------------------------------
-- Stellar Assault - Main Module
--   * Adds package.path entries so Lua can locate third-party libs inside src/
--   * Uses AssetManager for all fonts, images and sounds
------------------------------------------------------------------------------

-- Add ./src/ to Lua’s module search path BEFORE any require calls
if not package.path:match("src/%.lua") then
  package.path = table.concat({
    package.path,
    "src/?.lua", -- e.g. src/lunajson.lua
    "src/?/init.lua", -- e.g. src/lunajson/init.lua
  }, ";")
end

-- ---------------------------------------------------------------------------
-- Core modules (wrapped in error handler)
-- ---------------------------------------------------------------------------
local function abort(msg)
  io.stderr:write(msg.."\n"..debug.traceback("",2).."\n")
  love.event.quit(1)
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
  lw.setMode(800, 600, {
    fullscreen = false,
    resizable = true,
    minwidth = constants.window.minWidth,
    minheight = constants.window.minHeight,
  })
  lg.setDefaultFilter("nearest", "nearest")
  lg.setBackgroundColor(0.05, 0.05, 0.10)
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

  loadFonts()
  loadAudio()
  loadSettings()
  applyWindowMode()

  -- Images / sprites loaded via AssetManager
  Game.playerShips = {
    alpha = AssetManager.getImage("assets/ships/ship_alpha@1024x1024.png"),
    beta = AssetManager.getImage("assets/ships/ship_beta@112x75.png"),
    gamma = AssetManager.getImage("assets/ships/ship_gamma@98x75.png"),
  }
  Game.enemyShips = {
    basic = AssetManager.getImage("assets/enemies/enemy_basic_1.png"),
    homing = AssetManager.getImage("assets/enemies/enemy_homing_1.png"),
    dive = AssetManager.getImage("assets/enemies/enemy_dive_1.png"),
    zigzag = AssetManager.getImage("assets/enemies/enemy_zigzag_1.png"),
    formation = AssetManager.getImage("assets/enemies/enemy_formation_1.png"),
  }
  Game.bossSprites = {
    AssetManager.getImage("assets/bosses/boss_01@97x84.png"),
    AssetManager.getImage("assets/bosses/boss_02@97x84.png"),
  }
  Game.bossSprite, Game.boss2Sprite = Game.bossSprites[1], Game.bossSprites[2]

  Game.availableShips = { "alpha", "beta", "gamma" }
  Game.selectedShip = "alpha"
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
    local ok, err = xpcall(originalRun, debug.traceback, ...)
    if not ok then
      local stamp = os.date("%Y%m%d_%H%M%S")
      love.filesystem.write(string.format("crash_%s.log", stamp), err)
    end
  end
end
