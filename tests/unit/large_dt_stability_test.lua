local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local PlayerControl = require("src.player_control")
local ObjectPool = require("src.objectpool")

describe("Large dt stability", function()
  local state

  before_each(function()
    _G.player = {
      x = 0,
      y = 0,
      width = 20,
      height = 20,
      vx = 0,
      vy = 0,
      thrust = 100,
      drag = 0.5,
      maxSpeed = 200,
      heat = 0,
      maxHeat = 100,
      heatRate = 5,
      coolRate = 1,
      overheatTimer = 0,
      overheatPenalty = 1,
    }
    _G.activePowerups = {}
    _G.selectedShip = "alpha"
    _G.lasers = {}

    state = {
      keys = { right = true, shoot = true },
      laserPool = ObjectPool.new(function()
        return {}
      end),
      shootCooldown = 0,
    }
  end)

  it("scales heat with dt", function()
    PlayerControl.update(state, 3) -- large dt step
    assert.are.equal(15, player.heat)
  end)
end)
