-- Level Select State
local Persistence = require("src.persistence")
local constants = require("src.constants")
local ShopManager = require("src.shop_manager")
local lg = love.graphics
local Game = require("src.game")

local function formatTime(t)
  if not t then
    return ""
  end
  local m = math.floor(t / 60)
  local s = math.floor(t % 60)
  return string.format("%d:%02d", m, s)
end

local LevelSelectState = {}

function LevelSelectState:enter()
  self.selectedLevel = 1
  self.maxUnlocked = Persistence.getUnlockedLevels()
  self.columns = 5
  self.rows = 4
  self.levelButtons = {}

  -- Create level buttons
  local buttonWidth = 100
  local buttonHeight = 80
  local spacing = 20
  local startX = (lg.getWidth() - (self.columns * buttonWidth + (self.columns - 1) * spacing)) / 2
  local startY = 150

  for i = 1, 20 do
    local row = math.floor((i - 1) / self.columns)
    local col = (i - 1) % self.columns

    local button = {
      level = i,
      x = startX + col * (buttonWidth + spacing),
      y = startY + row * (buttonHeight + spacing),
      width = buttonWidth,
      height = buttonHeight,
      unlocked = i <= self.maxUnlocked,
      hover = false,
    }

    table.insert(self.levelButtons, button)
  end

  -- Shop setup
  self.shopManager = ShopManager:new()
  self.shopOpen = false
  self.currentScore = Persistence.getCurrentScore() or 0
  self.shopButton = {
    x = lg.getWidth() - 160,
    y = lg.getHeight() - 60,
    width = 140,
    height = 40,
    hover = false,
  }
  self.purchaseMessage = nil
  self.purchaseMessageTimer = 0

  -- Ship selection setup
  self.shipSelectOpen = false
  self.shipSelectButton = {
    x = 20,
    y = lg.getHeight() - 60,
    width = 140,
    height = 40,
    hover = false,
  }

  -- Animation
  self.fadeIn = 0
end

function LevelSelectState:leave()
  -- Cleanup if needed
end

function LevelSelectState:update(dt)
  self.fadeIn = math.min(self.fadeIn + dt * 2, 1)

  -- Update purchase message
  if self.purchaseMessageTimer > 0 then
    self.purchaseMessageTimer = self.purchaseMessageTimer - dt
    if self.purchaseMessageTimer <= 0 then
      self.purchaseMessage = nil
    end
  end

  -- Update hover states
  local mx, my = love.mouse.getPosition()

  -- Shop button hover
  self.shopButton.hover = mx >= self.shopButton.x
    and mx <= self.shopButton.x + self.shopButton.width
    and my >= self.shopButton.y
    and my <= self.shopButton.y + self.shopButton.height

  -- Ship select button hover
  self.shipSelectButton.hover = mx >= self.shipSelectButton.x
    and mx <= self.shipSelectButton.x + self.shipSelectButton.width
    and my >= self.shipSelectButton.y
    and my <= self.shipSelectButton.y + self.shipSelectButton.height

  -- Level button hover (only if shop not open)
  if not self.shopOpen and not self.shipSelectOpen then
    for _, button in ipairs(self.levelButtons) do
      button.hover = button.unlocked
        and mx >= button.x
        and mx <= button.x + button.width
        and my >= button.y
        and my <= button.y + button.height
    end
  else
    for _, button in ipairs(self.levelButtons) do
      button.hover = false
    end
  end

  -- Update shop if open
  if self.shopOpen and self.shopManager then
    self.shopManager:update(dt)
  end
end

