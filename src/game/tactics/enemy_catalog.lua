local EnemyCatalog = {}

EnemyCatalog.requiredArchetypes = { "mover", "shooter", "artillery", "pusher", "puller", "blocker", "summoner", "repairer", "saboteur", "overwatch", "terrain-breaker" }

EnemyCatalog.archetypes = {
    mover = { intent = "reposition", boardVerb = "move", counterplay = "body block lane or pin source", preview = "destination and path" },
    shooter = { intent = "direct harm", boardVerb = "shoot", counterplay = "break LoS or raise cover", preview = "source, path, target, damage" },
    artillery = { intent = "area harm", boardVerb = "lob", counterplay = "leave footprint or interrupt fuse", preview = "impact footprint and countdown" },
    pusher = { intent = "forced movement", boardVerb = "push", counterplay = "brace, block landing, or move target", preview = "push vector and collision" },
    puller = { intent = "forced movement", boardVerb = "pull", counterplay = "break hook path or anchor target", preview = "pull path and landing" },
    blocker = { intent = "space denial", boardVerb = "block", counterplay = "destroy, route around, or seal blocker", preview = "blocked edge or tile" },
    summoner = { intent = "spawn pressure", boardVerb = "summon", counterplay = "block spawn pocket or kill source", preview = "spawn pocket and turn" },
    repairer = { intent = "enemy sustain", boardVerb = "repair", counterplay = "isolate target or interrupt source", preview = "repaired target and amount" },
    saboteur = { intent = "objective damage", boardVerb = "sabotage", counterplay = "body block, repair, or disable source", preview = "objective delta" },
    overwatch = { intent = "reaction lane", boardVerb = "watch", counterplay = "bait trigger, smoke, or take alternate route", preview = "watch cone and trigger" },
    ["terrain-breaker"] = { intent = "terrain conversion", boardVerb = "break", counterplay = "evacuate, stabilize, or use new gap", preview = "terrain tile before and after" },
}

EnemyCatalog.exactIntentBlueprints = {
    mover = { targetPattern = "destination tile", pathPattern = "shortest legal movement path", effect = "reposition threat", objectiveImpact = "none", counterplay = { "body_block_path", "pin_source" } },
    shooter = { targetPattern = "visible target tile", pathPattern = "line of sight trace", effect = "direct damage", objectiveImpact = "none", counterplay = { "break_los", "raise_cover" } },
    artillery = { targetPattern = "marked line or area footprint", pathPattern = "lobbed or reflected trace", effect = "area pressure", objectiveImpact = "possible integrity loss", counterplay = { "leave_footprint", "interrupt_source" } },
    pusher = { targetPattern = "adjacent or pressure-line target", pathPattern = "push vector", effect = "forced displacement", objectiveImpact = "collision can damage objective", counterplay = { "brace", "block_landing" }, collision = { kind = "forced_movement", vector = "away" } },
    puller = { targetPattern = "hooked target tile", pathPattern = "pull trace", effect = "forced displacement", objectiveImpact = "collision can damage objective", counterplay = { "break_hook_path", "anchor_target" }, collision = { kind = "forced_movement", vector = "toward" } },
    blocker = { targetPattern = "blocked tile or edge", pathPattern = "adjacent placement trace", effect = "space denial", objectiveImpact = "none", counterplay = { "destroy_blocker", "route_around" } },
    summoner = { targetPattern = "spawn pocket", pathPattern = "summon trace", effect = "adds enemy pressure", objectiveImpact = "future objective pressure", counterplay = { "block_spawn", "kill_source" } },
    repairer = { targetPattern = "damaged ally or machine", pathPattern = "support trace", effect = "repairs enemy board state", objectiveImpact = "extends pressure clock", counterplay = { "isolate_target", "interrupt_source" } },
    saboteur = { targetPattern = "objective or route asset", pathPattern = "sabotage trace", effect = "objective pressure", objectiveImpact = "integrity loss or escape progress", counterplay = { "body_block", "repair_objective" } },
    overwatch = { targetPattern = "reaction cone", pathPattern = "watched lane", effect = "reaction attack", objectiveImpact = "none", counterplay = { "bait_trigger", "smoke_lane" } },
    ["terrain-breaker"] = { targetPattern = "terrain tile", pathPattern = "conversion trace", effect = "terrain conversion", objectiveImpact = "opens or closes route", counterplay = { "stabilize_tile", "evacuate_tile" } },
}

