local love_mock = require("tests.mocks.love_mock")
_G.love = love_mock
love.filesystem.append = function() end

local PlayingState = require("states.playing")
local ObjectPool = require("src.objectpool")

describe("Explosion particle limits", function()
    local state
    before_each(function()
        state = setmetatable({}, {__index = PlayingState})
        state.explosionPool = ObjectPool.createExplosionPool()
        state.particlePool = ObjectPool.createParticlePool()
        state.debrisPool = ObjectPool.createDebrisPool()
        _G.explosions = {}
    end)

    it("caps particle and debris counts", function()
        state:createExplosion(100, 100, 200)
        local particleCount, debrisCount = 0, 0
        for _, e in ipairs(explosions) do
            if e.vx then
                if e.isDebris then
                    debrisCount = debrisCount + 1
                elseif not e.isSpark and not e.isTrail then
                    particleCount = particleCount + 1
                end
            end
        end
        assert.is_true(particleCount <= 10)
        assert.is_true(debrisCount <= 10)
    end)
end)
