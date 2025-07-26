------------------------------------------------------------------------------
-- Stellar Assault - Main Module (fixed)
--   * Adds package.path entries so Lua can locate third-party libs inside src/
--   * Loads lunajson with its canonical name (`require("lunajson")`)
------------------------------------------------------------------------------

-- Add ./src/ to Lua’s module search path BEFORE any require calls
if not package.path:match("src/%.lua") then
  package.path = package.path
    .. ";src/?.lua" -- e.g. src/lunajson.lua
    .. ";src/?/init.lua" -- e.g. src/lunajson/init.lua
end

-- ---------------------------------------------------------------------------
-- Core modules
-- ---------------------------------------------------------------------------
local StateManager = require("src.core.statemachine")
local Helpers = require("src.core.helpers")
local constants = require("src.constants")
local DebugConsole = require("src.debugconsole")
local CONFIG = require("src.config")
local logger = require("src.logger")
local Persistence = require("src.persistence")
local UIManager = require("src.uimanager")
local Game = require("src.game")

-- Cache Love2D modules for speed
local lg, la, lw, lt, lf = love.graphics, love.audio, love.window, love.timer, love.filesystem

-- ---------------------------------------------------------------------------
-- Globals stored on Game table
-- ---------------------------------------------------------------------------
Game.stateManager = nil
Game.debugConsole = nil
debugConsole = nil -- kept for callbacks that look for this global

Game.titleFont = nil
Game.menuFont = nil
Game.uiFont = nil
Game.smallFont = nil
Game.mediumFont = nil
Game.uiManager = nil

Game.laserSound = nil
Game.explosionSound = nil
Game.powerupSound = nil
Game.shieldBreakSound = nil
Game.gameOverSound = nil
Game.menuSelectSound = nil
Game.menuConfirmSound = nil
Game.backgroundMusic = nil
Game.bossMusic = nil
Game.victorySound = nil

Game.laserClones = nil
Game.laserCloneIndex = 1

Game.helpers = Helpers

local soundReferenceDistance, soundMaxDistance = 50, 800
local sfxSources, musicSources = {}, {}

Game.masterVolume = constants.audio.defaultMasterVolume
Game.sfxVolume = constants.audio.defaultSFXVolume
Game.musicVolume = constants.audio.defaultMusicVolume
Game.displayMode = "borderless"
Game.currentResolution = 1
Game.highContrast = false
Game.fontScale = 1

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
-- Helper: update last input type
-- ---------------------------------------------------------------------------
local function updateInputType(t)
  if Game.lastInputType ~= t then
    Game.lastInputType = t
    logger.debug("Input type changed to: %s", t)
  end
end

-- ---------------------------------------------------------------------------
-- Window setup
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
-- Fonts
-- ---------------------------------------------------------------------------
local function loadFonts()
  Game.titleFont = lg.newFont(48)
  Game.menuFont = lg.newFont(24)
  Game.uiFont = lg.newFont(18)
  Game.smallFont = lg.newFont(14)
  Game.mediumFont = lg.newFont(20)
  Game.uiManager = UIManager:new()

  if lf.getInfo("assets/fonts/monospace.ttf") then
    Game.consoleFont = lg.newFont("assets/fonts/monospace.ttf", 14)
  else
    Game.consoleFont = lg.newFont(14)
  end
end

-- ---------------------------------------------------------------------------
-- State registration
-- ---------------------------------------------------------------------------
local function initStates()
  stateManager = StateManager:new()
  Game.stateManager = stateManager

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
-- Audio loading helpers
-- ---------------------------------------------------------------------------
local function registerSfx(path, base)
  if not lf.getInfo(path) then
    return nil
  end
  local src = la.newSource(path, "static")
  src.baseVolume = base
  src:setVolume(base * Game.sfxVolume * Game.masterVolume)
  table.insert(sfxSources, src)
  return src
end
local function registerMusic(path, base, loop)
  if not lf.getInfo(path) then
    return nil
  end
  local src = la.newSource(path, "stream")
  src.baseVolume = base
  src:setLooping(loop)
  src:setVolume(base * Game.musicVolume * Game.masterVolume)
  table.insert(musicSources, src)
  return src
end

