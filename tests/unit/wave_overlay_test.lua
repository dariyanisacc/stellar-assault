local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local Persistence = require("src.persistence")
Persistence.init()

local PlayingState = require("states.playing")

describe("Wave Overlay", function()
    it("appears when a wave is completed", function()
        local state = setmetatable({}, {__index = PlayingState})
        state:enter()
        local manager = state.waveManager
        while manager.remainingToSpawn > 0 do
            manager:update(manager.spawnInterval + 0.1)
        end
        manager.enemies = {}
        manager:update(0.1)
        assert.is_table(state.waveOverlay)
        assert.is_true(state.waveOverlay.timer > 0)
    end)
end)