EnemyCatalog.families = {
    archive = {
        common = {
            { id = "hollow_guard", name = "Hollow Guard", archetype = "overwatch", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "nearest" }, boardVerb = "brace_cover" },
            { id = "ink_wretch", name = "Ink Wretch", archetype = "artillery", exactIntent = { mode = "exact", category = "debuff", damage = 1, target = "line" }, boardVerb = "ink_tile" },
            { id = "bone_scribe", name = "Bone Scribe", archetype = "shooter", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "marked" }, boardVerb = "redact_mark" },
            { id = "gutter_thing", name = "Gutter Thing", archetype = "puller", exactIntent = { mode = "exact", category = "move", damage = 1, target = "pull" }, boardVerb = "hook_cargo" },
            { id = "pale_censer", name = "Pale Censer", archetype = "blocker", exactIntent = { mode = "exact", category = "debuff", damage = 0, target = "claim_tile" }, boardVerb = "fog_claim" },
            { id = "page_scout", name = "Page Scout", archetype = "mover", exactIntent = { mode = "exact", category = "move", damage = 1, target = "flank" }, boardVerb = "flip_shelf" },
            { id = "writ_bailiff", name = "Writ Bailiff", archetype = "saboteur", exactIntent = { mode = "exact", category = "destroy", damage = 2, target = "objective" }, boardVerb = "stamp_claim" },
            { id = "seal_clerk", name = "Seal Clerk", archetype = "blocker", exactIntent = { mode = "exact", category = "guard", damage = 0, target = "seal" }, boardVerb = "lock_door" },
            { id = "ledger_hound", name = "Ledger Hound", archetype = "shooter", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "carrier" }, boardVerb = "sniff_route" },
            { id = "drawer_mite", name = "Drawer Mite", archetype = "summoner", exactIntent = { mode = "exact", category = "summon", damage = 1, target = "drawer" }, boardVerb = "spill_records" },
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
            { id = "drowned_acolyte", name = "Drowned Acolyte", archetype = "artillery", exactIntent = { mode = "exact", category = "debuff", damage = 1, target = "line" }, waterPressureVerb = "raise_mist" },
            { id = "brine_stalker", name = "Brine Stalker", archetype = "puller", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "flank" }, waterPressureVerb = "pull_current" },
            { id = "valve_thrall", name = "Valve Thrall", archetype = "terrain-breaker", exactIntent = { mode = "exact", category = "destroy", damage = 2, target = "cover" }, waterPressureVerb = "turn_valve" },
            { id = "brine_midwife", name = "Brine Midwife", archetype = "summoner", exactIntent = { mode = "exact", category = "summon", damage = 0, target = "pool" }, waterPressureVerb = "birth_brine" },
            { id = "sluice_eel", name = "Sluice Eel", archetype = "mover", exactIntent = { mode = "exact", category = "move", damage = 2, target = "current" }, waterPressureVerb = "ride_sluice" },
            { id = "salt_choir", name = "Salt Choir", archetype = "repairer", exactIntent = { mode = "exact", category = "repair", damage = 0, target = "wet_row" }, waterPressureVerb = "ring_pressure" },
            { id = "pearl_cyst", name = "Pearl Cyst", archetype = "blocker", exactIntent = { mode = "exact", category = "guard", damage = 1, target = "claim_tile" }, waterPressureVerb = "burst_pool" },
            { id = "halocline_tender", name = "Halocline Tender", archetype = "pusher", exactIntent = { mode = "exact", category = "debuff", damage = 0, target = "waterline" }, waterPressureVerb = "shift_halocline" },
            { id = "drowned_pilgrim", name = "Drowned Pilgrim", archetype = "shooter", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "low_ground" }, waterPressureVerb = "kneel_flood" },
            { id = "reed_mouth_diver", name = "Reed-Mouth Diver", archetype = "saboteur", exactIntent = { mode = "exact", category = "flee", damage = 0, target = "exit_water" }, waterPressureVerb = "signal_reed" },
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
            { id = "ash_husk", name = "Ash Husk", archetype = "pusher", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "front" }, heatAshGlassVerb = "kick_ash" },
            { id = "kiln_imp", name = "Kiln Imp", archetype = "mover", exactIntent = { mode = "exact", category = "move", damage = 1, target = "heat_lane" }, heatAshGlassVerb = "spark_jump" },
            { id = "kiln_nurse", name = "Kiln Nurse", archetype = "repairer", exactIntent = { mode = "exact", category = "repair", damage = 0, target = "burned_ally" }, heatAshGlassVerb = "cautery_stoke" },
            { id = "glass_penitent", name = "Glass Penitent", archetype = "overwatch", exactIntent = { mode = "exact", category = "guard", damage = 1, target = "line" }, heatAshGlassVerb = "raise_glass" },
            { id = "clinker_butcher", name = "Clinker Butcher", archetype = "puller", exactIntent = { mode = "exact", category = "attack", damage = 3, target = "cover" }, heatAshGlassVerb = "hook_clinker" },
            { id = "white_furnace", name = "White Furnace", archetype = "terrain-breaker", exactIntent = { mode = "exact", category = "destroy", damage = 3, target = "objective" }, heatAshGlassVerb = "pressure_coal" },
            { id = "glass_choirmaster", name = "Glass Choirmaster", archetype = "artillery", exactIntent = { mode = "exact", category = "debuff", damage = 0, target = "reflected_line" }, heatAshGlassVerb = "sing_reflection" },
            { id = "cinder_penitent", name = "Cinder Penitent", archetype = "shooter", exactIntent = { mode = "exact", category = "attack", damage = 2, target = "adjacent" }, heatAshGlassVerb = "immolate_cinder" },
            { id = "ember_mote", name = "Ember Mote", archetype = "summoner", exactIntent = { mode = "exact", category = "summon", damage = 1, target = "burn_tile" }, heatAshGlassVerb = "seed_ember" },
            { id = "coal_monk", name = "Coal Monk", archetype = "saboteur", exactIntent = { mode = "exact", category = "debuff", damage = 1, target = "white_coal" }, heatAshGlassVerb = "chant_pressure" },
        },
        elites = {
            { id = "halo_deacon", name = "Halo Deacon", partialIntent = { mode = "category", category = "destroy" }, weakPoints = { "halo_vent" }, burnDouseGlassCounterplay = "douse halo vent before vitrify" },
            { id = "glass_cantor", name = "Glass Cantor", partialIntent = { mode = "category", category = "debuff" }, weakPoints = { "glass_throat" }, burnDouseGlassCounterplay = "shatter reflector then douse shards" },
            { id = "coal_prioress", name = "Coal Prioress", partialIntent = { mode = "category", category = "buff" }, weakPoints = { "white_coal_notch" }, burnDouseGlassCounterplay = "glassify fuel line to starve pressure" },
        },
        alpha = {
            id = "white_furnace",
            name = "White Furnace",
            visiblePreBoard = true,
            preBoardThreat = "lights white coal on one route before entry",
            routeChoiceChange = "burns one fuel branch and opens one ash shortcut",
            boardGenerationChange = "adds heat lanes, a fuel-store fuse, and one meltable bridge",
        },
    },
}

