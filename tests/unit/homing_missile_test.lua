local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local PowerupHandler = require("src.powerup_handler")

describe("Homing Missile", function()
    it("moves toward nearest alien", function()
        _G.missiles = { {x = 0, y = 0, speed = 100} }
        _G.powerups = {}
        _G.powerupTexts = {}
        _G.aliens = { {x = 100, y = 0, width = 10, height = 10} }
        local state = {screenWidth = 200, screenHeight = 200, waveManager = {enemies = {}}}
        PowerupHandler.update(state, 1)
        assert.is_true(missiles[1].x > 0)
    end)
end)
