-- Basic Game Loop Integration Test
local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local WaveManager = require("src.wave_manager")

describe("Game Loop", function()
    it("runs update cycle without errors", function()
        local player = {x = 50, y = 50, width = 20, height = 20}
        local manager = WaveManager:new(player)
        manager:startWave(1)

        for i = 1, 5 do
            manager:update(manager.spawnInterval + 0.05)
            manager:updateLasers(0.05)
        end

        assert.is_true(manager:getEnemyCount() > 0)
    end)
end)
