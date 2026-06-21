local ClassCatalog = {}

ClassCatalog.classes = {
    warden = {
        name = "Warden",
        loadouts = {
            { id = "line_guard", role = "frontline protector", tools = { "brace_pavise", "route_hook" } },
            { id = "claim_anchor", role = "objective holder", tools = { "claim_spike", "oath_tether" } },
            { id = "breach_shield", role = "cover breaker", tools = { "shelf_shove_kit", "breach_maul" } },
        },
        tools = {
            { id = "brace_pavise", effect = "raise mobile half cover" },
            { id = "route_hook", effect = "pull ally or cargo one tile" },
            { id = "claim_spike", effect = "brace on claim tile without losing LoS" },
            { id = "shelf_shove_kit", effect = "shove full cover or blocker one tile" },
            { id = "oath_tether", effect = "redirect first objective hit to Warden guard" },
            { id = "breach_maul", effect = "damage destructible cover and expose flanks" },
        },
        terrainInteractions = {
            { id = "raise_mobile_cover", terrain = "cover", effect = "turn adjacent low object into half cover" },
            { id = "shove_blocker", terrain = "blocker", effect = "move a shelf, barricade, or cart into a lane" },
        },
        weakness = { id = "slow_to_pivot", effect = "after guarding an objective, next move costs +1 AP" },
        replayFixture = "warden_brace_line",
    },
}

function ClassCatalog.class(id)
    return ClassCatalog.classes[id]
end

function ClassCatalog.loadouts(id)
    local class = ClassCatalog.class(id)
    return class and class.loadouts or {}
end

function ClassCatalog.tools(id)
    local class = ClassCatalog.class(id)
    return class and class.tools or {}
end

function ClassCatalog.terrainInteractions(id)
    local class = ClassCatalog.class(id)
    return class and class.terrainInteractions or {}
end

return ClassCatalog
