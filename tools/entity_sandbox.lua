#!/usr/bin/env love .

-- Entity Sandbox - Test entities in isolation
-- Usage: love . tools/entity_sandbox.lua [entity_name]

local lg = love.graphics
local lk = love.keyboard

-- Sandbox state
local sandbox = {
    entity = nil,
    entityType = nil,
    camera = {x = 0, y = 0},
    paused = false,
    showInfo = true,
    deltaTime = 0,
    totalTime = 0,
    frameCount = 0,
    avgDelta = 0,
    bulletManager = nil,
    particles = nil
}

-- Mock bullet manager for testing
local MockBulletManager = {}
MockBulletManager.__index = MockBulletManager

function MockBulletManager:new()
    local self = setmetatable({}, MockBulletManager)
    self.bullets = {}
    return self
end

function MockBulletManager:spawn(x, y, angle, speed)
    table.insert(self.bullets, {
        x = x,
        y = y,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        radius = 4,
        lifetime = 5
    })
end

function MockBulletManager:update(dt)
    for i = #self.bullets, 1, -1 do
        local b = self.bullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.lifetime = b.lifetime - dt
        
        if b.lifetime <= 0 then
            table.remove(self.bullets, i)
        end
    end
end

function MockBulletManager:draw()
    lg.setColor(1, 1, 0, 1)
    for _, b in ipairs(self.bullets) do
        lg.circle("fill", b.x, b.y, b.radius)
    end
    lg.setColor(1, 1, 1, 1)
end

-- Load entity
function loadEntity(entityName)
    local success, result
    
    -- Try to load from entities folder
    success, result = pcall(require, "src.entities." .. entityName)
    if success then
        sandbox.entityType = entityName
        
        -- Create entity based on type
        if entityName == "boss" or entityName == "boss02" then
            sandbox.entity = result.new(5) -- Level 5 boss
        elseif entityName == "powerup" then
            local Powerup = result
            sandbox.entity = Powerup.new(lg.getWidth()/2, 100, Powerup.getRandomType())
        else
            -- Generic entity creation
            sandbox.entity = result.new(lg.getWidth()/2, lg.getHeight()/2)
        end
        
        return true
    end
    
    -- Try custom entity file
    success, result = pcall(dofile, entityName .. ".lua")
    if success and type(result) == "table" and result.new then
        sandbox.entityType = entityName
        sandbox.entity = result.new(lg.getWidth()/2, lg.getHeight()/2)
        return true
    end
    
    return false
end

function love.load(arg)
    lg.setBackgroundColor(0.1, 0.1, 0.2)
    
    -- Initialize mock systems
    sandbox.bulletManager = MockBulletManager:new()
    
    -- Mock globals that entities might expect
    _G.player = {x = lg.getWidth()/2, y = lg.getHeight() - 100}
    _G.bossSprite = nil  -- Will use fallback drawing
    _G.boss2Sprite = nil
    
    -- Load fonts
    _G.titleFont = lg.newFont(32)
    _G.menuFont = lg.newFont(24)
    _G.uiFont = lg.newFont(18)
    _G.smallFont = lg.newFont(14)
    
    -- Parse command line arguments
    local entityName = arg[2] or "boss"
    
    if not loadEntity(entityName) then
        print("Failed to load entity: " .. entityName)
        print("Usage: love . tools/entity_sandbox.lua [entity_name]")
        print("Available entities: boss, boss02, powerup")
        love.event.quit()
    end
    
    print("Entity Sandbox loaded: " .. entityName)
    print("Controls:")
    print("  Space: Pause/Resume")
    print("  R: Reset entity")
    print("  I: Toggle info display")
    print("  Arrow keys: Move camera")
    print("  1-9: Set time scale")
    print("  0: Reset time scale")
end

function love.update(dt)
    -- Update timing info
    sandbox.deltaTime = dt
    sandbox.totalTime = sandbox.totalTime + dt
    sandbox.frameCount = sandbox.frameCount + 1
    sandbox.avgDelta = sandbox.totalTime / sandbox.frameCount
    
    if not sandbox.paused and sandbox.entity then
        -- Apply time scale
        local scaledDt = dt * (sandbox.timeScale or 1.0)
        
        -- Update entity
        if sandbox.entity.update then
            sandbox.entity:update(scaledDt, sandbox.bulletManager)
        end
        
        -- Update bullets
        sandbox.bulletManager:update(scaledDt)
    end
    
    -- Camera controls
    local camSpeed = 200 * dt
    if lk.isDown("left") then sandbox.camera.x = sandbox.camera.x + camSpeed end
    if lk.isDown("right") then sandbox.camera.x = sandbox.camera.x - camSpeed end
    if lk.isDown("up") then sandbox.camera.y = sandbox.camera.y + camSpeed end
    if lk.isDown("down") then sandbox.camera.y = sandbox.camera.y - camSpeed end
