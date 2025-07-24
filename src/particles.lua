local Particles = {}
local lg = love.graphics

local trailImage
local debrisImage

local trailPool = {}
local debrisPool = {}
local active = {}

local function createTrailSystem()
    trailImage = trailImage or lg.newImage('assets/particles/trail.png')
    local ps = lg.newParticleSystem(trailImage, 32)
    ps:setParticleLifetime(0.3, 0.5)
    ps:setSizes(1, 0)
    ps:setLinearAcceleration(0, 0, 0, 0)
    ps:setColors(1, 1, 1, 1, 1, 1, 1, 0)
    return ps
end

local function createDebrisSystem()
    debrisImage = debrisImage or lg.newImage('assets/particles/debris.png')
    local ps = lg.newParticleSystem(debrisImage, 64)
    ps:setParticleLifetime(0.4, 0.8)
    ps:setSpeed(80, 160)
    ps:setSpread(math.pi * 2)
    ps:setLinearAcceleration(-100, -100, 100, 100)
    ps:setSizes(1, 1)
    ps:setColors(1, 0.6, 0.2, 1, 1, 0.3, 0.1, 0)
    return ps
end

local function getTrail()
    return table.remove(trailPool) or createTrailSystem()
end

local function getDebris()
    return table.remove(debrisPool) or createDebrisSystem()
end

local function releaseTrail(ps)
    ps:reset()
    table.insert(trailPool, ps)
end

local function releaseDebris(ps)
    ps:reset()
    table.insert(debrisPool, ps)
end

function Particles.emitTrail(x, y, color)
    local ps = getTrail()
    if color then
        ps:setColors(color[1], color[2], color[3], 1, color[1], color[2], color[3], 0)
    else
        ps:setColors(1, 1, 1, 1, 1, 1, 1, 0)
    end
    ps:setPosition(x, y)
    ps:emit(1)
    table.insert(active, {ps = ps, release = releaseTrail})
end

function Particles.emitExplosionDebris(x, y, size)
    local ps = getDebris()
    ps:setSizes(math.min(size / 20, 2), math.min(size / 10, 4))
    ps:setPosition(x, y)
    ps:emit(math.floor(size / 8))
    table.insert(active, {ps = ps, release = releaseDebris})
end

function Particles.update(dt)
    for i = #active, 1, -1 do
        local a = active[i]
        a.ps:update(dt)
        if a.ps:getCount() == 0 then
            a.release(a.ps)
            table.remove(active, i)
        end
    end
end

function Particles.draw()
    lg.setBlendMode('add')
    for _, a in ipairs(active) do
        lg.draw(a.ps)
    end
    lg.setBlendMode('alpha')
end

function Particles.clear()
    for _, a in ipairs(active) do
        a.release(a.ps)
    end
    active = {}
    -- Do not reset trailPool or debrisPool; keep for reuse to avoid recreation overhead
end

function Particles.getActiveCount()
    return #active
end

return Particles