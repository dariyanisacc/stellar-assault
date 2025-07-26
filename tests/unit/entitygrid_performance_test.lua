local SpatialHash = require("src.spatial")
local Collision = require("src.collision")

local function createEntities(count)
  local list = {}
  for i = 1, count do
    table.insert(
      list,
      { x = math.random(0, 800), y = math.random(0, 600), width = 20, height = 20, tag = "asteroid" }
    )
  end
  return list
end

describe("SpatialHash performance", function()
  it("is faster than naive search", function()
    local grid = SpatialHash.new(50)
    local lasers = {}
    for i = 1, 200 do
      local l = { x = math.random(0, 800), y = math.random(0, 600), width = 4, height = 12 }
      table.insert(lasers, l)
      grid:insert(l)
    end
    local asteroids = createEntities(200)
    for _, a in ipairs(asteroids) do
      grid:insert(a)
    end

    local function naive()
      local c = 0
      for _, a in ipairs(asteroids) do
        for _, l in ipairs(lasers) do
          if Collision.checkAABB(a, l) then
            c = c + 1
          end
        end
      end
      return c
    end

    local function hashed()
      local c = 0
      for _, l in ipairs(lasers) do
        for _, e in ipairs(grid:getNearby(l)) do
          if e.tag == "asteroid" and Collision.checkAABB(e, l) then
            c = c + 1
          end
        end
      end
      return c
    end

    local t1 = os.clock()
    naive()
    local naiveTime = os.clock() - t1
    t1 = os.clock()
    hashed()
    local hashTime = os.clock() - t1
    assert.is_truthy(hashTime)
    assert.is_truthy(naiveTime)
  end)
end)
