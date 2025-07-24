local love_mock = require("tests.mocks/love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local PlayingState = require("states.playing")
local ObjectPool = require("src.objectpool")
local Particles = require("src.particles")

describe("Explosion particle limits", function()
    local state
    before_each(function()
        state = setmetatable({}, {__index = PlayingState})
        state.explosionPool = ObjectPool.createExplosionPool()
        state.particlePool = ObjectPool.createParticlePool()
        state.debrisPool = ObjectPool.createDebrisPool()
        _G.explosions = {}
    end

    it("spawns debris particle system", function()
        state:createExplosion(100, 100, 200)
        assert.is_true(Particles.getActiveCount() > 0)
    end)
end