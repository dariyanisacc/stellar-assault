local lg = love.graphics
local la = love.audio
local lf = love.filesystem

---@class AssetManager
---@field gfx table<string, love.Image>
---@field sfx table<string, love.Source>
---@field music table<string, love.Source>
---@field fonts table<string, love.Font>
---@field atlases table<string, love.Image>
local AssetManager = {}
AssetManager.__index = AssetManager

function AssetManager.new()
  local self = setmetatable({}, AssetManager)
  self.gfx = {}
  self.sfx = {}
  self.music = {}
  self.fonts = {}
  self.atlases = {}
  return self
end

local function loadDirectory(out, path, loader, exts)
  if not lf.getInfo(path, "directory") then
    return
  end
  for _, filename in ipairs(lf.getDirectoryItems(path)) do
    local full = path .. "/" .. filename
    if lf.getInfo(full, "file") then
      local ext = filename:match("%.([%w]+)$")
      if ext and exts[ext:lower()] then
        local key = filename:gsub("%.[%w]+$", ""):lower()
        out[key] = loader(full)
      end
    end
  end
end

function AssetManager:loadAll()
  loadDirectory(self.gfx, "assets/gfx", lg.newImage, { png = true, jpg = true })
  loadDirectory(self.sfx, "assets/sfx", function(p)
    return la.newSource(p, "static")
  end, { ogg = true, wav = true })
  loadDirectory(self.music, "assets/music", function(p)
    return la.newSource(p, "stream")
  end, { ogg = true, mp3 = true })
  loadDirectory(self.fonts, "assets/fonts", lg.newFont, { ttf = true, otf = true })
  loadDirectory(self.atlases, "assets/atlases", lg.newImage, { png = true })
end

function AssetManager:get(category, name)
  local set = self[category]
  return set and set[name]
end

return AssetManager
