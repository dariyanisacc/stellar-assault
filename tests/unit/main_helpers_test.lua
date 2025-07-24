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

    it("exposes loadAudioResources", function()
        assert.is_function(loadAudioResources)
    end)

    it("exposes initStates", function()
        assert.is_function(initStates)
    end)
end)
