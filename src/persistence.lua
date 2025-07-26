-- Stellar Assault – Persistence system
-- Handles saving / loading game data and validates it with a checksum.
-- Tries to use lunajson for speed, but will fall back to love.data JSON if
-- lunajson isn’t bundled with the project.

----------------------------------------------------------------------
-- JSON SET-UP
----------------------------------------------------------------------

local ok, json = pcall(require, "lunajson") -- system-wide install
if not ok then
  ok, json = pcall(require, "src.lunajson")
end -- local copy

-- Graceful fallback so the game still boots without lunajson
if not ok then
  print("[Persistence] lunajson not found – falling back to love.data JSON.")
  json = {
    encode = function(tbl)
      return love.data.encode("string", "json", tbl)
    end,
    decode = function(str)
      return love.data.decode("string", "json", str)
    end,
  }
end

----------------------------------------------------------------------
-- DEPENDENCIES
----------------------------------------------------------------------

local logger = require("src.logger")
local constants = require("src.constants")

----------------------------------------------------------------------
-- UTILITY
----------------------------------------------------------------------

---Simple deep-copy (avoids sharing references to default data).
local function deepcopy(obj)
  if type(obj) ~= "table" then
    return obj
  end
  local res = {}
  for k, v in pairs(obj) do
    res[deepcopy(k)] = deepcopy(v)
  end
  return res
end

----------------------------------------------------------------------
-- CONSTANTS
----------------------------------------------------------------------

local Persistence = {}
local SAVE_FILE = "stellar_assault_save.dat"
local CHECKSUM_FILE = SAVE_FILE .. ".sum"

-- Default control mappings
local defaultControls = {
  keyboard = {
    left = "left",
    right = "right",
    up = "up",
    down = "down",
    shoot = "space",
    boost = "lshift",
    bomb = "b",
    pause = "escape",
  },
  gamepad = {
    shoot = "rightshoulder",
    bomb = "a",
    boost = "x",
    pause = "start",
  },
}

-- Set when a load fails so calling code can react
Persistence.loadError = nil

-- Default structure for new saves or schema upgrades
local defaultSaveData = {
  highScore = 0,
  leaderboard = {},
  unlockedLevels = { true }, -- Level 1 always unlocked
  totalBossesDefeated = 0,

  statistics = {
    totalPlayTime = 0,
    totalEnemiesDefeated = 0,
    totalDeaths = 0,
    favoriteShip = "alpha",
    bestKillCount = 0,
    bestSurvivalTime = 0,
  },

  achievements = {},

  controls = deepcopy(defaultControls),

  settings = {
    masterVolume = 1.0,
    sfxVolume = 1.0,
    musicVolume = 0.2,
    selectedShip = "alpha",
    displayMode = "windowed",
    highContrast = false,
    palette = constants.defaultPalette,
  },
}

----------------------------------------------------------------------
-- INTERNAL HELPERS
----------------------------------------------------------------------

---Returns an MD5 checksum for a string.
local function checksum(str)
  return love.data.hash("md5", str)
end

---Write the checksum for the given JSON string.
local function writeChecksum(jsonStr)
  love.filesystem.write(CHECKSUM_FILE, checksum(jsonStr))
end

---Verify that the checksum on disk matches the supplied JSON string.
local function isChecksumValid(jsonStr)
  if not love.filesystem.getInfo(CHECKSUM_FILE) then
    return false
  end
  local stored = love.filesystem.read(CHECKSUM_FILE)
  return stored == checksum(jsonStr)
end

---Deep-merge source into destination, preserving existing keys.
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
    Persistence.save(defaultSaveData)
    return deepcopy(defaultSaveData)
  end

  local jsonStr = love.filesystem.read(SAVE_FILE)

  -- Integrity check
  if not isChecksumValid(jsonStr) then
    Persistence.loadError = "Save data failed checksum – starting fresh."
    logger.warn(Persistence.loadError)
    love.filesystem.remove(SAVE_FILE)
    love.filesystem.remove(CHECKSUM_FILE)
    Persistence.save(defaultSaveData)
    return deepcopy(defaultSaveData)
  end

  -- Decode JSON safely
  local okDecode, data = pcall(json.decode, jsonStr)
  if not okDecode or type(data) ~= "table" then
    Persistence.loadError = "Save data corrupt – starting fresh."
    logger.error(Persistence.loadError .. " (" .. tostring(data) .. ")")
    love.filesystem.remove(SAVE_FILE)
    love.filesystem.remove(CHECKSUM_FILE)
    Persistence.save(defaultSaveData)
    return deepcopy(defaultSaveData)
  end

  -- Upgrade older saves if the schema changed
  mergeDefaults(data, defaultSaveData)
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

  love.filesystem.write(SAVE_FILE, jsonStr)
  writeChecksum(jsonStr)
  return true
end

