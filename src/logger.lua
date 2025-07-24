-- src/logger.lua
-- Logger implementation for Stellar Assault (supports levels, formatted logs, and on-screen overlay)

local Logger = {}
Logger.__index = Logger

Logger.levels = {
    debug = 1,
    info = 2,
    warn = 3,
    error = 4
}

function Logger:new()
    local self = setmetatable({}, Logger)
    self.currentLevel = self.levels.info
    self.history = {}
    self.overlayEnabled = false  -- Toggled via console command; main.lua can call drawOverlay always, this checks internally
    return self
end

function Logger:setLevel(levelStr)
    local level = self.levels[levelStr:lower()]
    if level then
        self.currentLevel = level
    else
        print("[LOGGER] Invalid log level: " .. levelStr .. ". Defaulting to INFO.")
        self.currentLevel = self.levels.info
    end
end

function Logger:toggleOverlay()
    self.overlayEnabled = not self.overlayEnabled
end

function Logger:internalLog(levelStr, fmt, ...)
    local levelNum = self.levels[levelStr:lower()]
    if not levelNum or levelNum < self.currentLevel then
        return
    end

    local msg = string.format(fmt, ...)
    print("[" .. levelStr:upper() .. "] " .. msg)
    table.insert(self.history, "[" .. levelStr:upper() .. "] " .. msg)
    if #self.history > 50 then
        table.remove(self.history, 1)
    end
end

function Logger:debug(fmt, ...) self:internalLog("debug", fmt, ...) end
function Logger:info(fmt, ...) self:internalLog("info", fmt, ...) end
function Logger:warn(fmt, ...) self:internalLog("warn", fmt, ...) end
function Logger:error(fmt, ...) self:internalLog("error", fmt, ...) end

function Logger:drawOverlay(x, y, lineSpacing)
    if not self.overlayEnabled then return end

    local font = love.graphics.getFont() or love.graphics.newFont(12)
    local screenH = love.graphics.getHeight()
    local maxHeight = screenH - y
    local numLines = math.floor(maxHeight / lineSpacing)
    local startIdx = math.max(1, #self.history - numLines + 1)

    love.graphics.setColor(1, 1, 1, 0.8)  -- Semi-transparent white for visibility
    for i = 1, numLines do
        local idx = startIdx + i - 1
        if idx <= #self.history then
            love.graphics.print(self.history[idx], x, y + (i - 1) * lineSpacing)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)  -- Reset color
end

return Logger