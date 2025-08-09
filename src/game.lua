-- src/game.lua
-- Lightweight global game namespace and helpers used across states.

local Game = {
  isPaused = false,
  isGameOver = false,
  overReason = nil,
  -- Input tuning (used by PlayerControl and main callbacks)
  gamepadDeadzone = 0.35,           -- analog stick magnitude threshold
  gamepadTriggerThreshold = 0.75,   -- right-trigger fire threshold
  gamepadActiveTimer = 0,           -- seconds remaining that stick is considered active
  gamepadActiveTimeout = 1.0,       -- how long after movement we trust the stick
}

function Game:reset()
  self.isPaused = false
  self.isGameOver = false
  self.overReason = nil
end

function Game:pause()
  self.isPaused = true
end

function Game:resume()
  self.isPaused = false
end

function Game:gameOver(arg)
  self.isGameOver = true
  if type(arg) == "table" then
    self.overReason = arg.reason
  else
    self.overReason = arg
  end
  local params = type(arg) == "table" and arg or { reason = arg }
  local sm = self.stateManager or _G.stateManager
  if sm and sm.switch then
    sm:switch("gameover", params)
  end
end

return Game
