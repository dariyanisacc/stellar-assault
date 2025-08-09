-- UI Manager for Stellar Assault
local constants = require("src.constants")
local lg = love.graphics
local Game = require("src.game")
local AssetManager = require("src.asset_manager")

local function setColorContrast(normal, contrast)
  local c = normal
  if normal[1] == 0 and normal[2] == 1 and normal[3] == 1 then
    c = Game.palette.ui
  elseif normal[1] == 1 and normal[2] == 0 and normal[3] == 0 then
    c = Game.palette.enemy
  end
  if Game.highContrast and contrast then
    c = contrast
  end
  lg.setColor(c[1], c[2], c[3], c[4] or 1)
end

local UIManager = {}
UIManager.__index = UIManager

function UIManager:new()
  local self = setmetatable({}, UIManager)
  self.margin = constants.ui.margin
  self.elements = {}
  return self
end

-- Core UI Elements
function UIManager:drawScore(x, y, score)
  x = x or self.margin
  y = y or self.margin

  setColorContrast({ 0, 1, 1 }, { 1, 1, 1 })
  lg.setFont(Game.uiFont or lg.newFont(18))
  lg.print("Score: " .. (score or 0), x, y)
end

function UIManager:drawLives(x, y, lives)
  x = x or self.margin
  y = y or self.margin + 25

  setColorContrast({ 0, 1, 1 }, { 1, 1, 1 })
  lg.setFont(Game.uiFont or lg.newFont(18))
  lg.print("Lives: " .. (lives or 0), x, y)
end

function UIManager:drawLevel(x, y, level)
  x = x or self.margin
  y = y or self.margin + 50

  setColorContrast({ 0, 1, 1 }, { 1, 1, 1 })
  lg.setFont(Game.uiFont or lg.newFont(18))
  lg.print("Level: " .. (level or 1), x, y)
end

function UIManager:drawHealthBar(x, y, current, max, width, height, label)
  x = x or self.margin
  y = y or self.margin + 75
  width = width or constants.ui.healthBarWidth
  height = height or constants.ui.healthBarHeight

  -- Background
  lg.setColor(0.3, 0.3, 0.3)
  lg.rectangle("fill", x, y, width, height)

  -- Fill
  if current > 0 then
    local fillWidth = (current / max) * width
    setColorContrast({ 0, 1, 1 }, { 1, 0, 0 })
    lg.rectangle("fill", x, y, fillWidth, height)
  end

  -- Border
  setColorContrast({ 1, 1, 1 }, { 1, 1, 1 })
  lg.rectangle("line", x, y, width, height)

  -- Label
  if label then
    lg.setFont(Game.smallFont or lg.newFont(14))
    setColorContrast({ 0, 1, 1 }, { 1, 1, 1 })
    lg.print(label, x + 2, y - 16)
  end
end

function UIManager:drawPowerupBar(x, y, width, current, max, color)
  width = width or constants.ui.powerupBarWidth
  height = constants.ui.powerupBarHeight

  -- Background
  lg.setColor(0.2, 0.2, 0.2, Game.highContrast and 1 or 0.8)
  lg.rectangle("fill", x, y, width, height)

  -- Fill
  if current > 0 then
    local fillWidth = (current / max) * width
    setColorContrast({ color[1], color[2], color[3], 0.8 }, { 1, 1, 1, 0.8 })
    lg.rectangle("fill", x, y, fillWidth, height)
  end

  -- Border
  setColorContrast({ color[1], color[2], color[3], 1 }, { 1, 1, 1, 1 })
  lg.rectangle("line", x, y, width, height)
end

function UIManager:drawActivePowerups(x, y, powerups)
  x = x or self.margin
  y = y or self.margin + 110

  lg.setFont(Game.smallFont or lg.newFont(14))

  local colors = {
    shield = { 0, 1, 1 },
    rapidFire = { 1, 1, 0 },
    multiShot = { 1, 0.5, 0 },
    timeWarp = { 0.5, 0, 1 },
    magnetField = { 0, 1, 0 },
    vampire = { 0.8, 0.2, 0.8 },
    freeze = { 0.5, 0.5, 1 },
  }

  local drawY = y
  for powerup, timer in pairs(powerups or {}) do
    local color = colors[powerup] or { 1, 1, 1 }
    setColorContrast(color, { 1, 1, 1 })

    -- Draw text
    local text = powerup .. ": " .. string.format("%.1f", timer) .. "s"
    lg.print(text, x, drawY)

    -- Draw timer bar
    self:drawPowerupBar(
      x + 120,
      drawY + 2,
      60,
      timer,
      constants.powerup.duration[powerup] or 10,
      color
    )

    drawY = drawY + 20
  end
end

