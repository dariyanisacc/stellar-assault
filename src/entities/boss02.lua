-- Boss02 entity - Phase-based boss with escalating patterns
-- Usage: local Boss02 = require("src.entities.boss02"); boss = Boss02.new(level)

local lg = love.graphics
local AssetManager = require("src.asset_manager")

local Boss02 = {}
Boss02.__index = Boss02

function Boss02.new(level)
  local self = setmetatable({}, Boss02)

  -- basic placement
  self.sprite = AssetManager.getImage("assets/bosses/boss_02@97x84.png")
  self.x = lg.getWidth() / 2
  self.y = -100

  -- stats scale with level
  self.maxHP = 400 + level * 75
  self.hp = self.maxHP
  self.level = level

  -- phase system
  self.currentPhase = 1
  self.phases = {
    { hp = 0.66, pattern = "spiral", cooldown = 2.0 },
    { hp = 0.33, pattern = "ringBurst", cooldown = 1.5 },
    { hp = 0.00, pattern = "lastStand", cooldown = 0.8 },
  }

  -- pattern state
  self.patternCooldown = 2.0
  self.patternTimer = 0
  self.telegraphTimer = 0
  self.isTelegraphing = false

  -- visual state
  self.rotation = 0
  self.scale = 1.5
  self.flashTimer = 0
  self.color = { 0.3, 0.5, 1.0 } -- blue tint

  return self
end

function Boss02:update(dt, bullets)
  -- entrance animation
  if self.y < 120 then
    self.y = self.y + 50 * dt
  else
    -- hovering movement
    self.x = self.x + math.sin(love.timer.getTime() * 0.8) * 60 * dt
    self.rotation = self.rotation + dt * 0.5
  end

  -- update phase based on HP
  local hpPercent = self.hp / self.maxHP
  for i, phase in ipairs(self.phases) do
    if hpPercent <= phase.hp and self.currentPhase < i then
      self.currentPhase = i
      self.patternCooldown = phase.cooldown
      self:onPhaseChange(i)
      break
    end
  end

  -- pattern execution
  self.patternCooldown = self.patternCooldown - dt

  if self.isTelegraphing then
    self.telegraphTimer = self.telegraphTimer - dt
    if self.telegraphTimer <= 0 then
      self.isTelegraphing = false
      self:executePattern(bullets)
    end
  elseif self.patternCooldown <= 0 then
    -- start telegraph
    self.isTelegraphing = true
    self.telegraphTimer = 0.4
    self.flashTimer = 0.4

    -- reset cooldown
    local phase = self.phases[self.currentPhase]
    self.patternCooldown = phase.cooldown
  end

  -- visual effects update
  if self.flashTimer > 0 then
    self.flashTimer = self.flashTimer - dt
  end

  -- bounds check
  local margin = 60
  self.x = math.max(margin, math.min(lg.getWidth() - margin, self.x))
end

function Boss02:executePattern(bullets)
  local phase = self.phases[self.currentPhase]
  local pattern = phase.pattern

  if pattern == "spiral" then
    self:patternSpiral(bullets)
  elseif pattern == "ringBurst" then
    self:patternRingBurst(bullets)
  elseif pattern == "lastStand" then
    self:patternLastStand(bullets)
  end
end

-- Pattern: Spiral - rotating spiral of bullets
function Boss02:patternSpiral(bullets)
  local numArms = 5
  local baseAngle = love.timer.getTime() * 2

  for i = 0, numArms - 1 do
    local angle = baseAngle + (i * math.pi * 2 / numArms)
    bullets:spawn(self.x, self.y, angle, 250)
  end
end

-- Pattern: Ring Burst - expanding ring of bullets
function Boss02:patternRingBurst(bullets)
  local numBullets = 16

  for i = 0, numBullets - 1 do
    local angle = (i / numBullets) * math.pi * 2
    bullets:spawn(self.x, self.y, angle, 200)
  end
end

-- Pattern: Last Stand - desperation attack with rapid fire
function Boss02:patternLastStand(bullets)
  -- rapid random spread
  for i = 1, 8 do
    local angle = math.random() * math.pi * 2
    local speed = 150 + math.random() * 150
    bullets:spawn(self.x, self.y, angle, speed)
  end

  -- aimed shot at player
  if player then
    local dx = player.x - self.x
    local dy = player.y - self.y
    local angle = math.atan2(dy, dx)
    bullets:spawn(self.x, self.y, angle, 350)
  end
end

function Boss02:onPhaseChange(phase)
  -- visual feedback for phase change
  self.flashTimer = 1.0

  -- phase-specific changes
  if phase == 2 then
    self.color = { 1.0, 0.5, 0.3 } -- orange tint
    self.scale = 1.7
  elseif phase == 3 then
    self.color = { 1.0, 0.3, 0.3 } -- red tint
    self.scale = 2.0
  end
end

function Boss02:draw()
  lg.push()
  lg.translate(self.x, self.y)
  lg.rotate(self.rotation)

  -- flash effect when telegraphing
  local r, g, b = self.color[1], self.color[2], self.color[3]
  if self.flashTimer > 0 then
    local flash = math.sin(self.flashTimer * 20) * 0.5 + 0.5
    r = r + flash * (1 - r)
    g = g + flash * (1 - g)
    b = b + flash * (1 - b)
  end

  lg.setColor(r, g, b, 1)

  if self.sprite then
    lg.draw(
      self.sprite,
      0,
      0,
      0,
      self.scale * 4,
      self.scale * 4,
      self.sprite:getWidth() / 2,
      self.sprite:getHeight() / 2
    )
  else
    -- fallback shape
    lg.circle("fill", 0, 0, 40 * self.scale)
    lg.setColor(0, 0, 0, 0.5)
    lg.circle("fill", 0, 0, 20 * self.scale)
  end

  lg.pop()

  -- HP bar
  local barWidth = 120
  local barHeight = 8
  local barY = self.y - 60 * self.scale

  lg.setColor(0.2, 0.2, 0.2, 0.8)
  lg.rectangle("fill", self.x - barWidth / 2, barY, barWidth, barHeight)

  lg.setColor(1, 0.2, 0.2, 1)
  lg.rectangle("fill", self.x - barWidth / 2, barY, barWidth * (self.hp / self.maxHP), barHeight)

  lg.setColor(1, 1, 1, 1)
  lg.rectangle("line", self.x - barWidth / 2, barY, barWidth, barHeight)

  -- Phase indicator
  lg.setColor(1, 1, 1, 0.8)
  lg.print("Phase " .. self.currentPhase, self.x - 25, barY - 20)
end

return Boss02
