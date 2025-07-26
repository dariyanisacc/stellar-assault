-- Menu State for Stellar Assault
local Persistence = require("src.persistence")
local lg = love.graphics
local Game = require("src.game")

local MenuState = {}

----------------------------------------------------------------------
--  NEW: simple helper for persisting settings
----------------------------------------------------------------------
local function saveSettings()
  -- Load (or create) current save-data table
  local data = Persistence.load()
  data.settings = data.settings or {}
  data.settings.selectedShip = Game.selectedShip or "alpha"
  -- Write it back
  Persistence.save(data)
end
----------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- State lifecycle
-- ---------------------------------------------------------------------------
function MenuState:enter()
  self.selection = 1
  self.menuState = "main"
  self.selectedSaveSlot = 1
  self.selectedLevel = 1
  self.saveSlots = self:loadSaves()
  self.levelSelectSource = "main" -- track where we came from

  -- Cached dimensions
  self.screenWidth = lg.getWidth()
  self.screenHeight = lg.getHeight()

  -- Analogue stick handling
  self.analogStates = { up = false, down = false, left = false, right = false }
  self.analogRepeatTimers = { up = 0, down = 0, left = 0, right = 0 }

  -- Persistence-layer load errors
  local err = Persistence.getLoadError and Persistence.getLoadError()
  if err then
    self.loadErrorMessage = err
    self.loadErrorTimer = 4
    if Persistence.clearLoadError then
      Persistence.clearLoadError()
    end
  else
    self.loadErrorMessage = nil
    self.loadErrorTimer = 0
  end
end

function MenuState:leave() end

-- ---------------------------------------------------------------------------
-- Update / Input
-- ---------------------------------------------------------------------------
function MenuState:update(dt)
  -- Handle window resize
  self.screenWidth = lg.getWidth()
  self.screenHeight = lg.getHeight()

  -- Fade out persistence error
  if self.loadErrorTimer and self.loadErrorTimer > 0 then
    self.loadErrorTimer = self.loadErrorTimer - dt
    if self.loadErrorTimer <= 0 then
      self.loadErrorMessage = nil
    end
  end

  -- Analogue navigation ---------------------------------------------------
  local js = love.joystick.getJoysticks()[1]
  if js and js:isGamepad() then
    local jy = js:getGamepadAxis("lefty")
    local jx = js:getGamepadAxis("leftx")

    -- Vertical
    if math.abs(jy) > 0.5 then
      if jy < 0 then
        self:_analogPress("up", dt)
      end
      if jy > 0 then
        self:_analogPress("down", dt)
      end
    else
      self.analogStates.up = false
      self.analogStates.down = false
    end
    -- Horizontal
    if math.abs(jx) > 0.5 then
      if jx < 0 then
        self:_analogPress("left", dt)
      end
      if jx > 0 then
        self:_analogPress("right", dt)
      end
    else
      self.analogStates.left = false
      self.analogStates.right = false
    end
  end
end

-- Helper for analogue repeat behaviour
function MenuState:_analogPress(dir, dt)
  if not self.analogStates[dir] then
    self:keypressed(dir)
    self.analogStates[dir] = true
    self.analogRepeatTimers[dir] = 0.5 -- initial delay
  else
    self.analogRepeatTimers[dir] = self.analogRepeatTimers[dir] - dt
    if self.analogRepeatTimers[dir] <= 0 then
      self:keypressed(dir)
      self.analogRepeatTimers[dir] = 0.1 -- repeat rate
    end
  end
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------
function MenuState:draw()
  -- Starfield background
  if drawStarfield then
    drawStarfield()
  end

  -- Title
  local titleColour = Game.highContrast and { 1, 1, 1 } or Game.palette.ui
  Game.uiManager:drawMessage(
    "STELLAR ASSAULT",
    self.screenWidth / 2,
    100,
    titleColour,
    Game.titleFont
  )

  -- Active sub-menu
  if self.menuState == "main" then
    self:drawMainMenu()
  elseif self.menuState == "saves" then
    self:drawSaveMenu()
  elseif self.menuState == "levelselect" then
    self:drawLevelSelect()
  elseif self.menuState == "shipselect" then
    self:drawShipSelect()
  end

  -- Persistence error (if any)
  if self.loadErrorMessage then
    Game.uiManager:drawMessage(
      self.loadErrorMessage,
      self.screenWidth / 2,
      140,
      { 1, 0.3, 0.3 },
      Game.smallFont
    )
  end
end

