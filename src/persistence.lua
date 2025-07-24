-- Persistence system for save data
local json = require("src.json") -- We'll need a simple JSON library
local logger = require("src.logger")

local Persistence = {}
local SAVE_FILE = "stellar_assault_save.dat"

-- Default save data structure
local defaultSaveData = {
    highScore = 0,
    leaderboard = {},
    unlockedLevels = {true}, -- Level 1 always unlocked
    totalBossesDefeated = 0,
    statistics = {
        totalPlayTime = 0,
        totalEnemiesDefeated = 0,
        totalDeaths = 0,
        favoriteShip = "alpha",
        bestKillCount = 0,
        bestSurvivalTime = 0
    },
    achievements = {},
    settings = {
        masterVolume = 1.0,
        sfxVolume = 1.0,
        musicVolume = 0.2,
        selectedShip = "alpha",
        displayMode = "windowed",
        highContrast = false,
        fontScale = 1
    },
    controls = {
        -- Default keyboard bindings
        keyboard = {
            left = "a",
            right = "d",
            up = "w",
            down = "s",
            shoot = "space",
            boost = "lshift",
            bomb = "b",
            pause = "escape"
        },
        -- Default gamepad bindings
        gamepad = {
            shoot = "a",
            bomb = "b",
            boost = "x",
            pause = "start"
        }
    },
    upgrades = {
        -- Incremental upgrades
        maxShield = 0,
        speedMultiplier = 0,
        fireRateMultiplier = 0,
        extraLives = 0,
        bombCapacity = 0,
        -- Unlock upgrades
        unlockBeta = false,
        unlockGamma = false
    },
    currentScore = 0,  -- Store the player's current score for the shop
    -- New persistent data
    levelStats = {},  -- Per-level best score and time
    unlockedShips = {alpha = true}
}

-- Current save data
local saveData = nil

function Persistence.init()
    saveData = Persistence.load()
end

function Persistence.load()
    local data = defaultSaveData
    
    if love.filesystem.getInfo(SAVE_FILE) then
        local contents = love.filesystem.read(SAVE_FILE)
        if contents then
            local success, loaded = pcall(function()
                return Persistence.decode(contents)
            end)
            
            if success and loaded then
                -- Merge with defaults to handle missing fields
                data = Persistence.merge(defaultSaveData, loaded)
                local migrated = false
                -- Migrate old ship unlock flags
                data.unlockedShips = data.unlockedShips or {alpha = true}
                if data.upgrades and data.upgrades.unlockBeta and not data.unlockedShips.beta then
                    data.unlockedShips.beta = true
                    migrated = true
                end
                if data.upgrades and data.upgrades.unlockGamma and not data.unlockedShips.gamma then
                    data.unlockedShips.gamma = true
                    migrated = true
                end
                -- Ensure level stats table exists
                if not data.levelStats then
                    data.levelStats = {}
                    migrated = true
                end
                if migrated then
                    Persistence.save(data)
                end
                logger.info("Save data loaded successfully")
            else
                logger.error("Failed to parse save data, using defaults")
            end
        end
    else
        logger.info("No save file found, creating new one")
        Persistence.save(data)
    end
    
    return data
end

function Persistence.save(data)
    data = data or saveData

    local success, encoded = pcall(function()
        return Persistence.encode(data)
    end)

    if success then
        if love.filesystem.getInfo(SAVE_FILE) then
            local existing = love.filesystem.read(SAVE_FILE)
            if existing then
                love.filesystem.write(SAVE_FILE .. ".bak", existing)
            end
        end
        local writeSuccess = love.filesystem.write(SAVE_FILE, encoded)
        if writeSuccess then
            logger.info("Save data written successfully")
        else
            logger.error("Failed to write save file")
        end
    else
        logger.error("Failed to encode save data")
    end
end

-- Simple JSON encoding/decoding (basic implementation)
function Persistence.encode(data)
    local function serialize(tbl, indent)
        indent = indent or 0
        local spacing = string.rep("  ", indent)
        local result = "{\n"
        
        local items = {}
        for k, v in pairs(tbl) do
            local key = string.format('"%s"', tostring(k))
            local value
            
            if type(v) == "table" then
                value = serialize(v, indent + 1)
            elseif type(v) == "string" then
                value = string.format('"%s"', v)
            elseif type(v) == "boolean" then
                value = tostring(v)
            else
                value = tostring(v)
            end
            
            table.insert(items, spacing .. "  " .. key .. ": " .. value)
        end
        
        result = result .. table.concat(items, ",\n") .. "\n" .. spacing .. "}"
        return result
    end
    
    return serialize(data)
