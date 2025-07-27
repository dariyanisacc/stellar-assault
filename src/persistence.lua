----------------------------------------------------------------------
-- Stellar Assault – Persistence system
-- Handles saving / loading game data and validates it with a checksum.
-- Tries to use lunajson for speed, but falls back to love.data JSON
-- if lunajson isn’t bundled with the project.
----------------------------------------------------------------------

----------------------------------------------------------------------
-- JSON SET‑UP
----------------------------------------------------------------------

local ok, json = pcall(require, "lunajson")      -- system‑wide install
if not ok then
  ok, json = pcall(require, "src.lunajson")      -- bundled copy
end

-- Graceful fallback so the game still boots without lunajson
if not ok then
  print("[Persistence] lunajson not found – falling back to love.data JSON.")
  json = {
    encode = function(tbl) return love.data.encode("string", "json", tbl) end,
    decode = function(str) return love.data.decode("string", "json", str) end,
  }
end

----------------------------------------------------------------------
-- DEPENDENCIES
----------------------------------------------------------------------

local logger    = require("src.logger")
local constants = require("src.constants")

----------------------------------------------------------------------
-- UTILITY
----------------------------------------------------------------------

---Simple deep‑copy (avoids sharing references to default data).
local function deepcopy(obj)
  if type(obj) ~= "table" then return obj end
  local res = {}
  for k, v in pairs(obj) do res[deepcopy(k)] = deepcopy(v) end
  return res
end

----------------------------------------------------------------------
-- CONSTANTS
----------------------------------------------------------------------

local Persistence      = {}
Persistence.settings   = nil          -- cached reference for convenience

local SAVE_FILE        = "stellar_assault_save.dat"
local CHECKSUM_FILE    = SAVE_FILE .. ".sum"
local SAVE_VERSION     = 3            -- bump when schema changes

-- Default control mappings
local defaultControls = {
  keyboard = {
    left   = "left",  right = "right", up   = "up",    down = "down",
    shoot  = "space", boost = "lshift", bomb = "b",    pause = "escape",
  },
  gamepad  = { shoot = "rightshoulder", bomb = "a", boost = "x", pause = "start" }
}

-- Set when a load fails so calling code can react
Persistence.loadError = nil

-- Default structure for new saves or schema upgrades
local defaultSaveData = {
  highScore            = 0,
  leaderboard          = {},
  unlockedLevels       = { true }, -- Level 1 always unlocked
  totalBossesDefeated  = 0,

  statistics = {
    totalPlayTime      = 0,
    totalEnemiesDefeated = 0,
    totalDeaths        = 0,
    favoriteShip       = "alpha",
    bestKillCount      = 0,
    bestSurvivalTime   = 0,
  },

  achievements = {},

  settings = {
    controls      = deepcopy(defaultControls),
    masterVolume  = 1.0,
    sfxVolume     = 1.0,
    musicVolume   = 0.2,
    selectedShip  = "alpha",
    displayMode   = "windowed",
    highContrast  = false,
    palette       = constants.defaultPalette, -- from main
  },
}

----------------------------------------------------------------------
-- INTERNAL HELPERS
----------------------------------------------------------------------

local function checksum(str) return love.data.hash("md5", str) end

local function writeChecksum(jsonStr)
  love.filesystem.write(CHECKSUM_FILE, checksum(jsonStr))
end

local function isChecksumValid(jsonStr)
  if not love.filesystem.getInfo(CHECKSUM_FILE) then return false end
  return love.filesystem.read(CHECKSUM_FILE) == checksum(jsonStr)
end

---Deep‑merge source into destination, preserving existing keys.
local function mergeDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = dst[k] or {}
      mergeDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

----------------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------------

