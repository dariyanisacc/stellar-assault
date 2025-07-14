-- Camera system with shake effects
local Camera = {}
Camera.__index = Camera

function Camera:new()
    local self = setmetatable({}, Camera)
    self.x = 0
    self.y = 0
    self.shakeAmount = 0
    self.shakeDuration = 0
    self.shakeIntensity = 0
    return self
end

function Camera:update(dt)
    if self.shakeDuration > 0 then
        self.shakeDuration = self.shakeDuration - dt
        
        -- Calculate shake offset
        local angle = math.random() * math.pi * 2
        local radius = self.shakeAmount * (self.shakeDuration / self.shakeIntensity)
        
        self.x = math.cos(angle) * radius
        self.y = math.sin(angle) * radius
    else
        -- Smooth return to center
        self.x = self.x * 0.9
        self.y = self.y * 0.9
    end
end

function Camera:shake(duration, intensity)
    self.shakeDuration = duration or 0.2
    self.shakeIntensity = duration or 0.2
    self.shakeAmount = intensity or 4
end

function Camera:apply()
    love.graphics.push()
    love.graphics.translate(-self.x, -self.y)
end

function Camera:release()
    love.graphics.pop()
end

return Camera