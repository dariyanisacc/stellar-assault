local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

local AudioPool = require("src.audiopool")

describe("AudioPool", function()
  local pool
  before_each(function()
    _G.Game = { sfxVolume = 1, masterVolume = 1 }
    _G.player = { x = 0, y = 0 }
    pool = AudioPool:new(8)
    local src = love.audio.newSource("laser.wav", "static")
    pool:register("laser", src)
  end)

  it("reuses pre-cloned sources", function()
    assert.equals(8, #pool.pool.laser.clones)
    for i = 1, 20 do
      pool:play("laser", 0, 0)
    end
    assert.equals(8, #pool.pool.laser.clones)
  end)
end)
