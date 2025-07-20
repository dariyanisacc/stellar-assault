local SpatialHash = require('src.spatial')

describe("SpatialHash", function()
    local function contains(t, v)
        for _, x in ipairs(t) do
            if x == v then return true end
        end
        return false
    end

    it("finds nearby entities in same cell", function()
        local grid = SpatialHash:new(50)
        local a = {x=10, y=10, size=10}
        local b = {x=20, y=20, size=10}
        grid:insert(a)
        grid:insert(b)
        local near = grid:getNearby(a)
        assert.is_true(contains(near, b))
    end)

    it("ignores distant entities", function()
        local grid = SpatialHash:new(50)
        local a = {x=10, y=10, size=10}
        local c = {x=120, y=120, size=10}
        grid:insert(a)
        grid:insert(c)
        local near = grid:getNearby(a)
        assert.is_false(contains(near, c))
    end)

    it("removes entities correctly", function()
        local grid = SpatialHash:new(50)
        local a = {x=10, y=10, size=10}
        local b = {x=20, y=20, size=10}
        grid:insert(a)
        grid:insert(b)
        grid:remove(b)
        local near = grid:getNearby(a)
        assert.is_false(contains(near, b))
    end)

    it("updates moved entities", function()
        local grid = SpatialHash:new(50)
        local a = {x=10, y=10, size=10}
        grid:insert(a)
        a.x, a.y = 120, 120
        grid:update(a)
        local nearOld = grid:getNearby({x=10, y=10, size=10})
        local nearNew = grid:getNearby({x=120, y=120, size=10})
        assert.is_false(contains(nearOld, a))
        assert.is_true(contains(nearNew, a))
    end)
end)
