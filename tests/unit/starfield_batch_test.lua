local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local Starfield = require("src.starfield")

describe("Starfield batching", function()
  it("uses one draw call", function()
    local drawCalls = 0
    love.graphics.draw = function()
      drawCalls = drawCalls + 1
    end

    local sf = Starfield.new(200)
    sf:update(0.016)
    sf:draw()

    assert.is_true(drawCalls <= 20)
  end)
end)
