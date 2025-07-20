-- Spatial hash grid for efficient entity lookup
local SpatialHash = {}
SpatialHash.__index = SpatialHash

function SpatialHash:new(cellSize)
    local self = setmetatable({}, SpatialHash)
    self.cellSize = cellSize or 100
    self.cells = {}
    return self
end

function SpatialHash:clear()
    self.cells = {}
end

function SpatialHash:getKey(x, y)
    local cx = math.floor(x / self.cellSize)
    local cy = math.floor(y / self.cellSize)
    return cx .. "," .. cy
end

function SpatialHash:getEntityKeys(entity)
    local keys = {}
    local w = entity.width or entity.size or (entity.radius and entity.radius * 2) or 0
    local h = entity.height or entity.size or (entity.radius and entity.radius * 2) or 0

    local left = entity.x - w / 2
    local right = entity.x + w / 2
    local top = entity.y - h / 2
    local bottom = entity.y + h / 2

    local startX = math.floor(left / self.cellSize)
    local endX = math.floor(right / self.cellSize)
    local startY = math.floor(top / self.cellSize)
    local endY = math.floor(bottom / self.cellSize)

    for x = startX, endX do
        for y = startY, endY do
            table.insert(keys, x .. "," .. y)
        end
    end

    return keys
end

function SpatialHash:insert(entity)
    local keys = self:getEntityKeys(entity)
    for _, key in ipairs(keys) do
        if not self.cells[key] then
            self.cells[key] = {}
        end
        table.insert(self.cells[key], entity)
    end
end

function SpatialHash:getNearby(entity)
    local nearby = {}
    local seen = {}

    local keys = self:getEntityKeys(entity)
    for _, key in ipairs(keys) do
        local cell = self.cells[key]
        if cell then
            for _, other in ipairs(cell) do
                if other ~= entity and not seen[other] then
                    seen[other] = true
                    table.insert(nearby, other)
                end
            end
        end
    end

    return nearby
end

return SpatialHash
