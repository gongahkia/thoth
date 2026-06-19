local Defs = require("src.game.defs")
local Settings = require("src.app.settings")

local Render = {}
local state = {
    loaded = false,
    headless = false,
    g3d = nil,
    assets = {},
}
local cameraPitch = math.rad(30)
local cameraDistance = 26
local cameraViewSize = 24
local baseYaw = math.rad(45)
local visibleRadius = 10
local atlasColumns = 8
local atlasRows = 5

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function clearList(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local function panel(x, y, w, h, alpha)
    love.graphics.setColor(0.055, 0.06, 0.07, alpha or 0.88)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.22, 0.24, 0.24, 0.9)
    love.graphics.rectangle("line", x, y, w, h)
end

local function drawMeter(x, y, w, h, ratio, color)
    love.graphics.setColor(0.08, 0.09, 0.09, 1)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.rectangle("fill", x, y, w * clamp(ratio or 0, 0, 1), h)
    love.graphics.setColor(0.24, 0.26, 0.24, 1)
    love.graphics.rectangle("line", x, y, w, h)
end

local function compactStacks(stacks)
    local parts = {}
    for _, stack in ipairs(stacks or {}) do
        local item = Defs.item(stack.item)
        if item then
            parts[#parts + 1] = (item.short or string.sub(stack.item, 1, 1)) .. tostring(stack.count or 0)
        end
    end
    return table.concat(parts, " ")
end

local function readText(path)
    if love and love.filesystem and love.filesystem.getInfo(path) then
        return love.filesystem.read(path)
    end
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local text = file:read("*a")
    file:close()
    return text
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function stripBackticks(value)
    value = trim(value)
    if value:sub(1, 1) == "`" and value:sub(-1) == "`" then
        return value:sub(2, -2)
    end
    return value
end

local function statMapText(map, skip)
    local keys = {}
    for key in pairs(map or {}) do
        if not (skip and skip[key]) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = key .. " " .. tostring(map[key])
    end
    return #parts > 0 and table.concat(parts, ", ") or "-"
end

local function rosterHasTrinket(sim, trinketKey)
    for _, hero in ipairs((sim and sim.estate and sim.estate.roster) or {}) do
        for _, equipped in ipairs(hero.trinkets or {}) do
            if equipped == trinketKey then
                return true
            end
        end
    end
    return false
end

local function ownedSetPieces(sim, setDef)
    local count = 0
    for _, trinketKey in ipairs((setDef and setDef.pieces) or {}) do
        if ((sim.estate.trinkets or {})[trinketKey] or 0) > 0 or rosterHasTrinket(sim, trinketKey) then
            count = count + 1
        end
    end
    return count
end

function Render.trinketTooltip(sim, trinketKey)
    local trinket = Defs.trinket(trinketKey)
    if not trinket then
        return {}
    end
    local lines = { trinket.name .. " value " .. tostring(trinket.value or 0), "stats: " .. statMapText(trinket, { name = true, short = true, value = true }) }
    local equippedCounts = sim and sim.trinketSetCounts and sim:trinketSetCounts() or {}
    for _, setKey in ipairs(Defs.trinketSetOrder or {}) do
        local setDef = Defs.trinketSet(setKey)
        if setDef then
            for _, piece in ipairs(setDef.pieces or {}) do
                if piece == trinketKey then
                    lines[#lines + 1] = "set: " .. setDef.name .. " owned " .. ownedSetPieces(sim, setDef) .. "/4 equipped " .. tostring(equippedCounts[setKey] or 0) .. "/4"
                    lines[#lines + 1] = "2pc " .. statMapText(setDef.twoPiece) .. " / 4pc " .. statMapText(setDef.fourPiece) .. " / cost " .. statMapText(setDef.cost)
                    break
                end
            end
        end
    end
    return lines
end

local function clamp01(value)
    return clamp(value or 0, 0, 1)
end

local function smooth(value)
    value = clamp01(value)
    return value * value * (3 - 2 * value)
end

local function phase(progress, startAt, endAt)
    local span = math.max(0.001, (endAt or 1) - (startAt or 0))
    return smooth((progress - (startAt or 0)) / span)
end

local function containsText(text, needle)
    return string.find(string.lower(tostring(text or "")), needle, 1, true) ~= nil
end

local function actorSide(actor, sim)
    if not actor or actor == "" or not sim then
        return "ally"
    end
    for _, hero in ipairs((sim.estate and sim.estate.roster) or {}) do
        if hero.name == actor then
            return "ally"
        end
    end
    if sim.combat then
        for _, enemy in ipairs(sim.combat.enemies or {}) do
            local def = Defs.enemy(enemy.kind)
            if def and def.name == actor then
                return "enemy"
            end
        end
    end
    return "ally"
end

local cutsceneProfiles = {
    default = { mood = "neutral", focus = "stage", beat = "hold", camera = "still", caption = "Event", intensity = 0.65, accent = { 0.7, 0.58, 0.35 } },
    idle = { mood = "watch", focus = "party", beat = "idle", camera = "still", caption = "Combat", intensity = 0.35, accent = { 0.42, 0.54, 0.36 } },
    intro = { mood = "threat", focus = "enemy", beat = "arrival", camera = "push", caption = "Encounter", duration = 0.92, intensity = 0.75, accent = { 0.72, 0.2, 0.12 } },
    boss_intro = { mood = "boss", focus = "boss", beat = "reveal", camera = "quake", caption = "Boss Encounter", duration = 1.18, intensity = 1.2, accent = { 0.86, 0.08, 0.08 } },
    ambush = { mood = "panic", focus = "enemy", beat = "snap", camera = "snap", caption = "Ambush", duration = 1.0, intensity = 1.05, accent = { 0.9, 0.12, 0.08 } },
    strike = { mood = "action", focus = "actor", beat = "strike", camera = "hit", caption = "Skill", duration = 0.72, intensity = 0.9, accent = { 0.96, 0.72, 0.32 } },
    boss_strike = { mood = "boss", focus = "boss", beat = "smite", camera = "quake", caption = "Boss Skill", duration = 0.95, intensity = 1.25, accent = { 0.9, 0.08, 0.06 } },
    victory = { mood = "resolve", focus = "party", beat = "triumph", camera = "lift", caption = "Victory", duration = 0.86, intensity = 0.8, accent = { 0.86, 0.68, 0.24 } },
    boss_victory = { mood = "seal", focus = "party", beat = "triumph", camera = "lift", caption = "Boss Felled", duration = 1.2, intensity = 1.05, accent = { 0.92, 0.74, 0.18 } },
    campaign_victory = { mood = "seal", focus = "party", beat = "seal", camera = "lift", caption = "Campaign Sealed", duration = 1.25, intensity = 1.1, accent = { 0.72, 0.82, 0.42 } },
    defeat = { mood = "doom", focus = "enemy", beat = "collapse", camera = "sink", caption = "Defeat", duration = 0.95, intensity = 1.0, accent = { 0.78, 0.08, 0.06 } },
    boss_defeat = { mood = "doom", focus = "boss", beat = "collapse", camera = "sink", caption = "Annihilation", duration = 1.2, intensity = 1.22, accent = { 0.82, 0.04, 0.04 } },
    retreat = { mood = "flight", focus = "party", beat = "exit", camera = "pull", caption = "Retreat", duration = 0.78, intensity = 0.7, accent = { 0.46, 0.58, 0.48 } },
    blocked = { mood = "panic", focus = "enemy", beat = "block", camera = "hit", caption = "Blocked", duration = 0.72, intensity = 0.9, accent = { 0.86, 0.08, 0.06 } },
    death_door = { mood = "threshold", focus = "actor", beat = "threshold", camera = "sink", caption = "Death's Door", duration = 0.85, intensity = 1.05, accent = { 0.72, 0.08, 0.08 } },
    death_save = { mood = "resolve", focus = "actor", beat = "revive", camera = "lift", caption = "Deathblow Resisted", duration = 0.85, intensity = 0.9, accent = { 0.86, 0.78, 0.38 } },
    hero_death = { mood = "doom", focus = "actor", beat = "fall", camera = "sink", caption = "Hero Lost", duration = 1.1, intensity = 1.15, accent = { 0.8, 0.06, 0.06 } },
    resolve_virtue = { mood = "virtue", focus = "actor", beat = "resolve", camera = "lift", caption = "Virtue", duration = 0.95, intensity = 0.95, accent = { 0.62, 0.82, 0.34 } },
    resolve_affliction = { mood = "affliction", focus = "actor", beat = "fracture", camera = "snap", caption = "Affliction", duration = 0.95, intensity = 1.05, accent = { 0.72, 0.12, 0.52 } },
    stress_break = { mood = "affliction", focus = "actor", beat = "break", camera = "sink", caption = "Stress Break", duration = 0.95, intensity = 1.0, accent = { 0.7, 0.12, 0.38 } },
    affliction_act = { mood = "affliction", focus = "actor", beat = "lash", camera = "snap", caption = "Afflicted Action", duration = 0.95, intensity = 0.95, accent = { 0.66, 0.1, 0.44 } },
    falter = { mood = "dazed", focus = "actor", beat = "stagger", camera = "hit", caption = "Falter", duration = 0.62, intensity = 0.65, accent = { 0.64, 0.62, 0.52 } },
    hero_hold = { mood = "guard", focus = "actor", beat = "hold", camera = "still", caption = "Hold", duration = 0.62, intensity = 0.55, accent = { 0.62, 0.62, 0.5 } },
    danger = { mood = "doom", focus = "enemy", beat = "omen", camera = "sink", caption = "Danger", duration = 0.85, intensity = 0.95, accent = { 0.82, 0.08, 0.06 } },
}

local function sceneAccent(scene)
    return (scene and scene.accent) or { 0.74, 0.48, 0.22 }
end

local function scene(kind, title, options)
    local profile = cutsceneProfiles[kind] or cutsceneProfiles.default
    local result = {
        kind = kind,
        title = title,
        elapsed = 0,
    }
    for key, value in pairs(profile) do
        result[key] = value
    end
    for key, value in pairs(options or {}) do
        result[key] = value
    end
    result.side = result.side or "ally"
    result.duration = result.duration or 0.85
    return result
end

function Render.prepareUi(app)
    app.ui = app.ui or {}
    app.ui.skillButtons = app.ui.skillButtons or {}
    app.ui.heroButtons = app.ui.heroButtons or {}
    app.ui.enemyButtons = app.ui.enemyButtons or {}
    app.ui.itemButtons = app.ui.itemButtons or {}
    app.ui.missionButtons = app.ui.missionButtons or {}
    app.ui.recruitButtons = app.ui.recruitButtons or {}
    app.ui.provisionButtons = app.ui.provisionButtons or {}
    app.ui.estateActionButtons = app.ui.estateActionButtons or {}
    app.ui.rosterButtons = app.ui.rosterButtons or {}
    app.ui.partyRankSlots = app.ui.partyRankSlots or {}
    app.ui.curioButtons = app.ui.curioButtons or {}
    app.ui.campSkillButtons = app.ui.campSkillButtons or {}
    app.ui.campHeroButtons = app.ui.campHeroButtons or {}
    app.ui.pauseButtons = app.ui.pauseButtons or {}
    app.ui.confirmButtons = app.ui.confirmButtons or {}
    app.ui.gameOverButtons = app.ui.gameOverButtons or {}
    app.ui.creditsButtons = app.ui.creditsButtons or {}
    app.ui.journalButtons = app.ui.journalButtons or {}
    app.ui.tutorialButtons = app.ui.tutorialButtons or {}
    app.ui.titleButtons = app.ui.titleButtons or {}
    app.ui.settingsButtons = app.ui.settingsButtons or {}
    clearList(app.ui.skillButtons)
    clearList(app.ui.heroButtons)
    clearList(app.ui.enemyButtons)
    clearList(app.ui.itemButtons)
    clearList(app.ui.missionButtons)
    clearList(app.ui.recruitButtons)
    clearList(app.ui.provisionButtons)
    clearList(app.ui.estateActionButtons)
    clearList(app.ui.rosterButtons)
    clearList(app.ui.partyRankSlots)
    clearList(app.ui.curioButtons)
    clearList(app.ui.campSkillButtons)
    clearList(app.ui.campHeroButtons)
    clearList(app.ui.pauseButtons)
    clearList(app.ui.confirmButtons)
    clearList(app.ui.gameOverButtons)
    clearList(app.ui.creditsButtons)
    clearList(app.ui.journalButtons)
    clearList(app.ui.tutorialButtons)
    clearList(app.ui.titleButtons)
    clearList(app.ui.settingsButtons)
end

local function eventCaption(event, fallback)
    local value = event and (event.skill or event.actor)
    return value and tostring(value) or fallback
end

local function encounterCaption(event, fallback)
    local enemies = event and event.enemies
    return enemies and enemies[1] and tostring(enemies[1]) or fallback
end

function Render.cutsceneForEvent(event, sim)
    event = type(event) == "table" and event or { message = event }
    local text = tostring(event.message or "")
    if text == "" then
        return nil
    end
    local eventKind = event.event
    if eventKind == "combat_start" then
        return scene("intro", text, { side = "enemy", duration = 0.9, encounter = event.encounter, enemies = event.enemies, caption = encounterCaption(event, "Encounter") })
    end
    if eventKind == "boss_start" then
        return scene("boss_intro", text, { side = "enemy", duration = 1.15, encounter = event.encounter, enemies = event.enemies, boss = true, caption = encounterCaption(event, "Boss Encounter") })
    end
    if eventKind == "ambush_start" then
        return scene("ambush", text, { side = "enemy", duration = 1.0, encounter = event.encounter, enemies = event.enemies, caption = encounterCaption(event, "Ambush") })
    end
    if eventKind == "hero_skill" then
        return scene("strike", text, { side = "ally", duration = 0.72, actor = event.actor, skill = event.skill, caption = eventCaption(event, "Skill") })
    end
    if eventKind == "enemy_skill" or eventKind == "boss_skill" then
        return scene(eventKind == "boss_skill" and "boss_strike" or "strike", text, { side = "enemy", duration = eventKind == "boss_skill" and 0.95 or 0.72, actor = event.actor, skill = event.skill, boss = event.boss, caption = eventCaption(event, eventKind == "boss_skill" and "Boss Skill" or "Enemy Skill") })
    end
    if eventKind == "combat_win" or eventKind == "boss_win" then
        return scene(eventKind == "boss_win" and "boss_victory" or "victory", text, { side = "ally", duration = eventKind == "boss_win" and 1.2 or 0.86, encounter = event.encounter, enemies = event.enemies, boss = event.boss, caption = eventKind == "boss_win" and "Boss Felled" or "Victory" })
    end
    if eventKind == "combat_loss" or eventKind == "boss_loss" then
        return scene(eventKind == "boss_loss" and "boss_defeat" or "defeat", text, { side = "enemy", duration = eventKind == "boss_loss" and 1.2 or 0.95, encounter = event.encounter, enemies = event.enemies, boss = event.boss, caption = eventKind == "boss_loss" and "Annihilation" or "Defeat" })
    end
    if eventKind == "retreat" then
        return scene("retreat", text, { side = "ally", duration = 0.78, encounter = event.encounter, boss = event.boss })
    end
    if eventKind == "retreat_blocked" then
        return scene("blocked", text, { side = "enemy", duration = 0.72 })
    end
    if eventKind == "death_door" or eventKind == "death_save" or eventKind == "hero_death" then
        return scene(eventKind, text, { side = "ally", duration = eventKind == "hero_death" and 1.1 or 0.85, actor = event.actor, caption = eventCaption(event, nil) })
    end
    if eventKind == "resolve_virtue" or eventKind == "resolve_affliction" or eventKind == "stress_break" or eventKind == "affliction_act" then
        return scene(eventKind, text, { side = "ally", duration = 0.95, actor = event.actor, caption = eventCaption(event, nil) })
    end
    if eventKind == "falter" or eventKind == "hero_hold" then
        return scene(eventKind, text, { side = event.side or "ally", duration = 0.62, actor = event.actor, caption = eventCaption(event, nil) })
    end
    if containsText(text, "combat:") then
        return scene("intro", text, { side = "enemy", duration = 0.9 })
    end
    if containsText(text, "campaign sealed") then
        return scene("campaign_victory", text, { side = "ally", duration = 1.25 })
    end
    if containsText(text, "combat won") or containsText(text, "mission complete") then
        return scene("victory", text, { side = "ally", duration = 0.86 })
    end
    if containsText(text, "party lost") or containsText(text, "fell") or containsText(text, "death") or containsText(text, "ambush") or containsText(text, "faltered") then
        return scene("danger", text, { side = "enemy", duration = 0.85 })
    end
    local actor = string.match(text, "^(.-) used ")
    if actor then
        return scene("strike", text, { actor = actor, side = actorSide(actor, sim), duration = 0.75 })
    end
    return nil
end

function Render.cutsceneForStatus(message, sim)
    return Render.cutsceneForEvent({ message = message }, sim)
end

function Render.idleCombatScene(sim)
    if not (sim and sim.mode == "combat" and sim.combat) then
        return nil
    end
    local active = sim:activeHero()
    return scene("idle", active and (active.name .. " acts") or "enemy turn", { side = "ally", duration = 1 })
end

function Render.advanceCutscene(app, dt)
    if not (app and app.cutscene) then
        return
    end
    local cutscene = app.cutscene
    cutscene.elapsed = (cutscene.elapsed or 0) + (dt or 0)
    if cutscene.elapsed >= (cutscene.duration or 0.75) then
        app.cutscene = nil
    end
end

function Render.rotateDelta(dx, dy, rotation)
    rotation = (rotation or 0) % 4
    if rotation == 1 then
        return -dy, dx
    end
    if rotation == 2 then
        return -dx, -dy
    end
    if rotation == 3 then
        return dy, -dx
    end
    return dx, dy
end

function Render.unrotateDelta(rx, ry, rotation)
    rotation = (rotation or 0) % 4
    if rotation == 1 then
        return ry, -rx
    end
    if rotation == 2 then
        return -rx, -ry
    end
    if rotation == 3 then
        return -ry, rx
    end
    return rx, ry
end

function Render.projectIso(view, x, y)
    local rx, ry = Render.rotateDelta(x - view.originX, y - view.originY, view.rotation)
    return view.centerX + (rx - ry) * view.halfW, view.centerY + (rx + ry) * view.halfH
end

function Render.screenToWorld(view, x, y)
    local sx = x - view.centerX
    local sy = y - view.centerY
    local rx = (sx / view.halfW + sy / view.halfH) / 2
    local ry = (sy / view.halfH - sx / view.halfW) / 2
    local dx, dy = Render.unrotateDelta(rx, ry, view.rotation)
    return math.floor(view.originX + dx + 0.5), math.floor(view.originY + dy + 0.5)
end

local function newSolidImage(r, g, b, a)
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, r, g, b, a or 1)
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return image
end

local function loadImage(path)
    if not love.filesystem.getInfo(path, "file") then
        return nil
    end
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

local function newImageFromData(data)
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return image
end

function Render.load()
    state.loaded = true
    state.headless = not (love and love.graphics)
    state.assets = {}
    state.g3d = nil
    state.loadError = nil
    if state.headless then
        Render.state = state
        return state
    end
    local ok, g3dOrErr = pcall(require, "vendor.g3d.g3d")
    if not ok then
        state.loadError = g3dOrErr
        Render.state = state
        return state
    end
    state.g3d = g3dOrErr
    state.assets.white = newSolidImage(1, 1, 1, 1)
    state.assets.enemy = newSolidImage(0.68, 0.16, 0.18, 1)
    state.assets.alpha = newSolidImage(0.58, 0.12, 0.46, 1)
    state.assets.boss = newSolidImage(0.82, 0.22, 0.12, 1)
    state.assets.spriteAtlas = loadImage("assets/sprites/thoth_atlas.png")
    state.g3d.camera.updateProjectionMatrix()
    state.g3d.camera.updateViewMatrix()
    Render.state = state
    return state
end

local function tileVertex(x, y, z, u)
    return {x, y, z, u, 0.5, 0, 0, 1, 1, 1, 1, 1}
end

local function billboardVertex(x, y, z, u, v)
    return {x, y, z, u, v, 0, 0, 1, 1, 1, 1, 1}
end

local function pushTileQuad(vertices, x, y, z, u)
    local gap = 0.03
    local left = x + gap
    local right = x + 1 - gap
    local top = y + gap
    local bottom = y + 1 - gap
    local a = tileVertex(left, top, z, u)
    local b = tileVertex(right, top, z, u)
    local c = tileVertex(right, bottom, z, u)
    local d = tileVertex(left, bottom, z, u)
    vertices[#vertices + 1] = a
    vertices[#vertices + 1] = b
    vertices[#vertices + 1] = c
    vertices[#vertices + 1] = a
    vertices[#vertices + 1] = c
    vertices[#vertices + 1] = d
end

local function torchLevel(sim)
    if sim and sim.expedition and sim.expedition.torch then
        return clamp(sim.expedition.torch, 0, 100)
    end
    return 100
end

local function lightProfile(sim)
    local torch = torchLevel(sim)
    local ratio = torch / 100
    return {
        torch = torch,
        ambient = 0.2 + ratio * 0.38,
        radius = 3.5 + ratio * 9.5,
    }
end

local function lightAt(sim, x, y, profile)
    if not (sim and sim.player) then
        return 1
    end
    profile = profile or lightProfile(sim)
    local dx = x - sim.player.x
    local dy = y - sim.player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local falloff = 1 - clamp(distance / profile.radius, 0, 1)
    falloff = falloff * falloff * (3 - 2 * falloff)
    return clamp(profile.ambient + falloff * (1 - profile.ambient), 0, 1)
end

local function litTileColor(rgb, light)
    local r = clamp((rgb[1] / 255) * light * 1.08, 0, 1)
    local g = clamp((rgb[2] / 255) * light * (0.9 + light * 0.1), 0, 1)
    local b = clamp((rgb[3] / 255) * light * (0.78 + light * 0.22), 0, 1)
    return r, g, b, 1
end

local function buildWorldTileModel(sim, profile)
    local vertices = {}
    local z = sim.player.z or 0
    local minX = sim.player.x - visibleRadius
    local maxX = sim.player.x + visibleRadius
    local minY = sim.player.y - visibleRadius
    local maxY = sim.player.y + visibleRadius
    local width = maxX - minX + 1
    local height = maxY - minY + 1
    local data = love.image.newImageData(width * height, 1)
    local index = 0
    for y = minY, maxY do
        for x = minX, maxX do
            index = index + 1
            local tile = sim.world:peekTile(x, y, z)
            local rgb = Defs.tile(tile.id).color or { 255, 255, 255 }
            local light = lightAt(sim, x, y, profile)
            data:setPixel(index - 1, 0, litTileColor(rgb, light))
            local u = (index - 0.5) / (width * height)
            pushTileQuad(vertices, x, y, z, u)
        end
    end
    local model = state.g3d.newModel(vertices, newImageFromData(data))
    model:makeNormals()
    return model
end

local function applyCamera(sim, app)
    local yaw = baseYaw + ((app.viewRotation or 0) % 4) * math.pi / 2
    local horizontal = math.cos(cameraPitch) * cameraDistance
    local targetX = sim.player.x + 0.5
    local targetY = sim.player.y + 0.5
    local targetZ = sim.player.z or 0
    local x = targetX + math.cos(yaw) * horizontal
    local y = targetY - math.sin(yaw) * horizontal
    local z = targetZ + math.sin(cameraPitch) * cameraDistance
    state.g3d.camera.lookAt(x, y, z, targetX, targetY, targetZ)
    state.g3d.camera.updateOrthographicMatrix(cameraViewSize)
    return yaw
end

local function atlasFrameUv(frame)
    local index = (frame or 0) % (atlasColumns * atlasRows)
    local col = index % atlasColumns
    local row = math.floor(index / atlasColumns)
    local u0 = col / atlasColumns
    local u1 = (col + 1) / atlasColumns
    local v0 = row / atlasRows
    local v1 = (row + 1) / atlasRows
    return u0, v0, u1, v1
end

local function billboardVerts(width, height, frame)
    local u0, v0, u1, v1 = atlasFrameUv(frame)
    local halfWidth = width / 2
    return {
        billboardVertex(-halfWidth, 0, 0, u0, v1),
        billboardVertex(halfWidth, 0, 0, u1, v1),
        billboardVertex(halfWidth, 0, height, u1, v0),
        billboardVertex(-halfWidth, 0, 0, u0, v1),
        billboardVertex(halfWidth, 0, height, u1, v0),
        billboardVertex(-halfWidth, 0, height, u0, v0),
    }
end

local function newBillboard(width, height, frame, x, y, z, yaw, texture)
    texture = texture or state.assets.spriteAtlas or state.assets.white
    local model = state.g3d.newModel(billboardVerts(width, height, frame), texture, {x, y, z or 0})
    model:makeNormals()
    model:setRotation(0, 0, math.pi / 2 - yaw)
    return model
end

local function drawLitModel(model, light)
    love.graphics.push("all")
    love.graphics.setColor(light, light, light, 1)
    model:draw()
    love.graphics.pop()
end

local function drawHeroBillboards(sim, yaw, profile)
    if not (state.g3d and (state.assets.spriteAtlas or state.assets.white) and sim.partyState) then
        return
    end
    local offsets = {
        {-1.1, -0.65},
        {-0.35, -0.95},
        {0.35, -0.95},
        {1.1, -0.65},
    }
    for _, hero in ipairs(sim:partyState()) do
        if hero.alive ~= false and hero.rank and offsets[hero.rank] then
            local offset = offsets[hero.rank]
            local x = sim.player.x + 0.5 + offset[1]
            local y = sim.player.y + 0.5 + offset[2]
            local model = newBillboard(0.85, 1.1, 24 + hero.rank, x, y, sim.player.z or 0, yaw)
            drawLitModel(model, lightAt(sim, x, y, profile))
        end
    end
end

local function enemyFrame(objectType)
    if objectType == "boss" then
        return 36
    end
    if objectType == "alpha" then
        return 35
    end
    if objectType == "encounter" then
        return 34
    end
    return 33
end

local function hasRole(def, role)
    for _, candidate in ipairs(def.roles or {}) do
        if candidate == role then
            return true
        end
    end
    return false
end

local function combatEnemyType(enemy)
    local def = Defs.enemy(enemy and enemy.kind) or {}
    if def.boss or hasRole(def, "boss") then
        return "boss"
    end
    if def.alpha or hasRole(def, "alpha") then
        return "alpha"
    end
    return "threat"
end

local function enemyTexture(objectType)
    if objectType == "boss" then
        return state.assets.boss or state.assets.enemy
    end
    if objectType == "alpha" then
        return state.assets.alpha or state.assets.enemy
    end
    return state.assets.enemy or state.assets.white
end

local function enemySize(objectType)
    if objectType == "boss" then
        return 1.2, 1.45
    end
    if objectType == "alpha" then
        return 1.08, 1.3
    end
    return 0.95, 1.15
end

local function drawCombatEnemyBillboards(sim, yaw, profile)
    if not (sim.combat and sim.combat.enemies) then
        return false
    end
    local offsets = {
        {-1.35, 1.7},
        {-0.45, 2.0},
        {0.45, 2.0},
        {1.35, 1.7},
    }
    for _, enemy in ipairs(sim.combat.enemies) do
        if enemy.hp > 0 and enemy.rank and offsets[enemy.rank] then
            local offset = offsets[enemy.rank]
            local objectType = combatEnemyType(enemy)
            local width, height = enemySize(objectType)
            local x = sim.player.x + 0.5 + offset[1]
            local y = sim.player.y + 0.5 + offset[2]
            local model = newBillboard(width, height, enemyFrame(objectType), x, y, sim.player.z or 0, yaw, enemyTexture(objectType))
            drawLitModel(model, lightAt(sim, x, y, profile))
        end
    end
    return true
end

local function isEnemyObject(object)
    return object.type == "threat" or object.type == "alpha" or object.type == "encounter" or object.type == "boss"
end

local function drawWorldEnemyBillboards(sim, yaw, profile)
    if not sim.objectsInRect then
        return
    end
    local minX = sim.player.x - visibleRadius
    local maxX = sim.player.x + visibleRadius
    local minY = sim.player.y - visibleRadius
    local maxY = sim.player.y + visibleRadius
    for _, object in ipairs(sim:objectsInRect(minX, maxX, minY, maxY, sim.player.z or 0)) do
        if isEnemyObject(object) then
            local width, height = enemySize(object.type)
            local model = newBillboard(width, height, enemyFrame(object.type), object.x + 0.5, object.y + 0.5, object.z or 0, yaw, enemyTexture(object.type))
            drawLitModel(model, lightAt(sim, object.x, object.y, profile))
        end
    end
end

local function drawEnemyBillboards(sim, yaw, profile)
    if not (state.g3d and (state.assets.spriteAtlas or state.assets.white)) then
        return
    end
    if not drawCombatEnemyBillboards(sim, yaw, profile) then
        drawWorldEnemyBillboards(sim, yaw, profile)
    end
end

function Render.drawWorld(sim, app)
    app.worldView = app.worldView or {}
    app.worldView.mode = "render3d-placeholder"
    local screenWidth = love and love.graphics and love.graphics.getWidth() or 0
    local screenHeight = love and love.graphics and love.graphics.getHeight() or 0
    app.worldView.centerX = screenWidth / 2
    app.worldView.centerY = screenHeight / 2
    app.worldView.halfW = 32
    app.worldView.halfH = 16
    app.worldView.originX = sim and sim.player and sim.player.x or 0
    app.worldView.originY = sim and sim.player and sim.player.y or 0
    app.worldView.rotation = app.viewRotation or 0
    if not (love and love.graphics and sim and sim.world and state.g3d) then
        return
    end
    app.worldView.mode = "render3d"
    local profile = lightProfile(sim)
    app.worldView.light = { torch = profile.torch, ambient = profile.ambient, radius = profile.radius }
    local yaw = applyCamera(sim, app)
    local model = buildWorldTileModel(sim, profile)
    love.graphics.setColor(1, 1, 1, 1)
    model:draw()
    drawHeroBillboards(sim, yaw, profile)
    drawEnemyBillboards(sim, yaw, profile)
end

function Render.titleMenuItems(app)
    local canContinue = app and app.canContinue == true
    return {
        { action = "new", label = "New Game", enabled = true },
        { action = "continue", label = "Continue", enabled = canContinue },
        { action = "settings", label = "Settings", enabled = true },
        { action = "credits", label = "Credits", enabled = true },
        { action = "quit", label = "Quit", enabled = true },
    }
end

function Render.expeditionHudSummary(sim)
    local roomKey = sim and sim.currentRoomKey and sim:currentRoomKey() or nil
    return {
        torch = sim and sim.expedition and sim.expedition.torch or nil,
        currentRoom = roomKey or "corridor",
        partyCount = sim and sim.partyState and #sim:partyState() or 0,
    }
end

local function combatActorLabel(sim, actor)
    if not actor then
        return "-"
    end
    if actor.side == "hero" then
        local hero = sim:heroById(actor.id)
        return "R" .. tostring(actor.rank or "?") .. " " .. (hero and hero.name or "hero")
    end
    local enemy = sim.combat and sim.combat.enemies and sim.combat.enemies[actor.id]
    local enemyDef = enemy and Defs.enemy(enemy.kind)
    return "E" .. tostring(actor.rank or "?") .. " " .. (enemyDef and enemyDef.name or "enemy")
end

function Render.combatHudSummary(sim, app)
    local turns = {}
    for index, actor in ipairs((sim and sim.combat and sim.combat.turnQueue) or {}) do
        turns[#turns + 1] = {
            index = index,
            active = index == ((sim.combat and sim.combat.turnIndex) or 0),
            label = combatActorLabel(sim, actor),
        }
    end
    return {
        mode = sim and sim.mode or nil,
        round = sim and sim.combat and sim.combat.round or nil,
        turns = turns,
        active = combatActorLabel(sim, sim and sim.combat and sim.combat.active),
        target = app and app.pendingTargetSide or nil,
        skill = app and app.pendingSkillKey or nil,
    }
end

function Render.campHudSummary(sim, app)
    local camping = sim and sim.expedition and sim.expedition.camping
    return {
        active = camping ~= nil,
        respite = camping and camping.respite or 0,
        skills = sim and sim.availableCampSkills and sim:availableCampSkills() or {},
        pendingSkill = app and app.pendingCampSkillKey or nil,
        partyCount = sim and sim.partyState and #sim:partyState() or 0,
    }
end

local curioChoiceOrder = {
    { key = "safe_use", label = "Safe" },
    { key = "greedy_use", label = "Greedy" },
    { key = "repair_use", label = "Repair" },
    { key = "leave_alone", label = "Leave" },
}

local function listContains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
end

function Render.curioModalForTarget(sim)
    local target = sim and sim.targetCurio and sim:targetCurio() or nil
    if not target then
        return nil
    end
    local copy = target.curio.copy or {}
    local choices = {}
    for _, choice in ipairs(curioChoiceOrder) do
        choices[#choices + 1] = {
            key = choice.key,
            label = choice.label,
            text = copy[choice.key] or choice.label,
            enabled = listContains(target.curio.outcomes or {}, choice.key),
        }
    end
    return {
        x = target.x,
        y = target.y,
        z = target.z,
        key = target.key,
        title = target.curio.name,
        observe = copy.observe or target.curio.name,
        result = copy.result or (target.curio.name .. " resolved."),
        choices = choices,
    }
end

function Render.drawCurioModal(app)
    local modal = app.curioModal
    if not modal or not (love and love.graphics) then
        return
    end
    local width, height = love.graphics.getDimensions()
    local w, h = 520, 260
    local x = (width - w) / 2
    local y = (height - h) / 2
    panel(x, y, w, h, 0.96)
    love.graphics.setColor(0.92, 0.9, 0.8, 1)
    love.graphics.print(modal.title, x + 18, y + 16)
    love.graphics.setColor(0.68, 0.72, 0.66, 1)
    love.graphics.printf(modal.observe, x + 18, y + 42, w - 36)
    for index, choice in ipairs(modal.choices or {}) do
        local bx = x + 18
        local by = y + 82 + (index - 1) * 40
        local bw = w - 36
        love.graphics.setColor(choice.enabled and 0.14 or 0.08, choice.enabled and 0.17 or 0.08, choice.enabled and 0.15 or 0.08, 1)
        love.graphics.rectangle("fill", bx, by, bw, 32)
        love.graphics.setColor(choice.enabled and 0.62 or 0.24, choice.enabled and 0.56 or 0.24, choice.enabled and 0.36 or 0.24, 1)
        love.graphics.rectangle("line", bx, by, bw, 32)
        love.graphics.setColor(choice.enabled and 0.9 or 0.38, choice.enabled and 0.92 or 0.38, choice.enabled and 0.84 or 0.38, 1)
        love.graphics.printf(index .. " " .. choice.label .. " - " .. choice.text, bx + 8, by + 9, bw - 16, "left")
        app.ui.curioButtons[#app.ui.curioButtons + 1] = { x = bx, y = by, w = bw, h = 32, choice = choice.key, enabled = choice.enabled, index = index }
    end
end

function Render.drawCurioResult(app)
    local result = app.curioResult
    if not result or not (love and love.graphics) then
        return
    end
    local width = love.graphics.getWidth()
    local w, h = 460, 88
    local x = (width - w) / 2
    local y = 112
    panel(x, y, w, h, 0.94)
    love.graphics.setColor(0.92, 0.9, 0.8, 1)
    love.graphics.print(result.title or "Curio", x + 14, y + 12)
    love.graphics.setColor(0.72, 0.76, 0.68, 1)
    love.graphics.printf(result.text or "", x + 14, y + 38, w - 28)
end

local pauseActions = {
    { action = "resume", label = "Resume" },
    { action = "save", label = "Save" },
    { action = "settings", label = "Settings" },
    { action = "quitTitle", label = "Quit to Title" },
}

function Render.pauseMenuItems()
    return pauseActions
end

local function layoutPauseButtons(app, x, y, w)
    app.pauseMenuIndex = clamp(app.pauseMenuIndex or 1, 1, #pauseActions)
    for index, item in ipairs(pauseActions) do
        local by = y + 72 + (index - 1) * 42
        app.ui.pauseButtons[#app.ui.pauseButtons + 1] = { x = x + 46, y = by, w = w - 92, h = 34, action = item.action, index = index }
    end
end

function Render.drawPauseMenu(app)
    if not (app and app.paused) then
        return
    end
    Render.prepareUi(app)
    local w, h = 320, 260
    layoutPauseButtons(app, (1280 - w) / 2, (720 - h) / 2, w)
    if not (love and love.graphics) then
        return
    end
    local width, height = love.graphics.getDimensions()
    clearList(app.ui.pauseButtons)
    love.graphics.setColor(0.01, 0.012, 0.014, 0.62)
    love.graphics.rectangle("fill", 0, 0, width, height)
    local x = (width - w) / 2
    local y = (height - h) / 2
    layoutPauseButtons(app, x, y, w)
    panel(x, y, w, h, 0.96)
    love.graphics.setColor(0.92, 0.9, 0.8, 1)
    love.graphics.printf("Paused", x, y + 24, w, "center")
    for index, item in ipairs(pauseActions) do
        local button = app.ui.pauseButtons[index]
        local active = app.pauseMenuIndex == index
        love.graphics.setColor(active and 0.18 or 0.1, active and 0.22 or 0.12, active and 0.19 or 0.12, 1)
        love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
        love.graphics.setColor(active and 0.74 or 0.34, active and 0.66 or 0.38, active and 0.36 or 0.32, 1)
        love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
        love.graphics.setColor(0.92, 0.94, 0.88, 1)
        love.graphics.printf((active and "> " or "") .. item.label, button.x + 10, button.y + 10, button.w - 20, "left")
    end
    love.graphics.setColor(0.58, 0.62, 0.58, 1)
    love.graphics.printf(app.pauseStatus or "", x + 20, y + h - 30, w - 40, "center")
end

local confirmActions = {
    { action = "cancel", label = "Cancel", enabled = true },
    { action = "confirm", label = "Confirm", enabled = true },
}

function Render.confirmMenuItems()
    return confirmActions
end

local function layoutConfirmButtons(app, x, y, w)
    app.confirmMenuIndex = clamp(app.confirmMenuIndex or 1, 1, #confirmActions)
    for index, item in ipairs(confirmActions) do
        app.ui.confirmButtons[#app.ui.confirmButtons + 1] = { x = x + 28 + (index - 1) * 144, y = y + 118, w = 128, h = 38, action = item.action, enabled = item.enabled, index = index }
    end
end

function Render.drawConfirmDialog(app)
    if not (app and app.confirmDialog) then
        return
    end
    Render.prepareUi(app)
    local w, h = 340, 184
    layoutConfirmButtons(app, (1280 - w) / 2, (720 - h) / 2, w)
    if not (love and love.graphics) then
        return app.confirmDialog
    end
    local width, height = love.graphics.getDimensions()
    clearList(app.ui.confirmButtons)
    love.graphics.setColor(0.01, 0.012, 0.014, 0.64)
    love.graphics.rectangle("fill", 0, 0, width, height)
    local x = (width - w) / 2
    local y = (height - h) / 2
    layoutConfirmButtons(app, x, y, w)
    panel(x, y, w, h, 0.98)
    love.graphics.setColor(0.92, 0.9, 0.8, 1)
    love.graphics.printf(app.confirmDialog.title or "Confirm", x + 18, y + 22, w - 36, "center")
    love.graphics.setColor(0.66, 0.7, 0.64, 1)
    love.graphics.printf(app.confirmDialog.body or "", x + 24, y + 58, w - 48, "center")
    for index, item in ipairs(confirmActions) do
        local button = app.ui.confirmButtons[index]
        local active = (app.confirmMenuIndex or 1) == index
        love.graphics.setColor(active and 0.18 or 0.1, active and 0.2 or 0.11, active and 0.16 or 0.1, 1)
        love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
        love.graphics.setColor(active and 0.78 or 0.34, active and 0.62 or 0.36, active and 0.32 or 0.3, 1)
        love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
        love.graphics.setColor(0.92, 0.94, 0.88, 1)
        love.graphics.printf((active and "> " or "") .. item.label, button.x + 8, button.y + 12, button.w - 16, "center")
    end
    return app.confirmDialog
end

function Render.drawKeyboardFocus(app)
    local focus = app and app.keyboardFocus
    if not (focus and app.ui and love and love.graphics) then
        return
    end
    local hitbox = app.ui[focus.group] and app.ui[focus.group][focus.index]
    if not hitbox then
        return
    end
    love.graphics.setColor(0.95, 0.82, 0.28, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", hitbox.x - 3, hitbox.y - 3, hitbox.w + 6, hitbox.h + 6)
end

local gameOverActions = {
    { action = "restart", label = "Restart", enabled = true },
    { action = "title", label = "Title", enabled = true },
    { action = "credits", label = "Credits", enabled = true },
}

local dreadTierNames = { [0] = "quiet", [1] = "uneasy", [2] = "strained", [3] = "breaking", [4] = "collapsed" }

local function dreadTier(dread, limit)
    local cap = math.max(1, limit or 18)
    return clamp(math.floor(((dread or 0) / cap) * 4), 0, 4)
end

local function bossKillCount(campaign)
    local count = 0
    for _, key in ipairs(Defs.locationOrder or {}) do
        if campaign.bossKills and campaign.bossKills[key] then
            count = count + 1
        end
    end
    return count
end

function Render.gameOverMenuItems()
    return gameOverActions
end

function Render.gameOverSummary(sim)
    local estate = (sim and sim.estate) or {}
    local campaign = estate.campaign or {}
    local routeKey = campaign.endingRoute or (campaign.victory and "estate_seal" or "quiet_failure")
    local route = Defs.endingRoute(routeKey) or {}
    local tier = dreadTier(campaign.dread or 0, campaign.dreadLimit or 18)
    local factions = {}
    for _, key in ipairs(Defs.factionOrder or {}) do
        local def = Defs.faction(key) or {}
        local entry = (campaign.factions and campaign.factions[key]) or {}
        factions[#factions + 1] = { key = key, name = def.name or key, state = entry.state or "neutral", value = entry.value or 0 }
    end
    return {
        ended = campaign.lost == true or campaign.victory == true,
        won = campaign.victory == true,
        reason = campaign.victory and "victory" or (campaign.lossReason or "lost"),
        route = routeKey,
        routeName = route.name or routeKey,
        copy = sim and sim.endingScreenCopy and sim:endingScreenCopy(routeKey) or "",
        week = estate.week or 1,
        renown = campaign.renown or 0,
        dread = campaign.dread or 0,
        dreadLimit = campaign.dreadLimit or 18,
        dreadTier = tier,
        dreadTierName = dreadTierNames[tier],
        deaths = #((estate and estate.graveyard) or {}),
        bosses = bossKillCount(campaign),
        bossTotal = #(Defs.locationOrder or {}),
        party = estate.roster or {},
        graveyard = estate.graveyard or {},
        factions = factions,
    }
end

local function layoutGameOverButtons(app, items, width, height)
    local totalW = 480
    local buttonW = 148
    local gap = 18
    local x = (width - totalW) / 2
    local y = height - 96
    for index, item in ipairs(items) do
        app.ui.gameOverButtons[#app.ui.gameOverButtons + 1] = { x = x + (index - 1) * (buttonW + gap), y = y, w = buttonW, h = 42, action = item.action, enabled = item.enabled, index = index }
    end
end

local function drawGameOverButton(app, item, button)
    local active = (app.gameOverMenuIndex or 1) == button.index
    local enabled = item.enabled
    love.graphics.setColor(active and 0.18 or 0.09, active and 0.2 or 0.1, active and 0.16 or 0.1, enabled and 0.95 or 0.45)
    love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
    love.graphics.setColor(active and 0.78 or 0.34, active and 0.62 or 0.36, active and 0.32 or 0.3, enabled and 1 or 0.45)
    love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
    love.graphics.setColor(enabled and 0.94 or 0.46, enabled and 0.94 or 0.46, enabled and 0.86 or 0.46, 1)
    love.graphics.printf((active and "> " or "") .. item.label, button.x + 8, button.y + 13, button.w - 16, "center")
end

function Render.drawGameOver(sim, app)
    Render.prepareUi(app)
    local summary = Render.gameOverSummary(sim)
    local items = Render.gameOverMenuItems(app)
    app.gameOverMenuIndex = clamp(app.gameOverMenuIndex or 1, 1, #items)
    layoutGameOverButtons(app, items, 1280, 720)
    if not (love and love.graphics) then
        return summary
    end
    love.graphics.clear(0.035, 0.038, 0.042, 1)
    local width, height = love.graphics.getDimensions()
    clearList(app.ui.gameOverButtons)
    layoutGameOverButtons(app, items, width, height)
    love.graphics.push("all")
    love.graphics.setDepthMode()
    panel(56, 52, width - 112, height - 124, 0.96)
    love.graphics.setColor(0.92, 0.9, 0.8, 1)
    love.graphics.printf(summary.won and "Campaign Sealed" or "Game Over", 80, 82, width - 160, "left", 0, 1.6, 1.6)
    love.graphics.setColor(0.68, 0.72, 0.66, 1)
    love.graphics.print(summary.reason .. " / " .. summary.routeName .. " / week " .. summary.week .. " / dread " .. summary.dread .. "/" .. summary.dreadLimit .. " tier " .. summary.dreadTier, 82, 138)
    love.graphics.print("renown " .. summary.renown .. " / bosses " .. summary.bosses .. "/" .. summary.bossTotal .. " / fallen " .. summary.deaths, 82, 162)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Party Fate", 82, 210)
    for index, hero in ipairs(summary.party) do
        if index > 6 then
            break
        end
        local class = Defs.heroClass(hero.class) or {}
        local line = hero.name .. "  " .. (class.name or hero.class) .. "  L" .. tostring(hero.level or 1) .. "  stress " .. tostring(hero.stress or 0)
        love.graphics.setColor(hero.alive == false and 0.56 or 0.76, hero.alive == false and 0.42 or 0.78, hero.alive == false and 0.42 or 0.72, 1)
        love.graphics.print(line, 82, 238 + (index - 1) * 24)
    end
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Graveyard", 82, 406)
    for index, death in ipairs(summary.graveyard) do
        if index > 5 then
            break
        end
        love.graphics.setColor(0.62, 0.64, 0.58, 1)
        love.graphics.print((death.name or "fallen") .. "  " .. (death.location or "estate"), 82, 432 + (index - 1) * 22)
    end
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Faction State", width * 0.52, 210)
    for index, faction in ipairs(summary.factions) do
        love.graphics.setColor(0.74, 0.78, 0.72, 1)
        love.graphics.print(faction.name, width * 0.52, 238 + (index - 1) * 28)
        love.graphics.setColor(0.58, 0.66, 0.56, 1)
        love.graphics.print(faction.state .. " (" .. tostring(faction.value) .. ")", width * 0.74, 238 + (index - 1) * 28)
    end
    love.graphics.setColor(0.62, 0.66, 0.58, 1)
    love.graphics.printf(summary.copy or "", width * 0.52, 406, width * 0.38)
    love.graphics.printf(app.gameOverStatus or "", 80, height - 130, width - 160, "center")
    for index, item in ipairs(items) do
        drawGameOverButton(app, item, app.ui.gameOverButtons[index])
    end
    love.graphics.pop()
    return summary
end

local function markdownCells(line)
    if not line:match("^|") then
        return nil
    end
    local cells = {}
    for cell in line:gmatch("|([^|]*)") do
        cells[#cells + 1] = stripBackticks(cell)
    end
    return cells
end

function Render.creditsData()
    local rows = {}
    local text = readText("docs/asset-licenses.md") or ""
    for line in text:gmatch("[^\r\n]+") do
        local cells = markdownCells(line)
        if cells and cells[1] and cells[1] ~= "File" and not cells[1]:find("%-%-%-", 1, false) then
            rows[#rows + 1] = { file = cells[1], source = cells[2], author = cells[3], license = cells[4], notes = cells[5] }
        end
    end
    return {
        project = "Thoth",
        assets = rows,
        libraries = {
            { name = "g3d", source = "vendor/g3d/LICENSE", author = "groverburger", license = "MIT" },
            { name = "LOVE", source = "https://love2d.org", author = "LOVE Development Team", license = "zlib/libpng" },
        },
        music = {},
    }
end

local function creditsLineCount(data)
    return 6 + #data.assets * 3 + #data.libraries * 2 + math.max(1, #data.music)
end

local function layoutCreditsButtons(app, width, height)
    app.ui.creditsButtons[#app.ui.creditsButtons + 1] = { x = 72, y = height - 86, w = 160, h = 42, action = "back", enabled = true, index = 1 }
end

function Render.drawCredits(app)
    Render.prepareUi(app)
    local data = Render.creditsData()
    local maxScroll = math.max(0, creditsLineCount(data) - 15)
    app.creditsScroll = clamp(app.creditsScroll or 0, 0, maxScroll)
    layoutCreditsButtons(app, 1280, 720)
    if not (love and love.graphics) then
        return data
    end
    love.graphics.clear(0.035, 0.038, 0.042, 1)
    local width, height = love.graphics.getDimensions()
    clearList(app.ui.creditsButtons)
    layoutCreditsButtons(app, width, height)
    love.graphics.push("all")
    love.graphics.setDepthMode()
    panel(56, 52, width - 112, height - 124, 0.96)
    love.graphics.setColor(0.92, 0.9, 0.8, 1)
    love.graphics.printf("Credits", 80, 82, width - 160, "left", 0, 1.5, 1.5)
    love.graphics.setColor(0.68, 0.72, 0.66, 1)
    love.graphics.print(data.project .. " / playable prototype", 82, 132)
    local y = 178 - app.creditsScroll * 24
    local function line(text, x, color)
        if y > 142 and y < height - 112 then
            love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
            love.graphics.printf(text, x or 82, y, width - (x or 82) - 92)
        end
        y = y + 24
    end
    line("Asset Attributions", 82, { 0.9, 0.92, 0.86, 1 })
    for _, asset in ipairs(data.assets) do
        line(asset.file .. " / " .. asset.license .. " / " .. asset.author, 96, { 0.76, 0.78, 0.72, 1 })
        line(asset.source or "-", 110, { 0.56, 0.64, 0.58, 1 })
        line(asset.notes or "", 110, { 0.5, 0.54, 0.5, 1 })
    end
    y = y + 8
    line("Libraries", 82, { 0.9, 0.92, 0.86, 1 })
    for _, lib in ipairs(data.libraries) do
        line(lib.name .. " / " .. lib.license .. " / " .. lib.author, 96, { 0.76, 0.78, 0.72, 1 })
        line(lib.source, 110, { 0.56, 0.64, 0.58, 1 })
    end
    y = y + 8
    line("Music", 82, { 0.9, 0.92, 0.86, 1 })
    if #data.music == 0 then
        line("No external music tracks packaged.", 96, { 0.62, 0.66, 0.58, 1 })
    end
    local button = app.ui.creditsButtons[1]
    love.graphics.setColor(0.1, 0.12, 0.11, 1)
    love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
    love.graphics.setColor(0.42, 0.48, 0.36, 1)
    love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
    love.graphics.setColor(0.92, 0.94, 0.88, 1)
    love.graphics.printf("Back", button.x + 8, button.y + 13, button.w - 16, "center")
    love.graphics.setColor(0.58, 0.62, 0.58, 1)
    love.graphics.printf("scroll " .. tostring(app.creditsScroll) .. "/" .. tostring(maxScroll), width - 260, height - 72, 180, "right")
    love.graphics.pop()
    return data
end

function Render.journalSummary(sim)
    local documents = {}
    for _, entry in ipairs(sim and sim.journalEntries and sim:journalEntries() or {}) do
        local document = Defs.document(entry.key) or {}
        documents[#documents + 1] = {
            key = entry.key,
            title = entry.title,
            typeName = entry.typeName,
            location = entry.location,
            abstract = entry.abstract,
            text = document.text or "",
        }
    end
    local epitaphs = {}
    for index, death in ipairs((sim and sim.estate and sim.estate.graveyard) or {}) do
        local location = death.location or "estate"
        local lines = Defs.graveyardEpitaphsFor(location) or Defs.graveyardEpitaphsFor("estate") or {}
        local line = lines[((death.id or index) - 1) % math.max(1, #lines) + 1] or "recorded without epitaph"
        local class = Defs.heroClass(death.class) or {}
        epitaphs[#epitaphs + 1] = {
            name = death.name or "fallen",
            className = class.name or death.class or "hero",
            location = location,
            epitaph = line,
        }
    end
    return { documents = documents, epitaphs = epitaphs }
end

local function layoutJournalButtons(app, summary, width, height)
    app.ui.journalButtons[#app.ui.journalButtons + 1] = { x = 84, y = 118, w = 150, h = 34, action = "tab", tab = "documents", enabled = true, index = 1 }
    app.ui.journalButtons[#app.ui.journalButtons + 1] = { x = 246, y = 118, w = 150, h = 34, action = "tab", tab = "epitaphs", enabled = true, index = 2 }
    local tab = app.journalTab or "documents"
    local items = tab == "epitaphs" and summary.epitaphs or summary.documents
    local listX = 84
    local listY = 174
    local rowH = 42
    for index = 1, math.min(#items, 10) do
        app.ui.journalButtons[#app.ui.journalButtons + 1] = { x = listX, y = listY + (index - 1) * rowH, w = 340, h = rowH - 6, action = "select", selection = index, enabled = true, index = index + 2 }
    end
    app.ui.journalButtons[#app.ui.journalButtons + 1] = { x = 84, y = height - 86, w = 150, h = 42, action = "back", enabled = true, index = #app.ui.journalButtons + 1 }
end

local function drawJournalButton(app, button, label, active)
    love.graphics.setColor(active and 0.18 or 0.09, active and 0.15 or 0.09, active and 0.22 or 0.12, 1)
    love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
    love.graphics.setColor(active and 0.64 or 0.34, active and 0.48 or 0.34, active and 0.82 or 0.44, 1)
    love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
    love.graphics.setColor(0.92, 0.9, 0.94, 1)
    love.graphics.printf(label, button.x + 8, button.y + 10, button.w - 16, "center")
end

function Render.drawJournal(sim, app)
    Render.prepareUi(app)
    local summary = Render.journalSummary(sim)
    app.journalTab = app.journalTab or "documents"
    local items = app.journalTab == "epitaphs" and summary.epitaphs or summary.documents
    app.journalIndex = clamp(app.journalIndex or 1, 1, math.max(1, #items))
    layoutJournalButtons(app, summary, 1280, 720)
    if not (love and love.graphics) then
        return summary
    end
    love.graphics.clear(0.035, 0.038, 0.042, 1)
    local width, height = love.graphics.getDimensions()
    clearList(app.ui.journalButtons)
    layoutJournalButtons(app, summary, width, height)
    love.graphics.push("all")
    love.graphics.setDepthMode()
    panel(56, 52, width - 112, height - 124, 0.96)
    love.graphics.setColor(0.92, 0.9, 0.94, 1)
    love.graphics.printf("Journal", 84, 82, width - 168, "left", 0, 1.5, 1.5)
    drawJournalButton(app, app.ui.journalButtons[1], "Documents", app.journalTab == "documents")
    drawJournalButton(app, app.ui.journalButtons[2], "Epitaphs", app.journalTab == "epitaphs")
    for index, item in ipairs(items) do
        if index > 10 then
            break
        end
        local button = app.ui.journalButtons[index + 2]
        local active = app.journalIndex == index
        local label = app.journalTab == "epitaphs" and (item.name .. " / " .. item.className) or (item.title .. " / " .. item.typeName)
        drawJournalButton(app, button, label, active)
    end
    local detailX = 456
    local detailY = 172
    local detailW = width - detailX - 96
    local selected = items[app.journalIndex]
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    if selected and app.journalTab == "documents" then
        love.graphics.print(selected.title, detailX, detailY)
        love.graphics.setColor(0.66, 0.72, 0.68, 1)
        love.graphics.print(selected.typeName .. " / " .. selected.location, detailX, detailY + 28)
        love.graphics.printf(selected.abstract, detailX, detailY + 68, detailW)
        love.graphics.printf(selected.text, detailX, detailY + 124, detailW)
    elseif selected then
        love.graphics.print(selected.name, detailX, detailY)
        love.graphics.setColor(0.66, 0.72, 0.68, 1)
        love.graphics.print(selected.className .. " / " .. selected.location, detailX, detailY + 28)
        love.graphics.printf(selected.epitaph, detailX, detailY + 68, detailW)
    else
        love.graphics.printf(app.journalTab == "epitaphs" and "no epitaphs" or "no documents", detailX, detailY, detailW)
    end
    local back = app.ui.journalButtons[#app.ui.journalButtons]
    drawJournalButton(app, back, "Back", false)
    love.graphics.setColor(0.58, 0.62, 0.58, 1)
    love.graphics.printf("documents " .. #summary.documents .. " / epitaphs " .. #summary.epitaphs, width - 360, height - 72, 280, "right")
    love.graphics.pop()
    return summary
end

local tutorialSteps = {
    { key = "torch", title = "Torch", body = "Torch falls as the party advances. Spend carried torches before dark rooms turn pressure into ambush." },
    { key = "stress", title = "Stress", body = "Stress can break heroes before HP does. Camp skills, curios, and retreat are pressure valves." },
    { key = "rank", title = "Rank", body = "Rank controls skills and targets. Front and back positions decide who can act and who can be hit." },
}

function Render.tutorialSteps()
    return tutorialSteps
end

local function layoutTutorialButtons(app, x, y, w)
    app.ui.tutorialButtons[#app.ui.tutorialButtons + 1] = { x = x + 18, y = y + 148, w = 92, h = 34, action = "skip", enabled = true, index = 1 }
    app.ui.tutorialButtons[#app.ui.tutorialButtons + 1] = { x = x + w - 226, y = y + 148, w = 92, h = 34, action = "prev", enabled = (app.tutorial.index or 1) > 1, index = 2 }
    app.ui.tutorialButtons[#app.ui.tutorialButtons + 1] = { x = x + w - 122, y = y + 148, w = 104, h = 34, action = "next", enabled = true, index = 3 }
end

function Render.drawTutorial(app)
    if not (app and app.tutorial and app.tutorial.active) then
        return
    end
    Render.prepareUi(app)
    app.tutorial.index = clamp(app.tutorial.index or 1, 1, #tutorialSteps)
    local w, h = 480, 204
    layoutTutorialButtons(app, 1280 - w - 36, 116, w)
    if not (love and love.graphics) then
        return tutorialSteps
    end
    clearList(app.ui.tutorialButtons)
    local width = love.graphics.getWidth()
    local x = width - w - 36
    local y = 116
    layoutTutorialButtons(app, x, y, w)
    local step = tutorialSteps[app.tutorial.index]
    panel(x, y, w, h, 0.97)
    love.graphics.setColor(0.92, 0.9, 0.8, 1)
    love.graphics.printf(step.title, x + 18, y + 18, w - 36)
    love.graphics.setColor(0.68, 0.72, 0.66, 1)
    love.graphics.printf(step.body, x + 18, y + 52, w - 36)
    love.graphics.setColor(0.58, 0.62, 0.58, 1)
    love.graphics.printf(tostring(app.tutorial.index) .. "/" .. tostring(#tutorialSteps), x + 18, y + 120, w - 36, "right")
    for _, button in ipairs(app.ui.tutorialButtons) do
        love.graphics.setColor(button.enabled and 0.11 or 0.07, button.enabled and 0.13 or 0.07, button.enabled and 0.11 or 0.07, 1)
        love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
        love.graphics.setColor(button.enabled and 0.44 or 0.22, button.enabled and 0.5 or 0.22, button.enabled and 0.34 or 0.22, 1)
        love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
        love.graphics.setColor(button.enabled and 0.9 or 0.4, button.enabled and 0.92 or 0.4, button.enabled and 0.84 or 0.4, 1)
        love.graphics.printf(button.action == "next" and (app.tutorial.index == #tutorialSteps and "Done" or "Next") or (button.action == "prev" and "Back" or "Skip"), button.x + 6, button.y + 10, button.w - 12, "center")
    end
    return tutorialSteps
end

local function layoutTitleButtons(app, items, width, height)
    local buttonW = math.min(320, math.max(220, width - 88))
    local x = math.max(44, width - buttonW - 96)
    local y = math.max(206, height * 0.5 - 88)
    for index, item in ipairs(items) do
        app.ui.titleButtons[#app.ui.titleButtons + 1] = {
            x = x,
            y = y + (index - 1) * 52,
            w = buttonW,
            h = 42,
            action = item.action,
            enabled = item.enabled,
            index = index,
        }
    end
end

local function drawLedgerSweep(width, height, t)
    love.graphics.setColor(0.74, 0.62, 0.38, 0.08)
    local offset = ((t or 0) * 28) % 88
    for index = -1, 9 do
        local y = index * 88 + offset
        love.graphics.rectangle("fill", 0, y, width, 1)
        love.graphics.rectangle("fill", 0, height - y, width, 1)
    end
    love.graphics.setColor(0.34, 0.42, 0.48, 0.06)
    local xOffset = ((t or 0) * 18) % 140
    for index = -1, 10 do
        love.graphics.rectangle("fill", index * 140 + xOffset, 0, 1, height)
    end
end

local function drawTitleButton(app, item, button)
    local active = (app.titleMenuIndex or 1) == button.index
    local enabled = item.enabled
    love.graphics.setColor(active and 0.2 or 0.1, active and 0.24 or 0.12, active and 0.19 or 0.12, enabled and 0.94 or 0.55)
    love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
    love.graphics.setColor(active and 0.82 or 0.36, active and 0.68 or 0.38, active and 0.34 or 0.28, enabled and 1 or 0.55)
    love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
    love.graphics.setColor(enabled and 0.94 or 0.42, enabled and 0.94 or 0.42, enabled and 0.86 or 0.42, 1)
    love.graphics.printf((active and "> " or "") .. item.label, button.x + 10, button.y + 12, button.w - 20, "left")
end

function Render.drawTitle(sim, app)
    Render.prepareUi(app)
    local items = Render.titleMenuItems(app)
    layoutTitleButtons(app, items, 1280, 720)
    if not (love and love.graphics) then
        return items
    end
    love.graphics.clear(0.035, 0.038, 0.042, 1)
    Render.drawWorld(sim, app)
    local width, height = love.graphics.getDimensions()
    clearList(app.ui.titleButtons)
    layoutTitleButtons(app, items, width, height)
    love.graphics.push("all")
    love.graphics.setDepthMode()
    love.graphics.setColor(0.015, 0.017, 0.019, 0.68)
    love.graphics.rectangle("fill", 0, 0, width, height)
    drawLedgerSweep(width, height, app.titleTime or 0)
    love.graphics.setColor(0.92, 0.9, 0.8, 1)
    love.graphics.printf("THOTH", 64, math.max(86, height * 0.28), math.min(520, width - 128), "left", 0, 3.2, 3.2)
    love.graphics.setColor(0.62, 0.68, 0.62, 1)
    love.graphics.printf("account the dead", 70, math.max(164, height * 0.28 + 76), math.min(520, width - 128), "left")
    for index, item in ipairs(items) do
        drawTitleButton(app, item, app.ui.titleButtons[index])
    end
    love.graphics.setColor(0.58, 0.62, 0.58, 1)
    local status = app.titleStatus or app.saveStatus or "ready"
    love.graphics.printf(status, 64, height - 54, width - 128, "left")
    love.graphics.printf("keyboard", 64, height - 32, width - 128, "right")
    love.graphics.pop()
    return items
end

local function drawSliderControl(app, control, x, y, w, active)
    love.graphics.setColor(0.68, 0.72, 0.68, 1)
    love.graphics.printf(Settings.valueText(app.settings, control), x + w - 70, y + 2, 64, "right")
    local barX = x + 180
    local barW = w - 280
    local value = clamp01(app.settings[control.setting] or 0)
    love.graphics.setColor(0.11, 0.13, 0.13, 1)
    love.graphics.rectangle("fill", barX, y + 8, barW, 10)
    love.graphics.setColor(active and 0.82 or 0.42, active and 0.68 or 0.5, active and 0.34 or 0.36, 1)
    love.graphics.rectangle("fill", barX, y + 8, barW * value, 10)
    app.ui.settingsButtons[#app.ui.settingsButtons + 1] = { x = barX - 34, y = y - 4, w = 28, h = 28, action = "adjust", setting = control.setting, delta = -1, index = control.index }
    app.ui.settingsButtons[#app.ui.settingsButtons + 1] = { x = barX + barW + 8, y = y - 4, w = 28, h = 28, action = "adjust", setting = control.setting, delta = 1, index = control.index }
    love.graphics.setColor(0.22, 0.25, 0.23, 1)
    love.graphics.rectangle("line", barX - 34, y - 4, 28, 28)
    love.graphics.rectangle("line", barX + barW + 8, y - 4, 28, 28)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.printf("-", barX - 34, y + 3, 28, "center")
    love.graphics.printf("+", barX + barW + 8, y + 3, 28, "center")
end

local function drawButtonControl(app, control, x, y, w, active)
    local action = control.kind == "toggle" and "toggle" or (control.kind == "cycle" and "cycle" or "bind")
    local button = { x = x + 180, y = y - 5, w = math.min(220, w - 220), h = 30, action = action, setting = control.setting, binding = control.binding, delta = 1, index = control.index }
    app.ui.settingsButtons[#app.ui.settingsButtons + 1] = button
    love.graphics.setColor(active and 0.18 or 0.1, active and 0.22 or 0.12, active and 0.2 or 0.12, 1)
    love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
    love.graphics.setColor(active and 0.74 or 0.34, active and 0.66 or 0.38, active and 0.36 or 0.32, 1)
    love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
    love.graphics.setColor(0.92, 0.94, 0.88, 1)
    local value = Settings.valueText(app.settings, control)
    if app.captureBinding == control.binding then
        value = "press key"
    end
    love.graphics.printf(value, button.x + 8, button.y + 8, button.w - 16, "center")
end

function Render.drawSettings(app)
    Render.prepareUi(app)
    if not (love and love.graphics) then
        for index, control in ipairs(Settings.controls()) do
            if control.kind == "back" then
                app.ui.settingsButtons[#app.ui.settingsButtons + 1] = { x = 64, y = 610, w = 180, h = 42, action = "back", index = index }
            else
                app.ui.settingsButtons[#app.ui.settingsButtons + 1] = { x = 64, y = 80 + index * 34, w = 320, h = 28, action = control.kind, setting = control.setting, binding = control.binding, index = index }
            end
        end
        return
    end
    local width, height = love.graphics.getDimensions()
    love.graphics.clear(0.045, 0.048, 0.052, 1)
    love.graphics.push("all")
    love.graphics.setDepthMode()
    panel(48, 48, width - 96, height - 96, 0.94)
    love.graphics.setColor(0.92, 0.9, 0.8, 1)
    love.graphics.print("Settings", 72, 72)
    local controls = Settings.controls()
    app.settingsFocus = clamp(app.settingsFocus or 1, 1, #controls)
    local rowX = 72
    local rowW = width - 144
    local rowY = 126
    for index, control in ipairs(controls) do
        control.index = index
        local y = rowY + (index - 1) * 34
        if y > height - 126 then
            break
        end
        local active = app.settingsFocus == index
        love.graphics.setColor(active and 0.16 or 0.08, active and 0.18 or 0.09, active and 0.15 or 0.09, active and 0.9 or 0.55)
        love.graphics.rectangle("fill", rowX - 8, y - 8, rowW + 16, 30)
        love.graphics.setColor(active and 0.92 or 0.72, active and 0.9 or 0.76, active and 0.8 or 0.7, 1)
        love.graphics.printf(control.label, rowX, y, 170, "left")
        if control.kind == "slider" then
            drawSliderControl(app, control, rowX, y, rowW, active)
        elseif control.kind == "toggle" or control.kind == "cycle" or control.kind == "bind" then
            drawButtonControl(app, control, rowX, y, rowW, active)
        elseif control.kind == "back" then
            app.ui.settingsButtons[#app.ui.settingsButtons + 1] = { x = rowX + 180, y = y - 5, w = 180, h = 30, action = "back", index = index }
            love.graphics.setColor(active and 0.18 or 0.1, active and 0.22 or 0.12, active and 0.2 or 0.12, 1)
            love.graphics.rectangle("fill", rowX + 180, y - 5, 180, 30)
            love.graphics.setColor(active and 0.74 or 0.34, active and 0.66 or 0.38, active and 0.36 or 0.32, 1)
            love.graphics.rectangle("line", rowX + 180, y - 5, 180, 30)
            love.graphics.setColor(0.92, 0.94, 0.88, 1)
            love.graphics.printf("Back", rowX + 188, y + 3, 164, "center")
        end
    end
    love.graphics.setColor(0.58, 0.62, 0.58, 1)
    love.graphics.printf(app.settingsStatus or "", 72, height - 82, width - 144, "left")
    love.graphics.pop()
end

local function checklistText(group)
    local parts = { group.title }
    for _, item in ipairs(group.items) do
        parts[#parts + 1] = (item.done and "[x]" or "[ ]") .. item.label
    end
    return table.concat(parts, " ")
end

local function drawHeroRows(sim, app, x, y, w)
    for _, hero in ipairs(sim:partyState()) do
        local rowY = y + (hero.rank - 1) * 42
        local active = hero.rank == sim.player.selectedHero
        love.graphics.setColor(active and 0.2 or 0.12, active and 0.24 or 0.14, active and 0.18 or 0.13, 1)
        love.graphics.rectangle("fill", x, rowY, w, 40)
        love.graphics.setColor(active and 0.82 or 0.32, active and 0.72 or 0.34, active and 0.34 or 0.28, 1)
        love.graphics.rectangle("line", x, rowY, w, 40)
        love.graphics.setColor(0.94, 0.96, 0.9, 1)
        love.graphics.print(hero.rank .. " " .. hero.name .. " / " .. hero.class .. " L" .. (hero.level or 1), x + 6, rowY + 4)
        drawMeter(x + 6, rowY + 20, w - 78, 6, (hero.hp or 0) / math.max(1, hero.maxHp or 1), { 0.34, 0.68, 0.42, 1 })
        drawMeter(x + 6, rowY + 30, w - 78, 6, (hero.stress or 0) / 100, { 0.78, 0.58, 0.26, 1 })
        love.graphics.setColor(0.74, 0.82, 0.74, 1)
        love.graphics.print(hero.hp .. "/" .. hero.maxHp, x + w - 66, rowY + 17)
        love.graphics.print("s" .. hero.stress, x + w - 66, rowY + 28)
        if hero.deathsDoor then
            love.graphics.setColor(0.94, 0.34, 0.28, 1)
            love.graphics.print("door", x + w - 54, rowY + 19)
        elseif hero.affliction then
            love.graphics.setColor(0.9, 0.46, 0.42, 1)
            love.graphics.print(hero.affliction, x + w - 74, rowY + 19)
        elseif hero.virtue then
            love.graphics.setColor(0.56, 0.82, 0.66, 1)
            love.graphics.print(hero.virtue, x + w - 64, rowY + 19)
        elseif hero.diseases and #hero.diseases > 0 then
            love.graphics.setColor(0.68, 0.72, 0.46, 1)
            love.graphics.print("ill", x + w - 34, rowY + 19)
        end
        app.ui.heroButtons[#app.ui.heroButtons + 1] = { x = x, y = rowY, w = w, h = 40, rank = hero.rank }
    end
end

local function stacksText(inventory)
    local parts = {}
    if not inventory then
        return "-"
    end
    for _, stack in ipairs(inventory:stacks()) do
        parts[#parts + 1] = stack.item .. ":" .. stack.count
    end
    return #parts > 0 and table.concat(parts, "  ") or "-"
end

local function firstOpenTrinketSlot(hero)
    for slot = 1, 2 do
        if not hero.trinkets or not hero.trinkets[slot] then
            return slot
        end
    end
    return nil
end

local function firstVisibleTrinket(sim, hero)
    for _, key in ipairs((hero and hero.trinkets) or {}) do
        if key then
            return key
        end
    end
    for _, key in ipairs(Defs.trinketOrder) do
        if ((sim.estate.trinkets or {})[key] or 0) > 0 then
            return key
        end
    end
    return nil
end

local function activeTrinketTooltipKey(app, sim, hero)
    if love and love.mouse then
        local mx, my = love.mouse.getPosition()
        for _, hitbox in ipairs((app.ui and app.ui.estateActionButtons) or {}) do
            if hitbox.tooltipKey and mx >= hitbox.x and mx <= hitbox.x + hitbox.w and my >= hitbox.y and my <= hitbox.y + hitbox.h then
                return hitbox.tooltipKey
            end
        end
    end
    return app.trinketTooltipKey or firstVisibleTrinket(sim, hero)
end

local function selectedEstateHero(sim, app)
    local selected = app.estateHeroId and sim:heroById(app.estateHeroId)
    if selected and selected.alive then
        return selected
    end
    return sim:heroAtRank(sim.player.selectedHero) or sim:heroAtRank(1) or sim.estate.roster[1]
end

local rosterFilters = {
    { key = "all", label = "all" },
    { key = "party", label = "party" },
    { key = "recovering", label = "rest" },
    { key = "stressed", label = "stress" },
}

local rosterSorts = {
    { key = "rank", label = "rank" },
    { key = "level", label = "lvl" },
    { key = "stress", label = "str" },
    { key = "name", label = "name" },
}

local function addEstateAction(app, label, x, y, w, action)
    love.graphics.setColor(action.enabled and 0.15 or 0.09, action.enabled and 0.18 or 0.09, action.enabled and 0.16 or 0.09, 1)
    love.graphics.rectangle("fill", x, y, w, 28)
    love.graphics.setColor(action.enabled and 0.48 or 0.25, action.enabled and 0.54 or 0.25, action.enabled and 0.38 or 0.25, 1)
    love.graphics.rectangle("line", x, y, w, 28)
    love.graphics.setColor(action.enabled and 0.86 or 0.42, action.enabled and 0.88 or 0.42, action.enabled and 0.8 or 0.42, 1)
    love.graphics.printf(label, x + 4, y + 7, w - 8, "center")
    if action.enabled then
        action.x = x
        action.y = y
        action.w = w
        action.h = 28
        app.ui.estateActionButtons[#app.ui.estateActionButtons + 1] = action
    end
end

local function rosterVisible(sim, hero, filter)
    if filter == "party" then
        return sim:heroRank(hero.id) ~= nil
    end
    if filter == "recovering" then
        return (hero.recovering or 0) > 0
    end
    if filter == "stressed" then
        return (hero.stress or 0) >= 50
    end
    return hero.alive ~= false
end

local function rosterEntries(sim, app)
    local filter = app.rosterFilter or "all"
    local sort = app.rosterSort or "rank"
    local heroes = {}
    for _, hero in ipairs(sim.estate.roster) do
        if rosterVisible(sim, hero, filter) then
            heroes[#heroes + 1] = hero
        end
    end
    table.sort(heroes, function(a, b)
        if sort == "level" then
            if (a.level or 1) ~= (b.level or 1) then
                return (a.level or 1) > (b.level or 1)
            end
        elseif sort == "stress" then
            if (a.stress or 0) ~= (b.stress or 0) then
                return (a.stress or 0) > (b.stress or 0)
            end
        elseif sort == "name" then
            if a.name ~= b.name then
                return a.name < b.name
            end
        else
            local ar = sim:heroRank(a.id) or 99
            local br = sim:heroRank(b.id) or 99
            if ar ~= br then
                return ar < br
            end
        end
        return (a.id or 0) < (b.id or 0)
    end)
    return heroes
end

local function drawRosterBrowser(sim, app, x, y, w, h)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Roster", x, y)
    local filter = app.rosterFilter or "all"
    local sort = app.rosterSort or "rank"
    for index, option in ipairs(rosterFilters) do
        addEstateAction(app, option.label, x + (index - 1) * 58, y + 20, 54, { action = "rosterFilter", filter = option.key, enabled = filter ~= option.key })
    end
    for index, option in ipairs(rosterSorts) do
        addEstateAction(app, option.label, x + (index - 1) * 58, y + 52, 54, { action = "rosterSort", sort = option.key, enabled = sort ~= option.key })
    end
    local selected = selectedEstateHero(sim, app)
    for index, hero in ipairs(rosterEntries(sim, app)) do
        local rowY = y + 86 + (index - 1) * 30
        if rowY + 28 > y + h then
            break
        end
        local active = selected and selected.id == hero.id
        local class = Defs.heroClass(hero.class)
        local rank = sim:heroRank(hero.id)
        local suffix = (rank and (" R" .. rank) or "") .. " S" .. (hero.stress or 0)
        love.graphics.setColor(active and 0.2 or 0.11, active and 0.23 or 0.13, active and 0.18 or 0.13, 1)
        love.graphics.rectangle("fill", x, rowY, w, 28)
        love.graphics.setColor(active and 0.72 or 0.32, active and 0.62 or 0.34, active and 0.32 or 0.28, 1)
        love.graphics.rectangle("line", x, rowY, w, 28)
        love.graphics.setColor(hero.alive and 0.9 or 0.48, hero.alive and 0.92 or 0.44, hero.alive and 0.86 or 0.42, 1)
        love.graphics.printf(hero.name .. " / " .. class.name .. " L" .. (hero.level or 1) .. suffix, x + 4, rowY + 6, w - 8, "left")
        app.ui.rosterButtons[#app.ui.rosterButtons + 1] = { x = x, y = rowY, w = w, h = 28, heroId = hero.id }
    end
    return selected
end

local function drawPartyFormation(sim, app, x, y, w)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Party Formation", x, y)
    local slotW = math.floor((w - 18) / 4)
    for rank = 1, 4 do
        local hero = sim:heroAtRank(rank)
        local sx = x + (rank - 1) * (slotW + 6)
        local sy = y + 24
        love.graphics.setColor(0.12, 0.15, 0.14, 1)
        love.graphics.rectangle("fill", sx, sy, slotW, 52)
        love.graphics.setColor(0.42, 0.52, 0.38, 1)
        love.graphics.rectangle("line", sx, sy, slotW, 52)
        love.graphics.setColor(0.88, 0.9, 0.82, 1)
        love.graphics.printf("R" .. rank, sx + 4, sy + 6, slotW - 8, "center")
        love.graphics.setColor(0.68, 0.74, 0.68, 1)
        love.graphics.printf(hero and hero.name or "empty", sx + 4, sy + 28, slotW - 8, "center")
        app.ui.partyRankSlots[#app.ui.partyRankSlots + 1] = { x = sx, y = sy, w = slotW, h = 52, rank = rank }
    end
    if app.dragHeroId then
        local hero = sim:heroById(app.dragHeroId)
        love.graphics.setColor(0.86, 0.78, 0.44, 1)
        love.graphics.printf("assigning " .. (hero and hero.name or "hero"), x, y + 84, w, "left")
    end
end

local function drawSelectedEstateHero(sim, app, hero, x, y, w)
    if not hero then
        return
    end
    local class = Defs.heroClass(hero.class)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(hero.name .. " / " .. class.name, x, y)
    love.graphics.setColor(0.74, 0.78, 0.72, 1)
    love.graphics.printf("hp " .. hero.hp .. "/" .. sim:maxHp(hero) .. " stress " .. hero.stress .. " weapon " .. (hero.weapon or 0) .. " armor " .. (hero.armor or 0), x, y + 18, w)
    local nextXp = (hero.level or 1) < 5 and ((hero.level or 1) * 2) or nil
    love.graphics.printf("rank " .. (sim:heroRank(hero.id) or "-") .. " resolve " .. sim:heroResolve(hero) .. " xp " .. (hero.xp or 0) .. (nextXp and ("/" .. nextXp) or " max"), x, y + 36, w)
    local actionY = y + 62
    for index, skillKey in ipairs(hero.skills or {}) do
        addEstateAction(app, "train " .. index, x + ((index - 1) % 3) * 82, actionY + math.floor((index - 1) / 3) * 34, 76, { action = "upgradeSkill", heroId = hero.id, skillKey = skillKey, enabled = true })
    end
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Equipment", x, actionY + 42)
    addEstateAction(app, "weapon L" .. (hero.weapon or 0), x, actionY + 62, 76, { action = "upgradeGear", heroId = hero.id, kind = "weapon", enabled = true })
    addEstateAction(app, "armor L" .. (hero.armor or 0), x + 82, actionY + 62, 76, { action = "upgradeGear", heroId = hero.id, kind = "armor", enabled = true })
    addEstateAction(app, "dismiss", x + 164, actionY + 62, 76, { action = "dismissHero", heroId = hero.id, enabled = not sim:heroRank(hero.id) and sim:livingRosterCount() > 4 and (hero.recovering or 0) <= 0 })
    for index, activityKey in ipairs(Defs.estateActivityOrder) do
        local activity = Defs.estateActivity(activityKey)
        addEstateAction(app, (activity.short or activity.name) .. " " .. activity.cost, x + ((index - 1) % 3) * 82, actionY + 96 + math.floor((index - 1) / 3) * 34, 76, { action = "recoverHero", heroId = hero.id, activityKey = activityKey, enabled = (hero.recovering or 0) <= 0 })
    end
    local trinketY = actionY + 140
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Trinkets", x, trinketY)
    for slot = 1, 2 do
        local key = hero.trinkets and hero.trinkets[slot]
        local trinket = key and Defs.trinket(key)
        local label = key and ((trinket and (trinket.short or trinket.name)) or key) or ("slot " .. slot)
        addEstateAction(app, label, x + (slot - 1) * 82, trinketY + 22, 76, { action = "unequipTrinket", heroId = hero.id, slot = slot, tooltipKey = key, enabled = key ~= false and key ~= nil })
    end
    local openSlot = firstOpenTrinketSlot(hero)
    local trinketIndex = 0
    for _, key in ipairs(Defs.trinketOrder) do
        local count = (sim.estate.trinkets or {})[key] or 0
        if count > 0 then
            trinketIndex = trinketIndex + 1
            local trinket = Defs.trinket(key)
            local bx = x + ((trinketIndex - 1) % 3) * 82
            local by = trinketY + 56 + math.floor((trinketIndex - 1) / 3) * 34
            addEstateAction(app, (trinket.short or key) .. ":" .. count, bx, by, 50, { action = "equipTrinket", heroId = hero.id, trinketKey = key, slot = openSlot, tooltipKey = key, enabled = openSlot ~= nil })
            addEstateAction(app, "$" .. (trinket.value or 0), bx + 52, by, 24, { action = "sellTrinket", trinketKey = key, tooltipKey = key, enabled = true })
        end
    end
    local tooltipKey = activeTrinketTooltipKey(app, sim, hero)
    if tooltipKey then
        local tooltipLines = Render.trinketTooltip(sim, tooltipKey)
        love.graphics.setColor(0.82, 0.78, 0.56, 1)
        love.graphics.print("Set Bonus", x, trinketY + 92)
        love.graphics.setColor(0.68, 0.72, 0.66, 1)
        for index = 1, math.min(3, #tooltipLines) do
            love.graphics.printf(tooltipLines[index], x, trinketY + 108 + (index - 1) * 16, w)
        end
    end
    local treatY = trinketY + 126
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Treatment", x, treatY)
    local index = 0
    for _, key in ipairs(hero.quirks or {}) do
        local quirk = Defs.quirk(key)
        if quirk and quirk.kind == "negative" then
            addEstateAction(app, key, x + (index % 3) * 82, treatY + 22 + math.floor(index / 3) * 34, 76, { action = "treatQuirk", heroId = hero.id, quirkKey = key, enabled = true })
            index = index + 1
        elseif quirk and quirk.kind == "positive" then
            local locked = hero.lockedQuirks and hero.lockedQuirks[key]
            addEstateAction(app, (locked and "*" or "+") .. key, x + (index % 3) * 82, treatY + 22 + math.floor(index / 3) * 34, 76, { action = "lockQuirk", heroId = hero.id, quirkKey = key, enabled = not locked })
            index = index + 1
        end
    end
    for _, key in ipairs(hero.diseases or {}) do
        addEstateAction(app, key, x + (index % 3) * 82, treatY + 22 + math.floor(index / 3) * 34, 76, { action = "treatDisease", heroId = hero.id, diseaseKey = key, enabled = true })
        index = index + 1
    end
    local rankY = treatY + 90
    for rank = 1, 4 do
        addEstateAction(app, "rank " .. rank, x + (rank - 1) * 62, rankY, 56, { action = "assignParty", heroId = hero.id, rank = rank, enabled = true })
    end
end

local function drawJournalPanel(sim, x, y, w)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Journal", x, y)
    love.graphics.setColor(0.7, 0.74, 0.68, 1)
    local entries = sim:journalEntries()
    if #entries == 0 then
        love.graphics.print("no documents", x, y + 20)
        return
    end
    local first = math.max(1, #entries - 2)
    for index = first, #entries do
        local entry = entries[index]
        love.graphics.printf(entry.title .. " - " .. entry.abstract, x, y + 20 + (index - first) * 18, w)
    end
end

function Render.drawHud(sim, app)
    local width = love.graphics.getWidth()
    panel(0, 0, width, 92, 0.9)
    if app.eventFlash then
        local color = app.eventFlash.color or { 0.42, 0.54, 0.76 }
        love.graphics.setColor(color[1], color[2], color[3], math.min(0.5, app.eventFlash.t or 0))
        love.graphics.rectangle("fill", 0, 90, width, 2)
    end
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Thoth  tick " .. sim.tick .. "  " .. sim.mode .. "  pos " .. sim.player.x .. "," .. sim.player.y .. "  view " .. ((app.viewRotation or 0) * 90), 16, 10)
    love.graphics.printf("status " .. tostring(app.status or sim.status), width - 286, 10, 270, "right")
    love.graphics.printf("next " .. sim:nextStepText(), 16, 32, width - 320)
    local checklist = sim:objectiveChecklist()[1]
    love.graphics.printf(checklistText(checklist), 16, 54, width - 32)
    local summary = Render.expeditionHudSummary(sim)
    love.graphics.printf("room " .. tostring(summary.currentRoom), 16, 74, 260)
    if sim.expedition then
        love.graphics.setColor(0.9, 0.82, 0.48, 1)
        love.graphics.printf("torch " .. tostring(summary.torch), width - 286, 36, 270, "right")
        drawMeter(width - 176, 58, 160, 8, (summary.torch or 0) / 100, { 0.86, 0.58, 0.22, 1 })
    end
    love.graphics.setColor(0.74, 0.78, 0.72, 1)
    love.graphics.printf(sim:missionProgressText(), width - 286, 74, 270, "right")
end

function Render.drawSidePanel(sim, app)
    local width, height = love.graphics.getDimensions()
    local x = width - 306
    local y = 104
    panel(x, y, 292, height - 120, 0.88)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Party", x + 10, y + 10)
    drawHeroRows(sim, app, x + 10, y + 34, 272)
    local detailY = y + 214
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Supplies", x + 10, detailY)
    love.graphics.setColor(0.75, 0.78, 0.72, 1)
    love.graphics.printf(sim.expedition and stacksText(sim.expedition.supplies) or "-", x + 10, detailY + 20, 272)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Loot", x + 10, detailY + 74)
    love.graphics.setColor(0.75, 0.78, 0.72, 1)
    love.graphics.printf(sim.expedition and stacksText(sim.expedition.loot) or ("gold:" .. sim.estate.gold .. " heirlooms:" .. sim.estate.heirlooms), x + 10, detailY + 94, 272)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Voice", x + 10, detailY + 126)
    love.graphics.setColor(0.68, 0.72, 0.68, 1)
    love.graphics.printf(sim.narration or "-", x + 10, detailY + 146, 272)
    if sim.documentPopup then
        love.graphics.setColor(0.9, 0.82, 0.58, 1)
        love.graphics.print("Document", x + 10, detailY + 166)
        love.graphics.setColor(0.68, 0.72, 0.68, 1)
        love.graphics.printf(sim.documentPopup.title .. ": " .. sim.documentPopup.text, x + 10, detailY + 184, 272)
    end
    local logY = sim.documentPopup and (detailY + 244) or (detailY + 198)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Log", x + 10, logY)
    love.graphics.setColor(0.72, 0.76, 0.72, 1)
    local log = sim.expedition and sim.expedition.log or sim.log
    for i = math.max(1, #log - 5), #log do
        love.graphics.print(log[i], x + 10, logY + 4 + (i - math.max(1, #log - 5) + 1) * 18)
    end
end

local function sceneDanger(scene)
    local kind = scene and scene.kind
    return kind == "danger" or kind == "defeat" or kind == "boss_defeat" or kind == "death_door" or kind == "hero_death" or kind == "stress_break" or kind == "resolve_affliction" or kind == "affliction_act" or kind == "ambush" or kind == "blocked"
end

local function setSceneColor(scene, alpha, amount)
    local accent = sceneAccent(scene)
    amount = amount or 1
    love.graphics.setColor(math.min(1, accent[1] * amount), math.min(1, accent[2] * amount), math.min(1, accent[3] * amount), alpha or 1)
end

local function drawCinematicMatte(x, y, w, h, progress, scene)
    local lift = phase(progress, 0, 0.25)
    local bar = 15 + 8 * (scene and scene.intensity or 1)
    love.graphics.setColor(0, 0, 0, 0.34 + 0.18 * lift)
    love.graphics.rectangle("fill", x, y, w, bar)
    love.graphics.rectangle("fill", x, y + h - bar, w, bar)
    love.graphics.setColor(0, 0, 0, 0.16)
    love.graphics.rectangle("fill", x, y, 34, h)
    love.graphics.rectangle("fill", x + w - 34, y, 34, h)
end

local function drawSceneAtmosphere(scene, x, y, w, h, progress)
    local accent = sceneAccent(scene)
    local intensity = scene and scene.intensity or 0.7
    local danger = sceneDanger(scene)
    for i = 1, 18 do
        local seed = i * 37
        local drift = (progress * (0.32 + (i % 5) * 0.06) + (seed % 97) / 97) % 1
        local px = x + ((seed * 17) % 1000) / 1000 * w
        local py = y + h - 32 - drift * (h - 54)
        local size = 2 + (i % 4)
        love.graphics.setColor(accent[1], accent[2], accent[3], (danger and 0.13 or 0.08) * intensity)
        if scene and (scene.mood == "affliction" or scene.mood == "doom") then
            love.graphics.rectangle("fill", px, py, size * 3, 1)
        else
            love.graphics.circle("fill", px, py, size)
        end
    end
    if scene and (scene.focus == "boss" or scene.boss) then
        setSceneColor(scene, 0.18 + 0.18 * math.sin(progress * math.pi), 1)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", x + w * 0.72, y + h * 0.43, 80 + 24 * phase(progress, 0.12, 0.8))
        love.graphics.circle("line", x + w * 0.72, y + h * 0.43, 42 + 18 * phase(progress, 0.2, 0.9))
        love.graphics.setLineWidth(1)
    end
    if scene and scene.beat == "seal" then
        setSceneColor(scene, 0.28 * phase(progress, 0.1, 0.9), 1.05)
        love.graphics.setLineWidth(4)
        love.graphics.line(x + w * 0.38, y + h * 0.24, x + w * 0.62, y + h * 0.24)
        love.graphics.line(x + w * 0.5, y + h * 0.16, x + w * 0.5, y + h * 0.58)
        love.graphics.setLineWidth(1)
    end
end

local function drawFocusBeam(scene, x, y, w, h, progress)
    if not scene then
        return
    end
    local focusX = scene.side == "enemy" and x + w * 0.72 or x + w * 0.3
    if scene.focus == "party" then
        focusX = x + w * 0.32
    elseif scene.focus == "boss" then
        focusX = x + w * 0.74
    end
    local pulse = math.sin(progress * math.pi)
    local accent = sceneAccent(scene)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.08 + 0.12 * pulse)
    love.graphics.polygon("fill", focusX - w * 0.16, y + 22, focusX + w * 0.16, y + 22, focusX + 62, y + h - 42, focusX - 62, y + h - 42)
end

local function drawCutsceneHud(scene, x, y, w, progress)
    local caption = scene and scene.caption or ""
    if caption == "" then
        return
    end
    local labelW = math.min(260, math.max(132, #caption * 8 + 34))
    love.graphics.setColor(0.015, 0.018, 0.018, 0.76)
    love.graphics.rectangle("fill", x + 12, y + 10, labelW, 24)
    setSceneColor(scene, 0.9, 1.05)
    love.graphics.rectangle("line", x + 12, y + 10, labelW, 24)
    love.graphics.print(string.upper(caption), x + 22, y + 15)
    for i = 1, 3 do
        local lit = progress >= (i - 1) / 3
        love.graphics.setColor(0.9, 0.82, 0.56, lit and 0.9 or 0.24)
        love.graphics.rectangle("fill", x + w - 68 + (i - 1) * 16, y + 16, 10, 5)
    end
end

local function cutsceneShake(scene, progress)
    if not scene then
        return 0, 0
    end
    local pulse = math.sin(progress * math.pi)
    local intensity = scene.intensity or 1
    if scene.camera == "quake" then
        return math.sin(progress * 54) * 4 * pulse * intensity, math.cos(progress * 41) * 3 * pulse * intensity
    end
    if scene.camera == "hit" or scene.camera == "snap" then
        local hit = phase(progress, 0.18, 0.42) * (1 - phase(progress, 0.42, 0.75))
        return (scene.side == "enemy" and -1 or 1) * hit * 6 * intensity, math.sin(progress * 35) * hit * 2
    end
    if scene.camera == "sink" then
        return 0, phase(progress, 0.1, 1) * 5 * intensity
    end
    if scene.camera == "lift" then
        return 0, -phase(progress, 0.1, 1) * 4 * intensity
    end
    return 0, 0
end

local function drawSceneWall(x, y, w, h, pulse, scene)
    local danger = sceneDanger(scene)
    local accent = sceneAccent(scene)
    love.graphics.setColor(0.045, 0.052, 0.052, 0.96)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(danger and 0.32 or 0.12 + accent[1] * 0.04, danger and 0.08 or 0.14 + accent[2] * 0.04, danger and 0.08 or 0.12 + accent[3] * 0.04, 0.92)
    love.graphics.rectangle("fill", x, y + h * 0.55, w, h * 0.45)
    local blockW = math.max(54, w / 12)
    for row = 0, 3 do
        for col = 0, 11 do
            local bx = x + col * blockW + (row % 2) * blockW * 0.42
            local by = y + 18 + row * 34
            if bx < x + w - 12 then
                love.graphics.setColor(0.1 + accent[1] * 0.08 + pulse * 0.04, 0.12 + accent[2] * 0.1 + pulse * 0.04, 0.11 + accent[3] * 0.08 + pulse * 0.04, 0.5)
                love.graphics.rectangle("line", bx, by, blockW - 5, 26)
            end
        end
    end
    love.graphics.setColor(accent[1], math.min(1, accent[2] + pulse * 0.22), accent[3], 0.78)
    love.graphics.rectangle("fill", x + 24, y + 28, w - 48, 3)
    love.graphics.circle("fill", x + w * 0.5, y + 30, 10 + pulse * 7)
    love.graphics.setColor(0.08, 0.08, 0.07, 0.72)
    love.graphics.rectangle("fill", x, y + h - 30, w, 30)
end

local function drawSceneFigure(cx, floorY, side, label, active, danger, scene, rank, progress)
    local dir = side == "ally" and 1 or -1
    local bodyR, bodyG, bodyB = 0.52, 0.57, 0.48
    if side == "enemy" then
        bodyR, bodyG, bodyB = 0.48, 0.28, 0.25
    end
    if danger then
        bodyR, bodyG, bodyB = 0.58, 0.16, 0.13
    end
    if active and scene then
        local beat = scene.beat
        local t = progress or 0
        local force = scene.intensity or 1
        if beat == "fall" or beat == "collapse" then
            floorY = floorY + phase(t, 0.16, 1) * 18 * force
        elseif beat == "revive" or beat == "triumph" or beat == "resolve" or beat == "seal" then
            floorY = floorY - math.sin(t * math.pi) * 8 * force
        elseif beat == "stagger" or beat == "break" or beat == "fracture" then
            cx = cx + math.sin(t * math.pi * 8 + (rank or 0)) * 5 * force
        elseif beat == "strike" or beat == "smite" or beat == "lash" then
            cx = cx + dir * math.sin(t * math.pi) * 8 * force
        end
    end
    love.graphics.setColor(0, 0, 0, 0.42)
    love.graphics.ellipse("fill", cx, floorY + 4, 23, 7)
    if active then
        setSceneColor(scene, 0.22, 1.1)
        love.graphics.circle("fill", cx, floorY - 40, 33 + 10 * math.sin((progress or 0) * math.pi))
    end
    love.graphics.setColor(bodyR, bodyG, bodyB, active and 1 or 0.78)
    love.graphics.polygon("fill", cx - 12, floorY - 48, cx + 12, floorY - 48, cx + 16, floorY - 8, cx - 16, floorY - 8)
    love.graphics.setColor(0.86, 0.78, 0.58, active and 1 or 0.8)
    love.graphics.circle("fill", cx, floorY - 60, 11)
    love.graphics.setColor(0.08, 0.08, 0.07, 0.9)
    love.graphics.circle("line", cx, floorY - 60, 11)
    love.graphics.setLineWidth(active and 4 or 2)
    love.graphics.setColor(0.74, 0.72, 0.62, active and 1 or 0.62)
    love.graphics.line(cx + dir * 8, floorY - 42, cx + dir * 32, floorY - 64)
    love.graphics.line(cx - dir * 8, floorY - 30, cx - dir * 18, floorY - 5)
    love.graphics.line(cx + dir * 8, floorY - 30, cx + dir * 18, floorY - 5)
    love.graphics.setLineWidth(1)
    if active then
        setSceneColor(scene, 0.9, 1.15)
        love.graphics.rectangle("line", cx - 22, floorY - 78, 44, 76)
        if scene and (scene.mood == "affliction" or scene.mood == "doom" or scene.mood == "dazed") then
            setSceneColor(scene, 0.62, 1.2)
            love.graphics.line(cx - 18, floorY - 74, cx + 18, floorY - 4)
            love.graphics.line(cx + 18, floorY - 74, cx - 18, floorY - 4)
        end
    end
    love.graphics.setColor(0.84, 0.86, 0.78, active and 1 or 0.72)
    love.graphics.printf(label or "", cx - 44, floorY + 12, 88, "center")
end

local function drawBossSigil(cx, y, pulse)
    love.graphics.setColor(0.72, 0.08, 0.08, 0.45 + pulse * 0.35)
    love.graphics.circle("line", cx, y, 38 + pulse * 16)
    love.graphics.line(cx - 30, y, cx + 30, y)
    love.graphics.line(cx, y - 30, cx, y + 30)
end

local function drawHeroLine(sim, floorY, x, scene, lunge, intro, progress)
    for rank = 1, 4 do
        local hero = sim:heroAtRank(rank)
        if hero and hero.alive then
            local partyFocus = scene.focus == "party" or scene.beat == "triumph" or scene.beat == "seal"
            local active = (scene.side == "ally" and scene.actor == hero.name) or (partyFocus and scene.side == "ally")
            local cx = x + (rank - 1) * 56 - intro * 70
            if active then
                cx = cx + lunge * 86
            end
            drawSceneFigure(cx, floorY, "ally", hero.name, active, false, scene, rank, progress)
        end
    end
end

local function drawEnemyLine(sim, floorY, x, scene, lunge, intro, progress)
    local labels = scene.enemies or {}
    if not (sim and sim.combat) and #labels == 0 then
        return
    end
    for rank = 1, 4 do
        local enemy = sim and sim.combat and sim:enemyAtRank(rank) or nil
        local name = labels[rank]
        local isBoss = false
        if enemy then
            local def = Defs.enemy(enemy.kind)
            name = def.name
            isBoss = def.boss == true
        end
        if name then
            local broadFocus = scene.side == "enemy" and scene.focus ~= "actor"
            local active = (scene.side == "enemy" and scene.actor == name) or broadFocus or (scene.focus == "boss" and (isBoss or rank == 1))
            local cx = x - (rank - 1) * (isBoss and 72 or 56) + intro * 70
            if active then
                cx = cx - lunge * (isBoss and 112 or 86)
            end
            if isBoss or (scene.boss and rank == 1) then
                drawBossSigil(cx, floorY - 58, math.abs(lunge) + math.abs(intro) * 0.6)
            end
            drawSceneFigure(cx, floorY, "enemy", name, active or isBoss, scene.kind == "danger" or scene.kind == "boss_defeat" or scene.kind == "boss_strike", scene, rank, progress)
        end
    end
end

local function drawImpact(scene, x, y, w, h, progress)
    local pulse = math.sin(progress * math.pi)
    local kind = scene.kind
    local accent = sceneAccent(scene)
    if kind == "intro" or kind == "boss_intro" then
        local reveal = phase(progress, 0.04, 0.68)
        setSceneColor(scene, 0.22 + 0.24 * pulse, kind == "boss_intro" and 1.2 or 1)
        love.graphics.rectangle("fill", x + w * (0.55 + reveal * 0.12), y + h * 0.18, 8, h * 0.52)
        love.graphics.rectangle("fill", x + w * (0.78 - reveal * 0.12), y + h * 0.18, 8, h * 0.52)
        love.graphics.setLineWidth(kind == "boss_intro" and 6 or 3)
        love.graphics.line(x + w * 0.57, y + h * 0.22, x + w * 0.77, y + h * 0.64)
        love.graphics.line(x + w * 0.77, y + h * 0.22, x + w * 0.57, y + h * 0.64)
        if kind == "boss_intro" then
            love.graphics.circle("line", x + w * 0.72, y + h * 0.43, 48 + 70 * pulse)
            love.graphics.circle("line", x + w * 0.72, y + h * 0.43, 18 + 30 * reveal)
        end
        love.graphics.setLineWidth(1)
    elseif kind == "strike" or kind == "boss_strike" then
        local cx = scene.side == "enemy" and x + w * 0.42 or x + w * 0.58
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.82 * pulse)
        love.graphics.setLineWidth(kind == "boss_strike" and 8 or 5)
        love.graphics.line(cx - 52, y + h * 0.42, cx + 58, y + h * 0.26)
        love.graphics.line(cx - 35, y + h * 0.28, cx + 45, y + h * 0.52)
        love.graphics.line(cx - 62, y + h * (0.5 - 0.08 * pulse), cx + 68, y + h * (0.5 + 0.08 * pulse))
        if kind == "boss_strike" then
            love.graphics.circle("line", cx, y + h * 0.4, 36 + pulse * 60)
        end
        love.graphics.setLineWidth(1)
    elseif kind == "victory" or kind == "boss_victory" or kind == "campaign_victory" then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.7 * smooth(progress))
        love.graphics.circle("line", x + w * 0.5, y + h * 0.48, 44 + 120 * progress)
        love.graphics.rectangle("fill", x + w * 0.5 - 4, y + h * 0.2, 8, 80 * pulse)
        if kind == "campaign_victory" then
            love.graphics.setLineWidth(4)
            love.graphics.line(x + w * 0.42, y + h * 0.4, x + w * 0.58, y + h * 0.4)
            love.graphics.line(x + w * 0.5, y + h * 0.28, x + w * 0.5, y + h * 0.58)
            love.graphics.setLineWidth(1)
        end
    elseif kind == "defeat" or kind == "boss_defeat" or kind == "danger" then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.26 * pulse)
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setColor(0, 0, 0, 0.42 * smooth(progress))
        love.graphics.rectangle("fill", x, y, w, h * smooth(progress))
    elseif kind == "ambush" then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.42 * pulse)
        for i = 0, 5 do
            love.graphics.rectangle("fill", x + i * w / 6, y, 12, h)
        end
    elseif kind == "retreat" then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.75 * pulse)
        love.graphics.polygon("fill", x + w * (0.65 - progress * 0.35), y + h * 0.45, x + w * (0.75 - progress * 0.35), y + h * 0.34, x + w * (0.75 - progress * 0.35), y + h * 0.56)
    elseif kind == "blocked" then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.8 * pulse)
        love.graphics.setLineWidth(7)
        love.graphics.line(x + w * 0.45, y + h * 0.32, x + w * 0.55, y + h * 0.58)
        love.graphics.line(x + w * 0.55, y + h * 0.32, x + w * 0.45, y + h * 0.58)
        love.graphics.setLineWidth(1)
    elseif kind == "death_door" or kind == "hero_death" or kind == "death_save" then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.72 * pulse)
        love.graphics.circle("line", x + w * 0.28, y + h * 0.48, 28 + 42 * pulse)
        love.graphics.line(x + w * 0.28, y + h * 0.32, x + w * 0.28, y + h * 0.64)
    elseif kind == "resolve_virtue" or kind == "resolve_affliction" or kind == "stress_break" or kind == "affliction_act" then
        local good = kind == "resolve_virtue"
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.55 * pulse)
        love.graphics.circle("line", x + w * 0.34, y + h * 0.43, 32 + 58 * pulse)
        love.graphics.circle("fill", x + w * 0.34, y + h * 0.43, 8 + 8 * pulse)
        if not good then
            love.graphics.line(x + w * 0.3, y + h * 0.3, x + w * 0.38, y + h * 0.56)
            love.graphics.line(x + w * 0.38, y + h * 0.3, x + w * 0.3, y + h * 0.56)
        end
    elseif kind == "falter" or kind == "hero_hold" then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.5 * pulse)
        love.graphics.line(x + w * 0.3, y + h * 0.32, x + w * 0.3, y + h * 0.6)
        love.graphics.line(x + w * 0.32, y + h * 0.32, x + w * 0.32, y + h * 0.6)
    end
end

function Render.drawCutscene(sim, app)
    local currentScene = app and app.cutscene
    if not currentScene then
        return
    end
    local width = love.graphics.getWidth()
    local x = 28
    local w = math.max(360, width - 370)
    local y = 92
    local h = 238
    local progress = clamp01((currentScene.elapsed or 0) / (currentScene.duration or 0.75))
    local pulse = math.sin(progress * math.pi)
    local intro = (currentScene.kind == "intro" or currentScene.kind == "boss_intro" or currentScene.kind == "ambush") and (1 - smooth(progress)) or 0
    local lunge = (currentScene.kind == "strike" or currentScene.kind == "boss_strike") and pulse or 0
    local shakeX, shakeY = cutsceneShake(currentScene, progress)
    love.graphics.push("all")
    love.graphics.setDepthMode()
    love.graphics.translate(shakeX, shakeY)
    drawSceneWall(x, y, w, h, pulse, currentScene)
    drawSceneAtmosphere(currentScene, x, y, w, h, progress)
    drawFocusBeam(currentScene, x, y, w, h, progress)
    drawHeroLine(sim, y + h - 42, x + 92, currentScene, lunge, intro, progress)
    drawEnemyLine(sim, y + h - 42, x + w - 96, currentScene, lunge, intro, progress)
    drawImpact(currentScene, x, y, w, h, progress)
    drawCinematicMatte(x, y, w, h, progress, currentScene)
    drawCutsceneHud(currentScene, x, y, w, progress)
    love.graphics.setColor(0.02, 0.025, 0.026, 0.72)
    love.graphics.rectangle("fill", x, y + h - 34, w, 34)
    love.graphics.setColor(0.93, 0.9, 0.78, 1)
    love.graphics.printf(currentScene.title or "", x + 18, y + h - 25, w - 36, "center")
    setSceneColor(currentScene, 0.92, 1.05)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.pop()
end

function Render.drawCombatStage(sim, app)
    if app and app.cutscene then
        return
    end
    local currentScene = Render.idleCombatScene(sim)
    if not currentScene then
        return
    end
    local width = love.graphics.getWidth()
    local x = 28
    local w = math.max(360, width - 370)
    local y = 92
    local h = 238
    love.graphics.push("all")
    love.graphics.setDepthMode()
    drawSceneWall(x, y, w, h, 0.08, currentScene)
    drawSceneAtmosphere(currentScene, x, y, w, h, 0.15)
    drawHeroLine(sim, y + h - 42, x + 92, currentScene, 0, 0, 0)
    drawEnemyLine(sim, y + h - 42, x + w - 96, currentScene, 0, 0, 0)
    love.graphics.setColor(0.02, 0.025, 0.026, 0.62)
    love.graphics.rectangle("fill", x, y + h - 34, w, 34)
    love.graphics.setColor(0.82, 0.84, 0.76, 0.92)
    love.graphics.printf(currentScene.title or "", x + 18, y + h - 25, w - 36, "center")
    love.graphics.setColor(0.28, 0.34, 0.3, 0.9)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.pop()
end

function Render.drawCombatOverlay(sim, app)
    if sim.mode ~= "combat" or not sim.combat then
        return
    end
    local width, height = love.graphics.getDimensions()
    local x = 28
    local y = height - 206
    local w = width - 370
    panel(x, y, w, 186, 0.93)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Combat  round " .. sim.combat.round, x + 10, y + 8)
    local active = sim:activeHero()
    love.graphics.print(active and (active.name .. " acts") or "enemy turn", x + 170, y + 8)
    local summary = Render.combatHudSummary(sim, app)
    local turnLabels = {}
    for _, turn in ipairs(summary.turns) do
        turnLabels[#turnLabels + 1] = (turn.active and ">" or "") .. turn.label
    end
    love.graphics.setColor(0.68, 0.72, 0.66, 1)
    love.graphics.printf("turn " .. table.concat(turnLabels, "  "), x + 10, y + 24, w - 20)
    if summary.skill then
        love.graphics.setColor(0.9, 0.72, 0.42, 1)
        love.graphics.printf("target " .. tostring(summary.target or "-") .. " for " .. tostring(summary.skill), x + w - 310, y + 8, 292, "right")
    end
    for rank = 1, 4 do
        local hero = sim:heroAtRank(rank)
        local hx = x + 18 + (rank - 1) * 92
        love.graphics.setColor(0.14, 0.18, 0.15, 1)
        love.graphics.rectangle("fill", hx, y + 38, 82, 58)
        love.graphics.setColor(0.42, 0.52, 0.38, 1)
        love.graphics.rectangle("line", hx, y + 38, 82, 58)
        love.graphics.setColor(0.9, 0.92, 0.86, 1)
        love.graphics.print("R" .. rank, hx + 4, y + 42)
        love.graphics.printf(hero and hero.name or "-", hx + 4, y + 44, 74, "center")
        if hero then
            love.graphics.printf(hero.hp .. "hp " .. hero.stress .. "s", hx + 4, y + 66, 74, "center")
            app.ui.heroButtons[#app.ui.heroButtons + 1] = { x = hx, y = y + 38, w = 82, h = 58, rank = rank, side = "ally" }
        end
    end
    for rank = 1, 4 do
        local enemy = sim:enemyAtRank(rank)
        local ex = x + w - 386 + (rank - 1) * 92
        love.graphics.setColor(0.2, 0.11, 0.12, 1)
        love.graphics.rectangle("fill", ex, y + 38, 82, 58)
        love.graphics.setColor(0.58, 0.28, 0.28, 1)
        love.graphics.rectangle("line", ex, y + 38, 82, 58)
        love.graphics.setColor(0.94, 0.86, 0.82, 1)
        love.graphics.print("E" .. rank, ex + 4, y + 42)
        love.graphics.printf(enemy and Defs.enemy(enemy.kind).name or "-", ex + 4, y + 44, 74, "center")
        if enemy then
            love.graphics.printf(enemy.hp .. "hp", ex + 4, y + 66, 74, "center")
            app.ui.enemyButtons[#app.ui.enemyButtons + 1] = { x = ex, y = y + 38, w = 82, h = 58, rank = rank, side = "enemy" }
            for index, part in ipairs(enemy.parts or {}) do
                if index <= 2 then
                    local pw = 38
                    local px = ex + 2 + (index - 1) * 40
                    local py = y + 98
                    love.graphics.setColor(part.disabled and 0.11 or 0.26, part.disabled and 0.1 or 0.13, part.disabled and 0.1 or 0.16, 1)
                    love.graphics.rectangle("fill", px, py, pw, 16)
                    love.graphics.setColor(part.disabled and 0.28 or 0.72, part.disabled and 0.24 or 0.38, part.disabled and 0.24 or 0.42, 1)
                    love.graphics.rectangle("line", px, py, pw, 16)
                    love.graphics.setColor(part.disabled and 0.42 or 0.96, part.disabled and 0.4 or 0.82, part.disabled and 0.4 or 0.82, 1)
                    love.graphics.printf(string.sub(part.name or part.key, 1, 4) .. " " .. tostring(part.hp or 0), px + 1, py + 3, pw - 2, "center")
                    if not part.disabled then
                        app.ui.enemyButtons[#app.ui.enemyButtons + 1] = { x = px, y = py, w = pw, h = 16, rank = rank, side = "enemy", partKey = part.key }
                    end
                end
            end
        end
    end
    local skillY = y + 116
    for _, skill in ipairs(sim:availableSkills()) do
        local sx = x + 12 + (skill.index - 1) * 150
        love.graphics.setColor(skill.usable and 0.18 or 0.1, skill.usable and 0.22 or 0.1, skill.usable and 0.2 or 0.1, 1)
        love.graphics.rectangle("fill", sx, skillY, 140, 42)
        love.graphics.setColor(skill.usable and 0.74 or 0.34, skill.usable and 0.66 or 0.34, skill.usable and 0.36 or 0.32, 1)
        love.graphics.rectangle("line", sx, skillY, 140, 42)
        love.graphics.setColor(skill.usable and 0.94 or 0.46, skill.usable and 0.96 or 0.46, skill.usable and 0.9 or 0.46, 1)
        love.graphics.printf(skill.index .. " " .. skill.name, sx + 6, skillY + 8, 128, "center")
        if skill.usable then
            local def = Defs.skill(skill.key)
            app.ui.skillButtons[#app.ui.skillButtons + 1] = { x = sx, y = skillY, w = 140, h = 42, skillKey = skill.key, targetSide = def.target == "ally" and "ally" or (def.target == "enemy" and "enemy" or nil), immediate = def.target == "self" or def.target == "party" }
        end
    end
end

function Render.drawCampOverlay(sim, app)
    if not (sim.expedition and sim.expedition.camping) then
        return
    end
    local width, height = love.graphics.getDimensions()
    local x = 28
    local y = height - 238
    local w = width - 370
    panel(x, y, w, 218, 0.93)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Camp  respite " .. sim.expedition.camping.respite, x + 10, y + 8)
    local summary = Render.campHudSummary(sim, app)
    if summary.pendingSkill then
        love.graphics.setColor(0.9, 0.72, 0.42, 1)
        love.graphics.printf("assign " .. tostring(summary.pendingSkill), x + w - 260, y + 8, 240, "right")
    end
    local skillY = y + 42
    for _, skill in ipairs(sim:availableCampSkills()) do
        local sx = x + 12 + ((skill.index - 1) % 4) * 150
        local sy = skillY + math.floor((skill.index - 1) / 4) * 58
        love.graphics.setColor(skill.usable and 0.18 or 0.1, skill.usable and 0.22 or 0.1, skill.usable and 0.2 or 0.1, 1)
        love.graphics.rectangle("fill", sx, sy, 140, 50)
        love.graphics.setColor(skill.usable and 0.74 or 0.34, skill.usable and 0.66 or 0.34, skill.usable and 0.36 or 0.32, 1)
        love.graphics.rectangle("line", sx, sy, 140, 50)
        love.graphics.setColor(skill.usable and 0.94 or 0.46, skill.usable and 0.96 or 0.46, skill.usable and 0.9 or 0.46, 1)
        love.graphics.printf(skill.index .. " " .. skill.name, sx + 6, sy + 7, 128, "center")
        love.graphics.printf("cost " .. skill.cost, sx + 6, sy + 28, 128, "center")
        if skill.usable then
            local def = Defs.campSkill(skill.key)
            app.ui.campSkillButtons[#app.ui.campSkillButtons + 1] = { x = sx, y = sy, w = 140, h = 50, skillKey = skill.key, target = def and def.target or "party" }
        end
    end
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Assign Hero", x + 10, y + 162)
    for _, hero in ipairs(sim:partyState()) do
        local hx = x + 100 + (hero.rank - 1) * 104
        local hy = y + 154
        love.graphics.setColor(0.12, 0.15, 0.14, 1)
        love.graphics.rectangle("fill", hx, hy, 96, 40)
        love.graphics.setColor(0.42, 0.52, 0.38, 1)
        love.graphics.rectangle("line", hx, hy, 96, 40)
        love.graphics.setColor(0.88, 0.9, 0.82, 1)
        love.graphics.printf("R" .. hero.rank .. " " .. hero.name, hx + 4, hy + 13, 88, "center")
        app.ui.campHeroButtons[#app.ui.campHeroButtons + 1] = { x = hx, y = hy, w = 96, h = 40, rank = hero.rank }
    end
end

function Render.drawEstatePanel(sim, app)
    if app.panel ~= "estate" and sim.mode ~= "estate" then
        return
    end
    local x = 24
    local y = 92
    panel(x, y, 720, 610, 0.92)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Estate", x + 10, y + 10)
    love.graphics.print("week " .. (sim.estate.week or 1) .. "  gold " .. sim.estate.gold .. "  heirlooms " .. sim.estate.heirlooms, x + 10, y + 34)
    local campaign = sim.estate.campaign or {}
    local bosses = 0
    for _, key in ipairs(Defs.locationOrder) do
        if campaign.bossKills and campaign.bossKills[key] then
            bosses = bosses + 1
        end
    end
    local campaignStatus = campaign.lost and ("lost " .. (campaign.lossReason or "")) or (campaign.victory and "victory" or ("bosses " .. bosses .. "/" .. #Defs.locationOrder))
    love.graphics.print("renown " .. (campaign.renown or 0) .. "  dread " .. (campaign.dread or 0) .. "  " .. campaignStatus, x + 390, y + 34)
    drawJournalPanel(sim, x + 390, y + 58, 320)
    addEstateAction(app, "journal", x + 622, y + 56, 88, { action = "openJournal", enabled = true })
    local timerCopy = sim:panelCopy("timer_panel_copy")
    local factionCopy = sim:panelCopy("faction_panel_copy")
    love.graphics.setColor(0.62, 0.66, 0.58, 1)
    love.graphics.printf((timerCopy and timerCopy.body or "") .. " " .. (factionCopy and factionCopy.body or ""), x + 390, y + 128, 320)
    love.graphics.setColor(0.74, 0.78, 0.72, 1)
    love.graphics.print("roster " .. sim:livingRosterCount() .. "/" .. sim:rosterLimit() .. "  recruits " .. #sim.estate.recruits, x + 10, y + 58)
    if sim.estate.currentEvent then
        love.graphics.print("event " .. Defs.townEvent(sim.estate.currentEvent).name, x + 220, y + 58)
    end
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Buildings", x + 10, y + 82)
    for index, key in ipairs(Defs.estateBuildingOrder) do
        local building = Defs.estateBuilding(key)
        local level = sim:buildingLevel(key)
        local cost = (building.heirloomCost or 0) * (level + 1)
        local bx = x + 10 + ((index - 1) % 2) * 154
        local by = y + 104 + math.floor((index - 1) / 2) * 34
        local label = string.sub(building.name, 1, 10) .. " " .. level .. "/" .. building.maxLevel .. " " .. cost .. "h"
        addEstateAction(app, label, bx, by, 148, { action = "upgradeBuilding", buildingKey = key, enabled = level < building.maxLevel and sim.estate.heirlooms >= cost })
    end
    local trinkets = {}
    for _, key in ipairs(Defs.trinketOrder) do
        local count = (sim.estate.trinkets or {})[key] or 0
        if count > 0 then
            trinkets[#trinkets + 1] = key .. ":" .. count
        end
    end
    love.graphics.printf(#trinkets > 0 and table.concat(trinkets, "  ") or "no trinkets", x + 10, y + 174, 312)
    love.graphics.print("Market", x + 10, y + 196)
    for index, offer in ipairs(sim.estate.trinketStock or {}) do
        local trinket = Defs.trinket(offer.trinket)
        addEstateAction(app, (trinket.short or offer.trinket) .. " " .. offer.price, x + 70 + (index - 1) * 112, y + 190, 104, { action = "buyTrinket", stockIndex = index, enabled = sim.estate.gold >= (offer.price or 0) })
    end
    love.graphics.printf("cart " .. stacksText(sim.estate.provisionCart), x + 10, y + 220, 400)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Missions", x + 10, y + 246)
    for index, key in ipairs(sim:availableMissionKeys()) do
        local mission = Defs.mission(key)
        local bx = x + 10 + ((index - 1) % 2) * 205
        local by = y + 268 + math.floor((index - 1) / 2) * 44
        love.graphics.setColor(0.13, 0.16, 0.15, 1)
        love.graphics.rectangle("fill", bx, by, 196, 38)
        love.graphics.setColor(0.42, 0.48, 0.36, 1)
        love.graphics.rectangle("line", bx, by, 196, 38)
        love.graphics.setColor(0.86, 0.88, 0.8, 1)
        love.graphics.printf((mission.difficulty or "mission") .. " " .. mission.kind, bx + 4, by + 5, 188, "center")
        local location = Defs.location(mission.location)
        love.graphics.setColor(0.58, 0.62, 0.55, 1)
        love.graphics.printf("kit " .. compactStacks(location and location.provisions), bx + 4, by + 21, 188, "center")
        app.ui.missionButtons[#app.ui.missionButtons + 1] = { x = bx, y = by, w = 196, h = 38, missionKey = key }
    end
    drawPartyFormation(sim, app, x + 10, y + 356, 410)
    local recruitY = y + 452
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Recruits", x + 10, recruitY)
    for index, recruit in ipairs(sim.estate.recruits or {}) do
        local bx = x + 10 + ((index - 1) % 3) * 136
        local by = recruitY + 24 + math.floor((index - 1) / 3) * 34
        love.graphics.setColor(0.13, 0.14, 0.16, 1)
        love.graphics.rectangle("fill", bx, by, 128, 28)
        love.graphics.setColor(0.38, 0.42, 0.52, 1)
        love.graphics.rectangle("line", bx, by, 128, 28)
        love.graphics.setColor(0.86, 0.88, 0.8, 1)
        love.graphics.printf(recruit.name .. " " .. Defs.heroClass(recruit.class).name, bx + 4, by + 7, 120, "center")
        app.ui.recruitButtons[#app.ui.recruitButtons + 1] = { x = bx, y = by, w = 128, h = 28, recruitIndex = index }
    end
    local provisionY = y + 544
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Provisions", x + 10, provisionY)
    local provisionItems = {}
    for _, itemKey in ipairs(Defs.itemOrder) do
        if Defs.item(itemKey).provision then
            provisionItems[#provisionItems + 1] = itemKey
        end
    end
    for index, itemKey in ipairs(provisionItems) do
        local item = Defs.item(itemKey)
        local bx = x + 10 + ((index - 1) % 3) * 136
        local by = provisionY + 24 + math.floor((index - 1) / 3) * 34
        love.graphics.setColor(0.14, 0.13, 0.12, 1)
        love.graphics.rectangle("fill", bx, by, 128, 28)
        love.graphics.setColor(0.48, 0.42, 0.32, 1)
        love.graphics.rectangle("line", bx, by, 128, 28)
        love.graphics.setColor(0.86, 0.88, 0.8, 1)
        love.graphics.printf(item.name .. " " .. item.cost .. "g", bx + 4, by + 7, 120, "center")
        app.ui.provisionButtons[#app.ui.provisionButtons + 1] = { x = bx, y = by, w = 128, h = 28, item = itemKey, tooltip = sim:itemTooltip(itemKey) }
    end
    local selected = drawRosterBrowser(sim, app, x + 446, y + 10, 252, 254)
    drawSelectedEstateHero(sim, app, selected, x + 446, y + 286, 252)
end

function Render.draw(sim, app)
    Render.prepareUi(app)
    if not (love and love.graphics) then
        Render.drawWorld(sim, app)
        return
    end
    love.graphics.clear(0.055, 0.058, 0.065, 1)
    Render.drawWorld(sim, app)
    love.graphics.push("all")
    love.graphics.setDepthMode()
    Render.drawHud(sim, app)
    Render.drawSidePanel(sim, app)
    Render.drawCombatStage(sim, app)
    Render.drawCombatOverlay(sim, app)
    Render.drawCampOverlay(sim, app)
    Render.drawEstatePanel(sim, app)
    Render.drawCurioResult(app)
    Render.drawCurioModal(app)
    Render.drawCutscene(sim, app)
    Render.drawKeyboardFocus(app)
    Render.drawTutorial(app)
    Render.drawPauseMenu(app)
    Render.drawConfirmDialog(app)
    love.graphics.pop()
end

return Render