EnemyCatalog.globalPressure = {
    { id = "survey_auditor", name = "Survey Auditor", faction = "survey_office", rareEvent = "audit_route", pressureEffect = "adds redacted intent to next board" },
    { id = "survey_levy_guard", name = "Survey Levy Guard", faction = "survey_office", rareEvent = "asset_seizure", pressureEffect = "guards extraction cargo" },
    { id = "survey_map_burner", name = "Survey Map Burner", faction = "survey_office", rareEvent = "map_confiscation", pressureEffect = "removes one route preview" },
    { id = "lamplighter_defector", name = "Lamplighter Defector", faction = "lamplighter", rareEvent = "stolen_beacon", pressureEffect = "moves hidden-intent reveal farther away" },
    { id = "lamp_claimant", name = "Lamp Claimant", faction = "lamplighter", rareEvent = "claimed_light", pressureEffect = "adds overwatch cone to lit routes" },
    { id = "merchant_collector", name = "Merchant Collector", faction = "merchant", rareEvent = "debt_collection", pressureEffect = "adds AP tax until cargo is paid" },
    { id = "debt_drone", name = "Debt Drone", faction = "merchant", rareEvent = "salvage_escrow", pressureEffect = "steals unclaimed loot on timer" },
    { id = "contract_knight", name = "Contract Knight", faction = "merchant", rareEvent = "called_collateral", pressureEffect = "protects enemy objective with legal cover" },
}

