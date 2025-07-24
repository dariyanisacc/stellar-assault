-- gamestate.lua
-- Manages game states for Stellar Assault (e.g., menu, gameplay, pause).
-- Usage: local gs = require('gamestate').new()
-- gs:register('menu', require('menu'))
-- gs:switch('menu')

local GameState = {}
GameState.__index = GameState

-- Create a new GameState manager instance
function GameState.new()
    local self = setmetatable({}, GameState)
    self.currentState = nil
    self.states = {}
    return self
end

-- Register a state with a name and its table of callbacks
function GameState:register(name, state)
    if not state or type(state) ~= "table" then
        error("Invalid state table for '" .. name .. "'")
    end
    self.states[name] = state
end

-- Switch to a new state
function GameState:switch(name)
    if not self.states[name] then
        error("State '" .. name .. "' not registered")
    end
    if self.currentState and self.states[self.currentState].exit then
        self.states[self.currentState]:exit()
    end
    self.currentState = name
    if self.states[name].enter then
        self.states[name]:enter()
    end
end

-- Reset the current state (useful for restarting levels in Stellar Assault)
function GameState:reset()
    if self.currentState and self.states[self.currentState].reset then
        self.states[self.currentState]:reset()
    end
end

-- Update the current state
function GameState:update(dt)
    if self.currentState and self.states[self.currentState].update then
        self.states[self.currentState]:update(dt)
    end
end

-- Draw the current state
function GameState:draw()
    if self.currentState and self.states[self.currentState].draw then
        self.states[self.currentState]:draw()
    end
end

-- Handle key presses
function GameState:keypressed(key)
    if self.currentState and self.states[self.currentState].keypressed then
        self.states[self.currentState]:keypressed(key)
    end
end

-- Handle key releases (added for better input handling in games like Stellar Assault)
function GameState:keyreleased(key)
    if self.currentState and self.states[self.currentState].keyreleased then
        self.states[self.currentState]:keyreleased(key)
    end
end

-- Handle window resize (useful for responsive UI)
function GameState:resize(w, h)
    if self.currentState and self.states[self.currentState].resize then
        self.states[self.currentState]:resize(w, h)
    end
end

-- Add more Love2D callbacks as needed (e.g., mousepressed, etc.)

return GameState