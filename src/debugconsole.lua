-- Debug Console for Stellar Assault
local lg = love.graphics
local lk = love.keyboard

local DebugConsole = {}
DebugConsole.__index = DebugConsole

function DebugConsole:new()
    local self = setmetatable({}, DebugConsole)
    
    self.active = false
    self.input = ""
    self.history = {}
    self.historyIndex = 0
    self.commandHistory = {}
    self.maxHistory = 50
    self.maxOutput = 100
    self.cursorBlink = 0
    self.commands = {}
    
    -- Console appearance
    self.height = 300
    self.alpha = 0.9
    self.fontSize = 14
    self.padding = 10
    
    -- Register default commands
    self:registerDefaultCommands()
    
    return self
end

function DebugConsole:registerDefaultCommands()
    self:registerSystemCommands()
    self:registerPlayerCommands()
    self:registerSpawnCommands()
    self:registerGameCommands()
end

function DebugConsole:registerSystemCommands()
    -- Help command
    self:register("help", "Show available commands", function(args)
        self:log("Available commands:")
        local categories = {}
        for cmd, data in pairs(self.commands) do
            local category = data.category or "General"
            if not categories[category] then
                categories[category] = {}
            end
            table.insert(categories[category], {cmd = cmd, desc = data.description})
        end
        
        for category, commands in pairs(categories) do
            self:log("  " .. category .. ":")
            table.sort(commands, function(a, b) return a.cmd < b.cmd end)
            for _, cmd in ipairs(commands) do
                self:log(string.format("    %s - %s", cmd.cmd, cmd.desc))
            end
        end
    end)
    
    -- Clear console
    self:register("clear", "Clear console output", function(args)
        self.history = {}
        self:log("Console cleared")
    end, "System")
    
    -- FPS limit
    self:register("fps", "Set FPS limit (usage: fps 60)", function(args)
        if not args[2] then
            self:log("Current FPS: " .. love.timer.getFPS())
            return
        end
        
        local num = tonumber(args[2])
        if not num or num < 0 then
            self:log("Error: Invalid FPS value")
            return
        end
        
        if num == 0 then
            love.window.setVSync(0)
            self:log("VSync disabled, FPS unlimited")
        else
            love.window.setVSync(1)
            self:log("VSync enabled")
        end
    end, "System")
    
    -- Memory info
    self:register("mem", "Show memory usage", function(args)
        local count = collectgarbage("count")
        self:log(string.format("Memory usage: %.2f MB", count / 1024))
        
        if args[2] == "gc" then
            collectgarbage()
            local newCount = collectgarbage("count")
            self:log(string.format("After GC: %.2f MB (freed %.2f MB)", 
                newCount / 1024, (count - newCount) / 1024))
        end
    end, "System")
end

function DebugConsole:registerPlayerCommands()
    -- God mode
    self:register("god", "Toggle god mode", function(args)
        if not player then
            self:log("Error: No player exists")
            return
        end
        
        player.godMode = not player.godMode
        if player.godMode then
            player.shield = 999
            player.maxShield = 999
            self:log("God mode enabled")
        else
            player.shield = constants.player.shield
            player.maxShield = constants.player.maxShield
            self:log("God mode disabled")
        end
    end, "Player")
    
    -- Set lives
    self:register("lives", "Set player lives (usage: lives 5)", function(args)
        if not args[2] then
            self:log("Usage: lives <number>")
            return
        end
        
        local num = tonumber(args[2])
        if not num then
            self:log("Error: Invalid number")
            return
        end
        
        lives = math.max(0, math.min(99, num))
        self:log("Lives set to " .. lives)
    end, "Player")
    
    -- Give powerup
    self:register("powerup", "Give powerup (usage: powerup shield)", function(args)
        if not args[2] then
            self:log("Usage: powerup <type>")
            self:log("Types: shield, rapidFire, multiShot, timeWarp, magnetField")
            return
        end
        
        if not activePowerups then
            activePowerups = {}
        end
        
        local powerupType = args[2]
        local duration = constants.powerup.duration[powerupType]
        
        if duration then
            activePowerups[powerupType] = duration
            self:log("Granted " .. powerupType .. " for " .. duration .. " seconds")
            
            if powerupType == "shield" and player then
                player.shieldActive = true
            end
        else
            self:log("Unknown powerup: " .. powerupType)
        end
    end, "Player")
end

function DebugConsole:registerSpawnCommands()
    -- Spawn enemies
    self:register("spawn", "Spawn entity (usage: spawn asteroid/alien/boss)", function(args)
        if not args[2] then
            self:log("Usage: spawn <type> [count]")
            self:log("Types: asteroid, alien, boss, powerup")
            return
        end
        
        local count = tonumber(args[3]) or 1
        local spawned = 0
        
        local spawnFunctions = {
            asteroid = _G.spawnAsteroid,
            alien = _G.spawnAlien,
            boss = _G.spawnBoss,
            powerup = _G.spawnPowerup
        }
        
        local spawnFunc = spawnFunctions[args[2]]
        if spawnFunc then
            if args[2] == "boss" then
                spawnFunc()
                self:log("Spawned boss")
            else
                for i = 1, count do
                    spawnFunc()
                    spawned = spawned + 1
                end
                self:log("Spawned " .. spawned .. " " .. args[2] .. "s")
            end
        else
            self:log("Unknown entity type: " .. args[2])
        end
    end, "Spawn")
    
    -- Kill all enemies
    self:register("killall", "Kill all enemies", function(args)
        local killed = 0
        
        if asteroids then
            killed = killed + #asteroids
            asteroids = {}
        end
        
        if aliens then
            killed = killed + #aliens
            aliens = {}
        end
        
        if boss then
            boss = nil
            killed = killed + 1
        end
        
        self:log("Killed " .. killed .. " enemies")
    end, "Spawn")
