-- src/logger.lua
-- Simple logger for Stellar Assault
--  ✧ NEW ✧ 2025‑07‑25 : adds a singleton‑facade so dot‑style calls work
-----------------------------------------------------------------------

local Logger = {}
Logger.__index = Logger

-- log‑level → numeric priority
Logger.levels = { debug = 1, info = 2, warn = 3, error = 4 }

-----------------------------------------------------------------------
--  Core class --------------------------------------------------------
-----------------------------------------------------------------------

--- Construct a fresh logger object
function Logger:new()
  local self = setmetatable({}, Logger)
  self.currentLevel   = Logger.levels.info
  self.history        = {}           -- last 50 lines for on‑screen overlay
  self.overlayEnabled = false
  return self
end

--- Change active log level (“debug”, “info”, “warn”, “error”)
function Logger:setLevel(levelStr)
  local lvl = Logger.levels[(levelStr or ""):lower()]
  if lvl then
    self.currentLevel = lvl
  else
    print(("[LOGGER] Invalid level '%s' – keeping %d")
          :format(tostring(levelStr), self.currentLevel))
  end
end

--- Toggle on‑screen overlay
function Logger:toggleOverlay()  self.overlayEnabled = not self.overlayEnabled end

--- Internal helper that actually emits and stores the message
function Logger:internalLog(levelStr, fmt, ...)
  local idx = Logger.levels[levelStr]
  if not idx or idx < self.currentLevel then return end     -- filtered out

  local ok, msg = pcall(string.format, fmt, ...)
  if not ok then  msg = fmt  end                            -- bad format string

  local line = ("[%s] %s"):format(levelStr:upper(), msg)
  print(line)

  table.insert(self.history, line)
  if #self.history > 50 then table.remove(self.history, 1) end
end

function Logger:debug(fmt, ...) self:internalLog("debug", fmt, ...) end
function Logger:info (fmt, ...) self:internalLog("info",  fmt, ...) end
function Logger:warn (fmt, ...) self:internalLog("warn",  fmt, ...) end
function Logger:error(fmt, ...) self:internalLog("error", fmt, ...) end

--- Optional on‑screen overlay (toggle with logger.toggleOverlay())
function Logger:drawOverlay(x, y, lineSpacing)
  if not self.overlayEnabled then return end
  x, y             = x or 10, y or 10
  lineSpacing      = lineSpacing or 14
  local maxLines   = math.floor((love.graphics.getHeight() - y) / lineSpacing)
  local startIndex = math.max(1, #self.history - maxLines + 1)

  love.graphics.setColor(1, 1, 1, 0.8)
  for i = startIndex, #self.history do
    love.graphics.print(self.history[i], x, y + (i - startIndex) * lineSpacing)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-----------------------------------------------------------------------
--  Singleton facade (backwards‑compat) ------------------------------
-----------------------------------------------------------------------
-- Many existing modules do `local logger = require("src.logger")`
-- and then call `logger.info("text")` (dot‑syntax, *no* implicit `self`).
-- The facade below transparently injects the singleton object as `self`,
-- so no changes are needed elsewhere.
-----------------------------------------------------------------------

local _instance = Logger:new()
local facade    = {}

local function forward(method)
  return function(...)
    return _instance[method](_instance, ...)
  end
end

facade.debug         = forward("debug")
facade.info          = forward("info")
facade.warn          = forward("warn")
facade.error         = forward("error")
facade.setLevel      = forward("setLevel")
facade.toggleOverlay = forward("toggleOverlay")
facade.drawOverlay   = forward("drawOverlay")

-- expose the real object for advanced use‑cases
facade._instance = _instance

return facade
