-- Options State for Stellar Assault
local constants = require("src.constants")
local lg = love.graphics
local Persistence = require("src.persistence")
local Game = require("src.game")

local OptionsState = {}

function OptionsState:enter()
  self.selection = 1
  self.screenWidth = lg.getWidth()
  self.screenHeight = lg.getHeight()

  -- Input state for smooth volume adjustment
  self.keys = {
    left = false,
    right = false,
  }

  -- Analog stick state for menu navigation
  self.analogStates = { up = false, down = false, left = false, right = false }
  self.analogRepeatTimers = { up = 0, down = 0, left = 0, right = 0 }
  self.analogHoldDelays = { up = 0.5, down = 0.5, left = 0.5, right = 0.5 } -- Initial hold delay before repeat

  -- Resolution options
  self.resolutions = {
    { width = 800, height = 600, name = "800x600 (4:3)" },
    { width = 1024, height = 768, name = "1024x768 (4:3)" },
    { width = 1280, height = 720, name = "1280x720 (16:9)" },
    { width = 1366, height = 768, name = "1366x768 (16:9)" },
    { width = 1920, height = 1080, name = "1920x1080 (16:9)" },
    { width = 2560, height = 1440, name = "2560x1440 (16:9)" },
  }

  -- New: Display mode options as list
  self.displayModes = { "windowed", "fullscreen", "borderless" }
  self.fontScaleRange = { min = 0.8, max = 1.3 }

  -- Find current index (default to 3 for borderless if not set)
  local dmValue = 3 -- Default to borderless
  for i, mode in ipairs(self.displayModes) do
    if mode == (Game.displayMode or "borderless") then
      dmValue = i
      break
    end
  end

  local settings = Persistence.getSettings()
  local fontValue = settings.fontScale or 1

  -- Menu items (change Display Mode to list type)
  self.menuItems = {
    { name = "Resolution", type = "list", value = Game.currentResolution or 1 },
    { name = "Display Mode", type = "list", value = dmValue },
    { name = "Master Volume", type = "slider", value = Game.masterVolume or 1.0 },
    { name = "SFX Volume", type = "slider", value = Game.sfxVolume or 1.0 },
    { name = "Music Volume", type = "slider", value = Game.musicVolume or 0.2 },
    { name = "High Contrast", type = "toggle", value = settings.highContrast or false },
    { name = "Font Size", type = "slider", value = fontValue },
    { name = "Controls", type = "button" },
    { name = "Apply", type = "button" },
    { name = "Back", type = "button" },
  }

  -- Control remapping state
  self.inControlsMenu = false
  self.remappingKey = nil
  self.remappingType = nil -- "keyboard" or "gamepad"
end

function OptionsState:update(dt)
  self.screenWidth = lg.getWidth()
  self.screenHeight = lg.getHeight()

  -- Smooth volume adjustment when holding keys
  local item = self.menuItems[self.selection]
  if item.type == "slider" then
    if self.keys.left then
      self:adjustValue(-constants.audio.volumeAdjustRate * dt)
    elseif self.keys.right then
      self:adjustValue(constants.audio.volumeAdjustRate * dt)
    end
  end

  -- Analog stick navigation
  local joysticks = love.joystick.getJoysticks()
  if #joysticks > 0 then
    local joystick = joysticks[1]
    if joystick:isGamepad() then
      local jy = joystick:getGamepadAxis("lefty")
      local jx = joystick:getGamepadAxis("leftx")

      -- Helper function to handle direction
      local function handleAnalogDirection(dir, value, threshold, key)
        local isTilted = math.abs(value) > 0.2 and ((dir == "left" or dir == "up") == (value < 0))
        if isTilted then
          if not self.analogStates[dir] then
            -- Initial press
            self:keypressed(key)
            self.analogRepeatTimers[dir] = self.analogHoldDelays[dir] -- Start hold timer
            self.analogStates[dir] = true
          else
            -- Hold and repeat
            self.analogRepeatTimers[dir] = self.analogRepeatTimers[dir] - dt
            if self.analogRepeatTimers[dir] <= 0 then
              self:keypressed(key)
              self.analogRepeatTimers[dir] = 0.2 -- Repeat interval
            end
          end
        else
          if self.analogStates[dir] then
            self:keyreleased(key)
            self.analogStates[dir] = false
            self.analogRepeatTimers[dir] = 0
          end
        end
      end

      handleAnalogDirection("up", jy, 0.5, "up")
      handleAnalogDirection("down", jy, 0.5, "down")
      handleAnalogDirection("left", jx, 0.5, "left")
      handleAnalogDirection("right", jx, 0.5, "right")
    end
  end
