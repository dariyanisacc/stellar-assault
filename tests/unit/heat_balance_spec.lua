local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

-- Stub JSON reads
love.filesystem.append = function() end
love.filesystem.read = function(path)
  if path == "data/ships.json" then
    return [[{"alpha":{"name":"Alpha","spread":0,"fireRate":0.3,"speedMultiplier":1.0,"shieldMultiplier":1.0,"description":"Balanced fighter"}}]]
  elseif path == "data/levels.json" then
    return [[{"bossFrequency":4}]]
  elseif path == "data/balance.json" then
    return [[{"heatPerShot":8, "coolRate":10}]]
  end
  return nil, "File not found"
end

local Constants = require("src.constants")
local PlayerControl = require("src.player_control")
local Scene = require("src.scene")

describe("Heat balance under sustained fire", function()
  local state
  before_each(function()
    local scene = Scene.new()
    _G.selectedShip = "alpha"
    _G.player = {
      x = 50, y = 100, width = 20, height = 20,
      heat = 0, maxHeat = 100,
      heatRate = (Constants.balance.heatPerShot or 8),
      coolRate = (Constants.balance.coolRate or 10),
      overheatTimer = 0, overheatPenalty = 1.0,
      vx = 0, vy = 0, thrust = 0, drag = 0, maxSpeed = 0,
    }
    state = {
      keys = { shoot = true },
      scene = scene,
      laserPool = scene.laserPool,
      shootCooldown = 0,
    }
  end)

  it("reaches overheat in ~6-8s of continuous fire", function()
    local t, dt = 0, 0.05
    local timeout, overheatedAt
    while t < 10 do
      PlayerControl.update(state, dt)
      t = t + dt
      if (player.overheatTimer or 0) > 0 or (player.heat or 0) >= (player.maxHeat or 100) then
        overheatedAt = t
        break
      end
    end
    assert.is_true(overheatedAt ~= nil, "did not overheat within 10s")
    assert.is_true(overheatedAt > 5.0 and overheatedAt < 8.5, ("overheated at %.2fs"):format(overheatedAt))
  end)

  it("cools back down when not firing", function()
    -- Heat up briefly
    PlayerControl.update(state, 0.5)
    local hot = player.heat
    state.keys.shoot = false
    PlayerControl.update(state, 1.0)
    assert.is_true(player.heat < hot)
  end)
end)

