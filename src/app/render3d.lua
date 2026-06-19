local Defs = require("src.game.defs")

local Render3D = {}
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

function Render3D.prepareUi(app)
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
    clearList(app.ui.skillButtons)
    clearList(app.ui.heroButtons)
    clearList(app.ui.enemyButtons)
    clearList(app.ui.itemButtons)
    clearList(app.ui.missionButtons)
    clearList(app.ui.recruitButtons)
    clearList(app.ui.provisionButtons)
    clearList(app.ui.estateActionButtons)
    clearList(app.ui.rosterButtons)
end

local function eventCaption(event, fallback)
    local value = event and (event.skill or event.actor)
    return value and tostring(value) or fallback
end

local function encounterCaption(event, fallback)
    local enemies = event and event.enemies
    return enemies and enemies[1] and tostring(enemies[1]) or fallback
end

function Render3D.cutsceneForEvent(event, sim)
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

function Render3D.cutsceneForStatus(message, sim)
    return Render3D.cutsceneForEvent({ message = message }, sim)
end

function Render3D.idleCombatScene(sim)
    if not (sim and sim.mode == "combat" and sim.combat) then
        return nil
    end
    local active = sim:activeHero()
    return scene("idle", active and (active.name .. " acts") or "enemy turn", { side = "ally", duration = 1 })
end

function Render3D.advanceCutscene(app, dt)
    if not (app and app.cutscene) then
        return
    end
    local cutscene = app.cutscene
    cutscene.elapsed = (cutscene.elapsed or 0) + (dt or 0)
    if cutscene.elapsed >= (cutscene.duration or 0.75) then
        app.cutscene = nil
    end
end

function Render3D.rotateDelta(dx, dy, rotation)
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

function Render3D.unrotateDelta(rx, ry, rotation)
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

function Render3D.projectIso(view, x, y)
    local rx, ry = Render3D.rotateDelta(x - view.originX, y - view.originY, view.rotation)
    return view.centerX + (rx - ry) * view.halfW, view.centerY + (rx + ry) * view.halfH
end

function Render3D.screenToWorld(view, x, y)
    local sx = x - view.centerX
    local sy = y - view.centerY
    local rx = (sx / view.halfW + sy / view.halfH) / 2
    local ry = (sy / view.halfH - sx / view.halfW) / 2
    local dx, dy = Render3D.unrotateDelta(rx, ry, view.rotation)
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

function Render3D.load()
    state.loaded = true
    state.headless = not (love and love.graphics)
    state.assets = {}
    state.g3d = nil
    state.loadError = nil
    if state.headless then
        Render3D.state = state
        return state
    end
    local ok, g3dOrErr = pcall(require, "vendor.g3d.g3d")
    if not ok then
        state.loadError = g3dOrErr
        Render3D.state = state
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
    Render3D.state = state
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

function Render3D.drawWorld(sim, app)
    app.worldView = app.worldView or {}
    app.worldView.mode = "render3d-placeholder"
    app.worldView.centerX = 0
    app.worldView.centerY = 0
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

function Render3D.drawHud()
end

function Render3D.drawSidePanel()
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

function Render3D.drawCutscene(sim, app)
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

function Render3D.drawCombatStage(sim, app)
    if app and app.cutscene then
        return
    end
    local currentScene = Render3D.idleCombatScene(sim)
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

function Render3D.drawCombatOverlay()
end

function Render3D.drawCampOverlay()
end

function Render3D.drawEstatePanel()
end

function Render3D.draw(sim, app)
    if love and love.graphics then
        love.graphics.clear(0.055, 0.058, 0.065, 1)
    end
    Render3D.prepareUi(app)
    Render3D.drawWorld(sim, app)
    Render3D.drawCombatStage(sim, app)
    Render3D.drawCutscene(sim, app)
end

return Render3D
