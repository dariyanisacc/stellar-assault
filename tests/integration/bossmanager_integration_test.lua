local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local BossManager = require("src.bossmanager")

describe("BossManager integration", function()
    it("handles phases and attacks", function()
        math.randomseed(1)
        local mgr = BossManager:new()
        local boss = mgr:spawnBoss("annihilator", nil, -100)
        mgr:update(3)
        assert.equals(1, boss.phase)

        mgr:takeDamage(boss.maxHealth * 0.3)
        mgr:update(0)
        assert.is_true(boss.phase > 1)

        mgr:update(5)
        assert.is_not_nil(boss.currentAttack)
    end)
end)
