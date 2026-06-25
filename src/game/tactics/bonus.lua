-- per-board bonus objective tracking (Captain Toad style secondary challenges)
local Bonus = {}

Bonus.catalog = {
    no_damage         = { label = "untouched",      preview = "no unit takes damage",        track = "squadDamageTaken",   limit = 0 },
    fast_extract      = { label = "swift exit",     preview = "extract within N turns",      track = "turnsElapsed",       limit = 6 },
    no_cover_destroyed = { label = "preservation",  preview = "destroy no cover tile",       track = "coversDestroyed",    limit = 0 },
    no_deaths         = { label = "intact squad",   preview = "no squad death",              track = "unitsLost",          limit = 0 },
    no_objective_loss = { label = "clean record",   preview = "no objective integrity lost", track = "objectiveDamage",    limit = 0 },
    no_overwatch      = { label = "silent step",    preview = "no overwatch triggered",      track = "overwatchTriggers",  limit = 0 },
}

function Bonus.new(ids)
    local active = {}
    for _, id in ipairs(ids or {}) do
        local def = Bonus.catalog[id]
        if def then
            active[#active + 1] = {
                id = id,
                label = def.label,
                preview = def.preview,
                track = def.track,
                limit = def.limit,
                value = 0,
                failed = false,
            }
        end
    end
    return {
        challenges = active,
        counters = { squadDamageTaken = 0, turnsElapsed = 0, coversDestroyed = 0, unitsLost = 0, objectiveDamage = 0, overwatchTriggers = 0 },
    }
end

function Bonus.bump(tracker, key, amount)
    if not tracker or not tracker.counters then return end
    amount = amount or 1
    tracker.counters[key] = (tracker.counters[key] or 0) + amount
    for _, ch in ipairs(tracker.challenges or {}) do
        if ch.track == key and not ch.failed then
            ch.value = tracker.counters[key]
            if ch.value > ch.limit then
                ch.failed = true
            end
        end
    end
end

function Bonus.status(tracker)
    local result = {}
    for _, ch in ipairs((tracker and tracker.challenges) or {}) do
        result[#result + 1] = { id = ch.id, label = ch.label, preview = ch.preview, value = ch.value, limit = ch.limit, failed = ch.failed, intact = not ch.failed }
    end
    return result
end

function Bonus.snapshot(tracker)
    if not tracker then return nil end
    local challenges = {}
    for _, ch in ipairs(tracker.challenges or {}) do
        challenges[#challenges + 1] = { id = ch.id, label = ch.label, preview = ch.preview, track = ch.track, limit = ch.limit, value = ch.value, failed = ch.failed }
    end
    local counters = {}
    for k, v in pairs(tracker.counters or {}) do counters[k] = v end
    return { challenges = challenges, counters = counters }
end

function Bonus.fromSnapshot(snap)
    if not snap then return nil end
    local tracker = { challenges = {}, counters = {} }
    for _, ch in ipairs(snap.challenges or {}) do
        tracker.challenges[#tracker.challenges + 1] = { id = ch.id, label = ch.label, preview = ch.preview, track = ch.track, limit = ch.limit, value = ch.value or 0, failed = ch.failed == true }
    end
    for k, v in pairs(snap.counters or {}) do tracker.counters[k] = v end
    return tracker
end

return Bonus
