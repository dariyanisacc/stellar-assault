-- Additional debug commands for Stellar Assault
local logger = require("src.logger")

local function registerGameCommands(console)
    -- State switching
    console:register("state", "Switch game state (usage: state menu/playing/pause)", function(args)
        if not args[2] then
            console:log("Current state: " .. (stateManager.currentName or "none"))
            console:log("Available states: menu, intro, playing, pause, gameover, options, levelselect")
            return
        end
        
        local validStates = {"menu", "intro", "playing", "pause", "gameover", "options", "levelselect"}
        local newState = args[2]:lower()
        
        for _, valid in ipairs(validStates) do
            if newState == valid then
                stateManager:switch(newState)
                console:log("Switched to state: " .. newState)
                logger.info("Debug: Switched to state %s", newState)
                return
            end
        end
        
        console:log("Invalid state: " .. newState)
    end)
    
    -- Time manipulation
    console:register("timescale", "Set time scale (usage: timescale 0.5)", function(args)
        if not args[2] then
            console:log("Usage: timescale <factor>")
            console:log("Current timescale: " .. (_G.timeScale or 1))
            return
        end
        
        local scale = tonumber(args[2])
        if not scale or scale < 0 then
            console:log("Error: Invalid time scale")
            return
        end
        
        _G.timeScale = scale
        console:log("Time scale set to " .. scale)
        logger.info("Debug: Time scale set to %f", scale)
    end)
    
    -- Performance stats
    console:register("stats", "Show performance statistics", function(args)
        console:log("=== Performance Stats ===")
        console:log("FPS: " .. love.timer.getFPS())
        console:log("Memory: " .. string.format("%.2f MB", collectgarbage("count") / 1024))
        console:log("Texture Memory: " .. string.format("%.2f MB", love.graphics.getStats().texturememory / 1024 / 1024))
        console:log("Draw calls: " .. love.graphics.getStats().drawcalls)
        
        if stateManager.currentName == "playing" then
            console:log("Entities:")
            console:log("  Asteroids: " .. #(asteroids or {}))
            console:log("  Aliens: " .. #(aliens or {}))
            console:log("  Player Lasers: " .. #(lasers or {}))
            console:log("  Alien Lasers: " .. #(alienLasers or {}))
            console:log("  Explosions: " .. #(explosions or {}))
            console:log("  Powerups: " .. #(powerups or {}))
        end
    end)
    
    -- Save/Load
    console:register("save", "Save game to slot (usage: save 1)", function(args)
        if stateManager.currentName ~= "playing" then
            console:log("Error: Can only save during gameplay")
            return
        end
        
        local slot = tonumber(args[2]) or 1
        if slot < 1 or slot > 3 then
            console:log("Error: Slot must be 1-3")
            return
        end
        
        saveGame(slot, currentLevel or 1, score or 0, lives or 3)
        console:log("Game saved to slot " .. slot)
        logger.info("Debug: Game saved to slot %d", slot)
    end)
    
    -- Screenshot
    console:register("screenshot", "Take a screenshot", function(args)
        local filename = args[2] or os.date("screenshot_%Y%m%d_%H%M%S.png")
        love.graphics.captureScreenshot(filename)
        console:log("Screenshot saved as: " .. filename)
        logger.info("Screenshot saved: %s", filename)
    end)
    
    -- Reload assets
    console:register("reload", "Reload game assets", function(args)
        local what = args[2] or "all"
        
        if what == "audio" or what == "all" then
            loadAudio()
            console:log("Audio reloaded")
        end
        
        if what == "settings" or what == "all" then
            loadSettings()
            console:log("Settings reloaded")
        end
        
        if what == "config" or what == "all" then
            package.loaded["src.constants"] = nil
            constants = require("src.constants")
            console:log("Config reloaded")
        end
        
        console:log("Assets reloaded")
        logger.info("Debug: Reloaded assets (%s)", what)
    end)
    
    -- Log level
    console:register("loglevel", "Set log level (debug/info/warn/error)", function(args)
        if not args[2] then
            console:log("Usage: loglevel <level>")
            console:log("Levels: debug, info, warn, error")
            return
        end
        
        logger.setLevel(args[2]:upper())
        console:log("Log level set to: " .. args[2]:upper())
    end)
    
    -- Show log
    console:register("showlog", "Toggle log overlay", function(args)
        _G.showLogOverlay = not _G.showLogOverlay
        console:log("Log overlay: " .. (_G.showLogOverlay and "enabled" or "disabled"))
    end)
    
    -- Entity info
    console:register("info", "Show detailed entity info", function(args)
        if not player then
            console:log("No player entity found")
            return
        end
        
        console:log("=== Player Info ===")
        console:log("Position: " .. string.format("%.1f, %.1f", player.x, player.y))
        console:log("Shield: " .. (player.shield or 0) .. "/" .. (player.maxShield or 3))
        console:log("Lives: " .. (lives or 0))
        console:log("Score: " .. (score or 0))
        console:log("Level: " .. (currentLevel or 1))
        console:log("God Mode: " .. (player.godMode and "ON" or "OFF"))
        
        if activePowerups then
            console:log("Active Powerups:")
            for powerup, timer in pairs(activePowerups) do
                console:log("  " .. powerup .. ": " .. string.format("%.1f", timer) .. "s")
            end
        end
    end)
    
    -- Development mode commands
    console:register("god", "Toggle god mode", function(args)
        if player then
            player.godMode = not player.godMode
            console:log("God mode: " .. (player.godMode and "ENABLED" or "DISABLED"))
        else
            console:log("No player found")
        end
    end)
    
    console:register("give", "Give items (usage: give bombs 10)", function(args)
        if stateManager.currentName ~= "playing" then
            console:log("Must be in playing state")
            return
        end
        
        local what = args[2]
        local amount = tonumber(args[3]) or 1
        
        if what == "score" then
            score = (score or 0) + amount
            console:log("Added " .. amount .. " score")
        elseif what == "lives" then
            lives = (lives or 0) + amount
            console:log("Added " .. amount .. " lives")
        elseif what == "bombs" then
            bombCount = (bombCount or 0) + amount
            console:log("Added " .. amount .. " bombs")
        elseif what == "shield" then
            if player then
                player.shield = math.min((player.shield or 0) + amount, player.maxShield or 5)
                console:log("Shield set to " .. player.shield)
            end
        else
            console:log("Usage: give <score|lives|bombs|shield> [amount]")
        end
    end)
    
    console:register("spawn", "Spawn entities (usage: spawn boss)", function(args)
        if stateManager.currentName ~= "playing" then
            console:log("Must be in playing state")
            return
        end
        
        local entity = args[2] or "asteroid"
        local count = tonumber(args[3]) or 1
        
        if entity == "boss" then
            if stateManager.currentState.spawnBoss then
                stateManager.currentState:spawnBoss()
                console:log("Boss spawned!")
            end
        elseif entity == "powerup" then
            local Powerup = require("src.entities.powerup")
            for i = 1, count do
                local ptype = args[4] or Powerup.getRandomType()
                local powerup = Powerup.new(
                    math.random(50, love.graphics.getWidth() - 50),
                    100,
                    ptype
                )
                table.insert(powerups, powerup)
            end
            console:log("Spawned " .. count .. " powerup(s)")
        elseif entity == "asteroid" then
            for i = 1, count do
                table.insert(asteroids, {
                    x = math.random(0, love.graphics.getWidth()),
                    y = -50,
                    size = math.random(20, 50),
                    speed = 100 + math.random(50)
                })
            end
            console:log("Spawned " .. count .. " asteroid(s)")
        elseif entity == "alien" then
            for i = 1, count do
                table.insert(aliens, {
                    x = math.random(50, love.graphics.getWidth() - 50),
                    y = -50,
                    width = 40,
                    height = 40,
                    shootTimer = 0
                })
            end
            console:log("Spawned " .. count .. " alien(s)")
        else
            console:log("Unknown entity: " .. entity)
            console:log("Available: asteroid, alien, powerup, boss")
        end
    end)
    
    console:register("level", "Jump to level (usage: level 5)", function(args)
        if stateManager.currentName ~= "playing" then
            console:log("Must be in playing state")
            return
        end
        
        local level = tonumber(args[2])
        if not level or level < 1 then
            console:log("Usage: level <number>")
            return
        end
        
        currentLevel = level
        console:log("Jumped to level " .. level)
        
        -- Reset enemies for new level
        asteroids = {}
        aliens = {}
        alienLasers = {}
        
        console:log("Level " .. level .. " started")
    end)
    
    console:register("clear", "Clear all enemies", function(args)
        if stateManager.currentName ~= "playing" then
            console:log("Must be in playing state")
            return
        end
        
        asteroids = {}
        aliens = {}
        alienLasers = {}
        
        console:log("All enemies cleared")
    end)
    
    console:register("sandbox", "Launch entity sandbox", function(args)
        local entity = args[2] or "boss"
        console:log("Launching entity sandbox...")
        console:log("Run: love . tools/entity_sandbox.lua " .. entity)
    end)
    
    -- Profiling
    console:register("profile", "Toggle profiling", function(args)
        _G.profiling = not _G.profiling
        console:log("Profiling: " .. (_G.profiling and "ENABLED" or "DISABLED"))
        
        if _G.profiling then
            _G.profileData = {}
            console:log("Profiling data will be collected")
        end
    end)
end

return {
    register = registerGameCommands
}