---Load the save file (creating a new one if necessary).
function Persistence.load()
  -- No save yet – create one with defaults
  if not love.filesystem.getInfo(SAVE_FILE) then
    logger.info("Save file not found – creating new save.")
    Persistence.save(deepcopy(defaultSaveData))
    return deepcopy(defaultSaveData)
  end

  --------------------------------------------------------------------
  -- Handle version header (added originally in SAVE_VERSION 2)
  --------------------------------------------------------------------
  local fileStr       = love.filesystem.read(SAVE_FILE)
  local version       = 1                -- default to pre‑header saves
  local first, rest   = fileStr:match("^(.-)\n(.*)$")
  local jsonStr       = fileStr

  if first then
    local v = first:match("^version%s*=%s*(%d+)$")
    if v then version = tonumber(v); jsonStr = rest end
  end

  -- Integrity check (JSON portion only)
  if not isChecksumValid(jsonStr) then
    Persistence.loadError = "Save data failed checksum – starting fresh."
    logger.warn(Persistence.loadError)
    love.filesystem.remove(SAVE_FILE)
    love.filesystem.remove(CHECKSUM_FILE)
    Persistence.save(deepcopy(defaultSaveData))
    return deepcopy(defaultSaveData)
  end

  -- Decode JSON safely
  local okDecode, data = pcall(json.decode, jsonStr)
  if not okDecode or type(data) ~= "table" then
    Persistence.loadError = "Save data corrupt – starting fresh."
    logger.error(Persistence.loadError .. " (" .. tostring(data) .. ")")
    love.filesystem.remove(SAVE_FILE)
    love.filesystem.remove(CHECKSUM_FILE)
    Persistence.save(deepcopy(defaultSaveData))
    return deepcopy(defaultSaveData)
  end

  --------------------------------------------------------------------
  -- Schema migrations ----------------------------------------------
  --------------------------------------------------------------------
  -- Merge new default keys
  mergeDefaults(data, defaultSaveData)

  -- Migrate old top‑level `controls` into `settings.controls`
  if data.controls and not (data.settings and data.settings.controls) then
    data.settings        = data.settings or {}
    data.settings.controls = deepcopy(data.controls)
    data.controls        = nil
  end

  if version < SAVE_VERSION then
    -- future migrations belong here (currently none needed 2 → 3)
    version = SAVE_VERSION
    Persistence.save(data)  -- write upgraded schema back to disk
  end

  return data
end

---Write the supplied table to disk.
function Persistence.save(data)
  assert(type(data) == "table", "Persistence.save expects a table")

  local okEncode, jsonStr = pcall(json.encode, data)
  if not okEncode then
    logger.error("Could not encode save data: " .. tostring(jsonStr))
    return false
  end

  local fileStr = string.format("version = %d\n%s", SAVE_VERSION, jsonStr)
  love.filesystem.write(SAVE_FILE, fileStr)
  writeChecksum(jsonStr)  -- checksum ONLY the JSON payload
  return true
end

-----------------------------------------------------------------------
-- Save Data Helpers
-----------------------------------------------------------------------

function Persistence.getSaveData()
  if not Persistence.saveData then
    Persistence.saveData = Persistence.load()
  end
  Persistence.settings = Persistence.saveData.settings
  return Persistence.saveData
end

function Persistence.getLoadError() return Persistence.loadError end
function Persistence.clearLoadError() Persistence.loadError = nil end

-----------------------------------------------------------------------
-- Settings and Controls
-----------------------------------------------------------------------

function Persistence.getSettings()
  return deepcopy(Persistence.getSaveData().settings)
end

function Persistence.updateSettings(changes)
  local data = Persistence.getSaveData()
  data.settings = data.settings or {}
  for k, v in pairs(changes or {}) do data.settings[k] = v end
  Persistence.save(data)
  Persistence.settings = data.settings
end

function Persistence.getControls()
  local data = Persistence.getSaveData()
  data.settings = data.settings or {}
  data.settings.controls = data.settings.controls or deepcopy(defaultControls)
  Persistence.settings = data.settings
  return deepcopy(data.settings.controls)
end

function Persistence.setKeyBinding(action, key)
  local data = Persistence.getSaveData()
  data.settings = data.settings or {}
  data.settings.controls = data.settings.controls or deepcopy(defaultControls)
  data.settings.controls.keyboard[action] = key
  Persistence.save(data)
  Persistence.settings = data.settings
end

function Persistence.setGamepadBinding(action, button)
  local data = Persistence.getSaveData()
  data.settings = data.settings or {}
  data.settings.controls = data.settings.controls or deepcopy(defaultControls)
  data.settings.controls.gamepad[action] = button
  Persistence.save(data)
  Persistence.settings = data.settings
