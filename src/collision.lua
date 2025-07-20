-- Collision System for Stellar Assault
local Collision = {}
local SpatialHash = require("src.spatial")

-- Basic AABB collision detection
function Collision.checkAABB(a, b)
    local aLeft = a.x - (a.width or a.size) / 2
    local aRight = a.x + (a.width or a.size) / 2
    local aTop = a.y - (a.height or a.size) / 2
    local aBottom = a.y + (a.height or a.size) / 2
    
    local bLeft = b.x - (b.width or b.size) / 2
    local bRight = b.x + (b.width or b.size) / 2
    local bTop = b.y - (b.height or b.size) / 2
    local bBottom = b.y + (b.height or b.size) / 2
    
    return aLeft < bRight and aRight > bLeft and 
           aTop < bBottom and aBottom > bTop
end

-- Point vs AABB collision
function Collision.pointInAABB(px, py, box)
    local left = box.x - (box.width or box.size) / 2
    local right = box.x + (box.width or box.size) / 2
    local top = box.y - (box.height or box.size) / 2
    local bottom = box.y + (box.height or box.size) / 2
    
    return px >= left and px <= right and py >= top and py <= bottom
end

-- Circle collision detection
function Collision.checkCircle(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local radiusA = a.radius or a.size / 2
    local radiusB = b.radius or b.size / 2
    
    return distance < radiusA + radiusB
end

-- Line vs AABB collision (for lasers)
function Collision.lineIntersectsAABB(x1, y1, x2, y2, box)
    local left = box.x - (box.width or box.size) / 2
    local right = box.x + (box.width or box.size) / 2
    local top = box.y - (box.height or box.size) / 2
    local bottom = box.y + (box.height or box.size) / 2
    
    -- Check if line is completely outside box
    if (x1 < left and x2 < left) or (x1 > right and x2 > right) then
        return false
    end
    if (y1 < top and y2 < top) or (y1 > bottom and y2 > bottom) then
        return false
    end
    
    -- Check if either endpoint is inside box
    if Collision.pointInAABB(x1, y1, box) or Collision.pointInAABB(x2, y2, box) then
        return true
    end
    
    -- Check line intersections with box edges
    local dx = x2 - x1
    local dy = y2 - y1
    
    -- Check intersection with each edge
    local edges = {
        {left, top, right, top},      -- top edge
        {right, top, right, bottom},  -- right edge
        {right, bottom, left, bottom}, -- bottom edge
        {left, bottom, left, top}      -- left edge
    }
    
    for _, edge in ipairs(edges) do
        if Collision.lineIntersectsLine(x1, y1, x2, y2, edge[1], edge[2], edge[3], edge[4]) then
            return true
        end
    end
    
    return false
end

-- Line vs Line intersection
function Collision.lineIntersectsLine(x1, y1, x2, y2, x3, y3, x4, y4)
    local denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if math.abs(denom) < 0.0001 then
        return false -- Lines are parallel
    end
    
    local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
    local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
    
    return t >= 0 and t <= 1 and u >= 0 and u <= 1
end

-- Get collision normal for bounce effects
function Collision.getCollisionNormal(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        return dx / distance, dy / distance
    else
        return 0, -1 -- Default to up
    end
end

-- Check if entity is on screen
function Collision.isOnScreen(entity, screenWidth, screenHeight, margin)
    margin = margin or 0
    local size = entity.radius or entity.size or math.max(entity.width or 0, entity.height or 0)
    
    return entity.x + size + margin >= 0 and
           entity.x - size - margin <= screenWidth and
           entity.y + size + margin >= 0 and
           entity.y - size - margin <= screenHeight
end

Collision.SpatialHash = SpatialHash



return Collision
