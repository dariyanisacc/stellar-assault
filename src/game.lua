-- src/game.lua
-- Lightweight global game namespace and helpers used across states.

local Game = {
  isPaused = false,
  isGameOver = false,
  overReason = nil,
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

function Game:gameOver(reason)
  self.isGameOver = true
  self.overReason = reason
  if _G.stateManager and stateManager.switch then
    stateManager:switch("gameover", { reason = reason })
  end
end

return Game
