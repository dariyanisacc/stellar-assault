local lg = love.graphics
local la = love.audio
local lf = love.filesystem

local AssetManager = {
  images = {},
  fonts = {},
  sounds = {},
}

function AssetManager.getImage(path)
  if not AssetManager.images[path] then
    AssetManager.images[path] = lg.newImage(path)
  end
  return AssetManager.images[path]
end

function AssetManager.getFont(arg1, size)
  local path = arg1
  if type(arg1) == "number" then
    size = arg1
    path = nil
  end
  local key = (path or "default") .. ":" .. tostring(size or 12)
  if not AssetManager.fonts[key] then
    if path then
      AssetManager.fonts[key] = lg.newFont(path, size)
    else
      AssetManager.fonts[key] = lg.newFont(size)
    end
  end
  return AssetManager.fonts[key]
end

function AssetManager.getSound(path, kind)
  local key = path .. ":" .. (kind or "static")
  if not AssetManager.sounds[key] then
    AssetManager.sounds[key] = la.newSource(path, kind or "static")
  end
  return AssetManager.sounds[key]
end

local function scanDir(dir)
  for _, entry in ipairs(lf.getDirectoryItems(dir)) do
    if entry ~= "." and entry ~= ".." then
      local path = dir .. "/" .. entry
      local info = lf.getInfo(path)
      if info then
        if info.type == "directory" then
          scanDir(path)
        elseif entry:match("%.png$") then
          AssetManager.getImage(path)
        elseif entry:match("%.ttf$") or entry:match("%.otf$") then
          AssetManager.getFont(path, 14)
        elseif
          entry:match("%.ogg$")
          or entry:match("%.wav$")
          or entry:match("%.mp3$")
          or entry:match("%.flac$")
        then
          AssetManager.getSound(path, "static")
        end
      end
    end
  end
end

function AssetManager.load()
  if lf.getInfo("assets") then
    scanDir("assets")
  end
end

return AssetManager
