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

-- Trail Particle Pool
function ObjectPool.createTrailPool()
    local function createTrail()
        return {
            x = 0,
            y = 0,
            vx = 0,
            vy = 0,
            life = 0,
            maxLife = 0,
            size = 1,
            color = {1, 1, 1},
            type = "trail",
            pool = nil
        }
    end

    local function resetTrail(trail)
        trail.x = 0
        trail.y = 0
        trail.vx = 0
        trail.vy = 0
        trail.life = 0
        trail.maxLife = 0
        trail.size = 1
        trail.color = {1, 1, 1}
        trail.type = "trail"
        trail.pool = nil
    end

    return ObjectPool:new(createTrail, resetTrail, 300)
end

-- Debris Particle Pool
function ObjectPool.createDebrisPool()
    local function createDebris()
        return {
            x = 0,
            y = 0,
            vx = 0,
            vy = 0,
            life = 0,
            maxLife = 0,
            size = 1,
            rotation = 0,
            rotationSpeed = 0,
            color = {1, 1, 1},
            type = "debris",
            pool = nil
        }
    end

    local function resetDebris(debris)
        debris.x = 0
        debris.y = 0
        debris.vx = 0
        debris.vy = 0
        debris.life = 0
        debris.maxLife = 0
        debris.size = 1
        debris.rotation = 0
        debris.rotationSpeed = 0
        debris.color = {1, 1, 1}
        debris.type = "debris"
        debris.pool = nil
    end

    return ObjectPool:new(createDebris, resetDebris, 300)
end

return ObjectPool