end

function love.draw()
    -- Apply camera
    lg.push()
    lg.translate(sandbox.camera.x, sandbox.camera.y)
    
    -- Draw grid
    lg.setColor(0.2, 0.2, 0.3, 0.5)
    local gridSize = 50
    for x = -1000, 1000, gridSize do
        lg.line(x, -1000, x, 1000)
    end
    for y = -1000, 1000, gridSize do
        lg.line(-1000, y, 1000, y)
    end
    
    -- Draw origin
    lg.setColor(1, 0, 0, 0.5)
    lg.line(0, -20, 0, 20)
    lg.setColor(0, 1, 0, 0.5)
    lg.line(-20, 0, 20, 0)
    
    -- Draw mock player
    lg.setColor(0, 1, 1, 0.5)
    lg.rectangle("fill", _G.player.x - 15, _G.player.y - 15, 30, 30)
    
    -- Draw entity
    lg.setColor(1, 1, 1, 1)
    if sandbox.entity and sandbox.entity.draw then
        sandbox.entity:draw()
    end
    
    -- Draw bullets
    sandbox.bulletManager:draw()
    
    lg.pop()
    
    -- Draw info overlay
    if sandbox.showInfo then
        drawInfo()
    end
    
    -- Paused indicator
    if sandbox.paused then
        lg.setFont(_G.titleFont)
        lg.setColor(1, 1, 0, 1)
        lg.printf("PAUSED", 0, lg.getHeight()/2 - 20, lg.getWidth(), "center")
    end
end

function drawInfo()
    lg.setFont(_G.smallFont)
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 10, 10, 300, 250)
    
    lg.setColor(1, 1, 1, 1)
    local y = 20
    local lineHeight = 16
    
    lg.print("Entity: " .. (sandbox.entityType or "none"), 20, y)
    y = y + lineHeight
    
    if sandbox.entity then
        lg.print("Position: " .. math.floor(sandbox.entity.x) .. ", " .. math.floor(sandbox.entity.y), 20, y)
        y = y + lineHeight
        
        if sandbox.entity.hp then
            lg.print("HP: " .. sandbox.entity.hp .. "/" .. (sandbox.entity.maxHP or "?"), 20, y)
            y = y + lineHeight
        end
        
        if sandbox.entity.currentPhase then
            lg.print("Phase: " .. sandbox.entity.currentPhase, 20, y)
            y = y + lineHeight
        end
        
        if sandbox.entity.state then
            lg.print("State: " .. sandbox.entity.state, 20, y)
            y = y + lineHeight
        end
    end
    
    y = y + lineHeight
    lg.print("FPS: " .. love.timer.getFPS(), 20, y)
    y = y + lineHeight
    lg.print("Delta: " .. string.format("%.3f ms", sandbox.deltaTime * 1000), 20, y)
    y = y + lineHeight
    lg.print("Avg Delta: " .. string.format("%.3f ms", sandbox.avgDelta * 1000), 20, y)
    y = y + lineHeight
    lg.print("Time Scale: " .. (sandbox.timeScale or 1.0) .. "x", 20, y)
    y = y + lineHeight
    lg.print("Bullets: " .. #sandbox.bulletManager.bullets, 20, y)
    
    y = y + lineHeight * 2
    lg.setColor(0.7, 0.7, 0.7, 1)
    lg.print("Controls:", 20, y)
    y = y + lineHeight
    lg.print("Space: Pause | R: Reset | I: Info", 20, y)
    y = y + lineHeight
    lg.print("Arrows: Camera | 1-9: Time Scale", 20, y)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        sandbox.paused = not sandbox.paused
    elseif key == "r" then
        -- Reset entity
        loadEntity(sandbox.entityType)
        sandbox.bulletManager.bullets = {}
    elseif key == "i" then
        sandbox.showInfo = not sandbox.showInfo
    elseif tonumber(key) and tonumber(key) >= 1 and tonumber(key) <= 9 then
        sandbox.timeScale = tonumber(key)
    elseif key == "0" then
        sandbox.timeScale = 1.0
    end
end

-- Allow running as standalone script
if arg and arg[1] and arg[1]:match("entity_sandbox%.lua$") then
    -- Running directly
else
    -- Being required as a module
    return {
        loadEntity = loadEntity,
        sandbox = sandbox
    }
end