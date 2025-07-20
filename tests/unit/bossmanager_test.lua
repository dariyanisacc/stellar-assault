local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local BossManager = require("src.bossmanager")
local constants = require("src.constants")

describe("BossManager", function()
    it("spawns boss with correct attributes", function()
        local mgr = BossManager:new()
        local boss = mgr:spawnBoss("annihilator", 100, 50)
        assert.is_not_nil(mgr.activeBoss)
        assert.equals("annihilator", boss.type)
        assert.equals(100, boss.x)
        assert.equals(constants.boss.annihilator.hp, boss.health)
    end)

    it("updates boss state", function()
        local mgr = BossManager:new()
        mgr:spawnBoss("annihilator", nil, -100)
        mgr:update(3)
        assert.equals("active", mgr.activeBoss.state)
    end)

    it("applies damage and defeats boss", function()
        local mgr = BossManager:new()
        local boss = mgr:spawnBoss("annihilator")
        mgr:takeDamage(boss.health)
        assert.equals("dying", mgr.activeBoss.state)
        mgr:update(4)
        assert.is_nil(mgr.activeBoss)
    end)
end)
