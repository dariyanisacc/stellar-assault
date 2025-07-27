local PlayerControl = require("src.player_control")

local Input = {}
Input.__index = Input

function Input:new(state)
  local obj = { state = state }
  setmetatable(obj, self)
  return obj
end

function Input:update(dt)
  -- placeholder for future per-frame input polling
end

function Input:keypressed(key, scancode, isrepeat)
  PlayerControl.handleKeyPress(self.state, key)
end

function Input:keyreleased(key, scancode)
  PlayerControl.handleKeyRelease(self.state, key)
end

function Input:gamepadpressed(joystick, button)
  PlayerControl.handleGamepadPress(self.state, button)
end

function Input:gamepadreleased(joystick, button)
  PlayerControl.handleGamepadRelease(self.state, button)
end

return Input
