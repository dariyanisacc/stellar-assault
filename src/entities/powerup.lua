-- src/entities/powerup.lua
-- Simple power‑up manager for Stellar Assault.
-- Provides spawning, updating, drawing and pickup handling for power‑up entities.
-- This (re‑)implementation is intentionally lightweight so it can act as a
-- drop‑in replacement for the original missing file referenced from
-- states/playing.lua.

local lg    = love.graphics
local timer = love.timer

local Powerup = {}

-- ========================================================================= --
-- >>> INTERNAL HELPERS
-- ========================================================================= --
local _images = {}
local _loaded = false

local function _tryLoadImage(name, fallbackColor)
  local ok, img = pcall(lg.newImage, ("assets/powerups/%s.png"):format(name))
  if ok and img then
    return { kind = name, img = img, w = img:getWidth(), h = img:getHeight() }
  else
    -- Use a dummy coloured circle if the sprite is missing
    return { kind = name, color = fallbackColor or {1, 1, 1}, w = 32, h = 32 }
  end
end

local function _ensureLoaded()
  if _loaded then return end
  _loaded = true
  -- Preload the common power‑up sprites (or fallbacks)
  _images["health"] = _tryLoadImage("health", {0.1, 1.0, 0.1})
  _images["shield"] = _tryLoadImage("shield", {0.1, 0.6, 1.0})
  _images["weapon"] = _tryLoadImage("weapon", {1.0, 0.6, 0.1})
  _images["score"]  = _tryLoadImage("score",  {1.0, 0.9, 0.1})
end

-- ========================================================================= --
-- >>> POWER‑UP INSTANCE OBJECT
-- ========================================================================= --
local PU = {}
PU.__index = PU

function PU:new(kind, x, y)
  _ensureLoaded()
  local sprite = _images[kind] or _images["score"]
  local o = {
    kind   = kind,
    x      = x,
    y      = y,
    r      = 0,        -- rotation for visual flair
    radius = math.max(sprite.w, sprite.h) * 0.5,
    sprite = sprite,
    ttl    = 15,       -- despawn after N seconds if unpicked
    active = true
  }
  return setmetatable(o, self)
end

function PU:update(dt)
  if not self.active then return end
  self.r = (self.r + dt) % (math.pi * 2)
  self.ttl = self.ttl - dt
  if self.ttl <= 0 then
    self.active = false
  end
end

function PU:draw()
  if not self.active then return end
  if self.sprite.img then
    lg.draw(self.sprite.img, self.x, self.y, self.r, 1, 1,
             self.sprite.w * 0.5, self.sprite.h * 0.5)
  else
    lg.push()
    lg.translate(self.x, self.y)
    lg.rotate(self.r)
    lg.setColor(self.sprite.color)
    lg.circle("fill", 0, 0, self.radius)
    lg.setColor(1, 1, 1)
    lg.pop()
  end
end

-- Axis‑aligned bounding box vs circle (player vs power‑up) utility.
local function _aabbCircle(ax, ay, aw, ah, cx, cy, cr)
  local nearestX = math.max(ax, math.min(cx, ax + aw))
  local nearestY = math.max(ay, math.min(cy, ay + ah))
  local dx = cx - nearestX
  local dy = cy - nearestY
  return (dx * dx + dy * dy) <= cr * cr
end

-- ========================================================================= --
-- >>> PUBLIC API (returned module)
-- ========================================================================= --

Powerup._list = {}

--- Spawn a new power‑up at the given coordinates. Returns the new instance.
---@param kind string @"health", "shield", "weapon", or "score"
function Powerup.spawn(kind, x, y)
  _ensureLoaded()
  local pu = PU:new(kind, x, y)
  table.insert(Powerup._list, pu)
  return pu
end

--- Reset/clear all active power‑ups.
function Powerup.reset()
  Powerup._list = {}
end

--- Update all power‑ups (called from states/playing.lua)
function Powerup.update(dt)
  for i = #Powerup._list, 1, -1 do
    local pu = Powerup._list[i]
    pu:update(dt)
    if not pu.active then
      table.remove(Powerup._list, i)
    end
  end
end

--- Draw all power‑ups (called from states/playing.lua)
function Powerup.draw()
  for _, pu in ipairs(Powerup._list) do
    pu:draw()
  end
end

--- Check if an AABB entity (e.g. player) has picked up any power‑up.
--- Returns the kind of the first collected power‑up or nil.
---@param x number
---@param y number
---@param w number
---@param h number
function Powerup.checkPickupAABB(x, y, w, h)
  for i = #Powerup._list, 1, -1 do
    local pu = Powerup._list[i]
    if _aabbCircle(x, y, w, h, pu.x, pu.y, pu.radius) then
      local kind = pu.kind
      pu.active = false
      table.remove(Powerup._list, i)
      return kind
    end
  end
  return nil
end

return Powerup
