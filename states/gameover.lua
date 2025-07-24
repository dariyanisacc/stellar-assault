-- Game Over State for Stellar Assault
local lg = love.graphics

local GameOverState = {}

function GameOverState:enter(params)
    self.game = params and params.game
    local isNewHighScore = params and params.isNewHighScore
    self.selection = 1 -- 1 = Restart Level, 2 = Main Menu
    self.finalScore = self.game and self.game.score or 0
    self.levelReached = levelAtDeath or currentLevel or 1
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
    self.isNewHighScore = isNewHighScore or false
    
    -- Animation timers
    self.animationTimer = 0
    self.textAlpha = 0
    
    -- Get high score for display
    local Persistence = require("src.persistence")
    self.highScore = Persistence.getHighScore()
end

function GameOverState:update(dt)
    -- Update screen dimensions
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
    
    -- Update animation timer
    self.animationTimer = self.animationTimer + dt
    
    -- Fade in text
    if self.textAlpha < 1 then
        self.textAlpha = math.min(1, self.textAlpha + dt * 2)
    end
end

function GameOverState:draw()
    -- Draw starfield background
    if drawStarfield then
        drawStarfield()
    end
    
    -- Darken background
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    
    -- Game Over title
    lg.setFont(titleFont or lg.newFont(48))
    lg.setColor(1, 0, 0, self.textAlpha)
    local title = gameComplete and "VICTORY!" or "GAME OVER"
    local titleWidth = lg.getFont():getWidth(title)
    lg.print(title, self.screenWidth/2 - titleWidth/2, 150)
    
    -- New High Score notification
    if self.isNewHighScore then
        lg.setFont(menuFont or lg.newFont(24))
        local pulse = math.sin(self.animationTimer * 5) * 0.3 + 0.7
        lg.setColor(1, 1, 0, self.textAlpha * pulse)
        local highScoreText = "NEW HIGH SCORE!"
        local hsWidth = lg.getFont():getWidth(highScoreText)
        lg.print(highScoreText, self.screenWidth/2 - hsWidth/2, 200)
    end
    
    -- Stats
    lg.setFont(menuFont or lg.newFont(24))
    lg.setColor(1, 1, 1, self.textAlpha)
    
    local stats = {
        "Final Score: " .. string.format("%d", self.finalScore),
        "High Score: " .. string.format("%d", self.highScore),
        "Level Reached: " .. self.levelReached
    }
    
    -- Add completion status if game was completed
    if gameComplete then
        table.insert(stats, "Game Completed!")
    end
    
    local y = self.isNewHighScore and 260 or 250
    for _, stat in ipairs(stats) do
        local statWidth = lg.getFont():getWidth(stat)
        lg.print(stat, self.screenWidth/2 - statWidth/2, y)
        y = y + 40
    end
    
    -- Menu options
    local options = {"Restart Level", "Main Menu", "Leaderboard"}
    
    y = self.isNewHighScore and 420 or 400
    for i, option in ipairs(options) do
        if i == self.selection then
            lg.setColor(1, 1, 0, self.textAlpha)
        else
            lg.setColor(0.7, 0.7, 0.7, self.textAlpha)
        end
        
        local optionWidth = lg.getFont():getWidth(option)
        lg.print(option, self.screenWidth/2 - optionWidth/2, y)
        y = y + 50
    end
    
    -- Instructions
    lg.setFont(smallFont or lg.newFont(14))
    lg.setColor(0.5, 0.5, 0.5)
    local instructions = "Arrow Keys: Navigate | Enter: Select"
    local instructWidth = lg.getFont():getWidth(instructions)
    lg.print(instructions, self.screenWidth/2 - instructWidth/2, self.screenHeight - 40)
end

function GameOverState:keypressed(key)
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
            -- Restart Level
            currentLevel = self.levelReached
            gameState = "playing"
            stateManager:switch("playing", {game = self.game})
        elseif self.selection == 2 then
            -- Main Menu
            gameState = "menu"
            stateManager:switch("menu")
        else
            stateManager:switch("leaderboard", "menu")
        end
    end
end

function GameOverState:gamepadpressed(joystick, button)
    -- Map gamepad buttons to keyboard inputs
    local keyMap = {
        dpup = "up",
        dpdown = "down",
        a = "return",
        b = "escape",
        start = "return"
    }
    
    local key = keyMap[button]
    if key then
        self:keypressed(key)
    end
end

-- Removed checkHighScore function as it's now handled by Persistence module

return GameOverState