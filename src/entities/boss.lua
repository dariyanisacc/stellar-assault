-- Boss entity ---------------------------------------------------------------
-- Usage: local Boss = require("src.entities.boss"); boss = Boss.new(level)

local lg   = love.graphics
local BULLET_COOLDOWN = 1.5        -- seconds between patterns

local Boss = {}
Boss.__index = Boss

function Boss.new(level)
    local self = setmetatable({}, Boss)

    -- basic placement ----------------------------
    self.sprite = bossSprite                 -- ← pre‑loaded in main.lua
    self.x      = lg.getWidth() / 2
    self.y      = -self.sprite:getHeight()    -- scroll in from top

    -- stats scale with level ---------------------
    self.maxHP  = 250 + level * 50
    self.hp     = self.maxHP
    self.phase  = 1
    self.cool   = BULLET_COOLDOWN
    return self
end

-- simple sinusoidal sweep ---------------------------------------------------
function Boss:update(dt, bullets)
    self.y = math.min(self.y + 40 * dt, 110)          -- settle on screen
    self.x = self.x + math.sin(love.timer.getTime()*0.6) * 45 * dt

    -- fire pattern ------------------------------
    self.cool = self.cool - dt
    if self.cool <= 0 then
        self.cool = BULLET_COOLDOWN
        for angle = 0, math.pi * 2, math.pi / 6 do
            bullets:spawn(self.x, self.y, angle, 220) -- radial spiral
        end
    end
end

function Boss:draw()
    lg.draw(self.sprite, self.x, self.y, 0, 4, 4,
            self.sprite:getWidth()/2, self.sprite:getHeight()/2)
    -- optional hp bar
    lg.rectangle("fill", self.x-48, self.y-70, 96 * (self.hp/self.maxHP), 6)
    lg.rectangle("line", self.x-48, self.y-70, 96, 6)
end

return Boss