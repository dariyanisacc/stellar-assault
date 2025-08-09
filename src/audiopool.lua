local AudioPool = {}
AudioPool.__index = AudioPool
local AudioUtils = require("src.audioutils")

function AudioPool:new(size, list)
  local obj = setmetatable({}, self)
  obj.size = size or 8
  obj.pool = {}
  obj.list = list
  obj.pitchJitter = 0.035 -- subtle variety when no variants are available
  return obj
end

-- Register a single source as one variant
function AudioPool:register(name, src)
  if not src then return end
  self:registerVariants(name, { src })
end

-- Register multiple variant sources (round-robin per play)
function AudioPool:registerVariants(name, sources)
  if not sources or #sources == 0 then return end
  local entry = { variants = {}, vindex = 1 }
  for _, src in ipairs(sources) do
    if src then
      local variant = { clones = {}, index = 1 }
      for i = 1, self.size do
        local c = src:clone()
        -- Preserve base volume metadata for clones
        AudioUtils.setBaseVolume(c, AudioUtils.getBaseVolume(src) or 1)
        table.insert(variant.clones, c)
        if self.list then table.insert(self.list, c) end
      end
      table.insert(entry.variants, variant)
    end
  end
  -- Fallback to at least one variant if any invalids filtered out
  if #entry.variants == 0 then return end
  self.pool[name] = entry
end

function AudioPool:play(name, x, y)
  local entry = self.pool[name]
  if not entry then return end

  -- Choose variant and clone in round-robin
  local v = entry.variants and entry.variants[entry.vindex]
  if not v then return end
  entry.vindex = (entry.vindex % #entry.variants) + 1
  local src = v.clones[v.index]
  v.index = (v.index % #v.clones) + 1

  if src.stop then src:stop() end
  if x and y and _G.player and src.getChannelCount and src:getChannelCount() == 1 then
    local dx, dy = x - _G.player.x, y - _G.player.y
    src:setRelative(true)
    src:setPosition(dx, dy, 0)
    if _G.soundReferenceDistance and _G.soundMaxDistance then
      src:setAttenuationDistances(_G.soundReferenceDistance, _G.soundMaxDistance)
    end
  end
  if _G.Game then
    local bv = AudioUtils.getBaseVolume(src) or 1
    src:setVolume(bv * Game.sfxVolume * Game.masterVolume)
  end
  -- Apply subtle pitch jitter if only one variant to simulate variety
  if #entry.variants == 1 and src.setPitch then
    local j = self.pitchJitter or 0
    local p = 1 + (math.random() * 2 - 1) * j
    src:setPitch(p)
  end
  src:play()
end

return AudioPool
