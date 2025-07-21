-- Combo Bonus Unit Tests
local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local Persistence = require("src.persistence")
Persistence.addScore = function() end
local PlayingState

local function setupState(combo)
    _G.powerups = {}
    _G.powerupTexts = {}
    _G.asteroids = {}
    _G.aliens = {}
    _G.lasers = {}
    _G.alienLasers = {}
    _G.explosions = {}
    _G.activePowerups = {}
    _G.score = 0
    _G.enemiesDefeated = 0
    _G.currentLevel = 1

    local state = setmetatable({
        combo = combo,
        comboTimer = 0,
        comboMultiplier = 1,
        sessionEnemiesDefeated = 0,
        previousHighScore = 0,
        newHighScore = false,
        createExplosion = function() end,
        showNewHighScoreNotification = function() end,
        camera = {shake = function() end},
    }, {__index = PlayingState})

    return state
end

local function stubRandom(value)
    local called = false
    love.math.random = function(a, b)
        if a then
            if b then return a end
            return a
        end
        if not called then
            called = true
            return value
        end
        return 1
    end
    package.loaded["states.playing"] = nil
    PlayingState = require("states.playing")
end

describe("Combo Bonus", function()
    it("spawns coolant powerup when combo is high", function()
        stubRandom(0.04)
        local state = setupState(9)
        local asteroid = {x=50, y=60, size=20}
        state:handleAsteroidDestruction(asteroid, 1)
        assert.equals(1, #powerups)
        assert.equals("coolant", powerups[1].type)
        assert.equals(1, #powerupTexts)
        assert.equals("COMBO BONUS!", powerupTexts[1].text)
    end)

    it("spawns bonus on alien destruction at high combo", function()
        stubRandom(0.04)
        local state = setupState(9)
        local alien = {x=30, y=40}
        state:handleAlienDestruction(alien, 1)
        assert.equals(1, #powerups)
        assert.equals("coolant", powerups[1].type)
        assert.equals(1, #powerupTexts)
        assert.equals("COMBO BONUS!", powerupTexts[1].text)
    end)

    it("does not spawn bonus when combo below threshold", function()
        stubRandom(0.3)
        local state = setupState(5)
        local alien = {x=40, y=40}
        state:handleAlienDestruction(alien, 1)
        assert.equals(0, #powerups)
        assert.equals(0, #powerupTexts)
    end)
end)
