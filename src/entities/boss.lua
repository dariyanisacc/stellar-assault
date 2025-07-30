-- Boss entity ---------------------------------------------------------------
-- Usage: local Boss = require("src.entities.boss"); local boss = Boss.new(level)

local lg            = love.graphics
local AssetManager  = require("src.asset_manager")

local BULLET_COOLDOWN = 1.5 -- seconds between volleys

---@class Boss
local Boss   = {}
Boss.__index = Boss

function Boss.new(level)
  local self = setmetatable({}, Boss)

  -- sprite path matches assets/bosses used elsewhere
  local path   = string.format("assets/bosses/boss_%02d@97x84.png", level)
  self.sprite  = AssetManager.getImage(path)

  -- starting position (scroll in from top centre)
  self.x = lg.getWidth()  / 2
  self.y = -self.sprite:getHeight()

  -- stats scale with level
  self.maxHP = 250 + level * 50
  self.hp    = self.maxHP
  self.phase = 1
  self.cool  = BULLET_COOLDOWN

  return self
end

-- simple sinusoidal sweep ---------------------------------------------------
function Boss:update(dt, bullets)
  -- vertical settle
  self.y = math.min(self.y + 40 * dt, 110)
  -- horizontal sway
  self.x = self.x + math.sin(love.timer.getTime() * 0.6) * 45 * dt

  -- radial fire pattern
  self.cool = self.cool - dt
  if self.cool <= 0 then
    self.cool = BULLET_COOLDOWN
    for angle = 0, math.pi * 2, math.pi / 6 do
      bullets:spawn(self.x, self.y, angle, 220)
    end
  end
end

function Boss:draw()
  lg.draw(
    self.sprite,
    self.x, self.y,
    0,                         -- rotation
    4, 4,                      -- scale
    self.sprite:getWidth()  / 2,
    self.sprite:getHeight() / 2
  )

  -- HP bar
  lg.rectangle("fill", self.x - 48, self.y - 70, 96 * (self.hp / self.maxHP), 6)
  lg.rectangle("line", self.x - 48, self.y - 70, 96, 6)
end

return Boss