end

function Persistence.decode(str)
    -- Very basic JSON parser - in production, use a proper JSON library
    local function parse()
        -- Remove whitespace and newlines
        str = str:gsub("[\n\r]", "")
        
        -- This is a simplified parser - for production use a real JSON library
        local success, result = pcall(function()
            return loadstring("return " .. str:gsub('(".-"):', function(match)
                return "[" .. match .. "] ="
            end))()
        end)
        
        if success then
            return result
        else
            -- Fallback to manual parsing
            return defaultSaveData
        end
    end
    
    return parse()
end

function Persistence.merge(default, loaded)
    local result = {}
    
    for k, v in pairs(default) do
        if type(v) == "table" and loaded[k] and type(loaded[k]) == "table" then
            result[k] = Persistence.merge(v, loaded[k])
        elseif loaded[k] ~= nil then
            result[k] = loaded[k]
        else
            result[k] = v
        end
    end
    
    return result
end

-- Public API functions
function Persistence.getHighScore()
    if saveData.leaderboard and #saveData.leaderboard > 0 then
        return saveData.leaderboard[1].score
    end
    return saveData.highScore or 0
end

function Persistence.getLeaderboard()
    return saveData.leaderboard or {}
end

function Persistence.setHighScore(score, name)
    name = name or "Player"

    if not saveData.leaderboard then
        saveData.leaderboard = {}
    end

    -- Insert new entry
    table.insert(saveData.leaderboard, {name = name, score = score})

    -- Sort descending by score
    table.sort(saveData.leaderboard, function(a, b)
        return a.score > b.score
    end)

    -- Trim to top 10
    while #saveData.leaderboard > 10 do
        table.remove(saveData.leaderboard)
    end

    -- Update legacy highScore field
    saveData.highScore = saveData.leaderboard[1].score

    Persistence.save()

    return score == saveData.highScore
end

function Persistence.unlockLevel(level)
    saveData.unlockedLevels[level] = true
    Persistence.save()
end

function Persistence.isLevelUnlocked(level)
    return saveData.unlockedLevels[level] == true
end

function Persistence.getUnlockedLevels()
    local count = 0
    for i = 1, 20 do
        if saveData.unlockedLevels[i] then
            count = count + 1
        else
            break
        end
    end
    return count
end

function Persistence.incrementBossesDefeated()
    saveData.totalBossesDefeated = (saveData.totalBossesDefeated or 0) + 1
    Persistence.save()
end

function Persistence.getBestKillCount()
    return saveData.statistics.bestKillCount or 0
end

function Persistence.getBestSurvivalTime()
    return saveData.statistics.bestSurvivalTime or 0
end

function Persistence.updateBestKillCount(kills)
    if kills > (saveData.statistics.bestKillCount or 0) then
        saveData.statistics.bestKillCount = kills
        Persistence.save()
        return true
    end
    return false
end

function Persistence.updateBestSurvivalTime(time)
    if time > (saveData.statistics.bestSurvivalTime or 0) then
        saveData.statistics.bestSurvivalTime = time
        Persistence.save()
        return true
    end
    return false
end

function Persistence.updateStatistics(stats)
    for k, v in pairs(stats) do
        if saveData.statistics[k] then
            if type(v) == "number" then
                saveData.statistics[k] = saveData.statistics[k] + v
            else
                saveData.statistics[k] = v
            end
        end
    end
    Persistence.save()
end

function Persistence.getSettings()
    return saveData.settings
end

function Persistence.updateSettings(settings)
    for k, v in pairs(settings) do
        saveData.settings[k] = v
    end
    Persistence.save()
end

function Persistence.getHighContrast()
    return saveData.settings.highContrast or false
end

function Persistence.setHighContrast(value)
    saveData.settings.highContrast = value
    Persistence.save()
end

function Persistence.getFontScale()
    return saveData.settings.fontScale or 1
end

function Persistence.setFontScale(scale)
    saveData.settings.fontScale = scale
    Persistence.save()
end

function Persistence.getSaveData()
    return saveData
end

