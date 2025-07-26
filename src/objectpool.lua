-- src/objectpool.lua
-- Object Pool module for efficient object reuse in the game, e.g., for trails and debris.

local ObjectPool = {}

function ObjectPool.new(createFunction, resetFunction, initialSize)
    local self = {}
    self.pool = {}
    self.create = createFunction
    self.reset = resetFunction or function(obj) end
    self.active = {}

    -- Prepopulate the pool if initialSize is provided
    if initialSize then
        for i = 1, initialSize do
            table.insert(self.pool, self.create())
        end
    end

    function self:get()
        local obj
        if #self.pool > 0 then
            obj = table.remove(self.pool)
        else
            obj = self.create()
        end
        self.reset(obj)
        table.insert(self.active, obj)
        return obj
    end

    function self:recycle(obj)
        for i, activeObj in ipairs(self.active) do
            if activeObj == obj then
                table.remove(self.active, i)
                break
            end
        end
        table.insert(self.pool, obj)
    end

    self.release = self.recycle

    function self:releaseAll()
        for i = #self.active, 1, -1 do
            table.insert(self.pool, table.remove(self.active, i))
        end
    end

    function self:getActiveCount()
        return #self.active
    end

    function self:update(dt)
        -- Optionally update active objects if needed
        for _, obj in ipairs(self.active) do
            if obj.update then
                obj:update(dt)
            end
        end
    end

    function self:draw()
        -- Optionally draw active objects if needed
        for _, obj in ipairs(self.active) do
            if obj.draw then
                obj:draw()
            end
        end
    end

    return self
end

local function clearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

function ObjectPool.createLaserPool(size)
    local constants = require("src.constants")
    local function create()
        return {width = constants.laser.width, height = constants.laser.height}
    end
    local function reset(obj)
        clearTable(obj)
        obj.width = constants.laser.width
        obj.height = constants.laser.height
    end
    return ObjectPool.new(create, reset, size or 100)
end

function ObjectPool.createExplosionPool(size)
    local function create() return {} end
    local function reset(obj) clearTable(obj) end
    return ObjectPool.new(create, reset, size or 50)
end

function ObjectPool.createParticlePool(size)
    local function create() return {} end
    local function reset(obj) clearTable(obj) end
    return ObjectPool.new(create, reset, size or 200)
end

function ObjectPool.createTrailPool(size)
    local function create() return {} end
    local function reset(obj) clearTable(obj) end
    return ObjectPool.new(create, reset, size or 100)
end

function ObjectPool.createDebrisPool(size)
    local function create() return {} end
    local function reset(obj) clearTable(obj) end
    return ObjectPool.new(create, reset, size or 100)
end

return ObjectPool