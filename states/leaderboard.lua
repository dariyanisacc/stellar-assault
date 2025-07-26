-- states/leaderboard.lua

local leaderboard = {}

-- Sample leaderboard data (can be loaded from a file or online service)
leaderboard.scores = {
    {name = "AAA", score = 15000},
    {name = "BBB", score = 12000},
    {name = "CCC", score = 10000},
    {name = "DDD", score = 8000},
    {name = "EEE", score = 5000},
    -- Add more as needed
}

-- Enter the leaderboard state
function leaderboard:enter()
    -- Sort scores descending
    table.sort(leaderboard.scores, function(a, b) return a.score > b.score end)
    print("Leaderboard Entered")
end

-- Update function (not much needed)
function leaderboard:update(dt)
    -- Any animations or updates
end

-- Draw the leaderboard
function leaderboard:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Leaderboard", 0, 50, love.graphics.getWidth(), "center")
    
    local y = 100
    for i, entry in ipairs(leaderboard.scores) do
        love.graphics.printf(i .. ". " .. entry.name .. " - " .. entry.score, 0, y, love.graphics.getWidth(), "center")
        y = y + 30
    end
    
    love.graphics.printf("Press 'ESC' to return to menu", 0, love.graphics.getHeight() - 50, love.graphics.getWidth(), "center")
end

-- Handle key presses
function leaderboard:keypressed(key)
    if key == "escape" then
        -- Switch back to the main menu state
        stateManager:switch("menu")
    end
end

return leaderboard