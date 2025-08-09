local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end
love.filesystem.read = function(path)
  if path == "data/ships.json" then
    return [[{"alpha":{"name":"Alpha","spread":0,"fireRate":0.3,"speedMultiplier":1.0,"shieldMultiplier":1.0,"description":"Balanced fighter"}}]]
  elseif path == "data/levels.json" then
    return [[{"bossFrequency":4}]]
  end
  return nil, "File not found"
end

local PlayerControl = require("src.player_control")
local ObjectPool = require("src.objectpool")
local Scene = require("src.scene")

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
    local scene = Scene.new()
    _G.selectedShip = "alpha"

    state = {
      keys = { right = true, shoot = true },
      laserPool = scene.laserPool,
      shootCooldown = 0,
      scene = scene,
    }
    state.scene.activePowerups = {}
  end)

  it("adds heat per shot regardless of dt", function()
    PlayerControl.update(state, 3) -- large dt step should not multiply heat per shot
    assert.are.equal(player.heatRate, player.heat)
  end)
end)
