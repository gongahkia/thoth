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
    duelist = {
        name = "Duelist",
        loadouts = {
            { id = "red_line", role = "dash striker", tools = { "razor_dash", "angle_step" } },
            { id = "patron_shadow", role = "position trader", tools = { "swap_foil", "riposte_mark" } },
            { id = "debt_blade", role = "flank finisher", tools = { "cloak_pin", "ledger_stiletto" } },
        },
        tools = {
            { id = "razor_dash", effect = "dash through a safe lane before attacking" },
            { id = "angle_step", effect = "shift one tile after a flank preview" },
            { id = "swap_foil", effect = "swap with adjacent enemy or ally" },
            { id = "riposte_mark", effect = "mark first enemy entering adjacent tile" },
            { id = "cloak_pin", effect = "ignore first overwatch line while flanking" },
            { id = "ledger_stiletto", effect = "bonus damage against isolated objective guards" },
        },
        terrainInteractions = {
            { id = "vault_low_cover", terrain = "half_cover", effect = "vault low cover without ending movement" },
            { id = "cut_hanging_line", terrain = "suspended_object", effect = "drop hanging cover into a flank lane" },
        },
        weakness = { id = "overextends", effect = "after dashing, adjacent enemies add +1 incoming damage" },
        replayFixture = "duelist_flank_dash",
    },
    mender = {
        name = "Apothecary",
        loadouts = {
            { id = "field_triage", role = "objective medic", tools = { "wound_clamp", "salt_draught" } },
            { id = "smoke_binder", role = "LoS controller", tools = { "hush_smoke", "salve_flare" } },
            { id = "plague_cutter", role = "hazard cleanser", tools = { "bitter_vial", "sterilize_hook" } },
        },
        tools = {
            { id = "wound_clamp", effect = "repair ally or civilian integrity" },
            { id = "salt_draught", effect = "cleanse brine or blight status" },
            { id = "hush_smoke", effect = "place short-lived obscurant" },
            { id = "salve_flare", effect = "reveal safe rescue route through smoke" },
            { id = "bitter_vial", effect = "apply deterministic debuff to one enemy" },
            { id = "sterilize_hook", effect = "drag cargo or patient out of hazard" },
        },
        terrainInteractions = {
            { id = "douse_brine_pool", terrain = "hazard", effect = "turn adjacent brine or burn tile inactive" },
            { id = "smoke_claim_line", terrain = "claim_line", effect = "obscure claim tile without changing ownership" },
        },
        weakness = { id = "triage_burden", effect = "after repairing an objective, next carry or drag costs +1 AP" },
        replayFixture = "apothecary_smoke_triage",
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
