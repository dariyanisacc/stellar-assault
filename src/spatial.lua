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
    for k in pairs(self.cells) do
        self.cells[k] = nil
    end
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
    entity._spatialKeys = keys
end

function SpatialHash:remove(entity)
    local keys = entity._spatialKeys or self:getEntityKeys(entity)
    for _, key in ipairs(keys) do
        local cell = self.cells[key]
        if cell then
            for i = #cell, 1, -1 do
                if cell[i] == entity then
                    table.remove(cell, i)
                end
            end
            if #cell == 0 then
                self.cells[key] = nil
            end
        end
    end
    entity._spatialKeys = nil
end

function SpatialHash:update(entity)
    local newKeys = self:getEntityKeys(entity)
    self:remove(entity)
    for _, key in ipairs(newKeys) do
        if not self.cells[key] then
            self.cells[key] = {}
        end
        table.insert(self.cells[key], entity)
    end
    entity._spatialKeys = newKeys
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
