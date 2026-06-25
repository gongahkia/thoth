local Defs = require("src.game.defs")
local Settings = require("src.app.settings")
local Credits = require("src.app.credits")
local TacticsUICatalog = require("src.game.tactics.ui_catalog")
local SquadLoadout = require("src.game.tactics.squad_loadout")

local function t(key, vars)
    local text = tostring(key or "")
    for name, value in pairs(vars or {}) do
        text = text:gsub("{" .. name .. "}", tostring(value))
    end
    return text
end

local i18n = { t = t }

local Render = {}
Render.Topology = require("src.core.topology")
Render.TileAtlas = require("src.app.tile_atlas")
local state = {
    loaded = false,
    headless = false,
    g3d = nil,
    assets = {},
    fonts = {},
}
local cameraPitch = math.rad(30)
local cameraDistance = 26
local cameraViewSize = 24
local minTacticalZoom = 0.65
local maxTacticalZoom = 2.4
local baseYaw = math.rad(45)
local visibleRadius = 10
local atlasColumns = 8
local atlasRows = 5
local defaultAtlasMeta = {
    image = "assets/sprites/oga_700_sprites.png",
    frameWidth = 32,
    frameHeight = 32,
    columns = 16,
    rows = 19,
    frames = 304,
}
local uiHitboxGroups = {
    "titleButtons",
    "settingsButtons",
    "pauseButtons",
    "confirmButtons",
    "gameOverButtons",
    "creditsButtons",
    "journalButtons",
    "tutorialButtons",
    "squadLoadoutButtons",
    "tacticalIntentButtons",
    "curioButtons",
    "campSkillButtons",
    "campHeroButtons",
    "skillButtons",
    "enemyButtons",
    "heroButtons",
    "missionButtons",
    "recruitButtons",
    "provisionButtons",
    "rosterButtons",
    "partyRankSlots",
    "estateActionButtons",
}

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

local function copyValue(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, nested in pairs(value) do
        result[key] = copyValue(nested)
    end
    return result
end

local function hitboxContains(hitbox, x, y)
    return hitbox and x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h
end

local function accessibilitySettings(appOrSettings)
    if appOrSettings and appOrSettings.settings then
        return appOrSettings.settings
    end
    return appOrSettings
end

function Render.fontScale(settings)
    return clamp((settings and settings.fontScale) or 1, 0.8, 1.4)
end

function Render.reducedMotion(appOrSettings)
    local settings = accessibilitySettings(appOrSettings)
    return settings and settings.reducedMotion == true
end

function Render.screenShakeEnabled(appOrSettings)
    local settings = accessibilitySettings(appOrSettings)
    return not (settings and (settings.reducedMotion == true or settings.screenShake == false))
end

local reducedMotionEquivalents = {
    rotation = { animated = "smooth camera tween", reduced = "instant camera snap with view label", cue = "view_degrees", preserves = "logical tile coordinates" },
    destruction = { animated = "debris burst and impact shake", reduced = "static destroyed marker with HP delta", cue = "destroyed_tile", preserves = "terrain state change" },
    knockback = { animated = "sliding unit and collision shake", reduced = "origin-to-landing arrow with collision text", cue = "forced_movement_path", preserves = "final unit tile" },
    explosion = { animated = "expanding blast and screen shake", reduced = "static blast footprint with damage chips", cue = "blast_footprint", preserves = "affected tiles" },
}

function Render.reducedMotionEquivalents()
    return copyValue(reducedMotionEquivalents)
end

function Render.motionPlan(appOrSettings, effect, details)
    local spec = reducedMotionEquivalents[effect]
    if not spec then
        return nil
    end
    details = details or {}
    local reduced = Render.reducedMotion(appOrSettings)
    return {
        effect = effect,
        mode = reduced and "reduced" or "animated",
        animation = reduced and "none" or spec.animated,
        equivalent = reduced and spec.reduced or nil,
        cue = spec.cue,
        preserves = spec.preserves,
        source = details.source,
        target = details.target,
        tiles = copyValue(details.tiles),
    }
end

function Render.accessibleColor(settings, color)
    settings = accessibilitySettings(settings)
    local r = color[1] or 1
    local g = color[2] or 1
    local b = color[3] or 1
    local a = color[4] or 1
    local mode = settings and settings.colorblindMode or "off"
    if mode == "deuteranopia" then
        r, g, b = r * 0.62 + g * 0.38, r * 0.7 + g * 0.3, b
    elseif mode == "protanopia" then
        r, g, b = r * 0.57 + g * 0.43, r * 0.56 + g * 0.44, b
    elseif mode == "tritanopia" then
        r, g, b = r, g * 0.68 + b * 0.32, g * 0.42 + b * 0.58
    end
    if settings and settings.highContrast then
        r = clamp((r - 0.5) * 1.35 + 0.5, 0, 1)
        g = clamp((g - 0.5) * 1.35 + 0.5, 0, 1)
        b = clamp((b - 0.5) * 1.35 + 0.5, 0, 1)
    end
    return { clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1), a }
end

function Render.tileAccessibleColor(settings, color)
    settings = accessibilitySettings(settings)
    local adjusted = Render.accessibleColor(settings, color)
    if settings and settings.highContrastTiles then
        adjusted[1] = clamp((adjusted[1] - 0.5) * 1.6 + 0.5, 0, 1)
        adjusted[2] = clamp((adjusted[2] - 0.5) * 1.6 + 0.5, 0, 1)
        adjusted[3] = clamp((adjusted[3] - 0.5) * 1.6 + 0.5, 0, 1)
    end
    return adjusted
end

local function fontForScale(scale)
    if not (love and love.graphics) then
        return nil
    end
    local size = math.floor(12 * Render.fontScale({ fontScale = scale }) + 0.5)
    state.fonts[size] = state.fonts[size] or love.graphics.newFont(size)
    return state.fonts[size]
end

function Render.applyFont(appOrSettings)
    if not (love and love.graphics) then
        return nil
    end
    local font = fontForScale(Render.fontScale(accessibilitySettings(appOrSettings)))
    love.graphics.setFont(font)
    return font
end

function Render.hitboxAt(app, x, y)
    for _, group in ipairs(uiHitboxGroups) do
        for index, hitbox in ipairs((app and app.ui and app.ui[group]) or {}) do
            if hitboxContains(hitbox, x, y) then
                return hitbox, group, index
            end
        end
    end
    return nil
end

function Render.markUiPulse(app, hitbox, kind)
    if not (app and hitbox) then
        return false
    end
    if Render.reducedMotion(app) then
        return false
    end
    local pulseKind = kind or "press"
    local duration = (pulseKind == "success" or pulseKind == "error") and 0.32 or 0.22
    app.uiPulse = { x = hitbox.x, y = hitbox.y, w = hitbox.w, h = hitbox.h, t = duration, duration = duration, kind = pulseKind }
    return true
end

function Render.markUiFeedback(app, kind)
    if not app or Render.reducedMotion(app) then
        return false
    end
    local pulse = app.uiPulse
    if pulse then
        local duration = (kind == "success" or kind == "error") and 0.32 or (pulse.duration or 0.22)
        pulse.kind = kind or pulse.kind or "press"
        pulse.duration = duration
        pulse.t = duration
        return true
    end
    local hot = app.uiHot
    local hitbox = hot and app.ui and app.ui[hot.group] and app.ui[hot.group][hot.index]
    if hitbox then
        return Render.markUiPulse(app, hitbox, kind)
    end
    local focus = app.keyboardFocus
    hitbox = focus and app.ui and app.ui[focus.group] and app.ui[focus.group][focus.index]
    if hitbox then
        return Render.markUiPulse(app, hitbox, kind)
    end
    return false
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
    default = { mood = "neutral", focus = "stage", beat = "hold", camera = "still", caption = i18n.t("Event"), intensity = 0.65, accent = { 0.7, 0.58, 0.35 } },
    idle = { mood = "watch", focus = "party", beat = "idle", camera = "still", caption = i18n.t("Combat"), intensity = 0.35, accent = { 0.42, 0.54, 0.36 } },
    intro = { mood = "threat", focus = "enemy", beat = "arrival", camera = "push", caption = i18n.t("Encounter"), duration = 0.92, intensity = 0.75, accent = { 0.72, 0.2, 0.12 } },
    boss_intro = { mood = "boss", focus = "boss", beat = "reveal", camera = "quake", caption = i18n.t("Boss Encounter"), duration = 1.18, intensity = 1.2, accent = { 0.86, 0.08, 0.08 } },
    ambush = { mood = "panic", focus = "enemy", beat = "snap", camera = "snap", caption = i18n.t("Ambush"), duration = 1.0, intensity = 1.05, accent = { 0.9, 0.12, 0.08 } },
    strike = { mood = "action", focus = "actor", beat = "strike", camera = "hit", caption = i18n.t("Skill"), duration = 0.72, intensity = 0.9, accent = { 0.96, 0.72, 0.32 } },
    boss_strike = { mood = "boss", focus = "boss", beat = "smite", camera = "quake", caption = i18n.t("Boss Skill"), duration = 0.95, intensity = 1.25, accent = { 0.9, 0.08, 0.06 } },
    victory = { mood = "resolve", focus = "party", beat = "triumph", camera = "lift", caption = i18n.t("Victory"), duration = 0.86, intensity = 0.8, accent = { 0.86, 0.68, 0.24 } },
    boss_victory = { mood = "seal", focus = "party", beat = "triumph", camera = "lift", caption = i18n.t("Boss Felled"), duration = 1.2, intensity = 1.05, accent = { 0.92, 0.74, 0.18 } },
    campaign_victory = { mood = "seal", focus = "party", beat = "seal", camera = "lift", caption = i18n.t("Campaign Sealed"), duration = 1.25, intensity = 1.1, accent = { 0.72, 0.82, 0.42 } },
    merchant_unlock = { mood = "ledger", focus = "actor", beat = "arrival", camera = "push", caption = i18n.t("Merchant Unlocked"), duration = 1.05, intensity = 0.9, accent = { 0.66, 0.58, 0.34 } },
    defeat = { mood = "doom", focus = "enemy", beat = "collapse", camera = "sink", caption = i18n.t("Defeat"), duration = 0.95, intensity = 1.0, accent = { 0.78, 0.08, 0.06 } },
    boss_defeat = { mood = "doom", focus = "boss", beat = "collapse", camera = "sink", caption = i18n.t("Annihilation"), duration = 1.2, intensity = 1.22, accent = { 0.82, 0.04, 0.04 } },
    retreat = { mood = "flight", focus = "party", beat = "exit", camera = "pull", caption = i18n.t("Retreat"), duration = 0.78, intensity = 0.7, accent = { 0.46, 0.58, 0.48 } },
    blocked = { mood = "panic", focus = "enemy", beat = "block", camera = "hit", caption = i18n.t("Blocked"), duration = 0.72, intensity = 0.9, accent = { 0.86, 0.08, 0.06 } },
    death_door = { mood = "threshold", focus = "actor", beat = "threshold", camera = "sink", caption = i18n.t("Death's Door"), duration = 0.85, intensity = 1.05, accent = { 0.72, 0.08, 0.08 } },
    death_save = { mood = "resolve", focus = "actor", beat = "revive", camera = "lift", caption = i18n.t("Deathblow Resisted"), duration = 0.85, intensity = 0.9, accent = { 0.86, 0.78, 0.38 } },
    hero_death = { mood = "doom", focus = "actor", beat = "fall", camera = "sink", caption = i18n.t("Hero Lost"), duration = 1.1, intensity = 1.15, accent = { 0.8, 0.06, 0.06 } },
    resolve_virtue = { mood = "virtue", focus = "actor", beat = "resolve", camera = "lift", caption = i18n.t("Virtue"), duration = 0.95, intensity = 0.95, accent = { 0.62, 0.82, 0.34 } },
    resolve_affliction = { mood = "affliction", focus = "actor", beat = "fracture", camera = "snap", caption = i18n.t("Affliction"), duration = 0.95, intensity = 1.05, accent = { 0.72, 0.12, 0.52 } },
    stress_break = { mood = "affliction", focus = "actor", beat = "break", camera = "sink", caption = i18n.t("Stress Break"), duration = 0.95, intensity = 1.0, accent = { 0.7, 0.12, 0.38 } },
    affliction_act = { mood = "affliction", focus = "actor", beat = "lash", camera = "snap", caption = i18n.t("Afflicted Action"), duration = 0.95, intensity = 0.95, accent = { 0.66, 0.1, 0.44 } },
    falter = { mood = "dazed", focus = "actor", beat = "stagger", camera = "hit", caption = i18n.t("Falter"), duration = 0.62, intensity = 0.65, accent = { 0.64, 0.62, 0.52 } },
    hero_hold = { mood = "guard", focus = "actor", beat = "hold", camera = "still", caption = i18n.t("Hold"), duration = 0.62, intensity = 0.55, accent = { 0.62, 0.62, 0.5 } },
    danger = { mood = "doom", focus = "enemy", beat = "omen", camera = "sink", caption = i18n.t("Danger"), duration = 0.85, intensity = 0.95, accent = { 0.82, 0.08, 0.06 } },
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
    app.ui.squadLoadoutButtons = app.ui.squadLoadoutButtons or {}
    app.ui.tacticalIntentButtons = app.ui.tacticalIntentButtons or {}
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
    clearList(app.ui.squadLoadoutButtons)
    clearList(app.ui.tacticalIntentButtons)
    clearList(app.ui.titleButtons)
    clearList(app.ui.settingsButtons)
end

local function eventCaption(event, fallback)
    local value = event and (event.skill or event.actor)
    return value and tostring(value) or fallback
end

local function eventImpactTotal(event)
    local total = 0
    for _, impact in ipairs((event and event.impacts) or {}) do
        total = total + math.max(0, tonumber(impact.amount) or 0)
    end
    return total
end

local function eventHasCrit(event)
    if event and event.crit == true then
        return true
    end
    for _, impact in ipairs((event and event.impacts) or {}) do
        if impact.crit == true then
            return true
        end
    end
    return false
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
        return scene("intro", text, { side = "enemy", duration = 0.9, encounter = event.encounter, enemies = event.enemies, caption = encounterCaption(event, i18n.t("Encounter")) })
    end
    if eventKind == "merchant_unlock" then
        return scene("merchant_unlock", text, { side = "ally", actor = event.actor, caption = i18n.t("Merchant Unlocked") })
    end
    if eventKind == "boss_start" then
        return scene("boss_intro", text, { side = "enemy", duration = 1.15, encounter = event.encounter, enemies = event.enemies, boss = true, caption = encounterCaption(event, i18n.t("Boss Encounter")) })
    end
    if eventKind == "ambush_start" then
        return scene("ambush", text, { side = "enemy", duration = 1.0, encounter = event.encounter, enemies = event.enemies, caption = encounterCaption(event, i18n.t("Ambush")) })
    end
    if eventKind == "hero_skill" then
        return scene("strike", text, { side = "ally", duration = 0.72, actor = event.actor, skill = event.skill, caption = eventCaption(event, i18n.t("Skill")), damage = eventImpactTotal(event), crit = eventHasCrit(event) })
    end
    if eventKind == "enemy_skill" or eventKind == "boss_skill" then
        return scene(eventKind == "boss_skill" and "boss_strike" or "strike", text, { side = "enemy", duration = eventKind == "boss_skill" and 0.95 or 0.72, actor = event.actor, skill = event.skill, boss = event.boss, caption = eventCaption(event, eventKind == "boss_skill" and i18n.t("Boss Skill") or i18n.t("Enemy Skill")), damage = eventImpactTotal(event), crit = eventHasCrit(event) })
    end
    if eventKind == "combat_win" or eventKind == "boss_win" then
        return scene(eventKind == "boss_win" and "boss_victory" or "victory", text, { side = "ally", duration = eventKind == "boss_win" and 1.2 or 0.86, encounter = event.encounter, enemies = event.enemies, boss = event.boss, caption = eventKind == "boss_win" and i18n.t("Boss Felled") or i18n.t("Victory") })
    end
    if eventKind == "combat_loss" or eventKind == "boss_loss" then
        return scene(eventKind == "boss_loss" and "boss_defeat" or "defeat", text, { side = "enemy", duration = eventKind == "boss_loss" and 1.2 or 0.95, encounter = event.encounter, enemies = event.enemies, boss = event.boss, caption = eventKind == "boss_loss" and i18n.t("Annihilation") or i18n.t("Defeat") })
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
    return scene("idle", active and (active.name .. " " .. i18n.t("acts")) or i18n.t("enemy turn"), { side = "ally", duration = 1 })
end

function Render.advanceCutscene(app, dt)
    if not (app and app.cutscene) then
        return
    end
    if Render.reducedMotion(app) then
        app.cutscene = nil
        app.cutsceneQueue = {}
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

function Render.screenToWorldPoint(view, x, y)
    local sx = x - view.centerX
    local sy = y - view.centerY
    local rx = (sx / view.halfW + sy / view.halfH) / 2
    local ry = (sy / view.halfH - sx / view.halfW) / 2
    local dx, dy = Render.unrotateDelta(rx, ry, view.rotation)
    return view.originX + dx, view.originY + dy
end

function Render.screenToWorld(view, x, y)
    local worldX, worldY = Render.screenToWorldPoint(view, x, y)
    return math.floor(worldX + 0.5), math.floor(worldY + 0.5)
end

local function normalize3(x, y, z)
    local length = math.sqrt(x * x + y * y + z * z)
    if length <= 0 then
        return 0, 0, 0
    end
    return x / length, y / length, z / length
end

local function cross3(ax, ay, az, bx, by, bz)
    return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

function Render.tacticalScreenToWorldPoint(view, screenX, screenY)
    local camera = view and view.tacticalCamera
    if not camera then
        return nil
    end
    local width = camera.screenWidth or (love and love.graphics and love.graphics.getWidth()) or 0
    local height = camera.screenHeight or (love and love.graphics and love.graphics.getHeight()) or 0
    if width <= 0 or height <= 0 then
        return nil
    end
    local eyeX, eyeY, eyeZ = camera.eyeX, camera.eyeY, camera.eyeZ
    local targetX, targetY, targetZ = camera.targetX, camera.targetY, camera.targetZ
    local backX, backY, backZ = normalize3(eyeX - targetX, eyeY - targetY, eyeZ - targetZ)
    local rightX, rightY, rightZ = normalize3(cross3(0, 0, 1, backX, backY, backZ))
    local upX, upY, upZ = cross3(backX, backY, backZ, rightX, rightY, rightZ)
    local top = camera.orthoSize or 1
    local right = top * (width / height)
    local cameraX = ((screenX / width) * 2 - 1) * right
    local cameraY = (1 - (screenY / height) * 2) * top
    local rayX = eyeX + rightX * cameraX + upX * cameraY
    local rayY = eyeY + rightY * cameraX + upY * cameraY
    local rayZ = eyeZ + rightZ * cameraX + upZ * cameraY
    local dirX, dirY, dirZ = -backX, -backY, -backZ
    if math.abs(dirZ) < 0.0001 then
        return nil
    end
    local t = ((camera.boardZ or 0) - rayZ) / dirZ
    return rayX + dirX * t, rayY + dirY * t
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function Render.tacticalZoom(app)
    return clamp(tonumber(app and app.tacticalZoom) or 1, minTacticalZoom, maxTacticalZoom)
end

function Render.adjustTacticalZoom(app, steps)
    if not app then
        return 1
    end
    local count = math.abs(math.floor(tonumber(steps) or 0))
    local zoom = Render.tacticalZoom(app)
    local factor = steps and steps < 0 and (1 / 1.12) or 1.12
    for _ = 1, count do
        zoom = zoom * factor
    end
    app.tacticalZoom = clamp(zoom, minTacticalZoom, maxTacticalZoom)
    return app.tacticalZoom
end

function Render.tileHeight(tileDef)
    return math.max(0, tonumber(tileDef and tileDef.height) or 0)
end

function Render.isOccluderTile(tileDef)
    return tileDef and (tileDef.occluder == true or Render.tileHeight(tileDef) > 0)
end

function Render.occlusionOffsets(rotation)
    rotation = (rotation or 0) % 4
    if rotation == 1 then
        return { { -1, -1 }, { -1, 0 }, { 0, -1 } }
    end
    if rotation == 2 then
        return { { -1, 1 }, { -1, 0 }, { 0, 1 } }
    end
    if rotation == 3 then
        return { { 1, 1 }, { 1, 0 }, { 0, 1 } }
    end
    return { { 1, -1 }, { 1, 0 }, { 0, -1 } }
end

local function rotationAllowed(value, allowed)
    if allowed == nil then
        return true
    end
    value = (value or 0) % 4
    if type(allowed) == "number" then
        return value == (allowed % 4)
    end
    for _, entry in ipairs(allowed or {}) do
        if value == (entry % 4) then
            return true
        end
    end
    return false
end

local tacticalOverlayOrder = { "movement", "los", "cover", "flank", "intent", "overwatch", "aiDebug", "hazard", "blocker", "objective", "cursor" }
local tacticalOverlayPalette = TacticsUICatalog.accessiblePalette().roles
local tacticalOverlayColors = {
    movement = { 0.34, 0.72, 1.0, 0.86 },
    los = { 0.86, 0.78, 0.28, 0.46 },
    cover = tacticalOverlayPalette.cover.color,
    flank = { 0.94, 0.52, 0.18, 0.55 },
    intent = tacticalOverlayPalette.intent.color,
    overwatch = { 0.18, 0.9, 0.88, 0.78 },
    aiDebug = { 0.58, 0.92, 0.42, 0.84 },
    hazard = tacticalOverlayPalette.hazard.color,
    blocker = { 0.06, 0.065, 0.075, 0.92 },
    objective = { 1.0, 0.78, 0.18, 0.94 },
    cursor = { 1.0, 0.92, 0.22, 0.98 },
    hover = { 1.0, 1.0, 1.0, 0.86 },
    selected = { 0.34, 1.0, 0.52, 0.94 },
}

local tacticalOverlayStyles = {
    movement = { icon = "move", pattern = "dot" },
    los = { icon = "eye", pattern = "ray" },
    cover = { icon = tacticalOverlayPalette.cover.icon, pattern = tacticalOverlayPalette.cover.pattern },
    flank = { icon = "angle", pattern = "chevron" },
    intent = { icon = tacticalOverlayPalette.intent.icon, pattern = tacticalOverlayPalette.intent.pattern },
    overwatch = { icon = "cone", pattern = "ray" },
    aiDebug = { icon = "ai", pattern = "path" },
    hazard = { icon = tacticalOverlayPalette.hazard.icon, pattern = tacticalOverlayPalette.hazard.pattern },
    blocker = { icon = "x", pattern = "solid" },
    objective = { icon = "!", pattern = "solid" },
    cursor = { icon = "+", pattern = "outline" },
    hover = { icon = "hover", pattern = "outline" },
    selected = { icon = "unit", pattern = "ring" },
}

local tacticalCoverEdgePalettes = {
    colorblind = {
        color = tacticalOverlayPalette.cover.color,
        icon = tacticalOverlayPalette.cover.icon,
        pattern = tacticalOverlayPalette.cover.pattern,
    },
    standard = {
        color = { 0.42, 0.58, 0.82, 0.48 },
        icon = "shield",
        pattern = "edge",
    },
}

function Render.tacticalAccessibility(appOrSettings)
    local settings = accessibilitySettings(appOrSettings) or {}
    local coverPalette = settings.coverEdgePalette == "standard" and "standard" or "colorblind"
    return {
        highContrastTiles = settings.highContrastTiles == true,
        intentIconScale = clamp(settings.intentIconScale or 1, 0.75, 1.75),
        intentText = settings.intentText == true,
        coverEdgePalette = coverPalette,
        coverEdge = copyValue(tacticalCoverEdgePalettes[coverPalette]),
    }
end

local function parseTileKey(key)
    local x, y = tostring(key):match("^(-?%d+):(-?%d+)$")
    return tonumber(x), tonumber(y)
end

