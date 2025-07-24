local GameState = {}
GameState.__index = GameState

function GameState:new()
    local o = {
        player = {},
        score = 0,
        lives = 0,
        currentLevel = 1,
        asteroids = {},
        aliens = {},
        lasers = {},
        alienLasers = {},
        explosions = {},
        powerups = {},
        powerupTexts = {},
        activePowerups = {}
    }
    return setmetatable(o, GameState)
end

return GameState
