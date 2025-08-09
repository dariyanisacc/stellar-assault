-- Boss02 entity - Phase-based boss with escalating patterns
-- Usage: local Boss02 = require("src.entities.boss02"); local boss = Boss02.new(level)

local lg           = love.graphics
local AssetManager = require("src.asset_manager")

---@class Boss02
local Boss02   = {}
Boss02.__index = Boss02

function Boss02.new(level)
  local self = setmetatable({}, Boss02)

  -- sprite path consistent with boss01
  self.sprite = AssetManager.getImage("assets/bosses/boss_02@97x84.png")

  -- entrance placement
  self.x, self.y = lg.getWidth() / 2, -100

  -- stats scale with level
  self.maxHP = 400 + level * 75
  self.hp    = self.maxHP
  -- Mirror fields for systems using health/maxHealth
  self.maxHealth = self.maxHP
  self.health    = self.hp
  self.level = level

  -- phase system
  self.currentPhase = 1
  self.phases = {
    { hp = 0.66, pattern = "spiral",    cooldown = 2.0 },
    { hp = 0.33, pattern = "ringBurst", cooldown = 1.5 },
    { hp = 0.00, pattern = "lastStand", cooldown = 0.8 },
  }

  -- pattern state
  self.patternCooldown = 2.0
  self.patternTimer    = 0
  self.telegraphTimer  = 0
  self.isTelegraphing  = false

  -- visuals
  self.rotation   = 0
  self.scale      = 1.5
  self.flashTimer = 0
  self.color      = { 0.3, 0.5, 1.0 } -- blue tint

  -- collision extents (updated dynamically if scale changes)
  self.tag    = "boss"
  local texW  = (self.sprite and self.sprite:getWidth())  or 64
  local texH  = (self.sprite and self.sprite:getHeight()) or 64
  local drawScale = self.scale * 3
  self.width  = texW * drawScale
  self.height = texH * drawScale
  self.size   = math.max(self.width, self.height)

  return self
end

-- ---------------------------------------------------------------------------
-- Update & attack patterns
-- ---------------------------------------------------------------------------
function Boss02:update(dt, bullets)
  -- entrance slide
  if self.y < 120 then
    self.y = self.y + 50 * dt
  else
    -- hover motion
    self.x = self.x + math.sin(love.timer.getTime() * 0.8) * 60 * dt
    self.rotation = self.rotation + dt * 0.5
  end

  -- phase progression
  local hpPercent = self.hp / self.maxHP
  for i, phase in ipairs(self.phases) do
    if hpPercent <= phase.hp and self.currentPhase < i then
      self.currentPhase   = i
      self.patternCooldown = phase.cooldown
      self:onPhaseChange(i)
      break
    end
  end

  -- pattern timing
  self.patternCooldown = self.patternCooldown - dt
  if self.isTelegraphing then
    self.telegraphTimer = self.telegraphTimer - dt
    if self.telegraphTimer <= 0 then
      self.isTelegraphing = false
      self:executePattern(bullets)
    end
  elseif self.patternCooldown <= 0 then
    self.isTelegraphing = true
    self.telegraphTimer = 0.4
    self.flashTimer     = 0.4
    self.patternCooldown = self.phases[self.currentPhase].cooldown
  end

  -- flash decay
  if self.flashTimer > 0 then
    self.flashTimer = self.flashTimer - dt
  end

  -- keep on-screen
  local margin = 60
  self.x = math.max(margin, math.min(lg.getWidth() - margin, self.x))

  -- Update collision extents in case scale/rotation changed
  if self.sprite then
    local texW, texH = self.sprite:getWidth(), self.sprite:getHeight()
    local drawScale = (self.scale or 1) * 3
    self.width  = texW * drawScale
    self.height = texH * drawScale
    self.size   = math.max(self.width, self.height)
  end
end

function Boss02:executePattern(bullets)
  local pattern = self.phases[self.currentPhase].pattern
  if     pattern == "spiral"    then self:patternSpiral(bullets)
  elseif pattern == "ringBurst" then self:patternRingBurst(bullets)
  elseif pattern == "lastStand" then self:patternLastStand(bullets) end
end

-- bullet patterns -----------------------------------------------------------
function Boss02:patternSpiral(bullets)
  local arms, base = 5, love.timer.getTime() * 2
  for i = 0, arms - 1 do
    bullets:spawn(self.x, self.y, base + (i * math.pi * 2 / arms), 250)
  end
end

function Boss02:patternRingBurst(bullets)
  local n = 16
  for i = 0, n - 1 do
    bullets:spawn(self.x, self.y, (i / n) * math.pi * 2, 200)
  end
end

function Boss02:patternLastStand(bullets)
  for _ = 1, 8 do
    local angle = math.random() * math.pi * 2
    local speed = 150 + math.random() * 150
    bullets:spawn(self.x, self.y, angle, speed)
  end
  if player then
    local dx, dy = player.x - self.x, player.y - self.y
    local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
    bullets:spawn(self.x, self.y, atan2(dy, dx), 350)
  end
end

-- phase visuals -------------------------------------------------------------
function Boss02:onPhaseChange(phase)
  self.flashTimer = 1.0
  if     phase == 2 then self.color = { 1.0, 0.5, 0.3 }; self.scale = 1.7
  elseif phase == 3 then self.color = { 1.0, 0.3, 0.3 }; self.scale = 2.0 end
  -- Recompute extents for new scale
  if self.sprite then
    local texW, texH = self.sprite:getWidth(), self.sprite:getHeight()
    local drawScale = (self.scale or 1) * 3
    self.width  = texW * drawScale
    self.height = texH * drawScale
    self.size   = math.max(self.width, self.height)
  end
end

-- draw ----------------------------------------------------------------------
function Boss02:draw()
  lg.push()
  lg.translate(self.x, self.y)
  lg.rotate(self.rotation)

  -- flash effect
  local r, g, b = table.unpack(self.color)
  if self.flashTimer > 0 then
    local f = math.sin(self.flashTimer * 20) * 0.5 + 0.5
    r = r + f * (1 - r)
    g = g + f * (1 - g)
    b = b + f * (1 - b)
  end
  lg.setColor(r, g, b, 1)

  if self.sprite then
    lg.draw(self.sprite, 0, 0, 0, self.scale * 3, self.scale * 3,
            self.sprite:getWidth() / 2, self.sprite:getHeight() / 2)
  else
    lg.circle("fill", 0, 0, 40 * self.scale)
    lg.setColor(0, 0, 0, 0.5)
    lg.circle("fill", 0, 0, 20 * self.scale)
  end
  lg.pop()

  -- HP bar & phase indicator
  local w, h, yBar = 120, 8, self.y - 60 * self.scale
  lg.setColor(0.2, 0.2, 0.2, 0.8)
  lg.rectangle("fill", self.x - w / 2, yBar, w, h)
  lg.setColor(1, 0.2, 0.2, 1)
  lg.rectangle("fill", self.x - w / 2, yBar, w * (self.hp / self.maxHP), h)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("line", self.x - w / 2, yBar, w, h)
  lg.print("Phase " .. self.currentPhase, self.x - 25, yBar - 20)
end

return Boss02
