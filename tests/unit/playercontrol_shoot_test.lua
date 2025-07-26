-- tests/player_control_spec.lua
local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local ObjectPool = require("src.objectpool")
local PlayerControl = require("src.player_control")
local Scene = require("src.scene")

describe("PlayerControl.shoot", function()
  local state

  before_each(function()
    local scene = Scene.new()
    _G.missiles = nil
    _G.selectedShip = "alpha"
    _G.player = {
      x = 50,
      y = 100,
      width = 20,
      height = 20,
      heat = 0,
      maxHeat = 100,
      heatRate = 5,
      overheatTimer = 0,
      overheatPenalty = 1.5,
    }
    state = {
      shootCooldown = 0,
      keys = { shoot = true },
      laserPool = scene.laserPool,
      scene = scene,
    }
    state.scene.activePowerups = {}
  end)

  it("spawns a laser and applies cooldown", function()
    PlayerControl.shoot(state)
    assert.equals(1, #state.scene.lasers)
    assert.is_true(state.shootCooldown > 0)
    assert.is_true(player.heat > 0)
  end)

  it("does not shoot when overheated", function()
    player.heat = player.maxHeat
    PlayerControl.shoot(state)
    assert.equals(0, #state.scene.lasers)
    assert.is_true(player.overheatTimer > 0)
  end)

  it("creates multiple lasers with multiShot", function()
    state.scene.activePowerups.multiShot = true
    PlayerControl.shoot(state)
    assert.equals(3, #state.scene.lasers)
  end)
end)
