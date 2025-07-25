local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local WaveManager = require("src.wave_manager")

describe("WaveManager spawnEnemy", function()
    local manager
    local player

    before_each(function()
        player = {x = 0, y = 0, width = 20, height = 20}
        manager = WaveManager:new(player)
        math.randomseed(1)
    end)

    it("adds enemy to list and increments count", function()
        manager.currentWaveConfig = {enemyTypes={{behavior="move_left", speed=100, health=1, weight=1}}}
        manager.waveDifficulty = 1
        manager.waveNumber = 1
        manager:spawnEnemy()
        assert.equals(1, #manager.enemies)
        assert.equals(1, manager.enemiesSpawned)
    end)

    it("uses pooled enemy when available", function()
        local pooled = {width = 40, height = 40}
        table.insert(manager.pool, pooled)
        manager.currentWaveConfig = {enemyTypes={{behavior="move_left", speed=100, health=1, weight=1}}}
        manager.waveDifficulty = 1
        manager.waveNumber = 1
        manager:spawnEnemy()
        assert.equals(pooled, manager.enemies[1])
    end)

    it("assigns shooting properties when type can shoot", function()
        manager.getRandomEnemyType = function()
            return {behavior="move_left", speed=100, health=1, weight=1, canShoot=true, shootInterval=1.2}
        end
        manager.waveDifficulty = 1
        manager.waveNumber = 1
        manager:spawnEnemy()
        local enemy = manager.enemies[1]
        assert.is_true(enemy.canShoot)
        assert.are.same(1.2, enemy.shootInterval)
    end)
end)

