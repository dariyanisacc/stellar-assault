local SpatialHash = require("src.spatial")
local ObjectPool = require("src.objectpool")

---Scene groups all active entities and supporting systems.
---@class Scene
local Scene = {}
Scene.__index = Scene

---Create a new empty scene.
---@return Scene
function Scene.new()
  local self = setmetatable({}, Scene)

  -- entity collections
  self.asteroids = {}
  self.aliens = {}
  self.lasers = {}
  self.alienLasers = {}
  self.explosions = {}
  self.powerups = {}
  self.powerupTexts = {}
  self.activePowerups = {}

  -- spatial grids
  self.laserGrid = SpatialHash:new(100)
  self.entityGrid = SpatialHash:new(100)

  -- object pools
  self.laserPool = ObjectPool.createLaserPool()
  self.explosionPool = ObjectPool.createExplosionPool()
  self.particlePool = ObjectPool.createParticlePool()
  self.trailPool = ObjectPool.createTrailPool()
  self.debrisPool = ObjectPool.createDebrisPool()

  return self
end

---Clear all entities and reset grids/pools.
function Scene:clear()
  self.asteroids = {}
  self.aliens = {}
  self.lasers = {}
  self.alienLasers = {}
  self.explosions = {}
  self.powerups = {}
  self.powerupTexts = {}
  self.activePowerups = {}
  if self.laserGrid then
    self.laserGrid:clear()
  end
  if self.entityGrid then
    self.entityGrid:clear()
  end
  self.laserPool:releaseAll()
  self.explosionPool:releaseAll()
  self.particlePool:releaseAll()
  self.trailPool:releaseAll()
  self.debrisPool:releaseAll()
end

return Scene
