local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local StateMachine = require("src.core.statemachine")

describe("Intro state nextState", function()
  local machine
  local playing

  before_each(function()
    machine = StateMachine:new()
    stateManager = machine
    _G.stateManager = machine
    package.loaded["states.intro"] = nil
    playing = { entered = false }
    function playing:enter()
      self.entered = true
    end
    machine:register("intro", require("states.intro"))
    machine:register("playing", playing)
  end)

  it("auto advances to nextState", function()
    machine:switch("intro", { nextState = "playing" })
    machine:update(3.1)
    assert.equals("playing", machine.currentName)
    assert.is_true(playing.entered)
  end)

  it("skips to nextState on keypress", function()
    machine:switch("intro", { nextState = "playing" })
    machine:update(0.7)
    machine:keypressed("space")
    assert.equals("playing", machine.currentName)
  end)
end)
