local Powerup = require("src.entities.powerup")
local constants = require("src.constants")
local PowerupHandler = {}

function PowerupHandler.update(state, dt)
for i = #powerups, 1, -1 do
local powerup = powerups[i]
powerup:update(dt)
if powerup.y > state.screenHeight + powerup.height then
table.remove(powerups, i)
end
end
for i = #powerupTexts, 1, -1 do
local text = powerupTexts[i]
text.y = text.y - 50 * dt
text.life = text.life - dt
if text.life <= 0 then
table.remove(powerupTexts, i)
end
end

missiles = missiles or {}
for i = #missiles, 1, -1 do
local m = missiles[i]
if not m.target or m.target._remove then
local closest
local closestDist = math.huge
for _, a in ipairs(aliens or {}) do
        local dx = (a.x + (a.width or 0)/2) - m.x
        local dy = (a.y + (a.height or 0)/2) - m.y
        local d = dx*dx + dy*dy
if d < closestDist then
closestDist = d
closest = a
end
end
if state.waveManager and state.waveManager.enemies then
for _, a in ipairs(state.waveManager.enemies) do
        local dx = (a.x + (a.width or 0)/2) - m.x
        local dy = (a.y + (a.height or 0)/2) - m.y
        local d = dx*dx + dy*dy
if d < closestDist then
closestDist = d
closest = a
end
end
end
m.target = closest
end

if m.target then
        local dx = (m.target.x + (m.target.width or 0)/2) - m.x
        local dy = (m.target.y + (m.target.height or 0)/2) - m.y
        local dist = math.sqrt(dx*dx + dy*dy)
if dist > 0 then
m.vx = (dx/dist) * m.speed
m.vy = (dy/dist) * m.speed
end
end

m.x = m.x + (m.vx or 0) * dt
m.y = m.y + (m.vy or -m.speed) * dt

if m.x < -20 or m.x > state.screenWidth + 20 or m.y < -20 or m.y > state.screenHeight + 20 then
table.remove(missiles, i)
end
end
end

function PowerupHandler.spawn(state, x, y, forceType)
x = x or math.random(30, state.screenWidth - 30)
y = y or -30
local types = {"shield", "rapid", "spread"}
if currentLevel >= 2 then
table.insert(types, "boost")
table.insert(types, "coolant")
end
if currentLevel >= 3 then
table.insert(types, "bomb")
end
if currentLevel >= 4 then
table.insert(types, "health")
end
local isEnhanced = math.random() < 0.1

local powerupType = forceType
if not powerupType then
if math.random() < 0.1 then
powerupType = "homingMissile"
else
powerupType = types[math.random(#types)]
end
end

local powerup = Powerup.new(x, y, powerupType)
if isEnhanced then
powerup.enhanced = true
powerup.color = {powerup.color[1], powerup.color[2], powerup.color[3], 1}
end
table.insert(powerups, powerup)
end

function PowerupHandler.checkCollisions(state)
for i = #powerups, 1, -1 do
local powerup = powerups[i]
if Collision.checkAABB(player, powerup) then
local result = powerup:collect(player)
local enhancementMultiplier = powerup.enhanced and 2 or 1
if result == "bomb" then
player.bombs = (player.bombs or 0) + (1 * enhancementMultiplier)
if powerup.enhanced then
state:createPowerupText("DOUBLE BOMB!", powerup.x, powerup.y, {1,1,0})
end
elseif type(result) == "table" then
local duration = result.duration * enhancementMultiplier
activePowerups[result.type] = duration
if result.type == "rapid" and powerup.enhanced then
state:createPowerupText("SUPER RAPID FIRE!", powerup.x, powerup.y, {1,1,0})
elseif result.type == "spread" then
activePowerups.multiShot = duration
if powerup.enhanced then
state:createPowerupText("MEGA SPREAD!", powerup.x, powerup.y, {1,0.5,0})
end
elseif result.type == "boost" and powerup.enhanced then
state:createPowerupText("HYPER BOOST!", powerup.x, powerup.y, {0,1,0})
elseif result.type == "coolant" then
player.heat = 0
if powerup.enhanced then
state:createPowerupText("SUPER COOLANT!", powerup.x, powerup.y, {0,0.7,1})
else
state:createPowerupText("HEAT RESET!", powerup.x, powerup.y, {0,0.5,1})
end
end
elseif result == true and powerup.type == "shield" and powerup.enhanced then
player.shield = math.min(player.shield + 1, player.maxShield)
state:createPowerupText("DOUBLE SHIELD!", powerup.x, powerup.y, {0,1,1})
elseif result == true and powerup.type == "health" and powerup.enhanced then
lives = lives + 1
state:createPowerupText("EXTRA LIFE!", powerup.x, powerup.y, {1,0.2,0.2})
end
score = score + constants.score.powerup
if score > state.previousHighScore and not state.newHighScore then
state.newHighScore = true
state:showNewHighScoreNotification()
end
if powerupSound then
powerupSound:stop()
powerupSound:play()
end
state:createPowerupText(powerup.description, powerup.x, powerup.y, powerup.color)
table.remove(powerups, i)
end
end
end

function PowerupHandler.createText(state, text, x, y, color)
table.insert(powerupTexts, {text = text, x = x, y = y, color = color, life = 1.5})
end

return PowerupHandler