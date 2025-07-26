-- UI Manager for Stellar Assault
local constants = require("src.constants")
local lg = love.graphics
local Game = require("src.game")

local function setColorContrast(normal, contrast)
    local c = normal
    if Game.highContrast and contrast then
        c = contrast
    elseif not Game.highContrast then
        c = normal
    end
    lg.setColor(c[1], c[2], c[3], c[4] or 1)
end

local UIManager = {}
UIManager.__index = UIManager

function UIManager:new()
    local self = setmetatable({}, UIManager)
    self.margin = constants.ui.margin
    self.elements = {}
    return self
end

-- Core UI Elements
function UIManager:drawScore(x, y, score)
    x = x or self.margin
    y = y or self.margin
    
    setColorContrast({0, 1, 1}, {1, 1, 1})
    lg.setFont(Game.uiFont or lg.newFont(18))
    lg.print("Score: " .. (score or 0), x, y)
end

function UIManager:drawLives(x, y, lives)
    x = x or self.margin
    y = y or self.margin + 25
    
    setColorContrast({0, 1, 1}, {1, 1, 1})
    lg.setFont(Game.uiFont or lg.newFont(18))
    lg.print("Lives: " .. (lives or 0), x, y)
end

function UIManager:drawLevel(x, y, level)
    x = x or self.margin
    y = y or self.margin + 50
    
    setColorContrast({0, 1, 1}, {1, 1, 1})
    lg.setFont(Game.uiFont or lg.newFont(18))
    lg.print("Level: " .. (level or 1), x, y)
end

function UIManager:drawHealthBar(x, y, current, max, width, height, label)
    x = x or self.margin
    y = y or self.margin + 75
    width = width or constants.ui.healthBarWidth
    height = height or constants.ui.healthBarHeight
    
    -- Background
    lg.setColor(0.3, 0.3, 0.3)
    lg.rectangle("fill", x, y, width, height)
    
    -- Fill
    if current > 0 then
        local fillWidth = (current / max) * width
        setColorContrast({0, 1, 1}, {1, 0, 0})
        lg.rectangle("fill", x, y, fillWidth, height)
    end
    
    -- Border
    setColorContrast({1, 1, 1}, {1, 1, 1})
    lg.rectangle("line", x, y, width, height)
    
    -- Label
    if label then
        lg.setFont(Game.smallFont or lg.newFont(14))
        setColorContrast({0, 1, 1}, {1, 1, 1})
        lg.print(label, x + 2, y - 16)
    end
end

function UIManager:drawPowerupBar(x, y, width, current, max, color)
    width = width or constants.ui.powerupBarWidth
    height = constants.ui.powerupBarHeight
    
    -- Background
    lg.setColor(0.2, 0.2, 0.2, Game.highContrast and 1 or 0.8)
    lg.rectangle("fill", x, y, width, height)
    
    -- Fill
    if current > 0 then
        local fillWidth = (current / max) * width
        setColorContrast({color[1], color[2], color[3], 0.8}, {1, 1, 1, 0.8})
        lg.rectangle("fill", x, y, fillWidth, height)
    end
    
    -- Border
    setColorContrast({color[1], color[2], color[3], 1}, {1, 1, 1, 1})
    lg.rectangle("line", x, y, width, height)
end

function UIManager:drawActivePowerups(x, y, powerups)
    x = x or self.margin
    y = y or self.margin + 110
    
    lg.setFont(Game.smallFont or lg.newFont(14))
    
    local colors = {
        shield = {0, 1, 1},
        rapidFire = {1, 1, 0},
        multiShot = {1, 0.5, 0},
        timeWarp = {0.5, 0, 1},
        magnetField = {0, 1, 0},
        vampire = {0.8, 0.2, 0.8},
        freeze = {0.5, 0.5, 1}
    }
    
    local drawY = y
    for powerup, timer in pairs(powerups or {}) do
        local color = colors[powerup] or {1, 1, 1}
        setColorContrast(color, {1, 1, 1})
        
        -- Draw text
        local text = powerup .. ": " .. string.format("%.1f", timer) .. "s"
        lg.print(text, x, drawY)
        
        -- Draw timer bar
        self:drawPowerupBar(x + 120, drawY + 2, 60, timer, 
                           constants.powerup.duration[powerup] or 10, color)
        
        drawY = drawY + 20
    end
end