-- ---------------------------------------------------------------------------
-- Main menu
-- ---------------------------------------------------------------------------
function MenuState:drawMainMenu()
  lg.setFont(Game.menuFont)
  local options = {
    "Start Game",
    "Level Select",
    "Select Ship",
    "Leaderboard",
    "Options",
    "Quit",
  }

  for i, option in ipairs(options) do
    if i == self.selection then
      lg.setColor(
        Game.highContrast and 1 or 1,
        Game.highContrast and 0 or 1,
        Game.highContrast and 0 or 0
      )
    else
      lg.setColor(1, 1, 1)
    end
    local w = lg.getFont():getWidth(option)
    lg.print(option, self.screenWidth / 2 - w / 2, 250 + i * 50)
  end

  -- Input hint string
  local hints = Game.inputHints[Game.lastInputType]
  local nav = hints.navigate or "Arrow Keys/D-Pad"
  local select = hints.select or "Enter/A"
  local back = hints.back or "Escape/B"
  local msg = nav .. ": Navigate | " .. select .. ": Select | " .. back .. ": Back"
  local colour = Game.highContrast and { 1, 1, 1 } or { 0.7, 0.7, 0.7 }
  Game.uiManager:drawMessage(
    msg,
    self.screenWidth / 2,
    self.screenHeight - 30,
    colour,
    Game.smallFont
  )
end

-- ---------------------------------------------------------------------------
-- Save-slot menu
-- ---------------------------------------------------------------------------
function MenuState:drawSaveMenu()
  lg.setFont(Game.menuFont)
  lg.setColor(1, 1, 1)
  local t = "Select Save Slot"
  lg.print(t, self.screenWidth / 2 - lg.getFont():getWidth(t) / 2, 200)

  for i = 1, 3 do
    lg.setColor(
      i == self.selectedSaveSlot and 1 or 1,
      i == self.selectedSaveSlot and 1 or 1,
      i == self.selectedSaveSlot and 0 or 1
    )

    local text = ("Slot %d: "):format(i)
    if self.saveSlots[i] then
      local s = self.saveSlots[i]
      text = text .. ("Level %d - Score: %d"):format(s.level, s.score)
    else
      text = text .. "Empty"
    end
    lg.print(text, self.screenWidth / 2 - lg.getFont():getWidth(text) / 2, 250 + i * 50)
  end

  -- Back option (mapped to faux "slot 4")
  lg.setColor(
    self.selectedSaveSlot == 4 and 1 or 1,
    self.selectedSaveSlot == 4 and 1 or 1,
    self.selectedSaveSlot == 4 and 0 or 1
  )
  local back = "Back"
  lg.print(back, self.screenWidth / 2 - lg.getFont():getWidth(back) / 2, 450)
end

-- ---------------------------------------------------------------------------
-- Level-select
-- ---------------------------------------------------------------------------
function MenuState:drawLevelSelect()
  lg.setFont(Game.menuFont)
  lg.setColor(1, 1, 1)
  local title = "Select Level"
  lg.print(title, self.screenWidth / 2 - lg.getFont():getWidth(title) / 2, 100)

  -- Grid
  local cols, rows, box, gap = 5, 3, 60, 20
  local gridW = cols * box + (cols - 1) * gap
  local startX, startY = self.screenWidth / 2 - gridW / 2, 200

  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      local lvl = r * cols + c + 1
      if lvl <= 15 then
        local x = startX + c * (box + gap)
        local y = startY + r * (box + gap)

        local unlocked = lvl == 1
        if self.levelSelectSource == "main" then
          unlocked = true
        elseif self.saveSlots[currentSaveSlot] then
          unlocked = lvl <= self.saveSlots[currentSaveSlot].level
        end

        if lvl == self.selectedLevel then
          lg.setColor(1, 1, 0)
        elseif unlocked then
          lg.setColor(Game.palette.ui)
        else
          lg.setColor(0.3, 0.3, 0.3)
        end
        lg.rectangle("line", x, y, box, box)

        -- number
        lg.setFont(Game.smallFont)
        local s = tostring(lvl)
        lg.print(
          s,
          x + box / 2 - lg.getFont():getWidth(s) / 2,
          y + box / 2 - lg.getFont():getHeight() / 2
        )
      end
    end
  end

  -- Back button (virtual "level 16")
  lg.setFont(Game.menuFont)
  lg.setColor(
    self.selectedLevel == 16 and 1 or 1,
    self.selectedLevel == 16 and 1 or 1,
    self.selectedLevel == 16 and 0 or 1
  )
  local back = "Back"
  lg.print(back, self.screenWidth / 2 - lg.getFont():getWidth(back) / 2, 450)