end

function OptionsState:draw()
  -- Draw starfield background
  if drawStarfield then
    drawStarfield()
  end

  -- Darken background
  lg.setColor(0, 0, 0, 0.5)
  lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

  -- Check if we're in controls menu
  if self.inControlsMenu then
    self:drawControlsMenu()
    return
  end

  -- Title
  local titleColor = Game.highContrast and { 1, 1, 1 } or { 0, 1, 1 }
  uiManager:drawMessage("OPTIONS", self.screenWidth / 2, 80, titleColor, Game.titleFont)

  -- Draw menu items
  lg.setFont(Game.menuFont or lg.newFont(24))

  local y = 200
  for i, item in ipairs(self.menuItems) do
    local isSelected = i == self.selection

    if isSelected then
      if Game.highContrast then
        lg.setColor(1, 0, 0)
      else
        lg.setColor(1, 1, 0)
      end
    else
      if Game.highContrast then
        lg.setColor(1, 1, 1)
      else
        lg.setColor(0.7, 0.7, 0.7)
      end
    end

    local text = item.name

    if item.type == "list" then
      if item.name == "Resolution" then
        text = text .. ": " .. self.resolutions[item.value].name
      elseif item.name == "Display Mode" then
        text = text .. ": " .. self.displayModes[item.value]:gsub("^%l", string.upper)
      end
    elseif item.type == "slider" then
      text = text .. ": " .. math.floor(item.value * 100) .. "%"
    elseif item.type == "toggle" then
      text = text .. ": " .. (item.value and "On" or "Off")
    end

    local textWidth = lg.getFont():getWidth(text)
    lg.print(text, self.screenWidth / 2 - textWidth / 2, y)

    -- Draw slider bar if applicable
    if item.type == "slider" and isSelected then
      local barWidth = 200
      local barHeight = 10
      local barX = self.screenWidth / 2 - barWidth / 2
      local barY = y + 30

      -- Background
      lg.setColor(0.3, 0.3, 0.3)
      lg.rectangle("fill", barX, barY, barWidth, barHeight)

      -- Fill
      local fillValue = item.value
      if item.name == "Font Size" then
        fillValue = (item.value - self.fontScaleRange.min)
          / (self.fontScaleRange.max - self.fontScaleRange.min)
      end
      if Game.highContrast then
        lg.setColor(1, 1, 1, 1)
      else
        lg.setColor(0, 1, 1, 1)
      end
      lg.rectangle("fill", barX, barY, barWidth * fillValue, barHeight)

      -- Border
      lg.setColor(1, 1, 1)
      lg.rectangle("line", barX, barY, barWidth, barHeight)

      y = y + 20
    end

    y = y + 50
  end

  -- Instructions
  local nav = Game.inputHints[Game.lastInputType].navigate or "Arrow Keys"
  local select = Game.inputHints[Game.lastInputType].select or "Enter"
  local adjust = Game.lastInputType == "gamepad" and "Left/Right Stick" or "Left/Right"
  local instructions = nav .. ": Navigate | " .. select .. ": Select | " .. adjust .. ": Adjust"
  local instrColor = Game.highContrast and { 1, 1, 1 } or { 0.5, 0.5, 0.5 }
  uiManager:drawMessage(
    instructions,
    self.screenWidth / 2,
    self.screenHeight - 40,
    instrColor,
    Game.smallFont
  )
end

