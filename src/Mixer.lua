local Mixer = {}
Mixer.__index = Mixer

function Mixer.new()
  local constants = require("src.constants")
  local self = setmetatable({}, Mixer)
  self.volumes = {
    master = constants.audio.defaultMasterVolume,
    sfx = constants.audio.defaultSFXVolume,
    music = constants.audio.defaultMusicVolume,
  }
  self.groups = { master = {}, sfx = {}, music = {} }
  self.map = {}
  return self
end

function Mixer:register(src, group)
  group = group or "sfx"
  if not self.groups[group] then
    self.groups[group] = {}
  end
  table.insert(self.groups[group], src)
  table.insert(self.groups.master, src)
  self.map[src] = group
  src:setVolume((src.baseVolume or 1) * self.volumes[group] * self.volumes.master)
end

function Mixer:setMasterVolume(group, value)
  if not self.volumes[group] then
    return
  end
  self.volumes[group] = value
  if group == "master" then
    for src, g in pairs(self.map) do
      src:setVolume((src.baseVolume or 1) * self.volumes[g] * self.volumes.master)
    end
  else
    for _, src in ipairs(self.groups[group] or {}) do
      src:setVolume((src.baseVolume or 1) * self.volumes[group] * self.volumes.master)
    end
  end
end

function Mixer:updateAll()
  for src, g in pairs(self.map) do
    src:setVolume((src.baseVolume or 1) * self.volumes[g] * self.volumes.master)
  end
end

return Mixer
