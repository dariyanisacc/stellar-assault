-- states/pause.lua

local pause = {}

local lg = love.graphics
local menuItems = { "Resume", "Restart Level", "Options", "Controls", "Quit to Menu" }
local selected = 1

-- Enter the pause state
function pause:enter()
  if _G.Game and Game.pause then Game:pause() end
end

-- Update function (may not need much if fully paused)
function pause:update(dt) end

-- Draw the pause screen
function pause:draw()
  local w, h = lg.getWidth(), lg.getHeight()
  -- Dim background
  lg.setColor(0, 0, 0, 0.5)
  lg.rectangle("fill", 0, 0, w, h)

  -- Panel
  local panelW, panelH = math.min(420, w * 0.8), 220
  local panelX, panelY = (w - panelW) / 2, (h - panelH) / 2
  lg.setColor(0.1, 0.1, 0.15, 0.9)
  lg.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
  lg.setColor(1, 1, 1, 0.2)
  lg.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)

  -- Title
  lg.setColor(1, 1, 1)
  local title = "Paused"
  local titleFont = Game and Game.titleFont or lg.newFont(32)
  lg.setFont(titleFont)
  local tw = lg.getFont():getWidth(title)
  lg.print(title, panelX + (panelW - tw) / 2, panelY + 16)

  -- Menu items
  lg.setFont(Game and Game.menuFont or lg.newFont(22))
  local startY = panelY + 70
  for i, item in ipairs(menuItems) do
    if i == selected then
      lg.setColor(1, 1, 0)
    else
      lg.setColor(0.8, 0.9, 1)
    end
    local iw = lg.getFont():getWidth(item)
    lg.print(item, panelX + (panelW - iw) / 2, startY + (i - 1) * 36)
  end
end

-- Handle key presses
function pause:keypressed(key)
  if key == "p" or key == "escape" then
    if _G.Game and Game.resume then Game:resume() end
    stateManager:pop()
    return
  end
  if key == "up" then
    selected = (selected - 2) % #menuItems + 1
  elseif key == "down" then
    selected = selected % #menuItems + 1
  elseif key == "return" or key == "space" then
    if menuItems[selected] == "Resume" then
      if _G.Game and Game.resume then Game:resume() end
      stateManager:pop()
    elseif menuItems[selected] == "Restart Level" then
      if _G.Game and Game.resume then Game:resume() end
      stateManager:switch("playing")
    elseif menuItems[selected] == "Options" then
      stateManager:push("options", { returnTo = "pause" })
    elseif menuItems[selected] == "Controls" then
      stateManager:push("options_controls")
    elseif menuItems[selected] == "Quit to Menu" then
      if _G.Game and Game.resume then Game:resume() end
      stateManager:switch("menu")
    end
  end
end

function pause:gamepadpressed(joystick, button)
  local map = { dpup = "up", dpdown = "down", a = "return", b = "escape", start = "escape" }
  local key = map[button]
  if key then self:keypressed(key) end
end

return pause
