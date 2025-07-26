-- src/shop_manager.lua

local shop_manager = {}

-- Sample shop items
shop_manager.items = {
    {name = "Health Upgrade", cost = 100, description = "Increases max health by 50"},
    {name = "Speed Boost", cost = 150, description = "Increases ship speed by 20%"},
    {name = "Weapon Upgrade", cost = 200, description = "Improves weapon damage by 30%"},
    -- Add more items as needed
}

-- Player's currency (example, should be linked to game state)
shop_manager.currency = 500  -- Starting currency, adjust as needed

-- Initialize shop manager
function shop_manager.init()
    print("Shop Manager Initialized")
    -- Load shop data, perhaps from save file
end

-- Update shop logic
function shop_manager.update(dt)
    -- Any update logic, like animations in shop
end

-- Draw the shop UI
function shop_manager.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Shop - Currency: " .. shop_manager.currency, 10, 10, love.graphics.getWidth(), "left")
    
    local y = 50
    for i, item in ipairs(shop_manager.items) do
        love.graphics.printf(i .. ". " .. item.name .. " - Cost: " .. item.cost .. " - " .. item.description, 10, y, love.graphics.getWidth(), "left")
        y = y + 30
    end
end

-- Buy an item
function shop_manager.buyItem(index)
    local item = shop_manager.items[index]
    if item and shop_manager.currency >= item.cost then
        shop_manager.currency = shop_manager.currency - item.cost
        -- Apply upgrade logic here, e.g., increase player health, etc.
        print("Bought: " .. item.name)
        -- Remove item from shop or mark as bought if one-time
        table.remove(shop_manager.items, index)
        return true
    else
        print("Cannot buy item: Insufficient currency or invalid item")
        return false
    end
end

-- Handle key presses or mouse clicks for buying
function shop_manager.keypressed(key)
    -- Example: buy items with number keys
    local index = tonumber(key)
    if index and index > 0 and index <= #shop_manager.items then
        shop_manager.buyItem(index)
    end
end

return shop_manager