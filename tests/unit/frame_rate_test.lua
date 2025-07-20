-- Frame rate independence tests for movement and timers

local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

local Powerup = require("src.entities.powerup")

-- helper to simulate updates over totalTime seconds at step dt
local function simulateUpdates(obj, dt, totalTime)
    local steps = math.floor(totalTime / dt + 0.5)
    for i = 1, steps do
        obj:update(dt)
    end
end

describe("Frame Rate Independence", function()
    it("powerup falls consistently across frame rates", function()
        local totalTime = 1
        local p60 = Powerup.new(0, 0, "rapid")
        local p30 = Powerup.new(0, 0, "rapid")
        simulateUpdates(p60, 1/60, totalTime)
        simulateUpdates(p30, 1/30, totalTime)
        assert.is_true(math.abs(p60.y - p30.y) < 0.01)
        assert.is_true(math.abs(p60.rotation - p30.rotation) < 0.01)
    end)
end)

