local Persistence = require("src.persistence")

local InputManager = {}
InputManager.__index = InputManager

function InputManager:new(stateManager)
    local obj = setmetatable({}, self)
    obj.stateManager = stateManager
    obj.lastInputType = "keyboard"
    obj.controls = {}
    obj.keyToAction = {}
    obj.buttonToAction = {}
    obj:refreshBindings()
    return obj
end

function InputManager:refreshBindings()
    self.controls = Persistence.getControls()
    self.keyToAction = {}
    self.buttonToAction = {}
    if self.controls.keyboard then
        for action, key in pairs(self.controls.keyboard) do
            self.keyToAction[key] = action
        end
    end
    if self.controls.gamepad then
        for action, button in pairs(self.controls.gamepad) do
            self.buttonToAction[button] = action
        end
    end
end

function InputManager:updateInputType(t)
    if self.lastInputType ~= t then
        self.lastInputType = t
        _G.lastInputType = t
    end
end

function InputManager:dispatchPress(action)
    if self.stateManager and self.stateManager.current and self.stateManager.current.onPress then
        self.stateManager.current:onPress(action)
    end
end

function InputManager:dispatchRelease(action)
    if self.stateManager and self.stateManager.current and self.stateManager.current.onRelease then
        self.stateManager.current:onRelease(action)
    end
end

function InputManager:keypressed(key)
    local action = self.keyToAction[key]
    if action then
        self:updateInputType("keyboard")
        self:dispatchPress(action)
    elseif self.stateManager then
        self.stateManager:keypressed(key)
    end
end

function InputManager:keyreleased(key)
    local action = self.keyToAction[key]
    if action then
        self:updateInputType("keyboard")
        self:dispatchRelease(action)
    elseif self.stateManager then
        self.stateManager:keyreleased(key)
    end
end

function InputManager:gamepadpressed(button)
    local action = self.buttonToAction[button]
    self:updateInputType("gamepad")
    if action then
        self:dispatchPress(action)
    elseif self.stateManager and self.stateManager.current and self.stateManager.current.gamepadpressed then
        self.stateManager.current:gamepadpressed(nil, button)
    end
end

function InputManager:gamepadreleased(button)
    local action = self.buttonToAction[button]
    self:updateInputType("gamepad")
    if action then
        self:dispatchRelease(action)
    elseif self.stateManager and self.stateManager.current and self.stateManager.current.gamepadreleased then
        self.stateManager.current:gamepadreleased(nil, button)
    end
end

function InputManager:getAxis(axis)
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        local j = joysticks[1]
        if j:isGamepad() then
            local val = j:getGamepadAxis(axis) or 0
            if math.abs(val) > 0.2 then
                self:updateInputType("gamepad")
            end
            return val
        end
    end
    return 0
end

return InputManager
