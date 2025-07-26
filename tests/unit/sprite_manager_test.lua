local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local SpriteManager = require("src.sprite_manager")

describe("SpriteManager.load", function()
  it("loads png files and generates keys", function()
    love.filesystem.__items = {
      ["assets/sprites"] = { "My Sprite.png", "other.txt" },
    }
    local manager = SpriteManager.load("assets/sprites")
    assert.is_not_nil(manager.sprites["my_sprite"])
    assert.is_nil(manager.sprites["other"])
  end)

  it("marks used sprites", function()
    love.filesystem.__items = {
      ["assets/sprites"] = { "Test.png" },
    }
    local manager = SpriteManager.load("assets/sprites")
    assert.is_false(manager.used["test"])
    manager:get("test")
    assert.is_true(manager.used["test"])
  end)
end)
