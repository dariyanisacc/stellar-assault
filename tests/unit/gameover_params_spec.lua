local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock

describe("GameOverState params handling", function()
  local savedPersistence

  before_each(function()
    -- Stub Persistence used by gameover state
    savedPersistence = package.loaded["src.persistence"]
    package.loaded["src.persistence"] = {
      getHighScore = function() return 1000 end,
      getBestKillCount = function() return 25 end,
      getBestSurvivalTime = function() return 120 end,
      updateBestKillCount = function(_) return false end,
      updateBestSurvivalTime = function(_) return false end,
    }
    -- Ensure any stray globals won't be read
    _G.score = 777
    _G.currentLevel = 42
    _G.levelAtDeath = 99
  end)

  after_each(function()
    package.loaded["src.persistence"] = savedPersistence
  end)

  it("consumes a params table and ignores globals", function()
    package.loaded["states.gameover"] = nil
    local GameOver = require("states.gameover")
    local params = {
      score = 250,
      level = 3,
      kills = 17,
      duration = 45.5,
      reason = "death",
      gameComplete = false,
    }
    GameOver:enter(params)

    assert.equals(250, GameOver.finalScore)
    assert.equals(3, GameOver.levelReached)
    assert.equals(17, GameOver.killCount)
    assert.is_true(math.abs(GameOver.playTime - 45.5) < 1e-6)
    assert.equals("death", GameOver.reason)
    assert.is_false(GameOver.gameComplete)
  end)
end)