-- Upgrade system functions
function Persistence.applyUpgrade(key, value, upgradeType)
    if not saveData.upgrades then
        saveData.upgrades = {}
    end
    
    if upgradeType == "incremental" then
        -- Add to existing value
        saveData.upgrades[key] = (saveData.upgrades[key] or 0) + value
    else
        -- Set value directly (for unlocks)
        saveData.upgrades[key] = value
        if key == "unlockBeta" then
            Persistence.unlockShip("beta")
        elseif key == "unlockGamma" then
            Persistence.unlockShip("gamma")
        end
    end
    
    Persistence.save()
    logger.info("Applied upgrade: " .. key .. " = " .. tostring(saveData.upgrades[key]))
end

function Persistence.getUpgrade(key)
    if not saveData.upgrades then
        return nil
    end
    return saveData.upgrades[key]
end

function Persistence.getUpgradeLevel(key)
    if not saveData.upgrades then
        return 0
    end
    return saveData.upgrades[key] or 0
end

function Persistence.getCurrentScore()
    return saveData.currentScore or 0
end

function Persistence.setCurrentScore(score)
    saveData.currentScore = score
    Persistence.save()
end

function Persistence.deductScore(amount)
    saveData.currentScore = math.max(0, (saveData.currentScore or 0) - amount)
    Persistence.save()
end

function Persistence.addScore(amount)
    saveData.currentScore = (saveData.currentScore or 0) + amount
    Persistence.save()
end

-- Update per-level best stats
function Persistence.updateLevelStats(level, score, time)
    saveData.levelStats = saveData.levelStats or {}
    local stats = saveData.levelStats[level] or {}
    if not stats.bestScore or score > stats.bestScore then
        stats.bestScore = score
    end
    if time and (not stats.bestTime or time < stats.bestTime) then
        stats.bestTime = time
    end
    saveData.levelStats[level] = stats
    Persistence.save()
end

function Persistence.getLevelStats(level)
    if saveData.levelStats and saveData.levelStats[level] then
        return saveData.levelStats[level]
    end
    return {bestScore = 0}
end

function Persistence.unlockShip(name)
    saveData.unlockedShips = saveData.unlockedShips or {alpha = true}
    if not saveData.unlockedShips[name] then
        saveData.unlockedShips[name] = true
        Persistence.save()
    end
end

function Persistence.getUnlockedShips()
    local ships = {}
    for name in pairs(saveData.unlockedShips or {alpha = true}) do
        table.insert(ships, name)
    end
    return ships
end

-- Check if a ship is unlocked
function Persistence.isShipUnlocked(shipName)
    if shipName == "alpha" then
        return true
    end
    if saveData.unlockedShips and saveData.unlockedShips[shipName] then
        return true
    end
    -- Fallback to old upgrade flags
    if shipName == "beta" then
        return saveData.upgrades and saveData.upgrades.unlockBeta == true
    elseif shipName == "gamma" then
        return saveData.upgrades and saveData.upgrades.unlockGamma == true
    end
    return false
end

-- Control binding functions
function Persistence.getKeyBinding(action)
    if not saveData.controls or not saveData.controls.keyboard then
        return defaultSaveData.controls.keyboard[action]
    end
    return saveData.controls.keyboard[action] or defaultSaveData.controls.keyboard[action]
end

function Persistence.setKeyBinding(action, key)
    if not saveData.controls then
        saveData.controls = defaultSaveData.controls
    end
    if not saveData.controls.keyboard then
        saveData.controls.keyboard = defaultSaveData.controls.keyboard
    end
    saveData.controls.keyboard[action] = key
    Persistence.save()
end

function Persistence.getGamepadBinding(action)
    if not saveData.controls or not saveData.controls.gamepad then
        return defaultSaveData.controls.gamepad[action]
    end
    return saveData.controls.gamepad[action] or defaultSaveData.controls.gamepad[action]
end

function Persistence.setGamepadBinding(action, button)
    if not saveData.controls then
        saveData.controls = defaultSaveData.controls
    end
    if not saveData.controls.gamepad then
        saveData.controls.gamepad = defaultSaveData.controls.gamepad
    end
    saveData.controls.gamepad[action] = button
    Persistence.save()
end

function Persistence.getControls()
    return saveData.controls or defaultSaveData.controls
end

function Persistence.resetControls()
    saveData.controls = defaultSaveData.controls
    Persistence.save()
end

return Persistence