function UIManager:drawBossHealth(boss)
  if not boss then
    return
  end

  local barWidth = 400
  local barHeight = 20
  local x = lg.getWidth() / 2 - barWidth / 2
  local y = 50

  -- Boss name
  lg.setFont(Game.menuFont or lg.newFont(24))
  setColorContrast({ 1, 0, 0 }, { 1, 1, 1 })
  local name = boss.name or "BOSS"
  local nameWidth = lg.getFont():getWidth(name)
  lg.print(name, lg.getWidth() / 2 - nameWidth / 2, y - 30)

  -- Health bar
  self:drawHealthBar(x, y, boss.health, boss.maxHealth, barWidth, barHeight)

  -- Shield bar if applicable
  if boss.shield and boss.maxShield and boss.shield > 0 then
    setColorContrast({ 0, 0.5, 1 }, { 1, 1, 1 })
    local shieldHeight = 5
    lg.rectangle(
      "fill",
      x,
      y - shieldHeight - 2,
      (boss.shield / boss.maxShield) * barWidth,
      shieldHeight
    )
  end
end

function UIManager:drawMessage(text, x, y, color, font)
  x = x or lg.getWidth() / 2
  y = y or lg.getHeight() / 2
  color = color or { 1, 1, 1 }
  font = font or Game.titleFont or lg.newFont(48)

  lg.setFont(font)
  setColorContrast(color, { 1, 1, 1 })

  local width = lg.getFont():getWidth(text)
  lg.print(text, x - width / 2, y)
end

