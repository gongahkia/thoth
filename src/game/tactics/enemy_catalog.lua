local EnemyCatalog = {}

EnemyCatalog.families = {
    archive = {
        common = {
            { id = "hollow_guard", name = "Hollow Guard", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "nearest" }, boardVerb = "brace_cover" },
            { id = "ink_wretch", name = "Ink Wretch", exactIntent = { mode = "exact", category = "debuff", damage = 1, target = "line" }, boardVerb = "ink_tile" },
            { id = "bone_scribe", name = "Bone Scribe", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "marked" }, boardVerb = "redact_mark" },
            { id = "gutter_thing", name = "Gutter Thing", exactIntent = { mode = "exact", category = "move", damage = 1, target = "pull" }, boardVerb = "hook_cargo" },
            { id = "pale_censer", name = "Pale Censer", exactIntent = { mode = "exact", category = "debuff", damage = 0, target = "claim_tile" }, boardVerb = "fog_claim" },
            { id = "page_scout", name = "Page Scout", exactIntent = { mode = "exact", category = "move", damage = 1, target = "flank" }, boardVerb = "flip_shelf" },
            { id = "writ_bailiff", name = "Writ Bailiff", exactIntent = { mode = "exact", category = "destroy", damage = 2, target = "objective" }, boardVerb = "stamp_claim" },
            { id = "seal_clerk", name = "Seal Clerk", exactIntent = { mode = "exact", category = "guard", damage = 0, target = "seal" }, boardVerb = "lock_door" },
            { id = "ledger_hound", name = "Ledger Hound", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "carrier" }, boardVerb = "sniff_route" },
            { id = "drawer_mite", name = "Drawer Mite", exactIntent = { mode = "exact", category = "summon", damage = 1, target = "drawer" }, boardVerb = "spill_records" },
        },
        elites = {
            { id = "codex_advocate", name = "Codex Advocate", partialIntent = { mode = "category", category = "debuff" }, weakPoints = { "open_register" }, terrainInteraction = "seal_claim_line" },
            { id = "shelf_knight", name = "Shelf Knight", partialIntent = { mode = "category", category = "guard" }, weakPoints = { "rear_binding" }, terrainInteraction = "shove_shelf_wall" },
            { id = "writ_cantor", name = "Writ Cantor", partialIntent = { mode = "category", category = "summon" }, weakPoints = { "choir_chain" }, terrainInteraction = "ring_audit_beam" },
        },
        alpha = {
            id = "shelf_warden",
            name = "Shelf Warden",
            visiblePreBoard = true,
            preBoardThreat = "pursues the chosen archive route before board reveal",
            routeChoiceChange = "marks one adjacent archive node as audited",
            boardGenerationChange = "adds two shoveable shelf blockers and one audit beam lane",
        },
    },
    cistern = {
        common = {
            { id = "drowned_acolyte", name = "Drowned Acolyte", exactIntent = { mode = "exact", category = "debuff", damage = 1, target = "line" }, waterPressureVerb = "raise_mist" },
            { id = "brine_stalker", name = "Brine Stalker", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "flank" }, waterPressureVerb = "pull_current" },
            { id = "valve_thrall", name = "Valve Thrall", exactIntent = { mode = "exact", category = "destroy", damage = 2, target = "cover" }, waterPressureVerb = "turn_valve" },
            { id = "brine_midwife", name = "Brine Midwife", exactIntent = { mode = "exact", category = "summon", damage = 0, target = "pool" }, waterPressureVerb = "birth_brine" },
            { id = "sluice_eel", name = "Sluice Eel", exactIntent = { mode = "exact", category = "move", damage = 2, target = "current" }, waterPressureVerb = "ride_sluice" },
            { id = "salt_choir", name = "Salt Choir", exactIntent = { mode = "exact", category = "buff", damage = 0, target = "wet_row" }, waterPressureVerb = "ring_pressure" },
            { id = "pearl_cyst", name = "Pearl Cyst", exactIntent = { mode = "exact", category = "guard", damage = 1, target = "claim_tile" }, waterPressureVerb = "burst_pool" },
            { id = "halocline_tender", name = "Halocline Tender", exactIntent = { mode = "exact", category = "debuff", damage = 0, target = "waterline" }, waterPressureVerb = "shift_halocline" },
            { id = "drowned_pilgrim", name = "Drowned Pilgrim", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "low_ground" }, waterPressureVerb = "kneel_flood" },
            { id = "reed_mouth_diver", name = "Reed-Mouth Diver", exactIntent = { mode = "exact", category = "flee", damage = 0, target = "exit_water" }, waterPressureVerb = "signal_reed" },
        },
        elites = {
            { id = "depth_bailiff", name = "Depth Bailiff", partialIntent = { mode = "category", category = "destroy" }, weakPoints = { "depth_warrant" }, floodDrainCounterplay = "drain adjacent pressure bell" },
            { id = "pearl_choir", name = "Pearl Choir", partialIntent = { mode = "category", category = "summon" }, weakPoints = { "choir_throat" }, floodDrainCounterplay = "lower waterline before chorus" },
            { id = "undertow_notary", name = "Undertow Notary", partialIntent = { mode = "category", category = "move" }, weakPoints = { "tide_stamp" }, floodDrainCounterplay = "open drain grate to break pull lane" },
        },
        alpha = {
            id = "depth_bailiff",
            name = "Depth Bailiff",
            visiblePreBoard = true,
            preBoardThreat = "posts a depth warrant on the route map",
            routeChoiceChange = "floods one shallow route and discounts one pump route",
            boardGenerationChange = "adds one pressure bell, two flood lanes, and raised low-ground punishment",
        },
    },
    warrens = {
        common = {
            { id = "ash_husk", name = "Ash Husk", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "front" }, heatAshGlassVerb = "kick_ash" },
            { id = "kiln_imp", name = "Kiln Imp", exactIntent = { mode = "exact", category = "move", damage = 1, target = "heat_lane" }, heatAshGlassVerb = "spark_jump" },
            { id = "kiln_nurse", name = "Kiln Nurse", exactIntent = { mode = "exact", category = "buff", damage = 0, target = "burned_ally" }, heatAshGlassVerb = "cautery_stoke" },
            { id = "glass_penitent", name = "Glass Penitent", exactIntent = { mode = "exact", category = "guard", damage = 1, target = "line" }, heatAshGlassVerb = "raise_glass" },
            { id = "clinker_butcher", name = "Clinker Butcher", exactIntent = { mode = "exact", category = "attack", damage = 3, target = "cover" }, heatAshGlassVerb = "hook_clinker" },
            { id = "white_furnace", name = "White Furnace", exactIntent = { mode = "exact", category = "destroy", damage = 3, target = "objective" }, heatAshGlassVerb = "pressure_coal" },
            { id = "glass_choirmaster", name = "Glass Choirmaster", exactIntent = { mode = "exact", category = "debuff", damage = 0, target = "reflected_line" }, heatAshGlassVerb = "sing_reflection" },
            { id = "cinder_penitent", name = "Cinder Penitent", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "adjacent" }, heatAshGlassVerb = "immolate_cinder" },
            { id = "ember_mote", name = "Ember Mote", exactIntent = { mode = "exact", category = "summon", damage = 1, target = "burn_tile" }, heatAshGlassVerb = "seed_ember" },
            { id = "coal_monk", name = "Coal Monk", exactIntent = { mode = "exact", category = "debuff", damage = 1, target = "white_coal" }, heatAshGlassVerb = "chant_pressure" },
        },
    },
}

function EnemyCatalog.family(id)
    return EnemyCatalog.families[id]
end

function EnemyCatalog.common(familyId)
    local family = EnemyCatalog.family(familyId)
    return family and family.common or {}
end

function EnemyCatalog.elites(familyId)
    local family = EnemyCatalog.family(familyId)
    return family and family.elites or {}
end

function EnemyCatalog.alpha(familyId)
    local family = EnemyCatalog.family(familyId)
    return family and family.alpha or nil
end

return EnemyCatalog
