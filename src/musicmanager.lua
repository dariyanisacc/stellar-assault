-- Dynamic music manager with crossfade support
local MusicManager = {}
MusicManager.__index = MusicManager

function MusicManager:new()
    local self = setmetatable({}, MusicManager)
    
    self.tracks = {}
    self.currentTrack = nil
    self.targetTrack = nil
    self.fadeSpeed = 0.5  -- volume change per second
    self.masterVolume = 1.0
    
    return self
end

function MusicManager:addTrack(name, source)
    if source then
        self.tracks[name] = {
            source = source,
            volume = 0,
            targetVolume = 0
        }
        source:setLooping(true)
        source:setVolume(0)
    end
end

function MusicManager:play(trackName, fadeIn)
    local track = self.tracks[trackName]
    if not track then return end
    
    -- If already playing this track, just ensure volume
    if self.currentTrack == trackName then
        track.targetVolume = 1.0
        return
    end
    
    -- Fade out current track
    if self.currentTrack and self.tracks[self.currentTrack] then
        self.tracks[self.currentTrack].targetVolume = 0
    end
    
    -- Start new track
    self.currentTrack = trackName
    track.targetVolume = 1.0
    
    if not track.source:isPlaying() then
        track.source:play()
    end
    
    if not fadeIn then
        track.volume = 1.0
        track.source:setVolume(self.masterVolume)
    end
end

function MusicManager:crossfade(fromTrack, toTrack, duration)
    if self.tracks[fromTrack] then
        self.tracks[fromTrack].targetVolume = 0
    end
    
    if self.tracks[toTrack] then
        self.tracks[toTrack].targetVolume = 1.0
        if not self.tracks[toTrack].source:isPlaying() then
            self.tracks[toTrack].source:play()
        end
    end
    
    self.currentTrack = toTrack
    self.fadeSpeed = 1.0 / (duration or 1.0)
end

function MusicManager:update(dt)
    for name, track in pairs(self.tracks) do
        -- Update volume
        if track.volume < track.targetVolume then
            track.volume = math.min(track.volume + self.fadeSpeed * dt, track.targetVolume)
        elseif track.volume > track.targetVolume then
            track.volume = math.max(track.volume - self.fadeSpeed * dt, track.targetVolume)
        end
        
        -- Apply volume
        track.source:setVolume(track.volume * self.masterVolume)
        
        -- Stop tracks that have faded out
        if track.volume <= 0 and track.source:isPlaying() then
            track.source:stop()
        end
    end
end

function MusicManager:setMasterVolume(volume)
    self.masterVolume = volume
    for _, track in pairs(self.tracks) do
        track.source:setVolume(track.volume * self.masterVolume)
    end
end

function MusicManager:stop()
    for _, track in pairs(self.tracks) do
        track.targetVolume = 0
    end
end

function MusicManager:pause()
    for _, track in pairs(self.tracks) do
        if track.source:isPlaying() then
            track.source:pause()
        end
    end
end

function MusicManager:resume()
    for name, track in pairs(self.tracks) do
        if track.volume > 0 and not track.source:isPlaying() then
            track.source:play()
        end
    end
end

return MusicManager