end

function DebugConsole:registerGameCommands()
    -- Set score
    self:register("score", "Set score (usage: score 1000)", function(args)
        if not args[2] then
            self:log("Usage: score <number>")
            return
        end
        
        local num = tonumber(args[2])
        if not num then
            self:log("Error: Invalid number")
            return
        end
        
        score = math.max(0, num)
        self:log("Score set to " .. score)
    end, "Game")
    
    -- Level jump
    self:register("level", "Jump to level (usage: level 5)", function(args)
        if not args[2] then
            self:log("Usage: level <number>")
            return
        end
        
        local num = tonumber(args[2])
        if not num then
            self:log("Error: Invalid number")
            return
        end
        
        currentLevel = math.max(1, math.min(99, num))
        self:log("Jumped to level " .. currentLevel)
    end, "Game")
end

function DebugConsole:register(command, description, func, category)
    self.commands[command] = {
        description = description,
        func = func,
        category = category or "General"
    }
end

function DebugConsole:toggle()
    self.active = not self.active
    if self.active then
        self:log("Debug console activated")
        love.keyboard.setTextInput(true)
    else
        love.keyboard.setTextInput(false)
    end
end

function DebugConsole:log(message)
    table.insert(self.history, {
        text = tostring(message),
        time = love.timer.getTime()
    })
    
    -- Limit history size
    while #self.history > self.maxOutput do
        table.remove(self.history, 1)
    end
end

function DebugConsole:execute(command)
    -- Add to command history
    table.insert(self.commandHistory, command)
    if #self.commandHistory > self.maxHistory then
        table.remove(self.commandHistory, 1)
    end
    self.historyIndex = #self.commandHistory + 1
    
    -- Log the command
    self:log("> " .. command)
    
    -- Parse command
    local args = {}
    for word in command:gmatch("%S+") do
        table.insert(args, word)
    end
    
    if #args == 0 then return end
    
    local cmd = args[1]:lower()
    
    -- Execute command
    if self.commands[cmd] then
        local success, err = pcall(self.commands[cmd].func, args)
        if not success then
            self:log("Error: " .. tostring(err))
        end
    else
        self:log("Unknown command: " .. cmd)
        self:log("Type 'help' for available commands")
    end
end

function DebugConsole:update(dt)
    if not self.active then return end
    
    -- Update cursor blink
    self.cursorBlink = self.cursorBlink + dt
end

function DebugConsole:draw()
    if not self.active then return end
    
    local width = lg.getWidth()
    local y = 0
    
    -- Draw background
    lg.setColor(0, 0, 0, self.alpha)
    lg.rectangle("fill", 0, y, width, self.height)
    
    -- Draw border
    lg.setColor(0, 1, 1, 0.8)
    lg.setLineWidth(2)
    lg.line(0, y + self.height, width, y + self.height)
    lg.setLineWidth(1)
    
    -- Set font
    local oldFont = lg.getFont()
    if consoleFont then
        lg.setFont(consoleFont)
    else
        lg.setFont(lg.newFont(self.fontSize))
    end
    
    -- Draw history
    lg.setColor(1, 1, 1, 1)
    local lineHeight = lg.getFont():getHeight()
    local displayY = y + self.height - self.padding - lineHeight * 2
    
    for i = #self.history, 1, -1 do
        if displayY < y + self.padding then break end
        
        lg.print(self.history[i].text, self.padding, displayY)
        displayY = displayY - lineHeight
    end
    
    -- Draw input line
    lg.setColor(0, 1, 1, 1)
    lg.print("> ", self.padding, y + self.height - self.padding - lineHeight)
    
    lg.setColor(1, 1, 1, 1)
    lg.print(self.input, self.padding + 20, y + self.height - self.padding - lineHeight)
    
    -- Draw cursor
    if math.sin(self.cursorBlink * 5) > 0 then
        local cursorX = self.padding + 20 + lg.getFont():getWidth(self.input)
        lg.rectangle("fill", cursorX, y + self.height - self.padding - lineHeight, 2, lineHeight)
    end
    
    -- Restore font
    lg.setFont(oldFont)
end

function DebugConsole:keypressed(key)
    if not self.active then
        if key == "`" or key == "~" then
            self:toggle()
        end
        return false
    end
    
    if key == "`" or key == "~" then
        self:toggle()
        return true
    elseif key == "return" then
        if #self.input > 0 then
            self:execute(self.input)
            self.input = ""
        end
        return true
    elseif key == "backspace" then
        self.input = self.input:sub(1, -2)
        return true
    elseif key == "up" then
        if self.historyIndex > 1 then
            self.historyIndex = self.historyIndex - 1
            self.input = self.commandHistory[self.historyIndex] or ""
        end
        return true
    elseif key == "down" then
        if self.historyIndex < #self.commandHistory then
            self.historyIndex = self.historyIndex + 1
            self.input = self.commandHistory[self.historyIndex] or ""
        else
            self.historyIndex = #self.commandHistory + 1
            self.input = ""
        end
        return true
    end
    
    return false
end

function DebugConsole:textinput(text)
    if self.active then
        self.input = self.input .. text
        return true
    end
    return false
end

return DebugConsole