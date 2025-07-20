-- Object Pool for efficient memory management
local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool:new(createFunc, resetFunc, maxSize)
    local self = setmetatable({}, ObjectPool)
    self.createFunc = createFunc or function() return {} end
    self.resetFunc = resetFunc or function(obj) end
    self.maxSize = maxSize or 100
    self.available = {}
    self.active = {}
    
    -- Pre-allocate some objects
    for i = 1, math.min(10, maxSize) do
        table.insert(self.available, self.createFunc())
    end
    
    return self
end

function ObjectPool:get()
    local obj
    
    if #self.available > 0 then
        obj = table.remove(self.available)
    else
        obj = self.createFunc()
    end
    
    table.insert(self.active, obj)
    return obj
end

function ObjectPool:release(obj)
    for i = #self.active, 1, -1 do
        if self.active[i] == obj then
            table.remove(self.active, i)
            self.resetFunc(obj)
            
            if #self.available < self.maxSize then
                table.insert(self.available, obj)
            end
            
            return true
        end
    end
    
    return false
end

function ObjectPool:releaseAll()
    for i = #self.active, 1, -1 do
        local obj = self.active[i]
        self.resetFunc(obj)
        
        if #self.available < self.maxSize then
            table.insert(self.available, obj)
        end
    end
    
    self.active = {}
end

function ObjectPool:getActiveCount()
    return #self.active
end

function ObjectPool:getAvailableCount()
    return #self.available
end

-- Specialized pools for common game objects

-- Laser Pool
function ObjectPool.createLaserPool()
    local createLaser = function()
        return {
            x = 0,
            y = 0,
            speed = 0,
            isAlien = false,
            width = 4,
            height = 12
        }
    end
    
    local resetLaser = function(laser)
        laser.x = 0
        laser.y = 0
        laser.speed = 0
        laser.isAlien = false
    end
    
    return ObjectPool:new(createLaser, resetLaser, 200)
end

-- Explosion Pool
function ObjectPool.createExplosionPool()
    local createExplosion = function()
        return {
            x = 0,
            y = 0,
            radius = 0,
            maxRadius = 0,
            speed = 0,
            alpha = 1,
            particles = {}
        }
    end
    
    local resetExplosion = function(explosion)
        explosion.x = 0
        explosion.y = 0
        explosion.radius = 0
        explosion.maxRadius = 0
        explosion.speed = 0
        explosion.alpha = 1
        explosion.particles = {}
    end
    
    return ObjectPool:new(createExplosion, resetExplosion, 50)
end

-- Particle Pool
function ObjectPool.createParticlePool()
    local createParticle = function()
        return {
            x = 0,
            y = 0,
            vx = 0,
            vy = 0,
            life = 0,
            maxLife = 0,
            size = 1,
            color = {1, 1, 1}
        }
    end
    
    local resetParticle = function(particle)
        particle.x = 0
        particle.y = 0
        particle.vx = 0
        particle.vy = 0
        particle.life = 0
        particle.maxLife = 0
        particle.size = 1
        particle.color = {1, 1, 1}
    end
    
    return ObjectPool:new(createParticle, resetParticle, 500)
end

-- Trail particles follow lasers briefly
function ObjectPool.createTrailPool()
    local function createTrail()
        return {
            x = 0,
            y = 0,
            vx = 0,
            vy = 0,
            life = 0,
            maxLife = 0,
            size = 2,
            color = {1, 1, 1, 1}
        }
    end

    local function resetTrail(p)
        p.x, p.y, p.vx, p.vy = 0, 0, 0, 0
        p.life, p.maxLife = 0, 0
        p.size = 2
        p.color[1], p.color[2], p.color[3], p.color[4] = 1, 1, 1, 1
        p.rotation = nil
        p.rotationSpeed = nil
        p.isDebris = nil
        p.isSpark = nil
        p.pool = nil
    end

    return ObjectPool:new(createTrail, resetTrail, 300)
end

-- Debris particles spawned from explosions
function ObjectPool.createDebrisPool()
    local function createDebris()
        return {
            x = 0,
            y = 0,
            vx = 0,
            vy = 0,
            life = 0,
            maxLife = 0,
            size = 2,
            rotation = 0,
            rotationSpeed = 0,
            isDebris = true,
            color = {1, 1, 1, 1}
        }
    end

    local function resetDebris(d)
        d.x, d.y, d.vx, d.vy = 0, 0, 0, 0
        d.life, d.maxLife = 0, 0
        d.size = 2
        d.rotation, d.rotationSpeed = 0, 0
        d.color[1], d.color[2], d.color[3], d.color[4] = 1, 1, 1, 1
        d.isDebris = true
        d.isSpark = nil
        d.pool = nil
    end

    return ObjectPool:new(createDebris, resetDebris, 300)
end

return ObjectPool