function OptionsState:keypressed(key)
  -- Handle controls menu
  if self.inControlsMenu then
    self:controlsKeypressed(key)
    return
  end

  local item = self.menuItems[self.selection]

  if key == "up" then
    self.selection = self.selection - 1
    if self.selection < 1 then
      self.selection = #self.menuItems
    end
    if menuSelectSound then
      menuSelectSound:play()
    end
  elseif key == "down" then
    self.selection = self.selection + 1
    if self.selection > #self.menuItems then
      self.selection = 1
    end
    if menuSelectSound then
      menuSelectSound:play()
    end
  elseif key == "left" then
    self.keys.left = true
    if item.type == "list" or item.type == "toggle" then
      self:adjustValue(-1)
    end
  elseif key == "right" then
    self.keys.right = true
    if item.type == "list" or item.type == "toggle" then
      self:adjustValue(1)
    end
  elseif key == "return" or key == "space" then
    if item.type == "button" then
      if menuConfirmSound then
        menuConfirmSound:play()
      end

      if item.name == "Apply" then
        self:applySettings()
      elseif item.name == "Back" then
        saveSettings()
        stateManager:switch("menu")
      elseif item.name == "Controls" then
        self.inControlsMenu = true
        self.controlsSelection = 1
        self:setupControlsMenu()
      end
    elseif item.type == "toggle" or item.type == "list" then
      self:adjustValue(1)
    end
  elseif key == "escape" then
    stateManager:switch("menu")
  end
end

function OptionsState:keyreleased(key)
  if key == "left" then
    self.keys.left = false
  elseif key == "right" then
    self.keys.right = false
  end
end

function OptionsState:adjustValue(direction)
  local item = self.menuItems[self.selection]

  if item.type == "list" then
    item.value = item.value + direction
    local maxValue
    if item.name == "Resolution" then
      maxValue = #self.resolutions
    elseif item.name == "Display Mode" then
      maxValue = #self.displayModes
    end
    if item.value < 1 then
      item.value = maxValue
    end
    if item.value > maxValue then
      item.value = 1
    end
    if menuSelectSound then
      menuSelectSound:play()
    end
  elseif item.type == "toggle" then
    item.value = not item.value
    if item.name == "High Contrast" then
      Game.highContrast = item.value
      Persistence.updateSettings({ highContrast = Game.highContrast })
    end
  elseif item.type == "slider" then
    -- For continuous adjustment, direction is already scaled by dt
    local newVal
    if item.name == "Font Size" then
      newVal = item.value + direction * (math.abs(direction) < 1 and 0.05 or 0.1)
      newVal = math.max(self.fontScaleRange.min, math.min(self.fontScaleRange.max, newVal))
    else
      if math.abs(direction) < 1 then
        newVal = math.max(0, math.min(1, item.value + direction))
      else
        newVal = math.max(0, math.min(1, item.value + direction * 0.1))
      end
    end
    item.value = newVal

    -- Update global values
    if item.name == "Master Volume" then
      Game.masterVolume = item.value
    elseif item.name == "SFX Volume" then
      Game.sfxVolume = item.value
    elseif item.name == "Music Volume" then
      Game.musicVolume = item.value
    elseif item.name == "Font Size" then
      Game.fontScale = item.value
      applyFontScale()
      Persistence.updateSettings({ fontScale = Game.fontScale })
    end

    -- Apply audio changes immediately
    updateAudioVolumes()
  end
end

function OptionsState:applySettings()
  -- Apply resolution
  local resItem = self.menuItems[1]
  local resolution = self.resolutions[resItem.value]
  Game.currentResolution = resItem.value

  -- Apply display mode
  local modeItem = self.menuItems[2]
  Game.displayMode = self.displayModes[modeItem.value]

  -- Apply window settings based on mode
  if Game.displayMode == "borderless" then
    -- Get desktop dimensions
    local dw, dh = love.window.getDesktopDimensions()

    -- Set to borderless at desktop size in one step
    love.window.setMode(dw, dh, {
      fullscreen = false,
      borderless = true,
      resizable = false,
      vsync = 1,
      display = 1,
      minwidth = constants.window.minWidth,
      minheight = constants.window.minHeight,
    })

    -- Position at 0,0 and maximize
    love.window.setPosition(0, 0)
    love.window.maximize()
  elseif Game.displayMode == "fullscreen" then
    -- Exclusive fullscreen
    love.window.setMode(resolution.width, resolution.height, {
      fullscreen = true,
      fullscreentype = "exclusive",
      resizable = false,
      minwidth = constants.window.minWidth,
      minheight = constants.window.minHeight,
    })
  else -- windowed
    love.window.setMode(resolution.width, resolution.height, {
      fullscreen = false,
      borderless = false,
      resizable = true,
      minwidth = constants.window.minWidth,
      minheight = constants.window.minHeight,
    })
  end

  -- Reinitialize starfield
  if initStarfield then
    initStarfield()
  end

  local hcItem = self.menuItems[6]
  local fsItem = self.menuItems[7]
  Game.highContrast = hcItem.value
  Game.fontScale = fsItem.value
  applyFontScale()

  -- Save settings
  saveSettings()
  Persistence.updateSettings({
    highContrast = Game.highContrast,
    fontScale = Game.fontScale,
  })
