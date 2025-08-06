-- File: src/asset_manager.lua
------------------------------------------------------------------------------
-- AssetManager
--  • Singleton cache for images, fonts, and sounds
--  • Automatically scans “assets/” on demand
------------------------------------------------------------------------------

local lg, la, lf = love.graphics, love.audio, love.filesystem

---@class AssetManager
local AssetManager = {
  images  = {},   -- [normalizedPath] = love.Image
  fonts   = {},   -- [key]            = love.Font          (key = "<path|default>:<size>")
  sounds  = {},   -- [key]            = love.Source        (key = "<path>:<static|stream>")
  atlases = {},   -- reserved for future use
}

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------
local function norm(path)      return path:gsub("\\","/"):lower() end
local function cache(tbl,k,f)  k = norm(k); if not tbl[k] then tbl[k] = f() end; return tbl[k] end
local function assertFile(path, what)
  if not love.filesystem.getInfo(path, "file") then
    error(("%s not found: %s"):format(what or "File", path), 2)
  end
end

-- ---------------------------------------------------------------------------
-- Public getters
-- ---------------------------------------------------------------------------
function AssetManager.getImage(path)
  assertFile(path, "Image")
  return cache(AssetManager.images, path, function() return lg.newImage(path) end)
end

---@overload fun(size:number):love.Font
function AssetManager.getFont(arg1, size)
  local path = arg1
  if type(arg1) == "number" then size, path = arg1, nil end
  size = size or 12
  local key = (path or "default") .. ":" .. tostring(size)
  return cache(AssetManager.fonts, key, function()
    return path and lg.newFont(path, size) or lg.newFont(size)
  end)
end

function AssetManager.getSound(path, kind)
  kind = kind or "static"
  local key = path .. ":" .. kind
  return cache(AssetManager.sounds, key, function() return la.newSource(path, kind) end)
end

-- ---------------------------------------------------------------------------
-- Bulk loader (optional—pre-caches everything in /assets)
-- ---------------------------------------------------------------------------
local exts = {
  img  = { png=true, jpg=true, jpeg=true },
  sfx  = { ogg=true, wav=true, mp3=true, flac=true },
  font = { ttf=true, otf=true },
}

local function scanDir(dir)
  for _, entry in ipairs(lf.getDirectoryItems(dir)) do
    if entry ~= "." and entry ~= ".." then
      local path = dir .. "/" .. entry
      local info = lf.getInfo(path)
      if info then
        if info.type == "directory" then
          scanDir(path)
        elseif info.type == "file" then
          local ext = entry:match("%.([%w]+)$")
          if ext then
            ext = ext:lower()
            if exts.img[ext] then
              AssetManager.getImage(path)
            elseif exts.font[ext] then
              AssetManager.getFont(path, 14)
            elseif exts.sfx[ext] then
              local kind = (info.size and info.size > 256 * 1024) and "stream" or "static"
              AssetManager.getSound(path, kind)
            end
          end
        end
      end
    end
  end
end

function AssetManager.loadAll()
  if lf.getInfo("assets") then  -- only scan if assets folder exists
    scanDir("assets")
  end
end

return AssetManager
