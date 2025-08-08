-- Loading State
local lg = love.graphics
local Game = require("src.game")

local LoadingState = {}

function LoadingState:enter(params)
  self.nextState = params and params.nextState or "intro"
  self.done = false
  -- Preload all discoverable assets. This is safe to call even if
  -- some asset folders are missing; the AssetManager checks existence.
  if Game.assetManager and Game.assetManager.loadAll then
    Game.assetManager.loadAll()
  end
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
