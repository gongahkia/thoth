local EnemyCatalog = {}

EnemyCatalog.requiredArchetypes = { "mover", "shooter", "artillery", "puller", "blocker", "summoner", "saboteur", "overwatch" }

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

EnemyCatalog.eliteMaskBlueprints = {
    archive = { mask = "seal", targetPattern = "sealed claim footprint", pathPattern = "audit beam or shelf trace", revealClass = "arcanist", revealAction = "unseal_intent", counterplay = "break seal line", preview = "category icon plus sealed footprint" },
}

EnemyCatalog.families = {
    archive = {
        common = {
            { id = "hollow_guard", name = "Hollow Guard", archetype = "overwatch", exactIntent = { mode = "exact", intentType = "archive_overwatch_lane", category = "attack", damage = 2, target = "nearest" }, boardVerb = "brace_cover" },
            { id = "ink_wretch", name = "Ink Wretch", archetype = "artillery", exactIntent = { mode = "exact", intentType = "ink_line_splash", category = "debuff", damage = 1, target = "line" }, boardVerb = "ink_tile" },
            { id = "bone_scribe", name = "Bone Scribe", archetype = "shooter", exactIntent = { mode = "exact", intentType = "redaction_shot", category = "attack", damage = 2, target = "marked" }, boardVerb = "redact_mark" },
            { id = "gutter_thing", name = "Gutter Thing", archetype = "puller", exactIntent = { mode = "exact", intentType = "cargo_hook_pull", category = "move", damage = 1, target = "pull" }, boardVerb = "hook_cargo" },
            { id = "pale_censer", name = "Pale Censer", archetype = "blocker", exactIntent = { mode = "exact", intentType = "claim_fog_block", category = "debuff", damage = 0, target = "claim_tile" }, boardVerb = "fog_claim" },
            { id = "page_scout", name = "Page Scout", archetype = "mover", exactIntent = { mode = "exact", intentType = "flank_reposition", category = "move", damage = 1, target = "flank" }, boardVerb = "flip_shelf" },
            { id = "writ_bailiff", name = "Writ Bailiff", archetype = "saboteur", exactIntent = { mode = "exact", intentType = "objective_stamp", category = "destroy", damage = 2, target = "objective" }, boardVerb = "stamp_claim" },
            { id = "seal_clerk", name = "Seal Clerk", archetype = "blocker", exactIntent = { mode = "exact", intentType = "door_seal_guard", category = "guard", damage = 0, target = "seal" }, boardVerb = "lock_door" },
            { id = "ledger_hound", name = "Ledger Hound", archetype = "shooter", exactIntent = { mode = "exact", intentType = "carrier_pursuit", category = "attack", damage = 2, target = "carrier" }, boardVerb = "sniff_route" },
            { id = "drawer_mite", name = "Drawer Mite", archetype = "summoner", exactIntent = { mode = "exact", intentType = "record_spill_summon", category = "summon", damage = 1, target = "drawer" }, boardVerb = "spill_records" },
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

EnemyCatalog.sliceEliteSpecData = {
    familyId = "archive",
    eliteId = "shelf_knight",
    boardFixture = "archive_elite_claim",
    role = "partial_intent_pressure",
    preview = "Shelf Knight guards archive claims with a masked footprint and rear-binding weak point",
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

local function zoneCounterplay(enemy)
    return enemy.terrainInteraction or enemy.floodDrainCounterplay or enemy.burnDouseGlassCounterplay
end

local function assignEliteMaskedIntent(enemy, familyId)
    if not (enemy and enemy.partialIntent and enemy.weakPoints and enemy.weakPoints[1]) then
        return
    end
    local blueprint = EnemyCatalog.eliteMaskBlueprints[familyId] or {}
    if not enemy.maskedIntent then
        enemy.maskedIntent = {
            mode = "hiddenFootprint",
            category = enemy.partialIntent.category,
            source = "self",
            mask = blueprint.mask,
            targetPattern = blueprint.targetPattern,
            pathPattern = blueprint.pathPattern,
            revealGate = { weakPoint = enemy.weakPoints[1], class = blueprint.revealClass, action = blueprint.revealAction },
            counterplay = { "expose_weak_point", blueprint.counterplay, zoneCounterplay(enemy) },
            preview = blueprint.preview,
            deterministic = true,
            footprintHidden = true,
        }
    end
end

for familyId, family in pairs(EnemyCatalog.families) do
    for _, enemy in ipairs(family.common or {}) do
        assignExactIntentBlueprint(enemy)
        assignUtility(enemy, familyId)
    end
    for _, enemy in ipairs(family.elites or {}) do
        assignEliteMaskedIntent(enemy, familyId)
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

function EnemyCatalog.elite(familyId, eliteId)
    for _, enemy in ipairs(EnemyCatalog.elites(familyId)) do
        if enemy.id == eliteId then
            return enemy
        end
    end
    return nil
end

function EnemyCatalog.sliceEliteSpec()
    return EnemyCatalog.sliceEliteSpecData
end

function EnemyCatalog.sliceElite()
    local spec = EnemyCatalog.sliceEliteSpecData
    return EnemyCatalog.elite(spec.familyId, spec.eliteId)
end

function EnemyCatalog.auditSliceElite()
    local report = { ok = true, missing = {}, invalid = {} }
    local spec = EnemyCatalog.sliceEliteSpecData
    local enemy = EnemyCatalog.sliceElite()
    if not enemy then
        report.missing[#report.missing + 1] = "sliceElite.enemy"
    else
        if not (spec.familyId == "archive" and spec.eliteId and spec.boardFixture and spec.role and spec.preview) then
            report.invalid[#report.invalid + 1] = "sliceElite.spec"
        end
        if not (enemy.partialIntent and enemy.partialIntent.mode == "category" and enemy.maskedIntent and enemy.maskedIntent.mode == "hiddenFootprint") then
            report.invalid[#report.invalid + 1] = "sliceElite.intent"
        end
        if not (enemy.weakPoints and enemy.weakPoints[1] and enemy.terrainInteraction and enemy.utilityBehavior) then
            report.invalid[#report.invalid + 1] = "sliceElite.counterplay"
        end
    end
    report.ok = #report.missing == 0 and #report.invalid == 0
    return report
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
    for _, familyId in ipairs({ "archive" }) do
        if (report.coverage[familyId] or 0) < 8 then
            table.insert(report.missing, familyId .. ".exactIntentCoverage")
        end
    end
    report.ok = #report.missing == 0 and #report.invalid == 0
    return report
end

function EnemyCatalog.auditArchiveCommonIntentTypes()
    local report = { ok = true, missing = {}, duplicate = {}, count = 0, types = {} }
    for _, enemy in ipairs(EnemyCatalog.common("archive")) do
        local intentType = enemy.exactIntent and enemy.exactIntent.intentType
        if not intentType then
            report.missing[#report.missing + 1] = enemy.id
        elseif report.types[intentType] then
            report.duplicate[#report.duplicate + 1] = intentType
        else
            report.types[intentType] = enemy.id
            report.count = report.count + 1
        end
    end
    report.ok = #report.missing == 0 and #report.duplicate == 0 and report.count == 10
    return report
end

function EnemyCatalog.auditEliteMaskedIntents()
    local report = { ok = true, missing = {}, invalid = {}, coverage = {} }
    for familyId, family in pairs(EnemyCatalog.families) do
        report.coverage[familyId] = 0
        for _, enemy in ipairs(family.elites or {}) do
            local partial = enemy.partialIntent
            local masked = enemy.maskedIntent
            if not partial then
                table.insert(report.missing, enemy.id .. ".partialIntent")
            elseif partial.mode ~= "category" or not partial.category then
                table.insert(report.invalid, enemy.id .. ".partialIntent")
            end
            if not masked then
                table.insert(report.missing, enemy.id .. ".maskedIntent")
            elseif masked.mode ~= "hiddenFootprint" then
                table.insert(report.invalid, enemy.id .. ".maskedIntent.mode")
            else
                report.coverage[familyId] = report.coverage[familyId] + 1
                if partial and masked.category ~= partial.category then
                    table.insert(report.invalid, enemy.id .. ".maskedIntent.category")
                end
                if not (masked.source and masked.mask and masked.targetPattern and masked.pathPattern and masked.preview) then
                    table.insert(report.invalid, enemy.id .. ".maskedIntent.preview")
                end
                if not (masked.revealGate and masked.revealGate.weakPoint and masked.revealGate.class and masked.revealGate.action) then
                    table.insert(report.invalid, enemy.id .. ".maskedIntent.revealGate")
                elseif masked.revealGate.weakPoint ~= enemy.weakPoints[1] then
                    table.insert(report.invalid, enemy.id .. ".maskedIntent.weakPoint")
                end
                if not (masked.counterplay and #masked.counterplay >= 2) then
                    table.insert(report.invalid, enemy.id .. ".maskedIntent.counterplay")
                end
                if masked.deterministic ~= true or masked.footprintHidden ~= true then
                    table.insert(report.invalid, enemy.id .. ".maskedIntent.flags")
                end
                if not zoneCounterplay(enemy) then
                    table.insert(report.invalid, enemy.id .. ".zoneCounterplay")
                end
            end
        end
    end
    for _, familyId in ipairs({ "archive" }) do
        if (report.coverage[familyId] or 0) ~= #EnemyCatalog.elites(familyId) then
            table.insert(report.missing, familyId .. ".maskedIntentCoverage")
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
    for _, familyId in ipairs({ "archive" }) do
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