function LevelSelectState:draw()
  lg.setColor(1, 1, 1, self.fadeIn)

  -- Title
  lg.setFont(Game.titleFont)
  lg.printf("SELECT LEVEL", 0, 50, lg.getWidth(), "center")

  -- Level buttons
  lg.setFont((Game and Game.menuFont) or lg.newFont(24))
  for _, button in ipairs(self.levelButtons) do
    local x, y = button.x, button.y

    if button.unlocked then
      -- Unlocked level
      if button.hover then
        lg.setColor(0.3, 0.8, 1, self.fadeIn)
        lg.rectangle("fill", x - 5, y - 5, button.width + 10, button.height + 10, 10)
      end

      lg.setColor(0.2, 0.6, 0.8, self.fadeIn)
      lg.rectangle("fill", x, y, button.width, button.height, 8)

      lg.setColor(0.4, 0.8, 1, self.fadeIn)
      lg.rectangle("line", x, y, button.width, button.height, 8)

      -- Level number
      lg.setColor(1, 1, 1, self.fadeIn)
      lg.printf(tostring(button.level), x, y + 20, button.width, "center")

      local stats = Persistence.getLevelStats(button.level)
      lg.setFont(Game.smallFont)
      lg.setColor(1, 1, 0, self.fadeIn)
      lg.printf(
        "S:" .. tostring(stats.bestScore or 0),
        x,
        y + button.height - 28,
        button.width,
        "center"
      )
      lg.setColor(0, 1, 1, self.fadeIn)
      lg.printf(formatTime(stats.bestTime), x, y + button.height - 14, button.width, "center")
      lg.setFont((Game and Game.menuFont) or lg.newFont(24))

      -- Boss indicator
      if button.level % constants.levels.bossFrequency == 0 then
        lg.setColor(1, 0.5, 0.5, self.fadeIn)
        lg.setFont(Game.smallFont)
        lg.printf("BOSS", x, y + 45, button.width, "center")
        lg.setFont((Game and Game.menuFont) or lg.newFont(24))
      end
    else
      -- Locked level
      lg.setColor(0.2, 0.2, 0.2, self.fadeIn * 0.5)
      lg.rectangle("fill", x, y, button.width, button.height, 8)

      lg.setColor(0.3, 0.3, 0.3, self.fadeIn * 0.5)
      lg.rectangle("line", x, y, button.width, button.height, 8)

      -- Lock icon
      lg.setColor(0.5, 0.5, 0.5, self.fadeIn * 0.5)
      lg.printf("🔒", x, y + 20, button.width, "center")
    end
  end

  -- Instructions (only if shop not open)
  if not self.shopOpen and not self.shipSelectOpen then
    lg.setColor(1, 1, 1, self.fadeIn * 0.8)
    lg.setFont(Game.uiFont)
    lg.printf("Click a level to start", 0, lg.getHeight() - 100, lg.getWidth(), "center")
    lg.printf("Press ESC to return to menu", 0, lg.getHeight() - 70, lg.getWidth(), "center")
  end

  -- Score and high score display
  lg.setFont(Game.uiFont)
  local highScore = Persistence.getHighScore()
  lg.setColor(1, 1, 0, self.fadeIn)
  lg.printf("High Score: " .. tostring(highScore), 0, 20, lg.getWidth(), "center")
  lg.setColor(0, 1, 1, self.fadeIn)
  lg.printf("Score: " .. tostring(self.currentScore), 0, 45, lg.getWidth(), "center")

  -- Shop button
  local shopBtn = self.shopButton
  if shopBtn.hover then
    lg.setColor(0, 1, 0, self.fadeIn)
  else
    lg.setColor(0, 0.7, 0, self.fadeIn)
  end
  lg.rectangle("fill", shopBtn.x, shopBtn.y, shopBtn.width, shopBtn.height, 5)
  lg.setColor(1, 1, 1, self.fadeIn)
  lg.setFont(Game.uiFont)
  lg.printf("SHOP", shopBtn.x, shopBtn.y + 12, shopBtn.width, "center")

  -- Ship select button
  local shipBtn = self.shipSelectButton
  if shipBtn.hover then
    lg.setColor(0.8, 0.5, 0, self.fadeIn)
  else
    lg.setColor(0.6, 0.3, 0, self.fadeIn)
  end
  lg.rectangle("fill", shipBtn.x, shipBtn.y, shipBtn.width, shipBtn.height, 5)
  lg.setColor(1, 1, 1, self.fadeIn)
  lg.printf("SELECT SHIP", shipBtn.x, shipBtn.y + 12, shipBtn.width, "center")

  -- Draw shop if open
  if self.shopOpen and self.shopManager then
    self.shopManager:draw(lg.getWidth() - 320, 100, 300, lg.getHeight() - 200, self.currentScore)
  end

  -- Draw ship selection if open
  if self.shipSelectOpen then
    self:drawShipSelection()
  end

  -- Purchase message
  if self.purchaseMessage then
    lg.setFont((Game and Game.menuFont) or lg.newFont(24))
    local msgAlpha = math.min(self.purchaseMessageTimer * 2, 1)
    if self.purchaseMessage:find("Not enough") or self.purchaseMessage:find("Already") then
      lg.setColor(1, 0.3, 0.3, msgAlpha)
    else
      lg.setColor(0.3, 1, 0.3, msgAlpha)
    end
    lg.printf(self.purchaseMessage, 0, lg.getHeight() / 2 - 50, lg.getWidth(), "center")
  end

  lg.setColor(1, 1, 1, 1)
end

