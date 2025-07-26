-- tests/player_control_spec.lua
local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local ObjectPool    = require("src.objectpool")
local PlayerControl = require("src.player_control")

describe("PlayerControl.shoot", function()
  local state

  before_each(function()
    _G.lasers         = {}
    _G.missiles       = nil
    _G.activePowerups = {}
    _G.selectedShip   = "alpha"
    _G.player = {
      x              = 50,
      y              = 100,
      width          = 20,
      height         = 20,
      heat           = 0,
      maxHeat        = 100,
      heatRate       = 5,
      overheatTimer  = 0,
      overheatPenalty = 1.5,
    }

    state = {
      shootCooldown = 0,
      laserPool     = ObjectPool.createLaserPool(),
      keys          = { shoot = true },
    }
  end)

  it("spawns a laser and applies cooldown", function()
    PlayerControl.shoot(state)
    assert.equals(1, #lasers)
    assert.is_true(state.shootCooldown > 0)
    assert.is_true(player.heat > 0)
  end)

  it("does not shoot when overheated", function()
    player.heat = player.maxHeat
    PlayerControl.shoot(state)
    assert.equals(0, #lasers)
    assert.is_true(player.overheatTimer > 0)
  end)

  it("creates multiple lasers with multiShot", function()
    activePowerups.multiShot = true
    PlayerControl.shoot(state)
    assert.equals(3, #lasers)
  end)
end)