local utilityEffects = {
    archive = "claim, reveal, seal, or reposition records without damage",
    cistern = "shift water, bell pressure, or drain state without damage",
    warrens = "alter heat, ash, glass, or fuel state without damage",
    global = "apply rare-event pressure without damage",
}

local function assignUtility(enemy, familyId)
    if enemy and not enemy.utilityBehavior then
        enemy.utilityBehavior = { id = enemy.id .. "_utility", damage = 0, effect = utilityEffects[familyId] }
    end
end

local function assignExactIntentBlueprint(enemy)
    if not (enemy and enemy.exactIntent and enemy.archetype) then
        return
    end
    local blueprint = EnemyCatalog.exactIntentBlueprints[enemy.archetype] or {}
    local archetype = EnemyCatalog.archetypes[enemy.archetype] or {}
    local intent = enemy.exactIntent
    intent.source = intent.source or "self"
    intent.targetPattern = intent.targetPattern or blueprint.targetPattern
    intent.pathPattern = intent.pathPattern or blueprint.pathPattern
    intent.effect = intent.effect or blueprint.effect
    intent.objectiveImpact = intent.objectiveImpact or blueprint.objectiveImpact
    intent.counterplay = intent.counterplay or blueprint.counterplay
    intent.preview = intent.preview or archetype.preview
    intent.deterministic = intent.deterministic ~= false
    if blueprint.collision and not intent.collision then
        intent.collision = blueprint.collision
    end
end

for familyId, family in pairs(EnemyCatalog.families) do
    for _, enemy in ipairs(family.common or {}) do
        assignExactIntentBlueprint(enemy)
        assignUtility(enemy, familyId)
    end
    for _, enemy in ipairs(family.elites or {}) do
        assignUtility(enemy, familyId)
    end
    assignUtility(family.alpha, familyId)
end

for _, enemy in ipairs(EnemyCatalog.globalPressure) do
    assignUtility(enemy, "global")
end

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

function EnemyCatalog.globalEnemies()
    return EnemyCatalog.globalPressure
end

function EnemyCatalog.archetype(id)
    return EnemyCatalog.archetypes[id]
end

local function zoneVerb(enemy)
    return enemy.boardVerb or enemy.waterPressureVerb or enemy.heatAshGlassVerb
end

