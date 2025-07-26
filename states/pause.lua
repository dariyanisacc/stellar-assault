-- states/pause.lua

local pause = {}

-- Enter the pause state
function pause:enter()
    -- Pause game logic, e.g., stop music, timers, etc.
    print("Game Paused")
end

-- Update function (may not need much if fully paused)
function pause:update(dt)
    -- Any update logic if needed during pause
end

-- Draw the pause screen
function pause:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Game Paused\nPress 'P' to Resume", 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
end

-- Handle key presses
function pause:keypressed(key)
    if key == "p" or key == "escape" then
        -- Resume the game by switching back to playing state
        -- Assuming the playing state is defined in states/playing.lua and named 'playing'
        local playing = require("states.playing")
        Gamestate.switch(playing)
    end
end

return pause