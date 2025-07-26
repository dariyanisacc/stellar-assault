-- State Manager for Stellar Assault
local StateManager = {}
StateManager.__index = StateManager

function StateManager:new()
    local self = setmetatable({}, StateManager)
    self.states = {}
    self.current = nil
    self.currentName = nil
    return self
end

function StateManager:register(name, state)
    self.states[name] = state
end

function StateManager:switch(name, ...)
    if not self.states[name] then
        error("State '" .. name .. "' not found!")
    end
    
    -- Leave current state
    if self.current and self.current.leave then
        self.current:leave()
    end
    
    -- Switch to new state
    self.currentName = name
    self.current = self.states[name]
    
    -- Enter new state
    if self.current.enter then
        self.current:enter(...)
    end
end

function StateManager:update(dt)
    if self.current and self.current.update then
        self.current:update(dt)
    end
end

function StateManager:draw()
    if self.current and self.current.draw then
        self.current:draw()
    end
end

function StateManager:keypressed(key, scancode, isrepeat)
    if self.current and self.current.keypressed then
        self.current:keypressed(key, scancode, isrepeat)
    end
end

function StateManager:keyreleased(key, scancode)
    if self.current and self.current.keyreleased then
        self.current:keyreleased(key, scancode)
    end
end

function StateManager:mousepressed(x, y, button, istouch, presses)
    if self.current and self.current.mousepressed then
        self.current:mousepressed(x, y, button, istouch, presses)
    end
end

function StateManager:gamepadpressed(joystick, button)
    if self.current and self.current.gamepadpressed then
        self.current:gamepadpressed(joystick, button)
    end
end

function StateManager:gamepadreleased(joystick, button)
    if self.current and self.current.gamepadreleased then
        self.current:gamepadreleased(joystick, button)
    end
end

function StateManager:resize(w, h)
    if self.current and self.current.resize then
        self.current:resize(w, h)
    end
end

return StateManager
