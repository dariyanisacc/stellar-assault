-- Menu State for Stellar Assault
local constants = require("src.constants")
local lg = love.graphics
local la = love.audio

local MenuState = {}

function MenuState:enter()
    self.selection = 1
    self.menuState = "main"
    self.selectedSaveSlot = 1
    self.selectedLevel = 1
    self.saveSlots = self:loadSaves()
    self.levelSelectSource = "main"  -- Track where we came from
    
    -- Cache globals
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
    
    -- Analog stick state
    self.analogStates = { up = false, down = false, left = false, right = false }
    self.analogRepeatTimers = { up = 0, down = 0, left = 0, right = 0 }
end

function MenuState:leave()
    -- Clean up if needed
end

function MenuState:update(dt)
    -- Update screen dimensions in case of resize
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
    
    -- Analog stick navigation
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        local joystick = joysticks[1]
        if joystick:isGamepad() then
            local jy = joystick:getGamepadAxis("lefty")
            local jx = joystick:getGamepadAxis("leftx")
            
            -- Handle vertical movement
            if math.abs(jy) > 0.5 then
                if jy < 0 and not self.analogStates.up then
                    self:keypressed("up")
                    self.analogStates.up = true
                    self.analogRepeatTimers.up = 0.5  -- Initial delay
                elseif jy > 0 and not self.analogStates.down then
                    self:keypressed("down")
                    self.analogStates.down = true
                    self.analogRepeatTimers.down = 0.5
                elseif jy < 0 and self.analogStates.up then
                    self.analogRepeatTimers.up = self.analogRepeatTimers.up - dt
                    if self.analogRepeatTimers.up <= 0 then
                        self:keypressed("up")
                        self.analogRepeatTimers.up = 0.1  -- Repeat rate
                    end
                elseif jy > 0 and self.analogStates.down then
                    self.analogRepeatTimers.down = self.analogRepeatTimers.down - dt
                    if self.analogRepeatTimers.down <= 0 then
                        self:keypressed("down")
                        self.analogRepeatTimers.down = 0.1
                    end
                end
            else
                self.analogStates.up = false
                self.analogStates.down = false
            end
            
            -- Handle horizontal movement (for level select, ship select)
            if math.abs(jx) > 0.5 then
                if jx < 0 and not self.analogStates.left then
                    self:keypressed("left")
                    self.analogStates.left = true
                    self.analogRepeatTimers.left = 0.5
                elseif jx > 0 and not self.analogStates.right then
                    self:keypressed("right")
                    self.analogStates.right = true
                    self.analogRepeatTimers.right = 0.5
                elseif jx < 0 and self.analogStates.left then
                    self.analogRepeatTimers.left = self.analogRepeatTimers.left - dt
                    if self.analogRepeatTimers.left <= 0 then
                        self:keypressed("left")
                        self.analogRepeatTimers.left = 0.1
                    end
                elseif jx > 0 and self.analogStates.right then
                    self.analogRepeatTimers.right = self.analogRepeatTimers.right - dt
                    if self.analogRepeatTimers.right <= 0 then
                        self:keypressed("right")
                        self.analogRepeatTimers.right = 0.1
                    end
                end
            else
                self.analogStates.left = false
                self.analogStates.right = false
            end
        end
    end
end

function MenuState:draw()
    -- Draw starfield background
    if drawStarfield then
        drawStarfield()
    end
    
    -- Draw title
    lg.setFont(titleFont or lg.newFont(48))
    if highContrast then
        lg.setColor(1, 1, 1)
    else
        lg.setColor(0, 1, 1)
    end
    local title = "STELLAR ASSAULT"
    local titleWidth = lg.getFont():getWidth(title)
    lg.print(title, self.screenWidth/2 - titleWidth/2, 100)
    
    if self.menuState == "main" then
        self:drawMainMenu()
    elseif self.menuState == "saves" then
        self:drawSaveMenu()
    elseif self.menuState == "levelselect" then
        self:drawLevelSelect()
    elseif self.menuState == "shipselect" then
        self:drawShipSelect()
    end
end

