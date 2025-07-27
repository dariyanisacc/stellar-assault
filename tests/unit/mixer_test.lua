local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

local Mixer = require("src.Mixer")

describe("Mixer", function()
  it("updates volumes for registered sources", function()
    local mixer = Mixer.new()
    local sfx = love.audio.newSource("laser.wav", "static")
    sfx.baseVolume = 1
    mixer:register(sfx, "sfx")
    local music = love.audio.newSource("music.mp3", "stream")
    music.baseVolume = 1
    mixer:register(music, "music")

    mixer:setMasterVolume("sfx", 0.5)
    assert.is_true(math.abs(sfx.volume - 0.5) < 0.001)

    mixer:setMasterVolume("master", 0.2)
    assert.is_true(math.abs(sfx.volume - 0.1) < 0.001)
    assert.is_true(math.abs(music.volume - 0.04) < 0.001)
  end)
end)
