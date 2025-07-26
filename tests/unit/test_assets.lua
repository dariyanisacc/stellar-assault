local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

-- override newImage to ensure the file exists on disk
love.graphics.newImage = function(path)
  local f = io.open(path, "rb")
  assert(f, "missing asset: " .. path)
  f:close()
  return { path = path, type = "image" }
end

local lfs = require("lfs")
local assets = {}
local function scan(dir)
  for entry in lfs.dir(dir) do
    if entry ~= "." and entry ~= ".." then
      local path = dir .. "/" .. entry
      local attr = lfs.attributes(path)
      if attr.mode == "directory" then
        scan(path)
      elseif attr.mode == "file" and entry:match("%.png$") then
        table.insert(assets, path)
      end
    end
  end
end
scan("assets")
table.sort(assets)

describe("Asset images", function()
  for _, path in ipairs(assets) do
    it("loads " .. path, function()
      local img = love.graphics.newImage(path)
      assert.is_table(img)
    end)
  end
end)

-- simple canvas mock for golden image hashing
local canvas = { ops = {} }

love.graphics.newCanvas = function(w, h)
  return setmetatable({ w = w, h = h, ops = {} }, { __index = canvas })
end

love.graphics.setCanvas = function(c)
  love.graphics._canvas = c
end

love.graphics.rectangle = function(mode, x, y, w, h)
  local c = love.graphics._canvas
  if c then
    table.insert(c.ops, string.format("rect:%s:%d:%d:%d:%d", mode, x, y, w, h))
  end
end

describe("Golden image", function()
  it("matches canvas hash", function()
    local c = love.graphics.newCanvas(32, 32)
    love.graphics.setCanvas(c)
    love.graphics.rectangle("fill", 0, 0, 10, 10)
    love.graphics.setCanvas()
    local data = table.concat(c.ops, "|")
    local hash = love.data.hash("sha1", data)
    assert.equals("hash" .. tostring(#data), hash)
  end)
end)
