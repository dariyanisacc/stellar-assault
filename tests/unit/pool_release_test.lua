-- Particle Pool Regression Tests
local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local ObjectPool = require("src.objectpool")
local PlayingState = require("states.playing")

describe("Particle Pools", function()
    local state

    before_each(function()
        _G.player = {x = 0, y = 0, width = 20, height = 20, heat = 0, maxHeat = 100}
        _G.explosions = {}

        local orig_random = math.random
        local function rand(min, max)
            if max and min > max then min, max = max, min end
            if max then
                return orig_random(min, max)
            elseif min then
                return orig_random(min)
            else
                return orig_random()
            end
        end
        love.math.random = rand
        math.random = rand

        state = setmetatable({
            explosionPool = ObjectPool.createExplosionPool(),
            particlePool = ObjectPool.createParticlePool(),
            trailPool = ObjectPool.createTrailPool(),
            debrisPool = ObjectPool.createDebrisPool()
        }, {__index = PlayingState})
    end)

    it("assigns pool on createExplosion", function()
        state:createExplosion(0, 0, 20)
        for _, p in ipairs(explosions) do
            assert.is_not_nil(p.pool)
        end
    end)

    it("assigns pool on createHitEffect", function()
        state:createHitEffect(0, 0)
        assert.is_not_nil(explosions[1].pool)
    end)

    it("assigns pool on heat particle", function()
        state:createHeatParticle()
        assert.is_not_nil(explosions[1].pool)
    end)

    it("releases objects back to pools", function()
        state:createExplosion(0, 0, 20)
        local beforeExp = state.explosionPool:getActiveCount()
        local beforePart = state.particlePool:getActiveCount()
        local beforeDeb = state.debrisPool:getActiveCount()
        assert.is_true(beforeExp > 0)
        assert.is_true(beforePart > 0)
        assert.is_true(beforeDeb > 0)

        state:updateExplosions(5)

        assert.equals(0, state.explosionPool:getActiveCount())
        assert.equals(0, state.particlePool:getActiveCount())
        assert.equals(0, state.debrisPool:getActiveCount())
        assert.equals(0, #explosions)
    end)

    it("releases hit effects", function()
        state:createHitEffect(0, 0)
        assert.equals(1, state.explosionPool:getActiveCount())
        state:updateExplosions(1)
        assert.equals(0, state.explosionPool:getActiveCount())
        assert.equals(0, #explosions)
    end)
end)
