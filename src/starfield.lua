local lg = love.graphics

---@class Starfield
local Starfield = {}
Starfield.__index = Starfield

---@param count integer
---@param image love.Image|nil
---@return Starfield
function Starfield.new(count, image)
  local self = setmetatable({}, Starfield)
  self.count = count or 200
  self.image = image
  if not self.image then
    if love.image and love.image.newImageData then
      local data = love.image.newImageData(1, 1)
      data:setPixel(0, 0, 1, 1, 1, 1)
      self.image = lg.newImage(data)
    else
      self.image = lg.newImage("assets/gfx/ship_alpha@1024x1024.png")
    end
  end
  self.quads = {}
  self.stars = {}
  self.batch = lg.newSpriteBatch(self.image, self.count, "stream")
  local iw, ih = 1, 1
  if self.image.getWidth then
    iw, ih = self.image:getWidth(), self.image:getHeight()
  end
  for i = 1, self.count do
    self.quads[i] = lg.newQuad(0, 0, iw, ih, iw, ih)
    local star = {
      x = love.math.random() * lg.getWidth(),
      y = love.math.random() * lg.getHeight(),
      speed = love.math.random() * 50 + 20,
      size = love.math.random() * 2,
    }
    self.stars[i] = star
    self.batch:add(self.quads[i], star.x, star.y, 0, star.size, star.size)
  end
  self.batch:flush()
  return self
end

function Starfield:update(dt)
  local height = lg.getHeight()
  local width = lg.getWidth()
  self.batch:clear()
  for i, star in ipairs(self.stars) do
    star.y = star.y + star.speed * dt
    if star.y > height then
      star.y = -star.size
      star.x = love.math.random() * width
    end
    self.batch:add(self.quads[i], star.x, star.y, 0, star.size, star.size)
  end
  self.batch:flush()
end

function Starfield:draw()
  lg.setColor(1, 1, 1)
  lg.draw(self.batch)
end

return Starfield