function MenuState:drawMainMenu()
    lg.setFont(menuFont or lg.newFont(24))
    local options = {"Start Game", "Level Select", "Select Ship", "Options", "Quit"}
    
    for i, option in ipairs(options) do
        if i == self.selection then
            if highContrast then
                lg.setColor(1, 0, 0)
            else
                lg.setColor(1, 1, 0)
            end
        else
            if highContrast then
                lg.setColor(1, 1, 1)
            else
                lg.setColor(1, 1, 1)
            end
        end
        
        local optionWidth = lg.getFont():getWidth(option)
        lg.print(option, self.screenWidth/2 - optionWidth/2, 250 + i * 50)
    end
    
    -- Draw instructions
    lg.setFont(smallFont or lg.newFont(14))
    if highContrast then
        lg.setColor(1, 1, 1)
    else
        lg.setColor(0.7, 0.7, 0.7)
    end
    local nav = inputHints[lastInputType].navigate or "Arrow Keys/D-Pad"
    local select = inputHints[lastInputType].select or "Enter/A"
    local back = inputHints[lastInputType].back or "Escape/B"
    local instructions = nav .. ": Navigate | " .. select .. ": Select | " .. back .. ": Back"
    local instructWidth = lg.getFont():getWidth(instructions)
    lg.print(instructions, self.screenWidth/2 - instructWidth/2, self.screenHeight - 30)
end

function MenuState:drawSaveMenu()
    lg.setFont(menuFont or lg.newFont(24))
    lg.setColor(1, 1, 1)
    local title = "Select Save Slot"
    local titleWidth = lg.getFont():getWidth(title)
    lg.print(title, self.screenWidth/2 - titleWidth/2, 200)
    
    for i = 1, 3 do
        if i == self.selectedSaveSlot then
            lg.setColor(1, 1, 0)
        else
            lg.setColor(1, 1, 1)
        end
        
        local slotText = "Slot " .. i .. ": "
        if self.saveSlots[i] then
            slotText = slotText .. "Level " .. self.saveSlots[i].level .. 
                       " - Score: " .. self.saveSlots[i].score
        else
            slotText = slotText .. "Empty"
        end
        
        local slotWidth = lg.getFont():getWidth(slotText)
        lg.print(slotText, self.screenWidth/2 - slotWidth/2, 250 + i * 50)
    end
    
    -- Back option
    if self.selectedSaveSlot == 4 then
        lg.setColor(1, 1, 0)
    else
        lg.setColor(1, 1, 1)
    end
    local backText = "Back"
    local backWidth = lg.getFont():getWidth(backText)
    lg.print(backText, self.screenWidth/2 - backWidth/2, 450)
end

function MenuState:drawLevelSelect()
    lg.setFont(menuFont or lg.newFont(24))
    lg.setColor(1, 1, 1)
    local title = "Select Level"
    local titleWidth = lg.getFont():getWidth(title)
    lg.print(title, self.screenWidth/2 - titleWidth/2, 100)
    
    -- Draw level grid
    local cols = 5
    local rows = 3
    local boxSize = 60
    local spacing = 20
    local gridWidth = cols * boxSize + (cols - 1) * spacing
    local startX = self.screenWidth/2 - gridWidth/2
    local startY = 200
    
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local level = row * cols + col + 1
            if level <= 15 then
                local x = startX + col * (boxSize + spacing)
                local y = startY + row * (boxSize + spacing)
                
                -- Check if level is unlocked
                local unlocked = level == 1
                if self.levelSelectSource == "main" then
                    -- All levels unlocked when accessed from main menu
                    unlocked = true
                elseif self.saveSlots[currentSaveSlot] then
                    unlocked = level <= self.saveSlots[currentSaveSlot].level
                end
                
                -- Draw box
                if level == self.selectedLevel then
                    lg.setColor(1, 1, 0)
                elseif unlocked then
                    lg.setColor(0, 1, 1)
                else
                    lg.setColor(0.3, 0.3, 0.3)
                end
                
                lg.rectangle("line", x, y, boxSize, boxSize)
                
                -- Draw level number
                lg.setFont(smallFont or lg.newFont(18))
                local levelText = tostring(level)
                local textWidth = lg.getFont():getWidth(levelText)
                local textHeight = lg.getFont():getHeight()
                lg.print(levelText, x + boxSize/2 - textWidth/2, 
                        y + boxSize/2 - textHeight/2)
            end
        end
    end
    
    -- Back option
    lg.setFont(menuFont or lg.newFont(24))
    if self.selectedLevel == 16 then
        lg.setColor(1, 1, 0)
    else
        lg.setColor(1, 1, 1)
    end
    local backText = "Back"
    local backWidth = lg.getFont():getWidth(backText)
    lg.print(backText, self.screenWidth/2 - backWidth/2, 450)
end

function MenuState:keypressed(key, scancode, isrepeat)
    if self.menuState == "main" then
        self:handleMainMenuInput(key)
    elseif self.menuState == "saves" then
        self:handleSaveMenuInput(key)
    elseif self.menuState == "levelselect" then
        self:handleLevelSelectInput(key)
    elseif self.menuState == "shipselect" then
        self:handleShipSelectInput(key)
    end
end

