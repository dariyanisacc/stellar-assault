-- Boss entity ---------------------------------------------------------------
-- Usage: local Boss = require("src.entities.boss"); local boss = Boss.new(level)

local lg            = love.graphics
local AssetManager  = require("src.asset_manager")

local BULLET_COOLDOWN = 1.5 -- seconds between volleys

---@class Boss
local Boss   = {}
Boss.__index = Boss

function Boss.new(level, opts)
  local self = setmetatable({}, Boss)

  opts = opts or {}
  -- Prefer injected sprite; otherwise fall back to a reasonable default if present
  if opts.sprite then
    self.sprite = opts.sprite
  else
    if love.filesystem.getInfo("assets/gfx/Boss 1.png") then
      self.sprite = AssetManager.getImage("assets/gfx/Boss 1.png")
    else
      -- Final fallback: a 1x1 white image to avoid crashes
      local imgdata = love.image and love.image.newImageData(1,1)
      if imgdata then imgdata:setPixel(0,0,1,1,1,1) end
      self.sprite = lg.newImage(imgdata or love.graphics.newCanvas(1,1):newImageData())
    end
  end

  -- starting position (scroll in from top centre)
  self.x = (opts.x or (lg.getWidth()  / 2))
  self.y = (opts.y or (-self.sprite:getHeight()))

  -- collision + draw scale (reduced by 25%)
  self.scale = 3
  self.width  = (self.sprite and self.sprite:getWidth()  * self.scale) or 64
  self.height = (self.sprite and self.sprite:getHeight() * self.scale) or 64
  self.size   = math.max(self.width, self.height)
  self.tag    = "boss"

  -- stats scale with level
  self.maxHP = 250 + level * 50
  self.hp    = self.maxHP
  -- Mirror fields for systems using health/maxHealth
  self.maxHealth = self.maxHP
  self.health    = self.hp
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
    self.scale, self.scale,    -- scale
    self.sprite:getWidth()  / 2,
    self.sprite:getHeight() / 2
  )

  -- HP bar
  lg.rectangle("fill", self.x - 48, self.y - 70, 96 * (self.hp / self.maxHP), 6)
  lg.rectangle("line", self.x - 48, self.y - 70, 96, 6)
end

return Boss
