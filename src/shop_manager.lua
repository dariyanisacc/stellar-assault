-- src/shop_manager.lua
-- Shop system for Stellar Assault
-- Allows buying upgrades with score points in level select

local constants = require("src.constants")
local Persistence = require("src.persistence")
local logger = require("src.logger")

local ShopManager = {}
ShopManager.__index = ShopManager

function ShopManager:new()
    local self = setmetatable({}, ShopManager)
    self.items = {
        {
            name = "Shield Upgrade", 
            cost = 1000, 
            desc = "+1 Max Shield", 
            key = "maxShield", 
            value = 1,
            type = "incremental"
        },
        {
            name = "Speed Boost", 
            cost = 1500, 
            desc = "+10% Speed", 
            key = "speedMultiplier", 
            value = 0.1,
            type = "incremental"
        },
        {
            name = "Fire Rate Upgrade", 
            cost = 2000, 
            desc = "-10% Fire Cooldown", 
            key = "fireRateMultiplier", 
            value = 0.1,
            type = "incremental"
        },
        {
            name = "Extra Life", 
            cost = 3000, 
            desc = "+1 Starting Life", 
            key = "extraLives", 
            value = 1,
            type = "incremental"
        },
        {
            name = "Bomb Capacity", 
            cost = 2500, 
            desc = "+1 Bomb Capacity", 
            key = "bombCapacity", 
            value = 1,
            type = "incremental"
        },
        {
            name = "Unlock Beta Ship", 
            cost = 5000, 
            desc = "Unlock Beta Ship (High Speed)", 
            key = "unlockBeta", 
            value = true, 
            once = true,
            type = "unlock"
        },
        {
            name = "Unlock Gamma Ship", 
            cost = 8000, 
            desc = "Unlock Gamma Ship (Heavy Shield)", 
            key = "unlockGamma", 
            value = true, 
            once = true,
            type = "unlock"
        }
    }
    self.selected = 1
    return self
end

function ShopManager:update(dt)
    -- Future: Add animations or effects
end

function ShopManager:draw(x, y, width, height, currentScore)
    local lg = love.graphics
    
    -- Shop background
    lg.setColor(0.1, 0.1, 0.2, 0.95)
    lg.rectangle("fill", x, y, width, height)
    lg.setColor(0.3, 0.3, 0.4, 1)
    lg.rectangle("line", x, y, width, height)
    
    -- Title and score
    lg.setColor(1, 1, 1)
    lg.setFont(menuFont or lg.newFont(24))
    lg.printf("UPGRADE SHOP", x, y + 10, width, "center")
    
    lg.setFont(uiFont or lg.newFont(18))
    lg.setColor(1, 1, 0)
    lg.printf("Score: " .. (currentScore or 0), x, y + 40, width, "center")
    
    -- Shop items
    local itemY = y + 80
    lg.setFont(smallFont or lg.newFont(14))
    
    for i, item in ipairs(self.items) do
        local canAfford = currentScore >= item.cost
        local isPurchased = item.once and Persistence.getUpgrade(item.key)
        
        -- Background for selected item
        if i == self.selected then
            lg.setColor(0.2, 0.2, 0.3, 0.5)
            lg.rectangle("fill", x + 5, itemY - 5, width - 10, 45)
        end
        
        -- Item color based on state
        if isPurchased then
            lg.setColor(0.4, 0.4, 0.4)
        elseif i == self.selected then
            if canAfford then
                lg.setColor(0, 1, 0)
            else
                lg.setColor(1, 0.5, 0)
            end
        elseif canAfford then
            lg.setColor(0.8, 0.8, 0.8)
        else
            lg.setColor(0.5, 0.5, 0.5)
        end
        
        -- Item name and cost
        local costText = isPurchased and "[OWNED]" or ("$" .. item.cost)
        lg.print(item.name, x + 10, itemY)
        lg.printf(costText, x + 10, itemY, width - 20, "right")
        
        -- Item description
        lg.setColor(0.6, 0.6, 0.7)
        lg.print(item.desc, x + 10, itemY + 18)
        
        -- Show current level for incremental upgrades
        if item.type == "incremental" and not isPurchased then
            local currentLevel = Persistence.getUpgradeLevel(item.key) or 0
            if currentLevel > 0 then
                lg.setColor(0.5, 0.7, 1)
                lg.print("(Level " .. currentLevel .. ")", x + 10 + lg.getFont():getWidth(item.desc) + 10, itemY + 18)
            end
        end
        
        itemY = itemY + 50
    end
    
    -- Instructions
    lg.setColor(0.7, 0.7, 0.7)
    lg.printf("UP/DOWN: Navigate  ENTER: Purchase  ESC: Exit", x, y + height - 30, width, "center")
end

function ShopManager:tryPurchase(itemIndex, currentScore)
    local item = self.items[itemIndex]
    if not item then return false, currentScore end
    
    if item.cost > currentScore then
        logger.info("Not enough score for " .. item.name)
        return false, currentScore, "Not enough score!"
    end
    
    if item.once and Persistence.getUpgrade(item.key) then
        logger.info(item.name .. " already purchased")
        return false, currentScore, "Already owned!"
    end
    
    -- Apply upgrade via Persistence
    Persistence.applyUpgrade(item.key, item.value, item.type)
    
    -- Deduct cost
    local newScore = currentScore - item.cost
    
    logger.info("Purchased " .. item.name .. " for " .. item.cost)
    return true, newScore, "Purchased " .. item.name .. "!"
end

function ShopManager:moveSelection(direction)
    if direction == "up" then
        self.selected = math.max(1, self.selected - 1)
        if menuSelectSound then
            menuSelectSound:stop()
            menuSelectSound:play()
        end
    elseif direction == "down" then
        self.selected = math.min(#self.items, self.selected + 1)
        if menuSelectSound then
            menuSelectSound:stop()
            menuSelectSound:play()
        end
    end
end

function ShopManager:getSelectedItem()
    return self.items[self.selected]
end

return ShopManager