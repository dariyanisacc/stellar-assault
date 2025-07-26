local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

describe("Main helper functions", function()
    before_each(function()
        package.loaded["main"] = nil
        dofile("main.lua")
    end)

    it("exposes initWindow", function()
        assert.is_function(initWindow)
    end)

    it("exposes loadFonts", function()
        assert.is_function(loadFonts)
    end)

    -- The main module exposes a function named `loadAudio` for initializing
    -- audio assets. Older code referenced this helper as
    -- `loadAudioResources`, so we simply ensure that the current name is
    -- available.
    it("exposes loadAudio", function()
        assert.is_function(loadAudio)
    end)

    it("exposes initStates", function()
        assert.is_function(initStates)
    end)
end)
