local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

local memory = {}
love.filesystem.write = function(path, data)
  memory[path] = data
  return true
end
love.filesystem.read = function(path)
  return memory[path]
end
love.filesystem.getInfo = function(path)
  if memory[path] then
    return {}
  end
end
love.filesystem.remove = function(path)
  memory[path] = nil
end
love.data.encode = function(_, _, tbl)
  return require("src.lunajson").encode(tbl)
end
love.data.decode = function(_, _, str)
  return require("src.lunajson").decode(str)
end
love.data.hash = function(_, str)
  return str
end

local Persistence = require("src.persistence")

describe("control persistence", function()
  before_each(function()
    memory = {}
    Persistence.saveData = nil
  end)

  it("saves and reloads fire mapping", function()
    local controls = Persistence.getControls()
    controls.keyboard.shoot = "space"
    Persistence.updateSettings({ controls = controls })
    Persistence.saveData = nil
    local loaded = Persistence.getControls()
    assert.equals("space", loaded.keyboard.shoot)
  end)
end)
