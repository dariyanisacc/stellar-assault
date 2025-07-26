-- states/intro.lua
-- Intro (splash‑screen) game state for *Stellar Assault*
-- Shows title, starfield background, and then hands control to the menu.
-- Author: Ada (ChatGPT) • 2025‑07‑25

local lg = love.graphics

---@class IntroState
local Intro = {}
Intro.__index = Intro

-- How long before we allow the player to skip (avoid accidental taps)
local INPUT_DELAY = 0.6 -- seconds
-- Auto‑advance to menu after this much time if no input
local AUTO_ADVANCE = 3.0 -- seconds

local timer = 0

---------------------------------------------------------------------
-- StateManager hooks ------------------------------------------------
---------------------------------------------------------------------
function Intro:enter(_params)
    timer = 0
end

function Intro:update(dt)
    timer = timer + dt
    if timer >= AUTO_ADVANCE then
        stateManager:switch("menu")
    end
end

function Intro:draw()
    -- Background
    drawStarfield()

    -- Title text
    lg.setColor(1, 1, 1, 1)
    lg.setFont(titleFont)
    lg.printf("Stellar Assault", 0, lg.getHeight() * 0.4, lg.getWidth(), "center")

    -- Prompt
    lg.setFont(uiFont)
    lg.printf("Press any key to begin", 0, lg.getHeight() * 0.6, lg.getWidth(), "center")
end

function Intro:keypressed(_key)
    if timer >= INPUT_DELAY then
        stateManager:switch("menu")
    end
end

function Intro:gamepadpressed(_joy, _button)
    if timer >= INPUT_DELAY then
        stateManager:switch("menu")
    end
end

-- Provide empty handlers so StateManager can safely call them
function Intro:keyreleased(...) end
function Intro:mousepressed(...) end
function Intro:mousereleased(...) end
function Intro:resize(...) end
function Intro:exit() end

return setmetatable({}, Intro)