function LevelSelectState:drawShipSelection()
  local x = 20
  local y = 100
  local width = 300
  local height = lg.getHeight() - 200

  -- Background
  lg.setColor(0.1, 0.1, 0.2, 0.95)
  lg.rectangle("fill", x, y, width, height)
  lg.setColor(0.3, 0.3, 0.4, 1)
  lg.rectangle("line", x, y, width, height)

  -- Title
  lg.setColor(1, 1, 1)
  lg.setFont((Game and Game.menuFont) or lg.newFont(24))
  lg.printf("SELECT SHIP", x, y + 10, width, "center")

  -- Ship options
  local shipY = y + 60
  lg.setFont(Game.uiFont)

  local shipsList = Game.availableShips or { "falcon", "titan", "wraith" }
  for i, shipName in ipairs(shipsList) do
    local isUnlocked = Persistence.isShipUnlocked(shipName)
    local isSelected = (Game and Game.selectedShip) == shipName
    local shipConfig = constants.ships[shipName]

    -- Background for current ship
    if isSelected then
      lg.setColor(0.2, 0.3, 0.2, 0.5)
      lg.rectangle("fill", x + 10, shipY - 5, width - 20, 80)
    end

    if isUnlocked then
      if isSelected then
        lg.setColor(0, 1, 0)
      else
        lg.setColor(0.8, 0.8, 0.8)
      end

      -- Ship name
      lg.print(shipConfig.name, x + 20, shipY)

      -- Ship sprite
      if Game.playerShips and Game.playerShips[shipName] then
        local sprite = Game.playerShips[shipName]
        local scale = 40 / math.max(sprite:getWidth(), sprite:getHeight())
        lg.setColor(1, 1, 1)
        lg.draw(
          sprite,
          x + width - 60,
          shipY + 20,
          0,
          scale,
          scale,
          sprite:getWidth() / 2,
          sprite:getHeight() / 2
        )
      end

      -- Ship stats (from data)
      lg.setFont(Game.smallFont)
      lg.setColor(0.7, 0.7, 0.7)
      local speedValue = shipConfig.speed or (200 * (shipConfig.speedMultiplier or 1.0))
      local hullValue  = shipConfig.hull or math.floor(100 * (shipConfig.shieldMultiplier or 1.0))
      local fireRate   = shipConfig.fireRate or 0.3
      local guns       = shipConfig.guns or 1
      lg.print(
        string.format("Hull: %d", hullValue),
        x + 20,
        shipY + 20
      )
      lg.print(
        string.format("Speed: %d px/s", speedValue),
        x + 20,
        shipY + 35
      )
      local frText = guns > 1 and string.format("Fire Rate: %.2fs x%d", fireRate, guns)
        or string.format("Fire Rate: %.2fs", fireRate)
      lg.print(frText, x + 20, shipY + 50)
      lg.setFont(Game.uiFont)
    else
      lg.setColor(0.4, 0.4, 0.4)
      lg.print(shipConfig.name .. " [LOCKED]", x + 20, shipY)
      lg.setFont(Game.smallFont)
      lg.setColor(0.5, 0.5, 0.5)
      lg.print("Unlock in shop", x + 20, shipY + 20)
      lg.setFont(Game.uiFont)
    end

    shipY = shipY + 90
  end

  -- Instructions
  lg.setColor(0.7, 0.7, 0.7)
  lg.setFont(Game.smallFont)
  lg.printf("Click to select", x, y + height - 25, width, "center")
end

function LevelSelectState:mousepressed(x, y, button)
  if button == 1 then
    -- Shop button
    if self.shopButton.hover then
      self.shopOpen = not self.shopOpen
      self.shipSelectOpen = false
      if menuSelectSound then
        menuSelectSound:stop()
        menuSelectSound:play()
      end
      return
    end

    -- Ship select button
    if self.shipSelectButton.hover then
      self.shipSelectOpen = not self.shipSelectOpen
      self.shopOpen = false
      if menuSelectSound then
        menuSelectSound:stop()
        menuSelectSound:play()
      end
      return
    end

    -- Ship selection
    if self.shipSelectOpen then
      local shipY = 160
      local shipsList = Game.availableShips or { "falcon", "titan", "wraith" }
      for i, shipName in ipairs(shipsList) do
        if y >= shipY - 5 and y <= shipY + 80 and x >= 30 and x <= 310 then
          if Persistence.isShipUnlocked(shipName) then
            Game.selectedShip = shipName
            _G.selectedShip = shipName
            Persistence.updateSettings({ selectedShip = shipName })
            if menuConfirmSound then
              menuConfirmSound:stop()
              menuConfirmSound:play()
            end
          end
          return
        end
        shipY = shipY + 90
      end
    end

    -- Level buttons (only if shop not open)
    if not self.shopOpen and not self.shipSelectOpen then
      for _, btn in ipairs(self.levelButtons) do
        if btn.unlocked and btn.hover then
          -- Start the selected level
          currentLevel = btn.level
          stateManager:switch("playing")

          if menuConfirmSound then
            menuConfirmSound:stop()
            menuConfirmSound:play()
          end
          return
        end
      end
    end
  end
end

function LevelSelectState:keypressed(key)
  if key == "escape" then
    if self.shopOpen then
      self.shopOpen = false
    elseif self.shipSelectOpen then
      self.shipSelectOpen = false
    else
      stateManager:switch("menu")
    end

    if menuSelectSound then
      menuSelectSound:stop()
      menuSelectSound:play()
    end
  elseif self.shopOpen and self.shopManager then
    -- Handle shop navigation
    if key == "up" then
      self.shopManager:moveSelection("up")
    elseif key == "down" then
      self.shopManager:moveSelection("down")
    elseif key == "return" or key == "space" then
      -- Try to purchase
      local success, newScore, message =
        self.shopManager:tryPurchase(self.shopManager.selected, self.currentScore)

      if success then
        self.currentScore = newScore
        Persistence.setCurrentScore(newScore)
        if menuConfirmSound then
          menuConfirmSound:stop()
          menuConfirmSound:play()
        end
      end

      -- Show message
      self.purchaseMessage = message
      self.purchaseMessageTimer = 2.0
    end
  end
end

return LevelSelectState
