-- Score Handling Unit Tests
local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local Persistence = require("src.persistence")

describe("Score Handling", function()
    before_each(function()
        Persistence.init()
        Persistence.setCurrentScore(0)
    end)

    it("adds score correctly", function()
        Persistence.addScore(15)
        assert.equals(15, Persistence.getCurrentScore())
    end)

    it("deducts score without going negative", function()
        Persistence.setCurrentScore(5)
        Persistence.deductScore(10)
        assert.equals(0, Persistence.getCurrentScore())
    end)

    it("sets current score", function()
        Persistence.setCurrentScore(123)
        assert.equals(123, Persistence.getCurrentScore())
    end)
end)
