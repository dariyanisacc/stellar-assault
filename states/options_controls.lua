-- Control remapping state
local lg = love.graphics
local Persistence = require("src.persistence")
local Game = require("src.game")

local OptionsControls = {}

function OptionsControls:enter()
  self.selection = 1
  self.remappingKey = nil
  self.remappingType = nil
  self.screenWidth = lg.getWidth()
  self.screenHeight = lg.getHeight()
  self:setupMenu()
end

function OptionsControls:setupMenu()
  local controls = Persistence.getControls()
  self.menuItems = {
    { name = "Keyboard Controls", type = "header" },
    { name = "Move Left", type = "key", action = "left", value = controls.keyboard.left },
    { name = "Move Right", type = "key", action = "right", value = controls.keyboard.right },
    { name = "Move Up", type = "key", action = "up", value = controls.keyboard.up },
    { name = "Move Down", type = "key", action = "down", value = controls.keyboard.down },
    { name = "Fire", type = "key", action = "shoot", value = controls.keyboard.shoot },
    { name = "Boost", type = "key", action = "boost", value = controls.keyboard.boost },
    { name = "Bomb", type = "key", action = "bomb", value = controls.keyboard.bomb },
    { name = "Pause", type = "key", action = "pause", value = controls.keyboard.pause },
    { name = "", type = "spacer" },
    { name = "Gamepad Controls", type = "header" },
    { name = "Fire", type = "gamepad", action = "shoot", value = controls.gamepad.shoot },
    { name = "Bomb", type = "gamepad", action = "bomb", value = controls.gamepad.bomb },
    { name = "Boost", type = "gamepad", action = "boost", value = controls.gamepad.boost },
    { name = "Pause", type = "gamepad", action = "pause", value = controls.gamepad.pause },
    { name = "", type = "spacer" },
    { name = "Reset to Defaults", type = "button" },
    { name = "Back", type = "button" },
  }
end

function OptionsControls:update(dt)
  self.screenWidth = lg.getWidth()
  self.screenHeight = lg.getHeight()
end

function OptionsControls:draw()
  if drawStarfield then
    drawStarfield()
  end
  lg.setColor(0, 0, 0, 0.5)
  lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

  lg.setFont(Game.titleFont or lg.newFont(48))
  local titleColor = Game.highContrast and { 1, 1, 1 } or { 0, 1, 1 }
  lg.setColor(titleColor)
  local title = "CONTROLS"
  local tw = lg.getFont():getWidth(title)
  lg.print(title, self.screenWidth / 2 - tw / 2, 50)

  if self.remappingKey then
    lg.setColor(0, 0, 0, 0.8)
    lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    lg.setFont(Game.menuFont or lg.newFont(24))
    lg.setColor(1, 1, 0)
    local t = "Press new key for: " .. self.remappingKey
    local w = lg.getFont():getWidth(t)
    lg.print(t, self.screenWidth / 2 - w / 2, self.screenHeight / 2 - 50)
    lg.setFont(Game.smallFont or lg.newFont(14))
    lg.setColor(0.5, 0.5, 0.5)
    local c = "Press ESC to cancel"
    local cw = lg.getFont():getWidth(c)
    lg.print(c, self.screenWidth / 2 - cw / 2, self.screenHeight / 2)
    return
  end

  local y = 130
  local itemHeight = 35
  for i, item in ipairs(self.menuItems) do
    local selected = i == self.selection
    if item.type == "header" then
      lg.setFont(Game.mediumFont or lg.newFont(20))
      lg.setColor(0.5, 0.8, 1)
      local w = lg.getFont():getWidth(item.name)
      lg.print(item.name, self.screenWidth / 2 - w / 2, y)
    elseif item.type ~= "spacer" then
      lg.setFont(Game.uiFont or lg.newFont(18))
      if selected then
        lg.setColor(Game.highContrast and { 1, 0, 0 } or { 1, 1, 0 })
      else
        lg.setColor(Game.highContrast and { 1, 1, 1 } or { 0.7, 0.7, 0.7 })
      end
      local text = item.name
      if item.type == "key" or item.type == "gamepad" then
        text = text .. ": " .. item.value:upper()
      end
      local w = lg.getFont():getWidth(text)
      lg.print(text, self.screenWidth / 2 - w / 2, y)
    end
    y = y + itemHeight
  end

  lg.setFont(Game.smallFont or lg.newFont(14))
  local nav = Game.inputHints[Game.lastInputType].navigate or "Arrow Keys"
  local remap = Game.inputHints[Game.lastInputType].action or "Enter"
  local back = Game.inputHints[Game.lastInputType].back or "ESC"
  local inst = nav .. ": Navigate | " .. remap .. ": Remap | " .. back .. ": Back"
  local instrColor = Game.highContrast and { 1, 1, 1 } or { 0.5, 0.5, 0.5 }
  Game.uiManager:drawMessage(
    inst,
    self.screenWidth / 2,
    self.screenHeight - 40,
    instrColor,
    Game.smallFont
  )
