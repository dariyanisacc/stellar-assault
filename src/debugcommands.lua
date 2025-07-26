-- src/debugcommands.lua

local CONFIG = require("src.config")
local debugcommands = {}

-- Flag for debug mode
debugcommands.debugMode = false

-- Register debug commands (this function is called from main.lua)
function debugcommands.register()
    if not CONFIG.debug then
        return
    end
    print("Registering debug commands...")
    
    -- Override love.keypressed to handle debug keys (assuming no nil values)
    local oldKeypressed = love.keypressed or function() end
    love.keypressed = function(key)
        oldKeypressed(key)
        
        if key == 'f1' then
            debugcommands.debugMode = not debugcommands.debugMode
            print("Debug mode: " .. (debugcommands.debugMode and "ON" or "OFF"))
        elseif key == 'f2' and debugcommands.debugMode then
            -- Add currency (assuming shop_manager exists globally or require it)
            local shop_manager = require("src.shop_manager")
            shop_manager.currency = shop_manager.currency + 1000
            print("Added 1000 currency")
        elseif key == 'f3' and debugcommands.debugMode then
            -- Skip to next level or something (customize as needed)
            print("Skipping level")
            -- Example: switch to next state
            stateManager:switch("playing")
        end
    end
    
    -- Additional setup if needed, e.g., register with a console if you have one
    -- If there was a nil object here, ensure it's required properly
    -- For example, if using a hypothetical 'console' module:
    -- local console = require('some.console')
    -- console:register('godmode', function() debugcommands.debugMode = true end)
end

return debugcommands