function UIManager:drawMessages(messages)
  local y = lg.getHeight() / 2 - (#messages * 30)

  for _, msg in ipairs(messages) do
    self:drawMessage(msg.text, nil, y, msg.color, msg.font)
    y = y + 60
  end
end

-- Combo/multiplier display
function UIManager:drawCombo(combo, x, y)
  if not combo or combo <= 1 then
    return
  end

  x = x or lg.getWidth() - 150
  y = y or 100

  lg.setFont(Game.menuFont or lg.newFont(24))

  -- Pulse effect based on combo
  local pulse = math.sin(love.timer.getTime() * 5) * 0.2 + 0.8
  local color = { 1, 1 * pulse, 0 }

  if combo >= 10 then
    color = { 1, 0, 0 } -- Red for high combos
  elseif combo >= 5 then
    color = { 1, 0.5, 0 } -- Orange for medium combos
  end

  setColorContrast(color, { 1, 1, 1 })
  lg.print("x" .. combo, x, y)
end

-- Warning indicators
function UIManager:drawWarning(text, severity)
  severity = severity or "normal"

  local colors = {
    normal = { 1, 1, 0 },
    critical = { 1, 0, 0 },
    info = { 0, 1, 1 },
  }

  local color = colors[severity] or colors.normal
  local pulse = math.sin(love.timer.getTime() * 10) * 0.5 + 0.5

  lg.setFont(Game.menuFont or lg.newFont(24))
  local c = Game.highContrast and { 1, 1, 1, pulse } or { color[1], color[2], color[3], pulse }
  lg.setColor(c)

  local width = lg.getFont():getWidth(text)
  lg.print(text, lg.getWidth() / 2 - width / 2, 150)
end

-- Input hint bar ------------------------------------------------------------
function UIManager:drawInputHints()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local scale = (Game and Game.uiScale) or 1
  local padY = math.floor(10 * scale)
  local barH = math.floor(28 * scale)
  local y = h - barH - padY

  local hints = (Game and Game.inputHints and Game.inputHints[Game.lastInputType])
    or { navigate = "Arrows", select = "Enter", back = "ESC" }
  local text = string.format(
    "Navigate: %s  •  Select: %s  •  Back: %s",
    hints.navigate or "Arrows",
    hints.select or "Enter",
    hints.back or "ESC"
  )

  love.graphics.setColor(0, 0, 0, Game.highContrast and 0.8 or 0.5)
  love.graphics.rectangle("fill", 0, y, w, barH)
  love.graphics.setColor(1, 1, 1, Game.highContrast and 1 or 0.8)
  love.graphics.setFont(Game.smallFont or love.graphics.newFont(14))
  local tw = love.graphics.getFont():getWidth(text)
  love.graphics.print(text, (w - tw) / 2, y + (barH - love.graphics.getFont():getHeight()) / 2)
end

-- Kenney UI helpers (3-slice bars) -----------------------------------------
-- These functions gracefully fallback to simple rects if assets are missing.
local function getKenneyPieces()
  if Game._kenneyUI ~= nil then return Game._kenneyUI end
  local base = "assets/kenny assets/UI Pack - Sci-fi/PNG/Blue/Double/"
  local lf = love.filesystem
  local ok = lf.getInfo(base, "directory") ~= nil
  if not ok then
    Game._kenneyUI = false -- mark as unavailable
    return false
  end
  local function try(path)
    if lf.getInfo(path, "file") then
      local ok2, img = pcall(function() return AssetManager.getImage(path) end)
      return ok2 and img or nil
    end
    return nil
  end
  local pieces = {
    L   = try(base .. "bar_square_gloss_large_l.png"),
    M   = try(base .. "bar_square_gloss_large_m.png"),
    R   = try(base .. "bar_square_gloss_large_r.png"),
    btnL= try(base .. "bar_square_gloss_small_l.png"),
    btnM= try(base .. "bar_square_gloss_small_m.png"),
    btnR= try(base .. "bar_square_gloss_small_r.png"),
  }
  -- If any critical piece missing, treat as unavailable
  if not (pieces.L and pieces.M and pieces.R and pieces.btnL and pieces.btnM and pieces.btnR) then
    Game._kenneyUI = false
    return false
  end
  Game._kenneyUI = pieces
  return pieces
end

local function draw3slice(L, M, R, x, y, w, h)
  local th = M:getHeight()
  local sy = h / th
  local lw = L:getWidth() * sy
  local rw = R:getWidth() * sy
  -- left
  lg.draw(L, x, y, 0, sy, sy)
  -- middle (tiled)
  local mx = x + lw
  local mmw = M:getWidth() * sy
  local avail = math.max(0, w - lw - rw)
  local tiles = math.ceil(avail / mmw)
  for i = 1, tiles do
    local dx = mx + (i - 1) * mmw
    if dx + mmw > x + w - rw then
      -- clip last tile
      local over = dx + mmw - (x + w - rw)
      local quadW = M:getWidth() - (over / sy)
      local quad = love.graphics.newQuad(0, 0, quadW, M:getHeight(), M:getDimensions())
      lg.draw(M, quad, dx, y, 0, sy, sy)
    else
      lg.draw(M, dx, y, 0, sy, sy)
    end
  end
  -- right
  lg.draw(R, x + w - rw, y, 0, sy, sy)
end

function UIManager:drawPanel(x, y, w, h)
  local ui = getKenneyPieces()
  if ui and ui ~= false then
    draw3slice(ui.L, ui.M, ui.R, x, y, w, h)
  else
    -- Fallback: simple rounded rectangle
    lg.setColor(0, 0, 0, Game.highContrast and 0.8 or 0.5)
    lg.rectangle("fill", x, y, w, h, 6)
    lg.setColor(1, 1, 1, Game.highContrast and 1 or 0.6)
    lg.rectangle("line", x, y, w, h, 6)
  end
end

function UIManager:drawButton(x, y, w, h, label, highlighted)
  local ui = getKenneyPieces()
  if ui and ui ~= false then
    -- Ensure button art isn't tinted by previous draw colors
    lg.setColor(1, 1, 1, 1)
    draw3slice(ui.btnL, ui.btnM, ui.btnR, x, y, w, h)
    lg.setFont(Game.menuFont or lg.newFont(24))
    if highlighted then lg.setColor(1, 1, 0) else lg.setColor(0.85, 0.9, 1) end
    local tw = lg.getFont():getWidth(label)
    local th = lg.getFont():getHeight()
    lg.print(label, x + (w - tw) / 2, y + (h - th) / 2)
  else
    -- Fallback: flat button
    lg.setColor(0.1, 0.1, 0.15, 0.85)
    lg.rectangle("fill", x, y, w, h, 4)
    if highlighted then lg.setColor(1, 1, 0, 1) else lg.setColor(0.9, 0.9, 0.9, 1) end
    lg.rectangle("line", x, y, w, h, 4)
    lg.setFont(Game.menuFont or lg.newFont(24))
    local tw = lg.getFont():getWidth(label)
    local th = lg.getFont():getHeight()
    lg.print(label, x + (w - tw) / 2, y + (h - th) / 2)
  end
end

-- Mini-map (for larger levels)
function UIManager:drawMinimap(x, y, width, height, entities, viewRange)
  x = x or lg.getWidth() - width - self.margin
  y = y or self.margin
  width = width or 150
  height = height or 150
  viewRange = viewRange or 2000

  -- Background
  lg.setColor(0, 0, 0, Game.highContrast and 0.8 or 0.5)
  lg.rectangle("fill", x, y, width, height)

  -- Border
  setColorContrast({ 0, 1, 1, 0.5 }, { 1, 1, 1, 0.5 })
  lg.rectangle("line", x, y, width, height)

  -- Draw entities
  local scale = width / viewRange
  local centerX = x + width / 2
  local centerY = y + height / 2

  -- Player
  if player then
    setColorContrast({ 0, 1, 0 }, { 1, 1, 1 })
    lg.circle("fill", centerX, centerY, 3)
  end

  -- Enemies
  setColorContrast({ 1, 0, 0, 0.8 }, { 1, 1, 1, 0.8 })
  for _, entity in ipairs(entities or {}) do
    local relX = (entity.x - player.x) * scale
    local relY = (entity.y - player.y) * scale

    if math.abs(relX) < width / 2 and math.abs(relY) < height / 2 then
      lg.circle("fill", centerX + relX, centerY + relY, 2)
    end
  end
end

return UIManager
