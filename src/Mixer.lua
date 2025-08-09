local Mixer = {}
Mixer.__index = Mixer

function Mixer.new()
  local constants = require("src.constants")
  local AudioUtils = require("src.audioutils")
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
  local AudioUtils = require("src.audioutils")
  group = group or "sfx"
  if not self.groups[group] then
    self.groups[group] = {}
  end
  table.insert(self.groups[group], src)
  table.insert(self.groups.master, src)
  self.map[src] = group
  local bv = AudioUtils.getBaseVolume(src) or 1
  src:setVolume(bv * self.volumes[group] * self.volumes.master)
end

function Mixer:setMasterVolume(group, value)
  local AudioUtils = require("src.audioutils")
  if not self.volumes[group] then
    return
  end
  self.volumes[group] = value
  if group == "master" then
    for src, g in pairs(self.map) do
      local bv = AudioUtils.getBaseVolume(src) or 1
      src:setVolume(bv * self.volumes[g] * self.volumes.master)
    end
  else
    for _, src in ipairs(self.groups[group] or {}) do
      local bv = AudioUtils.getBaseVolume(src) or 1
      src:setVolume(bv * self.volumes[group] * self.volumes.master)
    end
  end
end

function Mixer:updateAll()
  local AudioUtils = require("src.audioutils")
  for src, g in pairs(self.map) do
    local bv = AudioUtils.getBaseVolume(src) or 1
    src:setVolume(bv * self.volumes[g] * self.volumes.master)
  end
end

return Mixer
