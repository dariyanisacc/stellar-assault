local lg = love.graphics

local AssetLoader = {
  _images = {},
  _quads = {},
}

function AssetLoader.getImage(path)
  if not AssetLoader._images[path] then
    AssetLoader._images[path] = lg.newImage(path)
  end
  return AssetLoader._images[path]
end

function AssetLoader.getQuad(path, x, y, w, h)
  local key = string.format("%s:%d,%d,%d,%d", path, x, y, w, h)
  if not AssetLoader._quads[key] then
    local img = AssetLoader.getImage(path)
    AssetLoader._quads[key] = lg.newQuad(x, y, w, h, img:getDimensions())
  end
  return AssetLoader._quads[key], AssetLoader.getImage(path)
end

return AssetLoader
