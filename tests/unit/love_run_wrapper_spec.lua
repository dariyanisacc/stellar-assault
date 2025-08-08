local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

describe("love.run wrapper", function()
  it("returns the original runner on success", function()
    -- Stub original love.run to return a runner function
    local runner = function() return 0 end
    love.run = function() return runner end
    package.loaded["main"] = nil
    dofile("main.lua")
    local returned = love.run()
    assert.is_function(returned)
    assert.equals(0, returned())
  end)

  it("returns a quit runner on failure and logs", function()
    local logged = {}
    love.filesystem.write = function(path, data)
      logged.path, logged.data = path, data
      return true
    end
    love.run = function()
      error("boom")
    end
    package.loaded["main"] = nil
    dofile("main.lua")
    local returned = love.run()
    assert.is_function(returned)
    assert.equals(1, returned())
    assert.is_true(logged.path:match("^crash_%d+_%d+%.log$") ~= nil)
    assert.is_truthy(logged.data)
  end)
end)

