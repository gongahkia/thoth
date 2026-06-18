local Audio = {}

local cues = {
    mine = "assets/audio/mine.wav",
    place = "assets/audio/place.wav",
    craft = "assets/audio/craft.wav",
    invalid = "assets/audio/invalid.wav",
    save = "assets/audio/save.wav",
    load = "assets/audio/load.wav",
    produce = "assets/audio/produce.wav",
    tick = "assets/audio/tick.wav",
}

function Audio.load()
    local bank = {}
    if not love or not love.audio then
        return bank
    end
    for key, path in pairs(cues) do
        if love.filesystem.getInfo(path) then
            bank[key] = love.audio.newSource(path, "static")
        end
    end
    return bank
end

function Audio.play(bank, key)
    local source = bank and bank[key]
    if source then
        source:stop()
        source:play()
    end
end

return Audio