end

-- Controls menu functions
function OptionsState:setupControlsMenu()
  local Persistence = require("src.persistence")
  local controls = Persistence.getControls()

  self.controlsMenuItems = {
    { name = "Keyboard Controls", type = "header" },
    { name = "Move Left", type = "key", action = "left", value = controls.keyboard.left },
    { name = "Move Right", type = "key", action = "right", value = controls.keyboard.right },
    { name = "Move Up", type = "key", action = "up", value = controls.keyboard.up },
    { name = "Move Down", type = "key", action = "down", value = controls.keyboard.down },
    { name = "Shoot", type = "key", action = "shoot", value = controls.keyboard.shoot },
    { name = "Boost", type = "key", action = "boost", value = controls.keyboard.boost },
    { name = "Bomb", type = "key", action = "bomb", value = controls.keyboard.bomb },
    { name = "Pause", type = "key", action = "pause", value = controls.keyboard.pause },
    { name = "", type = "spacer" },
    { name = "Gamepad Controls", type = "header" },
    { name = "Shoot", type = "gamepad", action = "shoot", value = controls.gamepad.shoot },
    { name = "Bomb", type = "gamepad", action = "bomb", value = controls.gamepad.bomb },
    { name = "Boost", type = "gamepad", action = "boost", value = controls.gamepad.boost },
    { name = "Pause", type = "gamepad", action = "pause", value = controls.gamepad.pause },
    { name = "", type = "spacer" },
    { name = "Reset to Defaults", type = "button" },
    { name = "Back", type = "button" },
  }
end

function OptionsState:drawControlsMenu()
  -- Title
  lg.setFont(Game.titleFont or lg.newFont(48))
  if Game.highContrast then
    lg.setColor(1, 1, 1)
  else
    lg.setColor(0, 1, 1)
  end
  local title = "CONTROLS"
  local titleWidth = lg.getFont():getWidth(title)
  lg.print(title, self.screenWidth / 2 - titleWidth / 2, 50)

  -- If remapping, show overlay
  if self.remappingKey then
    lg.setColor(0, 0, 0, 0.8)
    lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    lg.setFont(Game.menuFont or lg.newFont(24))
    lg.setColor(1, 1, 0)
    local remapText = "Press new key for: " .. self.remappingKey
    local remapWidth = lg.getFont():getWidth(remapText)
    lg.print(remapText, self.screenWidth / 2 - remapWidth / 2, self.screenHeight / 2 - 50)

    lg.setFont(Game.smallFont or lg.newFont(14))
    lg.setColor(0.5, 0.5, 0.5)
    local escText = "Press ESC to cancel"
    local escWidth = lg.getFont():getWidth(escText)
    lg.print(escText, self.screenWidth / 2 - escWidth / 2, self.screenHeight / 2)
    return
  end

  -- Draw menu items
  local y = 130
  local itemHeight = 35

  for i, item in ipairs(self.controlsMenuItems) do
    local isSelected = i == self.controlsSelection

    if item.type == "header" then
      lg.setFont(Game.mediumFont or lg.newFont(20))
      lg.setColor(0.5, 0.8, 1)
      local headerWidth = lg.getFont():getWidth(item.name)
      lg.print(item.name, self.screenWidth / 2 - headerWidth / 2, y)
    elseif item.type == "spacer" then
      -- Skip spacers
    else
      lg.setFont(Game.uiFont or lg.newFont(18))

      if isSelected then
        if Game.highContrast then
          lg.setColor(1, 0, 0)
        else
          lg.setColor(1, 1, 0)
        end
      else
        if Game.highContrast then
          lg.setColor(1, 1, 1)
        else
          lg.setColor(0.7, 0.7, 0.7)
        end
      end

      local text = item.name
      if item.type == "key" or item.type == "gamepad" then
        text = text .. ": " .. item.value:upper()
      end

      local textWidth = lg.getFont():getWidth(text)
      lg.print(text, self.screenWidth / 2 - textWidth / 2, y)
    end

    y = y + itemHeight
  end

  -- Instructions
  lg.setFont(Game.smallFont or lg.newFont(14))
  local nav = Game.inputHints[Game.lastInputType].navigate or "Arrow Keys"
  local remap = Game.inputHints[Game.lastInputType].action or "Enter"
  local back = Game.inputHints[Game.lastInputType].back or "ESC"
  local instructions = nav .. ": Navigate | " .. remap .. ": Remap | " .. back .. ": Back"
  local instrColor = Game.highContrast and { 1, 1, 1 } or { 0.5, 0.5, 0.5 }
  uiManager:drawMessage(
    instructions,
    self.screenWidth / 2,
    self.screenHeight - 40,
    instrColor,
    Game.smallFont
  )