function UIManager:drawBossHealth(boss)
    if not boss then return end
    
    local barWidth = 400
    local barHeight = 20
    local x = lg.getWidth() / 2 - barWidth / 2
    local y = 50
    
    -- Boss name
    lg.setFont(Game.menuFont or lg.newFont(24))
    setColorContrast({1, 0, 0}, {1, 1, 1})
    local name = boss.name or "BOSS"
    local nameWidth = lg.getFont():getWidth(name)
    lg.print(name, lg.getWidth() / 2 - nameWidth / 2, y - 30)
    
    -- Health bar
    self:drawHealthBar(x, y, boss.health, boss.maxHealth, barWidth, barHeight)
    
    -- Shield bar if applicable
    if boss.shield and boss.maxShield and boss.shield > 0 then
        setColorContrast({0, 0.5, 1}, {1, 1, 1})
        local shieldHeight = 5
        lg.rectangle("fill", x, y - shieldHeight - 2, 
                    (boss.shield / boss.maxShield) * barWidth, shieldHeight)
    end
end

function UIManager:drawMessage(text, x, y, color, font)
    x = x or lg.getWidth() / 2
    y = y or lg.getHeight() / 2
    color = color or {1, 1, 1}
    font = font or Game.titleFont or lg.newFont(48)
    
    lg.setFont(font)
    setColorContrast(color, {1, 1, 1})
    
    local width = lg.getFont():getWidth(text)
    lg.print(text, x - width / 2, y)
end

function UIManager:drawMessages(messages)
    local y = lg.getHeight() / 2 - (#messages * 30)
    
    for _, msg in ipairs(messages) do
        self:drawMessage(msg.text, nil, y, msg.color, msg.font)
        y = y + 60
    end
end

-- Combo/multiplier display
function UIManager:drawCombo(combo, x, y)
    if not combo or combo <= 1 then return end
    
    x = x or lg.getWidth() - 150
    y = y or 100
    
    lg.setFont(Game.menuFont or lg.newFont(24))
    
    -- Pulse effect based on combo
    local pulse = math.sin(love.timer.getTime() * 5) * 0.2 + 0.8
    local color = {1, 1 * pulse, 0}
    
    if combo >= 10 then
        color = {1, 0, 0} -- Red for high combos
    elseif combo >= 5 then
        color = {1, 0.5, 0} -- Orange for medium combos
    end
    
    setColorContrast(color, {1, 1, 1})
    lg.print("x" .. combo, x, y)
end

-- Warning indicators
function UIManager:drawWarning(text, severity)
    severity = severity or "normal"
    
    local colors = {
        normal = {1, 1, 0},
        critical = {1, 0, 0},
        info = {0, 1, 1}
    }
    
    local color = colors[severity] or colors.normal
    local pulse = math.sin(love.timer.getTime() * 10) * 0.5 + 0.5
    
    lg.setFont(Game.menuFont or lg.newFont(24))
    local c = Game.highContrast and {1, 1, 1, pulse} or {color[1], color[2], color[3], pulse}
    lg.setColor(c)
    
    local width = lg.getFont():getWidth(text)
    lg.print(text, lg.getWidth() / 2 - width / 2, 150)
end

-- Mini-map (for larger levels)
function UIManager:drawMinimap(x, y, width, height, entities, viewRange)
    x = x or lg.getWidth() - width - self.margin
    y = y or self.margin
    width = width or 150
    height = height or 150
    viewRange = viewRange or 2000
    
    -- Background
    lg.setColor(0, 0, 0, Game.highContrast and 0.8 or 0.5)
    lg.rectangle("fill", x, y, width, height)
    
    -- Border
    setColorContrast({0, 1, 1, 0.5}, {1, 1, 1, 0.5})
    lg.rectangle("line", x, y, width, height)
    
    -- Draw entities
    local scale = width / viewRange
    local centerX = x + width / 2
    local centerY = y + height / 2
    
    -- Player
    if player then
        setColorContrast({0, 1, 0}, {1, 1, 1})
        lg.circle("fill", centerX, centerY, 3)
    end
    
    -- Enemies
    setColorContrast({1, 0, 0, 0.8}, {1, 1, 1, 0.8})
    for _, entity in ipairs(entities or {}) do
        local relX = (entity.x - player.x) * scale
        local relY = (entity.y - player.y) * scale
        
        if math.abs(relX) < width/2 and math.abs(relY) < height/2 then
            lg.circle("fill", centerX + relX, centerY + relY, 2)
        end
    end
end

return UIManager