end

-- ---------------------------------------------------------------------------
-- Ship-select
-- ---------------------------------------------------------------------------
function MenuState:drawShipSelect()
  lg.setFont(Game.menuFont)
  lg.setColor(1, 1, 1)
  local title = "Select Your Ship"
  lg.print(title, self.screenWidth / 2 - lg.getFont():getWidth(title) / 2, 150)

  local shipY, gap = 250, 150
  for i, name in ipairs(Game.availableShips) do
    local x = self.screenWidth / 2 - (#Game.availableShips * gap) / 2 + (i - 1) * gap + gap / 2

    -- Sprite / fallback
    local sprite = Game.playerShips and Game.playerShips[name]
    if sprite then
      local scale = 80 / math.max(sprite:getWidth(), sprite:getHeight())
      if i == self.selectedShipIndex then
        lg.setColor(1, 1, 0)
        lg.circle("line", x, shipY, 50)
      end
      lg.setColor(1, 1, 1)
      lg.draw(sprite, x, shipY, 0, scale, scale, sprite:getWidth() / 2, sprite:getHeight() / 2)
    else
      lg.setColor(
        i == self.selectedShipIndex and 1 or 0.7,
        i == self.selectedShipIndex and 1 or 0.7,
        i == self.selectedShipIndex and 0 or 0.7
      )
      lg.rectangle("fill", x - 20, shipY - 30, 40, 60)
    end

    -- Name
    lg.setFont(Game.smallFont)
    lg.setColor(
      i == self.selectedShipIndex and 1 or 1,
      i == self.selectedShipIndex and 1 or 1,
      i == self.selectedShipIndex and 0 or 1
    )
    local nm = name:upper()
    lg.print(nm, x - lg.getFont():getWidth(nm) / 2, shipY + 60)
  end

  -- Stats
  lg.setFont(Game.smallFont)
  lg.setColor(0.8, 0.8, 0.8)
  local stats = {
    alpha = "Balanced - Good all-around performance",
    beta = "Fast    - Higher speed, lower shields",
    gamma = "Tank    - Higher shields, slower speed",
  }
  local txt = stats[Game.availableShips[self.selectedShipIndex]] or "Standard fighter"
  lg.print(txt, self.screenWidth / 2 - lg.getFont():getWidth(txt) / 2, 380)

  -- Instructions
  local hints = Game.inputHints[Game.lastInputType]
  local nav = Game.lastInputType == "gamepad" and "D-Pad" or "Left/Right"
  local conf = hints.confirm or "Enter"
  local back = hints.back or "Escape"
  local instr = ("%s: Select | %s: Confirm | %s: Back"):format(nav, conf, back)
  Game.uiManager:drawMessage(
    instr,
    self.screenWidth / 2,
    self.screenHeight - 30,
    { 0.7, 0.7, 0.7 },
    Game.smallFont
  )
end

-- ---------------------------------------------------------------------------
-- Input dispatchers
-- ---------------------------------------------------------------------------
function MenuState:keypressed(key)
  if self.menuState == "main" then
    self:handleMainMenuInput(key)
  elseif self.menuState == "saves" then
    self:handleSaveMenuInput(key)
  elseif self.menuState == "levelselect" then
    self:handleLevelSelectInput(key)
  elseif self.menuState == "shipselect" then
    self:handleShipSelectInput(key)
  end
end

function MenuState:gamepadpressed(_, button)
  local map = {
    dpup = "up",
    dpdown = "down",
    dpleft = "left",
    dpright = "right",
    a = "return",
    start = "return",
    b = "escape",
  }
  local key = map[button]
  if key then
    self:keypressed(key)
  end
end

-- ---------------------------------------------------------------------------
-- Handlers: main menu
-- ---------------------------------------------------------------------------
function MenuState:handleMainMenuInput(key)
  if key == "up" then
    self.selection = (self.selection - 2) % 6 + 1
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  elseif key == "down" then
    self.selection = self.selection % 6 + 1
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  elseif key == "return" or key == "space" then
    if Game.menuConfirmSound then
      Game.menuConfirmSound:play()
    end
    if self.selection == 1 then
      self.menuState = "saves"
    elseif self.selection == 2 then
      self.menuState = "levelselect"
      self.selectedLevel = 1
      self.levelSelectSource = "main"
      currentSaveSlot = 1
    elseif self.selection == 3 then
      self.menuState = "shipselect"
      self.selectedShipIndex = 1
      for i, ship in ipairs(Game.availableShips) do
        if ship == Game.selectedShip then
          self.selectedShipIndex = i
          break
        end
      end
    elseif self.selection == 4 then
      stateManager:switch("leaderboard", "menu")
    elseif self.selection == 5 then
      stateManager:switch("options")
    elseif self.selection == 6 then
      love.event.quit()
    end
  end
end

-- ---------------------------------------------------------------------------
-- Handlers: save menu
-- ---------------------------------------------------------------------------
function MenuState:handleSaveMenuInput(key)
  if key == "up" then
    self.selectedSaveSlot = (self.selectedSaveSlot - 2) % 4 + 1
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  elseif key == "down" then
    self.selectedSaveSlot = self.selectedSaveSlot % 4 + 1
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  elseif key == "return" or key == "space" then
    if Game.menuConfirmSound then
      Game.menuConfirmSound:play()
    end
    if self.selectedSaveSlot == 4 then
      self.menuState = "main"
    else
      currentSaveSlot = self.selectedSaveSlot
      if self.saveSlots[currentSaveSlot] then
        self.menuState = "levelselect"
        self.selectedLevel = 1
        self.levelSelectSource = "saves"
      else
        currentLevel = 1
        if Game.backgroundMusic then
          Game.backgroundMusic:stop()
        end
        stateManager:switch("intro")
      end
    end
  elseif key == "escape" then
    self.menuState = "main"
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  end
end

-- ---------------------------------------------------------------------------
-- Handlers: level select
-- ---------------------------------------------------------------------------
function MenuState:handleLevelSelectInput(key)
  local cols, maxLvl = 5, 15
  if key == "left" then
    self.selectedLevel = math.max(1, self.selectedLevel - 1)
  elseif key == "right" then
    self.selectedLevel = (self.selectedLevel < maxLvl) and (self.selectedLevel + 1) or 16
  elseif key == "up" then
    if self.selectedLevel > cols and self.selectedLevel <= maxLvl then
      self.selectedLevel = self.selectedLevel - cols
    elseif self.selectedLevel == 16 then
      self.selectedLevel = maxLvl
    end
  elseif key == "down" then
    if self.selectedLevel <= maxLvl - cols then
      self.selectedLevel = self.selectedLevel + cols
    else
      self.selectedLevel = 16
    end
  end
  if key == "left" or key == "right" or key == "up" or key == "down" then
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  elseif key == "return" or key == "space" then
    if Game.menuConfirmSound then
      Game.menuConfirmSound:play()
    end
    if self.selectedLevel == 16 then
      self.menuState = self.levelSelectSource or "main"
    else
      local unlocked = (self.levelSelectSource == "main")
        or (self.saveSlots[currentSaveSlot] and self.selectedLevel <= self.saveSlots[currentSaveSlot].level)
        or self.selectedLevel == 1
      if unlocked then
        currentLevel = self.selectedLevel
        if Game.backgroundMusic then
          Game.backgroundMusic:stop()
        end
        stateManager:switch("playing")
      end
    end
  elseif key == "escape" then
    self.menuState = self.levelSelectSource or "main"
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  end
end

-- ---------------------------------------------------------------------------
-- Handlers: ship select
-- ---------------------------------------------------------------------------
function MenuState:handleShipSelectInput(key)
  if key == "left" then
    self.selectedShipIndex = (self.selectedShipIndex - 2) % #Game.availableShips + 1
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  elseif key == "right" then
    self.selectedShipIndex = self.selectedShipIndex % #Game.availableShips + 1
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  elseif key == "return" or key == "space" then
    Game.selectedShip = Game.availableShips[self.selectedShipIndex]
    saveSettings() -- persist new ship choice
    self.menuState = "main"
    if Game.menuConfirmSound then
      Game.menuConfirmSound:play()
    end
  elseif key == "escape" then
    self.menuState = "main"
    if Game.menuSelectSound then
      Game.menuSelectSound:play()
    end
  end
end

-- ---------------------------------------------------------------------------
-- Save-game loader
-- ---------------------------------------------------------------------------
function MenuState:loadSaves()
  local saves = {}
  for i = 1, 3 do
    local fn = ("save%d.dat"):format(i)
    if love.filesystem.getInfo(fn) then
      local data = love.filesystem.read(fn)
      local lvl, score, lives = data:match("([^,]+),([^,]+),([^,]+)")
      saves[i] = {
        level = tonumber(lvl) or 1,
        score = tonumber(score) or 0,
        lives = tonumber(lives) or 3,
      }
    end
  end
  return saves
end

return MenuState
