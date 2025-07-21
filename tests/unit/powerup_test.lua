-- Powerup Effects Unit Tests
local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

local Powerup = require("src.entities.powerup")

describe("Powerup Effects", function()
    local player

    before_each(function()
        player = {shield = 2, maxShield = 5}
    end)

    it("grants shield when collecting health powerup", function()
        local p = Powerup.new(0, 0, "health")
        local result = p:collect(player)
        assert.equals(3, player.shield)
        assert.is_true(result)
    end)

    it("returns bomb flag for bomb powerup", function()
        local p = Powerup.new(0, 0, "bomb")
        local result = p:collect(player)
        assert.equals("bomb", result)
    end)

    it("returns timed effect table for rapid powerup", function()
        local p = Powerup.new(0, 0, "rapid")
        local result = p:collect(player)
        assert.equals("rapid", result.type)
        assert.is_number(result.duration)
        assert.equals(result.duration, result.timer)
    end)

    it("returns timed effect for homingMissile powerup", function()
        local p = Powerup.new(0, 0, "homingMissile")
        local result = p:collect(player)
        assert.equals("homingMissile", result.type)
        assert.equals(5, result.duration)
        assert.equals(result.duration, result.timer)
    end)
end)
