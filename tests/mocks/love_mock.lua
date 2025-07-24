-- Mock Love2D framework for testing
local love_mock = {}

-- Mock graphics module
love_mock.graphics = {
    newImage = function(path) return {path = path, type = "image"} end,
    newFont = function(size) return {size = size, type = "font"} end,
    setFont = function(font) end,
    setColor = function(r, g, b, a) end,
    draw = function(...) end,
    rectangle = function(...) end,
    circle = function(...) end,
    line = function(...) end,
    print = function(...) end,
    getWidth = function() return 1280 end,
    getHeight = function() return 720 end,
    getDimensions = function() return 1280, 720 end,
    push = function() end,
    pop = function() end,
    translate = function(x, y) end,
    scale = function(sx, sy) end,
    setLineWidth = function(width) end,
    setDefaultFilter = function(min, mag) end,
    setBackgroundColor = function(r, g, b) end,
    clear = function(...) end,
    origin = function() end,
    setShader = function(shader) end,
    newShader = function(code) return {type = "shader"} end,
    newParticleSystem = function(image, buffer)
        local ps = {
            image = image,
            buffer = buffer or 100,
            count = 0,
            emit = function(self, num) self.count = self.count + (num or 1) end,
            update = function(self, dt)
                if self.count > 0 then
                    self.count = math.max(0, self.count - dt * 60)
                end
            end,
            getCount = function(self) return self.count end,
            setPosition = function() end,
            setParticleLifetime = function() end,
            setSizes = function() end,
            setSpeed = function() end,
            setSpread = function() end,
            setLinearAcceleration = function() end,
            setColors = function() end,
            reset = function(self) self.count = 0 end,
        }
        return ps
    end,
}

-- Mock audio module
love_mock.audio = {
    newSource = function(path, type)
        return {
            path = path,
            type = type or "stream",
            playing = false,
            volume = 1,
            looping = false,
            position = {0, 0, 0},
            relative = false,
            refDistance = 1,
            maxDistance = 10000,
            play = function(self) self.playing = true end,
            stop = function(self) self.playing = false end,
            pause = function(self) self.playing = false end,
            setVolume = function(self, v) self.volume = v end,
            setLooping = function(self, l) self.looping = l end,
            setPosition = function(self, x, y, z) self.position = {x, y, z} end,
            setRelative = function(self, r) self.relative = r end,
            setAttenuationDistances = function(self, ref, max)
                self.refDistance = ref
                self.maxDistance = max
            end,
            isPlaying = function(self) return self.playing end,
            clone = function(self)
                local clone = {}
                for k, v in pairs(self) do clone[k] = v end
                return clone
            end
        }
    end,
    stop = function() end,
    setVolume = function(volume) end,
}

-- Mock timer module
love_mock.timer = {
    getTime = function() return os.clock() end,
    getDelta = function() return 0.016 end, -- ~60 FPS
    getFPS = function() return 60 end,
}

-- Mock keyboard module
love_mock.keyboard = {
    isDown = function(key) return false end,
    setKeyRepeat = function(enable) end,
}

-- Mock mouse module
love_mock.mouse = {
    getPosition = function() return 0, 0 end,
    getX = function() return 0 end,
    getY = function() return 0 end,
    isDown = function(button) return false end,
}

-- Mock joystick module
love_mock.joystick = {
    getJoysticks = function() return {} end
    getJoystickCount = function() return 0 end,
}

-- Mock window module
love_mock.window = {
    setMode = function(width, height, flags) return true end,
    setFullscreen = function(fullscreen) return true end,
    getFullscreen = function() return false end,
    getMode = function() return 1280, 720, {fullscreen = false} end,
    setTitle = function(title) end,
    getDesktopDimensions = function() return 1920, 1080 end,
    toPixels = function(value) return value end,
    fromPixels = function(value) return value end,
    getDPIScale = function() return 1 end,
}

-- Mock math module
love_mock.math = {
    random = function(min, max)
        if min and max then
            return math.random(min, max)
        elseif min then
            return math.random(min)
        else
            return math.random()
        end
    end,
    newRandomGenerator = function()
        return {
            random = love_mock.math.random,
            setSeed = function(self, seed) math.randomseed(seed) end,
        }
    end,
}

-- Mock filesystem module
love_mock.filesystem = {
    exists = function(path) return false end,
    read = function(path) return "test data", 9 end,
    write = function(path, data) end,
    append = function(path, data) end,
    -- Assume additional mocks from main if needed
}

return love_mock