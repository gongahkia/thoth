local Audio = {}
local Defs = require("src.game.defs")

local cues = {
    mine = "assets/audio/mine.wav",
    place = "assets/audio/place.wav",
    craft = "assets/audio/craft.wav",
    invalid = "assets/audio/ui_error.wav",
    save = "assets/audio/ui_confirm.wav",
    load = "assets/audio/ui_back.wav",
    produce = "assets/audio/produce.wav",
    tick = "assets/audio/ui_click.wav",
    camp = "assets/audio/craft.wav",
    combat = "assets/audio/place.wav",
    danger = "assets/audio/invalid.wav",
    estate = "assets/audio/tick.wav",
    loot = "assets/audio/mine.wav",
    provision = "assets/audio/produce.wav",
    recovery = "assets/audio/load.wav",
    travel = "assets/audio/tick.wav",
    victory = "assets/audio/save.wav",
    hit_slash = "assets/audio/hit_slash.wav",
    hit_blunt = "assets/audio/hit_blunt.wav",
    hit_burn = "assets/audio/hit_burn.wav",
    hit_affliction = "assets/audio/hit_affliction.wav",
    hit_stress = "assets/audio/hit_stress.wav",
    footstep_stone = "assets/audio/footstep_stone.wav",
    footstep_wet = "assets/audio/footstep_wet.wav",
    footstep_ash = "assets/audio/footstep_ash.wav",
    ui_click = "assets/audio/ui_click.wav",
    ui_confirm = "assets/audio/ui_confirm.wav",
    ui_back = "assets/audio/ui_back.wav",
    ui_error = "assets/audio/ui_error.wav",
    dialogue_chirp_low = "assets/audio/dialogue_chirp_low.wav",
    dialogue_chirp_high = "assets/audio/dialogue_chirp_high.wav",
}

local defaultMusicManifest = {
    fadeSeconds = 1.6,
    contexts = {},
    ambient = {},
    tracks = {},
}

