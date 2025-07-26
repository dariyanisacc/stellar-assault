local lg = love.graphics
local random = (love.math and love.math.random) or math.random

local Camera = {}
Camera.__index = Camera

function Camera:new(x, y, scale)
  local obj = setmetatable({}, Camera)
  obj.x = x or 0
  obj.y = y or 0
  obj.scale = scale or 1
  obj.shakeTime = 0
  obj.shakeIntensity = 0
  obj.offsetX = 0
  obj.offsetY = 0
  return obj
end

function Camera:update(dt)
  if self.shakeTime > 0 then
    self.shakeTime = self.shakeTime - dt
    if self.shakeTime < 0 then
      self.shakeTime = 0
    end
    self.offsetX = (random() * 2 - 1) * self.shakeIntensity
    self.offsetY = (random() * 2 - 1) * self.shakeIntensity
  else
    self.offsetX = 0
    self.offsetY = 0
  end
end

function Camera:shake(duration, intensity)
  self.shakeTime = duration or 0
  self.shakeIntensity = intensity or 0
end

function Camera:apply()
  lg.push()
  lg.translate(-self.x + self.offsetX, -self.y + self.offsetY)
  lg.scale(self.scale, self.scale)
end

function Camera:release()
  lg.pop()
end

return Camera