function MenuState:gamepadpressed(joystick, button)
    -- Map gamepad buttons to keyboard inputs
    local keyMap = {
        dpup = "up",
        dpdown = "down",
        dpleft = "left",
        dpright = "right",
        a = "return",
        b = "escape",
        start = "return"
    }
    
    local key = keyMap[button]
    if key then
        if self.menuState == "main" then
            self:handleMainMenuInput(key)
        elseif self.menuState == "saves" then
            self:handleSaveMenuInput(key)
        elseif self.menuState == "levelselect" then
            self:handleLevelSelectInput(key)
        elseif self.menuState == "shipselect" then
            self:handleShipSelectInput(key)
        end
    end
end

function MenuState:handleMainMenuInput(key)
    if key == "up" then
        self.selection = self.selection - 1
        if self.selection < 1 then self.selection = 5 end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "down" then
        self.selection = self.selection + 1
        if self.selection > 5 then self.selection = 1 end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "return" or key == "space" then
        if menuConfirmSound then menuConfirmSound:play() end
        if self.selection == 1 then
            self.menuState = "saves"
        elseif self.selection == 2 then
            -- Level Select - go directly to level select without save slot
            self.menuState = "levelselect"
            self.selectedLevel = 1
            self.levelSelectSource = "main"
            currentSaveSlot = 1  -- Default to slot 1 for now
        elseif self.selection == 3 then
            self.menuState = "shipselect"
            self.selectedShipIndex = 1
            -- Find current ship index
            for i, ship in ipairs(availableShips) do
                if ship == selectedShip then
                    self.selectedShipIndex = i
                    break
                end
            end
        elseif self.selection == 4 then
            stateManager:switch("options")
        elseif self.selection == 5 then
            love.event.quit()
        end
    end
end

function MenuState:handleSaveMenuInput(key)
    if key == "up" then
        self.selectedSaveSlot = self.selectedSaveSlot - 1
        if self.selectedSaveSlot < 1 then self.selectedSaveSlot = 4 end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "down" then
        self.selectedSaveSlot = self.selectedSaveSlot + 1
        if self.selectedSaveSlot > 4 then self.selectedSaveSlot = 1 end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "return" or key == "space" then
        if menuConfirmSound then menuConfirmSound:play() end
        if self.selectedSaveSlot == 4 then
            self.menuState = "main"
        else
            currentSaveSlot = self.selectedSaveSlot
            if self.saveSlots[currentSaveSlot] then
                self.menuState = "levelselect"
                self.selectedLevel = 1
                self.levelSelectSource = "saves"
            else
                -- Start new game
                currentLevel = 1
                if backgroundMusic then
                    backgroundMusic:stop()
                end
                stateManager:switch("intro")
            end
        end
    elseif key == "escape" then
        self.menuState = "main"
        if menuSelectSound then menuSelectSound:play() end
    end
end

function MenuState:handleLevelSelectInput(key)
    local cols = 5
    local maxLevel = 15
    
    if key == "left" then
        if self.selectedLevel > 1 and self.selectedLevel <= maxLevel then
            self.selectedLevel = self.selectedLevel - 1
        end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "right" then
        if self.selectedLevel < maxLevel then
            self.selectedLevel = self.selectedLevel + 1
        elseif self.selectedLevel == maxLevel then
            self.selectedLevel = 16 -- Back button
        end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "up" then
        if self.selectedLevel > cols and self.selectedLevel <= maxLevel then
            self.selectedLevel = self.selectedLevel - cols
        elseif self.selectedLevel == 16 then
            self.selectedLevel = maxLevel
        end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "down" then
        if self.selectedLevel <= maxLevel - cols then
            self.selectedLevel = self.selectedLevel + cols
        elseif self.selectedLevel <= maxLevel then
            self.selectedLevel = 16 -- Back button
        end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "return" or key == "space" then
        if menuConfirmSound then menuConfirmSound:play() end
        if self.selectedLevel == 16 then
            self.menuState = self.levelSelectSource or "main"
        else
            -- Check if level is unlocked
            local unlocked = self.selectedLevel == 1
            if self.levelSelectSource == "main" then
                -- All levels unlocked when accessed from main menu
                unlocked = true
            elseif self.saveSlots[currentSaveSlot] then
                unlocked = self.selectedLevel <= self.saveSlots[currentSaveSlot].level
            end
            
            if unlocked then
                currentLevel = self.selectedLevel
                if backgroundMusic then
                    backgroundMusic:stop()
                end
                stateManager:switch("playing")
            end
        end
    elseif key == "escape" then
        self.menuState = self.levelSelectSource or "main"
        if menuSelectSound then menuSelectSound:play() end
    end
