local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

local logged = {}
love.filesystem.write = function(path, data)
  logged.path = path
  logged.data = data
  return true
end

-- stub original run to raise error
love.run = function()
  error("test")
end

-- deterministic timestamp
os.date = function()
  return "20230101_000000"
end

dofile("main.lua")

it("writes stack trace on crash", function()
  assert.has_no.errors(function()
    love.run()
  end)
  assert.is_true(logged.path:match("^crash_%d+_%d+%.log$") ~= nil)
  assert.is_not_nil(logged.data:match("test"))
  assert.is_not_nil(logged.data:match("stack traceback"))
end)
