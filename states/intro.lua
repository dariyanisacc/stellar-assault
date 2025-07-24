-- Intro State for Stellar Assault
local lg = love.graphics

local IntroState = {}

function IntroState:enter()
    self.timer = 0
    self.textIndex = 1
    self.lineTimer = 0
    self.complete = false
    
    self.backstory = {
        "The year is 2157...",
        "",
        "Earth's last space station, Stellar Outpost Prime,",
        "has sent a distress signal from the outer rim.",
        "",
        "A massive alien armada has been detected,",
        "heading straight for Earth.",
        "",
        "You are Lieutenant Kai Chen,",
        "Earth's most skilled starfighter pilot.",
        "",
        "Your mission: Hold the line.",
        "Give Earth time to prepare its defenses.",
        "",
        "You are humanity's last hope."
    }
    
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
end

function IntroState:update(dt)
    self.timer = self.timer + dt
    self.lineTimer = self.lineTimer + dt
    
    -- Update screen dimensions
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
    
    -- Auto-advance text
    if self.lineTimer > 2.5 and self.textIndex < #self.backstory then
        self.textIndex = self.textIndex + 1
        self.lineTimer = 0
    end
    
    -- Check if intro is complete
    if self.textIndex >= #self.backstory and self.lineTimer > 3 then
        self.complete = true
    end
    
    -- Auto-transition to game
    if self.complete then
        stateManager:switch("playing")
    end
end

function IntroState:draw()
    -- Draw starfield background
    if drawStarfield then
        drawStarfield()
    end
    
    -- Fade in effect
    local alpha = math.min(self.timer / 2, 1)
    
    -- Draw backstory text
    lg.setFont(menuFont or lg.newFont(24))
    
    local y = 100
    for i = 1, self.textIndex do
        local line = self.backstory[i]
        local lineAlpha = alpha
        
        -- Fade in current line
        if i == self.textIndex then
            lineAlpha = math.min(self.lineTimer / 0.5, 1) * alpha
        end
        
        lg.setColor(0.7, 0.7, 1, lineAlpha)
        local width = lg.getFont():getWidth(line)
        lg.print(line, self.screenWidth/2 - width/2, y)
        y = y + 35
    end
    
    -- Skip instruction
    if self.timer > 2 then
        lg.setFont(smallFont or lg.newFont(14))
        lg.setColor(0.5, 0.5, 0.5, alpha)
        local skipKey = inputHints[lastInputType].skip or "SPACE"
        local skipText = "Press " .. skipKey .. " to skip"
        local skipWidth = lg.getFont():getWidth(skipText)
        lg.print(skipText, self.screenWidth/2 - skipWidth/2, self.screenHeight - 40)
    end
end

function IntroState:keypressed(key)
    if key == "space" or key == "return" or key == "escape" then
        stateManager:switch("playing")
    end
end

function IntroState:gamepadpressed(joystick, button)
    -- Any button skips the intro
    if button == "a" or button == "b" or button == "x" or button == "y" or button == "start" then
        stateManager:switch("playing")
    end
end

function IntroState:onPress(action)
    self:keypressed(action)
end

function IntroState:onRelease(action)
    if self.keyreleased then
        self:keyreleased(action)
    end
end

return IntroState