local statusCues = {
    { "campaign sealed", "victory" },
    { "mission complete", "victory" },
    { "combat won", "victory" },
    { "combat:", "combat" },
    { "document:", "dialogue_chirp_low" },
    { "event:", "dialogue_chirp_low" },
    { ":", "dialogue_chirp_high" },
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

local function layerBlend(fade, fadeSeconds)
    if fadeSeconds <= 0 then
        return 1
    end
    return math.min(1, (fade or 0) / fadeSeconds)
end

local function musicBlend(music)
    return layerBlend(music.fade or 0, music.fadeSeconds or 0)
end

local function ambientBlend(music)
    return layerBlend(music.ambientFade or 0, music.ambientFadeSeconds or 0)
end

local function duckFactor(music)
    if not music or (music.duckTimer or 0) <= 0 then
        return 1
    end
    local duration = math.max(0.001, music.duckDuration or music.duckTimer or 0.001)
    local pressure = math.min(1, (music.duckTimer or 0) / duration)
    return math.max(0, 1 - (music.duckAmount or 0.35) * pressure)
end

local function applyMusicSettings(bank)
    local music = bank and bank.__music
    if not music then
        return
    end
    local duck = duckFactor(music)
    local volume = sourceVolume(bank.__settings, "music") * duck
    local blend = musicBlend(music)
    if music.next then
        setVolume(music.current and music.current.source, volume * (1 - blend))
        setVolume(music.next.source, volume * blend)
    elseif music.fadingOut then
        setVolume(music.current and music.current.source, volume * (1 - blend))
    else
        setVolume(music.current and music.current.source, volume)
    end
    local ambientVolume = sourceVolume(bank.__settings, "ambient") * duck
    local ambientCurrentVolume = music.ambientCurrentVolume or 1
    local ambientNextVolume = music.ambientNextVolume or 1
    local ambient = ambientBlend(music)
    if music.ambientNext then
        setVolume(music.ambientCurrent and music.ambientCurrent.source, ambientVolume * ambientCurrentVolume * (1 - ambient))
        setVolume(music.ambientNext.source, ambientVolume * ambientNextVolume * ambient)
    elseif music.ambientFadingOut then
        setVolume(music.ambientCurrent and music.ambientCurrent.source, ambientVolume * ambientCurrentVolume * (1 - ambient))
    else
        setVolume(music.ambientCurrent and music.ambientCurrent.source, ambientVolume * ambientCurrentVolume)
    end
end

local function loadMusicBank(manifest)
    local music = {
        manifest = manifest,
        tracks = {},
        ambientTracks = {},
        fadeSeconds = manifest.fadeSeconds or 1.6,
        ambientFadeSeconds = manifest.fadeSeconds or 1.6,
        fade = 0,
        ambientFade = 0,
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
            local ambientSource = love.audio.newSource(path, track.sourceType or "stream")
            setLooping(ambientSource, track.loop ~= false)
            setVolume(ambientSource, 0)
            music.ambientTracks[key] = { key = key, source = ambientSource, loop = track.loop ~= false, meta = track }
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

function Audio.ambientTrackForContext(context, manifest)
    local config = manifest or defaultMusicManifest
    local ambient = (config.ambient or {})[context]
    if type(ambient) == "table" then
        return ambient.track, ambient.volume or 1
    end
    if type(ambient) == "string" then
        return ambient, 1
    end
    return nil, 0
end

function Audio.setAmbientContext(bank, context, fadeSeconds)
    local music = bank and bank.__music
    if not music then
        return nil
    end
    local trackKey, volume = Audio.ambientTrackForContext(context, music.manifest)
    local previousNext = music.ambientNext
    if music.ambientContext == context and music.ambientTargetKey == trackKey and music.ambientNextVolume == volume then
        return trackKey
    end
    music.ambientContext = context
    music.ambientTargetKey = trackKey
    music.ambientFade = 0
    music.ambientFadeSeconds = fadeSeconds or (music.manifest and music.manifest.fadeSeconds) or music.ambientFadeSeconds or 1.6
    music.ambientNext = trackKey and music.ambientTracks and music.ambientTracks[trackKey] or nil
    music.ambientNextKey = music.ambientNext and trackKey or nil
    music.ambientNextVolume = volume or 1
    music.ambientFadingOut = music.ambientNext == nil and music.ambientCurrent ~= nil
    if previousNext and previousNext ~= music.ambientCurrent and previousNext ~= music.ambientNext then
        stopSource(previousNext.source)
    end
    if music.ambientNext == music.ambientCurrent then
        music.ambientCurrentVolume = volume or music.ambientCurrentVolume or 1
        music.ambientNext = nil
        music.ambientNextKey = nil
        music.ambientFadingOut = false
        applyMusicSettings(bank)
        return trackKey
    end
    if music.ambientNext then
        setLooping(music.ambientNext.source, music.ambientNext.loop)
        setVolume(music.ambientNext.source, 0)
        rewindSource(music.ambientNext.source)
        playSource(music.ambientNext.source)
        if not music.ambientCurrent then
            music.ambientCurrent = music.ambientNext
            music.ambientCurrentKey = music.ambientNextKey
            music.ambientCurrentVolume = music.ambientNextVolume
            music.ambientNext = nil
            music.ambientNextKey = nil
        end
    end
    applyMusicSettings(bank)
    return trackKey
end

function Audio.setMusicContext(bank, context, fadeSeconds)
    local music = bank and bank.__music
    if not music then
        return nil
    end
    local trackKey = Audio.musicTrackForContext(context, music.manifest)
    local previousNext = music.next
    if music.context == context and music.targetKey == trackKey then
        Audio.setAmbientContext(bank, context, fadeSeconds)
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
        Audio.setAmbientContext(bank, context, fadeSeconds)
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
    Audio.setAmbientContext(bank, context, fadeSeconds)
    applyMusicSettings(bank)
    return trackKey
end

function Audio.updateMusic(bank, dt)
    local music = bank and bank.__music
    if not music then
        return
    end
    music.duckTimer = math.max(0, (music.duckTimer or 0) - (dt or 0))
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
    end
    if music.ambientNext or music.ambientFadingOut then
        music.ambientFade = math.min(music.ambientFadeSeconds or 0, (music.ambientFade or 0) + (dt or 0))
        applyMusicSettings(bank)
        if ambientBlend(music) >= 1 then
            if music.ambientNext then
                stopSource(music.ambientCurrent and music.ambientCurrent.source)
                music.ambientCurrent = music.ambientNext
                music.ambientCurrentKey = music.ambientNextKey
                music.ambientCurrentVolume = music.ambientNextVolume
                music.ambientNext = nil
                music.ambientNextKey = nil
                music.ambientFade = 0
            elseif music.ambientFadingOut then
                stopSource(music.ambientCurrent and music.ambientCurrent.source)
                music.ambientCurrent = nil
                music.ambientCurrentKey = nil
                music.ambientFadingOut = false
                music.ambientFade = 0
            end
            applyMusicSettings(bank)
        end
    end
    applyMusicSettings(bank)
end

function Audio.duck(bank, amount, seconds)
    local music = bank and bank.__music
    if not music then
        return false
    end
    if (music.duckTimer or 0) <= 0 then
        music.duckAmount = amount or 0.35
        music.duckDuration = seconds or 0.45
        music.duckTimer = seconds or 0.45
    else
        music.duckAmount = math.max(music.duckAmount or 0, amount or 0.35)
        music.duckDuration = math.max(music.duckDuration or 0, seconds or 0.45)
        music.duckTimer = math.max(music.duckTimer or 0, seconds or 0.45)
    end
    applyMusicSettings(bank)
    return true
end

local criticalEvents = {
    boss_start = true,
    boss_skill = true,
    boss_loss = true,
    combat_loss = true,
    death_door = true,
    death_save = true,
    hero_death = true,
    stress_break = true,
}

function Audio.duckForEvent(bank, event)
    if not event then
        return false
    end
    if event.crit == true then
        return Audio.duck(bank, 0.45, 0.45)
    end
    if criticalEvents[event.event] then
        return Audio.duck(bank, 0.35, 0.5)
    end
    return false
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

local function textHas(text, values)
    for _, value in ipairs(values) do
        if text:find(value, 1, true) then
            return true
        end
    end
    return false
end

function Audio.footstepCueForTile(tileId)
    local id = string.lower(tostring(tileId or ""))
    if textHas(id, { "salt", "brine", "tide", "water", "sluice", "pearl", "drown" }) then
        return "footstep_wet"
    end
    if textHas(id, { "ember", "ash", "kiln", "furnace", "coal", "cinder", "halo", "vitrified" }) then
        return "footstep_ash"
    end
    return "footstep_stone"
end

function Audio.damageCueForSkill(skill)
    if not skill then
        return nil
    end
    local text = string.lower(tostring(skill.name or ""))
    local status = skill.status and skill.status.kind
    if skill.heal or skill.stressHeal then
        return "dialogue_chirp_high"
    end
    if (skill.stress or skill.stressDamage) and not skill.damage then
        return "hit_stress"
    end
    if status == "bleed" or textHas(text, { "cut", "chop", "saw", "bite", "shear", "lunge", "hook", "slash", "sweep" }) then
        return "hit_slash"
    end
    if textHas(text, { "ember", "kiln", "coal", "cinder", "flare", "burn", "immolate", "cauter", "furnace", "glass" }) then
        return "hit_burn"
    end
    if status == "blight" or skill.disease or textHas(text, { "ink", "brine", "acid", "vial", "soot", "ash", "drown", "salt", "pearl", "cyst" }) then
        return "hit_affliction"
    end
    if skill.damage or skill.stressDamage then
        return "hit_blunt"
    end
    if skill.stress then
        return "hit_stress"
    end
    return nil
end

function Audio.cueForSkill(skillKey, enemySkill)
    local skill = enemySkill and Defs.enemySkill(skillKey) or Defs.skill(skillKey)
    return Audio.damageCueForSkill(skill)
end

function Audio.cueForEvent(event)
    if not event then
        return nil
    end
    if event.event == "move" then
        return Audio.footstepCueForTile(event.tile)
    end
    if event.event == "hero_skill" then
        return Audio.cueForSkill(event.skillKey, false)
    end
    if event.event == "enemy_skill" or event.event == "boss_skill" then
        return Audio.cueForSkill(event.skillKey, true)
    end
    if event.event == "enemy_support" then
        return "hit_stress"
    end
    if event.event == "falter" or event.event == "resolve_affliction" or event.event == "resolve_virtue" then
        return "dialogue_chirp_low"
    end
    return nil
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
