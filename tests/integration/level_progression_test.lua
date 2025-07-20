-- Level Progression Integration Test
local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local WaveManager = require("src.wave_manager")

describe("Level Progression", function()
    it("advances through multiple waves", function()
        local player = {x = 0, y = 0, width = 20, height = 20}
        local manager = WaveManager:new(player)

        manager:startWave(1)
        -- Complete first wave
        while manager.remainingToSpawn > 0 do
            manager:update(manager.spawnInterval + 0.1)
        end
        manager.enemies = {}
        manager:update(0.1)
        assert.is_false(manager:isActive())

        manager:startWave()
        assert.equals(2, manager.waveNumber)
    end)
end)
