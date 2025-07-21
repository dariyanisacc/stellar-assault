local lg = love.graphics
local lf = love.filesystem

local SpriteManager = {}
SpriteManager.__index = SpriteManager

function SpriteManager.load(path)
    local manager = setmetatable({sprites = {}, used = {}}, SpriteManager)
    local files = lf.getDirectoryItems(path)
    for _, file in ipairs(files) do
        if file:match('%.png$') then
            local key = file:gsub('%.png$', ''):gsub('%s+', '_'):lower()
            local image = lg.newImage(path .. '/' .. file)
            manager.sprites[key] = image
            manager.used[key] = false
        end
    end
    return manager
end

function SpriteManager:get(name)
    local sprite = self.sprites[name]
    if sprite then
        self.used[name] = true
    end
    return sprite
end

function SpriteManager:reportUnused()
    for name, used in pairs(self.used) do
        if not used then
            print('Unused sprite: ' .. name)
        end
    end
end

return SpriteManager
