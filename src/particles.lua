-- Enhanced particle system for visual effects
local Particles = {}
Particles.__index = Particles

function Particles:new()
    local self = setmetatable({}, Particles)
    self.particles = {}
    return self
end

-- Create debris particles when something explodes
function Particles:createDebris(x, y, count, color, speed)
    count = count or 10
    color = color or {1, 1, 1}
    speed = speed or 100
    
    for i = 1, count do
        local angle = (i / count) * math.pi * 2 + math.random() * 0.5
        local velocity = speed + math.random() * speed * 0.5
        
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * velocity,
            vy = math.sin(angle) * velocity,
            life = 0.5 + math.random() * 0.5,
            maxLife = 0.5 + math.random() * 0.5,
            size = 2 + math.random() * 3,
            color = {color[1], color[2], color[3]},
            rotation = math.random() * math.pi * 2,
            rotationSpeed = math.random() * 10 - 5,
            type = "debris"
        }
        
        table.insert(self.particles, particle)
    end
end

-- Create spark particles for hits
function Particles:createSparks(x, y, count, color)
    count = count or 5
    color = color or {1, 1, 0}
    
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 150 + math.random() * 100
        
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.2 + math.random() * 0.2,
            maxLife = 0.2 + math.random() * 0.2,
            size = 1 + math.random() * 2,
            color = {color[1], color[2], color[3]},
            type = "spark"
        }
        
        table.insert(self.particles, particle)
    end
end

-- Create explosion ring effect
function Particles:createExplosionRing(x, y, color)
    color = color or {1, 0.5, 0}
    
    local ring = {
        x = x,
        y = y,
        radius = 0,
        maxRadius = 80,
        life = 0.5,
        maxLife = 0.5,
        color = {color[1], color[2], color[3]},
        type = "ring"
    }
    
    table.insert(self.particles, ring)
end

-- Create smoke/dust particles
function Particles:createSmoke(x, y, count)
    count = count or 8
    
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 20 + math.random() * 30
        
        local particle = {
            x = x + math.random() * 20 - 10,
            y = y + math.random() * 20 - 10,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 20,
            life = 1 + math.random() * 0.5,
            maxLife = 1 + math.random() * 0.5,
            size = 10 + math.random() * 10,
            color = {0.5, 0.5, 0.5},
            type = "smoke"
        }
        
        table.insert(self.particles, particle)
    end
end

function Particles:update(dt)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        
        p.life = p.life - dt
        
        if p.life <= 0 then
            table.remove(self.particles, i)
        else
            -- Update based on type
            if p.type == "debris" or p.type == "spark" then
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                p.vy = p.vy + 200 * dt  -- gravity
                p.vx = p.vx * 0.98      -- air resistance
                
                if p.rotation then
                    p.rotation = p.rotation + p.rotationSpeed * dt
                end
                
            elseif p.type == "smoke" then
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                p.vx = p.vx * 0.95
                p.vy = p.vy * 0.95
                p.size = p.size + dt * 10
                
            elseif p.type == "ring" then
                p.radius = p.radius + 200 * dt
            end
        end
    end
end

function Particles:draw()
    local lg = love.graphics
    
    for _, p in ipairs(self.particles) do
        local alpha = p.life / p.maxLife
        
        if p.type == "debris" then
            lg.push()
            lg.translate(p.x, p.y)
            lg.rotate(p.rotation or 0)
            lg.setColor(p.color[1], p.color[2], p.color[3], alpha)
            lg.rectangle("fill", -p.size/2, -p.size/2, p.size, p.size)
            lg.pop()
            
        elseif p.type == "spark" then
            lg.setColor(p.color[1], p.color[2], p.color[3], alpha)
            lg.circle("fill", p.x, p.y, p.size * alpha)
            
        elseif p.type == "smoke" then
            lg.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.3)
            lg.circle("fill", p.x, p.y, p.size)
            
        elseif p.type == "ring" then
            lg.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.5)
            lg.setLineWidth(3 * alpha)
            lg.circle("line", p.x, p.y, p.radius)
            lg.setLineWidth(1)
        end
    end
    
    lg.setColor(1, 1, 1, 1)
end

function Particles:clear()
    self.particles = {}
end

return Particles