local ZoneCatalog = {}

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

ZoneCatalog.requiredDestructibleKinds = { "shelf", "bridge", "door" }

ZoneCatalog.zones = {
    buried_archive = {
        tileMechanics = {
            { id = "archive_shelf_shift", subject = "shelves", verb = "shove", effect = "moves full cover and can crush lanes", helpsEitherSide = true },
            { id = "archive_claim_desk", subject = "desks", verb = "claim", effect = "half cover claim tile for hold objectives" },
            { id = "archive_claim_line", subject = "claim lines", verb = "hold", effect = "scores presence while intents escalate" },
            { id = "archive_sealed_door", subject = "sealed doors", verb = "seal_open", effect = "blocks movement and LoS until opened" },
            { id = "archive_witness_drawer", subject = "witness drawers", verb = "reveal", effect = "exposes redacted intent or hidden tile marks" },
            { id = "archive_falling_records", subject = "falling records", verb = "collapse", effect = "delayed fuse creates blocker and damage" },
            { id = "archive_name_lock", subject = "name locks", verb = "disable", effect = "spend AP/tool to open route or objective" },
            { id = "archive_audit_beam", subject = "audit beams", verb = "line", effect = "visible LoS lane pressures movement", helpsEitherSide = true },
            { id = "archive_misfile_pit", subject = "misfile pits", verb = "drop", effect = "forced movement hazard changes elevation" },
            { id = "archive_ledger_bridge", subject = "ledger bridges", verb = "toggle", effect = "opens split-squad crossing dependency" },
            { id = "archive_paper_swarm", subject = "paper swarms", verb = "obscure", effect = "visible obscurant with countdown", helpsEitherSide = true },
            { id = "archive_back_face_seal", subject = "back-face seals", verb = "rotate_reveal", effect = "rotation mark reveals planning fact only" },
        },
        objects = {
            { id = "rolling_shelf", apCost = 2, hp = 5, losEffect = "blocks until shoved or broken", coverState = "full", rotation = "reverse side marks crush lane" },
            { id = "oath_desk", apCost = 1, hp = 3, losEffect = "low blocker after tipped", coverState = "half", rotation = "reverse side marks claim desk" },
            { id = "sealed_stacks_door", apCost = 2, hp = 4, losEffect = "opaque while sealed, open lane after breach", coverState = "none", rotation = "reverse side marks alternate hinge" },
            { id = "witness_drawer_bank", apCost = 1, hp = 2, losEffect = "no block, reveal action source", coverState = "none", rotation = "reverse side marks hidden witness" },
            { id = "record_crate", apCost = 1, hp = 2, losEffect = "becomes half blocker when spilled", coverState = "half", rotation = "reverse side marks falling record arc" },
            { id = "name_lock_plinth", apCost = 2, hp = 3, losEffect = "blocks route node only", coverState = "none", rotation = "reverse side marks true name socket" },
            { id = "audit_lens_stand", apCost = 1, hp = 2, losEffect = "projects visible straight lane", coverState = "none", rotation = "reverse side marks beam bearing" },
            { id = "ledger_bridge_winch", apCost = 2, hp = 4, losEffect = "no block, toggles crossing", coverState = "none", rotation = "reverse side marks bridge latch" },
        },
        rotationFacts = {
            { id = "archive_shelf_weight", fact = "shelf back shows shove weight", planningImpact = "choose crush lane before spending AP", changesState = false },
            { id = "archive_claim_stamp", fact = "desk underside shows claim stamp", planningImpact = "identify hold tile before reveal action", changesState = false },
            { id = "archive_audit_bearing", fact = "audit lens back shows beam bearing", planningImpact = "path around future LoS pressure", changesState = false },
            { id = "archive_name_order", fact = "seal reverse lists name order", planningImpact = "route split squad to correct lock first", changesState = false },
        },
    },
}

ZoneCatalog.destructibleLocationRules = {
    shelf = { zone = "buried_archive", source = "object", objectId = "rolling_shelf", hp = 5, apCost = 2, breakEffect = "clears full-cover LoS blocker and opens crush lane", repairCounterplay = "brace or shove shelf before break", preview = "HP, cover edge, LoS block, crush lane", deterministic = true },
    bridge = { zone = "buried_archive", source = "object", objectId = "ledger_bridge_winch", hp = 4, apCost = 2, breakEffect = "toggles split-squad crossing dependency", repairCounterplay = "lower bridge or route around before collapse", preview = "HP, crossing state, bridge latch", deterministic = true },
    door = { zone = "buried_archive", source = "object", objectId = "sealed_stacks_door", hp = 4, apCost = 2, breakEffect = "opens movement and LoS through sealed route", repairCounterplay = "use hinge or seal-open action before breach", preview = "HP, blocker state, hinge mark", deterministic = true },
}

function ZoneCatalog.zone(id)
    return ZoneCatalog.zones[id]
end

function ZoneCatalog.tileMechanics(zoneId)
    local zone = ZoneCatalog.zone(zoneId)
    return zone and zone.tileMechanics or {}
end

function ZoneCatalog.objects(zoneId)
    local zone = ZoneCatalog.zone(zoneId)
    return zone and zone.objects or {}
end

function ZoneCatalog.rotationFacts(zoneId)
    local zone = ZoneCatalog.zone(zoneId)
    return zone and zone.rotationFacts or {}
end

function ZoneCatalog.destructibleRules()
    return copyValue(ZoneCatalog.destructibleLocationRules)
end

local function hasObject(zoneId, objectId)
    for _, object in ipairs(ZoneCatalog.objects(zoneId)) do
        if object.id == objectId then
            return true
        end
    end
    return false
end

local function hasMechanic(zoneId, objectId)
    for _, mechanic in ipairs(ZoneCatalog.tileMechanics(zoneId)) do
        if mechanic.id == objectId then
            return true
        end
    end
    return false
end

function ZoneCatalog.auditDestructibleLocations()
    local report = { ok = true, missing = {}, invalid = {}, coverage = {} }
    for _, kind in ipairs(ZoneCatalog.requiredDestructibleKinds) do
        local rule = ZoneCatalog.destructibleLocationRules[kind]
        if not rule then
            table.insert(report.missing, kind)
        else
            report.coverage[kind] = rule.objectId
            if not (rule.zone and rule.source and rule.objectId and rule.hp and rule.apCost and rule.breakEffect and rule.repairCounterplay and rule.preview) then
                table.insert(report.invalid, kind .. ".metadata")
            end
            if rule.deterministic ~= true then
                table.insert(report.invalid, kind .. ".deterministic")
            end
            if rule.source == "object" and not hasObject(rule.zone, rule.objectId) then
                table.insert(report.invalid, kind .. ".object")
            elseif rule.source == "mechanic" and not hasMechanic(rule.zone, rule.objectId) then
                table.insert(report.invalid, kind .. ".mechanic")
            elseif rule.source ~= "object" and rule.source ~= "mechanic" and rule.source ~= "objective" then
                table.insert(report.invalid, kind .. ".source")
            end
        end
    end
    report.ok = #report.missing == 0 and #report.invalid == 0
    return report
end

return ZoneCatalog