end

local function saveControls(items)
  local controls = { keyboard = {}, gamepad = {} }
  for _, it in ipairs(items) do
    if it.type == "key" then
      controls.keyboard[it.action] = it.value
    elseif it.type == "gamepad" then
      controls.gamepad[it.action] = it.value
    end
  end
  Persistence.updateSettings({ controls = controls })
end

function OptionsControls:keypressed(key)
  if self.remappingKey then
    if key == "escape" then
      self.remappingKey = nil
      self.remappingType = nil
    else
      local item = self.menuItems[self.selection]
      if self.remappingType == "keyboard" then
        item.value = key
      end
      saveControls(self.menuItems)
      self.remappingKey = nil
      self.remappingType = nil
    end
    return
  end

  local item = self.menuItems[self.selection]
  if key == "up" then
    repeat
      self.selection = self.selection - 1
      if self.selection < 1 then
        self.selection = #self.menuItems
      end
    until self.menuItems[self.selection].type ~= "spacer"
      and self.menuItems[self.selection].type ~= "header"
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  elseif key == "down" then
    repeat
      self.selection = self.selection + 1
      if self.selection > #self.menuItems then
        self.selection = 1
      end
    until self.menuItems[self.selection].type ~= "spacer"
      and self.menuItems[self.selection].type ~= "header"
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  elseif key == "return" or key == "space" then
    if item.type == "key" then
      self.remappingKey = item.name
      self.remappingType = "keyboard"
      if Game.menuConfirmSound then
        Game.menuConfirmSound:play()
      end
    elseif item.type == "gamepad" then
      self.remappingKey = item.name
      self.remappingType = "gamepad"
      if Game.menuConfirmSound then
        Game.menuConfirmSound:play()
      end
    elseif item.type == "button" then
      if item.name == "Reset to Defaults" then
        Persistence.resetControls()
        self:setupMenu()
        if Game.menuConfirmSound then
          Game.menuConfirmSound:play()
        end
      elseif item.name == "Back" then
        stateManager:pop()
        if Game.menuSelectSound then
          Game.menuSelectSound:play()
        end
      end
    end
  elseif key == "escape" then
    stateManager:pop()
  end
end

function OptionsControls:keyreleased(key) end

function OptionsControls:gamepadpressed(joystick, button)
  if self.remappingKey and self.remappingType == "gamepad" then
    local item = self.menuItems[self.selection]
    item.value = button
    saveControls(self.menuItems)
    self.remappingKey = nil
    self.remappingType = nil
  else
    local map = {
      dpup = "up",
      dpdown = "down",
      dpleft = "left",
      dpright = "right",
      a = "return",
      b = "escape",
      start = "return",
    }
    local k = map[button]
    if k then
      self:keypressed(k)
    end
  end
end

function OptionsControls:gamepadreleased(joystick, button)
  local map = { dpup = "up", dpdown = "down", dpleft = "left", dpright = "right" }
  local k = map[button]
  if k then
    self:keyreleased(k)
  end
end

return OptionsControls
