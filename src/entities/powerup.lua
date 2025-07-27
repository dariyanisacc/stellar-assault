-- Powerup entity ---------------------------------------------------------------
-- Usage: local Powerup = require("src.entities.powerup"); powerup = Powerup.new(x, y, type)

local lg = love.graphics

local Powerup = {}
Powerup.__index = Powerup

-- Powerup types and their properties
local POWERUP_TYPES = {
  rapid = {
    color = { 1, 1, 0 }, -- yellow
    icon = "R",
    duration = 8,
    description = "Rapid Fire",
  },
  spread = {
    color = { 1, 0.5, 0 }, -- orange
    icon = "S",
    duration = 10,
    description = "Spread Shot",
  },
  shield = {
    color = { 0, 1, 1 }, -- cyan
    icon = "D",
    duration = 15, -- shield barrier duration
    description = "Shield Barrier",
  },
  health = {
    color = { 1, 0.2, 0.2 }, -- red
    icon = "+",
    duration = 0, -- instant
    description = "Shield +1",
  },
  bomb = {
    color = { 1, 0, 1 }, -- magenta
    icon = "B",
    duration = 0, -- instant
    description = "Screen Clear",
  },
  boost = {
    color = { 0, 1, 0 }, -- green
    icon = ">>",
    duration = 6,
    description = "Speed Boost",
  },
  coolant = {
    color = { 0, 0.5, 1 }, -- ice blue
    icon = "C",
    duration = 10, -- cooling boost duration
    description = "Heat Coolant",
  },
  homingMissile = {
    color = { 1, 1, 1 }, -- white
    icon = "M",
    duration = 5,
    description = "Homing Missiles",
  },
}

function Powerup.new(x, y, type)
  local self = setmetatable({}, Powerup)

  -- position and movement
  self.x = x
  self.y = y
  self.width = 24
  self.height = 24
  self.size = 24 -- For collision compatibility
  self.fallSpeed = 50

  -- type and properties
  self.type = type or "rapid"
  local config = POWERUP_TYPES[self.type] or POWERUP_TYPES.rapid
  self.color = config.color
  self.icon = config.icon
  self.duration = config.duration
  self.description = config.description

  -- visual state
  self.rotation = 0
  self.pulse = 0
  self.collected = false

  return self
end

function Powerup:update(dt)
  -- fall down
  self.y = self.y + self.fallSpeed * dt

  -- rotate and pulse
  self.rotation = self.rotation + dt * 2
  self.pulse = self.pulse + dt * 3
end

function Powerup:draw()
  lg.push()
  lg.translate(self.x, self.y)
  lg.rotate(self.rotation)

  -- Enhanced powerups have special visual effects
  if self.enhanced then
    -- Extra glow ring for enhanced powerups
    local pulse = math.sin(self.pulse * 1.5) * 0.3 + 0.7
    lg.setColor(1, 1, 0.5, pulse * 0.4)
    lg.circle("line", 0, 0, self.width + 5)
    lg.setLineWidth(2)
  end

  -- pulsing glow effect
  local scale = 1 + math.sin(self.pulse) * 0.2
  if self.enhanced then
    scale = scale * 1.2 -- Slightly larger for enhanced
  end

  -- outer glow
  lg.setColor(self.color[1], self.color[2], self.color[3], 0.3)
  lg.circle("fill", 0, 0, self.width * scale)

  -- main body
  lg.setColor(self.color[1], self.color[2], self.color[3], 0.8)
  lg.circle("fill", 0, 0, self.width / 2)

  -- border
  if self.enhanced then
    lg.setColor(1, 1, 0.8, 1) -- Golden border for enhanced
    lg.setLineWidth(2)
  else
    lg.setColor(1, 1, 1, 1)
  end
  lg.circle("line", 0, 0, self.width / 2)
  lg.setLineWidth(1)

  -- icon
  if self.enhanced then
    -- Slightly larger icon for enhanced
    lg.push()
    lg.scale(1.2, 1.2)
    lg.setColor(0, 0, 0, 1)
    lg.print(self.icon, -7, -9)
    lg.pop()
  else
    lg.setColor(0, 0, 0, 1)
    lg.print(self.icon, -6, -8)
  end

  lg.pop()
end

function Powerup:collect(player)
  if self.collected then
    return
  end
  self.collected = true

  -- apply effect based on type
  if self.type == "health" then
    -- instant shield restore
    player.shield = math.min(player.shield + 1, player.maxShield or 5)
    return true -- instant effect
  elseif self.type == "bomb" then
    -- clear screen of enemies (handled by playing state)
    return "bomb"
  else
    -- timed powerup (including shield barrier)
    return {
      type = self.type,
      duration = self.duration,
      timer = self.duration,
    }
  end
end

-- Static method to get random powerup type
function Powerup.getRandomType()
  local types = {}
  for k, _ in pairs(POWERUP_TYPES) do
    table.insert(types, k)
  end
  return types[math.random(#types)]
end

return Powerup
