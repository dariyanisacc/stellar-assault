-- src/shop_manager.lua

local shop_manager = {}
shop_manager.__index = shop_manager

-- Sample shop items
shop_manager.items = {
  { name = "Health Upgrade", cost = 100, description = "Increases max health by 50" },
  { name = "Speed Boost", cost = 150, description = "Increases ship speed by 20%" },
  { name = "Weapon Upgrade", cost = 200, description = "Improves weapon damage by 30%" },
  -- Add more items as needed
}

-- Player's currency (example, should be linked to game state)
shop_manager.currency = 500 -- Starting currency, adjust as needed

-- Simple constructor to match expected OOP usage from LevelSelect state
function shop_manager:new()
  local inst = setmetatable({}, shop_manager)
  -- copy items so per-instance purchases don’t mutate the module table
  inst.items = {}
  for i, it in ipairs(self.items) do
    inst.items[i] = { name = it.name, cost = it.cost, description = it.description, purchased = false }
  end
  inst.selected = 1
  return inst
end

-- Initialize shop manager
function shop_manager.init()
  print("Shop Manager Initialized")
  -- Load shop data, perhaps from save file
end

-- Update shop logic
function shop_manager:update(dt)
  -- Any update logic, like animations in shop
end

-- Draw the shop UI
function shop_manager:draw(x, y, w, h, currentScore)
  local lg = love.graphics
  x, y = x or 20, y or 20
  w, h = w or 280, h or 320
  -- panel
  lg.setColor(0.05, 0.08, 0.10, 0.95)
  lg.rectangle("fill", x, y, w, h, 6, 6)
  lg.setColor(0.2, 0.4, 0.6, 1)
  lg.rectangle("line", x, y, w, h, 6, 6)

  -- header
  lg.setColor(1, 1, 1)
  local title = "SHOP"
  lg.print(title, x + 10, y + 8)
  local bal = string.format("Score: %d", currentScore or 0)
  local fw = lg.getFont():getWidth(bal)
  lg.print(bal, x + w - fw - 10, y + 8)

  -- items list
  local lineH = 26
  local iy = y + 36
  for i, item in ipairs(self.items) do
    local sel = (i == self.selected)
    if sel then
      lg.setColor(0.15, 0.25, 0.35, 0.8)
      lg.rectangle("fill", x + 6, iy - 4, w - 12, lineH)
    end
    if item.purchased then
      lg.setColor(0.6, 0.6, 0.6)
    else
      lg.setColor(0.85, 0.9, 1)
    end
    local label = string.format("%d. %s  (%d)", i, item.name, item.cost)
    lg.print(label, x + 12, iy)
    iy = iy + lineH + 4
  end
end

function shop_manager:moveSelection(dir)
  if dir == "up" then
    self.selected = (self.selected - 2) % #self.items + 1
  elseif dir == "down" then
    self.selected = self.selected % #self.items + 1
  end
end

-- Try to buy the item at index against provided score; returns (ok, newScore, msg)
function shop_manager:tryPurchase(index, currentScore)
  local item = self.items[index]
  if not item then return false, currentScore, "Invalid selection" end
  if item.purchased then return false, currentScore, "Already purchased" end
  local score = tonumber(currentScore or 0) or 0
  if score < (item.cost or 0) then
    return false, score, "Not enough score"
  end
  item.purchased = true
  score = score - (item.cost or 0)
  return true, score, ("Purchased: %s"):format(item.name)
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