local function loadAudio()
  la.setDistanceModel("inverseclamped")

  Game.laserSound = registerSfx("laser.wav", 0.5)
  Game.explosionSound = registerSfx("explosion.wav", 0.7)
  Game.powerupSound = registerSfx("powerup.wav", 0.6)
  Game.shieldBreakSound = registerSfx("shield_break.wav", 0.7)
  Game.gameOverSound = registerSfx("gameover.ogg", 0.8)
  Game.menuSelectSound = registerSfx("menu.flac", 0.4)

  if Game.menuSelectSound then
    Game.menuConfirmSound = Game.menuSelectSound:clone()
    Game.menuConfirmSound.baseVolume = Game.menuSelectSound.baseVolume
    Game.menuConfirmSound:setVolume(
      Game.menuConfirmSound.baseVolume * Game.sfxVolume * Game.masterVolume
    )
    table.insert(sfxSources, Game.menuConfirmSound)
  end

  if Game.laserSound then
    Game.laserClones = {}
    for i = 1, 5 do
      local c = Game.laserSound:clone()
      c.baseVolume = Game.laserSound.baseVolume
      c:setVolume(c.baseVolume * Game.sfxVolume * Game.masterVolume)
      table.insert(Game.laserClones, c)
      table.insert(sfxSources, c)
    end
    Game.laserCloneIndex = 1
  end

  Game.backgroundMusic = registerMusic("background.mp3", 1.0, true)
  Game.bossMusic = registerMusic("boss.mp3", 0.8, true)
  Game.victorySound = registerSfx("victory.ogg", 0.8)
end

local function applyFontScale()
  Game.titleFont = lg.newFont(48 * Game.fontScale)
  Game.menuFont = lg.newFont(24 * Game.fontScale)
  Game.uiFont = lg.newFont(18 * Game.fontScale)
  Game.smallFont = lg.newFont(14 * Game.fontScale)
  Game.mediumFont = lg.newFont(20 * Game.fontScale)
end

-- Settings I/O --------------------------------------------------------------
local function updateAudioVolumes()
  for _, s in ipairs(sfxSources) do
    s:setVolume((s.baseVolume or 1) * Game.sfxVolume * Game.masterVolume)
  end
  for _, s in ipairs(musicSources) do
    s:setVolume((s.baseVolume or 1) * Game.musicVolume * Game.masterVolume)
  end
end

