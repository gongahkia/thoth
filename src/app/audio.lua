local Audio = {}
local Defs = require("src.game.defs")

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

local defaultMusicManifest = {
    fadeSeconds = 1.6,
    contexts = {},
    tracks = {},
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

local dangerCutscenes = {
    ambush = true,
    blocked = true,
    boss_defeat = true,
    danger = true,
    death_door = true,
    defeat = true,
    hero_death = true,
    resolve_affliction = true,
    stress_break = true,
}

local victoryCutscenes = {
    boss_victory = true,
    campaign_victory = true,
    victory = true,
}

local bossCutscenes = {
    boss_intro = true,
    boss_strike = true,
}

local function loadMusicManifest()
    if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo("assets/music/tracks.lua", "file") then
        local chunk = love.filesystem.load("assets/music/tracks.lua")
        if chunk then
            local ok, manifest = pcall(chunk)
            if ok and type(manifest) == "table" then
                return manifest
            end
        end
    end
    local ok, manifest = pcall(require, "assets.music.tracks")
    if ok and type(manifest) == "table" then
        return manifest
    end
    return defaultMusicManifest
end

local function sourceVolume(settings, kind)
    local master = (settings and settings.masterVolume) or 1
    return master * ((settings and settings[kind .. "Volume"]) or 1)
end

local function setVolume(source, volume)
    if source and source.setVolume then
        source:setVolume(volume)
    end
end

local function setLooping(source, loop)
    if source and source.setLooping then
        source:setLooping(loop == true)
    end
end

local function playSource(source)
    if source and source.play then
        source:play()
    end
end

local function rewindSource(source)
    if source and source.seek then
        source:seek(0)
    end
end

local function stopSource(source)
    if source and source.stop then
        source:stop()
    end
end

local function musicBlend(music)
    local fadeSeconds = music.fadeSeconds or 0
    if fadeSeconds <= 0 then
        return 1
    end
    return math.min(1, (music.fade or 0) / fadeSeconds)
end

local function applyMusicSettings(bank)
    local music = bank and bank.__music
    if not music then
        return
    end
    local volume = sourceVolume(bank.__settings, "music")
    local blend = musicBlend(music)
    if music.next then
        setVolume(music.current and music.current.source, volume * (1 - blend))
        setVolume(music.next.source, volume * blend)
    elseif music.fadingOut then
        setVolume(music.current and music.current.source, volume * (1 - blend))
    else
        setVolume(music.current and music.current.source, volume)
    end
end

local function loadMusicBank(manifest)
    local music = {
        manifest = manifest,
        tracks = {},
        fadeSeconds = manifest.fadeSeconds or 1.6,
        fade = 0,
    }
    if not (love and love.audio and love.filesystem) then
        return music
    end
    for key, track in pairs(manifest.tracks or {}) do
        local path = track.path
        if path and love.filesystem.getInfo(path, "file") then
            local source = love.audio.newSource(path, track.sourceType or "stream")
            setLooping(source, track.loop ~= false)
            setVolume(source, 0)
            music.tracks[key] = { key = key, source = source, loop = track.loop ~= false, meta = track }
        end
    end
    return music
end

function Audio.load()
    local bank = {}
    if not love or not love.audio then
        bank.__music = loadMusicBank(loadMusicManifest())
        return bank
    end
    for key, path in pairs(cues) do
        if love.filesystem.getInfo(path) then
            bank[key] = love.audio.newSource(path, "static")
        end
    end
    bank.__music = loadMusicBank(loadMusicManifest())
    return bank
end

function Audio.applySettings(bank, settings)
    if not bank then
        return
    end
    bank.__settings = settings
    local volume = sourceVolume(settings, "sfx")
    for key, source in pairs(bank) do
        if key ~= "__settings" and key ~= "__music" and source and source.setVolume then
            setVolume(source, volume)
        end
    end
    applyMusicSettings(bank)
end

function Audio.play(bank, key)
    local source = bank and bank[key]
    if source then
        Audio.applySettings(bank, bank.__settings)
        source:stop()
        source:play()
    end
end

function Audio.musicTrackForContext(context, manifest)
    local config = manifest or defaultMusicManifest
    local contexts = config.contexts or {}
    return contexts[context] or context
end

function Audio.setMusicContext(bank, context, fadeSeconds)
    local music = bank and bank.__music
    if not music then
        return nil
    end
    local trackKey = Audio.musicTrackForContext(context, music.manifest)
    local previousNext = music.next
    if music.context == context and music.targetKey == trackKey then
        return trackKey
    end
    music.context = context
    music.targetKey = trackKey
    music.fade = 0
    music.fadeSeconds = fadeSeconds or (music.manifest and music.manifest.fadeSeconds) or music.fadeSeconds or 1.6
    music.next = music.tracks[trackKey]
    music.nextKey = music.next and trackKey or nil
    music.fadingOut = music.next == nil and music.current ~= nil
    if previousNext and previousNext ~= music.current and previousNext ~= music.next then
        stopSource(previousNext.source)
    end
    if music.next == music.current then
        music.next = nil
        music.nextKey = nil
        music.fadingOut = false
        applyMusicSettings(bank)
        return trackKey
    end
    if music.next then
        setLooping(music.next.source, music.next.loop)
        setVolume(music.next.source, 0)
        rewindSource(music.next.source)
        playSource(music.next.source)
        if not music.current then
            music.current = music.next
            music.currentKey = music.nextKey
            music.next = nil
            music.nextKey = nil
        end
    end
    applyMusicSettings(bank)
    return trackKey
end

function Audio.updateMusic(bank, dt)
    local music = bank and bank.__music
    if not music then
        return
    end
    if music.next or music.fadingOut then
        music.fade = math.min(music.fadeSeconds or 0, (music.fade or 0) + (dt or 0))
        applyMusicSettings(bank)
        if musicBlend(music) >= 1 then
            if music.next then
                stopSource(music.current and music.current.source)
                music.current = music.next
                music.currentKey = music.nextKey
                music.next = nil
                music.nextKey = nil
                music.fade = 0
            elseif music.fadingOut then
                stopSource(music.current and music.current.source)
                music.current = nil
                music.currentKey = nil
                music.fadingOut = false
                music.fade = 0
            end
            applyMusicSettings(bank)
        end
    else
        applyMusicSettings(bank)
    end
end

local function combatHasBoss(sim)
    for _, enemy in ipairs((sim and sim.combat and sim.combat.enemies) or {}) do
        local def = Defs.enemy(enemy.kind)
        if def and def.boss then
            return true
        end
    end
    return false
end

function Audio.contextForState(app, sim)
    local uiState = app and app.uiState or "title"
    local cutscene = app and app.cutscene
    if cutscene and victoryCutscenes[cutscene.kind] then
        return "victory"
    end
    if cutscene and dangerCutscenes[cutscene.kind] then
        return "expedition_tense"
    end
    if cutscene and bossCutscenes[cutscene.kind] then
        return "boss"
    end
    if uiState == "credits" then
        return "credits"
    end
    if uiState == "gameover" then
        local campaign = sim and sim.estate and sim.estate.campaign
        return campaign and campaign.victory and "victory" or "gameover"
    end
    if uiState == "settings" or uiState == "title" or uiState == "journal" then
        return uiState
    end
    if uiState ~= "game" then
        return "estate"
    end
    if sim and sim.mode == "combat" then
        return combatHasBoss(sim) and "boss" or "combat"
    end
    if sim and sim.mode == "expedition" then
        local expedition = sim.expedition or {}
        if expedition.camping then
            return "expedition"
        end
        if (expedition.torch or 100) < 35 or (expedition.noise or 0) >= 6 then
            return "expedition_tense"
        end
        return "expedition"
    end
    return "estate"
end

function Audio.updateForState(bank, dt, app, sim)
    local context = Audio.contextForState(app, sim)
    Audio.setMusicContext(bank, context)
    Audio.updateMusic(bank, dt)
    return context
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
