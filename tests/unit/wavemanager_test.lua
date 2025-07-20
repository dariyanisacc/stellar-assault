-- WaveManager Enemy Spawning Unit Tests
local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local WaveManager = require("src.wave_manager")

describe("WaveManager Spawning", function()
    local manager
    local player

    before_each(function()
        player = {x = 100, y = 100, width = 20, height = 20}
        manager = WaveManager:new(player)
        math.randomseed(1)
    end)

    it("starts wave and spawns enemies", function()
        manager:startWave(1)
        assert.is_true(manager:isActive())
        local remaining = manager.remainingToSpawn
        manager:update(manager.spawnInterval + 0.1)
        assert.is_true(#manager.enemies > 0)
        assert.is_true(manager.remainingToSpawn < remaining)
    end)

    it("completes wave after all enemies spawned and cleared", function()
        manager:startWave(1)
        while manager.remainingToSpawn > 0 do
            manager:update(manager.spawnInterval + 0.1)
        end
        manager.enemies = {}
        manager:update(0.1)
        assert.is_false(manager:isActive())
    end)
end)
