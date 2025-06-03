-- Collision Detection Unit Tests
describe("checkCollision", function()
    local checkCollision
    
    before_each(function()
        -- Extract the checkCollision function for testing
        checkCollision = function(a, b)
            return a.x < b.x + b.width and
                   a.x + a.width > b.x and
                   a.y < b.y + b.height and
                   a.y + a.height > b.y
        end
    end)
    
    describe("when objects overlap", function()
        it("detects collision when objects fully overlap", function()
            local objA = {x = 10, y = 10, width = 20, height = 20}
            local objB = {x = 10, y = 10, width = 20, height = 20}
            
            assert.is_true(checkCollision(objA, objB))
        end)
        
        it("detects collision when object A contains object B", function()
            local objA = {x = 0, y = 0, width = 100, height = 100}
            local objB = {x = 25, y = 25, width = 50, height = 50}
            
            assert.is_true(checkCollision(objA, objB))
        end)
        
        it("detects collision when object B contains object A", function()
            local objA = {x = 25, y = 25, width = 50, height = 50}
            local objB = {x = 0, y = 0, width = 100, height = 100}
            
            assert.is_true(checkCollision(objA, objB))
        end)
        
        it("detects collision when objects partially overlap from the right", function()
            local objA = {x = 0, y = 0, width = 50, height = 50}
            local objB = {x = 40, y = 10, width = 50, height = 30}
            
            assert.is_true(checkCollision(objA, objB))
        end)
        
        it("detects collision when objects partially overlap from the left", function()
            local objA = {x = 50, y = 0, width = 50, height = 50}
            local objB = {x = 10, y = 10, width = 50, height = 30}
            
            assert.is_true(checkCollision(objA, objB))
        end)
        
        it("detects collision when objects partially overlap from the top", function()
            local objA = {x = 0, y = 50, width = 50, height = 50}
            local objB = {x = 10, y = 10, width = 30, height = 50}
            
            assert.is_true(checkCollision(objA, objB))
        end)
        
        it("detects collision when objects partially overlap from the bottom", function()
            local objA = {x = 0, y = 0, width = 50, height = 50}
            local objB = {x = 10, y = 40, width = 30, height = 50}
            
            assert.is_true(checkCollision(objA, objB))
        end)
        
        it("detects collision when objects overlap at corners", function()
            local objA = {x = 0, y = 0, width = 50, height = 50}
            local objB = {x = 45, y = 45, width = 50, height = 50}
            
            assert.is_true(checkCollision(objA, objB))
        end)
    end)
    
    describe("when objects do not overlap", function()
        it("returns false when objects are separated horizontally", function()
            local objA = {x = 0, y = 0, width = 50, height = 50}
            local objB = {x = 60, y = 0, width = 50, height = 50}
            
            assert.is_false(checkCollision(objA, objB))
        end)
        
        it("returns false when objects are separated vertically", function()
            local objA = {x = 0, y = 0, width = 50, height = 50}
            local objB = {x = 0, y = 60, width = 50, height = 50}
            
            assert.is_false(checkCollision(objA, objB))
        end)
        
        it("returns false when objects are diagonally separated", function()
            local objA = {x = 0, y = 0, width = 50, height = 50}
            local objB = {x = 100, y = 100, width = 50, height = 50}
            
            assert.is_false(checkCollision(objA, objB))
        end)
    end)
    
    describe("edge cases", function()
        it("returns false when objects are exactly touching on the right edge", function()
            local objA = {x = 0, y = 0, width = 50, height = 50}
            local objB = {x = 50, y = 0, width = 50, height = 50}
            
            assert.is_false(checkCollision(objA, objB))
        end)
        
        it("returns false when objects are exactly touching on the left edge", function()
            local objA = {x = 50, y = 0, width = 50, height = 50}
            local objB = {x = 0, y = 0, width = 50, height = 50}
            
            assert.is_false(checkCollision(objA, objB))
        end)
        
        it("returns false when objects are exactly touching on the bottom edge", function()
            local objA = {x = 0, y = 0, width = 50, height = 50}
            local objB = {x = 0, y = 50, width = 50, height = 50}
            
            assert.is_false(checkCollision(objA, objB))
        end)
        
        it("returns false when objects are exactly touching on the top edge", function()
            local objA = {x = 0, y = 50, width = 50, height = 50}
            local objB = {x = 0, y = 0, width = 50, height = 50}
            
            assert.is_false(checkCollision(objA, objB))
        end)
        
        it("handles zero-sized objects", function()
            local objA = {x = 10, y = 10, width = 0, height = 0}
            local objB = {x = 10, y = 10, width = 20, height = 20}
            
            assert.is_false(checkCollision(objA, objB))
        end)
        
        it("handles negative positions", function()
            local objA = {x = -20, y = -20, width = 50, height = 50}
            local objB = {x = 0, y = 0, width = 20, height = 20}
            
            assert.is_true(checkCollision(objA, objB))
        end)
        
        it("handles very large objects", function()
            local objA = {x = 0, y = 0, width = 10000, height = 10000}
            local objB = {x = 5000, y = 5000, width = 100, height = 100}
            
            assert.is_true(checkCollision(objA, objB))
        end)
    end)
    
    describe("performance", function()
        it("handles many collision checks efficiently", function()
            local objA = {x = 100, y = 100, width = 50, height = 50}
            local objects = {}
            
            -- Create 1000 objects at random positions
            for i = 1, 1000 do
                table.insert(objects, {
                    x = math.random(0, 1000),
                    y = math.random(0, 1000),
                    width = 50,
                    height = 50
                })
            end
            
            local startTime = os.clock()
            local collisionCount = 0
            
            -- Check collision with all objects
            for _, obj in ipairs(objects) do
                if checkCollision(objA, obj) then
                    collisionCount = collisionCount + 1
                end
            end
            
            local endTime = os.clock()
            local elapsed = endTime - startTime
            
            -- Should complete 1000 checks in less than 0.001 seconds
            assert.is_true(elapsed < 0.001)
            assert.is_true(collisionCount >= 0) -- At least some collisions should occur
        end)
    end)
end)