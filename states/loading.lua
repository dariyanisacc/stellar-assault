-- Loading State
local lg = love.graphics
local Game = require("src.game")

local LoadingState = {}

function LoadingState:enter(params)
  self.nextState = params and params.nextState or "intro"
  self.done = false
  -- Keep loading snappy: defer heavy audio/video preloads to first use.
  -- We avoid calling AssetManager.loadAll() here because it streams many
  -- audio sources and videos, which can stall startup on some systems.
  -- Images needed for menus are already fetched during love.load.
  self.done = true
  self.timer = 0.2
end

function LoadingState:update(dt)
  if self.done then
    self.timer = self.timer - dt
    if self.timer <= 0 then
      stateManager:switch(self.nextState)
    end
  end
end

function LoadingState:draw()
  lg.clear(0, 0, 0)
  lg.setColor(1, 1, 1, 1)
  lg.printf("Loading...", 0, lg.getHeight() / 2, lg.getWidth(), "center")
end

return LoadingState