local function tileKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function sortedMapKeys(values)
    local keys = {}
    for key in pairs(values or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function tileHasCover(tile)
    for _, direction in ipairs({ "north", "east", "south", "west" }) do
        if tile and tile.coverEdges and tile.coverEdges[direction] and tile.coverEdges[direction] ~= "none" then
            return true
        end
    end
    return false
end

local function appendOverlayTile(entries, counts, seen, kind, x, y, options)
    if x == nil or y == nil then
        return
    end
    local key = kind .. ":" .. tostring(x) .. ":" .. tostring(y)
    if seen[key] then
        return
    end
    seen[key] = true
    counts[kind] = (counts[kind] or 0) + 1
    entries[#entries + 1] = {
        kind = kind,
        x = x,
        y = y,
        label = options and options.label or kind,
        color = (options and options.color) or tacticalOverlayColors[kind],
        icon = (options and options.icon) or (tacticalOverlayStyles[kind] and tacticalOverlayStyles[kind].icon),
        pattern = (options and options.pattern) or (tacticalOverlayStyles[kind] and tacticalOverlayStyles[kind].pattern),
        iconScale = options and options.iconScale,
        text = options and options.text,
    }
end

local function applyTacticalAccessibility(entries, settings)
    local access = Render.tacticalAccessibility(settings)
    for _, entry in ipairs(entries) do
        if entry.kind == "intent" then
            entry.iconScale = access.intentIconScale
            if access.intentText then
                entry.text = entry.label or "intent"
            end
        elseif entry.kind == "cover" then
            entry.color = access.coverEdge.color
            entry.icon = access.coverEdge.icon
            entry.pattern = access.coverEdge.pattern
            entry.palette = access.coverEdgePalette
        end
    end
end

local function appendOverlayList(entries, counts, seen, kind, values)
    if values == true then
        return
    end
    for key, value in pairs(values or {}) do
        local x = type(value) == "table" and value.x or nil
        local y = type(value) == "table" and value.y or nil
        if type(key) == "string" and (x == nil or y == nil) then
            x, y = parseTileKey(key)
        end
        if type(value) == "table" then
            appendOverlayTile(entries, counts, seen, kind, x, y, value)
        elseif value == true then
            appendOverlayTile(entries, counts, seen, kind, x, y)
        end
    end
end

function Render.tacticalOverlayEntries(tactics, overlays, settings)
    local entries = {}
    local counts = {}
    local seen = {}
    overlays = overlays or {}
    if tactics and tactics.board and overlays.cover ~= false then
        for key, tile in pairs(tactics.board.tiles or {}) do
            if tileHasCover(tile) then
                local x, y = parseTileKey(key)
                appendOverlayTile(entries, counts, seen, "cover", x, y, { label = "cover" })
            end
        end
    end
    if tactics and tactics.board and overlays.hazard ~= false then
        for key, tile in pairs(tactics.board.tiles or {}) do
            if tile and tile.hazard and next(tile.hazard) ~= nil then
                local x, y = parseTileKey(key)
                appendOverlayTile(entries, counts, seen, "hazard", x, y, { label = tile.hazard.kind or "hazard" })
            end
        end
    end
    if tactics and tactics.board and overlays.blocker ~= false then
        for key, tile in pairs(tactics.board.tiles or {}) do
            if tile and tile.blocker then
                local x, y = parseTileKey(key)
                appendOverlayTile(entries, counts, seen, "blocker", x, y, { label = "blocker" })
            end
        end
    end
    if tactics and tactics.objectives and overlays.objective ~= false then
        for _, id in ipairs(tactics.objectiveOrder or {}) do
            local objective = tactics.objectives[id]
            if objective then
                appendOverlayTile(entries, counts, seen, "objective", objective.x, objective.y, { label = objective.id })
            end
        end
    end
    appendOverlayList(entries, counts, seen, "movement", overlays.movement or overlays.movementRange)
    appendOverlayList(entries, counts, seen, "los", overlays.los or overlays.lineOfSight)
    appendOverlayList(entries, counts, seen, "flank", overlays.flanks or overlays.flank)
    appendOverlayList(entries, counts, seen, "intent", overlays.intent or overlays.intents)
    appendOverlayList(entries, counts, seen, "overwatch", overlays.overwatch or overlays.overwatchPreview)
    appendOverlayList(entries, counts, seen, "aiDebug", overlays.aiDebug)
    appendOverlayList(entries, counts, seen, "hazard", overlays.hazards)
    appendOverlayList(entries, counts, seen, "cursor", overlays.cursor)
    applyTacticalAccessibility(entries, settings)
    table.sort(entries, function(a, b)
        if a.y == b.y then
            if a.x == b.x then
                return a.kind < b.kind
            end
            return a.x < b.x
        end
        return a.y < b.y
    end)
    for _, kind in ipairs(tacticalOverlayOrder) do
        counts[kind] = counts[kind] or 0
    end
    return entries, counts
end

function Render.tacticalOverlaySummary(tactics, overlays)
    local entries, counts = Render.tacticalOverlayEntries(tactics, overlays)
    counts.total = #entries
    return counts
end

function Render.tacticalOverlayAccessibilityAudit(tactics, overlays)
    local result = {}
    for rotation = 0, 3 do
        local rotated = {}
        for key, value in pairs(overlays or {}) do
            rotated[key] = value
        end
        rotated.rotation = rotation
        local entries, counts = Render.tacticalOverlayEntries(tactics, rotated)
        result[#result + 1] = {
            rotation = rotation,
            entries = entries,
            counts = counts,
        }
    end
    return result
end

local function rotationAuditView(view, rotation)
    view = view or {}
    return {
        centerX = view.centerX or 0,
        centerY = view.centerY or 0,
        halfW = view.halfW or 1,
        halfH = view.halfH or 1,
        originX = view.originX or 0,
        originY = view.originY or 0,
        rotation = rotation,
    }
end

function Render.tacticalOverlayRotationAudit(tactics, overlays, view)
    local baseEntries, counts = Render.tacticalOverlayEntries(tactics, overlays)
    local result = {}
    for rotation = 0, 3 do
        local rotatedView = rotationAuditView(view, rotation)
        local entries = {}
        for _, entry in ipairs(baseEntries) do
            local screenX, screenY = Render.projectIso(rotatedView, entry.x, entry.y)
            local worldX, worldY = Render.screenToWorld(rotatedView, screenX, screenY)
            entries[#entries + 1] = {
                key = entry.kind .. ":" .. tostring(entry.x) .. ":" .. tostring(entry.y),
                kind = entry.kind,
                x = entry.x,
                y = entry.y,
                screenX = screenX,
                screenY = screenY,
                icon = entry.icon,
                pattern = entry.pattern,
                label = entry.label,
                labelOrientation = "upright",
                logicalStable = worldX == entry.x and worldY == entry.y,
                readable = entry.icon ~= nil and entry.pattern ~= nil,
                occlusionOffsets = Render.occlusionOffsets(rotation),
            }
        end
        result[#result + 1] = {
            rotation = rotation,
            entries = entries,
            counts = counts,
        }
    end
    return result
end

function Render.rotationCompass(rotation)
    local r = (rotation or 0) % 4
    local labels = {
        [0] = { top = "N", right = "E", bottom = "S", left = "W" },
        [1] = { top = "W", right = "N", bottom = "E", left = "S" },
        [2] = { top = "S", right = "W", bottom = "N", left = "E" },
        [3] = { top = "E", right = "S", bottom = "W", left = "N" },
    }
    local compass = copyValue(labels[r])
    compass.rotation = r
    compass.degrees = r * 90
    return compass
end

local function addBearingTile(list, seen, kind, x, y)
    if not (x and y) then
        return
    end
    local key = tostring(x) .. ":" .. tostring(y)
    if seen[key] then
        return
    end
    seen[key] = true
    list[#list + 1] = { kind = kind, x = x, y = y, tileId = key }
end

function Render.tacticalBearingTiles(app)
    local runtime = app and app.tactics
    local tactics = runtime and runtime.state
    local result, seen = {}, {}
    if not tactics then
        return result
    end
    addBearingTile(result, seen, "cursor", runtime.cursor and runtime.cursor.x, runtime.cursor and runtime.cursor.y)
    local selected = runtime.selectedUnitId and tactics:unit(runtime.selectedUnitId)
    addBearingTile(result, seen, "selected", selected and selected.x, selected and selected.y)
    for _, objectiveId in ipairs(sortedMapKeys(tactics.objectives or {})) do
        local objective = tactics:objective(objectiveId)
        addBearingTile(result, seen, "objective", objective.x, objective.y)
    end
    for _, unitId in ipairs(sortedMapKeys(tactics.intents or {})) do
        local preview = tactics:intentPreview(unitId, { side = "player" })
        for _, tile in ipairs((preview and preview.targetTiles) or {}) do
            addBearingTile(result, seen, "intent", tile.x, tile.y)
        end
    end
    return result
end

function Render.tacticalGhostArrowEntries(app)
    return {}
end

local function objectRevealRotations(object, tileDef)
    if object and object.revealRotations then
        return object.revealRotations
    end
    if object and object.revealRotation ~= nil then
        return object.revealRotation
    end
    if tileDef and tileDef.revealRotations then
        return tileDef.revealRotations
    end
    return tileDef and tileDef.revealRotation
end

function Render.occluderAt(sim, x, y, z)
    if not (sim and sim.world) then
        return false
    end
    local tile = sim.world:peekTile(x, y, z or 0)
    local tileDef = tile and Defs.tile(tile.id)
    return Render.isOccluderTile(tileDef), tileDef, tile
end

function Render.concealingOccluder(sim, app, object)
    if not (object and object.x and object.y) then
        return nil
    end
    local rotation = (app and app.viewRotation) or 0
    for _, offset in ipairs(Render.occlusionOffsets(rotation)) do
        local ox = object.x + offset[1]
        local oy = object.y + offset[2]
        local occludes, tileDef, tile = Render.occluderAt(sim, ox, oy, object.z or 0)
        if occludes then
            return { x = ox, y = oy, z = object.z or 0, tile = tile and tile.id, height = Render.tileHeight(tileDef) }
        end
    end
    return nil
end

function Render.objectRevealState(sim, app, object)
    local tileDef = object and object.tile and Defs.tile(object.tile) or nil
    local rotation = (app and app.viewRotation) or 0
    local allowed = objectRevealRotations(object, tileDef)
    local puzzleHidden = not rotationAllowed(rotation, allowed)
    local occluder = Render.concealingOccluder(sim, app, object)
    local architectureCandidate = (object and object.hiddenBehind == true) or (tileDef and tileDef.hiddenBehind == true)
    local architectureHidden = architectureCandidate and occluder ~= nil or false
    local hidden = puzzleHidden or architectureHidden
    return {
        visible = not hidden,
        hidden = hidden,
        alpha = hidden and 0.18 or 1,
        puzzleHidden = puzzleHidden,
        architectureHidden = architectureHidden,
        occluder = occluder,
        rotation = rotation % 4,
        rotationPuzzle = tileDef and tileDef.rotationPuzzle == true,
    }
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

local function loadSpriteAtlas()
    local meta = defaultAtlasMeta
    if love.filesystem.getInfo("assets/sprites/oga_700_sprites.lua", "file") then
        local chunk = love.filesystem.load("assets/sprites/oga_700_sprites.lua")
        local ok, loaded = pcall(chunk)
        if ok and type(loaded) == "table" then
            meta = loaded
        end
    end
    return loadImage(meta.image or defaultAtlasMeta.image), meta
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
    state.fonts = {}
    state.quads = {}
    state.modelCache = {}
    state.billboardCache = {}
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
    state.assets.spriteAtlas, state.assets.spriteAtlasMeta = loadSpriteAtlas()
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

function Render.pushTilePolygon(vertices, topology, x, y, z, u, inset)
    local points = Render.Topology.vertices(topology, x, y, inset or 0.03)
    if #points < 3 then
        return
    end
    local first = tileVertex(points[1][1], points[1][2], z, u)
    for index = 2, #points - 1 do
        vertices[#vertices + 1] = first
        vertices[#vertices + 1] = tileVertex(points[index][1], points[index][2], z, u)
        vertices[#vertices + 1] = tileVertex(points[index + 1][1], points[index + 1][2], z, u)
    end
end

local function pushFace(vertices, a, b, c, d, u)
    vertices[#vertices + 1] = tileVertex(a[1], a[2], a[3], u)
    vertices[#vertices + 1] = tileVertex(b[1], b[2], b[3], u)
    vertices[#vertices + 1] = tileVertex(c[1], c[2], c[3], u)
    vertices[#vertices + 1] = tileVertex(a[1], a[2], a[3], u)
    vertices[#vertices + 1] = tileVertex(c[1], c[2], c[3], u)
    vertices[#vertices + 1] = tileVertex(d[1], d[2], d[3], u)
end

local function pushBox(vertices, x, y, z, height, u)
    local gap = 0.035
    local l = x + gap
    local r = x + 1 - gap
    local t = y + gap
    local b = y + 1 - gap
    local floor = z or 0
    local top = floor + height
    pushFace(vertices, { l, t, top }, { r, t, top }, { r, b, top }, { l, b, top }, u)
    pushFace(vertices, { l, t, floor }, { l, t, top }, { r, t, top }, { r, t, floor }, u)
    pushFace(vertices, { r, t, floor }, { r, t, top }, { r, b, top }, { r, b, floor }, u)
    pushFace(vertices, { r, b, floor }, { r, b, top }, { l, b, top }, { l, b, floor }, u)
    pushFace(vertices, { l, b, floor }, { l, b, top }, { l, t, top }, { l, t, floor }, u)
end

function Render.pushTacticalGridLine(vertices, x1, y1, x2, y2, z, halfWidth, u)
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0 then
        return
    end
    local px = -dy / length * halfWidth
    local py = dx / length * halfWidth
    pushFace(vertices,
        { x1 + px, y1 + py, z },
        { x2 + px, y2 + py, z },
        { x2 - px, y2 - py, z },
        { x1 - px, y1 - py, z },
        u)
end

function Render.pushTacticalGridRing(vertices, x, y, z, u, topology)
    local inset = 0.035
    local width = 0.012
    topology = Render.Topology.normalize(topology)
    if topology ~= "square" then
        local points = Render.Topology.vertices(topology, x, y, inset)
        for index = 1, #points do
            local nextPoint = points[index % #points + 1]
            Render.pushTacticalGridLine(vertices, points[index][1], points[index][2], nextPoint[1], nextPoint[2], z, width, u)
        end
        return
    end
    local left = x + inset
    local right = x + 1 - inset
    local top = y + inset
    local bottom = y + 1 - inset
    Render.pushTacticalGridLine(vertices, left, top, right, top, z, width, u)
    Render.pushTacticalGridLine(vertices, right, top, right, bottom, z, width, u)
    Render.pushTacticalGridLine(vertices, right, bottom, left, bottom, z, width, u)
    Render.pushTacticalGridLine(vertices, left, bottom, left, top, z, width, u)
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

local function litTileColor(rgb, light, settings)
    local r = clamp((rgb[1] / 255) * light * 1.08, 0, 1)
    local g = clamp((rgb[2] / 255) * light * (0.9 + light * 0.1), 0, 1)
    local b = clamp((rgb[3] / 255) * light * (0.78 + light * 0.22), 0, 1)
    local color = Render.tileAccessibleColor(settings, { r, g, b, 1 })
    return color[1], color[2], color[3], color[4]
end

Render.tacticalHeightScale = 0.28

function Render.tileHasTag(tile, tag)
    for _, value in ipairs((tile and tile.tags) or {}) do
        if value == tag then
            return true
        end
    end
    return false
end

function Render.tacticalTileColor(tileOrId)
    local tile = type(tileOrId) == "table" and tileOrId or nil
    local tileId = tile and tile.id or tileOrId
    local kind = tile and tile.kind
    if Render.tileHasTag(tile, "megastructure") then
        if kind == "archive_shaft" then
            return { 38, 44, 50 }
        elseif kind == "hanging_slab" then
            return { 62, 65, 68 }
        elseif kind == "megastructure_shell" then
            return { 48, 52, 58 }
        end
        return { 56, 61, 66 }
    end
    if tile and tile.terrainType == "archive_chasm" then
        return { 18, 22, 27 }
    end
    if tile and (tile.terrainType == "sealed_archive_mass" or Render.tileHasTag(tile, "sealed_mass")) then
        return { 54, 58, 62 }
    end
    if tile and tile.terrainType == "sunken_water" then
        return { 52, 92, 96 }
    end
    if tile and tile.terrainType == "root_tangle" then
        return { 72, 82, 58 }
    end
    if tile and tile.terrainType == "root_screen" then
        return { 42, 70, 48 }
    end
    if tile and tile.terrainType == "bell_stone" then
        return { 118, 104, 74 }
    end
    if tile and tile.terrainType == "ash_glass" then
        return { 126, 122, 116 }
    end
    if tile and tile.terrainType == "heat_vent" then
        return { 138, 68, 48 }
    end
    if tile and tile.terrainType == "temple_stone" then
        return { 112, 106, 92 }
    end
    if tile and tile.terrainType == "ritual_pillar" then
        return { 74, 68, 64 }
    end
    if tile and tile.height and tile.height >= 3 then
        return { 118, 128, 112 }
    end
    if tile and tile.height and tile.height > 0 then
        return { 104, 116, 100 }
    end
    if tileId == "sealed_name" then
        return { 184, 132, 48 }
    end
    if tileId == "false_index" then
        return { 46, 104, 112 }
    end
    if tileId == "archive_monolith" then
        return { 86, 88, 92 }
    end
    return { 130, 142, 114 }
end

function Render.tacticalRenderHeight(tile)
    local height = math.max(0, tonumber(tile and tile.height) or 0)
    if Render.tileHasTag(tile, "megastructure") then
        return math.max(1.35, height * 0.34)
    end
    if tile and tile.blocker and tile.destructibleHp then
        return math.max(0.85, height * Render.tacticalHeightScale)
    end
    return height * Render.tacticalHeightScale
end

function Render.settingsRenderKey(settings)
    settings = accessibilitySettings(settings)
    if not settings then
        return "default"
    end
    return table.concat({
        tostring(settings.colorblindMode or "off"),
        tostring(settings.highContrast == true),
        tostring(settings.highContrastTiles == true),
    }, ":")
end

function Render.cachedModel(slot, key, build)
    state.modelCache = state.modelCache or {}
    local cached = state.modelCache[slot]
    if cached and cached.key == key then
        return cached.model, cached.count
    end
    local model, count = build()
    state.modelCache[slot] = { key = key, model = model, count = count or 0 }
    return model, count or 0
end

local function tacticalBoardBounds(sim, app)
    local source = (app and app.tactics) or (sim and sim.tactics)
    local tactics = source and (source.state or source)
    if not (tactics and tactics.board) then
        return nil
    end
    local originX = source.originX or 0
    local originY = source.originY or 0
    return originX + 1, originX + tactics.board.width, originY + 1, originY + tactics.board.height
end

function Render.tacticalTopology(sim, app)
    local source = (app and app.tactics) or (sim and sim.tactics)
    local tactics = source and (source.state or source)
    return Render.Topology.normalize(tactics and tactics.board and tactics.board.topology)
end

function Render.worldTileCacheKey(sim, profile, settings, app, minX, maxX, minY, maxY)
    local z = sim.player.z or 0
    local tactical = app and app.tacticalMode
    local parts = {
        "tiles",
        tactical and "tactical" or "world",
        tostring(minX),
        tostring(maxX),
        tostring(minY),
        tostring(maxY),
        tostring(z),
        Render.settingsRenderKey(settings),
    }
    if tactical then
        local runtime = app and app.tactics
        local tactics = runtime and runtime.state
        parts[#parts + 1] = tostring(runtime and runtime.worldRevision or 0)
        parts[#parts + 1] = tostring(tactics and tactics.revision and tactics:revision("terrain") or 0)
        parts[#parts + 1] = tostring(tactics and tactics.revision and tactics:revision("units") or 0)
        parts[#parts + 1] = tostring(tactics and tactics.board and tactics.board.topology or "square")
        return table.concat(parts, "|")
    end
    if not tactical then
        parts[#parts + 1] = tostring(sim.player.x)
        parts[#parts + 1] = tostring(sim.player.y)
        parts[#parts + 1] = string.format("%.3f", profile.ambient or 0)
        parts[#parts + 1] = string.format("%.3f", profile.radius or 0)
    end
    for y = minY, maxY do
        for x = minX, maxX do
            local tile = sim.world:peekTile(x, y, z) or {}
            parts[#parts + 1] = tostring(tile.id or "")
            parts[#parts + 1] = tostring(tile.kind or "")
            parts[#parts + 1] = tostring(tile.terrainType or "")
            parts[#parts + 1] = tostring(tile.height or 0)
            parts[#parts + 1] = tostring(tile.blocker == true)
            parts[#parts + 1] = tostring(tile.destroyed == true)
            parts[#parts + 1] = tostring(tile.material or "")
            parts[#parts + 1] = table.concat(tile.tags or {}, ",")
        end
    end
    return table.concat(parts, "|")
end

local function buildWorldTileModel(sim, profile, settings, app, minX, maxX, minY, maxY)
    local vertices = {}
    local z = sim.player.z or 0
    local topology = Render.tacticalTopology(sim, app)
    if not minX then
        minX, maxX, minY, maxY = tacticalBoardBounds(sim, app)
    end
    if not minX then
        minX = sim.player.x - visibleRadius
        maxX = sim.player.x + visibleRadius
        minY = sim.player.y - visibleRadius
        maxY = sim.player.y + visibleRadius
    end
    local width = maxX - minX + 1
    local height = maxY - minY + 1
    local data = love.image.newImageData(width * height, 1)
    local index = 0
    for y = minY, maxY do
        for x = minX, maxX do
            index = index + 1
            local tile = sim.world:peekTile(x, y, z)
            local atlasEntry = app and app.tacticalMode and Render.TileAtlas.entryFor(tile) or nil
            local rgb = atlasEntry and atlasEntry.color or (app and app.tacticalMode and Render.tacticalTileColor(tile) or (Defs.tile(tile.id).color or { 255, 255, 255 }))
            local light = app and app.tacticalMode and 0.98 or lightAt(sim, x, y, profile)
            data:setPixel(index - 1, 0, litTileColor(rgb, light, settings))
            local u = (index - 0.5) / (width * height)
            local tileHeight = app and app.tacticalMode and Render.tacticalRenderHeight(tile) or 0
            if tileHeight > 0 then
                pushBox(vertices, x, y, z, tileHeight, u)
            elseif app and app.tacticalMode then
                Render.pushTilePolygon(vertices, topology, x, y, z, u)
            else
                pushTileQuad(vertices, x, y, z, u)
            end
        end
    end
    local model = state.g3d.newModel(vertices, newImageFromData(data))
    model:makeNormals()
    return model
end

function Render.tacticalGridColor(tileOrId)
    local rgb = Render.tacticalTileColor(tileOrId)
    local lum = ((rgb[1] or 0) * 0.2126 + (rgb[2] or 0) * 0.7152 + (rgb[3] or 0) * 0.0722) / 255
    if lum > 0.42 then
        return 0.035, 0.04, 0.038, 0.72
    end
    return 0.34, 0.36, 0.37, 0.78
end

function Render.shouldDrawTacticalGridTile(tile)
    if not tile then
        return false
    end
    if tile.blocker and (tile.terrainType == "sealed_archive_mass" or Render.tileHasTag(tile, "sealed_mass")) then
        return false
    end
    return true
end

function Render.buildTacticalGridModel(sim, minX, maxX, minY, maxY, app)
    if not (state.g3d and state.assets.white and sim and sim.world) then
        return nil, 0
    end
    local z = sim.player.z or 0
    local topology = Render.tacticalTopology(sim, app)
    local cells = {}
    for y = minY, maxY do
        for x = minX, maxX do
            local tile = sim.world:peekTile(x, y, z) or {}
            if Render.shouldDrawTacticalGridTile(tile) then
                cells[#cells + 1] = { x = x, y = y, tile = tile }
            end
        end
    end
    local total = #cells
    if total <= 0 then
        return nil, 0
    end
    local vertices = {}
    local data = love.image.newImageData(total, 1)
    for index, cell in ipairs(cells) do
        local tile = cell.tile
        local r, g, b, a = Render.tacticalGridColor(tile)
        data:setPixel(index - 1, 0, r, g, b, a)
        local tileHeight = Render.tacticalRenderHeight(tile)
        Render.pushTacticalGridRing(vertices, cell.x, cell.y, z + tileHeight + 0.012, (index - 0.5) / total, topology)
    end
    local model = state.g3d.newModel(vertices, newImageFromData(data))
    model:makeNormals()
    return model, total
end

function Render.cachedTacticalGridModel(sim, profile, settings, app)
    local minX, maxX, minY, maxY = tacticalBoardBounds(sim, app)
    if not minX then
        return nil, 0
    end
    local key = "tacticalGrid|" .. Render.worldTileCacheKey(sim, profile or lightProfile(sim), settings, app, minX, maxX, minY, maxY)
    return Render.cachedModel("tacticalGrid", key, function()
        return Render.buildTacticalGridModel(sim, minX, maxX, minY, maxY, app)
    end)
end

function Render.cachedWorldTileModel(sim, profile, settings, app)
    local minX, maxX, minY, maxY = tacticalBoardBounds(sim, app)
    if not minX then
        minX = sim.player.x - visibleRadius
        maxX = sim.player.x + visibleRadius
        minY = sim.player.y - visibleRadius
        maxY = sim.player.y + visibleRadius
    end
    local key = Render.worldTileCacheKey(sim, profile, settings, app, minX, maxX, minY, maxY)
    return Render.cachedModel("worldTiles", key, function()
        return buildWorldTileModel(sim, profile, settings, app, minX, maxX, minY, maxY), 0
    end)
end

local function exposedArchitecture(sim, x, y, z, tileDef)
    if not Render.isOccluderTile(tileDef) then
        return false
    end
    local neighbors = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
    for _, offset in ipairs(neighbors) do
        local tile = sim.world:peekTile(x + offset[1], y + offset[2], z)
        local def = tile and Defs.tile(tile.id)
        if def and (def.walkable == true or not Render.isOccluderTile(def)) then
            return true
        end
    end
    return false
end

local function buildArchitectureModel(sim, profile, settings)
    local vertices = {}
    local entries = {}
    local z = sim.player.z or 0
    for y = sim.player.y - visibleRadius, sim.player.y + visibleRadius do
        for x = sim.player.x - visibleRadius, sim.player.x + visibleRadius do
            local tile = sim.world:peekTile(x, y, z)
            local tileDef = tile and Defs.tile(tile.id)
            if exposedArchitecture(sim, x, y, z, tileDef) then
                entries[#entries + 1] = { x = x, y = y, z = z, def = tileDef }
            end
        end
    end
    if #entries == 0 then
        return nil, 0
    end
    local data = love.image.newImageData(#entries, 1)
    for index, entry in ipairs(entries) do
        local light = lightAt(sim, entry.x, entry.y, profile) * 0.92
        data:setPixel(index - 1, 0, litTileColor(entry.def.color or { 255, 255, 255 }, light, settings))
        pushBox(vertices, entry.x, entry.y, entry.z, Render.tileHeight(entry.def), (index - 0.5) / #entries)
    end
    local model = state.g3d.newModel(vertices, newImageFromData(data))
    model:makeNormals()
    return model, #entries
end

function Render.architectureCacheKey(sim, profile, settings)
    local z = sim.player.z or 0
    local parts = {
        "architecture",
        tostring(sim.player.x),
        tostring(sim.player.y),
        tostring(z),
        Render.settingsRenderKey(settings),
        string.format("%.3f", profile.ambient or 0),
        string.format("%.3f", profile.radius or 0),
    }
    for y = sim.player.y - visibleRadius, sim.player.y + visibleRadius do
        for x = sim.player.x - visibleRadius, sim.player.x + visibleRadius do
            local tile = sim.world:peekTile(x, y, z) or {}
            parts[#parts + 1] = tostring(tile.id or "")
        end
    end
    return table.concat(parts, "|")
end

function Render.cachedArchitectureModel(sim, profile, settings)
    local key = Render.architectureCacheKey(sim, profile, settings)
    return Render.cachedModel("architecture", key, function()
        return buildArchitectureModel(sim, profile, settings)
    end)
end

local function tacticalOverlaySource(sim, app)
    local source = (app and app.tactics) or (sim and sim.tactics)
    if not source then
        return nil
    end
    if source.board then
        return { state = source, overlays = app and app.tacticalOverlays or {} }
    end
    return source
end

function Render.tacticalVisibilityCacheKey(tactics)
    if not (tactics and tactics.board) then
        return nil
    end
    if tactics.revision then
        return table.concat({
            "visibility",
            tostring(tactics:revision("vision")),
            tostring(tactics:revision("terrain")),
            tostring(tactics:revision("units")),
            tostring(tactics.board.width or 0),
            tostring(tactics.board.height or 0),
        }, "|")
    end
    local parts = {
        "visibility",
        tostring(tactics.tick or 0),
        tostring(tactics.board.width or 0),
        tostring(tactics.board.height or 0),
    }
    for _, id in ipairs(tactics.unitOrder or {}) do
        local unit = tactics.units and tactics.units[id]
        if unit then
            parts[#parts + 1] = tostring(id)
            parts[#parts + 1] = tostring(unit.side or "")
            parts[#parts + 1] = tostring(unit.x or 0)
            parts[#parts + 1] = tostring(unit.y or 0)
            parts[#parts + 1] = tostring(unit.visionRadius or 8)
            parts[#parts + 1] = tostring(unit.alive == true)
            parts[#parts + 1] = tostring(unit.evacuated == true)
            parts[#parts + 1] = tostring(unit.hidden == true)
        end
    end
    for _, key in ipairs(sortedMapKeys(tactics.board.tiles or {})) do
        local tile = tactics.board.tiles[key]
        parts[#parts + 1] = tostring(key)
        parts[#parts + 1] = tostring(tile and tile.blocker == true)
        parts[#parts + 1] = tostring(tile and tile.losBlocker == true)
        parts[#parts + 1] = tostring(tile and tile.destroyed == true)
        parts[#parts + 1] = tostring(tile and tile.height or 0)
    end
    return table.concat(parts, "|")
end

function Render.cacheValueKey(value, depth)
    depth = depth or 0
    if depth > 5 or type(value) ~= "table" then
        return tostring(value)
    end
    local parts = {}
    for _, key in ipairs(sortedMapKeys(value)) do
        parts[#parts + 1] = tostring(key)
        parts[#parts + 1] = Render.cacheValueKey(value[key], depth + 1)
    end
    return table.concat(parts, ",")
end

function Render.tacticalOverlayEntriesKey(source, app)
    if not (source and source.state) then
        return nil
    end
    return table.concat({
        "overlayEntries",
        tostring(source.originX or 0),
        tostring(source.originY or 0),
        Render.settingsRenderKey(app and app.settings),
        Render.tacticalVisibilityCacheKey(source.state) or "",
        Render.cacheValueKey(source.overlays or {}),
    }, "|")
end

function Render.cachedTacticalOverlayEntries(source, app)
    local key = Render.tacticalOverlayEntriesKey(source, app)
    local cache = app and app.tacticalOverlayEntriesCache
    if cache and cache.key == key then
        return cache.entries, cache.counts
    end
    local entries, counts = Render.tacticalOverlayEntries(source.state, source.overlays or {}, app and app.settings)
    if app then
        app.tacticalOverlayEntriesCache = { key = key, entries = entries, counts = counts }
    end
    return entries, counts
end

local function tacticalCameraBounds(app)
    local source = tacticalOverlaySource(nil, app)
    local board = source and source.state and source.state.board
    if not board then
        return nil
    end
    local originX = source.originX or 0
    local originY = source.originY or 0
    return originX + 1.5, originY + 1.5, originX + board.width + 0.5, originY + board.height + 0.5
end

function Render.clampTacticalCameraCenter(app, x, y)
    local minX, minY, maxX, maxY = tacticalCameraBounds(app)
    if not minX then
        return x, y
    end
    return clamp(x, minX, maxX), clamp(y, minY, maxY)
end

function Render.tacticalCameraCenter(sim, app)
    local fallbackX = ((sim and sim.player and sim.player.x) or 0) + 0.5
    local fallbackY = ((sim and sim.player and sim.player.y) or 0) + 0.5
    local fallbackZ = (sim and sim.player and sim.player.z) or 0
    local x = (app and app.tacticalCameraUserMoved and app.tacticalCameraCenterX) or fallbackX
    local y = (app and app.tacticalCameraUserMoved and app.tacticalCameraCenterY) or fallbackY
    x, y = Render.clampTacticalCameraCenter(app, x, y)
    return x, y, fallbackZ
end

function Render.setTacticalCameraCenter(app, x, y)
    if not app then
        return nil
    end
    local currentX = app.tacticalCameraCenterX
    local currentY = app.tacticalCameraCenterY
    local camera = app.worldView and app.worldView.tacticalCamera
    if currentX == nil and camera then
        currentX = camera.targetX
        currentY = camera.targetY
    end
    x, y = Render.clampTacticalCameraCenter(app, x, y)
    app.tacticalCameraUserMoved = true
    app.tacticalCameraCenterX = x
    app.tacticalCameraCenterY = y
    if app.worldView then
        app.worldView.originX = x - 0.5
        app.worldView.originY = y - 0.5
    end
    if camera then
        local dx = x - (currentX or camera.targetX or x)
        local dy = y - (currentY or camera.targetY or y)
        camera.targetX = x
        camera.targetY = y
        camera.eyeX = (camera.eyeX or x) + dx
        camera.eyeY = (camera.eyeY or y) + dy
    end
    return x, y
end

function Render.panTacticalCamera(app, dx, dy)
    local camera = app and app.worldView and app.worldView.tacticalCamera
    local x = (app and app.tacticalCameraCenterX) or (camera and camera.targetX)
    local y = (app and app.tacticalCameraCenterY) or (camera and camera.targetY)
    if not (x and y) then
        return nil
    end
    return Render.setTacticalCameraCenter(app, x + (dx or 0), y + (dy or 0))
end

function Render.tacticalDragWorldDelta(app, fromX, fromY, toX, toY)
    local view = app and app.worldView
    if not view then
        return nil
    end
    local ax, ay = Render.tacticalScreenToWorldPoint(view, fromX, fromY)
    local bx, by = Render.tacticalScreenToWorldPoint(view, toX, toY)
    if not ax or not bx then
        ax, ay = Render.screenToWorldPoint(view, fromX, fromY)
        bx, by = Render.screenToWorldPoint(view, toX, toY)
    end
    return ax - bx, ay - by
end

local function tacticalVisibilityGrid(source, app)
    local runtime = source and source.visibilityGrid and source or app and app.tactics
    if runtime and runtime.visibilityGrid then
        local key = Render.tacticalVisibilityCacheKey(runtime.state)
        local cache = app and app.tacticalVisibilityCache
        if cache and cache.runtime == runtime and cache.key == key then
            return cache.visibility
        end
        local visibility = runtime:visibilityGrid()
        if app then
            app.tacticalVisibilityCache = { runtime = runtime, key = key, visibility = visibility }
        end
        return visibility
    end
    if source and source.overlays and source.overlays.fog and source.overlays.fog.visible then
        return source.overlays.fog
    end
    if source and source.state and source.state.fogGrid then
        return source.state:fogGrid("player")
    end
    return nil
end

function Render.tacticalFogSummary(tactics, visibility, lastSeenEnemies)
    local stateSource = tactics and tactics.state or tactics
    if not visibility and tactics and tactics.visibilityGrid then
        visibility = tactics:visibilityGrid()
    end
    if not visibility and stateSource and stateSource.fogGrid then
        visibility = stateSource:fogGrid("player")
    end
    local summary = { visibleTiles = 0, fogTiles = 0, visibleEnemies = 0, hiddenEnemies = 0, ghostEnemies = 0 }
    for _, fogged in pairs((visibility and visibility.fog) or {}) do
        if fogged then
            summary.fogTiles = summary.fogTiles + 1
        else
            summary.visibleTiles = summary.visibleTiles + 1
        end
    end
    if stateSource then
        for _, enemy in ipairs(stateSource:unitsForSide("enemy")) do
            if visibility and visibility.visible[tileKey(enemy.x, enemy.y)] then
                summary.visibleEnemies = summary.visibleEnemies + 1
            else
                summary.hiddenEnemies = summary.hiddenEnemies + 1
            end
        end
    end
    for _, sighting in pairs(lastSeenEnemies or (tactics and tactics.lastSeenEnemies) or {}) do
        local enemy = stateSource and stateSource:unit(sighting.id)
        if enemy and enemy.alive and not (visibility and visibility.visible[tileKey(enemy.x, enemy.y)]) then
            summary.ghostEnemies = summary.ghostEnemies + 1
        end
    end
    return summary
end

local function buildTacticalFogModel(source, visibility, z)
    local tactics = source and source.state
    if not (tactics and visibility and visibility.fog and state.g3d and state.assets.white) then
        return nil, 0
    end
    local tiles = {}
    for y = 1, tactics.board.height do
        for x = 1, tactics.board.width do
            if visibility.fog[tileKey(x, y)] then
                local tile = tactics:tileAt(x, y)
                if Render.shouldDrawTacticalGridTile(tile) then
                    tiles[#tiles + 1] = { x = x, y = y }
                end
            end
        end
    end
    if #tiles == 0 then
        return nil, 0
    end
    local vertices = {}
    local data = love.image.newImageData(#tiles, 1)
    local originX = source.originX or 0
    local originY = source.originY or 0
    local topology = Render.Topology.normalize(tactics.board and tactics.board.topology)
    for index, tile in ipairs(tiles) do
        data:setPixel(index - 1, 0, 0.008, 0.01, 0.012, 0.68)
        Render.pushTilePolygon(vertices, topology, originX + tile.x, originY + tile.y, z or 0, (index - 0.5) / #tiles)
    end
    local model = state.g3d.newModel(vertices, newImageFromData(data))
    model:makeNormals()
    return model, #tiles
end

local function drawTacticalFog(sim, app)
    local source = tacticalOverlaySource(sim, app)
    if not (app and app.tacticalMode and source and source.state and love and love.graphics) then
        return 0
    end
    local visibility = tacticalVisibilityGrid(source, app)
    local z = ((sim and sim.player and sim.player.z) or 0) + 0.026
    local key = table.concat({
        "fog",
        tostring(source.originX or 0),
        tostring(source.originY or 0),
        tostring(z),
        Render.tacticalVisibilityCacheKey(source.state) or Render.cacheValueKey(visibility and visibility.fog or {}),
    }, "|")
    local model, count = Render.cachedModel("tacticalFog", key, function()
        return buildTacticalFogModel(source, visibility, z)
    end)
    if model then
        love.graphics.setColor(1, 1, 1, 1)
        model:draw()
    end
    return count
end

function Render.tacticalTileAt(app, screenX, screenY)
    local source = tacticalOverlaySource(nil, app)
    local view = app and app.worldView
    if not (source and source.state and view) then
        return nil
    end
    local worldX, worldY = Render.tacticalScreenToWorldPoint(view, screenX, screenY)
    if not worldX then
        worldX, worldY = Render.screenToWorldPoint(view, screenX, screenY)
    end
    local tileX, tileY = Render.Topology.cellAtPoint(source.state.board.topology, worldX, worldY, source.originX or 0, source.originY or 0)
    if not source.state:inBounds(tileX, tileY) then
        return nil
    end
    return tileX, tileY
end

local function pushOverlayLine(vertices, x1, y1, x2, y2, z, halfWidth, u)
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0 then
        return
    end
    local px = -dy / length * halfWidth
    local py = dx / length * halfWidth
    pushFace(vertices,
        { x1 + px, y1 + py, z },
        { x2 + px, y2 + py, z },
        { x2 - px, y2 - py, z },
        { x1 - px, y1 - py, z },
        u)
end

local tacticalRingSpecs = {
    movementFill = { inset = 0.09, z = 0.04, fillOnly = true },
    movement = { inset = 0.08, width = 0.04, z = 0.075 },
    intent = { inset = 0.1, width = 0.045, z = 0.08 },
    overwatch = { inset = 0.14, width = 0.04, z = 0.085 },
    aiDebug = { inset = 0.28, width = 0.03, z = 0.14 },
    objective = { inset = 0.07, width = 0.045, z = 0.09 },
    blocker = { inset = 0.16, width = 0.035, z = 0.07 },
    selected = { inset = 0.19, width = 0.05, z = 0.11 },
    cursor = { inset = 0.02, width = 0.055, z = 0.12 },
    hover = { inset = 0.24, width = 0.035, z = 0.13 },
}

local function pushTileRing(vertices, x, y, baseZ, kind, u, scale, topology)
    local spec = tacticalRingSpecs[kind] or tacticalRingSpecs.movement
    scale = clamp(scale or 1, 0.75, 1.75)
    local inset = clamp(spec.inset - ((scale - 1) * 0.055), 0.02, 0.42)
    local z = baseZ + spec.z
    topology = Render.Topology.normalize(topology)
    if topology ~= "square" then
        local points = Render.Topology.vertices(topology, x, y, inset)
        if spec.fillOnly then
            if #points >= 3 then
                local first = { points[1][1], points[1][2], z }
                for index = 2, #points - 1 do
                    pushFace(vertices, first, { points[index][1], points[index][2], z }, { points[index + 1][1], points[index + 1][2], z }, first, u)
                end
            end
            return
        end
        local width = spec.width * scale
        for index = 1, #points do
            local nextPoint = points[index % #points + 1]
            pushOverlayLine(vertices, points[index][1], points[index][2], nextPoint[1], nextPoint[2], z, width, u)
        end
        return
    end
    local left = x + inset
    local right = x + 1 - inset
    local top = y + inset
    local bottom = y + 1 - inset
    if spec.fillOnly then
        pushFace(vertices, { left, top, z }, { right, top, z }, { right, bottom, z }, { left, bottom, z }, u)
        return
    end
    local width = spec.width * scale
    pushOverlayLine(vertices, left, top, right, top, z, width, u)
    pushOverlayLine(vertices, right, top, right, bottom, z, width, u)
    pushOverlayLine(vertices, right, bottom, left, bottom, z, width, u)
    pushOverlayLine(vertices, left, bottom, left, top, z, width, u)
end

local function buildTacticalOverlayModel(entries, source, settings, z)
    if #entries == 0 then
        return nil
    end
    local vertices = {}
    local data = love.image.newImageData(#entries, 1)
    local originX = source.originX or 0
    local originY = source.originY or 0
    local topology = Render.Topology.normalize(source.state and source.state.board and source.state.board.topology)
    for index, entry in ipairs(entries) do
        local color = Render.accessibleColor(settings, entry.color or tacticalOverlayColors[entry.kind] or { 1, 1, 1, 0.5 })
        data:setPixel(index - 1, 0, color[1], color[2], color[3], color[4] or 0.5)
        local tile = source.state and source.state:inBounds(entry.x, entry.y) and source.state:tileAt(entry.x, entry.y) or nil
        pushTileRing(vertices, originX + entry.x, originY + entry.y, (z or 0) + Render.tacticalRenderHeight(tile), entry.kind, (index - 0.5) / #entries, entry.iconScale or 1, topology)
    end
    local model = state.g3d.newModel(vertices, newImageFromData(data))
    model:makeNormals()
    return model
end

local function drawTacticalOverlays(sim, app)
    local source = tacticalOverlaySource(sim, app)
    if not (source and source.state) then
        return nil
    end
    local entries, counts = Render.cachedTacticalOverlayEntries(source, app)
    counts.total = #entries
    local drawnEntries = {}
    for _, entry in ipairs(entries) do
        if entry.kind == "movement" or entry.kind == "intent" or entry.kind == "overwatch" or entry.kind == "aiDebug" or entry.kind == "objective" or entry.kind == "blocker" or entry.kind == "cursor" then
            if entry.kind == "movement" then
                drawnEntries[#drawnEntries + 1] = { kind = "movementFill", x = entry.x, y = entry.y, label = entry.label, color = { 0.1, 0.42, 0.9, 0.34 } }
            end
            drawnEntries[#drawnEntries + 1] = entry
        end
    end
    local selected = app and app.tactics and app.tactics.selectedUnitId and source.state:unit(app.tactics.selectedUnitId)
    if selected then
        drawnEntries[#drawnEntries + 1] = { kind = "selected", x = selected.x, y = selected.y, label = "selected" }
    end
    if app and app.tacticalHover then
        drawnEntries[#drawnEntries + 1] = { kind = "hover", x = app.tacticalHover.x, y = app.tacticalHover.y, label = "hover" }
    end
    if app and app.tacticalIntentHover then
        for _, tile in ipairs(app.tacticalIntentHover.targetTiles or {}) do
            drawnEntries[#drawnEntries + 1] = { kind = "intent", x = tile.x, y = tile.y, label = "legend_target", color = { 1.0, 0.48, 0.22, 0.96 } }
        end
        local sourceTile = app.tacticalIntentHover.sourceTile
        if sourceTile then
            drawnEntries[#drawnEntries + 1] = { kind = "selected", x = sourceTile.x, y = sourceTile.y, label = "legend_source", color = { 1.0, 0.68, 0.24, 0.98 } }
        end
    end
    for _, flash in ipairs((app and app.tacticalHitFlashes) or {}) do
        local duration = math.max(0.001, flash.duration or 0.28)
        local progress = 1 - clamp01((flash.t or 0) / duration)
        local alpha = clamp01((flash.t or 0) / duration)
        local color = flash.blocked and { 0.72, 0.74, 0.68, 0.58 * alpha } or { 1.0, 0.72, 0.28, 0.78 * alpha }
        if flash.targetSide == "player" and not flash.blocked then
            color = { 1.0, 0.24, 0.18, 0.82 * alpha }
        end
        drawnEntries[#drawnEntries + 1] = { kind = "intent", x = flash.x, y = flash.y, label = "hit", color = color, iconScale = 1.2 + progress * 0.75 }
    end
    if #drawnEntries > 0 and state.g3d and state.assets.white then
        local z = ((sim and sim.player and sim.player.z) or 0) + 0.035
        local key = table.concat({
            "overlayModel",
            tostring(source.originX or 0),
            tostring(source.originY or 0),
            tostring(z),
            Render.settingsRenderKey(app and app.settings),
            Render.cacheValueKey(drawnEntries),
        }, "|")
        local model = Render.cachedModel("tacticalOverlay", key, function()
            return buildTacticalOverlayModel(drawnEntries, source, app and app.settings, z), #drawnEntries
        end)
        if model then
            love.graphics.setDepthMode("always", false)
            love.graphics.setColor(1, 1, 1, 1)
            model:draw()
            love.graphics.setDepthMode("lequal", true)
        end
    end
    return counts
end

function Render.tacticalOverwatchAnimation(trigger, time)
    if not trigger then
        return nil
    end
    local phase = ((time or 0) * 2.8) % 1
    return {
        x = trigger.x,
        y = trigger.y,
        source = trigger.source,
        target = trigger.target,
        reaction = trigger.reaction,
        alpha = 0.32 + (1 - phase) * 0.5,
        scale = 1 + phase * 0.42,
    }
end

local function drawTacticalOverwatchTrigger(sim, app)
    local source = tacticalOverlaySource(sim, app)
    local trigger = app and app.tactics and app.tactics.overwatchTrigger or source and source.state and source.state.lastOverwatchTrigger
    local pulse = Render.tacticalOverwatchAnimation(trigger, app and app.titleTime or 0)
    if not (pulse and source and state.g3d and state.assets.white) then
        return 0
    end
    local model = buildTacticalOverlayModel({
        { kind = "overwatch", x = pulse.x, y = pulse.y, label = pulse.reaction, color = { 0.22, 1.0, 0.95, pulse.alpha } },
    }, source, app and app.settings, ((sim and sim.player and sim.player.z) or 0) + 0.11)
    if model then
        love.graphics.setColor(1, 1, 1, 1)
        model:draw()
        return 1
    end
    return 0
end

function Render.drawTacticalForecast(sim, app)
    if not (love and love.graphics and app and app.tacticalMode and app.worldView) then
        return nil
    end
    local source = tacticalOverlaySource(sim, app)
    if not (source and source.state) then
        return nil
    end
    local entries = Render.cachedTacticalOverlayEntries(source, app)
    return #entries + (app.tacticalHover and 1 or 0)
end

local function applyCamera(sim, app, targetX, targetY, targetZ)
    local visualRotation = app.viewRotationVisual or app.viewRotation or 0
    local yaw = baseYaw + visualRotation * math.pi / 2
    local horizontal = math.cos(cameraPitch) * cameraDistance
    local zoom = app and app.tacticalMode and Render.tacticalZoom(app) or 1
    targetX = targetX or (sim.player.x + 0.5)
    targetY = targetY or (sim.player.y + 0.5)
    targetZ = targetZ or (sim.player.z or 0)
    local x = targetX + math.cos(yaw) * horizontal
    local y = targetY - math.sin(yaw) * horizontal
    local z = targetZ + math.sin(cameraPitch) * cameraDistance
    state.g3d.camera.lookAt(x, y, z, targetX, targetY, targetZ)
    local viewSize = app and app.tacticalMode and (cameraViewSize * 0.58) or cameraViewSize
    local orthoSize = viewSize / zoom
    state.g3d.camera.updateOrthographicMatrix(orthoSize)
    if app and app.tacticalMode and app.worldView then
        app.worldView.tacticalCamera = {
            eyeX = x,
            eyeY = y,
            eyeZ = z,
            targetX = targetX,
            targetY = targetY,
            targetZ = targetZ,
            boardZ = targetZ,
            orthoSize = orthoSize,
            screenWidth = love.graphics.getWidth(),
            screenHeight = love.graphics.getHeight(),
        }
    end
    return yaw
end

local function atlasFrameUv(frame)
    local meta = (state.assets and state.assets.spriteAtlasMeta) or defaultAtlasMeta
    local columns = meta.columns or atlasColumns
    local rows = meta.rows or atlasRows
    local frames = meta.frames or (columns * rows)
    local index = (frame or 0) % frames
    local col = index % columns
    local row = math.floor(index / columns)
    local u0 = col / columns
    local u1 = (col + 1) / columns
    local v0 = row / rows
    local v1 = (row + 1) / rows
    return u0, v0, u1, v1
end

local function atlasFrameQuad(frame)
    if not (love and love.graphics and state.assets and state.assets.spriteAtlas) then
        return nil
    end
    local image = state.assets.spriteAtlas
    local meta = state.assets.spriteAtlasMeta or defaultAtlasMeta
    local columns = meta.columns or atlasColumns
    local frames = meta.frames or columns * (meta.rows or atlasRows)
    local index = (frame or 0) % frames
    state.quads = state.quads or {}
    if state.quads[index] then
        return state.quads[index].quad, state.quads[index].w, state.quads[index].h
    end
    local frameW = meta.frameWidth or math.floor(image:getWidth() / columns)
    local frameH = meta.frameHeight or math.floor(image:getHeight() / (meta.rows or atlasRows))
    local col = index % columns
    local row = math.floor(index / columns)
    local quad = love.graphics.newQuad(col * frameW, row * frameH, frameW, frameH, image:getWidth(), image:getHeight())
    state.quads[index] = { quad = quad, w = frameW, h = frameH }
    return quad, frameW, frameH
end

local classNameToKey = {
    Warden = "warden",
    Duelist = "duelist",
    Apothecary = "mender",
    Arcanist = "arcanist",
    Thief = "harrier",
    Chirurgeon = "chirurgeon",
    Exile = "exile",
    Lamplighter = "lamplighter",
    Merchant = "merchant",
}

local function namedAtlasFrame(name, fallback)
    local meta = (state.assets and state.assets.spriteAtlasMeta) or defaultAtlasMeta
    local framesByName = meta.framesByName or {}
    if name and framesByName[name] ~= nil then
        return framesByName[name]
    end
    if fallback and framesByName[fallback] ~= nil then
        return framesByName[fallback]
    end
    return 0
end

local function heroFrame(hero)
    local meta = (state.assets and state.assets.spriteAtlasMeta) or defaultAtlasMeta
    local classKey = hero and (hero.classId or classNameToKey[hero.class])
    local entry = classKey and meta.classes and meta.classes[classKey]
    return namedAtlasFrame(entry and entry.frame, meta.fallbacks and meta.fallbacks.hero)
end

function Render.cutsceneSpriteFrameForHero(hero)
    return heroFrame(hero)
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
    state.billboardCache = state.billboardCache or {}
    local key = table.concat({ tostring(width), tostring(height), tostring(frame or 0), tostring(texture) }, "|")
    local model = state.billboardCache[key]
    if not model then
        model = state.g3d.newModel(billboardVerts(width, height, frame), texture, { 0, 0, 0 })
        state.billboardCache[key] = model
    end
    local rotation = math.pi / 2 - yaw
    if model._billboardRotation ~= rotation then
        model:setRotation(0, 0, rotation)
        model._billboardRotation = rotation
    end
    model:setTranslation(x, y, z or 0)
    return model
end

local function drawLitModel(model, light)
    love.graphics.setColor(light, light, light, 1)
    model:draw()
end

local function drawTintedModel(model, color, light, alpha)
    love.graphics.setColor((color[1] or 1) * light, (color[2] or 1) * light, (color[3] or 1) * light, alpha or color[4] or 1)
    model:draw()
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
            local model = newBillboard(0.85, 1.1, heroFrame(hero), x, y, sim.player.z or 0, yaw)
            drawLitModel(model, lightAt(sim, x, y, profile))
        end
    end
end

local function enemyFrame(objectType, enemyKind)
    local meta = (state.assets and state.assets.spriteAtlasMeta) or defaultAtlasMeta
    local entry = enemyKind and meta.enemies and meta.enemies[enemyKind]
    if entry then
        return namedAtlasFrame(entry.frame, meta.fallbacks and meta.fallbacks.threat)
    end
    local fallback = meta.fallbacks and (meta.fallbacks[objectType] or meta.fallbacks.threat)
    return namedAtlasFrame(fallback, meta.fallbacks and meta.fallbacks.threat)
end

function Render.cutsceneSpriteFrameForEnemy(enemyKind, objectType)
    return enemyFrame(objectType or "threat", enemyKind)
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
    return state.assets.spriteAtlas or state.assets.enemy or state.assets.white
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
            local model = newBillboard(width, height, enemyFrame(objectType, enemy.kind), x, y, sim.player.z or 0, yaw, enemyTexture(objectType))
            drawLitModel(model, lightAt(sim, x, y, profile))
        end
    end
    return true
end

local function isEnemyObject(object)
    return object.type == "threat" or object.type == "alpha" or object.type == "encounter" or object.type == "boss"
end

local function drawWorldEnemyBillboards(sim, app, yaw, profile)
    if not sim.objectsInRect then
        return 0, 0
    end
    local minX = sim.player.x - visibleRadius
    local maxX = sim.player.x + visibleRadius
    local minY = sim.player.y - visibleRadius
    local maxY = sim.player.y + visibleRadius
    local visible = 0
    local hidden = 0
    for _, object in ipairs(sim:objectsInRect(minX, maxX, minY, maxY, sim.player.z or 0)) do
        if isEnemyObject(object) then
            local reveal = Render.objectRevealState(sim, app, object)
            local width, height = enemySize(object.type)
            local model = newBillboard(width, height, enemyFrame(object.type), object.x + 0.5, object.y + 0.5, object.z or 0, yaw, enemyTexture(object.type))
            if reveal.visible then
                visible = visible + 1
                drawLitModel(model, lightAt(sim, object.x, object.y, profile))
            elseif reveal.alpha > 0 then
                hidden = hidden + 1
                drawTintedModel(model, { 0.28, 0.3, 0.32, 1 }, lightAt(sim, object.x, object.y, profile), reveal.alpha)
            end
        end
    end
    return visible, hidden
end

local function objectMarkerColor(object)
    local tileDef = object and object.tile and Defs.tile(object.tile) or nil
    local rgb = tileDef and tileDef.color or { 180, 160, 96 }
    if object.type == "exit" then
        rgb = { 70, 150, 170 }
    elseif object.type == "boss" or object.type == "encounter" then
        rgb = { 180, 70, 88 }
    end
    return { (rgb[1] or 255) / 255, (rgb[2] or 255) / 255, (rgb[3] or 255) / 255, 1 }
end

local function drawWorldObjectMarkers(sim, app, yaw, profile)
    if not (sim.objectsInRect and state.assets.white) then
        return 0, 0, 0
    end
    local minX = sim.player.x - visibleRadius
    local maxX = sim.player.x + visibleRadius
    local minY = sim.player.y - visibleRadius
    local maxY = sim.player.y + visibleRadius
    local visible = 0
    local hidden = 0
    local puzzles = 0
    for _, object in ipairs(sim:objectsInRect(minX, maxX, minY, maxY, sim.player.z or 0)) do
        if not isEnemyObject(object) then
            local reveal = Render.objectRevealState(sim, app, object)
            local alpha = reveal.visible and 0.92 or reveal.alpha
            if alpha > 0.02 then
                local model = newBillboard(0.42, 0.55, 0, object.x + 0.5, object.y + 0.5, (object.z or 0) + 0.06, yaw, state.assets.white)
                local color = reveal.visible and objectMarkerColor(object) or { 0.24, 0.25, 0.28, 1 }
                drawTintedModel(model, color, lightAt(sim, object.x, object.y, profile), alpha)
            end
            if reveal.visible then
                visible = visible + 1
            else
                hidden = hidden + 1
            end
            if reveal.rotationPuzzle then
                puzzles = puzzles + 1
            end
        end
    end
    return visible, hidden, puzzles
end

local function drawEnemyBillboards(sim, app, yaw, profile)
    if not (state.g3d and (state.assets.spriteAtlas or state.assets.white)) then
        return 0, 0
    end
    if drawCombatEnemyBillboards(sim, yaw, profile) then
        return 0, 0
    end
    return drawWorldEnemyBillboards(sim, app, yaw, profile)
end

local function pushGroundLine(vertices, x1, y1, x2, y2, z, halfWidth, u)
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0 then
        return
    end
    local px = -dy / length * halfWidth
    local py = dx / length * halfWidth
    pushFace(vertices,
        { x1 + px, y1 + py, z },
        { x2 + px, y2 + py, z },
        { x2 - px, y2 - py, z },
        { x1 - px, y1 - py, z },
        u)
end

local function pushGroundArrowHead(vertices, tx, ty, ux, uy, z, u)
    local baseX = tx - ux * 0.22
    local baseY = ty - uy * 0.22
    local px = -uy * 0.16
    local py = ux * 0.16
    vertices[#vertices + 1] = tileVertex(tx, ty, z, u)
    vertices[#vertices + 1] = tileVertex(baseX + px, baseY + py, z, u)
    vertices[#vertices + 1] = tileVertex(baseX - px, baseY - py, z, u)
end

local function appendGridArrowSegment(segments, x1, y1, x2, y2, startInset, endInset)
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.abs(dx) + math.abs(dy)
    if length <= 0 then
        return
    end
    local ux = dx ~= 0 and (dx > 0 and 1 or -1) or 0
    local uy = dy ~= 0 and (dy > 0 and 1 or -1) or 0
    local sx = x1 + ux * (startInset or 0)
    local sy = y1 + uy * (startInset or 0)
    local tx = x2 - ux * (endInset or 0)
    local ty = y2 - uy * (endInset or 0)
    if math.abs(tx - sx) + math.abs(ty - sy) <= 0.02 then
        return
    end
    segments[#segments + 1] = { x1 = sx, y1 = sy, x2 = tx, y2 = ty, ux = ux, uy = uy }
end

function Render.tacticalGridArrowSegments(sourceTile, targetTile, originX, originY)
    if not (sourceTile and targetTile) then
        return {}
    end
    local sx = (originX or 0) + sourceTile.x + 0.5
    local sy = (originY or 0) + sourceTile.y + 0.5
    local tx = (originX or 0) + targetTile.x + 0.5
    local ty = (originY or 0) + targetTile.y + 0.5
    local dx = targetTile.x - sourceTile.x
    local dy = targetTile.y - sourceTile.y
    local points = { { x = sx, y = sy } }
    if dx ~= 0 and dy ~= 0 then
        if math.abs(dx) >= math.abs(dy) then
            points[#points + 1] = { x = tx, y = sy }
        else
            points[#points + 1] = { x = sx, y = ty }
        end
    end
    points[#points + 1] = { x = tx, y = ty }
    local segments = {}
    for index = 1, #points - 1 do
        appendGridArrowSegment(segments, points[index].x, points[index].y, points[index + 1].x, points[index + 1].y, index == 1 and 0.28 or 0, index == #points - 1 and 0.24 or 0)
    end
    return segments
end

local function drawTacticalIntentArrows(sim, app)
    local source = tacticalOverlaySource(sim, app)
    local tactics = source and source.state
    if not (app and app.tacticalMode and tactics and state.g3d and state.assets.white) then
        return 0
    end
    local visibility = tacticalVisibilityGrid(source, app)
    local z = ((sim and sim.player and sim.player.z) or 0) + 0.08
    local key = table.concat({
        "intentArrows",
        tostring(source.originX or 0),
        tostring(source.originY or 0),
        tostring(z),
        Render.tacticalVisibilityCacheKey(tactics) or "",
        Render.cacheValueKey(visibility and visibility.visible or {}),
    }, "|")
    local model, count = Render.cachedModel("tacticalIntentArrows", key, function()
        local vertices = {}
        local originX = source.originX or 0
        local originY = source.originY or 0
        local count = 0
        for _, unit in ipairs(tactics:unitsForSide("enemy")) do
            local intent = tactics:intentPreview(unit.id)
            local target = intent and intent.targetTiles and intent.targetTiles[1]
            local sourceTile = intent and intent.sourceTile
            local sourceVisible = not visibility or visibility.visible[tileKey(unit.x, unit.y)] == true
            local targetVisible = target and (not visibility or visibility.visible[tileKey(target.x, target.y)] == true)
            if target and sourceTile and sourceVisible and targetVisible then
                local segments = Render.tacticalGridArrowSegments(sourceTile, target, originX, originY)
                local sourceHeight = tactics:inBounds(sourceTile.x, sourceTile.y) and Render.tacticalRenderHeight(tactics:tileAt(sourceTile.x, sourceTile.y)) or 0
                local targetHeight = tactics:inBounds(target.x, target.y) and Render.tacticalRenderHeight(tactics:tileAt(target.x, target.y)) or 0
                local arrowZ = z + math.max(sourceHeight, targetHeight)
                for index, segment in ipairs(segments) do
                    pushGroundLine(vertices, segment.x1, segment.y1, segment.x2, segment.y2, arrowZ, 0.04, 0.5)
                    if index == #segments then
                        pushGroundArrowHead(vertices, segment.x2, segment.y2, segment.ux, segment.uy, arrowZ, 0.5)
                    end
                end
                if #segments > 0 then
                    count = count + 1
                end
            end
        end
        if #vertices == 0 then
            return nil, count
        end
        local model = state.g3d.newModel(vertices, state.assets.white)
        model:makeNormals()
        return model, count
    end)
    if not model then
        return count or 0
    end
    love.graphics.setColor(1.0, 0.22, 0.32, 0.92)
    model:draw()
    love.graphics.setColor(1, 1, 1, 1)
    return count or 0
end

local function drawTacticalBillboards(sim, app, yaw, profile)
    local source = tacticalOverlaySource(sim, app)
    local tactics = source and source.state
    if not (app and app.tacticalMode and tactics and state.g3d and (state.assets.spriteAtlas or state.assets.white)) then
        return 0
    end
    local originX = source.originX or 0
    local originY = source.originY or 0
    local visibility = tacticalVisibilityGrid(source, app)
    local drawn = 0
    local visibleEnemies = {}
    for _, id in ipairs(tactics.unitOrder or {}) do
        local unit = tactics.units[id]
        if unit and unit.alive and not unit.evacuated then
            local enemyHidden = unit.side == "enemy" and visibility and not visibility.visible[tileKey(unit.x, unit.y)]
            if enemyHidden then
                goto continue
            end
            local x = originX + unit.x + 0.5
            local y = originY + unit.y + 0.5
            local tile = tactics:inBounds(unit.x, unit.y) and tactics:tileAt(unit.x, unit.y) or nil
            local unitZ = (sim.player.z or 0) + Render.tacticalRenderHeight(tile)
            local selected = app.tactics and app.tactics.selectedUnitId == unit.id
            local intentHot = app.tacticalIntentHover and app.tacticalIntentHover.unit == unit.id
            local width, height = unit.side == "enemy" and enemySize("threat") or 0.86, unit.side == "enemy" and 1.12 or 1.08
            local frame = unit.side == "enemy" and enemyFrame("threat", unit.kind) or heroFrame({ classId = unit.class })
            local model = newBillboard(width, height, frame, x, y, unitZ, yaw, state.assets.spriteAtlas or state.assets.white)
            if intentHot then
                drawTintedModel(model, { 1.0, 0.68, 0.24, 1 }, lightAt(sim, x, y, profile), 1)
            elseif unit.side == "enemy" then
                drawTintedModel(model, { 0.9, 0.36, 0.28, 1 }, lightAt(sim, x, y, profile), 1)
            elseif selected then
                drawTintedModel(model, { 0.72, 0.9, 0.58, 1 }, lightAt(sim, x, y, profile), 1)
            else
                drawLitModel(model, lightAt(sim, x, y, profile))
            end
            if unit.side == "enemy" then
                visibleEnemies[unit.id] = true
            end
            drawn = drawn + 1
        end
        ::continue::
    end
    local sightings = app and app.tactics and app.tactics.lastSeenEnemies or {}
    for _, id in ipairs(sortedMapKeys(sightings)) do
        local sighting = sightings[id]
        local unit = tactics:unit(id)
        if sighting and unit and unit.alive and not visibleEnemies[id] then
            local x = originX + sighting.x + 0.5
            local y = originY + sighting.y + 0.5
            local tile = tactics:inBounds(sighting.x, sighting.y) and tactics:tileAt(sighting.x, sighting.y) or nil
            local model = newBillboard(0.66, 0.8, enemyFrame("threat", sighting.kind), x, y, (sim.player.z or 0) + 0.03 + Render.tacticalRenderHeight(tile), yaw, state.assets.spriteAtlas or state.assets.white)
            drawTintedModel(model, { 0.36, 0.4, 0.42, 1 }, lightAt(sim, x, y, profile), 0.38)
            drawn = drawn + 1
        end
    end
    local objective = tactics.objectives and tactics.objectives.route_machine
    if objective and state.assets.white then
        local x = originX + objective.x + 0.5
        local y = originY + objective.y + 0.5
        local model = newBillboard(0.5, 0.68, 0, x, y, (sim.player.z or 0) + 0.05, yaw, state.assets.white)
        drawTintedModel(model, { 0.84, 0.68, 0.32, 1 }, lightAt(sim, x, y, profile), 0.95)
        drawn = drawn + 1
    end
    return drawn
end

function Render.drawWorld(sim, app)
    app.worldView = app.worldView or {}
    app.worldView.mode = "render3d-placeholder"
    local screenWidth = love and love.graphics and love.graphics.getWidth() or 0
    local screenHeight = love and love.graphics and love.graphics.getHeight() or 0
    local tacticalLayout = app and app.tacticalMode and Render.tacticalHudLayout(screenWidth, screenHeight, 6) or nil
    app.worldView.boardRect = tacticalLayout and tacticalLayout.board or nil
    app.worldView.centerX = tacticalLayout and (tacticalLayout.board.x + tacticalLayout.board.w * 0.5) or (screenWidth / 2)
    app.worldView.centerY = tacticalLayout and (tacticalLayout.board.y + tacticalLayout.board.h * 0.5) or (screenHeight / 2)
    local zoom = app and app.tacticalMode and Render.tacticalZoom(app) or 1
    app.worldView.halfW = 32 * zoom
    app.worldView.halfH = 16 * zoom
    local targetX, targetY, targetZ = Render.tacticalCameraCenter(sim, app)
    app.worldView.originX = (targetX or 0) - 0.5
    app.worldView.originY = (targetY or 0) - 0.5
    app.worldView.rotation = app.viewRotation or 0
    if not (love and love.graphics and sim and sim.world and state.g3d) then
        return
    end
    app.worldView.mode = "render3d"
    local profile = lightProfile(sim)
    app.worldView.light = { torch = profile.torch, ambient = profile.ambient, radius = profile.radius }
    local yaw = applyCamera(sim, app, targetX, targetY, targetZ)
    local model = Render.cachedWorldTileModel(sim, profile, app and app.settings, app)
    love.graphics.setColor(1, 1, 1, 1)
    model:draw()
    local tacticalGridCount = 0
    if app and app.tacticalMode then
        local gridModel, gridCount = Render.cachedTacticalGridModel(sim, profile, app and app.settings, app)
        tacticalGridCount = gridCount or 0
        if gridModel then
            love.graphics.setColor(1, 1, 1, 1)
            gridModel:draw()
        end
    end
    local tacticalFogCount = drawTacticalFog(sim, app)
    local tacticalOverlayCounts = drawTacticalOverlays(sim, app)
    drawTacticalIntentArrows(sim, app)
    local tacticalOverwatchTriggers = drawTacticalOverwatchTrigger(sim, app)
    local architecture, architectureCount = nil, 0
    if not (app and app.tacticalMode) then
        architecture, architectureCount = Render.cachedArchitectureModel(sim, profile, app and app.settings)
    end
    if architecture then
        love.graphics.setColor(1, 1, 1, 1)
        architecture:draw()
    end
    local visibleObjects, hiddenObjects, rotationPuzzles = 0, 0, 0
    local visibleEnemies, hiddenEnemies = 0, 0
    if app and app.tacticalMode then
        visibleObjects = drawTacticalBillboards(sim, app, yaw, profile)
    else
        visibleObjects, hiddenObjects, rotationPuzzles = drawWorldObjectMarkers(sim, app, yaw, profile)
        drawHeroBillboards(sim, yaw, profile)
        visibleEnemies, hiddenEnemies = drawEnemyBillboards(sim, app, yaw, profile)
    end
    app.worldView.architecture = architectureCount or 0
    app.worldView.revealedObjects = (visibleObjects or 0) + (visibleEnemies or 0)
    app.worldView.hiddenObjects = (hiddenObjects or 0) + (hiddenEnemies or 0)
    app.worldView.rotationPuzzles = rotationPuzzles or 0
    app.worldView.tacticalOverlays = tacticalOverlayCounts
    app.worldView.tacticalFog = tacticalFogCount
    app.worldView.tacticalGrid = tacticalGridCount
    app.worldView.tacticalOverwatchTriggers = tacticalOverwatchTriggers
end

function Render.titleMenuItems(app)
    local canContinue = app and app.canContinue == true
    local canReplay = app and app.canReplay == true
    return {
        { action = "new", label = i18n.t("New Game"), enabled = true },
        { action = "continue", label = i18n.t("Continue"), enabled = canContinue },
        { action = "replay", label = i18n.t("Replay"), enabled = canReplay },
        { action = "settings", label = i18n.t("Settings"), enabled = true },
        { action = "credits", label = i18n.t("Credits"), enabled = true },
        { action = "quit", label = i18n.t("Quit"), enabled = true },
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

function Render.classUnlockSummary(sim)
    local statuses = sim and sim.classUnlockStatus and sim:classUnlockStatus() or {}
    local unlocked = 0
    local nextLocked = nil
    for _, status in ipairs(statuses) do
        if status.unlocked then
            unlocked = unlocked + 1
        elseif not nextLocked then
            nextLocked = status
        end
    end
    local line = i18n.t("classes") .. " " .. tostring(unlocked) .. "/" .. tostring(#statuses)
    if nextLocked then
        line = line .. " " .. i18n.t("next") .. " " .. nextLocked.name .. ": " .. nextLocked.reason
    end
    return { unlocked = unlocked, total = #statuses, next = nextLocked, line = line, statuses = statuses }
end

local function combatActorLabel(sim, actor)
    if not actor then
        return "-"
    end
    if actor.side == "hero" then
        local hero = sim:heroById(actor.id)
        return i18n.t("R") .. tostring(actor.rank or "?") .. " " .. (hero and hero.name or i18n.t("hero"))
    end
    local enemy = sim.combat and sim.combat.enemies and sim.combat.enemies[actor.id]
    local enemyDef = enemy and Defs.enemy(enemy.kind)
    return i18n.t("E") .. tostring(actor.rank or "?") .. " " .. (enemyDef and enemyDef.name or i18n.t("enemy"))
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
    { key = "safe_use", label = i18n.t("Safe") },
    { key = "greedy_use", label = i18n.t("Greedy") },
    { key = "repair_use", label = i18n.t("Repair") },
    { key = "leave_alone", label = i18n.t("Leave") },
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
    love.graphics.print(result.title or i18n.t("Curio"), x + 14, y + 12)
    love.graphics.setColor(0.72, 0.76, 0.68, 1)
    love.graphics.printf(result.text or "", x + 14, y + 38, w - 28)
end

local pauseActions = {
    { action = "resume", label = i18n.t("Resume") },
    { action = "save", label = i18n.t("Save") },
    { action = "settings", label = i18n.t("Settings") },
    { action = "quitTitle", label = i18n.t("Quit to Title") },
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
    love.graphics.printf(i18n.t("Paused"), x, y + 24, w, "center")
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
    { action = "cancel", label = i18n.t("Cancel"), enabled = true },
    { action = "confirm", label = i18n.t("Confirm"), enabled = true },
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
    love.graphics.printf(app.confirmDialog.title or i18n.t("Confirm"), x + 18, y + 22, w - 36, "center")
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

function Render.drawUiMicroAnimations(app)
    local drawn = 0
    local hot = app and app.uiHot
    local hotbox = hot and app.ui and app.ui[hot.group] and app.ui[hot.group][hot.index]
    if hotbox then
        drawn = drawn + 1
    end
    local focus = app and app.keyboardFocus
    local focusBox = focus and app.ui and app.ui[focus.group] and app.ui[focus.group][focus.index]
    if focusBox then
        drawn = drawn + 1
    end
    if app and app.uiPulse and not Render.reducedMotion(app) then
        drawn = drawn + 1
    end
    if not (love and love.graphics) then
        return drawn
    end
    if hotbox then
        love.graphics.setColor(0.95, 0.82, 0.28, 0.18)
        love.graphics.rectangle("fill", hotbox.x, hotbox.y, hotbox.w, hotbox.h)
        love.graphics.setColor(0.95, 0.82, 0.28, 0.66)
        love.graphics.rectangle("line", hotbox.x - 2, hotbox.y - 2, hotbox.w + 4, hotbox.h + 4)
    end
    if focusBox then
        love.graphics.setColor(0.98, 0.9, 0.38, 0.9)
        love.graphics.rectangle("line", focusBox.x - 4, focusBox.y - 4, focusBox.w + 8, focusBox.h + 8)
    end
    local pulse = app and app.uiPulse
    if pulse and not Render.reducedMotion(app) then
        local ratio = clamp((pulse.t or 0) / (pulse.duration or 0.22), 0, 1)
        local pad = (1 - ratio) * 10
        local color = { 0.95, 0.82, 0.28 }
        if pulse.kind == "error" then
            color = { 0.9, 0.18, 0.16 }
        elseif pulse.kind == "success" then
            color = { 0.34, 0.78, 0.42 }
        end
        color = Render.accessibleColor(app.settings, color)
        love.graphics.setColor(color[1], color[2], color[3], 0.24 * ratio)
        love.graphics.rectangle("fill", pulse.x - pad, pulse.y - pad, pulse.w + pad * 2, pulse.h + pad * 2)
        love.graphics.setColor(color[1], color[2], color[3], 0.75 * ratio)
        love.graphics.rectangle("line", pulse.x - pad, pulse.y - pad, pulse.w + pad * 2, pulse.h + pad * 2)
    end
    return drawn
end

local gameOverActions = {
    { action = "restart", label = i18n.t("Restart"), enabled = true },
    { action = "title", label = i18n.t("Title"), enabled = true },
    { action = "credits", label = i18n.t("Credits"), enabled = true },
}

local dreadTierNames = { [0] = i18n.t("quiet"), [1] = i18n.t("uneasy"), [2] = i18n.t("strained"), [3] = i18n.t("breaking"), [4] = i18n.t("collapsed") }

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
        reason = campaign.victory and i18n.t("victory") or (campaign.lossReason or i18n.t("lost")),
        route = routeKey,
        routeName = route.name or routeKey,
        routeAlias = route.alias or routeKey,
        routeCondition = route.condition or "",
        routeResult = route.result or "",
        copy = sim and sim.endingScreenCopy and sim:endingScreenCopy(routeKey) or "",
        routes = sim and sim.endingRouteStatus and sim:endingRouteStatus() or {},
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
    love.graphics.printf(summary.won and i18n.t("Campaign Sealed") or i18n.t("Game Over"), 80, 82, width - 160, "left", 0, 1.6, 1.6)
    love.graphics.setColor(0.68, 0.72, 0.66, 1)
    love.graphics.print(summary.reason .. " / " .. summary.routeName .. " / " .. i18n.t("week") .. " " .. summary.week .. " / " .. i18n.t("dread") .. " " .. summary.dread .. "/" .. summary.dreadLimit .. " " .. i18n.t("tier") .. " " .. summary.dreadTier, 82, 138)
    love.graphics.print(i18n.t("renown") .. " " .. summary.renown .. " / " .. i18n.t("bosses") .. " " .. summary.bosses .. "/" .. summary.bossTotal .. " / " .. i18n.t("fallen") .. " " .. summary.deaths, 82, 162)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Party Fate"), 82, 210)
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
    love.graphics.print(i18n.t("Graveyard"), 82, 406)
    for index, death in ipairs(summary.graveyard) do
        if index > 5 then
            break
        end
        love.graphics.setColor(0.62, 0.64, 0.58, 1)
        love.graphics.print((death.name or i18n.t("fallen")) .. "  " .. (death.location or i18n.t("estate")), 82, 432 + (index - 1) * 22)
    end
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Faction State"), width * 0.52, 210)
    for index, faction in ipairs(summary.factions) do
        love.graphics.setColor(0.74, 0.78, 0.72, 1)
        love.graphics.print(faction.name, width * 0.52, 238 + (index - 1) * 28)
        love.graphics.setColor(0.58, 0.66, 0.56, 1)
        love.graphics.print(faction.state .. " (" .. tostring(faction.value) .. ")", width * 0.74, 238 + (index - 1) * 28)
    end
    love.graphics.setColor(0.62, 0.66, 0.58, 1)
    love.graphics.printf((summary.routeCondition or "") .. "\n" .. (summary.routeResult or "") .. "\n\n" .. (summary.copy or ""), width * 0.52, 406, width * 0.38)
    love.graphics.printf(app.gameOverStatus or "", 80, height - 130, width - 160, "center")
    for index, item in ipairs(items) do
        drawGameOverButton(app, item, app.ui.gameOverButtons[index])
    end
    Render.drawUiMicroAnimations(app)
    love.graphics.pop()
    return summary
end

function Render.creditsData()
    return Credits.data(readText("docs/asset-licenses.md") or "")
end

local function creditsLineCount(data)
    return 2 + #((data and data.lines) or {})
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
    love.graphics.printf(i18n.t("Credits"), 80, 82, width - 160, "left", 0, 1.5, 1.5)
    love.graphics.setColor(0.68, 0.72, 0.66, 1)
    love.graphics.print(data.project .. " / " .. i18n.t("playable prototype"), 82, 132)
    local y = 178 - app.creditsScroll * 24
    local function line(text, x, color)
        if y > 142 and y < height - 112 then
            love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
            love.graphics.printf(text, x or 82, y, width - (x or 82) - 92)
        end
        y = y + 24
    end
    local colors = {
        heading = { 0.9, 0.92, 0.86, 1 },
        entry = { 0.76, 0.78, 0.72, 1 },
        source = { 0.56, 0.64, 0.58, 1 },
        note = { 0.5, 0.54, 0.5, 1 },
        spacer = { 0.5, 0.54, 0.5, 1 },
    }
    for _, entry in ipairs(data.lines or {}) do
        line(entry.text or "", 82 + (entry.indent or 0), colors[entry.kind] or colors.note)
    end
    local button = app.ui.creditsButtons[1]
    love.graphics.setColor(0.1, 0.12, 0.11, 1)
    love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
    love.graphics.setColor(0.42, 0.48, 0.36, 1)
    love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
    love.graphics.setColor(0.92, 0.94, 0.88, 1)
    love.graphics.printf(i18n.t("Back"), button.x + 8, button.y + 13, button.w - 16, "center")
    love.graphics.setColor(0.58, 0.62, 0.58, 1)
    love.graphics.printf(i18n.t("scroll") .. " " .. tostring(app.creditsScroll) .. "/" .. tostring(maxScroll), width - 260, height - 72, 180, "right")
    Render.drawUiMicroAnimations(app)
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
        local epitaphKey = death.class and Defs.graveyardEpitaphsFor(death.class) and death.class or location
        local lines = Defs.graveyardEpitaphsFor(epitaphKey) or Defs.graveyardEpitaphsFor("estate") or {}
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
    love.graphics.printf(i18n.t("Journal"), 84, 82, width - 168, "left", 0, 1.5, 1.5)
    drawJournalButton(app, app.ui.journalButtons[1], i18n.t("Documents"), app.journalTab == "documents")
    drawJournalButton(app, app.ui.journalButtons[2], i18n.t("Epitaphs"), app.journalTab == "epitaphs")
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
        love.graphics.printf(app.journalTab == "epitaphs" and i18n.t("no epitaphs") or i18n.t("no documents"), detailX, detailY, detailW)
    end
    local back = app.ui.journalButtons[#app.ui.journalButtons]
    drawJournalButton(app, back, i18n.t("Back"), false)
    love.graphics.setColor(0.58, 0.62, 0.58, 1)
    love.graphics.printf(i18n.t("documents") .. " " .. #summary.documents .. " / " .. i18n.t("epitaphs") .. " " .. #summary.epitaphs, width - 360, height - 72, 280, "right")
    Render.drawUiMicroAnimations(app)
    love.graphics.pop()
    return summary
end

local tutorialSteps = {
    { key = "tactical_onboarding", title = i18n.t("Onboarding Board"), body = i18n.t("Select. Move. Rotate. Watch. End. React."), board = TacticsUICatalog.tutorialBoard("tactical_onboarding"), controls = "A / arrows / [ ] / 1 / E" },
    { key = "ap_cursor", title = i18n.t("AP / Cursor"), body = i18n.t("Select a unit, move the tile cursor, inspect the preview, then commit. Blue rings show reachable AP tiles."), board = TacticsUICatalog.tutorialBoard("movement"), controls = "mouse/D-pad/left stick cursor, Enter/A commit, Space/X inspect" },
    { key = "intent", title = i18n.t("Enemy Intent"), body = i18n.t("Red traces are posted enemy actions. They resolve after End Turn, so move, block, or disrupt them first."), board = TacticsUICatalog.tutorialBoard("intent"), controls = "hover or inspect red tiles before committing AP" },
    { key = "cover", title = i18n.t("Cover / Flank"), body = i18n.t("Cover protects edges, not whole units. Rotate and attack from an exposed edge to make the board answerable."), board = TacticsUICatalog.tutorialBoard("cover_flank"), controls = "[ and ] rotate, inspect cover edges" },
    { key = "push_pull", title = i18n.t("Forced Movement"), body = i18n.t("Push and pull previews show collision paths before resolution. Use them to move threats off declared lines."), board = TacticsUICatalog.tutorialBoard("push_pull"), controls = "attack previews show forced-move path" },
    { key = "objective_pressure", title = i18n.t("Objective Pressure"), body = i18n.t("Gold tiles are route machinery. Losing integrity is the fail state, so blocking damage can beat killing."), board = TacticsUICatalog.tutorialBoard("objectives"), controls = "End Turn only after route machine risk is readable" },
    { key = "rotation", title = i18n.t("Rotation"), body = i18n.t("Rotate the board to read line of sight, cover edges, hidden lanes, and objective risk without changing tile truth."), board = TacticsUICatalog.rotationChecks(), controls = "[ and ] rotate view" },
}

function Render.tutorialSteps()
    return tutorialSteps
end

local function layoutTutorialButtons(app, x, y, w)
    app.ui.tutorialButtons[#app.ui.tutorialButtons + 1] = { x = x + 18, y = y + 180, w = 92, h = 34, action = "skip", enabled = true, index = 1 }
    app.ui.tutorialButtons[#app.ui.tutorialButtons + 1] = { x = x + w - 226, y = y + 180, w = 92, h = 34, action = "prev", enabled = (app.tutorial.index or 1) > 1, index = 2 }
    app.ui.tutorialButtons[#app.ui.tutorialButtons + 1] = { x = x + w - 122, y = y + 180, w = 104, h = 34, action = "next", enabled = true, index = 3 }
end

function Render.drawTutorial(app)
    if not (app and app.tutorial and app.tutorial.active) then
        return
    end
    Render.prepareUi(app)
    app.tutorial.index = clamp(app.tutorial.index or 1, 1, #tutorialSteps)
    local w, h = 520, 236
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
    love.graphics.printf(step.controls or "", x + 18, y + 126, w - 36)
    love.graphics.printf(tostring(app.tutorial.index) .. "/" .. tostring(#tutorialSteps), x + 18, y + 152, w - 36, "right")
    for _, button in ipairs(app.ui.tutorialButtons) do
        love.graphics.setColor(button.enabled and 0.11 or 0.07, button.enabled and 0.13 or 0.07, button.enabled and 0.11 or 0.07, 1)
        love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
        love.graphics.setColor(button.enabled and 0.44 or 0.22, button.enabled and 0.5 or 0.22, button.enabled and 0.34 or 0.22, 1)
        love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
        love.graphics.setColor(button.enabled and 0.9 or 0.4, button.enabled and 0.92 or 0.4, button.enabled and 0.84 or 0.4, 1)
        love.graphics.printf(button.action == "next" and (app.tutorial.index == #tutorialSteps and i18n.t("Done") or i18n.t("Next")) or (button.action == "prev" and i18n.t("Back") or i18n.t("Skip")), button.x + 6, button.y + 10, button.w - 12, "center")
    end
    return tutorialSteps
end

function Render.drawToasts(app)
    local toasts = (app and app.toasts) or {}
    if #toasts == 0 then
        return 0
    end
    if not (love and love.graphics) then
        return #toasts
    end
    local width = love.graphics.getWidth()
    local x = width - 338
    for index, toast in ipairs(toasts) do
        local y = 106 + (index - 1) * 70
        panel(x, y, 306, 58, 0.96)
        love.graphics.setColor(0.9, 0.82, 0.48, 1)
        love.graphics.print(toast.title or i18n.t("Unlocked"), x + 12, y + 10)
        love.graphics.setColor(0.7, 0.74, 0.68, 1)
        love.graphics.printf(toast.text or "", x + 12, y + 32, 282)
    end
    return #toasts
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
    drawLedgerSweep(width, height, Render.reducedMotion(app) and 0 or (app.titleTime or 0))
    love.graphics.setColor(0.92, 0.9, 0.8, 1)
    love.graphics.printf(i18n.t("THOTH"), 64, math.max(86, height * 0.28), math.min(520, width - 128), "left", 0, 3.2, 3.2)
    love.graphics.setColor(0.62, 0.68, 0.62, 1)
    love.graphics.printf(i18n.t("account the dead"), 70, math.max(164, height * 0.28 + 76), math.min(520, width - 128), "left")
    for index, item in ipairs(items) do
        drawTitleButton(app, item, app.ui.titleButtons[index])
    end
    love.graphics.setColor(0.58, 0.62, 0.58, 1)
    local status = app.titleStatus or app.saveStatus or i18n.t("ready")
    love.graphics.printf(status, 64, height - 54, width - 128, "left")
    love.graphics.printf(i18n.t("keyboard"), 64, height - 32, width - 128, "right")
    Render.drawUiMicroAnimations(app)
    love.graphics.pop()
    return items
end

local function layoutSquadLoadoutButtons(app, width, height)
    local selection = app.squadSelect or SquadLoadout.defaultSelection()
    app.squadSelect = selection
    local buttons = app.ui.squadLoadoutButtons
    local x = math.max(48, math.floor(width * 0.08))
    local y = math.max(112, math.floor(height * 0.16))
    local rowW = math.min(720, width - x * 2)
    local rowH = clamp(math.floor((height - y - 154) / math.max(1, #selection.classes)) - 8, 42, 62)
    for index in ipairs(selection.classes) do
        buttons[#buttons + 1] = { x = x, y = y + (index - 1) * (rowH + 8), w = rowW, h = rowH, action = "toggle", index = index }
    end
    local buttonY = height - 82
    buttons[#buttons + 1] = { x = x, y = buttonY, w = 176, h = 42, action = "back" }
    buttons[#buttons + 1] = { x = x + rowW - 212, y = buttonY, w = 212, h = 42, action = "start", enabled = SquadLoadout.ready(selection) }
    return buttons
end

function Render.squadLoadoutSummary(app)
    return SquadLoadout.summary((app and app.squadSelect) or SquadLoadout.defaultSelection())
end

local function loadoutText(entry)
    local parts = {}
    for _, loadoutId in ipairs(entry.loadoutIds or {}) do
        parts[#parts + 1] = tostring(loadoutId)
    end
    return table.concat(parts, " / ")
end

local function drawSquadLoadoutRow(app, entry, button)
    local active = app.squadSelect and app.squadSelect.focus == entry.index
    local selected = entry.selected == true
    love.graphics.setColor(selected and 0.11 or 0.07, selected and 0.14 or 0.08, selected and 0.13 or 0.08, 0.94)
    love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
    love.graphics.setColor(active and 0.84 or 0.28, active and 0.68 or 0.34, active and 0.34 or 0.28, selected and 1 or 0.65)
    love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
    love.graphics.setColor(selected and 0.92 or 0.46, selected and 0.92 or 0.46, selected and 0.84 or 0.46, 1)
    love.graphics.printf((selected and "[x] " or "[ ] ") .. tostring(entry.className), button.x + 12, button.y + 8, 220, "left")
    love.graphics.setColor(0.72, 0.78, 0.7, 1)
    love.graphics.printf(tostring(entry.routeRole or "-"), button.x + 230, button.y + 8, button.w - 242, "left")
    love.graphics.setColor(0.58, 0.64, 0.58, 1)
    love.graphics.printf(loadoutText(entry), button.x + 230, button.y + 30, button.w - 242, "left")
end

local function drawSquadLoadoutCommand(app, button, label, enabled)
    love.graphics.setColor(enabled and 0.12 or 0.07, enabled and 0.14 or 0.08, enabled and 0.12 or 0.08, enabled and 0.96 or 0.58)
    love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
    love.graphics.setColor(enabled and 0.72 or 0.28, enabled and 0.62 or 0.3, enabled and 0.34 or 0.26, 1)
    love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
    love.graphics.setColor(enabled and 0.92 or 0.44, enabled and 0.92 or 0.44, enabled and 0.84 or 0.44, 1)
    love.graphics.printf(label, button.x + 12, button.y + 13, button.w - 24, "center")
end

function Render.drawSquadLoadout(sim, app)
    Render.prepareUi(app)
    layoutSquadLoadoutButtons(app, 1280, 720)
    if not (love and love.graphics) then
        return Render.squadLoadoutSummary(app)
    end
    local width, height = love.graphics.getDimensions()
    love.graphics.clear(0.04, 0.043, 0.047, 1)
    Render.drawWorld(sim, app)
    clearList(app.ui.squadLoadoutButtons)
    local buttons = layoutSquadLoadoutButtons(app, width, height)
    local summary = Render.squadLoadoutSummary(app)
    love.graphics.push("all")
    love.graphics.setDepthMode()
    love.graphics.setColor(0.012, 0.014, 0.016, 0.72)
    love.graphics.rectangle("fill", 0, 0, width, height)
    panel(48, 48, width - 96, height - 96, 0.92)
    love.graphics.setColor(0.92, 0.9, 0.8, 1)
    love.graphics.print("Squad Loadout", 72, 72)
    love.graphics.setColor(0.62, 0.68, 0.62, 1)
    love.graphics.printf(tostring(summary.missionLabel or "mission 1") .. "  " .. tostring(summary.selected) .. "/" .. tostring(summary.required) .. "  " .. tostring(summary.duplicateLabel or "duplicates off"), 72, 96, width - 144, "left")
    for index, entry in ipairs(app.squadSelect.classes or {}) do
        drawSquadLoadoutRow(app, entry, buttons[index])
    end
    local back = buttons[#buttons - 1]
    local start = buttons[#buttons]
    drawSquadLoadoutCommand(app, back, "Back", true)
    drawSquadLoadoutCommand(app, start, "Start Mission", start.enabled ~= false)
    love.graphics.setColor(0.58, 0.62, 0.58, 1)
    love.graphics.printf(tostring(app.status or summary.duplicatePolicy), 72, height - 34, width - 144, "left")
    Render.drawUiMicroAnimations(app)
    love.graphics.pop()
    return summary
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
    local value = i18n.t(Settings.valueText(app.settings, control))
    if app.captureBinding == control.binding then
        value = i18n.t("press key")
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
    love.graphics.print(i18n.t("Settings"), 72, 72)
    local controls = Settings.controls()
    app.settingsFocus = clamp(app.settingsFocus or 1, 1, #controls)
    local gap = 24
    local rowW = math.floor((width - 144 - gap) / 2)
    local rowY = 126
    local maxRows = math.ceil(#controls / 2)
    for index, control in ipairs(controls) do
        control.index = index
        local column = math.floor((index - 1) / maxRows)
        local row = (index - 1) % maxRows
        local rowX = 72 + column * (rowW + gap)
        local y = rowY + row * 34
        if y > height - 126 then
            break
        end
        local active = app.settingsFocus == index
        love.graphics.setColor(active and 0.16 or 0.08, active and 0.18 or 0.09, active and 0.15 or 0.09, active and 0.9 or 0.55)
        love.graphics.rectangle("fill", rowX - 8, y - 8, rowW + 16, 30)
        love.graphics.setColor(active and 0.92 or 0.72, active and 0.9 or 0.76, active and 0.8 or 0.7, 1)
        love.graphics.printf(i18n.t(control.label), rowX, y, 170, "left")
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
            love.graphics.printf(i18n.t("Back"), rowX + 188, y + 3, 164, "center")
        end
    end
    love.graphics.setColor(0.58, 0.62, 0.58, 1)
    love.graphics.printf(i18n.t(app.settingsStatus or ""), 72, height - 82, width - 144, "left")
    Render.drawUiMicroAnimations(app)
    love.graphics.pop()
end

local function checklistText(group)
    local parts = { i18n.t(group.title or "") }
    for _, item in ipairs(group.items) do
        parts[#parts + 1] = (item.done and i18n.t("[x]") or i18n.t("[ ]")) .. i18n.t(item.label)
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
        love.graphics.print(hero.rank .. " " .. hero.name .. " / " .. i18n.t(hero.class) .. " " .. i18n.t("L") .. (hero.level or 1), x + 6, rowY + 4)
        drawMeter(x + 6, rowY + 20, w - 78, 6, (hero.hp or 0) / math.max(1, hero.maxHp or 1), { 0.34, 0.68, 0.42, 1 })
        drawMeter(x + 6, rowY + 30, w - 78, 6, (hero.stress or 0) / 100, { 0.78, 0.58, 0.26, 1 })
        love.graphics.setColor(0.74, 0.82, 0.74, 1)
        love.graphics.print(hero.hp .. "/" .. hero.maxHp, x + w - 66, rowY + 17)
        love.graphics.print(i18n.t("s") .. hero.stress, x + w - 66, rowY + 28)
        if hero.deathsDoor then
            love.graphics.setColor(0.94, 0.34, 0.28, 1)
            love.graphics.print(i18n.t("door"), x + w - 54, rowY + 19)
        elseif hero.affliction then
            love.graphics.setColor(0.9, 0.46, 0.42, 1)
            love.graphics.print(hero.affliction, x + w - 74, rowY + 19)
        elseif hero.virtue then
            love.graphics.setColor(0.56, 0.82, 0.66, 1)
            love.graphics.print(hero.virtue, x + w - 64, rowY + 19)
        elseif hero.diseases and #hero.diseases > 0 then
            love.graphics.setColor(0.68, 0.72, 0.46, 1)
            love.graphics.print(i18n.t("ill"), x + w - 34, rowY + 19)
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
    { key = "all", label = i18n.t("all") },
    { key = "party", label = i18n.t("party") },
    { key = "recovering", label = i18n.t("rest") },
    { key = "stressed", label = i18n.t("stress") },
}

local rosterSorts = {
    { key = "rank", label = i18n.t("rank") },
    { key = "level", label = i18n.t("lvl") },
    { key = "stress", label = i18n.t("str") },
    { key = "name", label = i18n.t("name") },
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
    love.graphics.print(i18n.t("Roster"), x, y)
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
        local suffix = (rank and (" " .. i18n.t("R") .. rank) or "") .. " " .. i18n.t("S") .. (hero.stress or 0)
        love.graphics.setColor(active and 0.2 or 0.11, active and 0.23 or 0.13, active and 0.18 or 0.13, 1)
        love.graphics.rectangle("fill", x, rowY, w, 28)
        love.graphics.setColor(active and 0.72 or 0.32, active and 0.62 or 0.34, active and 0.32 or 0.28, 1)
        love.graphics.rectangle("line", x, rowY, w, 28)
        love.graphics.setColor(hero.alive and 0.9 or 0.48, hero.alive and 0.92 or 0.44, hero.alive and 0.86 or 0.42, 1)
        love.graphics.printf(hero.name .. " / " .. i18n.t(class.name) .. " " .. i18n.t("L") .. (hero.level or 1) .. suffix, x + 4, rowY + 6, w - 8, "left")
        app.ui.rosterButtons[#app.ui.rosterButtons + 1] = { x = x, y = rowY, w = w, h = 28, heroId = hero.id }
    end
    return selected
end

local function drawPartyFormation(sim, app, x, y, w)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Party Formation"), x, y)
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
        love.graphics.printf(i18n.t("R") .. rank, sx + 4, sy + 6, slotW - 8, "center")
        love.graphics.setColor(0.68, 0.74, 0.68, 1)
        love.graphics.printf(hero and hero.name or i18n.t("empty"), sx + 4, sy + 28, slotW - 8, "center")
        app.ui.partyRankSlots[#app.ui.partyRankSlots + 1] = { x = sx, y = sy, w = slotW, h = 52, rank = rank }
    end
    if app.dragHeroId then
        local hero = sim:heroById(app.dragHeroId)
        love.graphics.setColor(0.86, 0.78, 0.44, 1)
        love.graphics.printf(i18n.t("assigning") .. " " .. (hero and hero.name or i18n.t("hero")), x, y + 84, w, "left")
    end
end

local function drawSelectedEstateHero(sim, app, hero, x, y, w)
    if not hero then
        return
    end
    local class = Defs.heroClass(hero.class)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(hero.name .. " / " .. i18n.t(class.name), x, y)
    love.graphics.setColor(0.74, 0.78, 0.72, 1)
    love.graphics.printf(i18n.t("hp") .. " " .. hero.hp .. "/" .. sim:maxHp(hero) .. " " .. i18n.t("stress") .. " " .. hero.stress .. " " .. i18n.t("weapon") .. " " .. (hero.weapon or 0) .. " " .. i18n.t("armor") .. " " .. (hero.armor or 0), x, y + 18, w)
    local nextXp = (hero.level or 1) < 5 and ((hero.level or 1) * 2) or nil
    love.graphics.printf(i18n.t("rank") .. " " .. (sim:heroRank(hero.id) or "-") .. " " .. i18n.t("resolve") .. " " .. sim:heroResolve(hero) .. " " .. i18n.t("xp") .. " " .. (hero.xp or 0) .. (nextXp and ("/" .. nextXp) or (" " .. i18n.t("max"))), x, y + 36, w)
    local actionY = y + 62
    for index, skillKey in ipairs(hero.skills or {}) do
        addEstateAction(app, i18n.t("train") .. " " .. index, x + ((index - 1) % 3) * 82, actionY + math.floor((index - 1) / 3) * 34, 76, { action = "upgradeSkill", heroId = hero.id, skillKey = skillKey, enabled = true })
    end
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Equipment"), x, actionY + 42)
    addEstateAction(app, i18n.t("weapon L") .. (hero.weapon or 0), x, actionY + 62, 76, { action = "upgradeGear", heroId = hero.id, kind = "weapon", enabled = true })
    addEstateAction(app, i18n.t("armor L") .. (hero.armor or 0), x + 82, actionY + 62, 76, { action = "upgradeGear", heroId = hero.id, kind = "armor", enabled = true })
    addEstateAction(app, i18n.t("dismiss"), x + 164, actionY + 62, 76, { action = "dismissHero", heroId = hero.id, enabled = not sim:heroRank(hero.id) and sim:livingRosterCount() > 4 and (hero.recovering or 0) <= 0 })
    for index, activityKey in ipairs(Defs.estateActivityOrder) do
        local activity = Defs.estateActivity(activityKey)
        addEstateAction(app, (activity.short or activity.name) .. " " .. activity.cost, x + ((index - 1) % 3) * 82, actionY + 96 + math.floor((index - 1) / 3) * 34, 76, { action = "recoverHero", heroId = hero.id, activityKey = activityKey, enabled = (hero.recovering or 0) <= 0 })
    end
    local trinketY = actionY + 140
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Trinkets"), x, trinketY)
    for slot = 1, 2 do
        local key = hero.trinkets and hero.trinkets[slot]
        local trinket = key and Defs.trinket(key)
        local label = key and ((trinket and (trinket.short or trinket.name)) or key) or (i18n.t("slot") .. " " .. slot)
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
        love.graphics.print(i18n.t("Set Bonus"), x, trinketY + 92)
        love.graphics.setColor(0.68, 0.72, 0.66, 1)
        for index = 1, math.min(3, #tooltipLines) do
            love.graphics.printf(tooltipLines[index], x, trinketY + 108 + (index - 1) * 16, w)
        end
    end
    local treatY = trinketY + 126
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Treatment"), x, treatY)
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
        addEstateAction(app, i18n.t("rank") .. " " .. rank, x + (rank - 1) * 62, rankY, 56, { action = "assignParty", heroId = hero.id, rank = rank, enabled = true })
    end
end

local function drawJournalPanel(sim, x, y, w)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Journal"), x, y)
    love.graphics.setColor(0.7, 0.74, 0.68, 1)
    local entries = sim:journalEntries()
    if #entries == 0 then
        love.graphics.print(i18n.t("no documents"), x, y + 20)
        return
    end
    local first = math.max(1, #entries - 2)
    for index = first, #entries do
        local entry = entries[index]
        love.graphics.printf(entry.title .. " - " .. entry.abstract, x, y + 20 + (index - first) * 18, w)
    end
end

local cueSubtitleLabels = {
    camp = "camp",
    combat = "combat",
    danger = "danger",
    dialogue_chirp_high = "dialogue",
    dialogue_chirp_low = "dialogue",
    estate = "estate",
    footstep_ash = "footstep",
    footstep_stone = "footstep",
    footstep_wet = "footstep",
    hit_affliction = "affliction hit",
    hit_blunt = "blunt hit",
    hit_burn = "burn hit",
    hit_slash = "slash hit",
    hit_stress = "stress hit",
    loot = "loot",
    provision = "provision",
    recovery = "recovery",
    travel = "travel",
    victory = "victory",
}

function Render.audioSubtitle(app)
    if not (app and app.settings and app.settings.subtitles and app.eventFlash) then
        return nil
    end
    local cue = app.eventFlash.cue
    local label = i18n.t(cueSubtitleLabels[cue] or tostring(cue or i18n.t("audio")):gsub("_", " "))
    local status = app.eventFlash.status or app.eventFlash.message
    if status and status ~= "" then
        return label .. ": " .. i18n.t(tostring(status))
    end
    return label
end

function Render.drawAudioSubtitle(app)
    local text = Render.audioSubtitle(app)
    if not text then
        return nil
    end
    if not (love and love.graphics) then
        return text
    end
    local width, height = love.graphics.getDimensions()
    local w = math.min(width - 48, 560)
    local x = (width - w) / 2
    local y = height - 46
    love.graphics.setColor(0.02, 0.024, 0.026, 0.86)
    love.graphics.rectangle("fill", x, y, w, 30)
    love.graphics.setColor(0.88, 0.9, 0.84, 1)
    love.graphics.printf(text, x + 12, y + 8, w - 24, "center")
    return text
end

local function tacticalSummary(app)
    local runtime = app and app.tactics
    if runtime and runtime.summary then
        local cursor = runtime.cursor or {}
        local key = table.concat({
            "summary",
            Render.tacticalVisibilityCacheKey(runtime.state) or "",
            tostring(runtime.selectedUnitId or ""),
            tostring(cursor.x or ""),
            tostring(cursor.y or ""),
            tostring(runtime.turn or ""),
            tostring(runtime.routeIndex or ""),
            tostring(runtime.message or ""),
            tostring(runtime.complete == true),
            tostring(runtime.routeComplete == true),
            tostring(runtime.failed == true),
            tostring(runtime.aiDebug == true),
            tostring(runtime.aiDoctrine and runtime.aiDoctrine.id or ""),
            tostring(runtime.lastEnemyDoctrine and runtime.lastEnemyDoctrine.id or ""),
            tostring(runtime.state and runtime.state.revision and runtime.state:revision("intent") or ""),
        }, "|")
        local cache = app.tacticalSummaryCache
        if cache and cache.runtime == runtime and cache.key == key then
            return cache.summary
        end
        local summary = runtime:summary()
        app.tacticalSummaryCache = { runtime = runtime, key = key, summary = summary }
        return summary
    end
    return app and app.tacticalSummary or nil
end

local function rectsOverlap(a, b)
    return a and b and a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function Render.tacticalHudLayout(width, height, squadSlots)
    width = math.max(1, tonumber(width) or (love and love.graphics and love.graphics.getWidth()) or 1280)
    height = math.max(1, tonumber(height) or (love and love.graphics and love.graphics.getHeight()) or 720)
    local slots = math.max(1, squadSlots or 6)
    local margin = 16
    local topH = height < 760 and 82 or 88
    local bottomH = height < 760 and 82 or 92
    local sideW = clamp(math.floor(width * (width < 1120 and 0.23 or 0.18)), width < 1120 and 244 or 272, width < 1120 and 296 or 336)
    local board = {
        x = margin,
        y = topH + margin,
        w = math.max(360, width - sideW - margin * 3),
        h = math.max(260, height - topH - bottomH - margin * 3),
    }
    local enemySlots = height < 760 and 2 or 4
    local enemyRowH = height < 760 and 38 or 52
    local threatH = 34 + enemyRowH * enemySlots
    local intentH = height < 760 and 86 or clamp(math.floor(board.h * 0.22), 92, 180)
    local rowH = clamp(math.floor((board.h - threatH - intentH - 24 - 34) / slots), 38, 74)
    local squadH = 34 + rowH * slots
    local threats = { x = width - sideW - margin, y = board.y, w = sideW, h = threatH }
    local squad = { x = threats.x, y = threats.y + threats.h + 12, w = sideW, h = squadH }
    local intent = { x = squad.x, y = squad.y + squad.h + 12, w = sideW, h = math.max(0, board.y + board.h - (squad.y + squad.h + 12)) }
    return {
        topLeft = { x = margin, y = 14, w = math.min(520, board.w), h = topH - 14 },
        objective = { x = squad.x, y = 14, w = sideW, h = topH - 14 },
        board = board,
        threats = threats,
        squad = squad,
        intent = intent,
        intentLegend = { x = board.x, y = height - bottomH - 28, w = board.w, h = 34 },
        action = { x = board.x, y = height - bottomH + 12, w = board.w, h = bottomH - 24 },
        squadSlots = slots,
        rowH = rowH,
        enemySlots = enemySlots,
        enemyRowH = enemyRowH,
        portraitSize = clamp(rowH - 12, 30, 52),
        enemyPortraitSize = clamp(enemyRowH - 12, 30, 42),
    }
end

function Render.tacticalHudLayoutAudit(width, height, squadSlots)
    local layout = Render.tacticalHudLayout(width, height, squadSlots)
    local overlaps = {}
    for _, entry in ipairs({
        { id = "top", rect = layout.topLeft },
        { id = "objective", rect = layout.objective },
        { id = "threats", rect = layout.threats },
        { id = "squad", rect = layout.squad },
        { id = "intent", rect = layout.intent },
        { id = "intent_legend", rect = layout.intentLegend },
        { id = "action", rect = layout.action },
    }) do
        if entry.rect.h > 0 and rectsOverlap(layout.board, entry.rect) then
            overlaps[#overlaps + 1] = entry.id
        end
    end
    local visiblePortraits = math.min(layout.squadSlots, math.floor(math.max(0, layout.squad.h - 34) / layout.rowH))
    return {
        ok = #overlaps == 0 and visiblePortraits >= (squadSlots or 6),
        layout = layout,
        overlaps = overlaps,
        visiblePortraits = visiblePortraits,
        apPools = visiblePortraits,
        selectionRows = visiblePortraits,
    }
end

function Render.tacticalSquadHudRows(summary, requiredSlots)
    local players = (summary and summary.players) or {}
    local slots = math.max(requiredSlots or #players, #players)
    local rows = {}
    for index = 1, slots do
        local unit = players[index]
        local ap = unit and (unit.ap or 0) or 0
        rows[#rows + 1] = {
            slot = index,
            id = unit and unit.id or "-",
            class = unit and unit.class or nil,
            className = unit and unit.className or nil,
            name = unit and unit.name or nil,
            quirks = unit and unit.quirks or nil,
            stress = unit and unit.stress or 0,
            defense = unit and unit.defense or nil,
            hp = unit and unit.hp or 0,
            maxHp = unit and unit.maxHp or 0,
            ap = ap,
            maxAp = unit and (unit.maxAp or math.max(ap, 3)) or 0,
            x = unit and unit.x or nil,
            y = unit and unit.y or nil,
            selected = unit and unit.selected == true or false,
            empty = unit == nil,
        }
    end
    return rows
end

local intentIcons = {
    attack = "ATT",
    move = "MOV",
    guard = "GRD",
    summon = "SUM",
    repair = "REP",
    destroy = "BRK",
    buff = "BUF",
    debuff = "DEB",
    flee = "RUN",
    redacted = "?",
}

local function tacticalIntentIcon(category, hidden)
    if hidden then
        return "?"
    end
    return intentIcons[category or ""] or string.upper(string.sub(tostring(category or "INT"), 1, 3))
end

function Render.tacticalEnemyHudRows(appOrSummary, requiredSlots)
    local summary = appOrSummary and appOrSummary.tactics and tacticalSummary(appOrSummary) or appOrSummary
    local enemies = (summary and summary.enemies) or {}
    local slots = math.max(requiredSlots or #enemies, #enemies)
    local rows = {}
    for index = 1, slots do
        local enemy = enemies[index]
        local category = enemy and enemy.intentCategory or nil
        local hidden = enemy and enemy.intentHidden == true
        local target = enemy and enemy.targetTiles and enemy.targetTiles[1]
        rows[#rows + 1] = {
            slot = index,
            id = enemy and enemy.id or "-",
            kind = enemy and enemy.kind or nil,
            hp = enemy and enemy.hp or 0,
            maxHp = enemy and enemy.maxHp or enemy and enemy.hp or 0,
            x = enemy and enemy.x or nil,
            y = enemy and enemy.y or nil,
            intentCategory = category,
            intentLabel = enemy and enemy.intentLabel or "-",
            intentDamage = enemy and enemy.intentDamage or 0,
            intentIcon = tacticalIntentIcon(category, hidden),
            hidden = hidden,
            targetTiles = enemy and copyValue(enemy.targetTiles or {}) or {},
            targetX = target and target.x or nil,
            targetY = target and target.y or nil,
            aiDebug = enemy and enemy.aiDebug or nil,
            breakGauge = enemy and enemy.breakGauge or 0,
            breakMax = enemy and enemy.breakMax or nil,
            broken = enemy and enemy.broken == true,
            empty = enemy == nil,
        }
    end
    return rows
end

function Render.tacticalTileInspectorSummary(app)
    local runtime = app and app.tactics
    local tactics = runtime and runtime.state
    if not tactics then
        return nil
    end
    local tile = app.tacticalHover or runtime.cursor
    if not (tile and tactics:inBounds(tile.x, tile.y)) then
        return nil
    end
    local summary = TacticsUICatalog.tileInspectorSummary(tactics, tile.x, tile.y, {
        rotation = app.viewRotation or 0,
        unitId = runtime.selectedUnitId,
        side = "player",
        intentOptions = { side = "player" },
    })
    if runtime.aiDebug and runtime.aiDebugPlans then
        summary.aiDebug = {}
        for unitId, debug in pairs(runtime.aiDebugPlans) do
            local intent = tactics.intents and tactics.intents[unitId]
            local match = false
            if debug.chosen and debug.chosen.x == tile.x and debug.chosen.y == tile.y then
                match = true
            end
            if debug.inputs and debug.inputs.targetX == tile.x and debug.inputs.targetY == tile.y then
                match = true
            end
            for _, pathTile in ipairs((intent and intent.path) or {}) do
                if pathTile.x == tile.x and pathTile.y == tile.y then
                    match = true
                    break
                end
            end
            if match then
                summary.aiDebug[#summary.aiDebug + 1] = debug
            end
        end
    end
    summary.source = app.tacticalHover and "hover" or "cursor"
    return summary
end

local function joinWords(values)
    local text = {}
    for _, value in ipairs(values or {}) do
        if value ~= nil and value ~= "" then
            text[#text + 1] = tostring(value)
        end
    end
    return table.concat(text, " ")
end

local function signedNumber(value)
    if value == nil then
        return nil
    end
    return value > 0 and ("+" .. tostring(value)) or tostring(value)
end

local function aiDebugLine(debug)
    local chosen = debug and debug.chosen or {}
    local terms = {}
    for index, term in ipairs((debug and debug.scoreBreakdown) or {}) do
        if index > 3 then
            break
        end
        terms[#terms + 1] = tostring(term.name) .. signedNumber(math.floor((term.value or 0) + 0.5))
    end
    return joinWords({
        "AI",
        debug and debug.doctrine and debug.doctrine.id or nil,
        debug and debug.role or nil,
        chosen.tactic,
        "score " .. tostring(math.floor((chosen.score or 0) + 0.5)),
        chosen.x and ("@" .. tostring(chosen.x) .. "," .. tostring(chosen.y)) or nil,
        #terms > 0 and table.concat(terms, " ") or nil,
    })
end

function Render.tacticalTileInspectorLines(summary)
    if not summary then
        return { "tile -" }
    end
    local lines = {}
    local terrain = summary.terrain or {}
    lines[#lines + 1] = joinWords({ "terrain", terrain.kind or "floor", terrain.material, terrain.state, terrain.terrainType and ("type " .. terrain.terrainType) or nil, "h" .. tostring(terrain.height or 0), terrain.moveCost and ("cost +" .. tostring(terrain.moveCost)) or nil, terrain.occupant and ("unit " .. terrain.occupant) or nil })
    lines[#lines + 1] = "tags " .. (#(terrain.tags or {}) > 0 and table.concat(terrain.tags, " ") or "-")
    local cover = {}
    for _, edge in ipairs(summary.cover or {}) do
        cover[#cover + 1] = edge.direction .. " " .. edge.cover
    end
    lines[#lines + 1] = "cover " .. (#cover > 0 and table.concat(cover, ", ") or "-")
    local hazard = summary.hazards or {}
    lines[#lines + 1] = joinWords({ "hazard", hazard.kind or "-", hazard.active ~= nil and ("active " .. tostring(hazard.active)) or nil, hazard.damage and ("dmg " .. hazard.damage) or nil, hazard.countdown and ("timer " .. hazard.countdown) or nil })
    local hp = summary.destructibleHp or {}
    lines[#lines + 1] = joinWords({ "terrain HP", hp.hp or "-", hp.destructible and "destructible" or nil, hp.movement and "move-block" or nil, hp.los and "los-block" or nil })
    local vision = {}
    for _, source in ipairs(summary.visionSources or {}) do
        vision[#vision + 1] = source.unit .. "@" .. tostring(source.x) .. "," .. tostring(source.y)
    end
    lines[#lines + 1] = "vision " .. (#vision > 0 and table.concat(vision, " ") or "-")
    local los = summary.los or {}
    lines[#lines + 1] = joinWords({ "LoS", los.from and los.from.unit or "-", los.visible and "visible" or "blocked", los.heightDelta and ("h" .. signedNumber(los.heightDelta)) or nil, los.vantage, los.effectiveCover and ("cover " .. los.effectiveCover) or nil, los.damageReduction and los.damageReduction > 0 and ("dr " .. tostring(los.damageReduction)) or nil, los.flanked and "flanked" or nil, los.coverIgnoredByHeight and "height-breaks-cover" or nil, los.obscured and "obscured" or nil })
    local traces = {}
    for _, trace in ipairs(summary.intentTraces or {}) do
        traces[#traces + 1] = joinWords({ trace.unit, trace.role, trace.category, trace.damage and ("dmg " .. trace.damage) or nil, trace.countdown and ("timer " .. trace.countdown) or nil })
    end
    lines[#lines + 1] = "intent " .. (#traces > 0 and table.concat(traces, "; ") or "-")
    for _, debug in ipairs(summary.aiDebug or {}) do
        lines[#lines + 1] = aiDebugLine(debug)
    end
    return lines
end

function Render.tacticalIntentLegendEntries(app)
    local runtime = app and app.tactics
    local tactics = runtime and runtime.state
    local access = Render.tacticalAccessibility(app)
    if not tactics then
        return {}
    end
    local key = table.concat({
        "intentLegend",
        Render.tacticalVisibilityCacheKey(tactics) or "",
        tostring(access.intentIconScale or ""),
        tostring(access.intentText == true),
    }, "|")
    local cache = app.tacticalIntentLegendCache
    if cache and cache.runtime == runtime and cache.key == key then
        return cache.entries
    end
    local entries = {}
    for _, unitId in ipairs(sortedMapKeys(tactics and tactics.intents or {})) do
        local unit = tactics and tactics:unit(unitId)
        if unit and unit.side == "enemy" and unit.alive and not unit.evacuated then
            local preview = tactics:intentPreview(unitId, { side = "player" })
            local category = preview and (preview.category or preview.intentType or preview.mode) or "intent"
            local label = preview and (preview.label or preview.effect or category) or category
            local sourceTile = preview and preview.sourceTile
            if not (sourceTile and sourceTile.x and sourceTile.y) then
                sourceTile = { x = unit.x, y = unit.y }
            end
            entries[#entries + 1] = {
                unit = unitId,
                icon = string.upper(string.sub(category or "INT", 1, 3)),
                category = category,
                label = label,
                iconScale = access.intentIconScale,
                text = access.intentText and (tostring(category) .. " " .. tostring(label)) or nil,
                hidden = preview and (preview.hiddenByVision == true or preview.categoryOnly == true) or false,
                targetTiles = copyValue((preview and preview.targetTiles) or {}),
                sourceTile = copyValue(sourceTile),
            }
        end
    end
    app.tacticalIntentLegendCache = { runtime = runtime, key = key, entries = entries }
    return entries
end

function Render.tacticalActionBar(app)
    if app and app.tactics and app.tactics.actionBar then
        return app.tactics:actionBar(app.tacticalHover)
    end
    return {}
end

local function shortText(value, limit)
    local text = tostring(value or "-")
    if #text <= limit then
        return text
    end
    return string.sub(text, 1, math.max(1, limit - 1)) .. "."
end

local function drawTacticalPortrait(row, x, y, size)
    love.graphics.setColor(row.selected and 0.19 or 0.1, row.selected and 0.24 or 0.13, row.selected and 0.14 or 0.12, 1)
    love.graphics.rectangle("fill", x, y, size, size)
    love.graphics.setColor(row.selected and 0.9 or 0.38, row.selected and 0.82 or 0.44, row.selected and 0.36 or 0.38, 1)
    love.graphics.rectangle("line", x, y, size, size)
    local quad, frameW, frameH = nil, nil, nil
    if not row.empty then
        quad, frameW, frameH = atlasFrameQuad(heroFrame({ classId = row.class, class = row.className }))
    end
    if quad and state.assets.spriteAtlas then
        local scale = math.min((size - 8) / frameW, (size - 8) / frameH)
        love.graphics.setColor(1, 1, 1, row.selected and 1 or 0.88)
        love.graphics.draw(state.assets.spriteAtlas, quad, x + size * 0.5, y + size * 0.5, 0, scale, scale, frameW * 0.5, frameH * 0.5)
    else
        love.graphics.setColor(row.empty and 0.34 or 0.82, row.empty and 0.36 or 0.84, row.empty and 0.34 or 0.74, 1)
        love.graphics.printf(string.upper(string.sub(row.id or "-", 1, 2)), x, y + size * 0.36, size, "center")
    end
end

local function drawTacticalEnemyPortrait(row, x, y, size)
    love.graphics.setColor(row.empty and 0.08 or 0.14, row.empty and 0.08 or 0.09, row.empty and 0.08 or 0.08, 1)
    love.graphics.rectangle("fill", x, y, size, size)
    love.graphics.setColor(row.hidden and 0.46 or 0.68, row.hidden and 0.42 or 0.28, row.hidden and 0.36 or 0.24, 1)
    love.graphics.rectangle("line", x, y, size, size)
    local quad, frameW, frameH = nil, nil, nil
    if not row.empty then
        quad, frameW, frameH = atlasFrameQuad(enemyFrame("threat", row.kind))
    end
    if quad and state.assets.spriteAtlas then
        local scale = math.min((size - 8) / frameW, (size - 8) / frameH)
        love.graphics.setColor(1, 1, 1, row.hidden and 0.62 or 0.92)
        love.graphics.draw(state.assets.spriteAtlas, quad, x + size * 0.5, y + size * 0.5, 0, scale, scale, frameW * 0.5, frameH * 0.5)
    else
        love.graphics.setColor(row.empty and 0.34 or 0.94, row.empty and 0.3 or 0.42, row.empty and 0.3 or 0.32, 1)
        love.graphics.printf(string.upper(string.sub(row.id or "-", 1, 2)), x, y + size * 0.36, size, "center")
    end
end

local function drawApPool(x, y, w, ap, maxAp)
    local pips = math.max(1, math.min(maxAp or 0, 6))
    local gap = 3
    local pipW = math.max(8, math.floor((w - gap * (pips - 1)) / pips))
    for index = 1, pips do
        local px = x + (index - 1) * (pipW + gap)
        love.graphics.setColor(index <= (ap or 0) and 0.86 or 0.12, index <= (ap or 0) and 0.72 or 0.14, index <= (ap or 0) and 0.28 or 0.14, 1)
        love.graphics.rectangle("fill", px, y, pipW, 7)
        love.graphics.setColor(0.33, 0.31, 0.22, 1)
        love.graphics.rectangle("line", px, y, pipW, 7)
    end
end

local function drawTileInspectorPanel(rect, inspector)
    panel(rect.x, rect.y, rect.w, rect.h, 0.88)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    local terrain = inspector and inspector.terrain or {}
    love.graphics.print("Tile " .. tostring(terrain.x or "-") .. "," .. tostring(terrain.y or "-") .. "  " .. tostring(inspector and inspector.source or "-"), rect.x + 12, rect.y + 12)
    local maxLines = math.max(1, math.floor((rect.h - 40) / 18))
    local lines = Render.tacticalTileInspectorLines(inspector)
    for index = 1, math.min(maxLines, #lines) do
        love.graphics.setColor(index == #lines and 0.9 or 0.7, index == #lines and 0.72 or 0.76, index == #lines and 0.42 or 0.68, 1)
        love.graphics.printf(shortText(lines[index], 42), rect.x + 12, rect.y + 32 + (index - 1) * 18, rect.w - 24, "left")
    end
end

local function drawRotationCompass(x, y, size, rotation)
    local compass = Render.rotationCompass(rotation)
    local cx = x + size * 0.5
    local cy = y + size * 0.5
    love.graphics.setColor(0.08, 0.09, 0.09, 0.86)
    love.graphics.circle("fill", cx, cy, size * 0.46)
    love.graphics.setColor(0.52, 0.56, 0.48, 1)
    love.graphics.circle("line", cx, cy, size * 0.46)
    love.graphics.line(cx, y + 4, cx, y + size - 4)
    love.graphics.line(x + 4, cy, x + size - 4, cy)
    love.graphics.setColor(0.96, 0.78, 0.34, 1)
    love.graphics.printf(compass.top, x, y + 2, size, "center")
    love.graphics.printf(compass.bottom, x, y + size - 14, size, "center")
    love.graphics.printf(compass.left, x + 3, cy - 6, 14, "center")
    love.graphics.printf(compass.right, x + size - 17, cy - 6, 14, "center")
end

local function drawArrowHead(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len <= 0.01 then
        return
    end
    local ux = dx / len
    local uy = dy / len
    local px = -uy
    local py = ux
    local size = 8
    love.graphics.line(x2, y2, x2 - ux * size + px * size * 0.55, y2 - uy * size + py * size * 0.55)
    love.graphics.line(x2, y2, x2 - ux * size - px * size * 0.55, y2 - uy * size - py * size * 0.55)
end

local function drawTacticalGhostArrows(app)
    local arrows = Render.tacticalGhostArrowEntries(app)
    for _, arrow in ipairs(arrows) do
        local dx = arrow.toX - arrow.fromX
        local dy = arrow.toY - arrow.fromY
        if dx * dx + dy * dy > 16 then
            love.graphics.setColor(0.92, 0.8, 0.42, 0.42)
            love.graphics.line(arrow.fromX, arrow.fromY, arrow.toX, arrow.toY)
            drawArrowHead(arrow.fromX, arrow.fromY, arrow.toX, arrow.toY)
            love.graphics.setColor(0.94, 0.86, 0.58, 0.74)
            love.graphics.printf(arrow.tileId, arrow.toX - 24, arrow.toY - 18, 48, "center")
        end
    end
    return #arrows
end

function Render.drawTacticalEnemyIntentBadges(app)
    if app and app.worldView then
        app.worldView.tacticalIntentBadges = 0
    end
    return 0
end

function Render.drawTacticalBonusStrip(app, layout, summary)
    local entries = (summary and summary.bonus) or {}
    if #entries == 0 then return end
    local rect = layout.intentLegend
    -- draw a thin row above the intent legend
    local stripH = 22
    local stripY = rect.y - stripH - 4
    love.graphics.setColor(0.05, 0.06, 0.08, 0.78)
    love.graphics.rectangle("fill", rect.x, stripY, rect.w, stripH)
    love.graphics.setColor(0.78, 0.74, 0.58, 1)
    love.graphics.print("Bonus", rect.x + 10, stripY + 4)
    local x = rect.x + 80
    for _, entry in ipairs(entries) do
        local chipW = math.min(170, math.floor((rect.w - 84) / math.max(1, #entries))) - 6
        local color = entry.failed and { 0.86, 0.38, 0.32 } or { 0.42, 0.86, 0.52 }
        love.graphics.setColor(color[1] * 0.16, color[2] * 0.16, color[3] * 0.16, 0.92)
        love.graphics.rectangle("fill", x, stripY + 3, chipW, stripH - 6)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("line", x, stripY + 3, chipW, stripH - 6)
        local label = entry.label or entry.id or "?"
        if entry.limit and entry.limit > 0 then
            label = label .. " " .. tostring(entry.value or 0) .. "/" .. tostring(entry.limit)
        end
        if entry.failed then label = "x " .. label else label = "\xe2\x9c\x93 " .. label end
        love.graphics.printf(shortText(label, math.floor(chipW / 7)), x + 6, stripY + 4, chipW - 12, "left")
        x = x + chipW + 6
    end
end

function Render.drawTacticalIntentLegend(app, layout)
    local entries = Render.tacticalIntentLegendEntries(app)
    if #entries == 0 then
        return 0
    end
    app.ui = app.ui or {}
    app.ui.tacticalIntentButtons = app.ui.tacticalIntentButtons or {}
    local rect = layout.intentLegend
    panel(rect.x, rect.y, rect.w, rect.h, 0.84)
    local gap = 6
    local labelW = 76
    love.graphics.setColor(0.88, 0.82, 0.66, 1)
    love.graphics.print("Intents", rect.x + 10, rect.y + 10)
    local itemW = math.floor((rect.w - labelW - gap * (#entries - 1) - 18) / #entries)
    itemW = math.max(86, itemW)
    local x = rect.x + labelW
    for index, entry in ipairs(entries) do
        local hot = app.tacticalIntentHover and app.tacticalIntentHover.unit == entry.unit
        local w = math.min(itemW, rect.x + rect.w - x - 10)
        if w <= 0 then
            break
        end
        love.graphics.setColor(hot and 0.24 or 0.11, hot and 0.12 or 0.08, hot and 0.08 or 0.08, 0.94)
        love.graphics.rectangle("fill", x, rect.y + 6, w, rect.h - 12)
        love.graphics.setColor(hot and 1.0 or 0.58, hot and 0.64 or 0.32, hot and 0.28 or 0.26, 1)
        love.graphics.rectangle("line", x, rect.y + 6, w, rect.h - 12)
        local iconW = math.floor(34 * clamp(entry.iconScale or 1, 0.75, 1.75))
        love.graphics.setColor(0.96, 0.78, 0.38, 1)
        love.graphics.printf(entry.icon, x + 6, rect.y + 12, iconW, "left")
        love.graphics.setColor(entry.hidden and 0.58 or 0.86, entry.hidden and 0.56 or 0.78, entry.hidden and 0.52 or 0.66, 1)
        love.graphics.printf(shortText(entry.text or (entry.unit .. " " .. entry.label), 26), x + 12 + iconW, rect.y + 12, w - 18 - iconW, "left")
        app.ui.tacticalIntentButtons[#app.ui.tacticalIntentButtons + 1] = {
            x = x,
            y = rect.y + 6,
            w = w,
            h = rect.h - 12,
            intentUnit = entry.unit,
            sourceTile = entry.sourceTile,
            targetTiles = entry.targetTiles,
        }
        x = x + w + gap
    end
    return #entries
end

local function drawTacticalActionSlot(action, x, y, w, h)
    local enabled = action.enabled == true
    local primary = action.primary == true
    local function compactSlotText(value, limit)
        local text = tostring(value or "")
        if #text > limit then
            text = text:gsub("%s+", "")
        end
        return shortText(text, limit)
    end
    local label = shortText(tostring(action.label or "-"):match("^[^%s]+") or action.label, 9)
    local detail = compactSlotText(action.detail, 9)
    local alpha = enabled and 0.92 or 0.58
    love.graphics.setColor(primary and 0.13 or 0.075, primary and 0.12 or 0.085, primary and 0.09 or 0.095, alpha)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(enabled and (primary and 0.92 or 0.42) or 0.22, enabled and (primary and 0.78 or 0.48) or 0.24, enabled and (primary and 0.36 or 0.52) or 0.26, 0.95)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(enabled and 0.96 or 0.42, enabled and 0.94 or 0.44, enabled and 0.78 or 0.42, 1)
    love.graphics.printf(tostring(action.key or "-"), x + 7, y + 6, w - 14, "left")
    love.graphics.setColor(enabled and 0.9 or 0.48, enabled and 0.92 or 0.5, enabled and 0.86 or 0.48, 1)
    love.graphics.printf(label, x + 7, y + 25, w - 14, "center")
    love.graphics.setColor(enabled and 0.62 or 0.36, enabled and 0.68 or 0.38, enabled and 0.64 or 0.36, 1)
    love.graphics.printf(detail, x + 7, y + 43, w - 14, "center")
end

function Render.drawTacticalActionBar(app, layout)
    local actions = Render.tacticalActionBar(app)
    if #actions == 0 then
        return 0
    end
    local width, height = love.graphics.getDimensions()
    layout = layout or Render.tacticalHudLayout(width, height, 6)
    local gap = 6
    local barW = layout.action.w
    local slotW = math.floor((barW - gap * (#actions - 1)) / #actions)
    local slotH = math.min(62, layout.action.h)
    local x = layout.action.x
    local y = layout.action.y
    for index, action in ipairs(actions) do
        drawTacticalActionSlot(action, x + (index - 1) * (slotW + gap), y, slotW, slotH)
    end
    return #actions
end

local function drawTacticalThreatPanel(app, layout, summary)
    local rect = layout.threats
    local showDebug = app and app.tactics and app.tactics.aiDebug == true
    panel(rect.x, rect.y, rect.w, rect.h, 0.88)
    local enemies = (summary and summary.enemies) or {}
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Threats", rect.x + 12, rect.y + 12)
    love.graphics.setColor(0.64, 0.68, 0.62, 1)
    love.graphics.printf(tostring(#enemies) .. " visible", rect.x + rect.w - 94, rect.y + 12, 82, "right")
    local rows = Render.tacticalEnemyHudRows(summary, layout.enemySlots)
    for _, row in ipairs(rows) do
        local rowY = rect.y + 32 + (row.slot - 1) * layout.enemyRowH
        local rowH = layout.enemyRowH - 6
        love.graphics.setColor(row.empty and 0.055 or 0.12, row.empty and 0.06 or 0.075, row.empty and 0.06 or 0.07, row.empty and 0.74 or 0.94)
        love.graphics.rectangle("fill", rect.x + 10, rowY, rect.w - 20, rowH)
        love.graphics.setColor(row.hidden and 0.48 or 0.7, row.hidden and 0.42 or 0.32, row.hidden and 0.34 or 0.26, row.empty and 0.34 or 0.96)
        love.graphics.rectangle("line", rect.x + 10, rowY, rect.w - 20, rowH)
        drawTacticalEnemyPortrait(row, rect.x + 16, rowY + 5, layout.enemyPortraitSize)
        local textX = rect.x + 24 + layout.enemyPortraitSize
        local textW = rect.w - layout.enemyPortraitSize - 50
        love.graphics.setColor(row.empty and 0.36 or 0.92, row.empty and 0.36 or 0.86, row.empty and 0.36 or 0.78, 1)
        love.graphics.printf(shortText(row.id, 16), textX, rowY + 5, textW - 54, "left")
        love.graphics.setColor(row.empty and 0.28 or 0.96, row.empty and 0.26 or 0.64, row.empty and 0.24 or 0.32, 1)
        love.graphics.printf(row.empty and "-" or row.intentIcon, textX + textW - 50, rowY + 5, 46, "right")
        love.graphics.setColor(0.62, 0.66, 0.58, 1)
        local target = row.targetX and (" >" .. tostring(row.targetX) .. "," .. tostring(row.targetY)) or ""
        local hpLine = "HP " .. tostring(row.hp) .. " @" .. tostring(row.x or "-") .. "," .. tostring(row.y or "-") .. target
        if showDebug and row.aiDebug then
            if rowH >= 46 then
                love.graphics.printf(hpLine, textX, rowY + 21, textW, "left")
                love.graphics.setColor(0.58, 0.92, 0.42, 1)
                love.graphics.printf(shortText(aiDebugLine(row.aiDebug), 34), textX, rowY + 36, textW, "left")
            else
                love.graphics.setColor(0.58, 0.92, 0.42, 1)
                love.graphics.printf(shortText(aiDebugLine(row.aiDebug), 34), textX, rowY + 23, textW, "left")
            end
        else
            love.graphics.printf(hpLine, textX, rowY + 23, textW, "left")
        end
        if not row.empty and row.breakMax and row.breakMax > 0 then -- expedition 33 break gauge under HP
            local gaugeX = textX
            local gaugeY = rowY + rowH - 8
            local gaugeW = textW - 4
            love.graphics.setColor(0.18, 0.16, 0.08, 0.92)
            love.graphics.rectangle("fill", gaugeX, gaugeY, gaugeW, 4)
            local fillRatio = math.min(1, (row.breakGauge or 0) / row.breakMax)
            if row.broken then
                love.graphics.setColor(0.98, 0.84, 0.22, 1) -- broken: full gold
            else
                love.graphics.setColor(0.86, 0.66, 0.18, 1)
            end
            love.graphics.rectangle("fill", gaugeX, gaugeY, gaugeW * fillRatio, 4)
            if row.broken then
                love.graphics.setColor(0.98, 0.84, 0.22, 1)
                love.graphics.printf("BRK", textX + textW - 50, rowY + rowH - 22, 46, "right")
            end
        end
        if not row.empty then
            app.ui.tacticalIntentButtons[#app.ui.tacticalIntentButtons + 1] = {
                x = rect.x + 10,
                y = rowY,
                w = rect.w - 20,
                h = rowH,
                intentUnit = row.id,
                sourceTile = { x = row.x, y = row.y },
                targetTiles = row.targetTiles,
            }
        end
    end
    if #enemies > layout.enemySlots then
        love.graphics.setColor(0.76, 0.8, 0.72, 1)
        love.graphics.printf("+" .. tostring(#enemies - layout.enemySlots) .. " more", rect.x + 12, rect.y + rect.h - 18, rect.w - 24, "right")
    end
    return math.min(#enemies, layout.enemySlots)
end

function Render.drawTacticalHud(sim, app)
    local summary = tacticalSummary(app)
    local width, height = love.graphics.getDimensions()
    local layout = Render.tacticalHudLayout(width, height, math.max(6, #((summary and summary.players) or {})))
    drawTacticalGhostArrows(app)
    Render.drawTacticalEnemyIntentBadges(app)
    if app and app.settings and app.settings.calmHud then -- Monument Valley style: surface essentials only
        local hover = app and app.tacticalHover
        local hasSelection = false
        for _, unit in ipairs((summary and summary.players) or {}) do
            if unit.selected then hasSelection = true; break end
        end
        if hover or hasSelection then
            panel(layout.topLeft.x, layout.topLeft.y, layout.topLeft.w, 36, 0.7)
            love.graphics.setColor(0.82, 0.86, 0.78, 0.94)
            love.graphics.print("AP " .. tostring(summary and summary.selectedAp or 0) .. "  HP " .. tostring(summary and summary.selectedHp or 0), layout.topLeft.x + 12, layout.topLeft.y + 10)
            drawRotationCompass(layout.topLeft.x + layout.topLeft.w - 48, layout.topLeft.y + 2, 32, app.viewRotation or 0)
        end
        return
    end
    local hover = app and app.tacticalHover
    local selectedAt = "-"
    for _, unit in ipairs((summary and summary.players) or {}) do
        if unit.selected then
            selectedAt = tostring(unit.x) .. "," .. tostring(unit.y)
            break
        end
    end
    panel(layout.topLeft.x, layout.topLeft.y, layout.topLeft.w, layout.topLeft.h, 0.88)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.printf("End Turn  E", layout.topLeft.x + 16, layout.topLeft.y + 14, 142, "center", 0, 1.2, 1.2)
    love.graphics.setColor(0.48, 0.54, 0.58, 1)
    love.graphics.rectangle("line", layout.topLeft.x + 12, layout.topLeft.y + 10, 156, 48)
    drawRotationCompass(layout.topLeft.x + 174, layout.topLeft.y + 10, 48, app.viewRotation or 0)
    love.graphics.setColor(0.82, 0.86, 0.78, 1)
    local textX = layout.topLeft.x + 236
    love.graphics.print("turn " .. tostring(summary and summary.turn or 1) .. "  " .. tostring(summary and summary.phase or "-") .. "  view " .. tostring((app.viewRotation or 0) * 90), textX, layout.topLeft.y + 10)
    love.graphics.print("selected " .. tostring(summary and summary.selected or "-") .. " @" .. selectedAt .. "  AP " .. tostring(summary and summary.selectedAp or 0) .. "  HP " .. tostring(summary and summary.selectedHp or 0), textX, layout.topLeft.y + 31)
    love.graphics.setColor(0.76, 0.8, 0.72, 1)
    love.graphics.print("target " .. tostring(summary and summary.cursor and summary.cursor.x or "-") .. "," .. tostring(summary and summary.cursor and summary.cursor.y or "-") .. "  hover " .. (hover and (hover.x .. "," .. hover.y) or "-") .. "  zoom " .. tostring(math.floor(Render.tacticalZoom(app) * 100 + 0.5)) .. "%", textX, layout.topLeft.y + 52)
    local objective = summary and summary.objective or {}
    panel(layout.objective.x, layout.objective.y, layout.objective.w, layout.objective.h, 0.88)
    love.graphics.setColor(0.9, 0.82, 0.48, 1)
    love.graphics.printf("route machine " .. tostring(objective.integrity or 0) .. "/" .. tostring(objective.maxIntegrity or 0), layout.objective.x + 12, layout.objective.y + 14, layout.objective.w - 24, "right")
    love.graphics.setColor(0.74, 0.78, 0.72, 1)
    local debugDoctrine = app and app.tactics and app.tactics.aiDebug and summary and summary.aiDoctrine and summary.aiDoctrine.id
    love.graphics.printf(debugDoctrine and ("AI doctrine " .. tostring(debugDoctrine) .. "; forecasts resolve after End Turn") or "red forecasts resolve after End Turn; no hit chance", layout.objective.x + 12, layout.objective.y + 38, layout.objective.w - 24, "right")
    Render.drawTacticalBonusStrip(app, layout, summary)
    Render.drawTacticalIntentLegend(app, layout)
    Render.drawTacticalActionBar(app, layout)
    if summary and summary.aestheticPassed ~= nil then
        -- small composition badge in the objective panel corner
        love.graphics.setColor(summary.aestheticPassed and 0.62 or 0.78, summary.aestheticPassed and 0.86 or 0.42, summary.aestheticPassed and 0.62 or 0.32, 0.86)
        love.graphics.print(summary.aestheticPassed and "\xe2\x97\x86 composed" or "\xe2\x97\x86 rough", layout.objective.x + 12, layout.objective.y + layout.objective.h - 20)
    end
end

function Render.drawTacticalSidePanel(sim, app)
    if app and app.settings and app.settings.calmHud then -- side panel hidden in calm mode
        return
    end
    local summary = tacticalSummary(app)
    local width, height = love.graphics.getDimensions()
    local layout = Render.tacticalHudLayout(width, height, math.max(6, #((summary and summary.players) or {})))
    drawTacticalThreatPanel(app, layout, summary)
    local x = layout.squad.x
    local y = layout.squad.y
    panel(x, y, layout.squad.w, layout.squad.h, 0.88)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Squad", x + 12, y + 12)
    love.graphics.setColor(0.64, 0.68, 0.62, 1)
    love.graphics.printf(tostring(#((summary and summary.players) or {})) .. "/6", x + layout.squad.w - 62, y + 12, 50, "right")
    local rows = Render.tacticalSquadHudRows(summary, layout.squadSlots)
    for _, row in ipairs(rows) do
        local rowY = y + 32 + (row.slot - 1) * layout.rowH
        local selected = row.selected
        love.graphics.setColor(selected and 0.17 or 0.075, selected and 0.17 or 0.09, selected and 0.095 or 0.095, 0.94)
        love.graphics.rectangle("fill", x + 10, rowY, layout.squad.w - 20, layout.rowH - 6)
        love.graphics.setColor(selected and 0.9 or 0.24, selected and 0.78 or 0.26, selected and 0.34 or 0.25, 0.96)
        love.graphics.rectangle("line", x + 10, rowY, layout.squad.w - 20, layout.rowH - 6)
        drawTacticalPortrait(row, x + 16, rowY + 5, layout.portraitSize)
        local textX = x + 24 + layout.portraitSize
        local textW = layout.squad.w - layout.portraitSize - 52
        love.graphics.setColor(row.empty and 0.36 or 0.9, row.empty and 0.38 or 0.92, row.empty and 0.36 or 0.82, 1)
        local nameLabel = row.name or row.id -- prefer generated identity name; falls back to id
        love.graphics.printf(shortText(nameLabel, 18), textX, rowY + 6, textW - 60, "left")
        if selected then
            love.graphics.setColor(0.9, 0.76, 0.32, 1)
            love.graphics.printf("SEL", textX + textW - 52, rowY + 6, 48, "right")
        end
        local infoY = layout.rowH < 46 and rowY + 19 or rowY + 24
        love.graphics.setColor(0.62, 0.66, 0.58, 1)
        local hpLine = "HP " .. tostring(row.hp) .. (row.maxHp and ("/" .. tostring(row.maxHp)) or "")
        if row.stress and row.stress > 0 then hpLine = hpLine .. "  S" .. tostring(row.stress) end
        if row.defense then hpLine = hpLine .. "  " .. string.upper(row.defense) end -- PAR / DOD badge
        love.graphics.printf(hpLine, textX, infoY, textW, "left")
        drawApPool(textX, rowY + layout.rowH - 12, math.min(92, textW - 58), row.ap, row.maxAp)
        love.graphics.setColor(0.74, 0.76, 0.66, 1)
        love.graphics.printf("AP " .. tostring(row.ap) .. "/" .. tostring(row.maxAp), textX + math.min(100, textW - 52), infoY, 52, "right")
    end

    -- bond chips: paint cohesion bars under each squad slot when a bond exists
    local bonds = (summary and summary.bonds) or {}
    if #bonds > 0 then
        local thresholds = { 10, 20, 30 }
        for _, row in ipairs(rows) do
            if row.id and row.id ~= "-" then
                local bestCohesion, bestMate = 0, nil
                for _, bond in ipairs(bonds) do
                    if bond.a == row.id or bond.b == row.id then
                        if (bond.cohesion or 0) > bestCohesion then
                            bestCohesion = bond.cohesion
                            bestMate = (bond.a == row.id) and bond.b or bond.a
                        end
                    end
                end
                if bestMate and bestCohesion > 0 then
                    local rowY = y + 32 + (row.slot - 1) * layout.rowH
                    local barX = x + 12
                    local barY = rowY + layout.rowH - 18
                    local barW = layout.squad.w - 24
                    love.graphics.setColor(0.08, 0.1, 0.16, 0.86)
                    love.graphics.rectangle("fill", barX, barY, barW, 3)
                    local ratio = math.min(1, bestCohesion / thresholds[3])
                    local level = 0
                    for i, t in ipairs(thresholds) do if bestCohesion >= t then level = i end end
                    if level >= 3 then love.graphics.setColor(0.74, 0.42, 0.92, 1)
                    elseif level >= 2 then love.graphics.setColor(0.42, 0.74, 0.92, 1)
                    else love.graphics.setColor(0.42, 0.92, 0.74, 1) end
                    love.graphics.rectangle("fill", barX, barY, barW * ratio, 3)
                    if level > 0 then
                        love.graphics.print("\xe2\x99\xa1" .. tostring(level) .. " " .. shortText(bestMate, 6), barX, barY - 12)
                    end
                end
            end
        end
    end
    if layout.intent.h <= 0 then
        return
    end
    drawTileInspectorPanel(layout.intent, Render.tacticalTileInspectorSummary(app))
end

function Render.drawHud(sim, app)
    if app and app.tacticalMode then
        return Render.drawTacticalHud(sim, app)
    end
    local width = love.graphics.getWidth()
    panel(0, 0, width, 92, 0.9)
    if app.eventFlash and not Render.reducedMotion(app) then
        local color = Render.accessibleColor(app.settings, app.eventFlash.color or { 0.42, 0.54, 0.76 })
        love.graphics.setColor(color[1], color[2], color[3], math.min(0.5, app.eventFlash.t or 0))
        love.graphics.rectangle("fill", 0, 90, width, 2)
    end
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Thoth") .. "  " .. i18n.t("tick") .. " " .. sim.tick .. "  " .. i18n.t(sim.mode) .. "  " .. i18n.t("pos") .. " " .. sim.player.x .. "," .. sim.player.y .. "  " .. i18n.t("view") .. " " .. ((app.viewRotation or 0) * 90), 16, 10)
    love.graphics.printf(i18n.t("status") .. " " .. i18n.t(tostring(app.status or sim.status)), width - 286, 10, 270, "right")
    love.graphics.printf(i18n.t("next") .. " " .. i18n.t(sim:nextStepText()), 16, 32, width - 320)
    local checklist = sim:objectiveChecklist()[1]
    love.graphics.printf(checklistText(checklist), 16, 54, width - 32)
    local summary = Render.expeditionHudSummary(sim)
    love.graphics.printf(i18n.t("room") .. " " .. tostring(summary.currentRoom), 16, 74, 260)
    if sim.expedition then
        love.graphics.setColor(0.9, 0.82, 0.48, 1)
        love.graphics.printf(i18n.t("torch") .. " " .. tostring(summary.torch), width - 286, 36, 270, "right")
        drawMeter(width - 176, 58, 160, 8, (summary.torch or 0) / 100, { 0.86, 0.58, 0.22, 1 })
    end
    love.graphics.setColor(0.74, 0.78, 0.72, 1)
    love.graphics.printf(sim:missionProgressText(), width - 286, 74, 270, "right")
end

function Render.drawSidePanel(sim, app)
    if app and app.tacticalMode then
        return Render.drawTacticalSidePanel(sim, app)
    end
    local width, height = love.graphics.getDimensions()
    local x = width - 306
    local y = 104
    panel(x, y, 292, height - 120, 0.88)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Party"), x + 10, y + 10)
    drawHeroRows(sim, app, x + 10, y + 34, 272)
    local detailY = y + 214
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Supplies"), x + 10, detailY)
    love.graphics.setColor(0.75, 0.78, 0.72, 1)
    love.graphics.printf(sim.expedition and stacksText(sim.expedition.supplies) or "-", x + 10, detailY + 20, 272)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Loot"), x + 10, detailY + 74)
    love.graphics.setColor(0.75, 0.78, 0.72, 1)
    love.graphics.printf(sim.expedition and stacksText(sim.expedition.loot) or (i18n.t("gold") .. ":" .. sim.estate.gold .. " " .. i18n.t("heirlooms") .. ":" .. sim.estate.heirlooms), x + 10, detailY + 94, 272)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Voice"), x + 10, detailY + 126)
    love.graphics.setColor(0.68, 0.72, 0.68, 1)
    love.graphics.printf(sim.narration or "-", x + 10, detailY + 146, 272)
    if sim.documentPopup then
        love.graphics.setColor(0.9, 0.82, 0.58, 1)
        love.graphics.print(i18n.t("Document"), x + 10, detailY + 166)
        love.graphics.setColor(0.68, 0.72, 0.68, 1)
        love.graphics.printf(sim.documentPopup.title .. ": " .. sim.documentPopup.text, x + 10, detailY + 184, 272)
    end
    local logY = sim.documentPopup and (detailY + 244) or (detailY + 198)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Log"), x + 10, logY)
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

local function cutsceneShake(scene, progress, app)
    if not scene then
        return 0, 0
    end
    if not Render.screenShakeEnabled(app) then
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

local function combatShakeOffset(app)
    if not Render.screenShakeEnabled(app) then
        return 0, 0
    end
    local remaining = app and app.combatShake or 0
    if remaining <= 0 then
        return 0, 0
    end
    local magnitude = app.combatShakeMagnitude or 4
    local pulse = math.min(1, remaining / 0.24)
    return math.sin(remaining * 85) * magnitude * pulse, math.cos(remaining * 63) * magnitude * 0.65 * pulse
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

local function drawSceneSprite(cx, floorY, side, label, active, danger, scene, rank, progress, frame, boss)
    local quad, frameW, frameH = atlasFrameQuad(frame)
    if not (quad and state.assets and state.assets.spriteAtlas) then
        return false
    end
    local dir = side == "ally" and 1 or -1
    local t = progress or 0
    local pulse = math.sin(t * math.pi)
    local scale = (boss and 2.75 or 2.1) * (active and (1 + pulse * 0.08) or 0.92)
    local alpha = active and 1 or 0.76
    if danger then
        love.graphics.setColor(1, 0.62, 0.58, alpha)
    else
        love.graphics.setColor(1, 1, 1, alpha)
    end
    love.graphics.draw(state.assets.spriteAtlas, quad, cx, floorY - 3, 0, dir * scale, scale, frameW / 2, frameH)
    if active then
        setSceneColor(scene, 0.86, 1.15)
        love.graphics.rectangle("line", cx - frameW * scale * 0.48, floorY - frameH * scale - 5, frameW * scale * 0.96, frameH * scale + 8)
        if scene and (scene.mood == "affliction" or scene.mood == "doom" or scene.mood == "dazed") then
            setSceneColor(scene, 0.58, 1.2)
            love.graphics.line(cx - 18, floorY - frameH * scale - 2, cx + 18, floorY + 2)
            love.graphics.line(cx + 18, floorY - frameH * scale - 2, cx - 18, floorY + 2)
        end
    end
    love.graphics.setColor(0.84, 0.86, 0.78, active and 1 or 0.72)
    love.graphics.printf(label or "", cx - 48, floorY + 12, 96, "center")
    return true
end

local function drawSceneFigure(cx, floorY, side, label, active, danger, scene, rank, progress, frame, boss)
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
    if drawSceneSprite(cx, floorY, side, label, active, danger, scene, rank, progress, frame, boss) then
        return
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
            drawSceneFigure(cx, floorY, "ally", hero.name, active, false, scene, rank, progress, heroFrame(hero), false)
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
            local boss = isBoss or (scene.boss and rank == 1)
            if boss then
                drawBossSigil(cx, floorY - 58, math.abs(lunge) + math.abs(intro) * 0.6)
            end
            drawSceneFigure(cx, floorY, "enemy", name, active or isBoss, scene.kind == "danger" or scene.kind == "boss_defeat" or scene.kind == "boss_strike", scene, rank, progress, enemy and enemyFrame(combatEnemyType(enemy), enemy.kind) or enemyFrame(boss and "boss" or "threat"), boss)
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
        if scene.crit then
            love.graphics.setColor(1, 0.9, 0.42, 0.92 * pulse)
            love.graphics.printf(i18n.t("CRIT"), cx - 70, y + h * 0.14, 140, "center")
        end
        if (scene.damage or 0) > 0 then
            love.graphics.setColor(0.96, 0.88, 0.62, 0.86 * pulse)
            love.graphics.printf("-" .. tostring(scene.damage), cx - 70, y + h * 0.62, 140, "center")
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
    local shakeX, shakeY = cutsceneShake(currentScene, progress, app)
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

function Render.damageNumberLabel(number)
    local kind = number and number.kind or "hp"
    if kind == "blocked" or (number and number.blocked) then
        return "BLOCK"
    end
    local amount = tostring(number and number.amount or 0)
    local prefix = kind == "heal" and "+" or "-"
    local label = prefix .. amount
    if kind == "stress" then
        label = label .. " " .. i18n.t("stress")
    end
    if number and number.crit then
        label = label .. " " .. i18n.t("CRIT")
    end
    return label
end

local function damageNumberAnchor(sim, app, number)
    if number and number.tactical and app and app.worldView then
        local source = tacticalOverlaySource(sim, app)
        local originX = source and source.originX or 0
        local originY = source and source.originY or 0
        local x, y = Render.projectIso(app.worldView, originX + (number.x or 0) + 0.5, originY + (number.y or 0) + 0.5)
        return x, y - 54
    end
    local width = love.graphics.getWidth()
    local x = 28
    local w = math.max(360, width - 370)
    local y = 92
    local h = 238
    local floorY = y + h - 42
    local rank = clamp(tonumber(number and number.rank) or 1, 1, 4)
    if number and number.side == "ally" then
        return x + 92 + (rank - 1) * 56, floorY - 94
    end
    local enemy = sim and sim.combat and sim:enemyAtRank(rank) or nil
    local def = enemy and Defs.enemy(enemy.kind) or nil
    local spacing = def and def.boss and 72 or 56
    return x + w - 96 - (rank - 1) * spacing, floorY - 94
end

function Render.drawDamageNumbers(sim, app)
    local numbers = app and app.damageNumbers
    if not numbers or #numbers == 0 then
        return 0
    end
    if not (love and love.graphics) then
        return #numbers
    end
    for _, number in ipairs(numbers) do
        local life = math.max(0.001, number.duration or 0.65)
        local progress = 1 - clamp01((number.t or 0) / life)
        local x, y = damageNumberAnchor(sim, app, number)
        y = y - progress * 28
        local alpha = clamp01((number.t or 0) / math.min(0.25, life))
        if number.kind == "blocked" or number.blocked then
            love.graphics.setColor(0.72, 0.74, 0.68, alpha)
        elseif number.targetSide == "player" then
            love.graphics.setColor(1.0, 0.34, 0.24, alpha)
        elseif number.kind == "stress" then
            love.graphics.setColor(0.72, 0.46, 0.86, alpha)
        elseif number.crit then
            love.graphics.setColor(1, 0.9, 0.36, alpha)
        else
            love.graphics.setColor(0.95, 0.78, 0.58, alpha)
        end
        love.graphics.printf(Render.damageNumberLabel(number), x - 58, y, 116, "center")
    end
    return #numbers
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
    love.graphics.print(i18n.t("Combat") .. "  " .. i18n.t("round") .. " " .. sim.combat.round, x + 10, y + 8)
    local active = sim:activeHero()
    love.graphics.print(active and (active.name .. " " .. i18n.t("acts")) or i18n.t("enemy turn"), x + 170, y + 8)
    local summary = Render.combatHudSummary(sim, app)
    local turnLabels = {}
    for _, turn in ipairs(summary.turns) do
        turnLabels[#turnLabels + 1] = (turn.active and ">" or "") .. turn.label
    end
    love.graphics.setColor(0.68, 0.72, 0.66, 1)
    love.graphics.printf(i18n.t("turn") .. " " .. table.concat(turnLabels, "  "), x + 10, y + 24, w - 20)
    if summary.skill then
        love.graphics.setColor(0.9, 0.72, 0.42, 1)
        love.graphics.printf(i18n.t("target") .. " " .. tostring(summary.target or "-") .. " " .. i18n.t("for") .. " " .. tostring(summary.skill), x + w - 310, y + 8, 292, "right")
    end
    for rank = 1, 4 do
        local hero = sim:heroAtRank(rank)
        local hx = x + 18 + (rank - 1) * 92
        love.graphics.setColor(0.14, 0.18, 0.15, 1)
        love.graphics.rectangle("fill", hx, y + 38, 82, 58)
        love.graphics.setColor(0.42, 0.52, 0.38, 1)
        love.graphics.rectangle("line", hx, y + 38, 82, 58)
        love.graphics.setColor(0.9, 0.92, 0.86, 1)
        love.graphics.print(i18n.t("R") .. rank, hx + 4, y + 42)
        love.graphics.printf(hero and hero.name or "-", hx + 4, y + 44, 74, "center")
        if hero then
            love.graphics.printf(hero.hp .. i18n.t("hp") .. " " .. hero.stress .. i18n.t("s"), hx + 4, y + 66, 74, "center")
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
        love.graphics.print(i18n.t("E") .. rank, ex + 4, y + 42)
        love.graphics.printf(enemy and Defs.enemy(enemy.kind).name or "-", ex + 4, y + 44, 74, "center")
        if enemy then
            love.graphics.printf(enemy.hp .. i18n.t("hp"), ex + 4, y + 66, 74, "center")
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
                        app.ui.enemyButtons[#app.ui.enemyButtons + 1] = { x = px, y = py, w = pw, h = 16, rank = rank, side = "enemy", partKey = part.key, hint = part.hint }
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
    love.graphics.print(i18n.t("Camp") .. "  " .. i18n.t("respite") .. " " .. sim.expedition.camping.respite, x + 10, y + 8)
    local summary = Render.campHudSummary(sim, app)
    if summary.pendingSkill then
        love.graphics.setColor(0.9, 0.72, 0.42, 1)
        love.graphics.printf(i18n.t("assign") .. " " .. tostring(summary.pendingSkill), x + w - 260, y + 8, 240, "right")
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
        love.graphics.printf(i18n.t("cost") .. " " .. skill.cost, sx + 6, sy + 28, 128, "center")
        if skill.usable then
            local def = Defs.campSkill(skill.key)
            app.ui.campSkillButtons[#app.ui.campSkillButtons + 1] = { x = sx, y = sy, w = 140, h = 50, skillKey = skill.key, target = def and def.target or "party" }
        end
    end
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Assign Hero"), x + 10, y + 162)
    for _, hero in ipairs(sim:partyState()) do
        local hx = x + 100 + (hero.rank - 1) * 104
        local hy = y + 154
        love.graphics.setColor(0.12, 0.15, 0.14, 1)
        love.graphics.rectangle("fill", hx, hy, 96, 40)
        love.graphics.setColor(0.42, 0.52, 0.38, 1)
        love.graphics.rectangle("line", hx, hy, 96, 40)
        love.graphics.setColor(0.88, 0.9, 0.82, 1)
        love.graphics.printf(i18n.t("R") .. hero.rank .. " " .. hero.name, hx + 4, hy + 13, 88, "center")
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
    love.graphics.print(i18n.t("Estate"), x + 10, y + 10)
    love.graphics.print(i18n.t("week") .. " " .. (sim.estate.week or 1) .. "  " .. i18n.t("gold") .. " " .. sim.estate.gold .. "  " .. i18n.t("heirlooms") .. " " .. sim.estate.heirlooms, x + 10, y + 34)
    local campaign = sim.estate.campaign or {}
    local bosses = 0
    for _, key in ipairs(Defs.locationOrder) do
        if campaign.bossKills and campaign.bossKills[key] then
            bosses = bosses + 1
        end
    end
    local campaignStatus = campaign.lost and (i18n.t("lost") .. " " .. (campaign.lossReason or "")) or (campaign.victory and i18n.t("victory") or (i18n.t("bosses") .. " " .. bosses .. "/" .. #Defs.locationOrder))
    love.graphics.print(i18n.t("renown") .. " " .. (campaign.renown or 0) .. "  " .. i18n.t("dread") .. " " .. (campaign.dread or 0) .. "  " .. campaignStatus, x + 390, y + 34)
    drawJournalPanel(sim, x + 390, y + 58, 320)
    addEstateAction(app, i18n.t("journal"), x + 622, y + 56, 88, { action = "openJournal", enabled = true })
    local timerCopy = sim:panelCopy("timer_panel_copy")
    local factionCopy = sim:panelCopy("faction_panel_copy")
    love.graphics.setColor(0.62, 0.66, 0.58, 1)
    love.graphics.printf((timerCopy and timerCopy.body or "") .. " " .. (factionCopy and factionCopy.body or ""), x + 390, y + 128, 320)
    love.graphics.setColor(0.74, 0.78, 0.72, 1)
    love.graphics.print(i18n.t("roster") .. " " .. sim:livingRosterCount() .. "/" .. sim:rosterLimit() .. "  " .. i18n.t("recruits") .. " " .. #sim.estate.recruits, x + 10, y + 58)
    if sim.estate.currentEvent then
        local event = Defs.townEvent(sim.estate.currentEvent)
        love.graphics.printf(i18n.t("event") .. " " .. event.name, x + 220, y + 58, 150)
        love.graphics.setColor(0.62, 0.66, 0.58, 1)
        love.graphics.printf(event.effect or event.summary or "", x + 220, y + 72, 150)
    end
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Buildings"), x + 10, y + 82)
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
    love.graphics.printf(#trinkets > 0 and table.concat(trinkets, "  ") or i18n.t("no trinkets"), x + 10, y + 174, 312)
    love.graphics.print(i18n.t("Market"), x + 10, y + 196)
    for index, offer in ipairs(sim.estate.trinketStock or {}) do
        local trinket = Defs.trinket(offer.trinket)
        addEstateAction(app, (trinket.short or offer.trinket) .. " " .. offer.price, x + 70 + (index - 1) * 112, y + 190, 104, { action = "buyTrinket", stockIndex = index, enabled = sim.estate.gold >= (offer.price or 0) })
    end
    love.graphics.printf(i18n.t("cart") .. " " .. stacksText(sim.estate.provisionCart), x + 10, y + 220, 400)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Missions"), x + 10, y + 246)
    for index, key in ipairs(sim:availableMissionKeys()) do
        local mission = Defs.mission(key)
        local bx = x + 10 + ((index - 1) % 2) * 205
        local by = y + 268 + math.floor((index - 1) / 2) * 44
        love.graphics.setColor(0.13, 0.16, 0.15, 1)
        love.graphics.rectangle("fill", bx, by, 196, 38)
        love.graphics.setColor(0.42, 0.48, 0.36, 1)
        love.graphics.rectangle("line", bx, by, 196, 38)
        love.graphics.setColor(0.86, 0.88, 0.8, 1)
        love.graphics.printf((mission.difficulty or i18n.t("mission")) .. " " .. mission.kind, bx + 4, by + 5, 188, "center")
        local location = Defs.location(mission.location)
        love.graphics.setColor(0.58, 0.62, 0.55, 1)
        love.graphics.printf(i18n.t("kit") .. " " .. compactStacks(location and location.provisions), bx + 4, by + 21, 188, "center")
        app.ui.missionButtons[#app.ui.missionButtons + 1] = { x = bx, y = by, w = 196, h = 38, missionKey = key }
    end
    drawPartyFormation(sim, app, x + 10, y + 356, 410)
    local recruitY = y + 452
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(i18n.t("Recruits"), x + 10, recruitY)
    love.graphics.setColor(0.58, 0.62, 0.55, 1)
    love.graphics.printf(Render.classUnlockSummary(sim).line, x + 92, recruitY, 328, "right")
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
    love.graphics.print(i18n.t("Provisions"), x + 10, provisionY)
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
    local shakeX, shakeY = combatShakeOffset(app)
    love.graphics.translate(shakeX, shakeY)
    love.graphics.setDepthMode()
    app.worldView.tacticalForecast = Render.drawTacticalForecast(sim, app)
    Render.drawHud(sim, app)
    Render.drawSidePanel(sim, app)
    Render.drawCombatStage(sim, app)
    Render.drawCombatOverlay(sim, app)
    Render.drawCampOverlay(sim, app)
    Render.drawEstatePanel(sim, app)
    Render.drawCurioResult(app)
    Render.drawCurioModal(app)
    Render.drawCutscene(sim, app)
    Render.drawDamageNumbers(sim, app)
    Render.drawKeyboardFocus(app)
    Render.drawTutorial(app)
    Render.drawPauseMenu(app)
    Render.drawConfirmDialog(app)
    Render.drawToasts(app)
    Render.drawAudioSubtitle(app)
    Render.drawUiMicroAnimations(app)
    love.graphics.pop()
end

return Render
