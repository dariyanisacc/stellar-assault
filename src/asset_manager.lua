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
  videos  = {},   -- [normalizedPath] = love.Video
}

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------
local function norm(path)      return path:gsub("\\","/"):lower() end
local function cache(tbl,k,f)  k = norm(k); if not tbl[k] then tbl[k] = f() end; return tbl[k] end
local function hasFile(path)
  return love.filesystem.getInfo(path, "file") ~= nil
end

-- ---------------------------------------------------------------------------
-- Public getters
-- ---------------------------------------------------------------------------
function AssetManager.getImage(path)
  if not hasFile(path) then
    print("[Image] File not found: " .. tostring(path))
    return nil
  end
  return cache(AssetManager.images, path, function()
    local ok, res = pcall(function() return lg.newImage(path) end)
    if not ok then
      print("[Image] Failed to load: " .. tostring(path) .. " (" .. tostring(res) .. ")")
      return nil
    end
    return res
  end)
end

---@overload fun(size:number):love.Font
function AssetManager.getFont(arg1, size)
  local path = arg1
  if type(arg1) == "number" then size, path = arg1, nil end
  size = size or 12
  local key = (path or "default") .. ":" .. tostring(size)
  return cache(AssetManager.fonts, key, function()
    if path then
      if not hasFile(path) then
        print("[Font] File not found: " .. tostring(path) .. "; falling back to default font")
        return lg.newFont(size)
      end
      local ok, res = pcall(function() return lg.newFont(path, size) end)
      if ok and res then return res end
      print("[Font] Failed to load: " .. tostring(path) .. " (" .. tostring(res) .. ")")
      return lg.newFont(size)
    else
      return lg.newFont(size)
    end
  end)
end

function AssetManager.getSound(path, kind)
  if not love.filesystem.getInfo(path, "file") then
    print("[Audio] Sound file not found: " .. tostring(path))
    return nil
  end
  kind = kind or "static"
  local key = path .. ":" .. kind
  return cache(AssetManager.sounds, key, function()
    local ok, srcOrErr = pcall(function() return la.newSource(path, kind) end)
    if not ok then
      print("[Audio] Failed to load sound: " .. tostring(path) .. " (" .. tostring(srcOrErr) .. ")")
      return nil
    end
    return srcOrErr
  end)
end

---Get and cache a video at `path`.
---@param path string
---@return love.Video
function AssetManager.getVideo(path)
  if not hasFile(path) then
    print("[Video] File not found: " .. tostring(path))
    return nil
  end
  return cache(AssetManager.videos, path, function()
    local ok, vid = pcall(function() return lg.newVideo(path) end)
    if not ok then
      print("[Video] Failed to load: " .. tostring(path) .. " (" .. tostring(vid) .. ")")
      return nil
    end
    return vid
  end)
end

-- ---------------------------------------------------------------------------
-- Bulk loader (optional—pre-caches everything in /assets)
-- ---------------------------------------------------------------------------
local exts = {
  img  = { png=true, jpg=true, jpeg=true },
  sfx  = { ogg=true, wav=true, mp3=true, flac=true },
  font = { ttf=true, otf=true },
  video= { ogv=true },
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
            elseif exts.video[ext] then
              -- Videos are typically streamed by the GPU; just cache the handle
              AssetManager.getVideo(path)
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
