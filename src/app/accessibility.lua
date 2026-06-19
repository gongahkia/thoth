local Accessibility = {}

local function add(lines, label, value)
    if value ~= nil and value ~= "" then
        lines[#lines + 1] = label .. ": " .. tostring(value)
    end
end

local function settingText(settings)
    settings = settings or {}
    return table.concat({
        "high_contrast=" .. tostring(settings.highContrast == true),
        "colorblind=" .. tostring(settings.colorblindMode or "off"),
        "font_scale=" .. tostring(settings.fontScale or 1),
        "ambient_volume=" .. tostring(settings.ambientVolume or 0.7),
        "reduced_motion=" .. tostring(settings.reducedMotion == true),
        "screen_shake=" .. tostring(settings.screenShake ~= false),
        "subtitles=" .. tostring(settings.subtitles ~= false),
    }, ", ")
end

local function heroLine(sim, hero, index)
    local maxHp = hero.maxHp or (hero.classId and sim and sim.maxHp and sim:maxHp(hero)) or "?"
    local alive = hero.alive == false and "dead" or "alive"
    return string.format(
        "%d. %s / %s / hp %s/%s / stress %s / %s",
        index,
        tostring(hero.name or "hero"),
        tostring(hero.class or "?"),
        tostring(hero.hp or "?"),
        tostring(maxHp),
        tostring(hero.stress or 0),
        alive
    )
end

function Accessibility.lines(sim, app)
    local lines = { "Thoth accessibility export" }
    add(lines, "ui", app and app.uiState or "game")
    add(lines, "status", (app and app.status) or (sim and sim.status))
    add(lines, "mode", sim and sim.mode)
    add(lines, "tick", sim and sim.tick)
    add(lines, "settings", settingText(app and app.settings))
    if sim and sim.estate then
        add(lines, "estate", "week " .. tostring(sim.estate.week or 1) .. ", gold " .. tostring(sim.estate.gold or 0) .. ", heirlooms " .. tostring(sim.estate.heirlooms or 0))
    end
    if sim and sim.expedition then
        add(lines, "mission", sim.expedition.mission)
        add(lines, "objective", sim.objectiveText and sim:objectiveText() or nil)
        add(lines, "next", sim.nextStepText and sim:nextStepText() or nil)
        add(lines, "torch", sim.expedition.torch)
        add(lines, "room", sim.currentRoomKey and sim:currentRoomKey() or nil)
        add(lines, "progress", sim.missionProgressText and sim:missionProgressText() or nil)
        if sim.player then
            add(lines, "position", tostring(sim.player.x) .. "," .. tostring(sim.player.y) .. "," .. tostring(sim.player.z or 0) .. " facing " .. tostring(sim.player.facing or "?"))
        end
    end
    lines[#lines + 1] = "party:"
    for index, hero in ipairs(sim and sim.partyState and sim:partyState() or {}) do
        lines[#lines + 1] = heroLine(sim, hero, index)
    end
    if sim and sim.combat then
        lines[#lines + 1] = "combat:"
        add(lines, "round", sim.combat.round)
        for index, enemy in ipairs(sim.combat.enemies or {}) do
            lines[#lines + 1] = string.format("%d. %s / hp %s / rank %s", index, tostring(enemy.kind or "enemy"), tostring(enemy.hp or "?"), tostring(enemy.rank or "?"))
        end
    end
    if app and app.eventFlash then
        add(lines, "subtitle", tostring(app.eventFlash.cue or "audio") .. ": " .. tostring(app.eventFlash.status or app.eventFlash.message or ""))
    end
    lines[#lines + 1] = "controls: move with WASD or arrows, interact with Space, pause with Escape"
    return lines
end

function Accessibility.text(sim, app)
    return table.concat(Accessibility.lines(sim, app), "\n") .. "\n"
end

function Accessibility.write(path, sim, app)
    local file, err = io.open(path, "w")
    if not file then
        return false, err
    end
    file:write(Accessibility.text(sim, app))
    file:close()
    return true
end

return Accessibility
