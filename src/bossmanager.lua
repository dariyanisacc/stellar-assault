-- src/bossmanager.lua

-- BossManager keeps track of the currently active boss entity and
-- provides simple helpers for spawning, updating and drawing it. The
-- previous implementation was a bare table without any constructor,
-- which caused `BossManager:new()` calls to fail in `playing.lua`.

local BossManager = {}
BossManager.__index = BossManager

--- Create a new BossManager instance.
-- @return table BossManager
function BossManager:new()
  local self = setmetatable({}, BossManager)
  self.activeBoss = nil
  return self
end

--- Spawn a boss of the given level.
-- Falls back to `src.entities.boss` which implements a simple boss
-- behaviour. Games embedding this module can replace it with a more
-- advanced boss entity if desired.
-- @param level number|nil Level of the boss to spawn
function BossManager:spawn(level)
  local Boss = require("src.entities.boss")
  self.activeBoss = Boss.new(level or 1)
end

--- Update the active boss, if any.
-- @param dt      number  Delta time
-- @param bullets table? Optional bullet pool passed to the boss entity
function BossManager:update(dt, bullets)
  if self.activeBoss and self.activeBoss.update then
    self.activeBoss:update(dt, bullets)
  end
end

--- Draw the active boss.
function BossManager:draw()
  if self.activeBoss and self.activeBoss.draw then
    self.activeBoss:draw()
  end
end

--- Clear the active boss reference.
function BossManager:clear()
  self.activeBoss = nil
end

return BossManager
