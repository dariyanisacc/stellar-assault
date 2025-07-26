local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local StateMachine = require("src.core.statemachine")

describe("StateMachine transitions", function()
  local machine
  local stateA
  local stateB

  before_each(function()
    machine = StateMachine:new()
    stateA = { entered = false, left = false }
    function stateA:enter()
      self.entered = true
    end
    function stateA:leave()
      self.left = true
    end
    function stateA:update(dt)
      self.updated = dt
    end
    stateB = { entered = false, left = false }
    function stateB:enter()
      self.entered = true
    end
    function stateB:leave()
      self.left = true
    end
    machine:register("a", stateA)
    machine:register("b", stateB)
  end)

  it("switches states and calls callbacks", function()
    machine:switch("a")
    assert.is_true(stateA.entered)
    machine:switch("b")
    assert.is_true(stateA.left)
    assert.is_true(stateB.entered)
    assert.equals("b", machine.currentName)
    assert.equals(stateB, machine.current)
  end)

  it("forwards update to current state", function()
    machine:switch("a")
    machine:update(0.5)
    assert.equals(0.5, stateA.updated)
  end)

  it("pushes and pops states", function()
    machine:push("a")
    machine:push("b")
    assert.equals("b", machine.currentName)
    machine:pop()
    assert.is_true(stateB.left)
    assert.equals("a", machine.currentName)
  end)
end)
