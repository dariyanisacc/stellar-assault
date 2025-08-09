-- src/audioutils.lua
-- Lightweight helpers to associate metadata with LÖVE Sources (userdata).
-- We can’t set arbitrary fields on Source userdata, so we keep a weak-key
-- registry that maps Source -> baseVolume and any future metadata.

local M = {}

-- weak-key tables so entries disappear when Sources are GC’d
local baseVolume = setmetatable({}, { __mode = "k" })

function M.setBaseVolume(src, v)
  if src == nil then return end
  baseVolume[src] = v or 1
end

function M.getBaseVolume(src)
  return (src ~= nil and baseVolume[src]) or 1
end

return M

