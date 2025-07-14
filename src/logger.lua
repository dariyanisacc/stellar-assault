-- Logger module for Stellar Assault
local Logger = {}
Logger.__index = Logger

local LOG_LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5
}

local LOG_LEVEL_NAMES = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "FATAL"
}

local LOG_COLORS = {
    [1] = {0.5, 0.5, 0.5}, -- DEBUG: gray
    [2] = {1, 1, 1},       -- INFO: white
    [3] = {1, 1, 0},       -- WARN: yellow
    [4] = {1, 0, 0},       -- ERROR: red
    [5] = {1, 0, 1}        -- FATAL: magenta
}

function Logger:new(filename, minLevel)
    local self = setmetatable({}, Logger)
    
    self.filename = filename or "stellar_assault.log"
    self.minLevel = minLevel or LOG_LEVELS.INFO
    self.buffer = {}
    self.maxBufferSize = 100
    self.consoleOutput = true
    self.fileOutput = true
    
    -- Initialize log file
    if self.fileOutput and love.filesystem then
        love.filesystem.write(self.filename, "=== Stellar Assault Log Started at " .. 
                             os.date("%Y-%m-%d %H:%M:%S") .. " ===\n")
    end
    
    return self
end

function Logger:setLevel(level)
    if type(level) == "string" then
        self.minLevel = LOG_LEVELS[level:upper()] or LOG_LEVELS.INFO
    else
        self.minLevel = level
    end
end

function Logger:log(level, message, ...)
    if level < self.minLevel then return end
    
    -- Format message with varargs
    local formattedMessage = message
    local args = {...}
    if #args > 0 then
        formattedMessage = string.format(message, ...)
    end
    
    -- Create log entry
    local timestamp = string.format("%.3f", love.timer and love.timer.getTime() or 0)
    local levelName = LOG_LEVEL_NAMES[level] or "UNKNOWN"
    local logLine = string.format("[%s] %s: %s", timestamp, levelName, formattedMessage)
    
    -- Add to buffer
    table.insert(self.buffer, {
        level = level,
        message = formattedMessage,
        timestamp = timestamp,
        raw = logLine
    })
    
    -- Limit buffer size
    while #self.buffer > self.maxBufferSize do
        table.remove(self.buffer, 1)
    end
    
    -- Console output
    if self.consoleOutput then
        print(logLine)
    end
    
    -- File output
    if self.fileOutput and love.filesystem then
        love.filesystem.append(self.filename, logLine .. "\n")
    end
end

-- Convenience methods
function Logger:debug(message, ...)
    self:log(LOG_LEVELS.DEBUG, message, ...)
end

function Logger:info(message, ...)
    self:log(LOG_LEVELS.INFO, message, ...)
end

function Logger:warn(message, ...)
    self:log(LOG_LEVELS.WARN, message, ...)
end

function Logger:error(message, ...)
    self:log(LOG_LEVELS.ERROR, message, ...)
end

function Logger:fatal(message, ...)
    self:log(LOG_LEVELS.FATAL, message, ...)
end

-- Get recent log entries
function Logger:getBuffer()
    return self.buffer
end

-- Draw log overlay (useful for debugging)
function Logger:drawOverlay(x, y, maxLines)
    x = x or 10
    y = y or 10
    maxLines = maxLines or 10
    
    local font = love.graphics.getFont()
    local lineHeight = font:getHeight()
    
    -- Draw background
    local width = 600
    local height = lineHeight * maxLines + 10
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x - 5, y - 5, width, height)
    
    -- Draw log entries
    local startIndex = math.max(1, #self.buffer - maxLines + 1)
    local drawY = y
    
    for i = startIndex, #self.buffer do
        local entry = self.buffer[i]
        local color = LOG_COLORS[entry.level] or {1, 1, 1}
        
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.print(entry.raw, x, drawY)
        drawY = drawY + lineHeight
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Export log to string
function Logger:export()
    local output = {}
    for _, entry in ipairs(self.buffer) do
        table.insert(output, entry.raw)
    end
    return table.concat(output, "\n")
end

-- Clear log
function Logger:clear()
    self.buffer = {}
    if self.fileOutput and love.filesystem then
        love.filesystem.write(self.filename, "=== Log Cleared at " .. 
                             os.date("%Y-%m-%d %H:%M:%S") .. " ===\n")
    end
end

-- Create global logger instance
local globalLogger = Logger:new()

-- Module exports
return {
    Logger = Logger,
    LOG_LEVELS = LOG_LEVELS,
    
    -- Global logger methods
    setLevel = function(level) globalLogger:setLevel(level) end,
    debug = function(...) globalLogger:debug(...) end,
    info = function(...) globalLogger:info(...) end,
    warn = function(...) globalLogger:warn(...) end,
    error = function(...) globalLogger:error(...) end,
    fatal = function(...) globalLogger:fatal(...) end,
    drawOverlay = function(...) globalLogger:drawOverlay(...) end,
    clear = function() globalLogger:clear() end,
    export = function() return globalLogger:export() end
}