-----------------------------------------------------------------------
-- Save Data Helpers
-----------------------------------------------------------------------

---Return cached save data, loading from disk if needed.
function Persistence.getSaveData()
  if not Persistence.saveData then
    Persistence.saveData = Persistence.load()
  end
  return Persistence.saveData
end

---Return and clear the last load error.
function Persistence.getLoadError()
  return Persistence.loadError
end

function Persistence.clearLoadError()
  Persistence.loadError = nil
end

-----------------------------------------------------------------------
-- Settings and Controls
-----------------------------------------------------------------------

---Return settings table (read-only).
function Persistence.getSettings()
  return deepcopy(Persistence.getSaveData().settings)
end

---Update settings fields and persist to disk.
function Persistence.updateSettings(changes)
  local data = Persistence.getSaveData()
  data.settings = data.settings or {}
  for k, v in pairs(changes or {}) do
    data.settings[k] = v
  end
  Persistence.save(data)
end

---Return control bindings.
function Persistence.getControls()
  local data = Persistence.getSaveData()
  data.controls = data.controls or deepcopy(defaultControls)
  return deepcopy(data.controls)
end

---Set a keyboard binding and persist.
function Persistence.setKeyBinding(action, key)
  local data = Persistence.getSaveData()
  data.controls = data.controls or deepcopy(defaultControls)
  data.controls.keyboard[action] = key
  Persistence.save(data)
end

---Set a gamepad binding and persist.
function Persistence.setGamepadBinding(action, button)
  local data = Persistence.getSaveData()
  data.controls = data.controls or deepcopy(defaultControls)
  data.controls.gamepad[action] = button
  Persistence.save(data)
end

---Reset all control bindings to defaults.
function Persistence.resetControls()
  local data = Persistence.getSaveData()
  data.controls = deepcopy(defaultControls)
  Persistence.save(data)
end

-----------------------------------------------------------------------
-- Score and Progression
-----------------------------------------------------------------------

function Persistence.getHighScore()
  local data = Persistence.getSaveData()
  return data.highScore or 0
end

function Persistence.setHighScore(score, name)
  local data = Persistence.getSaveData()
  if score > (data.highScore or 0) then
    data.highScore = score
    data.leaderboard = data.leaderboard or {}
    table.insert(data.leaderboard, { name = name or "Player", score = score })
    table.sort(data.leaderboard, function(a, b)
      return (a.score or 0) > (b.score or 0)
    end)
    if #data.leaderboard > 10 then
      data.leaderboard[11] = nil
    end
    Persistence.save(data)
    return true
  end
  return false
end

function Persistence.getCurrentScore()
  local data = Persistence.getSaveData()
  return data.currentScore or 0
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
  for i = #data.unlockedLevels + 1, level do
    data.unlockedLevels[i] = false
  end
  data.unlockedLevels[level] = true
  Persistence.save(data)
end

function Persistence.getUnlockedLevels()
  local data = Persistence.getSaveData()
  data.unlockedLevels = data.unlockedLevels or { true }
  local count = 0
  for i = 1, #data.unlockedLevels do
    if data.unlockedLevels[i] then
      count = i
    end
  end
  return count
end

function Persistence.isShipUnlocked(_name)
  -- Ships are always unlocked in this lightweight implementation
  return true
end

function Persistence.getLevelStats(level)
  local data = Persistence.getSaveData()
  data.levelStats = data.levelStats or {}
  data.levelStats[level] = data.levelStats[level] or { bestScore = 0, bestTime = 0 }
  return deepcopy(data.levelStats[level])
end

function Persistence.updateLevelStats(level, score, time)
  local data = Persistence.getSaveData()
  data.levelStats = data.levelStats or {}
  local stats = data.levelStats[level] or { bestScore = 0, bestTime = 0 }
  if score and score > (stats.bestScore or 0) then
    stats.bestScore = score
  end
  if time and (stats.bestTime == 0 or time < stats.bestTime) then
    stats.bestTime = time
  end
  data.levelStats[level] = stats
  Persistence.save(data)
end

function Persistence.updateStatistics(changes)
  local data = Persistence.getSaveData()
  data.statistics = data.statistics or {}
  for k, v in pairs(changes or {}) do
    data.statistics[k] = v
  end
  Persistence.save(data)
end

function Persistence.getBestKillCount()
  local data = Persistence.getSaveData()
  return (data.statistics and data.statistics.bestKillCount) or 0
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
  local data = Persistence.getSaveData()
  return (data.statistics and data.statistics.bestSurvivalTime) or 0
end

function Persistence.updateBestSurvivalTime(time)
  local data = Persistence.getSaveData()
  data.statistics = data.statistics or {}
  if data.statistics.bestSurvivalTime == nil or time > data.statistics.bestSurvivalTime then
    data.statistics.bestSurvivalTime = time
    Persistence.save(data)
    return true
  end
  return false
end

return Persistence