function EnemyCatalog.auditArchetypes()
    local report = { ok = true, missing = {}, invalid = {}, coverage = {} }
    local required = {}
    for _, id in ipairs(EnemyCatalog.requiredArchetypes) do
        required[id] = true
        local archetype = EnemyCatalog.archetypes[id]
        if not archetype then
            table.insert(report.missing, "archetype." .. id)
        elseif not (archetype.intent and archetype.boardVerb and archetype.counterplay and archetype.preview) then
            table.insert(report.invalid, "archetype." .. id .. ".metadata")
        end
    end
    for familyId, family in pairs(EnemyCatalog.families) do
        local common = family.common or {}
        if #common < 8 or #common > 12 then
            table.insert(report.invalid, familyId .. ".common.count")
        end
        for _, enemy in ipairs(common) do
            if not enemy.archetype or not required[enemy.archetype] then
                table.insert(report.invalid, enemy.id .. ".archetype")
            elseif not EnemyCatalog.archetypes[enemy.archetype] then
                table.insert(report.invalid, enemy.id .. ".archetype.unknown")
            else
                report.coverage[enemy.archetype] = (report.coverage[enemy.archetype] or 0) + 1
            end
            if not (enemy.exactIntent and enemy.exactIntent.mode == "exact") then
                table.insert(report.invalid, enemy.id .. ".exactIntent")
            end
            if not zoneVerb(enemy) then
                table.insert(report.invalid, enemy.id .. ".zoneVerb")
            end
        end
    end
    for _, id in ipairs(EnemyCatalog.requiredArchetypes) do
        if not report.coverage[id] then
            table.insert(report.missing, "coverage." .. id)
        end
    end
    report.ok = #report.missing == 0 and #report.invalid == 0
    return report
end

function EnemyCatalog.auditExactBasicIntents()
    local report = { ok = true, missing = {}, invalid = {}, coverage = {} }
    for familyId, family in pairs(EnemyCatalog.families) do
        report.coverage[familyId] = 0
        for _, enemy in ipairs(family.common or {}) do
            local intent = enemy.exactIntent
            if not intent then
                table.insert(report.missing, enemy.id .. ".exactIntent")
            elseif intent.mode ~= "exact" then
                table.insert(report.invalid, enemy.id .. ".exactIntent.mode")
            else
                report.coverage[familyId] = report.coverage[familyId] + 1
                if not (intent.source and intent.category and intent.target and intent.damage ~= nil) then
                    table.insert(report.invalid, enemy.id .. ".exactIntent.core")
                end
                if not (intent.targetPattern and intent.pathPattern and intent.effect and intent.preview) then
                    table.insert(report.invalid, enemy.id .. ".exactIntent.preview")
                end
                if not (intent.counterplay and #intent.counterplay > 0) then
                    table.insert(report.invalid, enemy.id .. ".exactIntent.counterplay")
                end
                if intent.objectiveImpact == nil then
                    table.insert(report.invalid, enemy.id .. ".exactIntent.objectiveImpact")
                end
                if intent.deterministic ~= true then
                    table.insert(report.invalid, enemy.id .. ".exactIntent.deterministic")
                end
                if (enemy.archetype == "pusher" or enemy.archetype == "puller") and not intent.collision then
                    table.insert(report.invalid, enemy.id .. ".exactIntent.collision")
                end
            end
        end
    end
    for _, familyId in ipairs({ "archive", "cistern", "warrens" }) do
        if (report.coverage[familyId] or 0) < 8 then
            table.insert(report.missing, familyId .. ".exactIntentCoverage")
        end
    end
    report.ok = #report.missing == 0 and #report.invalid == 0
    return report
end

function EnemyCatalog.allEnemies()
    local enemies = {}
    local seen = {}
    local function add(enemy)
        if enemy and not seen[enemy.id] then
            enemies[#enemies + 1] = enemy
            seen[enemy.id] = true
        end
    end
    for _, familyId in ipairs({ "archive", "cistern", "warrens" }) do
        local family = EnemyCatalog.family(familyId)
        for _, enemy in ipairs(family.common or {}) do
            add(enemy)
        end
        for _, enemy in ipairs(family.elites or {}) do
            add(enemy)
        end
        add(family.alpha)
    end
    for _, enemy in ipairs(EnemyCatalog.globalPressure) do
        add(enemy)
    end
    return enemies
end

return EnemyCatalog
