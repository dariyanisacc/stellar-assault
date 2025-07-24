-- menu.lua
-- Main menu state for Stellar Assault

local Menu = {}

function Menu:enter()
    -- Initialize menu (e.g., load assets, reset variables)
    print("Entered Menu State")  -- For debugging in terminal
    self.options = {"Start Game", "Options", "Quit"}
    self.selected = 1
end

function Menu:exit()
    -- Cleanup on exit
    print("Exiting Menu State")
end

function Menu:update(dt)
    -- Update logic (e.g., animations)
end

function Menu:draw()
    -- Draw the menu
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Stellar Assault - Main Menu", 100, 100)
    for i, option in ipairs(self.options) do
        if i == self.selected then
            love.graphics.setColor(1, 0, 0)  -- Highlight selected
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.print(option, 100, 150 + (i * 50))
    end
end

function Menu:keypressed(key)
    -- Handle input
    if key == "down" then
        self.selected = self.selected + 1
        if self.selected > #self.options then self.selected = 1 end
    elseif key == "up" then
        self.selected = self.selected - 1
        if self.selected < 1 then self.selected = #self.options end
    elseif key == "return" then
        if self.selected == 1 then
            -- Switch to gameplay state
            GameStateManager:switch("gameplay")  -- Assuming global GameStateManager
        elseif self.selected == 3 then
            love.event.quit()
        end
    end
end

return Menu