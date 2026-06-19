local Achievements = {}

local definitions = {
    first_steps = { title = "First Steps", text = "Entered an expedition." },
    first_document = { title = "Filed Evidence", text = "Recovered a document." },
    first_fall = { title = "Recorded Loss", text = "Added a name to the graveyard." },
}

function Achievements.definitions()
    return definitions
end

function Achievements.unlock(app, key)
    local def = definitions[key]
    if not (app and def) then
        return false
    end
    app.achievements = app.achievements or {}
    if app.achievements[key] then
        return false
    end
    app.achievements[key] = true
    app.toasts = app.toasts or {}
    app.toasts[#app.toasts + 1] = { key = key, title = def.title, text = def.text, t = 3.2 }
    return true
end

function Achievements.update(sim, app)
    if not (sim and app) then
        return
    end
    if sim.expedition and sim.expedition.active then
        Achievements.unlock(app, "first_steps")
    end
    if sim.estate and sim.estate.documentLog and #sim.estate.documentLog > 0 then
        Achievements.unlock(app, "first_document")
    end
    if sim.estate and sim.estate.graveyard and #sim.estate.graveyard > 0 then
        Achievements.unlock(app, "first_fall")
    end
end

function Achievements.updateToasts(app, dt)
    for index = #((app and app.toasts) or {}), 1, -1 do
        local toast = app.toasts[index]
        toast.t = (toast.t or 0) - dt
        if toast.t <= 0 then
            table.remove(app.toasts, index)
        end
    end
end

return Achievements
