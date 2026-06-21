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
