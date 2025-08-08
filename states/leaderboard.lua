-- states/leaderboard.lua

local leaderboard = {}
local lg = love.graphics
local Game = require("src.game")

-- Sample leaderboard data (can be loaded from a file or online service)
leaderboard.scores = {
  { name = "AAA", score = 15000 },
  { name = "BBB", score = 12000 },
  { name = "CCC", score = 10000 },
  { name = "DDD", score = 8000 },
  { name = "EEE", score = 5000 },
  -- Add more as needed
}

-- Enter the leaderboard state
function leaderboard:enter()
  -- Sort scores descending
  table.sort(leaderboard.scores, function(a, b)
    return a.score > b.score
  end)
  print("Leaderboard Entered")
end

-- Update function (not much needed)
function leaderboard:update(dt)
  -- Any animations or updates
end

-- Draw the leaderboard
function leaderboard:draw()
  local w, h = lg.getWidth(), lg.getHeight()
  -- Background
  if _G.drawStarfield then drawStarfield() end
  lg.setColor(0, 0, 0, 0.5)
  lg.rectangle("fill", 0, 0, w, h)

  -- Title
  lg.setFont((Game and Game.titleFont) or lg.newFont(48))
  lg.setColor(1, 1, 1)
  local title = "LEADERBOARD"
  local tw = lg.getFont():getWidth(title)
  lg.print(title, (w - tw) / 2, 60)

  -- Panel
  local panelW = math.min(720, w * 0.9)
  local panelH = math.min(520, h * 0.75)
  local panelX = (w - panelW) / 2
  local panelY = 110
  if Game and Game.uiManager and Game.uiManager.drawPanel then
    Game.uiManager:drawPanel(panelX, panelY, panelW, panelH)
  else
    lg.setColor(0.1, 0.1, 0.15, 0.9)
    lg.rectangle("fill", panelX, panelY, panelW, panelH, 8)
    lg.setColor(1, 1, 1, 0.2)
    lg.rectangle("line", panelX, panelY, panelW, panelH, 8)
  end

  -- Scores
  lg.setFont((Game and Game.menuFont) or lg.newFont(24))
  lg.setColor(0.85, 0.9, 1)
  local y = panelY + 30
  for i, entry in ipairs(leaderboard.scores) do
    local line = string.format("%2d. %s — %d", i, entry.name, entry.score)
    local lw = lg.getFont():getWidth(line)
    lg.print(line, panelX + (panelW - lw) / 2, y)
    y = y + 34
    if y > panelY + panelH - 100 then break end
  end

  -- Back button
  local scale = (Game and Game.uiScale) or 1
  local bw, bh = math.floor(280 * scale), math.floor(40 * scale)
  local bx = panelX + (panelW - bw) / 2
  local by = panelY + panelH - bh - 20
  if Game and Game.uiManager and Game.uiManager.drawButton then
    Game.uiManager:drawButton(bx, by, bw, bh, "Back", true)
  else
    lg.setColor(1, 1, 1)
    local label = "Back"
    local lw = lg.getFont():getWidth(label)
    lg.print(label, bx + (bw - lw) / 2, by)
  end
end

-- Handle key presses
function leaderboard:keypressed(key)
  if key == "escape" then
    -- Switch back to the main menu state
    stateManager:switch("menu")
  end
end

return leaderboard
