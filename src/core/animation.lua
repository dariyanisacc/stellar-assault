local Animation = {}
Animation.__index = Animation

function Animation.new(frames, frameTime, loop)
  return setmetatable({
    frames = frames,
    frameTime = frameTime or 0.1,
    time = 0,
    index = 1,
    loop = loop ~= false,
  }, Animation)
end

function Animation:update(dt)
  self.time = self.time + dt
  while self.time >= self.frameTime do
    self.time = self.time - self.frameTime
    self.index = self.index + 1
    if self.index > #self.frames then
      if self.loop then
        self.index = 1
      else
        self.index = #self.frames
      end
    end
  end
end

function Animation:getFrame()
  return self.frames[self.index]
end

function Animation:draw(x, y, r, sx, sy, ox, oy)
  local frame = self:getFrame()
  if type(frame) == "table" and frame.quad then
    love.graphics.draw(frame.image, frame.quad, x, y, r or 0, sx or 1, sy or 1, ox, oy)
  else
    love.graphics.draw(frame, x, y, r or 0, sx or 1, sy or 1, ox, oy)
  end
end

return Animation
