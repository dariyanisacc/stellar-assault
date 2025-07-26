-- Stellar Assault – Persistence system
-- Handles saving / loading game data and validates it with a checksum.
-- Tries to use lunajson for speed, but will fall back to love.data JSON if
-- lunajson isn’t bundled with the project.

----------------------------------------------------------------------
-- JSON SET-UP
----------------------------------------------------------------------

local ok, json = pcall(require, "lunajson")          -- system-wide install
if not ok then ok, json = pcall(require, "src.lunajson") end  -- local copy

-- Graceful fallback so the game still boots without lunajson
if not ok then
    print("[Persistence] lunajson not found – falling back to love.data JSON.")
    json = {
        encode = function(tbl) return love.data.encode("string", "json", tbl) end,
        decode = function(str)  return love.data.decode("string", "json", str)  end
    }
end

----------------------------------------------------------------------
-- DEPENDENCIES
----------------------------------------------------------------------

local logger = require("src.logger")

----------------------------------------------------------------------
-- CONSTANTS
----------------------------------------------------------------------

local Persistence   = {}
local SAVE_FILE     = "stellar_assault_save.dat"
local CHECKSUM_FILE = SAVE_FILE .. ".sum"

-- Set when a load fails so calling code can react
Persistence.loadError = nil

-- Default structure for new saves or schema upgrades
local defaultSaveData = {
    highScore           = 0,
    leaderboard         = {},
    unlockedLevels      = { true },  -- Level 1 always unlocked
    totalBossesDefeated = 0,

    statistics = {
        totalPlayTime        = 0,
        totalEnemiesDefeated = 0,
        totalDeaths          = 0,
        favoriteShip         = "alpha",
        bestKillCount        = 0,
        bestSurvivalTime     = 0
    },

    achievements = {},

    settings = {
        masterVolume = 1.0,
        sfxVolume    = 1.0,
        musicVolume  = 0.2,
        selectedShip = "alpha",
        displayMode  = "windowed",
        highContrast = false
    }
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
    if not love.filesystem.getInfo(CHECKSUM_FILE) then return false end
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

----------------------------------------------------------------------
-- UTILITY
----------------------------------------------------------------------

---Simple deep-copy (avoids sharing references to default data).
function deepcopy(obj)
    if type(obj) ~= "table" then return obj end
    local res = {}
    for k, v in pairs(obj) do res[deepcopy(k)] = deepcopy(v) end
    return res
end

return Persistence