local function loadSettings()
  if not lf.getInfo("settings.dat") then
    return
  end
  local lines = {}
  for l in lf.read("settings.dat"):gmatch("[^\n]+") do
    lines[#lines + 1] = l
  end
  if #lines < 5 then
    return
  end
  Game.currentResolution = tonumber(lines[1]) or 1
  Game.displayMode = lines[2] or "windowed"
  Game.masterVolume = tonumber(lines[3]) or 1
  Game.sfxVolume = tonumber(lines[4]) or 1
  Game.musicVolume = tonumber(lines[5]) or 0.2
  if lines[6] then
    Game.selectedShip = lines[6]
  end
  Game.highContrast = lines[7] == "true"
  if lines[8] then
    Game.fontScale = tonumber(lines[8]) or 1
  end
  updateAudioVolumes()
  applyFontScale()
end

function saveSettings()
  local out = table.concat({
    Game.currentResolution,
    Game.displayMode,
    Game.masterVolume,
    Game.sfxVolume,
    Game.musicVolume,
    Game.selectedShip or "alpha",
    tostring(Game.highContrast),
    Game.fontScale,
  }, "\n")
  lf.write("settings.dat", out)
  Persistence.updateSettings({
    masterVolume = Game.masterVolume,
    sfxVolume = Game.sfxVolume,
    musicVolume = Game.musicVolume,
    selectedShip = Game.selectedShip,
    displayMode = Game.displayMode,
    highContrast = Game.highContrast,
    fontScale = Game.fontScale,
  })
end

-- Window mode ---------------------------------------------------------------
local function applyWindowMode()
  local res = {
    { 800, 600 },
    { 1024, 768 },
    { 1280, 720 },
    { 1366, 768 },
    { 1920, 1080 },
    { 2560, 1440 },
  }
  local flags =
    { vsync = 1, minwidth = constants.window.minWidth, minheight = constants.window.minHeight }
  if Game.displayMode == "borderless" then
    flags.fullscreen = true
    flags.fullscreentype = "desktop"
    flags.resizable = false
    lw.setMode(0, 0, flags)
  elseif Game.displayMode == "fullscreen" then
    local r = res[Game.currentResolution] or res[1]
    flags.fullscreen = true
    flags.fullscreentype = "exclusive"
    flags.resizable = false
    lw.setMode(r[1], r[2], flags)
  else
    local r = res[Game.currentResolution] or res[1]
    flags.fullscreen = false
    flags.resizable = true
    lw.setMode(r[1], r[2], flags)
  end
  initStarfield()
end

-- Positional SFX ------------------------------------------------------------
function playPositionalSound(src, x, y)
  if not src or not player then
    return
  end
  local c
  if src == Game.laserSound and Game.laserClones then
    c = Game.laserClones[Game.laserCloneIndex]
    Game.laserCloneIndex = (Game.laserCloneIndex % #Game.laserClones) + 1
  else
    c = src:clone()
    c.baseVolume = src.baseVolume
  end
  local dx, dy = x - player.x, y - player.y
  if c:getChannelCount() == 1 then
    c:setRelative(true)
    c:setPosition(dx, dy, 0)
    c:setAttenuationDistances(soundReferenceDistance, soundMaxDistance)
  end
  c:setVolume((c.baseVolume or 1) * Game.sfxVolume * Game.masterVolume)
  c:play()
end

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

_G.initWindow = initWindow
_G.loadFonts = loadFonts
_G.loadAudio = loadAudio
_G.initStates = initStates

-- ---------------------------------------------------------------------------
-- Love2D callbacks
-- ---------------------------------------------------------------------------
function love.load()
  initWindow()
  loadFonts()
  loadAudio()
  loadSettings()
  applyWindowMode()
  local AssetLoader = require("src.core.asset_loader")
  Game.assetLoader = AssetLoader
  Game.playerShips = {
    alpha = AssetLoader.getImage("assets/ships/ship_alpha@1024x1024.png"),
    beta = AssetLoader.getImage("assets/ships/ship_beta@112x75.png"),
    gamma = AssetLoader.getImage("assets/ships/ship_gamma@98x75.png"),
  }
  Game.enemyShips = {
    basic = AssetLoader.getImage("assets/enemies/enemy_basic_1.png"),
    homing = AssetLoader.getImage("assets/enemies/enemy_homing_1.png"),
    dive = AssetLoader.getImage("assets/enemies/enemy_dive_1.png"),
    zigzag = AssetLoader.getImage("assets/enemies/enemy_zigzag_1.png"),
    formation = AssetLoader.getImage("assets/enemies/enemy_formation_1.png"),
  }
  Game.bossSprites = {
    AssetLoader.getImage("assets/bosses/boss_01@97x84.png"),
    AssetLoader.getImage("assets/bosses/boss_02@97x84.png"),
  }
  Game.bossSprite, Game.boss2Sprite = Game.bossSprites[1], Game.bossSprites[2]
  Game.availableShips, Game.selectedShip, Game.spriteScale =
    { "alpha", "beta", "gamma" }, "alpha", 0.15
  initStates()
  logger.info("Stellar Assault started")
  stateManager:switch("menu")
end

function love.update(dt)
  dt = math.min(dt, 1 / 30)
  if _G.timeScale then
    dt = dt * _G.timeScale
  end
  updateStarfield(dt)
  debugConsole:update(dt)
  if _G.configReloadNotification then
    local n = _G.configReloadNotification
    n.timer = n.timer - dt
    if n.timer <= 0 then
      _G.configReloadNotification = nil
    end
  end
  stateManager:update(dt)
end

local drawDebugInfo, drawDebugOverlay

function love.draw()
  stateManager:draw()
  if debugMode then
    drawDebugInfo()
  end
  if debugOverlay then
    drawDebugOverlay()
  end
  if _G.configReloadNotification then
    local n = _G.configReloadNotification
    lg.setFont(Game.menuFont)
    lg.setColor(n.color[1], n.color[2], n.color[3], n.timer)
    lg.printf(n.text, 0, lg.getHeight() / 2 - 50, lg.getWidth(), "center")
    lg.setColor(1, 1, 1, 1)
  end
  if _G.showLogOverlay then
    logger.drawOverlay(10, lg.getHeight() - 200, 10)
  end
  debugConsole:draw()
end

function love.keypressed(k, sc, isr)
  updateInputType("keyboard")
  if debugConsole:keypressed(k) then
    return
  end
  if k == "f3" then
    debugMode = not debugMode
    logger.info("Debug mode: %s", debugMode and "on" or "off")
  elseif k == "f5" then
    local ok, newC = pcall(function()
      package.loaded["src.constants"] = nil
      return require("src.constants")
    end)
    if ok then
      constants = newC
      logger.info("Config reloaded")
      _G.configReloadNotification = { text = "Config Reloaded!", timer = 2, color = { 0, 1, 0 } }
    else
      logger.error("Reload failed: " .. tostring(newC))
      _G.configReloadNotification = { text = "Reload Failed!", timer = 2, color = { 1, 0, 0 } }
    end
  elseif k == "f9" then
    debugOverlay = not debugOverlay
  end
  stateManager:keypressed(k, sc, isr)
end

function love.keyreleased(k, sc)
  stateManager:keyreleased(k, sc)
end
function love.mousepressed(x, y, b, ist, p)
  updateInputType("keyboard")
  stateManager:mousepressed(x, y, b, ist, p)
end
function love.mousemoved()
  updateInputType("keyboard")
end
function love.gamepadaxis(_, _, v)
  if math.abs(v) > 0.2 then
    updateInputType("gamepad")
  end
end
function love.gamepadpressed(js, b)
  updateInputType("gamepad")
  stateManager:gamepadpressed(js, b)
end
function love.gamepadreleased(js, b)
  stateManager:gamepadreleased(js, b)
end
function love.resize(w, h)
  initStarfield()
  stateManager:resize(w, h)
  logger.info("Resized to %dx%d", w, h)
end
function love.textinput(t)
  debugConsole:textinput(t)
end

-- Debug helpers -------------------------------------------------------------
debugMode, debugOverlay, frameTimeHistory, maxFrameTimeHistory = false, false, {}, 60
function drawDebugInfo()
  lg.setFont(Game.smallFont)
  lg.setColor(1, 1, 1, 0.8)
  table.insert(frameTimeHistory, lt.getDelta())
  if #frameTimeHistory > maxFrameTimeHistory then
    table.remove(frameTimeHistory, 1)
  end
  local avg, max = 0, 0
  for _, d in ipairs(frameTimeHistory) do
    avg = avg + d
    if d > max then
      max = d
    end
  end
  avg = avg / #frameTimeHistory
  local t = {
    "FPS: " .. lt.getFPS(),
    string.format("Mem: %.2f MB", collectgarbage("count") / 1024),
    string.format("Delta: %.3f ms", lt.getAverageDelta() * 1000),
    string.format("Avg: %.3f ms", avg * 1000),
    string.format("Max: %.3f ms", max * 1000),
    "State: " .. (stateManager.currentName or "none"),
    string.format("Res: %dx%d", lg.getWidth(), lg.getHeight()),
  }
  for i, l in ipairs(t) do
    lg.print(l, lg.getWidth() - 150, 10 + 15 * (i - 1))
  end
end
function drawDebugOverlay()
  lg.setFont(Game.smallFont)
  lg.setColor(0, 0, 0, 0.7)
  lg.rectangle("fill", lg.getWidth() - 250, 10, 240, 180, 5)
  lg.setColor(1, 1, 1, 1)
  local x, y, lh = lg.getWidth() - 240, 20, 18
  lg.print(string.format("Mem: %.2f MB", collectgarbage("count") / 1024), x, y)
  y = y + lh
  if stateManager.currentState == stateManager.states.playing then
    lg.print("Entities:", x, y)
    y = y + lh
    lg.print(string.format("  Asteroids: %d", asteroids and #asteroids or 0), x, y)
    y = y + lh
    lg.print(string.format("  Aliens:    %d", aliens and #aliens or 0), x, y)
    y = y + lh
    lg.print(string.format("  Lasers:    %d", lasers and #lasers or 0), x, y)
    y = y + lh
    lg.print(string.format("  Explosions:%d", explosions and #explosions or 0), x, y)
    y = y + lh
    lg.print(string.format("  Powerups:  %d", powerups and #powerups or 0), x, y)
    y = y + lh
  end
  y = y + lh
  lg.setColor(0.7, 0.7, 0.7, 1)
  lg.print("F3: Debug Info", x, y)
  y = y + lh
  lg.print("F5: Reload Config", x, y)
  y = y + lh
  lg.print("F9: Toggle Overlay", x, y)
  lg.setColor(1, 1, 1, 1)
end

-- Misc helpers --------------------------------------------------------------
function saveGame(slot, level, score, lives)
  lf.write("save" .. slot .. ".dat", table.concat({ level, score, lives }, ","))
end
function checkCollision(a, b)
  local aw, ah, bw, bh =
    a.width or a.size, a.height or a.size, b.width or b.size, b.height or b.size
  return (a.x - aw / 2) < (b.x + bw / 2)
    and (a.x + aw / 2) > (b.x - bw / 2)
    and (a.y - ah / 2) < (b.y + bh / 2)
    and (a.y + ah / 2) > (b.y - bh / 2)
end
function love.quit()
  if Game.spriteManager and Game.spriteManager.reportUsage then
    Game.spriteManager:reportUsage()
  end
end
