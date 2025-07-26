-- src/spatial.lua
-- Simple spatial hash grid utility for Stellar Assault
-- Provides fast neighbourhood queries and basic collision helpers.
-- Drop‑in replacement for the missing `src.spatial` module expected by
-- states/playing.lua and other gameplay code.

local SpatialHash = {}
SpatialHash.__index = SpatialHash

-- Create a new spatial hash grid. `cellSize` defaults to 64 pixels.
function SpatialHash:new(cellSize)
    local o = setmetatable({}, self)
    o.cellSize = cellSize or 64
    o.cells = {}
    return o
end

-- Internal cell key generator
local function _hash(self, x, y)
    return math.floor(x / self.cellSize) .. "," .. math.floor(y / self.cellSize)
end

-- Wipe all stored data
function SpatialHash:clear()
    self.cells = {}
end

-- Helper that inserts an `item` whose centre is `item.x,item.y` and whose
-- axis‑aligned bounding box is described by `width/height` or `size`.
function SpatialHash:insert(item)
    local halfW = (item.width  or item.size or 0) * 0.5
    local halfH = (item.height or item.size or 0) * 0.5
    local minX  = math.floor((item.x - halfW) / self.cellSize)
    local maxX  = math.floor((item.x + halfW) / self.cellSize)
    local minY  = math.floor((item.y - halfH) / self.cellSize)
    local maxY  = math.floor((item.y + halfH) / self.cellSize)

    for cx = minX, maxX do
        for cy = minY, maxY do
            local key = cx .. "," .. cy
            if not self.cells[key] then
                self.cells[key] = {}
            end
            table.insert(self.cells[key], item)
        end
    end
end

-- Remove an item from every cell it occupies
function SpatialHash:remove(item)
    for key, cell in pairs(self.cells) do
        for i = #cell, 1, -1 do
            if cell[i] == item then
                table.remove(cell, i)
            end
        end
        if #cell == 0 then
            self.cells[key] = nil
        end
    end
end

-- Re‑insert an item after it has moved
function SpatialHash:update(item)
    self:remove(item)
    self:insert(item)
end

-- Collect items whose AABB intersects the rectangle centred on (x,y)
-- with dimensions w×h. Reuses `results` table if supplied.
function SpatialHash:queryRange(x, y, w, h, results)
    results = results or {}
    local halfW, halfH = w * 0.5, h * 0.5
    local minX  = math.floor((x - halfW) / self.cellSize)
    local maxX  = math.floor((x + halfW) / self.cellSize)
    local minY  = math.floor((y - halfH) / self.cellSize)
    local maxY  = math.floor((y + halfH) / self.cellSize)

    local visited = {}
    for cx = minX, maxX do
        for cy = minY, maxY do
            local cell = self.cells[cx .. "," .. cy]
            if cell then
                for _, obj in ipairs(cell) do
                    if not visited[obj] then
                        visited[obj] = true
                        table.insert(results, obj)
                    end
                end
            end
        end
    end
    return results
end

-- Convenience: query everything that lies within `radius` of point (x,y)
function SpatialHash:queryRadius(x, y, radius, results)
    return self:queryRange(x, y, radius * 2, radius * 2, results)
end

---------------------------------------------------------------------
-- Collision helpers (AABB + point‑in‑circle) -----------------------
---------------------------------------------------------------------
local function _aabb(a, b)
    local aHalfW = (a.width  or a.size or 0) * 0.5
    local aHalfH = (a.height or a.size or 0) * 0.5
    local bHalfW = (b.width  or b.size or 0) * 0.5
    local bHalfH = (b.height or b.size or 0) * 0.5

    return math.abs(a.x - b.x) < (aHalfW + bHalfW) and
           math.abs(a.y - b.y) < (aHalfH + bHalfH)
end

local function _pointInCircle(px, py, cx, cy, r)
    local dx, dy = px - cx, py - cy
    return dx * dx + dy * dy <= r * r
end

---------------------------------------------------------------------
-- Public interface -------------------------------------------------
---------------------------------------------------------------------
local M = {
    SpatialHash    = SpatialHash,

    -- Legacy helpers expected by existing game code
    checkCollision = _aabb,
    aabb           = _aabb,
    pointInCircle  = _pointInCircle,
}

-- Look up SpatialHash methods on the module table
M.__index = SpatialHash

---Create a new spatial hash grid instance.
-- @param cellSize number? grid cell size in pixels (defaults to 64)
-- @return table grid instance
function M:new(cellSize)
    return SpatialHash.new(self, cellSize)
end

return M
