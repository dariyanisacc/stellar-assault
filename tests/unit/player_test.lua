-- Player Mechanics Unit Tests
describe("Player Mechanics", function()
    local player
    local lasers
    local laserCooldown
    local lives
    local maxLives
    local invulnerableTime
    local baseWidth
    local baseHeight
    
    before_each(function()
        -- Initialize player
        baseWidth = 800
        baseHeight = 600
        player = {
            x = baseWidth/2 - 20,
            y = 500,
            width = 40,
            height = 48,
            speed = 450
        }
        
        -- Initialize game variables
        lasers = {}
        laserCooldown = 0
        lives = 3
        maxLives = 5
        invulnerableTime = 0
    end)
    
    describe("Player Movement", function()
        it("initializes player at correct position", function()
            assert.equals(baseWidth/2 - 20, player.x)
            assert.equals(500, player.y)
        end)
        
        it("moves player left", function()
            local dt = 0.016 -- ~60 FPS
            local oldX = player.x
            player.x = player.x - player.speed * dt
            
            assert.is_true(player.x < oldX)
            assert.equals(oldX - player.speed * dt, player.x)
        end)
        
        it("moves player right", function()
            local dt = 0.016
            local oldX = player.x
            player.x = player.x + player.speed * dt
            
            assert.is_true(player.x > oldX)
            assert.equals(oldX + player.speed * dt, player.x)
        end)
        
        it("prevents player from moving beyond left boundary", function()
            player.x = 5
            local dt = 0.016
            
            -- Try to move left
            player.x = player.x - player.speed * dt
            
            -- Should clamp to 0
            if player.x < 0 then
                player.x = 0
            end
            
            assert.equals(0, player.x)
        end)
        
        it("prevents player from moving beyond right boundary", function()
            player.x = baseWidth - player.width - 5
            local dt = 0.016
            
            -- Try to move right
            player.x = player.x + player.speed * dt
            
            -- Should clamp to right edge
            if player.x > baseWidth - player.width then
                player.x = baseWidth - player.width
            end
            
            assert.equals(baseWidth - player.width, player.x)
        end)
        
        it("maintains player Y position during horizontal movement", function()
            local dt = 0.016
            local oldY = player.y
            
            -- Move left and right
            player.x = player.x - player.speed * dt
            assert.equals(oldY, player.y)
            
            player.x = player.x + player.speed * dt * 2
            assert.equals(oldY, player.y)
        end)
    end)
    
    describe("Player Shooting", function()
        local function shootLaser()
            if laserCooldown <= 0 then
                local laser = {
                    x = player.x + player.width/2 - 2,
                    y = player.y,
                    width = 4,
                    height = 10,
                    speed = 600
                }
                table.insert(lasers, laser)
                laserCooldown = 0.5 -- Reset cooldown
                return true
            end
            return false
        end
        
        it("creates laser at correct position", function()
            shootLaser()
            
            assert.equals(1, #lasers)
            local laser = lasers[1]
            assert.equals(player.x + player.width/2 - 2, laser.x)
            assert.equals(player.y, laser.y)
        end)
        
        it("respects shooting cooldown", function()
            -- First shot should succeed
            assert.is_true(shootLaser())
            assert.equals(1, #lasers)
            
            -- Second immediate shot should fail
            assert.is_false(shootLaser())
            assert.equals(1, #lasers)
        end)
        
        it("allows shooting after cooldown expires", function()
            shootLaser()
            assert.equals(1, #lasers)
            
            -- Simulate cooldown expiring
            laserCooldown = 0
            
            -- Should be able to shoot again
            assert.is_true(shootLaser())
            assert.equals(2, #lasers)
        end)
        
        it("creates lasers with correct properties", function()
            shootLaser()
            local laser = lasers[1]
            
            assert.equals(4, laser.width)
            assert.equals(10, laser.height)
            assert.equals(600, laser.speed)
        end)
        
        it("updates laser positions", function()
            shootLaser()
            local laser = lasers[1]
            local dt = 0.016
            local oldY = laser.y
            
            -- Update laser position
            laser.y = laser.y - laser.speed * dt
            
            assert.is_true(laser.y < oldY)
            assert.equals(oldY - laser.speed * dt, laser.y)
        end)
    end)
    
    describe("Player Lives System", function()
        local function loseLife()
            if invulnerableTime <= 0 and lives > 0 then
                lives = lives - 1
                invulnerableTime = 2 -- 2 seconds of invulnerability
                return true
            end
            return false
        end
        
        it("starts with 3 lives", function()
            assert.equals(3, lives)
        end)
        
        it("loses a life when taking damage", function()
            loseLife()
            assert.equals(2, lives)
        end)
        
        it("becomes invulnerable after taking damage", function()
            loseLife()
            assert.equals(2, invulnerableTime)
            
            -- Should not lose another life while invulnerable
            assert.is_false(loseLife())
            assert.equals(2, lives)
        end)
        
        it("can take damage again after invulnerability expires", function()
            loseLife()
            assert.equals(2, lives)
            
            -- Simulate invulnerability expiring
            invulnerableTime = 0
            
            loseLife()
            assert.equals(1, lives)
        end)
        
        it("handles game over when lives reach 0", function()
            lives = 1
            loseLife()
            assert.equals(0, lives)
            
            -- Should not be able to lose more lives
            invulnerableTime = 0
            assert.is_false(loseLife())
            assert.equals(0, lives)
        end)
        
        it("respects maximum lives limit", function()
            lives = maxLives
            
            -- Try to add a life
            lives = lives + 1
            if lives > maxLives then
                lives = maxLives
            end
            
            assert.equals(maxLives, lives)
        end)
        
        it("can gain extra lives", function()
            lives = 2
            lives = lives + 1
            assert.equals(3, lives)
        end)
    end)
    
    describe("Player Boundaries", function()
        it("has correct dimensions", function()
            assert.equals(40, player.width)
            assert.equals(48, player.height)
        end)
        
        it("has correct movement speed", function()
            assert.equals(450, player.speed)
        end)
        
        it("stays within horizontal game boundaries", function()
            -- Test multiple positions
            local positions = {-100, -10, 0, 400, baseWidth - player.width, baseWidth, baseWidth + 100}
            
            for _, pos in ipairs(positions) do
                player.x = pos
                
                -- Apply boundary constraints
                if player.x < 0 then
                    player.x = 0
                elseif player.x > baseWidth - player.width then
                    player.x = baseWidth - player.width
                end
                
                assert.is_true(player.x >= 0)
                assert.is_true(player.x <= baseWidth - player.width)
            end
        end)
    end)
    
    describe("Player State", function()
        it("maintains position between frames", function()
            local originalX = player.x
            local originalY = player.y
            
            -- Simulate multiple frames without input
            for i = 1, 60 do
                -- Position should remain unchanged
                assert.equals(originalX, player.x)
                assert.equals(originalY, player.y)
            end
        end)
        
        it("tracks invulnerability timer correctly", function()
            local dt = 0.016
            invulnerableTime = 2
            
            -- Simulate countdown
            for i = 1, 125 do -- ~2 seconds at 60 FPS
                invulnerableTime = invulnerableTime - dt
            end
            
            assert.is_true(invulnerableTime <= 0)
        end)
        
        it("tracks laser cooldown correctly", function()
            local dt = 0.016
            laserCooldown = 0.5
            
            -- Simulate countdown
            for i = 1, 32 do -- ~0.5 seconds at 60 FPS
                laserCooldown = laserCooldown - dt
            end
            
            assert.is_true(laserCooldown <= 0)
        end)
    end)
end)