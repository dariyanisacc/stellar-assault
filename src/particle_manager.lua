-- src/particle_manager.lua
-- Enhanced particle manager for explosions in Stellar Assault
-- Provides a more robust explosion system with particle effects

local logger = require("src.logger")

local ParticleManager = {}
ParticleManager.__index = ParticleManager

-- Pre-create explosion images (circular blasts of different sizes)
local function createBlastImage(size)
    local canvas = love.graphics.newCanvas(size, size)
    love.graphics.setCanvas(canvas)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", size/2, size/2, size/2)
    love.graphics.setCanvas()
    return canvas
end

-- Cache blast images
local blastImages = {}

local function getBlastImage(size)
    -- Round to nearest multiple of 8 for caching
    local cacheSize = math.ceil(size / 8) * 8
    if not blastImages[cacheSize] then
        blastImages[cacheSize] = createBlastImage(cacheSize)
    end
    return blastImages[cacheSize]
end

function ParticleManager:new()
    local self = setmetatable({}, ParticleManager)
    self.explosions = {}  -- Table to hold active particle systems
    
    -- Pre-create common sizes
    blastImages[16] = createBlastImage(16)
    blastImages[32] = createBlastImage(32)
    blastImages[64] = createBlastImage(64)
    
    return self
end

-- Create an explosion at a position, scaled by entity dimensions
function ParticleManager:createExplosion(x, y, size)
    -- Determine size if not provided
    if not size then
        size = 32  -- Default size
    end
    
    -- Determine blast image and particle count based on size
    local blastImage = getBlastImage(math.min(size, 64))
    local particleCount = math.floor(10 + size / 4)
    
    -- Create particle system
    local ps = love.graphics.newParticleSystem(blastImage, particleCount + 10)
    ps:setParticleLifetime(0.3, 0.7)
    ps:setLinearAcceleration(-150, -150, 150, 150)
    ps:setColors(
        1, 1, 0, 1,          -- Yellow
        1, 0.6, 0.2, 1,      -- Orange
        1, 0.3, 0.1, 0.8,    -- Dark orange
        0.5, 0.1, 0.1, 0     -- Fade to dark red
    )
    ps:setSizes(size/64, size/128)  -- Scale based on explosion size
    ps:setSpeed(100 + size, 200 + size * 2)
    ps:setSpread(math.pi * 2)
    
    -- Position at explosion center
    ps:setPosition(x, y)
    
    -- Emit particles
    ps:emit(particleCount)
    
    -- Add to active explosions
    table.insert(self.explosions, {
        ps = ps,
        lifetime = 0.7,
        x = x,
        y = y
    })
    
    -- Play sound if available
    if explosionSound then
        local sound = explosionSound:clone()
        sound:setVolume(math.min(1, size / 50))  -- Scale volume with size
        sound:play()
    end
    
    logger.debug("Explosion created at (" .. x .. ", " .. y .. ") with size " .. size)
end

-- Create explosion from entity (convenience method)
function ParticleManager:createExplosionFromEntity(entity)
    local size = entity.size or math.max(entity.width or 32, entity.height or 32)
    local centerX = entity.x + (entity.width or size) / 2
    local centerY = entity.y + (entity.height or size) / 2
    self:createExplosion(centerX, centerY, size)
end

function ParticleManager:update(dt)
    for i = #self.explosions, 1, -1 do
        local explosion = self.explosions[i]
        explosion.ps:update(dt)
        explosion.lifetime = explosion.lifetime - dt
        
        if explosion.lifetime <= 0 and explosion.ps:getCount() == 0 then
            table.remove(self.explosions, i)
        end
    end
end

function ParticleManager:draw()
    love.graphics.setBlendMode("add")  -- Additive blending for bright explosions
    for _, explosion in ipairs(self.explosions) do
        love.graphics.draw(explosion.ps)
    end
    love.graphics.setBlendMode("alpha")  -- Reset blend mode
end

function ParticleManager:clear()
    self.explosions = {}
end

return ParticleManager