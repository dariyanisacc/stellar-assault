local AudioPool = {}
AudioPool.__index = AudioPool

function AudioPool:new(size, list)
  local obj = setmetatable({}, self)
  obj.size = size or 8
  obj.pool = {}
  obj.list = list
  return obj
end

function AudioPool:register(name, src)
  if not src then
    return
  end
  local t = { clones = {}, index = 1 }
  for i = 1, self.size do
    local c = src:clone()
    c.baseVolume = src.baseVolume
    table.insert(t.clones, c)
    if self.list then
      table.insert(self.list, c)
    end
  end
  self.pool[name] = t
end

function AudioPool:play(name, x, y)
  local entry = self.pool[name]
  if not entry then
    return
  end
  local src = entry.clones[entry.index]
  entry.index = (entry.index % #entry.clones) + 1
  if src.stop then
    src:stop()
  end
  if x and y and _G.player and src.getChannelCount and src:getChannelCount() == 1 then
    local dx, dy = x - _G.player.x, y - _G.player.y
    src:setRelative(true)
    src:setPosition(dx, dy, 0)
    if _G.soundReferenceDistance and _G.soundMaxDistance then
      src:setAttenuationDistances(_G.soundReferenceDistance, _G.soundMaxDistance)
    end
  end
  if _G.Game then
    src:setVolume((src.baseVolume or 1) * Game.sfxVolume * Game.masterVolume)
  end
  src:play()
end

return AudioPool
