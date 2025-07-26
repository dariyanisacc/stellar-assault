-- src/debugconsole.lua
-- Basic debug console implementation for Stellar Assault

local DebugConsole = {}
DebugConsole.__index = DebugConsole

function DebugConsole:new(font)
    local self = setmetatable({}, DebugConsole)
    self.font = font or love.graphics.newFont(14)
    self.active = false
    self.input = ""
    self.history = {}
    self.commands = {}
    self.debugInfo = false
    self.debugOverlay = false
    self:addDefaultCommands()
    return self
end

function DebugConsole:addDefaultCommands()
    self.commands["help"] = function(args)
        self:print("Available commands: help, quit, system, player, game, spawn")
    end
    self.commands["quit"] = function(args)
        love.event.quit()
    end
    self.commands["system"] = function(args)
        self:print("System info: FPS " .. love.timer.getFPS() .. ", Delta " .. love.timer.getDelta())
    end
    self.commands["player"] = function(args)
        self:print("Player commands not implemented yet. Use to query/modify player state.")
    end
    self.commands["game"] = function(args)
        self:print("Game commands not implemented yet. Use to query/modify game state.")
    end
    self.commands["spawn"] = function(args)
        self:print("Spawn commands not implemented yet. Use to spawn entities.")
    end
    -- Add more custom commands here as needed for Stellar Assault (e.g., integrating with StateManager)
end

function DebugConsole:print(text)
    table.insert(self.history, text)
    if #self.history > 50 then
        table.remove(self.history, 1)
    end
end

function DebugConsole:keypressed(key)
    if key == "`" or key == "~" then
        self.active = not self.active
        return true
    elseif key == "f3" then
        self.debugInfo = not self.debugInfo
        self:print("Debug info toggled: " .. tostring(self.debugInfo))
        return true
    elseif key == "f9" then
        self.debugOverlay = not self.debugOverlay
        self:print("Debug overlay toggled: " .. tostring(self.debugOverlay))
        return true
    end

    if self.active then
        if key == "return" then
            self:execute(self.input)
            self.input = ""
        elseif key == "backspace" then
            self.input = self.input:sub(1, -2)
        end
        return true
    end
    return false
end

function DebugConsole:textinput(text)
    if self.active then
        self.input = self.input .. text
        return true
    end
    return false
end

function DebugConsole:execute(input)
    if input == "" then return end
    self:print("> " .. input)
    local parts = {}
    for word in input:gmatch("%S+") do
        table.insert(parts, word)
    end
    local cmd = table.remove(parts, 1)
    if self.commands[cmd] then
        self.commands[cmd](parts)
    else
        self:print("Unknown command: " .. cmd)
    end
end

function DebugConsole:update(dt)
    -- Optional: Add any update logic, e.g., for live debugging
end

function DebugConsole:draw()
    if self.debugInfo then
        love.graphics.setFont(self.font)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
        -- Add more debug info here (e.g., player position, score)
    end

    if self.debugOverlay then
        -- Draw overlay (e.g., grid, hitboxes) - implement as needed
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.rectangle("line", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    if not self.active then return end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, h * 0.5, w, h * 0.5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(self.font)

    local y = h * 0.5 + 10
    for _, line in ipairs(self.history) do
        love.graphics.print(line, 10, y)
        y = y + self.font:getHeight()
        if y > h - self.font:getHeight() - 10 then break end
    end

    love.graphics.print("> " .. self.input .. "_", 10, h - self.font:getHeight() - 10)
end

return DebugConsole
