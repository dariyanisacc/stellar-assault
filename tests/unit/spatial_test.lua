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
end)
