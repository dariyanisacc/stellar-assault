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
            local image = lg.newImage(path .. '/' .. file)
            local raw_key = file:gsub('%.png$', '')
            local lower_raw_key = raw_key:lower()
            local global_key = lower_raw_key:gsub('%s+', '_')

            manager.sprites[global_key] = image
            manager.used[global_key] = false

            if lower_raw_key:match('^boss') then
                manager.categories.boss[global_key] = image
            elseif lower_raw_key:match('^enemy') then
                local category_key = lower_raw_key:gsub('^enemy%s*', '')
                manager.categories.enemy[category_key] = image
            elseif lower_raw_key:match('player') or lower_raw_key:match('ship') then
                local category_key = lower_raw_key:match('.* (%w+)$') or lower_raw_key
                manager.categories.player[category_key] = image
            else
                manager.categories.misc[global_key] = image
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