end

function Persistence.resetControls()
  local data = Persistence.getSaveData()
  data.settings = data.settings or {}
  data.settings.controls = deepcopy(defaultControls)
  Persistence.save(data)
  Persistence.settings = data.settings
end

-----------------------------------------------------------------------
-- Score and Progression
-----------------------------------------------------------------------

function Persistence.getHighScore()
  return Persistence.getSaveData().highScore or 0
end

function Persistence.setHighScore(score, name)
  local data = Persistence.getSaveData()
  if score > (data.highScore or 0) then
    data.highScore   = score
    data.leaderboard = data.leaderboard or {}
    table.insert(data.leaderboard, { name = name or "Player", score = score })
    table.sort(data.leaderboard, function(a, b) return (a.score or 0) > (b.score or 0) end)
    if #data.leaderboard > 10 then data.leaderboard[11] = nil end
    Persistence.save(data)
    return true
  end
  return false
end

function Persistence.getCurrentScore()
  return Persistence.getSaveData().currentScore or 0
end

function Persistence.setCurrentScore(score)
  local data = Persistence.getSaveData()
  data.currentScore = score
  Persistence.save(data)
end

function Persistence.addScore(score)
  local data = Persistence.getSaveData()
  data.currentScore = (data.currentScore or 0) + (score or 0)
  Persistence.save(data)
end

function Persistence.incrementBossesDefeated()
  local data = Persistence.getSaveData()
  data.totalBossesDefeated = (data.totalBossesDefeated or 0) + 1
  Persistence.save(data)
end

function Persistence.unlockLevel(level)
  local data = Persistence.getSaveData()
  data.unlockedLevels = data.unlockedLevels or { true }
  for i = #data.unlockedLevels + 1, level do data.unlockedLevels[i] = false end
  data.unlockedLevels[level] = true
  Persistence.save(data)
end

function Persistence.getUnlockedLevels()
  local unlocked = Persistence.getSaveData().unlockedLevels or { true }
  local count = 0
  for i = 1, #unlocked do if unlocked[i] then count = i end end
  return count
end

function Persistence.isShipUnlocked(_) return true end -- all ships unlocked

function Persistence.getLevelStats(level)
  local data = Persistence.getSaveData()
  data.levelStats = data.levelStats or {}
  data.levelStats[level] = data.levelStats[level] or { bestScore = 0, bestTime = 0 }
  return deepcopy(data.levelStats[level])
end

function Persistence.updateLevelStats(level, score, time)
  local data  = Persistence.getSaveData()
  data.levelStats = data.levelStats or {}
  local stats = data.levelStats[level] or { bestScore = 0, bestTime = 0 }
  if score and score > (stats.bestScore or 0) then stats.bestScore = score end
  if time  and (stats.bestTime == 0 or time < stats.bestTime) then stats.bestTime = time end
  data.levelStats[level] = stats
  Persistence.save(data)
end

function Persistence.updateStatistics(changes)
  local data = Persistence.getSaveData()
  data.statistics = data.statistics or {}
  for k, v in pairs(changes or {}) do data.statistics[k] = v end
  Persistence.save(data)
end

function Persistence.getBestKillCount()
  return (Persistence.getSaveData().statistics or {}).bestKillCount or 0
end

function Persistence.updateBestKillCount(count)
  local data = Persistence.getSaveData()
  data.statistics = data.statistics or {}
  if count > (data.statistics.bestKillCount or 0) then
    data.statistics.bestKillCount = count
    Persistence.save(data)
    return true
  end
  return false
end

function Persistence.getBestSurvivalTime()
  return (Persistence.getSaveData().statistics or {}).bestSurvivalTime or 0
end

function Persistence.updateBestSurvivalTime(time)
  local data = Persistence.getSaveData()
  data.statistics = data.statistics or {}
  if not data.statistics.bestSurvivalTime or time > data.statistics.bestSurvivalTime then
    data.statistics.bestSurvivalTime = time
    Persistence.save(data)
    return true
  end
  return false
end

return Persistence
