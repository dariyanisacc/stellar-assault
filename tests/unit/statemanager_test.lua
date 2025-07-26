local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local StateManager = require("src.StateManager")

describe("StateManager transitions", function()
    local manager
    local stateA
    local stateB

    before_each(function()
        manager = StateManager:new()
        stateA = {entered=false,left=false}
        function stateA:enter() self.entered = true end
        function stateA:leave() self.left = true end
        function stateA:update(dt) self.updated = dt end
        stateB = {entered=false}
        function stateB:enter() self.entered = true end
        manager:register("a", stateA)
        manager:register("b", stateB)
    end)

    it("switches states and calls callbacks", function()
        manager:switch("a")
        assert.is_true(stateA.entered)
        manager:switch("b")
        assert.is_true(stateA.left)
        assert.is_true(stateB.entered)
        assert.equals("b", manager.currentName)
        assert.equals(stateB, manager.current)
    end)

    it("forwards update to current state", function()
        manager:switch("a")
        manager:update(0.5)
        assert.equals(0.5, stateA.updated)
    end)
end)

