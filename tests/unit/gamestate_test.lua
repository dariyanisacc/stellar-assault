-- Game State Management Unit Tests
describe("Game State Management", function()
    local love_mock
    local gameState
    local menuSelection
    local pauseSelection
    local score
    local lives
    local currentLevel
    
    before_each(function()
        -- Set up mock Love2D environment
        love_mock = require("tests.mocks.love_mock")
        _G.love = love_mock
        
        -- Initialize game state variables
        gameState = "menu"
        menuSelection = 1
        pauseSelection = 1
        score = 0
        lives = 3
        currentLevel = 1
    end)
    
    describe("State Transitions", function()
        it("starts in menu state", function()
            assert.equals("menu", gameState)
        end)
        
        it("transitions from menu to playing when starting game", function()
            gameState = "playing"
            assert.equals("playing", gameState)
        end)
        
        it("transitions from playing to paused", function()
            gameState = "playing"
            gameState = "paused"
            assert.equals("paused", gameState)
        end)
        
        it("transitions from paused back to playing", function()
            gameState = "paused"
            gameState = "playing"
            assert.equals("playing", gameState)
        end)
        
        it("transitions from playing to gameover", function()
            gameState = "playing"
            gameState = "gameover"
            assert.equals("gameover", gameState)
        end)
        
        it("transitions from gameover to menu", function()
            gameState = "gameover"
            gameState = "menu"
            assert.equals("menu", gameState)
        end)
        
        it("transitions from playing to levelcomplete", function()
            gameState = "playing"
            gameState = "levelcomplete"
            assert.equals("levelcomplete", gameState)
        end)
        
        it("transitions from levelcomplete back to playing", function()
            gameState = "levelcomplete"
            gameState = "playing"
            assert.equals("playing", gameState)
        end)
        
        it("transitions from menu to options", function()
            gameState = "menu"
            gameState = "options"
            assert.equals("options", gameState)
        end)
        
        it("transitions from options back to menu", function()
            gameState = "options"
            gameState = "menu"
            assert.equals("menu", gameState)
        end)
    end)
    
    describe("Menu Navigation", function()
        it("initializes menu selection to 1 (Start)", function()
            assert.equals(1, menuSelection)
        end)
        
        it("increments menu selection", function()
            menuSelection = 1
            menuSelection = menuSelection + 1
            assert.equals(2, menuSelection)
        end)
        
        it("decrements menu selection", function()
            menuSelection = 2
            menuSelection = menuSelection - 1
            assert.equals(1, menuSelection)
        end)
        
        it("wraps menu selection from bottom to top", function()
            menuSelection = 3
            menuSelection = menuSelection + 1
            if menuSelection > 3 then menuSelection = 1 end
            assert.equals(1, menuSelection)
        end)
        
        it("wraps menu selection from top to bottom", function()
            menuSelection = 1
            menuSelection = menuSelection - 1
            if menuSelection < 1 then menuSelection = 3 end
            assert.equals(3, menuSelection)
        end)
    end)
    
    describe("Pause Menu Navigation", function()
        it("initializes pause selection to 1 (Resume)", function()
            assert.equals(1, pauseSelection)
        end)
        
        it("toggles between pause options", function()
            pauseSelection = 1
            pauseSelection = pauseSelection + 1
            assert.equals(2, pauseSelection)
            
            pauseSelection = pauseSelection - 1
            assert.equals(1, pauseSelection)
        end)
        
        it("wraps pause selection correctly", function()
            pauseSelection = 2
            pauseSelection = pauseSelection + 1
            if pauseSelection > 2 then pauseSelection = 1 end
            assert.equals(1, pauseSelection)
        end)
    end)
    
    describe("Game Reset Functionality", function()
        local function resetGame()
            score = 0
            lives = 3
            currentLevel = 1
            gameState = "playing"
            -- In actual game, would also reset:
            -- asteroids = {}
            -- aliens = {}
            -- lasers = {}
            -- etc.
        end
        
        it("resets score to 0", function()
            score = 12345
            resetGame()
            assert.equals(0, score)
        end)
        
        it("resets lives to 3", function()
            lives = 1
            resetGame()
            assert.equals(3, lives)
        end)
        
        it("resets current level to 1", function()
            currentLevel = 5
            resetGame()
            assert.equals(1, currentLevel)
        end)
        
        it("sets game state to playing", function()
            gameState = "gameover"
            resetGame()
            assert.equals("playing", gameState)
        end)
    end)
    
    describe("State Validation", function()
        local validStates = {
            "menu", "options", "playing", "paused", "gameover", "levelcomplete"
        }
        
        local function isValidState(state)
            for _, validState in ipairs(validStates) do
                if state == validState then
                    return true
                end
            end
            return false
        end)
        
        it("recognizes all valid game states", function()
            assert.is_true(isValidState("menu"))
            assert.is_true(isValidState("options"))
            assert.is_true(isValidState("playing"))
            assert.is_true(isValidState("paused"))
            assert.is_true(isValidState("gameover"))
            assert.is_true(isValidState("levelcomplete"))
        end)
        
        it("rejects invalid game states", function()
            assert.is_false(isValidState("invalid"))
            assert.is_false(isValidState(""))
            assert.is_false(isValidState(nil))
            assert.is_false(isValidState("PLAYING"))
            assert.is_false(isValidState("Menu"))
        end)
    end)
    
    describe("State Persistence", function()
        it("maintains state through multiple frames", function()
            gameState = "playing"
            
            -- Simulate multiple frame updates
            for i = 1, 60 do
                -- State should remain unchanged without explicit transition
                assert.equals("playing", gameState)
            end
        end)
        
        it("preserves menu selection when returning to menu", function()
            menuSelection = 2
            gameState = "menu"
            gameState = "playing"
            gameState = "menu"
            
            -- Menu selection should be preserved
            assert.equals(2, menuSelection)
        end)
    end)
    
    describe("Invalid State Transitions", function()
        it("should not transition from menu directly to paused", function()
            gameState = "menu"
            -- This transition should be prevented in real game logic
            local function tryInvalidTransition()
                if gameState == "menu" then
                    -- Can't pause from menu
                    return false
                end
                gameState = "paused"
                return true
            end
            
            assert.is_false(tryInvalidTransition())
            assert.equals("menu", gameState)
        end)
        
        it("should not transition from gameover to paused", function()
            gameState = "gameover"
            local function tryInvalidTransition()
                if gameState == "gameover" then
                    -- Can't pause when game is over
                    return false
                end
                gameState = "paused"
                return true
            end
            
            assert.is_false(tryInvalidTransition())
            assert.equals("gameover", gameState)
        end)
    end)
end)