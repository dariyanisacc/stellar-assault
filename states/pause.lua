-- states/pause.lua

local pause = {}

local lg = love.graphics
local menuItems = { "Resume", "Restart Level", "Options", "Controls", "Quit to Menu" }

-- Enter the pause state
function pause:enter()
  if _G.Game and Game.pause then Game:pause() end
  -- Reset selection each time we enter pause to keep highlight aligned
  self.selected = 1
end

-- Update function (may not need much if fully paused)
function pause:update(dt) end

-- Draw the pause screen
function pause:draw()
  local w, h = lg.getWidth(), lg.getHeight()
  -- Dim background
  lg.setColor(0, 0, 0, 0.5)
  lg.rectangle("fill", 0, 0, w, h)

  -- Panel and title
  local panelW = math.min(600, w * 0.85)
  local panelH = math.min(360, h * 0.70)
  local panelX = (w - panelW) / 2
  local panelY = (h - panelH) / 2 - 20
  if Game and Game.uiManager and Game.uiManager.drawPanel then
    Game.uiManager:drawPanel(panelX, panelY, panelW, panelH)
  else
    lg.setColor(0.1, 0.1, 0.15, 0.9)
    lg.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
    lg.setColor(1, 1, 1, 0.2)
    lg.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
  end

  local title = "Paused"
  lg.setFont((Game and Game.titleFont) or lg.newFont(32))
  lg.setColor(1, 1, 1)
  local tw = lg.getFont():getWidth(title)
  lg.print(title, panelX + (panelW - tw) / 2, panelY + 20)

  -- Buttons
  local scale = (Game and Game.uiScale) or 1
  local bw, bh = math.floor(360 * scale), math.floor(42 * scale)
  local spacing = math.floor(10 * scale)
  local startY = panelY + 80
  for i, item in ipairs(menuItems) do
    local y = startY + (i - 1) * (bh + spacing)
    local x = panelX + (panelW - bw) / 2
    if Game and Game.uiManager and Game.uiManager.drawButton then
      Game.uiManager:drawButton(x, y, bw, bh, item, i == (self.selected or 1))
    else
      lg.setFont((Game and Game.menuFont) or lg.newFont(22))
      if i == (self.selected or 1) then lg.setColor(1, 1, 0) else lg.setColor(0.85, 0.9, 1) end
      local iwtxt = lg.getFont():getWidth(item)
      lg.print(item, x + (bw - iwtxt) / 2, y + (bh - lg.getFont():getHeight()) / 2)
    end
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
    self.selected = ((self.selected or 1) - 2) % #menuItems + 1
    if Game and Game.menuSelectSound then Game.menuSelectSound:play() end
  elseif key == "down" then
    self.selected = (self.selected or 1) % #menuItems + 1
    if Game and Game.menuSelectSound then Game.menuSelectSound:play() end
  elseif key == "return" or key == "space" then
    if Game and Game.menuConfirmSound then Game.menuConfirmSound:play() end
    if menuItems[self.selected or 1] == "Resume" then
      if _G.Game and Game.resume then Game:resume() end
      stateManager:pop()
    elseif menuItems[self.selected or 1] == "Restart Level" then
      if _G.Game and Game.resume then Game:resume() end
      stateManager:switch("playing")
    elseif menuItems[self.selected or 1] == "Options" then
      stateManager:push("options", { returnTo = "pause" })
    elseif menuItems[self.selected or 1] == "Controls" then
      stateManager:push("options_controls")
    elseif menuItems[self.selected or 1] == "Quit to Menu" then
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
