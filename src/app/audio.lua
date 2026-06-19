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
    camp = "assets/audio/craft.wav",
    combat = "assets/audio/place.wav",
    danger = "assets/audio/invalid.wav",
    estate = "assets/audio/tick.wav",
    loot = "assets/audio/mine.wav",
    provision = "assets/audio/produce.wav",
    recovery = "assets/audio/load.wav",
    travel = "assets/audio/tick.wav",
    victory = "assets/audio/save.wav",
}

local statusCues = {
    { "campaign sealed", "victory" },
    { "mission complete", "victory" },
    { "combat won", "victory" },
    { "combat:", "combat" },
    { "ambush", "danger" },
    { "collapsed", "danger" },
    { "death", "danger" },
    { "fell", "danger" },
    { "faltered", "danger" },
    { "hunger", "danger" },
    { "refused", "danger" },
    { "blocked", "danger" },
    { "camp", "camp" },
    { "resolved", "loot" },
    { "activated", "loot" },
    { "scouted", "loot" },
    { "bought", "estate" },
    { "recruited", "estate" },
    { "recovered", "recovery" },
    { "trained", "estate" },
    { "upgraded", "estate" },
    { "used", "provision" },
    { "moved", "travel" },
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

function Audio.cueForStatus(message)
    local text = string.lower(tostring(message or ""))
    for _, rule in ipairs(statusCues) do
        if string.find(text, rule[1], 1, true) then
            return rule[2]
        end
    end
    return nil
end

return Audio
