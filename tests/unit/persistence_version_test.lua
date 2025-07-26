local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

-- simple in-memory filesystem
local fs = {}
local function resetfs()
  fs = {}
end
love.filesystem.write = function(path, data)
  fs[path] = data
  return true
end
love.filesystem.read = function(path)
  return fs[path]
end
love.filesystem.getInfo = function(path)
  if fs[path] then
    return { size = #fs[path] }
  end
end
love.filesystem.remove = function(path)
  fs[path] = nil
  return true
end

local json = require("src.json")
local Persistence = require("src.persistence")

describe("Persistence version migration", function()
  before_each(function()
    resetfs()
  end)

  it("loads version 1 save and sets defaults", function()
    local data = { highScore = 42 }
    local jsonStr = json.encode(data)
    love.filesystem.write("stellar_assault_save.dat", jsonStr)
    love.filesystem.write("stellar_assault_save.dat.sum", love.data.hash("md5", jsonStr))
    local loaded = Persistence.load()
    assert.equals(42, loaded.highScore)
    assert.equals("windowed", loaded.settings.displayMode)
  end)

  it("saves and loads version 2 save", function()
    local data = { highScore = 10 }
    assert.is_true(Persistence.save(data))
    local fileStr = fs["stellar_assault_save.dat"]
    assert.is_not_nil(fileStr:match("^version = 2\n"))
    local loaded = Persistence.load()
    assert.equals(10, loaded.highScore)
  end)
end)