end

function MenuState:loadSaves()
    local saves = {}
    for i = 1, 3 do
        local filename = "save" .. i .. ".dat"
        if love.filesystem.getInfo(filename) then
            local data = love.filesystem.read(filename)
            local parts = {}
            for part in string.gmatch(data, "([^,]+)") do
                table.insert(parts, part)
            end
            if #parts >= 3 then
                saves[i] = {
                    level = tonumber(parts[1]) or 1,
                    score = tonumber(parts[2]) or 0,
                    lives = tonumber(parts[3]) or 3
                }
            end
        end
    end
    return saves
end

function MenuState:drawShipSelect()
    lg.setFont(menuFont or lg.newFont(24))
    lg.setColor(1, 1, 1)
    local title = "Select Your Ship"
    local titleWidth = lg.getFont():getWidth(title)
    lg.print(title, self.screenWidth/2 - titleWidth/2, 150)
    
    -- Draw ship options
    local shipY = 250
    local shipSpacing = 150
    
    for i, shipName in ipairs(availableShips) do
        local shipX = self.screenWidth/2 - (#availableShips * shipSpacing)/2 + (i-1) * shipSpacing + shipSpacing/2
        
        -- Draw ship sprite if available
        if playerShips and playerShips[shipName] then
            local sprite = playerShips[shipName]
            -- Scale sprites relative to their size so they fit comfortably in the menu
            local scale = 80 / math.max(sprite:getWidth(), sprite:getHeight())
            
            -- Highlight selected ship
            if i == self.selectedShipIndex then
                lg.setColor(1, 1, 0)
                lg.circle("line", shipX, shipY, 50)
            end
            
            lg.setColor(1, 1, 1)
            lg.draw(sprite, shipX, shipY, 0, scale, scale, 
                    sprite:getWidth()/2, sprite:getHeight()/2)
        else
            -- Fallback to colored rectangles
            if i == self.selectedShipIndex then
                lg.setColor(1, 1, 0)
            else
                lg.setColor(0.7, 0.7, 0.7)
            end
            lg.rectangle("fill", shipX - 20, shipY - 30, 40, 60)
        end
        
        -- Draw ship name
        lg.setFont(smallFont or lg.newFont(18))
        if i == self.selectedShipIndex then
            lg.setColor(1, 1, 0)
        else
            lg.setColor(1, 1, 1)
        end
        local nameWidth = lg.getFont():getWidth(shipName:upper())
        lg.print(shipName:upper(), shipX - nameWidth/2, shipY + 60)
    end
    
    -- Draw ship stats
    lg.setFont(smallFont or lg.newFont(16))
    lg.setColor(0.8, 0.8, 0.8)
    local statsY = 380
    local stats = {
        alpha = "Balanced - Good all-around performance",
        beta = "Fast - Higher speed, lower shields",
        gamma = "Tank - Higher shields, slower speed"
    }
    local currentShip = availableShips[self.selectedShipIndex]
    local statText = stats[currentShip] or "Standard fighter"
    local statWidth = lg.getFont():getWidth(statText)
    lg.print(statText, self.screenWidth/2 - statWidth/2, statsY)
    
    -- Instructions
    lg.setFont(smallFont or lg.newFont(14))
    lg.setColor(0.7, 0.7, 0.7)
    local nav = lastInputType == "gamepad" and "D-Pad" or "Left/Right"
    local confirm = inputHints[lastInputType].confirm or "Enter"
    local back = inputHints[lastInputType].back or "Escape"
    local instructions = nav .. ": Select | " .. confirm .. ": Confirm | " .. back .. ": Back"
    local instructWidth = lg.getFont():getWidth(instructions)
    lg.print(instructions, self.screenWidth/2 - instructWidth/2, self.screenHeight - 30)
end

function MenuState:handleShipSelectInput(key)
    if key == "left" then
        self.selectedShipIndex = self.selectedShipIndex - 1
        if self.selectedShipIndex < 1 then 
            self.selectedShipIndex = #availableShips 
        end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "right" then
        self.selectedShipIndex = self.selectedShipIndex + 1
        if self.selectedShipIndex > #availableShips then 
            self.selectedShipIndex = 1 
        end
        if menuSelectSound then menuSelectSound:play() end
    elseif key == "return" or key == "space" then
        -- Save selected ship
        selectedShip = availableShips[self.selectedShipIndex]
        saveSettings()  -- Save the selection
        self.menuState = "main"
        if menuConfirmSound then menuConfirmSound:play() end
    elseif key == "escape" then
        self.menuState = "main"
        if menuSelectSound then menuSelectSound:play() end
    end
end

return MenuState