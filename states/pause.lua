-- Pause State for Stellar Assault
local lg = love.graphics

local PauseState = {}

function PauseState:enter()
    self.selection = 1 -- 1 = Resume, 2 = Options, 3 = Main Menu
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
end

function PauseState:update(dt)
    -- Update screen dimensions
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
end

function PauseState:draw()
    -- Draw the game state in background (dimmed)
    lg.setColor(0.3, 0.3, 0.3, 0.8)
    lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    
    -- Draw pause menu box
    local boxWidth = 400
    local boxHeight = 300
    local boxX = self.screenWidth/2 - boxWidth/2
    local boxY = self.screenHeight/2 - boxHeight/2
    
    -- Box background
    lg.setColor(0.1, 0.1, 0.2, 0.95)
    lg.rectangle("fill", boxX, boxY, boxWidth, boxHeight)
    
    -- Box border
    lg.setColor(0, 1, 1)
    lg.setLineWidth(2)
    lg.rectangle("line", boxX, boxY, boxWidth, boxHeight)
    lg.setLineWidth(1)
    
    -- Title
    lg.setFont(menuFont or lg.newFont(24))
    lg.setColor(1, 1, 1)
    local title = "PAUSED"
    local titleWidth = lg.getFont():getWidth(title)
    lg.print(title, self.screenWidth/2 - titleWidth/2, boxY + 40)
    
    -- Menu options
    local options = {"Resume", "Options", "Main Menu"}
    
    for i, option in ipairs(options) do
        if i == self.selection then
            lg.setColor(1, 1, 0)
        else
            lg.setColor(0.7, 0.7, 0.7)
        end
        
        local optionWidth = lg.getFont():getWidth(option)
        lg.print(option, self.screenWidth/2 - optionWidth/2, boxY + 100 + i * 40)
    end
    
    -- Instructions
    lg.setFont(smallFont or lg.newFont(14))
    lg.setColor(0.5, 0.5, 0.5)
    local nav = inputHints[lastInputType].navigate or "Arrow Keys"
    local select = inputHints[lastInputType].select or "Enter"
    local resume = inputHints[lastInputType].back or "ESC"
    local instructions = nav .. ": Navigate | " .. select .. ": Select | " .. resume .. ": Resume"
    local instructWidth = lg.getFont():getWidth(instructions)
    lg.print(instructions, self.screenWidth/2 - instructWidth/2, boxY + boxHeight - 40)
end

function PauseState:keypressed(key)
    if key == "up" then
        self.selection = self.selection - 1
        if self.selection < 1 then self.selection = 3 end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "down" then
        self.selection = self.selection + 1
        if self.selection > 3 then self.selection = 1 end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "return" or key == "space" then
        if menuConfirmSound then menuConfirmSound:play() end
        
        if self.selection == 1 then
            -- Resume
            gameState = "playing"
            stateManager:switch("playing", {resume = true})
        elseif self.selection == 2 then
            -- Options
            stateManager:switch("options")
        elseif self.selection == 3 then
            -- Main Menu
            gameState = "menu"
            if backgroundMusic then
                backgroundMusic:stop()
            end
            stateManager:switch("menu")
        end
    elseif key == "escape" then
        -- Quick resume
        gameState = "playing"
        stateManager:switch("playing", {resume = true})
    end
end

function PauseState:gamepadpressed(joystick, button)
    -- Handle start button directly for proper resume
    if button == "start" then
        -- Quick resume
        gameState = "playing"
        stateManager:switch("playing", {resume = true})
        return
    end
    
    -- Map other gamepad buttons to keyboard inputs
    local keyMap = {
        dpup = "up",
        dpdown = "down",
        a = "return",
        b = "escape"
    }
    
    local key = keyMap[button]
    if key then
        self:keypressed(key)
    end
end

function PauseState:onPress(action)
    self:keypressed(action)
end

function PauseState:onRelease(action)
    if self.keyreleased then
        self:keyreleased(action)
    end
end

return PauseState