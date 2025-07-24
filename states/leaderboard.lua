-- Leaderboard State
local Persistence = require("src.persistence")
local lg = love.graphics

local LeaderboardState = {}

function LeaderboardState:enter(returnState)
    self.returnState = returnState or "menu"
    self.entries = Persistence.getLeaderboard()
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
    self.selection = 1
end

function LeaderboardState:update(dt)
    self.screenWidth = lg.getWidth()
    self.screenHeight = lg.getHeight()
end

function LeaderboardState:draw()
    if drawStarfield then drawStarfield() end

    lg.setFont(titleFont or lg.newFont(48))
    lg.setColor(0, 1, 1)
    local title = "LEADERBOARD"
    local titleWidth = lg.getFont():getWidth(title)
    lg.print(title, self.screenWidth/2 - titleWidth/2, 80)

    lg.setFont(menuFont or lg.newFont(24))
    for i, entry in ipairs(self.entries) do
        lg.setColor(1, 1, 1)
        local name = entry.name or "---"
        local score = entry.score or 0
        local text = string.format("%2d. %-10s %8d", i, name, score)
        local textWidth = lg.getFont():getWidth(text)
        lg.print(text, self.screenWidth/2 - textWidth/2, 150 + i * 30)
    end

    local backText = "Back"
    if self.selection == 1 then
        lg.setColor(1,1,0)
    else
        lg.setColor(0.7,0.7,0.7)
    end
    local bw = lg.getFont():getWidth(backText)
    lg.print(backText, self.screenWidth/2 - bw/2, self.screenHeight - 80)

    lg.setFont(smallFont or lg.newFont(14))
    lg.setColor(0.5,0.5,0.5)
    local instructions = "Enter: Back"
    local iw = lg.getFont():getWidth(instructions)
    lg.print(instructions, self.screenWidth/2 - iw/2, self.screenHeight - 40)
end

function LeaderboardState:keypressed(key)
    if key == "return" or key == "space" or key == "escape" then
        stateManager:switch(self.returnState)
    end
end

function LeaderboardState:gamepadpressed(joystick, button)
    if button == "a" or button == "b" or button == "start" then
        self:keypressed("return")
    end
end

function LeaderboardState:onPress(action)
    self:keypressed(action)
end

function LeaderboardState:onRelease(action)
    if self.keyreleased then
        self:keyreleased(action)
    end
end

return LeaderboardState