end

function OptionsState:controlsKeypressed(key)
  -- Handle remapping
  if self.remappingKey then
    if key == "escape" then
      self.remappingKey = nil
      self.remappingType = nil
    else
      -- Save the new binding
      local Persistence = require("src.persistence")
      local item = self.controlsMenuItems[self.controlsSelection]

      if self.remappingType == "keyboard" then
        Persistence.setKeyBinding(item.action, key)
        item.value = key
      end

      self.remappingKey = nil
      self.remappingType = nil
    end
    return
  end

  -- Normal navigation
  local item = self.controlsMenuItems[self.controlsSelection]

  if key == "up" then
    repeat
      self.controlsSelection = self.controlsSelection - 1
      if self.controlsSelection < 1 then
        self.controlsSelection = #self.controlsMenuItems
      end
    until self.controlsMenuItems[self.controlsSelection].type ~= "spacer"
      and self.controlsMenuItems[self.controlsSelection].type ~= "header"
    if menuSelectSound then
      menuSelectSound:play()
    end
  elseif key == "down" then
    repeat
      self.controlsSelection = self.controlsSelection + 1
      if self.controlsSelection > #self.controlsMenuItems then
        self.controlsSelection = 1
      end
    until self.controlsMenuItems[self.controlsSelection].type ~= "spacer"
      and self.controlsMenuItems[self.controlsSelection].type ~= "header"
    if menuSelectSound then
      menuSelectSound:play()
    end
  elseif key == "return" or key == "space" then
    if item.type == "key" then
      self.remappingKey = item.name
      self.remappingType = "keyboard"
      if menuConfirmSound then
        menuConfirmSound:play()
      end
    elseif item.type == "gamepad" then
      self.remappingKey = item.name
      self.remappingType = "gamepad"
      if menuConfirmSound then
        menuConfirmSound:play()
      end
    elseif item.type == "button" then
      if item.name == "Reset to Defaults" then
        local Persistence = require("src.persistence")
        Persistence.resetControls()
        self:setupControlsMenu()
        if menuConfirmSound then
          menuConfirmSound:play()
        end
      elseif item.name == "Back" then
        self.inControlsMenu = false
        if menuSelectSound then
          menuSelectSound:play()
        end
      end
    end
  elseif key == "escape" then
    self.inControlsMenu = false
  end
end

function OptionsState:gamepadpressed(joystick, button)
  if self.inControlsMenu and self.remappingKey and self.remappingType == "gamepad" then
    -- Save the new gamepad binding
    local Persistence = require("src.persistence")
    local item = self.controlsMenuItems[self.controlsSelection]

    Persistence.setGamepadBinding(item.action, button)
    item.value = button

    self.remappingKey = nil
    self.remappingType = nil
  else
    -- Normal gamepad navigation
    local keyMap = {
      dpup = "up",
      dpdown = "down",
      dpleft = "left",
      dpright = "right",
      a = "return",
      b = "escape",
      start = "return",
    }
    local key = keyMap[button]
    if key then
      self:keypressed(key)
    end
  end
end

function OptionsState:gamepadreleased(joystick, button)
  -- Map gamepad buttons to keyboard inputs for release
  local keyMap = {
    dpup = "up",
    dpdown = "down",
    dpleft = "left",
    dpright = "right",
  }
  local key = keyMap[button]
  if key then
    self:keyreleased(key)
  end
end

return OptionsState
