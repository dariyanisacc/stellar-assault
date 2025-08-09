-- src/bossmanager.lua

-- BossManager keeps track of the currently active boss entity and
-- provides simple helpers for spawning, updating and drawing it. The
-- previous implementation was a bare table without any constructor,
-- which caused `BossManager:new()` calls to fail in `playing.lua`.

local Game = require("src.game")
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

--- Spawn a boss by type and position, injecting sprite from Game.bossSprites.
-- @param kind string|nil Logical boss kind (unused for sprite selection for now)
-- @param x    number
-- @param y    number
function BossManager:spawnBoss(kind, x, y)
  local Boss = require("src.entities.boss")
  local level = (_G.currentLevel or 1)
  -- Choose sprite by current level index if available; cycle if needed
  local available = Game and Game.bossSprites or {}
  local count = 0
  for i = 1, math.huge do
    if available[i] then count = count + 1 else break end
  end
  local idx = (count > 0) and (((level - 1) % count) + 1) or 1
  local sprite = available[idx]

  self.activeBoss = Boss.new(level, { sprite = sprite, x = x, y = y, name = kind })
  return self.activeBoss
end

--- Update the active boss, if any.
-- @param dt      number  Delta time
-- @param bullets table? Optional bullet pool passed to the boss entity
function BossManager:update(dt, bullets)
  if self.activeBoss and self.activeBoss.update then
    self.activeBoss:update(dt, bullets)
  end
end

--- Apply damage to the active boss, normalizing hp/health fields.
-- @param amount number
function BossManager:takeDamage(amount)
  local b = self.activeBoss
  if not b or not amount or amount <= 0 then return end
  -- Normalize fields
  local maxH = b.maxHealth or b.maxHP or 0
  local curH = (b.health ~= nil) and b.health or b.hp
  if curH == nil then
    -- Initialize to a sane default if missing
    curH = maxH > 0 and maxH or 100
  end
  curH = math.max(0, curH - amount)
  -- Write back to both conventions
  b.health = curH
  if b.hp ~= nil then b.hp = curH end
  if b.maxHealth == nil and b.maxHP ~= nil then b.maxHealth = b.maxHP end

  -- Enter dying state if depleted
  if curH <= 0 then
    b.state = "dying"
    b.stateTimer = 0
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
