local lg = love.graphics
local lf = love.filesystem

local SpriteManager = {}
SpriteManager.__index = SpriteManager

function SpriteManager.load(path)
    local manager = setmetatable({sprites = {}, used = {}, categories = {
        enemy = {},
        boss = {},
        player = {},
        misc = {}
    }}, SpriteManager)

    local files = lf.getDirectoryItems(path)
    for _, file in ipairs(files) do
        if file:match('%.png$') then
            local key = file:gsub('%.png$', ''):gsub('%s+', '_'):lower()
            local image = lg.newImage(path .. '/' .. file)
            manager.sprites[key] = image
            manager.used[key] = false

            local lower = file:lower()
            if lower:match('^boss') then
                manager.categories.boss[key] = image
            elseif lower:match('enemy') then
                manager.categories.enemy[key] = image
            elseif lower:match('player') or lower:match('ship') then
                manager.categories.player[key] = image
            else
                manager.categories.misc[key] = image
            end
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

function SpriteManager:getCategory(name)
    return self.categories[name] or {}
end

function SpriteManager:reportUnused()
    for name, used in pairs(self.used) do
        if not used then
            print('Unused sprite: ' .. name)
        end
    end
end

function SpriteManager:reportUsage()
    local total = 0
    local usedCount = 0
    for name, sprite in pairs(self.sprites) do
        total = total + 1
        if self.used[name] then
            usedCount = usedCount + 1
        end
    end
    print(string.format('Sprite usage: %d / %d used', usedCount, total))
    self:reportUnused()
end

return SpriteManager
