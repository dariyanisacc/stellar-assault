local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

-- Provide file reads for constants
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
local Scene = require("src.scene")
_G.Game = require("src.game")

describe("PlayerControl gamepad drift gating", function()
  local state

  -- Stub one gamepad with constant leftX axis
  local function setJoystickAxis(value)
    love.joystick.getJoysticks = function()
      return {
        {
          isGamepad = function() return true end,
          getGamepadAxis = function(_, axis)
            if axis == "leftx" then return value end
            if axis == "lefty" then return 0 end
            if axis == "triggerright" then return 0 end
            return 0
          end,
        },
      }
    end
  end

  before_each(function()
    _G.player = {
      x = 100,
      y = 100,
      width = 20,
      height = 20,
      vx = 0,
      vy = 0,
      thrust = 100,
      drag = 0.5,
      maxSpeed = 200,
      heat = 0,
      maxHeat = 100,
      coolRate = 10,
      overheatTimer = 0,
      overheatPenalty = 1,
    }
    local scene = Scene.new()
    state = { keys = {}, scene = scene, laserPool = scene.laserPool }
    _G.selectedShip = "alpha"
    Game.lastInputType = "gamepad"
    Game.gamepadActiveTimer = 0
    setJoystickAxis(-0.8)
  end)

  it("ignores analog axis when not recently active", function()
    PlayerControl.update(state, 0.016)
    assert.are.equal(100, player.x) -- no movement
  end)

  it("uses analog axis when recently active", function()
    Game.gamepadActiveTimer = 1.0
    PlayerControl.update(state, 0.1)
    assert.is_true(player.x < 100) -- moved left
  end)
end)

