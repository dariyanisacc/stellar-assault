-- tests/player_control_spec.lua
local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

-- Stub out love.filesystem.* for config loads
love.filesystem.append = function() end
love.filesystem.read = function(path)
  if path == "data/ships.json" then
    return [[
      {"alpha":{"name":"Alpha","spread":0,"fireRate":0.3,"speedMultiplier":1.0,"shieldMultiplier":1.0,"description":"Balanced fighter"}}
    ]]
  elseif path == "data/levels.json" then
    return [[{"bossFrequency":4}]]
  end
  return nil, "File not found"
end

local ObjectPool = require("src.objectpool")
local PlayerControl = require("src.player_control")
local Scene = require("src.scene")

describe("PlayerControl.shoot", function()
  local state

  before_each(function()
    --------------------------------------------------------------
    -- Scene & global tables
    --------------------------------------------------------------
    local scene = Scene.new() -- pooled resources
    _G.lasers = scene.lasers -- fallback globals
    _G.missiles = nil
    _G.activePowerups = scene.activePowerups
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

    --------------------------------------------------------------
    -- State stub passed to PlayerControl
    --------------------------------------------------------------
    state = {
      shootCooldown = 0,
      keys = { shoot = true },
      scene = scene,
      laserPool = scene.laserPool, -- use scene’s pool
    }
  end)

  it("spawns a laser and applies cooldown", function()
    PlayerControl.shoot(state)
    assert.equal(1, #state.scene.lasers)
    assert.is_true(state.shootCooldown > 0)
    assert.is_true(player.heat > 0)
  end)

  it("does not shoot when overheated", function()
    player.heat = player.maxHeat
    PlayerControl.shoot(state)
    assert.equal(0, #state.scene.lasers)
  end)
end)
