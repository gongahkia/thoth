local Grid = require("src.core.grid")
local Cover = require("src.game.tactics.cover")

local State = {}
State.__index = State

local commands = {}

local function expect(value, message)
    if not value then
        error(message, 3)
    end
    return value
end

local function isInteger(value)
    return type(value) == "number" and value % 1 == 0
end

local function expectInteger(value, name)
    expect(isInteger(value), name .. " must be an integer")
    return value
end

local function copyList(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[#result + 1] = value
    end
    return result
end

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

local function copyMap(values)
    local result = {}
    for key, value in pairs(values or {}) do
        result[key] = copyValue(value)
    end
    return result
end

local collisionRules = {
    blockedTile = { result = "stop", movedUnitDamage = true, occupantDamage = false, objectiveDamage = false, deterministic = true },
    occupiedTile = { result = "stop", movedUnitDamage = true, occupantDamage = true, friendlyFire = true, objectiveDamage = false, deterministic = true },
    objectiveTile = { result = "enter", movedUnitDamage = false, occupantDamage = false, objectiveDamage = true, deterministic = true },
    threatZoneAfterStep = { result = "enter", triggerThreatZone = true, deterministic = true },
}

function State.collisionRules()
    return copyValue(collisionRules)
end

local function tileKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local oppositeDirection = {
    north = "south",
    east = "west",
    south = "north",
    west = "east",
}

local function normalizeCoverEdges(edges)
    local result = {}
    for _, direction in ipairs(Grid.order) do
        local value = (edges and edges[direction]) or "none"
        expect(value == "none" or value == "half" or value == "full", "invalid cover edge " .. tostring(value))
        result[direction] = value
    end
    return result
end

local function normalizeRotationMarks(marks)
    local result = {}
    for _, direction in ipairs(Grid.order) do
        if marks and marks[direction] ~= nil then
            result[direction] = marks[direction]
        end
    end
    return result
end

local function emptyCoverEdges()
    return normalizeCoverEdges()
end

local blockerKinds = {
    none = { blocker = false, losBlocker = false },
    hard = { blocker = true, losBlocker = true },
    low = { blocker = true, losBlocker = false, low = true },
    transparent = { blocker = true, losBlocker = false, transparent = true },
    destructible = { blocker = true, losBlocker = true, destructible = true },
    mobile = { blocker = true, losBlocker = false, mobile = true },
}

local obscurantKinds = {
    smoke = true,
    salt_mist = true,
    ash_cloud = true,
    index_miasma = true,
}

local function inferBlockerKind(tile, destructibleHp)
    local kind = tile.blockerKind or tile.blockerType
    if kind then
        expect(blockerKinds[kind], "invalid blocker kind " .. tostring(kind))
        return kind
    end
    if destructibleHp ~= nil and tile.blocker == true then
        return "destructible"
    end
    if tile.blocker == true and tile.losBlocker == true then
        return "hard"
    end
    if tile.blocker == true then
        return "low"
    end
    return "none"
end

local function normalizeTile(tile)
    tile = tile or {}
    local destructibleHp = tile.destructibleHp
    if destructibleHp == nil then
        destructibleHp = tile.hp
    end
    local blockerKind = inferBlockerKind(tile, destructibleHp)
    local blockerRule = blockerKinds[blockerKind]
    local blocker = tile.blocker
    if blocker == nil then
        blocker = blockerRule.blocker
    end
    local losBlocker = tile.losBlocker
    if losBlocker == nil then
        losBlocker = blockerRule.losBlocker
    end
    local moveCost = tile.moveCost or tile.apCost
    if moveCost ~= nil then
        moveCost = expectInteger(moveCost, "tile move cost")
        expect(moveCost >= 0, "tile move cost must be non-negative")
    end
    return {
        kind = tile.kind or tile.id or "floor",
        material = tile.material or tile.zoneMaterial or "archive",
        state = tile.state,
        terrainType = tile.terrainType,
        generationTechnique = tile.generationTechnique,
        height = expectInteger(tile.height or 0, "tile height"),
        moveCost = moveCost,
        coverEdges = normalizeCoverEdges(tile.coverEdges or tile.cover),
        blockerKind = blockerKind,
        blocker = blocker == true,
        losBlocker = losBlocker == true,
        destructibleHp = destructibleHp,
        hazard = copyMap(tile.hazard),
        objective = copyMap(tile.objective),
        interact = copyMap(tile.interact),
        revealed = tile.revealed ~= false,
        destroyed = tile.destroyed == true,
        rotationMarks = normalizeRotationMarks(tile.rotationMarks or tile.marks),
        revealClasses = copyList(tile.revealClasses),
        revealActions = copyList(tile.revealActions),
        weakPoint = tile.weakPoint,
        weakPointRevealed = tile.weakPointRevealed == true,
        terrainInteraction = tile.terrainInteraction,
        alphaTerrain = tile.alphaTerrain,
        collapseHeight = tile.collapseHeight,
        collapseKind = tile.collapseKind,
        tags = copyList(tile.tags),
    }
end

local function normalizeTileList(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[#result + 1] = { x = expectInteger(value.x, "tile x"), y = expectInteger(value.y, "tile y") }
    end
    return result
end

local function normalizeRotationList(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        local rotation = expectInteger(value, "reveal rotation")
        expect(rotation >= 0 and rotation <= 3, "reveal rotation must be 0-3")
        result[#result + 1] = rotation
    end
    return result
end

local function listHas(values, needle)
    for _, value in ipairs(values or {}) do
        if value == needle then
            return true
        end
    end
    return false
end

local heightRuleTags = {
    "height_band",
    "raised_archive_walk",
    "monument_stack",
    "expanse_path",
    "vertical_route",
    "ascent_route",
    "descent_route",
    "monument_stair",
}

local function hasHeightRuleTag(tile)
    for _, tag in ipairs(heightRuleTags) do
        if listHas(tile.tags, tag) then
            return true
        end
    end
    return false
end

local intentCategories = {
    attack = true,
    move = true,
    guard = true,
    summon = true,
    repair = true,
    destroy = true,
    buff = true,
    debuff = true,
    flee = true,
    redacted = true,
}

local intentModes = {
    exact = true,
    category = true,
    hiddenFootprint = true,
    bossStage = true,
    fuse = true,
    conditional = true,
    decoy = true,
}

local fuseTriggerKinds = {
    damage = true,
    damageObjective = true,
    repairObjective = true,
    convertTile = true,
    status = true,
}

local conditionKinds = {
    targetMoved = true,
    targetOnTile = true,
    otherwise = true,
}

local interruptKinds = {
    stun = true,
    shove = true,
    losBreak = true,
    coverRaise = true,
    seal = true,
    hack = true,
    douse = true,
    drain = true,
    exposeWeakPoint = true,
}

local function normalizeFuseAnchor(anchor)
    anchor = anchor or {}
    local kind = anchor.kind or anchor.type or (anchor.x and "tile") or (anchor.object and "object") or (anchor.enemy and "enemy") or (anchor.unit and "unit")
    if not kind then
        return {}
    end
    expect(kind == "tile" or kind == "object" or kind == "objective" or kind == "enemy" or kind == "unit", "unsupported fuse anchor " .. tostring(kind))
    if kind == "tile" then
        return { kind = kind, x = expectInteger(anchor.x, "fuse anchor x"), y = expectInteger(anchor.y, "fuse anchor y") }
    end
    local id = anchor.id or anchor.object or anchor.objective or anchor.enemy or anchor.unit
    expect(type(id) == "string" and id ~= "", "fuse anchor id required")
    return { kind = kind, id = id }
end

local function normalizeFuseTrigger(trigger)
    trigger = trigger or {}
    local kind = trigger.kind or trigger.type or "damage"
    expect(fuseTriggerKinds[kind], "unsupported fuse trigger " .. tostring(kind))
    local result = {
        kind = kind,
        damage = trigger.damage or 0,
        target = trigger.target,
        objective = trigger.objective,
        conversion = trigger.conversion,
        status = trigger.status,
        turns = trigger.turns,
        amount = trigger.amount,
        effect = trigger.effect,
        targetTiles = normalizeTileList(trigger.tiles or trigger.targetTiles),
    }
    if kind == "damageObjective" then
        expect(type(result.objective) == "string" and result.objective ~= "", "fuse objective required")
    elseif kind == "repairObjective" then
        expect(type(result.objective) == "string" and result.objective ~= "", "fuse objective required")
        result.amount = trigger.amount or trigger.repair or 1
    elseif kind == "convertTile" then
        expect(type(result.conversion) == "string" and result.conversion ~= "", "fuse conversion required")
        expect(#result.targetTiles > 0, "fuse conversion needs target tiles")
    elseif kind == "status" then
        expect(type(result.target) == "string" and result.target ~= "", "fuse status target required")
        expect(type(result.status) == "string" and result.status ~= "", "fuse status required")
    end
    return result
end

local function normalizeCondition(condition)
    if type(condition) == "string" then
        condition = { kind = condition }
    end
    condition = condition or { kind = "otherwise" }
    local kind = condition.kind or condition.type or condition.when
    expect(conditionKinds[kind], "unsupported intent condition " .. tostring(kind))
    local result = {
        kind = kind,
        target = condition.target,
    }
    if condition.from then
        result.from = { x = expectInteger(condition.from.x, "condition from x"), y = expectInteger(condition.from.y, "condition from y") }
    end
    if kind == "targetMoved" then
        expect(type(result.target) == "string" and result.target ~= "", "targetMoved condition target required")
    elseif kind == "targetOnTile" then
        expect(type(result.target) == "string" and result.target ~= "", "targetOnTile condition target required")
        result.x = expectInteger(condition.x, "condition x")
        result.y = expectInteger(condition.y, "condition y")
    end
    return result
end

local function normalizeBranchIntent(intent)
    intent = intent or {}
    local mode = intent.mode or "exact"
    expect(intentModes[mode] and mode ~= "conditional", "invalid branch intent mode " .. tostring(mode))
    local category = intent.category or "attack"
    expect(intentCategories[category], "invalid intent category " .. tostring(category))
    return {
        mode = mode,
        intentType = intent.intentType,
        category = category,
        target = intent.target,
        targetTiles = normalizeTileList(intent.tiles or intent.targetTiles),
        path = normalizeTileList(intent.path),
        damage = intent.damage or 0,
        effect = intent.effect,
        statusEffect = copyMap(intent.statusEffect),
        objectiveImpact = intent.objectiveImpact,
        trigger = copyMap(intent.trigger),
    }
end

local function normalizeConditionalBranches(intent)
    local sourceBranches = intent.branches
    if not sourceBranches then
        sourceBranches = {
            { condition = intent.condition or intent.when, intent = intent.ifTrue or intent.thenIntent, trigger = intent.thenTrigger },
            { condition = "otherwise", intent = intent.otherwise or intent.elseIntent, trigger = intent.elseTrigger },
        }
    end
    local branches = {}
    local hasOtherwise = false
    for _, branch in ipairs(sourceBranches or {}) do
        local branchIntent = normalizeBranchIntent(branch.intent or branch.preview or branch)
        local condition = normalizeCondition(branch.condition or branch.when)
        if condition.kind == "otherwise" then
            hasOtherwise = true
        end
        local branchTrigger = normalizeFuseTrigger(branch.trigger or branchIntent.trigger)
        expect(#branchIntent.targetTiles > 0 or #branchTrigger.targetTiles > 0 or branchTrigger.target or branchTrigger.objective, "conditional branch needs target or trigger")
        branches[#branches + 1] = {
            condition = condition,
            intent = branchIntent,
            trigger = branchTrigger,
            label = branch.label,
        }
    end
    expect(#branches >= 2, "conditional intent needs at least two branches")
    expect(hasOtherwise, "conditional intent needs otherwise branch")
    return branches
end

local function normalizeIntentPressure(rule)
    if not rule then
        return nil
    end
    return {
        after = rule.after or 1,
        every = rule.every or 1,
        damageDelta = rule.damageDelta or rule.damage,
        countdownDelta = rule.countdownDelta or rule.countdown,
        category = rule.category,
        effect = rule.effect,
        remove = rule.remove == true,
        removeAtZeroDamage = rule.removeAtZeroDamage == true,
    }
end

local function normalizeBossMasks(masks)
    local result = {}
    for _, mask in ipairs(masks or {}) do
        local entry = {
            mask = mask.mask,
            phase = mask.phase,
            turn = mask.turn,
            rotation = mask.rotation,
            revealRotation = mask.revealRotation,
            weakPoint = mask.weakPoint,
            stage = mask.stage,
            stageCount = mask.stageCount,
            revealed = mask.revealed == true,
            targetTiles = normalizeTileList(mask.tiles or mask.targetTiles),
        }
        if entry.rotation ~= nil then
            entry.rotation = expectInteger(entry.rotation, "boss mask rotation")
        end
        if entry.revealRotation ~= nil then
            entry.revealRotation = expectInteger(entry.revealRotation, "boss mask reveal rotation")
        end
        expect(entry.mask or entry.revealed, "boss mask needs mask or reveal")
        result[#result + 1] = entry
    end
    return result
end

local function normalizeIntent(intent)
    expect(type(intent) == "table", "intent must be a table")
    local mode = intent.mode or "exact"
    expect(intentModes[mode], "invalid intent mode " .. tostring(mode))
    local category = intent.category or (mode == "hiddenFootprint" and "redacted") or "attack"
    expect(intentCategories[category], "invalid intent category " .. tostring(category))
    local tiles = normalizeTileList(intent.tiles or intent.targetTiles)
    if mode == "exact" then
        expect(#tiles > 0, "exact intent needs target tiles")
    end
    if mode == "hiddenFootprint" then
        expect(#tiles > 0, "hidden footprint intent needs private target tiles")
    end
    local countdown = intent.countdown or intent.fuse
    local trigger = nil
    local anchor = nil
    if mode == "fuse" then
        countdown = expectInteger(countdown, "fuse countdown")
        expect(countdown >= 0, "fuse countdown must be non-negative")
        trigger = normalizeFuseTrigger(intent.trigger)
        anchor = normalizeFuseAnchor(intent.anchor)
        expect(#tiles > 0 or #trigger.targetTiles > 0 or trigger.target or trigger.objective, "fuse intent needs target or trigger")
    end
    local branches = nil
    if mode == "conditional" then
        branches = normalizeConditionalBranches(intent)
    end
    local revealRotations = normalizeRotationList(intent.revealRotations)
    local revealActions = copyList(intent.revealActions)
    local revealClasses = copyList(intent.revealClasses)
    local counterplay = copyList(intent.counterplay)
    local decoy = nil
    local actual = nil
    if mode == "decoy" then
        expect(type(intent.decoy) == "table" or type(intent.preview) == "table", "decoy intent needs false preview")
        expect(type(intent.actual) == "table" or type(intent.trueIntent) == "table", "decoy intent needs actual intent")
        decoy = normalizeBranchIntent(intent.decoy or intent.preview)
        actual = normalizeBranchIntent(intent.actual or intent.trueIntent)
        expect(#revealRotations > 0 or #revealActions > 0 or #revealClasses > 0 or #counterplay > 0, "decoy intent needs reveal or counterplay")
    end
    return {
        mode = mode,
        intentType = intent.intentType,
        category = category,
        source = intent.source,
        sourceTile = copyMap(intent.sourceTile),
        target = intent.target,
        targetTiles = tiles,
        path = normalizeTileList(intent.path),
        damage = intent.damage or 0,
        effect = intent.effect,
        collision = copyMap(intent.collision),
        statusEffect = copyMap(intent.statusEffect),
        objectiveImpact = intent.objectiveImpact,
        countdown = countdown,
        anchor = anchor,
        trigger = trigger,
        branches = branches,
        decoy = decoy,
        actual = actual,
        counterplay = counterplay,
        revealed = intent.revealed == true,
        ignoredTurns = intent.ignoredTurns or 0,
        escalation = normalizeIntentPressure(intent.escalation),
        decay = normalizeIntentPressure(intent.decay),
        revealRotations = revealRotations,
        revealActions = revealActions,
        revealClasses = revealClasses,
        stage = intent.stage,
        stageCount = intent.stageCount,
        mask = intent.mask,
        phase = intent.phase,
        turn = intent.turn,
        weakPoint = intent.weakPoint,
        masks = normalizeBossMasks(intent.masks),
        label = intent.label,
    }
end

local function shouldRevealIntentFootprint(intent, options)
    if intent.revealed == true then
        return true
    end
    if options == true or options.reveal == true then
        return true
    end
    local rotation = options.rotation
    if rotation == nil then
        rotation = options.viewRotation
    end
    if rotation ~= nil and listHas(intent.revealRotations, rotation % 4) then
        return true
    end
    if listHas(intent.revealActions, options.revealAction) then
        return true
    end
    if listHas(intent.revealClasses, options.revealClass) then
        return true
    end
    return false
end

local objectiveKinds = {
    protect_route_machinery = "protect",
    protect_route_machine = "protect",
    protect_enclave_shelter = "protect",
    protect_archive_shelf = "protect",
    protect_civilian_cell = "protect",
    protect_pressure_node = "protect",
    extract_record = "extract",
    extract_civilian = "extract",
    extract_body = "extract",
    extract_machine_core = "extract",
    extract_ledger = "extract",
    extract_fuel = "extract",
    extract_medicine = "extract",
    extract_witness = "extract",
    disable_seal = "disable",
    disable_bell = "disable",
    disable_valve = "disable",
    disable_kiln = "disable",
    disable_audit_lens = "disable",
    repair_cover = "repair",
    repair_machinery = "repair",
    repair_floodgate = "repair",
    repair_bridge = "repair",
    repair_ward = "repair",
    hold_claim = "hold",
    evacuate_board = "evacuate",
    split_switch = "split",
    stealth_read = "stealth",
    sacrifice_choice = "sacrifice",
    boss_procedure = "boss",
}

local sliceObjectiveTypeOrder = { "protect", "extract", "disable" }

local sliceObjectiveTypes = {
    protect = {
        id = "protect",
        kind = "protect_archive_shelf",
        command = "damageObjective",
        boardFixture = "archive_shelf_protection",
        preview = "keep archive shelf integrity above zero",
        counterplay = "brace, body block, repair, or redirect posted objective damage",
        success = "objective survives the pressure clock",
        failure = "integrity reaches zero",
    },
    extract = {
        id = "extract",
        kind = "extract_record",
        cargoKind = "record",
        command = "extractObjective",
        boardFixture = "archive_proof_extract",
        preview = "carry proof to the evacuation edge",
        counterplay = "clear route, carry cargo, block spawns, and extract before collapse",
        success = "objective is extracted",
        failure = "cargo or route integrity fails before extraction",
    },
    disable = {
        id = "disable",
        kind = "disable_audit_lens",
        command = "disableObjective",
        boardFixture = "archive_sealed_shortcut",
        preview = "disable audit lens before it locks the shortcut",
        counterplay = "reach interact tile, break LoS, smoke the claim, or spend disable AP",
        success = "objective is disabled",
        failure = "lens remains active through the pressure clock",
    },
}

local function normalizeObjective(objective, index)
    expect(type(objective) == "table", "objective must be a table")
    local id = objective.id or ("objective_" .. tostring(index))
    expect(type(id) == "string" and id ~= "", "objective id must be a non-empty string")
    local kind = objective.kind or "protect_route_machinery"
    expect(objectiveKinds[kind], "unsupported objective kind " .. tostring(kind))
    local integrity = objective.integrity or objective.maxIntegrity or 1
    local evacuateAt = objective.evacuateAt or objective.exit
    expect(evacuateAt and evacuateAt.x and evacuateAt.y, "objective needs evacuation tile")
    return {
        id = id,
        kind = kind,
        family = objective.family or objectiveKinds[kind],
        x = expectInteger(objective.x, "objective x"),
        y = expectInteger(objective.y, "objective y"),
        integrity = integrity,
        maxIntegrity = objective.maxIntegrity or integrity,
        evacuateAt = { x = expectInteger(evacuateAt.x, "evacuation x"), y = expectInteger(evacuateAt.y, "evacuation y") },
        evacuationsRequired = objective.evacuationsRequired or 1,
        evacuatedUnits = copyList(objective.evacuatedUnits),
        requiredTurns = objective.requiredTurns or objective.turnsRequired,
        heldTurns = objective.heldTurns or 0,
        escalateIntents = objective.escalateIntents == true,
        minUnits = objective.minUnits,
        minObjectives = objective.minObjectives,
        boardCollapseIn = objective.boardCollapseIn,
        switches = copyValue(objective.switches),
        requiredReads = objective.requiredReads,
        readCount = objective.readCount or 0,
        exposureCap = objective.exposureCap,
        choices = copyValue(objective.choices),
        choice = objective.choice,
        ritualSteps = copyValue(objective.ritualSteps or objective.steps),
        factionStandingDelta = objective.factionStandingDelta,
        lootLost = objective.lootLost,
        extracted = objective.extracted == true,
        disabled = objective.disabled == true,
        relocated = objective.relocated == true,
        sacrificed = objective.sacrificed == true,
        allowPartial = objective.allowPartial == true,
        failureCarryover = copyMap(objective.failureCarryover),
        complete = objective.complete == true,
        failed = objective.failed == true,
    }
end

function State.objectiveTypes()
    local result = {}
    for _, id in ipairs(sliceObjectiveTypeOrder) do
        result[#result + 1] = copyValue(sliceObjectiveTypes[id])
    end
    return result
end

function State.objectiveType(id)
    local objectiveType = sliceObjectiveTypes[id]
    return objectiveType and copyValue(objectiveType) or nil
end

function State.auditObjectiveTypes()
    local report = { valid = true, missing = {} }
    local seen = {}
    if #sliceObjectiveTypeOrder ~= 3 then
        report.valid = false
        table.insert(report.missing, "objectiveType.count")
    end
    for _, id in ipairs(sliceObjectiveTypeOrder) do
        local objectiveType = sliceObjectiveTypes[id]
        if seen[id] then
            report.valid = false
            table.insert(report.missing, id .. ".duplicate")
        end
        seen[id] = true
        if not objectiveType then
            report.valid = false
            table.insert(report.missing, id)
        else
            if objectiveType.id ~= id or objectiveKinds[objectiveType.kind] ~= id then
                report.valid = false
                table.insert(report.missing, id .. ".kind")
            end
            if not objectiveType.command or not objectiveType.boardFixture or not objectiveType.preview or not objectiveType.counterplay or not objectiveType.success or not objectiveType.failure then
                report.valid = false
                table.insert(report.missing, id .. ".metadata")
            end
        end
    end
    for _, id in ipairs({ "protect", "extract", "disable" }) do
        if not seen[id] then
            report.valid = false
            table.insert(report.missing, id .. ".missing")
        end
    end
    return report
end

local cargoKinds = {
    record = true,
    civilian = true,
    body = true,
    machine_core = true,
    machinery_core = true,
    ledger = true,
    fuel = true,
    medicine = true,
    witness = true,
    loot_crate = true,
    wounded_hero = true,
}

local cargoDefaultWeight = {
    record = 1,
    civilian = 1,
    body = 1,
    machine_core = 2,
    machinery_core = 2,
    ledger = 1,
    fuel = 2,
    medicine = 1,
    witness = 1,
    loot_crate = 2,
    wounded_hero = 1,
}

local interactionKinds = {
    valve = true,
    door = true,
    seal = true,
    shelf = true,
    furnace = true,
    bridge = true,
    terminal = true,
    bell = true,
    extraction = true,
}

local terrainConversions = {
    flood = true,
    drain = true,
    burn = true,
    ash_choke = true,
    glassify = true,
    collapse = true,
    raise_cover = true,
    lower_cover = true,
    seal_tile = true,
    open_tile = true,
    bend_los = true,
}

local rewardKinds = {
    tool_unlock = true,
    class_option = true,
    route_option = true,
    interact_option = true,
    scout_option = true,
    cargo_option = true,
}

local statusRules = {
    marked = { amount = 1 },
    exposed = { amount = 1 },
    pinned = {},
    bound = {},
    burning = { amount = 1, tickDamage = true },
    flooded = { amount = 1, tickDamage = true },
    corroded = { amount = 1, tickDamage = true },
    guarded = { amount = 1 },
    shredded = { amount = 1 },
    anchored = {},
    jammed = {},
    filed = {},
    redacted = {},
    sealed = {},
    stunned = {},
    blinded = {},
    braced = { amount = 1 },
    stabilized = {},
    ghosted = {},
}

local function normalizeStatuses(statuses)
    local result = {}
    for key, value in pairs(statuses or {}) do
        local status = type(value) == "table" and value or { turns = value }
        expect(statusRules[key] or statusRules[status.kind], "unsupported status " .. tostring(key))
        local kind = status.kind or key
        result[kind] = {
            kind = kind,
            turns = status.turns,
            amount = status.amount,
        }
    end
    return result
end

local function normalizeCargo(cargo, index)
    expect(type(cargo) == "table", "cargo must be a table")
    local id = cargo.id or ("cargo_" .. tostring(index))
    local kind = cargo.kind or "loot_crate"
    expect(type(id) == "string" and id ~= "", "cargo id must be a non-empty string")
    expect(cargoKinds[kind], "unsupported cargo kind " .. tostring(kind))
    local integrity = cargo.integrity or cargo.maxIntegrity
    return {
        id = id,
        kind = kind,
        x = expectInteger(cargo.x, "cargo x"),
        y = expectInteger(cargo.y, "cargo y"),
        weight = cargo.weight or cargoDefaultWeight[kind] or 1,
        integrity = integrity,
        maxIntegrity = cargo.maxIntegrity or integrity,
        carriedBy = cargo.carriedBy,
        extracted = cargo.extracted == true,
        failed = cargo.failed == true,
        tags = copyList(cargo.tags),
    }
end

local function normalizeUnit(unit, index, defaultAp)
    expect(type(unit) == "table", "unit must be a table")
    local id = unit.id or ("unit_" .. tostring(index))
    expect(type(id) == "string" and id ~= "", "unit id must be a non-empty string")
    local maxAp = unit.maxAp or unit.apMax or defaultAp or 2
    local visionRadius = expectInteger(unit.visionRadius or 8, "unit vision radius")
    expect(visionRadius >= 0, "unit vision radius must be non-negative")
    return {
        id = id,
        name = unit.name,
        kind = unit.kind,
        role = unit.role,
        archetype = unit.archetype,
        boardVerb = unit.boardVerb,
        spawnPocket = unit.spawnPocket,
        intentType = unit.intentType,
        intent = copyValue(unit.intent),
        partialIntent = copyValue(unit.partialIntent),
        maskedIntent = copyValue(unit.maskedIntent),
        weakPoints = copyList(unit.weakPoints),
        terrainInteraction = unit.terrainInteraction,
        class = unit.class,
        className = unit.className,
        side = unit.side or "player",
        x = expectInteger(unit.x, "unit x"),
        y = expectInteger(unit.y, "unit y"),
        hp = unit.hp or 1,
        maxHp = unit.maxHp or unit.hp or 1,
        maxAp = maxAp,
        ap = unit.ap ~= nil and unit.ap or maxAp,
        visionRadius = visionRadius,
        alive = unit.alive ~= false,
        evacuated = unit.evacuated == true,
        carryingObjective = unit.carryingObjective,
        carryingCargo = unit.carryingCargo,
        loadouts = copyValue(unit.loadouts),
        boardVerbs = copyList(unit.boardVerbs),
        tools = copyList(unit.tools),
        catalogBoardVerbs = copyList(unit.catalogBoardVerbs),
        statuses = normalizeStatuses(unit.statuses),
        tags = copyList(unit.tags),
    }
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function State.new(options)
    options = options or {}
    local board = options.board or options
    local width = expectInteger(board.width, "board width")
    local height = expectInteger(board.height, "board height")
    expect(width > 0 and height > 0, "board size must be positive")
    local state = setmetatable({
        tick = options.tick or 0,
        phase = options.phase or "player",
        exposure = options.exposure or 0,
        selectedUnitId = options.selectedUnitId,
        unlocks = copyMap(options.unlocks),
        rules = {
            defaultAp = options.defaultAp or options.apPerTurn or (options.rules and options.rules.defaultAp) or 2,
            moveApCost = options.moveApCost or (options.rules and options.rules.moveApCost) or 1,
            flanking = Cover.flankingRule(options.flanking or (options.rules and options.rules.flanking)),
        },
        board = {
            width = width,
            height = height,
            expanse = board.expanse == true,
            regions = copyValue(board.regions),
            districts = copyValue(board.districts),
            softGates = copyValue(board.softGates),
            landmarks = copyValue(board.landmarks),
            metrics = copyValue(board.metrics),
            heightBands = copyValue(board.heightBands),
            coverFields = copyValue(board.coverFields),
            sightBreaks = copyValue(board.sightBreaks),
            verticalRoutes = copyValue(board.verticalRoutes),
            sightlines = copyValue(board.sightlines),
            megaStructures = copyValue(board.megaStructures),
            terrainTypes = copyValue(board.terrainTypes),
            generationTechniques = copyValue(board.generationTechniques),
            tiles = {},
        },
        units = {},
        unitOrder = {},
        threatZones = copyMap(options.threatZones),
        intents = {},
        objectives = {},
        objectiveOrder = {},
        cargo = {},
        cargoOrder = {},
        pending = {},
        log = copyList(options.log),
    }, State)
    for key, tile in pairs(board.tiles or {}) do
        state.board.tiles[key] = normalizeTile(tile)
    end
    for index, unit in ipairs(options.units or {}) do
        local normalized = normalizeUnit(unit, index, state.rules.defaultAp)
        expect(state:inBounds(normalized.x, normalized.y), "unit " .. normalized.id .. " starts out of bounds")
        expect(not state:unitAt(normalized.x, normalized.y), "unit " .. normalized.id .. " starts on occupied tile")
        state.units[normalized.id] = normalized
        state.unitOrder[#state.unitOrder + 1] = normalized.id
    end
    if state.selectedUnitId then
        expect(state.units[state.selectedUnitId], "selected unit does not exist")
    end
    for unitId, intent in pairs(options.intents or {}) do
        state.intents[unitId] = normalizeIntent(intent)
    end
    for index, objective in ipairs(options.objectives or {}) do
        local normalized = normalizeObjective(objective, index)
        expect(state:inBounds(normalized.x, normalized.y), "objective " .. normalized.id .. " starts out of bounds")
        expect(state:inBounds(normalized.evacuateAt.x, normalized.evacuateAt.y), "objective " .. normalized.id .. " evacuation tile out of bounds")
        state.objectives[normalized.id] = normalized
        state.objectiveOrder[#state.objectiveOrder + 1] = normalized.id
    end
    for index, cargo in ipairs(options.cargo or {}) do
        local normalized = normalizeCargo(cargo, index)
        expect(state:inBounds(normalized.x, normalized.y), "cargo " .. normalized.id .. " starts out of bounds")
        if normalized.carriedBy then
            expect(state.units[normalized.carriedBy], "cargo carrier does not exist")
            state.units[normalized.carriedBy].carryingCargo = normalized.id
        end
        state.cargo[normalized.id] = normalized
        state.cargoOrder[#state.cargoOrder + 1] = normalized.id
    end
    return state
end

function State.fromSnapshot(snapshot)
    expect(type(snapshot) == "table", "snapshot must be a table")
    return State.new({
        tick = snapshot.tick or 0,
        phase = snapshot.phase or "player",
        exposure = snapshot.exposure or 0,
        selectedUnitId = snapshot.selectedUnitId,
        unlocks = snapshot.unlocks or {},
        rules = snapshot.rules,
        board = snapshot.board or { width = snapshot.width, height = snapshot.height, tiles = snapshot.tiles },
        units = snapshot.units or {},
        threatZones = snapshot.threatZones or {},
        intents = snapshot.intents or {},
        objectives = snapshot.objectives or {},
        cargo = snapshot.cargo or {},
        log = snapshot.log or {},
    })
end

function State:inBounds(x, y)
    return isInteger(x) and isInteger(y) and x >= 1 and y >= 1 and x <= self.board.width and y <= self.board.height
end

function State:tileAt(x, y)
    expect(self:inBounds(x, y), "tile out of bounds")
    return self.board.tiles[tileKey(x, y)] or normalizeTile()
end

function State:blockerAt(x, y)
    local tile = self:tileAt(x, y)
    local rule = blockerKinds[tile.blockerKind] or blockerKinds.none
    return {
        x = x,
        y = y,
        kind = tile.blockerKind,
        movement = tile.blocker == true,
        los = tile.losBlocker == true,
        low = rule.low == true,
        transparent = rule.transparent == true,
        destructible = rule.destructible == true or tile.destructibleHp ~= nil,
        mobile = rule.mobile == true,
        hp = tile.destructibleHp,
    }
end

local function rotationDirection(rotation)
    rotation = expectInteger(rotation or 0, "view rotation") % 4
    return Grid.order[rotation + 1]
end

function State:rotationMarkAt(x, y, rotation)
    local direction = rotationDirection(rotation)
    local mark = self:tileAt(x, y).rotationMarks[direction]
    return { x = x, y = y, direction = direction, mark = mark, visible = mark ~= nil }
end

function State:visibleRotationMarks(rotation)
    local result = {}
    for key, tile in pairs(self.board.tiles) do
        local x, y = key:match("^(%-?%d+):(%-?%d+)$")
        if x and y then
            local mark = tile.rotationMarks[rotationDirection(rotation)]
            if mark ~= nil then
                result[#result + 1] = { x = tonumber(x), y = tonumber(y), mark = mark, direction = rotationDirection(rotation) }
            end
        end
    end
    table.sort(result, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)
    return result
end

function State:unit(id)
    return self.units[id]
end

function State:unitsForSide(side)
    local result = {}
    for _, id in ipairs(self.unitOrder) do
        local unit = self.units[id]
        if unit and unit.side == side and unit.alive and not unit.evacuated then
            result[#result + 1] = unit
        end
    end
    return result
end

local function resolveVisionUnit(state, unit)
    if type(unit) == "table" then
        return unit
    end
    return expect(state.units[unit], "unknown unit " .. tostring(unit))
end

function State:computeVisibleTiles(unit)
    unit = resolveVisionUnit(self, unit)
    expect(unit.alive and not unit.evacuated, "unit is not active")
    expect(self:inBounds(unit.x, unit.y), "unit position out of bounds")
    local radius = expectInteger(unit.visionRadius or 8, "unit vision radius")
    expect(radius >= 0, "unit vision radius must be non-negative")
    local visible = {}
    for y = 1, self.board.height do
        for x = 1, self.board.width do
            if Grid.manhattan(unit.x, unit.y, x, y) <= radius then
                if x == unit.x and y == unit.y then
                    visible[tileKey(x, y)] = true
                else
                    local los = self:lineOfSight(unit.x, unit.y, x, y)
                    if los.visible then
                        visible[tileKey(x, y)] = true
                    end
                end
            end
        end
    end
    return visible
end

function State:visibilityGrid(side)
    side = side or "player"
    local visible = {}
    for _, unit in ipairs(self:unitsForSide(side)) do
        for key in pairs(self:computeVisibleTiles(unit)) do
            visible[key] = true
        end
    end
    local tiles = {}
    local fog = {}
    for y = 1, self.board.height do
        for x = 1, self.board.width do
            local key = tileKey(x, y)
            local isVisible = visible[key] == true
            tiles[key] = { x = x, y = y, visible = isVisible, fog = not isVisible }
            fog[key] = not isVisible
        end
    end
    local units = {}
    local hiddenUnits = {}
    for _, id in ipairs(self.unitOrder) do
        local unit = self.units[id]
        if unit and unit.alive and not unit.evacuated then
            local tileVisible = visible[tileKey(unit.x, unit.y)] == true
            local hidden = tileVisible and self:unitHiddenFromSide(unit, side)
            units[id] = tileVisible and not hidden
            if hidden then
                hiddenUnits[id] = true
            end
        end
    end
    return { side = side, width = self.board.width, height = self.board.height, visible = visible, fog = fog, tiles = tiles, units = units, hiddenUnits = hiddenUnits }
end

function State:computeSquadVisibility(side)
    return self:visibilityGrid(side)
end

function State:fogGrid(side)
    return self:visibilityGrid(side)
end

function State:unitAt(x, y)
    for _, id in ipairs(self.unitOrder) do
        local unit = self.units[id]
        if unit and unit.alive and not unit.evacuated and unit.x == x and unit.y == y then
            return unit
        end
    end
    return nil
end

function State:canEnter(x, y, movingUnitId, fromX, fromY)
    if not self:inBounds(x, y) then
        return false, "out_of_bounds"
    end
    local tile = self:tileAt(x, y)
    if tile.blocker then
        return false, "blocked_tile"
    end
    if fromX and fromY and self:inBounds(fromX, fromY) then
        local fromTile = self:tileAt(fromX, fromY)
        local heightDelta = (tile.height or 0) - (fromTile.height or 0)
        local stair = listHas(tile.tags, "stair") or listHas(fromTile.tags, "stair")
        local heightRule = hasHeightRuleTag(tile) or hasHeightRuleTag(fromTile)
        if heightRule then
            if heightDelta > 1 and not stair then
                return false, "climb_blocked"
            end
            if heightDelta < -2 and not stair then
                return false, "drop_blocked"
            end
        end
    end
    local occupant = self:unitAt(x, y)
    if occupant and occupant.id ~= movingUnitId then
        return false, "occupied"
    end
    return true
end

function State:moveUnitTo(unit, x, y)
    unit.x = x
    unit.y = y
    if unit.carryingCargo and self.cargo[unit.carryingCargo] then
        local cargo = self.cargo[unit.carryingCargo]
        cargo.x = x
        cargo.y = y
        local tile = self:tileAt(x, y)
        local damage = (tile.hazard and tile.hazard.carryDamage) or 0
        if damage > 0 then
            self:damageCargo(cargo.id, damage)
        end
    end
    self:resolveThreatAt(unit)
end

local function coverDirections(tile)
    local result = {}
    for _, direction in ipairs(Grid.order) do
        if tile and tile.coverEdges and tile.coverEdges[direction] and tile.coverEdges[direction] ~= "none" then
            result[#result + 1] = direction .. ":" .. tile.coverEdges[direction]
        end
    end
    return result
end

local function coverSet(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[value] = true
    end
    return result
end

local function coverDelta(fromTile, toTile)
    local from = coverDirections(fromTile)
    local to = coverDirections(toTile)
    local fromSet = coverSet(from)
    local toSet = coverSet(to)
    local gained = {}
    local lost = {}
    for _, value in ipairs(to) do
        if not fromSet[value] then
            gained[#gained + 1] = value
        end
    end
    for _, value in ipairs(from) do
        if not toSet[value] then
            lost[#lost + 1] = value
        end
    end
    return gained, lost
end

local function attackDirection(fromX, fromY, toX, toY)
    local dx = fromX - toX
    local dy = fromY - toY
    if math.abs(dx) >= math.abs(dy) and dx ~= 0 then
        return dx < 0 and "west" or "east"
    end
    if dy ~= 0 then
        return dy < 0 and "north" or "south"
    end
    return nil
end

function State:coverFromAttack(fromX, fromY, targetX, targetY)
    local direction = attackDirection(fromX, fromY, targetX, targetY)
    expect(direction, "attack direction required")
    local edge = self:tileAt(targetX, targetY).coverEdges[direction] or "none"
    return {
        x = targetX,
        y = targetY,
        direction = direction,
        cover = edge,
        damageReduction = edge == "half" and 1 or 0,
        blocked = edge == "full",
    }
end

function State:flankFromAttack(fromX, fromY, targetX, targetY)
    local cover = self:coverFromAttack(fromX, fromY, targetX, targetY)
    local coveredEdges = coverDirections(self:tileAt(targetX, targetY))
    return {
        x = targetX,
        y = targetY,
        direction = cover.direction,
        cover = cover.cover,
        flanked = #coveredEdges > 0 and cover.cover == "none",
        invalidated = cover.cover == "none" and coveredEdges or {},
    }
end

local function lineTiles(fromX, fromY, toX, toY)
    local points = {}
    local x = fromX
    local y = fromY
    local dx = math.abs(toX - fromX)
    local dy = math.abs(toY - fromY)
    local sx = fromX < toX and 1 or -1
    local sy = fromY < toY and 1 or -1
    local err = dx - dy
    while not (x == toX and y == toY) do
        local e2 = err * 2
        if e2 > -dy then
            err = err - dy
            x = x + sx
        end
        if e2 < dx then
            err = err + dx
            y = y + sy
        end
        points[#points + 1] = { x = x, y = y }
    end
    return points
end

function State:lineOfSight(fromX, fromY, toX, toY)
    expect(self:inBounds(fromX, fromY), "LoS source out of bounds")
    expect(self:inBounds(toX, toY), "LoS target out of bounds")
    local fromHeight = self:tileAt(fromX, fromY).height or 0
    local targetHeight = self:tileAt(toX, toY).height or 0
    local sightHeight = math.max(fromHeight, targetHeight)
    local points = lineTiles(fromX, fromY, toX, toY)
    local modifiers = {}
    for index, point in ipairs(points) do
        if index < #points then
            local tile = self:tileAt(point.x, point.y)
            if tile.hazard and tile.hazard.active and obscurantKinds[tile.hazard.kind] then
                modifiers[#modifiers + 1] = { x = point.x, y = point.y, kind = tile.hazard.kind, countdown = tile.hazard.countdown }
            end
            if tile.losBlocker and (tile.height or 0) >= sightHeight then
                return { visible = false, blockedBy = { x = point.x, y = point.y, height = tile.height or 0 }, heightDelta = fromHeight - targetHeight, highGround = fromHeight > targetHeight, lowGround = fromHeight < targetHeight, modifiers = modifiers, obscured = #modifiers > 0 }
            end
        end
    end
    return { visible = true, blockedBy = nil, heightDelta = fromHeight - targetHeight, highGround = fromHeight > targetHeight, lowGround = fromHeight < targetHeight, modifiers = modifiers, obscured = #modifiers > 0 }
end

function State:attackProfile(fromX, fromY, targetX, targetY)
    local los = self:lineOfSight(fromX, fromY, targetX, targetY)
    local cover = self:coverFromAttack(fromX, fromY, targetX, targetY)
    local flank = self:flankFromAttack(fromX, fromY, targetX, targetY)
    local flankingRule = Cover.flankingRule(self)
    local effectiveCover = cover.cover
    local damageReduction = cover.damageReduction
    local coverIgnoredByHeight = false
    if los.heightDelta >= 2 and cover.cover == "half" then
        effectiveCover = "none"
        damageReduction = 0
        coverIgnoredByHeight = true
    elseif los.heightDelta <= -2 then
        damageReduction = damageReduction + 1
    end
    if flank.flanked then
        effectiveCover = "none"
        damageReduction = 0
    end
    return {
        visible = los.visible,
        blockedBy = los.blockedBy,
        obscured = los.obscured,
        modifiers = copyValue(los.modifiers),
        heightDelta = los.heightDelta,
        highGround = los.highGround,
        lowGround = los.lowGround,
        cover = cover.cover,
        effectiveCover = effectiveCover,
        damageReduction = damageReduction,
        blocked = cover.blocked and not flank.flanked,
        coverIgnoredByHeight = coverIgnoredByHeight,
        flanked = flank.flanked,
        invalidatedCover = copyValue(flank.invalidated),
        flankingRule = copyValue(flankingRule),
    }
end

function State:sightlineProfile(fromX, fromY, targetX, targetY)
    expect(self:inBounds(fromX, fromY), "sightline source out of bounds")
    expect(self:inBounds(targetX, targetY), "sightline target out of bounds")
    local fromTile = self:tileAt(fromX, fromY)
    local targetTile = self:tileAt(targetX, targetY)
    if fromX == targetX and fromY == targetY then
        return {
            from = { x = fromX, y = fromY, height = fromTile.height or 0 },
            target = { x = targetX, y = targetY, height = targetTile.height or 0 },
            visible = true,
            blockedBy = nil,
            obscured = false,
            modifiers = {},
            heightDelta = 0,
            vantage = "same_tile",
            cover = "none",
            effectiveCover = "none",
            damageReduction = 0,
            blocked = false,
            flanked = false,
            coverIgnoredByHeight = false,
        }
    end
    local profile = self:attackProfile(fromX, fromY, targetX, targetY)
    local vantage = "level"
    if profile.heightDelta >= 2 then
        vantage = "high_ground"
    elseif profile.heightDelta <= -2 then
        vantage = "low_ground"
    elseif profile.heightDelta > 0 then
        vantage = "above"
    elseif profile.heightDelta < 0 then
        vantage = "below"
    end
    return {
        from = { x = fromX, y = fromY, height = fromTile.height or 0 },
        target = { x = targetX, y = targetY, height = targetTile.height or 0 },
        visible = profile.visible,
        blockedBy = copyMap(profile.blockedBy),
        obscured = profile.obscured,
        modifiers = copyValue(profile.modifiers),
        heightDelta = profile.heightDelta,
        vantage = vantage,
        cover = profile.cover,
        effectiveCover = profile.effectiveCover,
        damageReduction = profile.damageReduction,
        blocked = profile.blocked,
        flanked = profile.flanked,
        coverIgnoredByHeight = profile.coverIgnoredByHeight,
    }
end

function State:attackResolution(unitId, targetId, baseDamage)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    local target = expect(self.units[targetId], "unknown target " .. tostring(targetId))
    baseDamage = expectInteger(baseDamage or 1, "damage")
    expect(baseDamage >= 0, "damage must be non-negative")
    local profile = self:attackProfile(unit.x, unit.y, target.x, target.y)
    local damage = profile.blocked and 0 or math.max(0, baseDamage - (profile.damageReduction or 0))
    local flankingBonus = 0
    if profile.flanked and damage > 0 then
        damage, flankingBonus = Cover.flankingDamage(damage, profile.flankingRule)
    end
    profile.baseDamage = baseDamage
    profile.damageReductionApplied = baseDamage - (profile.blocked and 0 or math.max(0, baseDamage - (profile.damageReduction or 0)))
    profile.flankingBonus = flankingBonus
    profile.damage = damage
    return profile
end

local function tileHazardCost(tile)
    local hazard = tile and tile.hazard or nil
    if not hazard then
        return 0
    end
    return hazard.apCost or hazard.cost or hazard.damage or 0
end

local function tileTerrainCost(tile)
    return tile and tile.moveCost or 0
end

function State:movementPreview(unitId, options)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    expect(unit.alive and not unit.evacuated, "unit is not active")
    options = options or {}
    local stepCost = options.stepCost or self.rules.moveApCost
    local maxCost = options.maxCost or unit.ap or 0
    local startKey = tileKey(unit.x, unit.y)
    local startTile = self:tileAt(unit.x, unit.y)
    local seen = { [startKey] = 0 }
    local queue = { { x = unit.x, y = unit.y, apCost = 0, path = {} } }
    local reachable = {}
    local collisions = {}
    local collisionSeen = {}
    local index = 1
    while queue[index] do
        local node = queue[index]
        index = index + 1
        local tile = self:tileAt(node.x, node.y)
        local gained, lost = coverDelta(startTile, tile)
        local hazardCost = tileHazardCost(tile)
        local heightDelta = (tile.height or 0) - (startTile.height or 0)
        reachable[#reachable + 1] = {
            x = node.x,
            y = node.y,
            apCost = node.apCost,
            height = tile.height or 0,
            heightDelta = heightDelta,
            vertical = heightDelta > 0 and "ascend" or (heightDelta < 0 and "descend" or "level"),
            hazardCost = hazardCost,
            terrainCost = node.terrainCost or 0,
            moveCost = node.moveCost or 0,
            terrainType = tile.terrainType,
            coverGained = gained,
            coverLost = lost,
            objectiveCarryEffect = (unit.carryingObjective or unit.carryingCargo) and {
                objective = unit.carryingObjective,
                cargo = unit.carryingCargo,
                integrityDelta = -((tile.hazard and tile.hazard.carryDamage) or 0),
            } or nil,
            path = copyValue(node.path),
        }
        for _, direction in ipairs(Grid.order) do
            local delta = Grid.delta(direction)
            local nx = node.x + delta.x
            local ny = node.y + delta.y
            local ok, reason = self:canEnter(nx, ny, unit.id, node.x, node.y)
            if not ok then
                local key = tostring(node.x) .. ":" .. tostring(node.y) .. ":" .. direction
                if not collisionSeen[key] then
                    collisionSeen[key] = true
                    local toHeight = self:inBounds(nx, ny) and (self:tileAt(nx, ny).height or 0) or nil
                    collisions[#collisions + 1] = { fromX = node.x, fromY = node.y, x = nx, y = ny, direction = direction, result = reason, fromHeight = tile.height or 0, toHeight = toHeight, heightDelta = toHeight and (toHeight - (tile.height or 0)) or nil }
                end
            else
                local nextTile = self:tileAt(nx, ny)
                local terrainCost = tileTerrainCost(nextTile)
                local moveCost = stepCost + terrainCost
                local nextCost = node.apCost + moveCost
                local key = tileKey(nx, ny)
                if nextCost <= maxCost and (seen[key] == nil or nextCost < seen[key]) then
                    seen[key] = nextCost
                    local path = copyValue(node.path)
                    path[#path + 1] = direction
                    queue[#queue + 1] = { x = nx, y = ny, apCost = nextCost, terrainCost = terrainCost, moveCost = moveCost, path = path }
                end
            end
        end
    end
    table.sort(reachable, function(a, b)
        if a.apCost == b.apCost then
            if a.y == b.y then
                return a.x < b.x
            end
            return a.y < b.y
        end
        return a.apCost < b.apCost
    end)
    table.sort(collisions, function(a, b)
        if a.y == b.y then
            if a.x == b.x then
                return a.direction < b.direction
            end
            return a.x < b.x
        end
        return a.y < b.y
    end)
    return { unit = unitId, ap = unit.ap, reachable = reachable, collisions = collisions }
end

local function normalizeLosTargets(state, targets)
    local result = {}
    if targets then
        for _, target in ipairs(targets) do
            if target.id and state.units[target.id] then
                local unit = state.units[target.id]
                result[#result + 1] = { id = target.id, x = unit.x, y = unit.y }
            else
                result[#result + 1] = { id = target.id, x = expectInteger(target.x, "target x"), y = expectInteger(target.y, "target y") }
            end
        end
    else
        for _, unit in pairs(state.units) do
            if unit.side == "enemy" and unit.alive and not unit.evacuated then
                result[#result + 1] = { id = unit.id, x = unit.x, y = unit.y }
            end
        end
    end
    table.sort(result, function(a, b)
        return tostring(a.id or "") < tostring(b.id or "")
    end)
    return result
end

function State:movementLosPreview(unitId, options)
    options = options or {}
    local movement = self:movementPreview(unitId, options)
    local targets = normalizeLosTargets(self, options.targets)
    local destinations = {}
    for _, tile in ipairs(movement.reachable) do
        local entry = { x = tile.x, y = tile.y, apCost = tile.apCost, targets = {} }
        for _, target in ipairs(targets) do
            local los = self:lineOfSight(tile.x, tile.y, target.x, target.y)
            entry.targets[#entry.targets + 1] = {
                id = target.id,
                x = target.x,
                y = target.y,
                visible = los.visible,
                blockedBy = copyMap(los.blockedBy),
                obscured = los.obscured,
                modifiers = copyValue(los.modifiers),
            }
        end
        destinations[#destinations + 1] = entry
    end
    return { unit = unitId, ap = movement.ap, destinations = destinations }
end

function State:queue(command)
    expect(type(command) == "table", "command must be a table")
    self.pending[#self.pending + 1] = command
end

function State:selectUnit(id)
    local unit = expect(self.units[id], "unknown unit " .. tostring(id))
    expect(unit.alive and not unit.evacuated, "unit is not active")
    self.selectedUnitId = id
    return unit
end

function State:status(unitOrId, kind)
    local unit = type(unitOrId) == "table" and unitOrId or expect(self.units[unitOrId], "unknown unit " .. tostring(unitOrId))
    return unit.statuses and unit.statuses[kind] or nil
end

function State:unitHiddenFromSide(unitOrId, side)
    local unit = type(unitOrId) == "table" and unitOrId or expect(self.units[unitOrId], "unknown unit " .. tostring(unitOrId))
    if not unit.alive or unit.evacuated or unit.side == side then
        return false
    end
    return self:hasStatus(unit, "ghosted")
end

function State:hasStatus(unitOrId, kind)
    return self:status(unitOrId, kind) ~= nil
end

function State:applyStatus(unitId, kind, turns, amount)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    local rule = expect(statusRules[kind], "unsupported status " .. tostring(kind))
    unit.statuses = unit.statuses or {}
    unit.statuses[kind] = {
        kind = kind,
        turns = turns,
        amount = amount or rule.amount,
    }
    return unit.statuses[kind]
end

function State:removeStatus(unitId, kind)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    if unit.statuses then
        unit.statuses[kind] = nil
    end
end

function State:movementBlocked(unit)
    return self:hasStatus(unit, "pinned") or self:hasStatus(unit, "bound") or self:hasStatus(unit, "sealed")
end

local function statusAmount(unit, kind)
    local status = unit.statuses and unit.statuses[kind]
    return status and (status.amount or 1) or 0
end

local function incomingDamageBonus(unit)
    return statusAmount(unit, "marked") + statusAmount(unit, "exposed")
end

local function bracedReduction(unit)
    return statusAmount(unit, "braced")
end

local function incomingDamageReduction(unit)
    return math.max(0, statusAmount(unit, "guarded") - statusAmount(unit, "shredded"))
end

function State:spendAP(id, amount)
    local unit = expect(self.units[id], "unknown unit " .. tostring(id))
    expect(unit.alive and not unit.evacuated, "unit is not active")
    amount = expectInteger(amount, "ap cost")
    expect(amount >= 0, "ap cost must be non-negative")
    expect((unit.ap or 0) >= amount, "insufficient_ap")
    unit.ap = unit.ap - amount
    return unit.ap
end

function State:damageUnit(unitOrId, amount, options)
    local unit = type(unitOrId) == "table" and unitOrId or expect(self.units[unitOrId], "unknown unit " .. tostring(unitOrId))
    options = options or {}
    amount = expectInteger(amount or 0, "damage")
    expect(amount >= 0, "damage must be non-negative")
    if amount == 0 or not unit.alive or unit.evacuated then
        return unit.hp
    end
    if not options.ignoreStatusBonus then
        amount = amount + incomingDamageBonus(unit)
    end
    if not options.ignoreStatusReduction then
        amount = math.max(0, amount - incomingDamageReduction(unit))
    end
    if amount == 0 then
        return unit.hp
    end
    unit.hp = math.max(0, (unit.hp or 0) - amount)
    if unit.hp <= 0 then
        unit.alive = false
        unit.ap = 0
    end
    return unit.hp
end

function State:healUnit(unitOrId, amount)
    local unit = type(unitOrId) == "table" and unitOrId or expect(self.units[unitOrId], "unknown unit " .. tostring(unitOrId))
    amount = expectInteger(amount or 0, "healing")
    expect(amount >= 0, "healing must be non-negative")
    if amount == 0 or not unit.alive or unit.evacuated then
        return unit.hp
    end
    unit.hp = math.min(unit.maxHp or unit.hp or 0, (unit.hp or 0) + amount)
    return unit.hp
end

function State:tickStatuses(unitId)
    local units = unitId and { expect(self.units[unitId], "unknown unit " .. tostring(unitId)) } or self.units
    for _, unit in pairs(units) do
        if unit.alive and not unit.evacuated then
            for kind, status in pairs(copyMap(unit.statuses)) do
                local rule = statusRules[kind]
                if rule and rule.tickDamage then
                    self:damageUnit(unit, status.amount or rule.amount or 1, { ignoreStatusBonus = true })
                end
                local current = unit.statuses[kind]
                if current and current.turns ~= nil then
                    current.turns = current.turns - 1
                    if current.turns <= 0 then
                        unit.statuses[kind] = nil
                    end
                end
            end
        end
    end
end

function State:damageTile(x, y, amount)
    expect(self:inBounds(x, y), "tile out of bounds")
    amount = expectInteger(amount or 0, "tile damage")
    expect(amount >= 0, "tile damage must be non-negative")
    local key = tileKey(x, y)
    local tile = self.board.tiles[key]
    if not (tile and tile.destructibleHp ~= nil) then
        return nil
    end
    tile.destructibleHp = math.max(0, tile.destructibleHp - amount)
    if tile.destructibleHp <= 0 then
        tile.blocker = false
        tile.losBlocker = false
        tile.blockerKind = "none"
        tile.coverEdges = emptyCoverEdges()
        if tile.collapseHeight ~= nil then
            tile.height = tile.collapseHeight
        end
        if tile.collapseKind then
            tile.kind = tile.collapseKind
        end
        tile.destroyed = true
    end
    return tile.destructibleHp
end

function State:addObscurant(x, y, kind, countdown)
    x = expectInteger(x, "obscurant x")
    y = expectInteger(y, "obscurant y")
    expect(self:inBounds(x, y), "obscurant tile out of bounds")
    expect(obscurantKinds[kind], "unsupported obscurant " .. tostring(kind))
    countdown = expectInteger(countdown or 1, "obscurant countdown")
    expect(countdown > 0, "obscurant countdown must be positive")
    local key = tileKey(x, y)
    local tile = self.board.tiles[key] or normalizeTile()
    tile.hazard = { kind = kind, active = true, countdown = countdown, losModifier = "obscure" }
    tile.state = kind
    self.board.tiles[key] = tile
    return tile
end

function State:tickObscurants()
    for key, tile in pairs(self.board.tiles) do
        if tile.hazard and tile.hazard.active and obscurantKinds[tile.hazard.kind] and tile.hazard.countdown ~= nil then
            tile.hazard.countdown = tile.hazard.countdown - 1
            if tile.hazard.countdown <= 0 then
                tile.hazard.active = false
                tile.hazard.losModifier = nil
                tile.state = "clear"
            end
            self.board.tiles[key] = tile
        end
    end
end

local function tileInList(tiles, x, y)
    for _, tile in ipairs(tiles or {}) do
        if tile.x == x and tile.y == y then
            return true
        end
    end
    return false
end

local overwatchReactionKinds = {
    shoot = true,
    stun = true,
    mark = true,
}

local function normalizeOverwatchReaction(reaction, damage)
    if type(reaction) == "string" then
        reaction = { kind = reaction }
    end
    reaction = reaction or { kind = "shoot", damage = damage or 1 }
    local kind = reaction.kind or "shoot"
    expect(overwatchReactionKinds[kind], "unsupported overwatch reaction " .. tostring(kind))
    return {
        kind = kind,
        damage = reaction.damage or damage or (kind == "shoot" and 1 or 0),
        status = kind == "stun" and "stunned" or (kind == "mark" and "marked" or nil),
        turns = reaction.turns or 1,
        amount = reaction.amount,
    }
end

function State:pruneThreatZones()
    local active = {}
    for _, zone in ipairs(self.threatZones or {}) do
        if (zone.remaining or 0) > 0 and self.units[zone.unit] and self.units[zone.unit].alive then
            active[#active + 1] = zone
        end
    end
    self.threatZones = active
end

function State:addThreatZone(unitId, tiles, options)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    expect(not self:hasStatus(unit, "blinded"), "unit is blinded")
    expect(not self:hasStatus(unit, "jammed"), "unit is jammed")
    options = options or {}
    local zone = {
        unit = unitId,
        side = unit.side,
        tiles = normalizeTileList(tiles),
        damage = options.damage or 1,
        remaining = options.limit or options.remaining or 1,
        label = options.label or "overwatch",
        kind = options.kind,
        origin = copyMap(options.origin),
        facing = options.facing or options.direction,
        arc = options.arc or options.width,
        range = options.range or options.length,
        triggerPhase = options.triggerPhase,
        reaction = normalizeOverwatchReaction(options.reaction, options.damage or 1),
    }
    expect(#zone.tiles > 0, "threat zone needs at least one tile")
    expect(zone.remaining > 0, "threat zone limit must be positive")
    self.threatZones[#self.threatZones + 1] = zone
    return zone
end

function State:applyThreatReaction(source, unit, zone)
    local reaction = zone.reaction or normalizeOverwatchReaction(nil, zone.damage)
    local result = { source = source.id, target = unit.id, reaction = reaction.kind, x = unit.x, y = unit.y }
    if reaction.kind == "shoot" then
        result.hp = self:damageUnit(unit, reaction.damage or zone.damage or 1)
        result.damage = reaction.damage or zone.damage or 1
    elseif reaction.kind == "stun" then
        self:applyStatus(unit.id, "stunned", reaction.turns or 1, reaction.amount)
        result.status = "stunned"
    elseif reaction.kind == "mark" then
        self:applyStatus(unit.id, "marked", reaction.turns or 1, reaction.amount or 1)
        result.status = "marked"
    end
    self.lastOverwatchTrigger = result
    return result
end

local function perpendicularDirections(direction)
    if direction == "north" or direction == "south" then
        return { "west", "east" }
    end
    return { "north", "south" }
end

local function appendUniqueTile(list, seen, x, y)
    local key = tileKey(x, y)
    if not seen[key] then
        seen[key] = true
        list[#list + 1] = { x = x, y = y }
    end
end

function State:threatZoneTiles(unitId, shape, options)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    options = options or {}
    local direction = options.direction or unit.facing or "east"
    local forward = Grid.directions[direction]
    expect(forward, "unknown direction " .. tostring(direction))
    local length = options.length or options.range or 1
    local width = options.width or 1
    local result = {}
    local seen = {}
    if shape == "line" then
        for step = 1, length do
            local x = unit.x + forward.x * step
            local y = unit.y + forward.y * step
            if self:inBounds(x, y) then
                appendUniqueTile(result, seen, x, y)
            end
        end
    elseif shape == "cone" then
        local sides = perpendicularDirections(direction)
        for step = 1, length do
            local cx = unit.x + forward.x * step
            local cy = unit.y + forward.y * step
            if self:inBounds(cx, cy) then
                appendUniqueTile(result, seen, cx, cy)
            end
            local lateral = math.min(width, step - 1)
            for _, sideDirection in ipairs(sides) do
                local side = Grid.directions[sideDirection]
                for offset = 1, lateral do
                    local x = cx + side.x * offset
                    local y = cy + side.y * offset
                    if self:inBounds(x, y) then
                        appendUniqueTile(result, seen, x, y)
                    end
                end
            end
        end
    elseif shape == "arc" then
        local directions = { direction }
        for _, side in ipairs(perpendicularDirections(direction)) do
            directions[#directions + 1] = side
        end
        for _, arcDirection in ipairs(directions) do
            local delta = Grid.directions[arcDirection]
            for step = 1, length do
                local x = unit.x + delta.x * step
                local y = unit.y + delta.y * step
                if self:inBounds(x, y) then
                    appendUniqueTile(result, seen, x, y)
                end
            end
        end
    else
        error("unknown threat zone shape " .. tostring(shape), 2)
    end
    table.sort(result, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)
    return result
end

function State:addThreatZoneShape(unitId, shape, options)
    options = options or {}
    local tiles = self:threatZoneTiles(unitId, shape, options)
    return self:addThreatZone(unitId, tiles, options)
end

function State:declareOverwatch(unitId, options)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    expect(unit.alive and not unit.evacuated, "unit is not active")
    expect(not self:hasStatus(unit, "blinded"), "unit is blinded")
    expect(not self:hasStatus(unit, "jammed"), "unit is jammed")
    options = options or {}
    local facing = options.facing or options.direction or unit.facing or "east"
    local range = options.range or options.length or 3
    local arc = options.arc or options.width or 1
    local tiles = self:threatZoneTiles(unitId, "cone", { direction = facing, length = range, width = arc })
    return self:addThreatZone(unitId, tiles, {
        kind = "overwatch",
        origin = { x = unit.x, y = unit.y },
        facing = facing,
        arc = arc,
        range = range,
        triggerPhase = options.triggerPhase or "enemy",
        reaction = options.reaction or { kind = options.reactionKind or "shoot", damage = options.damage or 1, turns = options.turns, amount = options.amount },
        damage = options.damage or 1,
        limit = options.limit or 1,
        label = options.label or "overwatch",
    })
end

local function hydrateConditionalIntent(state, intent)
    if intent.mode ~= "conditional" then
        return
    end
    for _, branch in ipairs(intent.branches or {}) do
        local condition = branch.condition
        if condition.kind == "targetMoved" and not condition.from then
            local target = expect(state.units[condition.target], "unknown condition target " .. tostring(condition.target))
            condition.from = { x = target.x, y = target.y }
        end
    end
end

function State:declareIntent(unitId, intent)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    local normalized = normalizeIntent(intent)
    normalized.source = normalized.source or unitId
    if not normalized.sourceTile.x then
        normalized.sourceTile = { x = unit.x, y = unit.y }
    end
    hydrateConditionalIntent(self, normalized)
    self.intents[unitId] = normalized
    return normalized
end

function State:intentPreview(unitId, options)
    local intent = self.intents[unitId]
    if not intent then
        return nil
    end
    options = options or {}
    local reveal = shouldRevealIntentFootprint(intent, options)
    local preview = {
        mode = intent.mode,
        intentType = intent.intentType,
        category = intent.category,
        source = intent.source,
        sourceTile = copyMap(intent.sourceTile),
        target = intent.target,
        damage = intent.damage,
        effect = intent.effect,
        collision = copyMap(intent.collision),
        statusEffect = copyMap(intent.statusEffect),
        objectiveImpact = intent.objectiveImpact,
        countdown = intent.countdown,
        anchor = copyMap(intent.anchor),
        trigger = copyMap(intent.trigger),
        branches = copyValue(intent.branches),
        counterplay = copyList(intent.counterplay),
        revealed = intent.revealed == true,
        ignoredTurns = intent.ignoredTurns or 0,
        escalation = copyMap(intent.escalation),
        decay = copyMap(intent.decay),
        revealRotations = copyList(intent.revealRotations),
        revealActions = copyList(intent.revealActions),
        revealClasses = copyList(intent.revealClasses),
        stage = intent.stage,
        stageCount = intent.stageCount,
        mask = intent.mask,
        phase = intent.phase,
        turn = intent.turn,
        weakPoint = intent.weakPoint,
        masks = copyValue(intent.masks),
        label = intent.label,
    }
    if intent.mode == "decoy" then
        local branch = reveal and intent.actual or intent.decoy
        preview.category = branch.category
        preview.target = branch.target
        preview.targetTiles = copyValue(branch.targetTiles)
        preview.path = copyValue(branch.path)
        preview.damage = branch.damage
        preview.effect = branch.effect
        preview.objectiveImpact = branch.objectiveImpact
        preview.decoy = not reveal
        preview.decoyRevealed = reveal
    elseif intent.mode == "exact" or intent.mode == "fuse" or (intent.mode == "hiddenFootprint" and reveal) or (intent.mode == "bossStage" and not intent.mask) then
        preview.targetTiles = copyValue(intent.targetTiles)
        preview.path = copyValue(intent.path)
    elseif intent.mode == "hiddenFootprint" then
        preview.footprintHidden = true
    elseif intent.mode == "category" then
        preview.categoryOnly = true
    elseif intent.mode == "bossStage" then
        preview.footprintHidden = true
    end
    return preview
end

function State:resolveIntentTrigger(unitId, intent, trigger)
    intent = intent or {}
    trigger = trigger or intent.trigger or {}
    local source = self.units[unitId]
    if source and (not source.alive or source.evacuated) then
        return {
            triggered = false,
            source = unitId,
            blocked = "source_inactive",
            targetTiles = copyValue((#(trigger.targetTiles or {}) > 0) and trigger.targetTiles or intent.targetTiles),
            units = {},
            objectives = {},
            cargo = {},
            conversions = {},
        }
    end
    local damage = trigger.damage or intent.damage or 0
    local tiles = (#(trigger.targetTiles or {}) > 0) and trigger.targetTiles or intent.targetTiles
    local result = {
        triggered = true,
        source = unitId,
        kind = trigger.kind,
        countdown = 0,
        targetTiles = copyValue(tiles),
        units = {},
        objectives = {},
        cargo = {},
        conversions = {},
    }
    if trigger.kind == "damage" then
        local damagedUnits = {}
        local function damageUnitOnce(unitOrId)
            local unit = type(unitOrId) == "table" and unitOrId or expect(self.units[unitOrId], "unknown unit " .. tostring(unitOrId))
            if damagedUnits[unit.id] then
                return
            end
            self:damageUnit(unit, damage)
            damagedUnits[unit.id] = true
            result.units[#result.units + 1] = unit.id
        end
        if trigger.target then
            damageUnitOnce(trigger.target)
        end
        for _, tile in ipairs(tiles or {}) do
            local unit = self:unitAt(tile.x, tile.y)
            if unit then
                damageUnitOnce(unit)
            end
            local objective = self:objectiveAt(tile.x, tile.y)
            if objective then
                self:damageObjective(objective.id, damage)
                result.objectives[#result.objectives + 1] = objective.id
            end
            local cargo = self:cargoAt(tile.x, tile.y)
            if cargo then
                self:damageCargo(cargo.id, damage)
                result.cargo[#result.cargo + 1] = cargo.id
            end
        end
    elseif trigger.kind == "damageObjective" then
        self:damageObjective(trigger.objective, damage)
        result.objectives[#result.objectives + 1] = trigger.objective
    elseif trigger.kind == "repairObjective" then
        self:repairObjective(trigger.objective, trigger.amount or 1)
        result.objectives[#result.objectives + 1] = trigger.objective
    elseif trigger.kind == "convertTile" then
        for _, tile in ipairs(tiles or {}) do
            self:convertTile(tile.x, tile.y, trigger.conversion)
            result.conversions[#result.conversions + 1] = { x = tile.x, y = tile.y, conversion = trigger.conversion }
        end
    elseif trigger.kind == "status" then
        self:applyStatus(trigger.target, trigger.status, trigger.turns, trigger.amount)
        result.units[#result.units + 1] = trigger.target
    else
        error("unknown fuse trigger " .. tostring(trigger.kind), 2)
    end
    return result
end

function State:resolveIntentFuse(unitId, intent)
    intent = intent or expect(self.intents[unitId], "unknown intent " .. tostring(unitId))
    expect(intent.mode == "fuse", "intent is not a fuse")
    return self:resolveIntentTrigger(unitId, intent, intent.trigger)
end

function State:tickIntentFuse(unitId)
    local intent = expect(self.intents[unitId], "unknown intent " .. tostring(unitId))
    expect(intent.mode == "fuse", "intent is not a fuse")
    intent.countdown = math.max(0, (intent.countdown or 0) - 1)
    if intent.countdown > 0 then
        return { triggered = false, source = unitId, countdown = intent.countdown }
    end
    local result = self:resolveIntentFuse(unitId, intent)
    self.intents[unitId] = nil
    return result
end

function State:intentConditionMet(condition)
    if condition.kind == "otherwise" then
        return true
    elseif condition.kind == "targetMoved" then
        local unit = expect(self.units[condition.target], "unknown condition target " .. tostring(condition.target))
        local from = expect(condition.from, "targetMoved condition missing source tile")
        return unit.x ~= from.x or unit.y ~= from.y
    elseif condition.kind == "targetOnTile" then
        local unit = expect(self.units[condition.target], "unknown condition target " .. tostring(condition.target))
        return unit.x == condition.x and unit.y == condition.y
    end
    error("unknown intent condition " .. tostring(condition.kind), 2)
end

function State:selectConditionalBranch(unitId)
    local intent = expect(self.intents[unitId], "unknown intent " .. tostring(unitId))
    expect(intent.mode == "conditional", "intent is not conditional")
    for index, branch in ipairs(intent.branches or {}) do
        if self:intentConditionMet(branch.condition) then
            return branch, index
        end
    end
    return nil
end

function State:resolveConditionalIntent(unitId)
    local intent = expect(self.intents[unitId], "unknown intent " .. tostring(unitId))
    expect(intent.mode == "conditional", "intent is not conditional")
    local branch, index = expect(self:selectConditionalBranch(unitId), "conditional intent had no matching branch")
    local result = self:resolveIntentTrigger(unitId, branch.intent, branch.trigger)
    result.branch = index
    result.condition = copyValue(branch.condition)
    self.intents[unitId] = nil
    return result
end

function State:interruptIntent(unitId, interrupt)
    local intent = expect(self.intents[unitId], "unknown intent " .. tostring(unitId))
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    if type(interrupt) == "string" then
        interrupt = { kind = interrupt }
    end
    interrupt = interrupt or {}
    local kind = interrupt.kind or interrupt.type
    expect(interruptKinds[kind], "unsupported interrupt " .. tostring(kind))
    local result = { unit = unitId, kind = kind, prevented = false, revealed = false }
    if kind == "exposeWeakPoint" then
        intent.mask = nil
        intent.revealed = true
        result.revealed = true
        return result
    elseif kind == "stun" then
        self:applyStatus(unitId, "stunned", interrupt.turns or 1, interrupt.amount)
    elseif kind == "seal" then
        self:applyStatus(unitId, "sealed", interrupt.turns or 1, interrupt.amount)
    elseif kind == "shove" then
        local delta = expect(Grid.directions[interrupt.direction], "unknown direction " .. tostring(interrupt.direction))
        self:displaceUnit(unitId, delta.x, delta.y, interrupt.distance or 1, interrupt.collisionDamage or 1)
        result.moved = unit.x ~= intent.sourceTile.x or unit.y ~= intent.sourceTile.y
    elseif kind == "coverRaise" then
        self:convertTile(expectInteger(interrupt.x, "interrupt x"), expectInteger(interrupt.y, "interrupt y"), "raise_cover")
    elseif kind == "drain" then
        self:convertTile(expectInteger(interrupt.x, "interrupt x"), expectInteger(interrupt.y, "interrupt y"), "drain")
    elseif kind == "douse" then
        local x = expectInteger(interrupt.x, "interrupt x")
        local y = expectInteger(interrupt.y, "interrupt y")
        expect(self:inBounds(x, y), "interrupt tile out of bounds")
        local key = tileKey(x, y)
        local tile = self.board.tiles[key] or normalizeTile()
        tile.hazard = { kind = (tile.hazard and tile.hazard.kind) or "burn", active = false, damage = 0 }
        tile.state = "doused"
        self.board.tiles[key] = tile
    end
    self.intents[unitId] = nil
    result.prevented = true
    return result
end

local function pressureRuleApplies(intent, rule)
    if not rule then
        return false
    end
    local ignoredTurns = intent.ignoredTurns or 0
    if ignoredTurns < (rule.after or 1) then
        return false
    end
    return ((ignoredTurns - (rule.after or 1)) % (rule.every or 1)) == 0
end

function State:applyIntentPressureRule(unitId, intent, rule)
    local result = { unit = unitId, removed = false, damage = intent.damage, countdown = intent.countdown }
    if rule.damageDelta then
        intent.damage = math.max(0, (intent.damage or 0) + rule.damageDelta)
        result.damage = intent.damage
    end
    if rule.countdownDelta and intent.countdown ~= nil then
        intent.countdown = math.max(0, (intent.countdown or 0) + rule.countdownDelta)
        result.countdown = intent.countdown
    end
    if rule.category then
        expect(intentCategories[rule.category], "invalid intent category " .. tostring(rule.category))
        intent.category = rule.category
        result.category = rule.category
    end
    if rule.effect then
        intent.effect = rule.effect
        result.effect = rule.effect
    end
    if rule.remove or (rule.removeAtZeroDamage and (intent.damage or 0) <= 0) then
        self.intents[unitId] = nil
        result.removed = true
    end
    return result
end

function State:advanceIntentPressure(unitId, outcome)
    local intent = expect(self.intents[unitId], "unknown intent " .. tostring(unitId))
    outcome = outcome or "ignored"
    expect(outcome == "ignored" or outcome == "decay", "unsupported intent pressure outcome " .. tostring(outcome))
    if outcome == "ignored" then
        intent.ignoredTurns = (intent.ignoredTurns or 0) + 1
        if pressureRuleApplies(intent, intent.escalation) then
            local result = self:applyIntentPressureRule(unitId, intent, intent.escalation)
            result.outcome = outcome
            result.escalated = true
            result.ignoredTurns = intent.ignoredTurns
            return result
        end
        return { unit = unitId, outcome = outcome, escalated = false, ignoredTurns = intent.ignoredTurns }
    end
    intent.ignoredTurns = 0
    if intent.decay then
        local result = self:applyIntentPressureRule(unitId, intent, intent.decay)
        result.outcome = outcome
        result.decayed = true
        result.ignoredTurns = 0
        return result
    end
    return { unit = unitId, outcome = outcome, decayed = false, ignoredTurns = 0 }
end

function State:reduceIntent(unitId, amount)
    local intent = expect(self.intents[unitId], "unknown intent " .. tostring(unitId))
    amount = expectInteger(amount or 1, "intent reduction")
    expect(amount >= 0, "intent reduction must be non-negative")
    local before = intent.damage or 0
    intent.damage = math.max(0, before - amount)
    intent.effect = intent.effect or "ash_reduced"
    return { unit = unitId, damage = intent.damage, reduced = before - intent.damage }
end

local function bossMaskMatches(mask, context)
    if mask.phase ~= nil and mask.phase ~= context.phase then
        return false
    end
    if mask.turn ~= nil and mask.turn ~= context.turn then
        return false
    end
    local rotation = context.rotation
    if rotation == nil then
        rotation = context.viewRotation
    end
    if mask.rotation ~= nil and rotation ~= nil and mask.rotation % 4 ~= rotation % 4 then
        return false
    elseif mask.rotation ~= nil and rotation == nil then
        return false
    end
    if mask.revealRotation ~= nil and rotation ~= nil and mask.revealRotation % 4 ~= rotation % 4 then
        return false
    elseif mask.revealRotation ~= nil and rotation == nil then
        return false
    end
    if mask.weakPoint ~= nil and mask.weakPoint ~= context.weakPoint then
        return false
    end
    return true
end

function State:bossIntentMask(unitId, context)
    local intent = expect(self.intents[unitId], "unknown intent " .. tostring(unitId))
    expect(intent.mode == "bossStage", "intent is not boss-stage")
    context = context or {}
    context.turn = context.turn or self.tick
    for _, mask in ipairs(intent.masks or {}) do
        if bossMaskMatches(mask, context) then
            return mask
        end
    end
    return nil
end

function State:advanceBossIntentMask(unitId, context)
    context = context or {}
    local intent = expect(self.intents[unitId], "unknown intent " .. tostring(unitId))
    expect(intent.mode == "bossStage", "intent is not boss-stage")
    local mask = expect(self:bossIntentMask(unitId, context), "no boss mask matched")
    intent.phase = context.phase or intent.phase
    intent.turn = context.turn or self.tick
    intent.weakPoint = context.weakPoint or intent.weakPoint
    intent.mask = mask.revealed and nil or mask.mask
    intent.revealed = mask.revealed == true
    intent.stage = mask.stage or intent.stage
    intent.stageCount = mask.stageCount or intent.stageCount
    if #(mask.targetTiles or {}) > 0 then
        intent.targetTiles = copyValue(mask.targetTiles)
    end
    return {
        unit = unitId,
        mask = intent.mask,
        revealed = intent.revealed,
        phase = intent.phase,
        turn = intent.turn,
        weakPoint = intent.weakPoint,
        stage = intent.stage,
    }
end

function State:classReveal(unitId, options)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    options = options or {}
    local revealClass = options.revealClass or unit.class
    local revealAction = options.revealAction or options.action
    local revealOptions = { revealClass = revealClass, revealAction = revealAction, rotation = options.rotation, viewRotation = options.viewRotation }
    local result = { unit = unitId, revealClass = revealClass, revealAction = revealAction, intents = {}, tiles = {}, weakPoints = {} }
    for intentId, intent in pairs(self.intents) do
        if shouldRevealIntentFootprint(intent, revealOptions) then
            intent.revealed = true
            if intent.mode == "bossStage" then
                intent.mask = nil
            end
            result.intents[#result.intents + 1] = intentId
        end
    end
    for key, tile in pairs(self.board.tiles) do
        local classMatch = revealClass and listHas(tile.revealClasses, revealClass)
        local actionMatch = revealAction and listHas(tile.revealActions, revealAction)
        if classMatch or actionMatch then
            tile.revealed = true
            local x, y = key:match("^(%-?%d+):(%-?%d+)$")
            result.tiles[#result.tiles + 1] = { x = tonumber(x), y = tonumber(y) }
            if tile.weakPoint then
                tile.weakPointRevealed = true
                result.weakPoints[#result.weakPoints + 1] = { x = tonumber(x), y = tonumber(y), weakPoint = tile.weakPoint }
            end
            self.board.tiles[key] = tile
        end
    end
    table.sort(result.intents)
    table.sort(result.tiles, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)
    table.sort(result.weakPoints, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)
    return result
end

local function containsUnitId(values, unitId)
    for _, value in ipairs(values or {}) do
        if value == unitId then
            return true
        end
    end
    return false
end

function State:objective(id)
    return self.objectives[id]
end

function State:objectiveAt(x, y)
    for _, id in ipairs(self.objectiveOrder or {}) do
        local objective = self.objectives[id]
        if objective and objective.x == x and objective.y == y and not objective.complete and not objective.failed then
            return objective
        end
    end
    return nil
end

function State:cargoItem(id)
    return self.cargo[id]
end

function State:cargoAt(x, y)
    for _, id in ipairs(self.cargoOrder or {}) do
        local cargo = self.cargo[id]
        if cargo and not cargo.carriedBy and not cargo.extracted and not cargo.failed and cargo.x == x and cargo.y == y then
            return cargo
        end
    end
    return nil
end

function State:evaluateObjective(objective)
    if objective.failed then
        return "failed"
    end
    if objective.complete then
        return "complete"
    end
    if objective.disabled then
        objective.complete = true
        return "complete"
    end
    if objective.extracted then
        objective.complete = true
        return "complete"
    end
    if (objective.integrity or 0) <= 0 then
        objective.failed = true
        objective.failureCarryover = objective.failureCarryover or {}
        objective.failureCarryover.reason = objective.failureCarryover.reason or "integrity_zero"
        return "failed"
    end
    local requiredEvacuations = objective.minUnits or objective.evacuationsRequired or 1
    if #(objective.evacuatedUnits or {}) >= requiredEvacuations then
        objective.complete = true
        return "complete"
    end
    if objective.family == "hold" and objective.requiredTurns and (objective.heldTurns or 0) >= objective.requiredTurns then
        objective.complete = true
        return "complete"
    end
    if objective.family == "split" then
        local allActive = #(objective.switches or {}) > 0
        for _, switch in ipairs(objective.switches or {}) do
            if not switch.activated then
                allActive = false
                break
            end
        end
        if allActive then
            objective.complete = true
            return "complete"
        end
    end
    if objective.family == "stealth" then
        local readsReady = (objective.readCount or 0) >= (objective.requiredReads or 1)
        local evacReady = #(objective.evacuatedUnits or {}) >= (objective.minUnits or objective.evacuationsRequired or 1)
        if readsReady and evacReady then
            objective.complete = true
            return "complete"
        end
    end
    if objective.family == "boss" then
        local allCountered = #(objective.ritualSteps or {}) > 0
        for _, step in ipairs(objective.ritualSteps or {}) do
            if not step.countered then
                allCountered = false
                break
            end
        end
        if allCountered then
            objective.complete = true
            return "complete"
        end
    end
    return "active"
end

function State:objectiveStatus(id)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    return self:evaluateObjective(objective)
end

function State:damageObjective(id, amount)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    amount = expectInteger(amount or 0, "objective damage")
    expect(amount >= 0, "objective damage must be non-negative")
    if objective.complete or objective.failed then
        return objective.integrity
    end
    objective.integrity = math.max(0, objective.integrity - amount)
    self:evaluateObjective(objective)
    return objective.integrity
end

function State:repairObjective(id, amount)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    amount = expectInteger(amount or 0, "objective repair")
    expect(amount >= 0, "objective repair must be non-negative")
    if objective.complete or objective.failed then
        return objective.integrity
    end
    objective.integrity = math.min(objective.maxIntegrity or objective.integrity or amount, (objective.integrity or 0) + amount)
    return objective.integrity
end

function State:relocateObjective(id, x, y)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    x = expectInteger(x, "objective x")
    y = expectInteger(y, "objective y")
    expect(self:inBounds(x, y), "objective relocation out of bounds")
    expect(not self:tileAt(x, y).blocker, "objective relocation blocked")
    objective.x = x
    objective.y = y
    objective.relocated = true
    return objective
end

function State:extractObjective(id)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    expect(not objective.failed, "objective already failed")
    objective.extracted = true
    objective.complete = true
    return objective
end

function State:extractCargo(unitId, objectiveId)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    local cargoId = expect(unit.carryingCargo, "unit is not carrying cargo")
    local cargo = expect(self.cargo[cargoId], "unknown cargo " .. tostring(cargoId))
    local objective = expect(self.objectives[objectiveId], "unknown objective " .. tostring(objectiveId))
    local atObjective = unit.x == objective.x and unit.y == objective.y
    local atEvac = objective.evacuateAt and unit.x == objective.evacuateAt.x and unit.y == objective.evacuateAt.y
    expect(atObjective or atEvac, "unit is not on extraction tile")
    self:extractObjective(objectiveId)
    cargo.extracted = true
    cargo.carriedBy = nil
    cargo.x = unit.x
    cargo.y = unit.y
    unit.carryingCargo = nil
    return cargo
end

function State:disableObjective(id, reason)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    expect(not objective.failed, "objective already failed")
    objective.disabled = true
    objective.disabledReason = reason
    objective.complete = true
    return objective
end

function State:tickHoldObjective(id)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    expect(objective.family == "hold", "objective is not hold")
    local occupied = false
    for _, unit in pairs(self.units) do
        if unit.side == "player" and unit.alive and not unit.evacuated and unit.x == objective.x and unit.y == objective.y then
            occupied = true
            break
        end
    end
    if occupied then
        objective.heldTurns = (objective.heldTurns or 0) + 1
    end
    if objective.escalateIntents then
        for unitId in pairs(self.intents) do
            self:advanceIntentPressure(unitId, "ignored")
        end
    end
    self:evaluateObjective(objective)
    return { objective = id, occupied = occupied, heldTurns = objective.heldTurns or 0, complete = objective.complete == true }
end

function State:evacuationProgress(id)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    expect(objective.family == "evacuate", "objective is not evacuate")
    local completedObjectives = 0
    for _, objectiveId in ipairs(self.objectiveOrder or {}) do
        if objectiveId ~= id and self:objectiveStatus(objectiveId) == "complete" then
            completedObjectives = completedObjectives + 1
        end
    end
    return {
        objective = id,
        units = #(objective.evacuatedUnits or {}),
        requiredUnits = objective.minUnits or objective.evacuationsRequired or 1,
        objectives = completedObjectives,
        requiredObjectives = objective.minObjectives or 0,
        boardCollapseIn = objective.boardCollapseIn,
        complete = objective.complete == true,
        failed = objective.failed == true,
    }
end

function State:tickEvacuationObjective(id)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    expect(objective.family == "evacuate", "objective is not evacuate")
    if objective.complete or objective.failed then
        return self:evacuationProgress(id)
    end
    if objective.boardCollapseIn ~= nil then
        objective.boardCollapseIn = objective.boardCollapseIn - 1
        if objective.boardCollapseIn <= 0 and self:evaluateObjective(objective) ~= "complete" then
            objective.failed = true
            objective.failureCarryover = { reason = "board_collapse", evacuatedUnits = #(objective.evacuatedUnits or {}) }
        end
    end
    return self:evacuationProgress(id)
end

function State:splitObjectivePreview(id, options)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    expect(objective.family == "split", "objective is not split")
    options = options or {}
    local rotation = options.rotation or options.viewRotation or 0
    local switches = {}
    for _, switch in ipairs(objective.switches or {}) do
        local hidden = switch.revealRotation ~= nil and (switch.revealRotation % 4) ~= (rotation % 4)
        switches[#switches + 1] = {
            id = switch.id,
            x = hidden and nil or switch.x,
            y = hidden and nil or switch.y,
            activated = switch.activated == true,
            hidden = hidden,
            dependency = hidden and nil or switch.dependency,
        }
    end
    return { objective = id, switches = switches, complete = objective.complete == true }
end

function State:activateSplitObjective(id, switchId, unitId)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    expect(objective.family == "split", "objective is not split")
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    for _, switch in ipairs(objective.switches or {}) do
        if switch.id == switchId then
            expect(unit.x == switch.x and unit.y == switch.y, "unit is not on split switch")
            switch.activated = true
            self:evaluateObjective(objective)
            return switch
        end
    end
    error("unknown split switch " .. tostring(switchId), 2)
end

function State:stealthReadObjective(id, unitId, amount)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    expect(objective.family == "stealth", "objective is not stealth")
    expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    if objective.exposureCap ~= nil and self.exposure > objective.exposureCap then
        objective.failed = true
        objective.failureCarryover = { reason = "exposure_cap", exposure = self.exposure, cap = objective.exposureCap }
        return objective
    end
    objective.readCount = (objective.readCount or 0) + (amount or 1)
    self:evaluateObjective(objective)
    return objective
end

function State:chooseSacrificeObjective(id, choiceId)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    expect(objective.family == "sacrifice", "objective is not sacrifice")
    for _, choice in ipairs(objective.choices or {}) do
        if choice.id == choiceId then
            if choice.squadDamage then
                for _, unit in pairs(self.units) do
                    if unit.side == "player" and unit.alive and not unit.evacuated then
                        self:damageUnit(unit, choice.squadDamage, { ignoreStatusBonus = true })
                    end
                end
            end
            if choice.objectiveDamage then
                self:damageObjective(id, choice.objectiveDamage)
            end
            objective.choice = choiceId
            objective.lootLost = choice.lootLost
            objective.factionStandingDelta = choice.factionStandingDelta
            objective.complete = true
            return objective
        end
    end
    error("unknown sacrifice choice " .. tostring(choiceId), 2)
end

function State:counterBossProcedureObjective(id, stepId, options)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    expect(objective.family == "boss", "objective is not boss")
    options = options or {}
    for _, step in ipairs(objective.ritualSteps or {}) do
        if step.id == stepId then
            if step.weakPoint then
                expect(options.weakPoint == step.weakPoint, "wrong weak point counter")
            end
            if step.terrain then
                local tile = self:tileAt(expectInteger(step.terrain.x, "counter terrain x"), expectInteger(step.terrain.y, "counter terrain y"))
                expect(tile.state == step.terrain.state, "terrain counter state missing")
            end
            step.countered = true
            self:evaluateObjective(objective)
            return step
        end
    end
    error("unknown boss procedure step " .. tostring(stepId), 2)
end

function State:sacrificeObjective(id, reason)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    objective.sacrificed = true
    objective.failed = true
    objective.failureCarryover = { reason = reason or "sacrificed", integrity = objective.integrity or 0 }
    return objective
end

function State:objectiveResult(id)
    local objective = expect(self.objectives[id], "unknown objective " .. tostring(id))
    local status = self:evaluateObjective(objective)
    local maxIntegrity = math.max(1, objective.maxIntegrity or objective.integrity or 1)
    local ratio = math.max(0, objective.integrity or 0) / maxIntegrity
    return {
        status = status,
        integrityRatio = ratio,
        partialSuccess = status == "active" and objective.allowPartial == true and ratio > 0,
        failureCarryover = copyMap(objective.failureCarryover),
        extracted = objective.extracted == true,
        disabled = objective.disabled == true,
        relocated = objective.relocated == true,
        sacrificed = objective.sacrificed == true,
        choice = objective.choice,
        lootLost = objective.lootLost,
        factionStandingDelta = objective.factionStandingDelta,
    }
end

function State:damageObjectiveAt(x, y, amount)
    local objective = self:objectiveAt(x, y)
    if not objective then
        return nil
    end
    return self:damageObjective(objective.id, amount)
end

function State:damageCargo(id, amount)
    local cargo = expect(self.cargo[id], "unknown cargo " .. tostring(id))
    amount = expectInteger(amount or 0, "cargo damage")
    expect(amount >= 0, "cargo damage must be non-negative")
    if cargo.integrity == nil or cargo.failed or cargo.extracted then
        return cargo.integrity
    end
    cargo.integrity = math.max(0, cargo.integrity - amount)
    if cargo.integrity <= 0 then
        cargo.failed = true
        if cargo.carriedBy and self.units[cargo.carriedBy] then
            self.units[cargo.carriedBy].carryingCargo = nil
        end
        cargo.carriedBy = nil
    end
    return cargo.integrity
end

local function adjacentOrSame(a, b)
    return Grid.manhattan(a.x, a.y, b.x, b.y) <= 1
end

function State:carryCargo(unitId, cargoId)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    local cargo = expect(self.cargo[cargoId], "unknown cargo " .. tostring(cargoId))
    expect(unit.alive and not unit.evacuated, "unit is not active")
    expect(not unit.carryingCargo, "unit already carrying cargo")
    expect(not cargo.carriedBy and not cargo.extracted and not cargo.failed, "cargo is not available")
    expect(adjacentOrSame(unit, cargo), "cargo is not adjacent")
    unit.carryingCargo = cargoId
    cargo.carriedBy = unitId
    cargo.x = unit.x
    cargo.y = unit.y
    return cargo
end

function State:dropCargo(unitId, direction)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    local cargoId = expect(unit.carryingCargo, "unit is not carrying cargo")
    local cargo = expect(self.cargo[cargoId], "unknown cargo " .. tostring(cargoId))
    local x = unit.x
    local y = unit.y
    if direction then
        local delta = Grid.directions[direction]
        expect(delta, "unknown direction " .. tostring(direction))
        x = x + delta.x
        y = y + delta.y
    end
    expect(self:inBounds(x, y), "drop tile out of bounds")
    expect(not self:cargoAt(x, y), "drop tile has cargo")
    unit.carryingCargo = nil
    cargo.carriedBy = nil
    cargo.x = x
    cargo.y = y
    return cargo
end

function State:dragCargo(unitId, cargoId, direction)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    local cargo = expect(self.cargo[cargoId], "unknown cargo " .. tostring(cargoId))
    expect(unit.alive and not unit.evacuated, "unit is not active")
    expect(not cargo.carriedBy and not cargo.extracted and not cargo.failed, "cargo is not available")
    expect(Grid.manhattan(unit.x, unit.y, cargo.x, cargo.y) == 1, "cargo is not adjacent")
    local delta = Grid.directions[direction]
    expect(delta, "unknown direction " .. tostring(direction))
    local nx = cargo.x + delta.x
    local ny = cargo.y + delta.y
    expect(self:inBounds(nx, ny), "drag tile out of bounds")
    expect(not self:cargoAt(nx, ny), "drag tile has cargo")
    cargo.x = nx
    cargo.y = ny
    local tile = self:tileAt(nx, ny)
    local damage = (tile.hazard and (tile.hazard.dragDamage or tile.hazard.carryDamage)) or 0
    if damage > 0 then
        self:damageCargo(cargo.id, damage)
    end
    return cargo
end

local function addTag(tags, value)
    for _, tag in ipairs(tags or {}) do
        if tag == value then
            return
        end
    end
    tags[#tags + 1] = value
end

function State:interactTile(unitId, x, y)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    x = expectInteger(x, "interact x")
    y = expectInteger(y, "interact y")
    expect(unit.alive and not unit.evacuated, "unit is not active")
    expect(self:inBounds(x, y), "interact tile out of bounds")
    expect(Grid.manhattan(unit.x, unit.y, x, y) <= 1, "interact tile is not adjacent")
    local key = tileKey(x, y)
    local tile = self.board.tiles[key] or normalizeTile()
    local kind = tile.interact.kind or tile.kind
    if kind == "valve" then
        tile.state = tile.state == "open" and "closed" or "open"
        tile.hazard.kind = tile.hazard.kind or "flood"
        tile.hazard.active = tile.state == "open"
    elseif kind == "door" then
        tile.state = "open"
        tile.blocker = false
        tile.losBlocker = false
    elseif kind == "seal" then
        tile.state = "sealed"
        tile.blocker = true
        tile.losBlocker = true
    elseif kind == "shelf" then
        tile.state = "braced"
        tile.coverEdges = { north = "full", east = "half", south = "full", west = "half" }
        tile.losBlocker = true
    elseif kind == "furnace" then
        tile.state = tile.state == "lit" and "doused" or "lit"
        tile.hazard.kind = "heat"
        tile.hazard.damage = tile.state == "lit" and (tile.hazard.damage or 1) or 0
        tile.hazard.active = tile.state == "lit"
    elseif kind == "bridge" then
        tile.state = "lowered"
        tile.blocker = false
        tile.losBlocker = false
        addTag(tile.tags, "bridge_lowered")
    elseif kind == "terminal" then
        tile.state = "used"
        for _, boardTile in pairs(self.board.tiles) do
            boardTile.revealed = true
        end
    elseif kind == "bell" then
        tile.state = "rung"
        self.exposure = self.exposure + (tile.interact.exposure or 1)
    elseif kind == "extraction" then
        tile.state = "used"
        if unit.carryingCargo then
            local cargo = self.cargo[unit.carryingCargo]
            if cargo then
                cargo.extracted = true
                cargo.carriedBy = nil
            end
            unit.carryingCargo = nil
        else
            unit.evacuated = true
            unit.ap = 0
        end
    else
        error("unsupported interaction " .. tostring(kind), 2)
    end
    self.board.tiles[key] = tile
    return tile
end

function State:convertTile(x, y, conversion)
    x = expectInteger(x, "convert x")
    y = expectInteger(y, "convert y")
    expect(self:inBounds(x, y), "convert tile out of bounds")
    expect(terrainConversions[conversion], "unsupported terrain conversion " .. tostring(conversion))
    local key = tileKey(x, y)
    local tile = self.board.tiles[key] or normalizeTile()
    if conversion == "flood" then
        tile.material = "salt"
        tile.hazard = { kind = "flood", active = true, damage = tile.hazard.damage or 1 }
        tile.state = "flooded"
    elseif conversion == "drain" then
        tile.hazard = { kind = "flood", active = false, damage = 0 }
        tile.state = "drained"
    elseif conversion == "burn" then
        tile.material = "ember"
        tile.hazard = { kind = "burn", active = true, damage = tile.hazard.damage or 1 }
        tile.state = "burning"
    elseif conversion == "ash_choke" then
        tile.material = "ash"
        tile.hazard = { kind = "ash_choke", active = true, damage = 0 }
        tile.losBlocker = true
        tile.state = "ash_choke"
    elseif conversion == "glassify" then
        tile.material = "glass"
        tile.hazard = { kind = "glass", active = false, damage = 0 }
        tile.coverEdges = emptyCoverEdges()
        tile.state = "glassified"
    elseif conversion == "collapse" then
        tile.blocker = true
        tile.losBlocker = true
        tile.height = math.max(tile.height or 0, 1)
        tile.state = "collapsed"
    elseif conversion == "raise_cover" then
        tile.coverEdges = { north = "half", east = "half", south = "half", west = "half" }
        tile.state = "cover_raised"
    elseif conversion == "lower_cover" then
        tile.coverEdges = emptyCoverEdges()
        tile.state = "cover_lowered"
    elseif conversion == "seal_tile" then
        tile.blocker = true
        tile.losBlocker = true
        tile.state = "sealed"
    elseif conversion == "open_tile" then
        tile.blocker = false
        tile.losBlocker = false
        tile.state = "open"
    elseif conversion == "bend_los" then
        tile.losBlocker = false
        tile.losBent = true
        tile.state = "los_bent"
    end
    self.board.tiles[key] = tile
    return tile
end

function State:grantReward(reward)
    expect(type(reward) == "table", "reward must be a table")
    local kind = expect(reward.kind, "reward kind required")
    expect(rewardKinds[kind], "unsupported tactical reward " .. tostring(kind))
    local id = expect(reward.id, "reward id required")
    expect(not reward.stat and not reward.statBonus and not reward.permanentStat, "raw stat rewards are not tactical rewards")
    self.unlocks[kind] = self.unlocks[kind] or {}
    self.unlocks[kind][id] = {
        id = id,
        kind = kind,
        option = reward.option or id,
        source = reward.source,
    }
    return self.unlocks[kind][id]
end

function State:evacuateUnit(unitId, objectiveId)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    local objective = expect(self.objectives[objectiveId], "unknown objective " .. tostring(objectiveId))
    expect(unit.alive and not unit.evacuated, "unit cannot evacuate")
    expect(unit.x == objective.evacuateAt.x and unit.y == objective.evacuateAt.y, "unit is not on evacuation tile")
    expect(self:evaluateObjective(objective) ~= "failed", "objective already failed")
    if not containsUnitId(objective.evacuatedUnits, unitId) then
        objective.evacuatedUnits[#objective.evacuatedUnits + 1] = unitId
    end
    unit.evacuated = true
    unit.ap = 0
    return self:evaluateObjective(objective)
end

function State:resolveThreatAt(unit)
    for _, zone in ipairs(self.threatZones or {}) do
        local source = self.units[zone.unit]
        local phaseOk = not zone.triggerPhase or self.phase == zone.triggerPhase
        if phaseOk and source and source.alive and zone.side ~= unit.side and (zone.remaining or 0) > 0 and tileInList(zone.tiles, unit.x, unit.y) then
            self:applyThreatReaction(source, unit, zone)
            zone.remaining = zone.remaining - 1
        end
    end
    self:pruneThreatZones()
end

function State:startTurn(side)
    self.phase = side or self.phase
    for _, unit in ipairs(self:unitsForSide(self.phase)) do
        unit.ap = unit.maxAp or self.rules.defaultAp
    end
end

function State:displaceUnit(unitOrId, dx, dy, distance, collisionDamage)
    local unit = type(unitOrId) == "table" and unitOrId or expect(self.units[unitOrId], "unknown unit " .. tostring(unitOrId))
    if self:hasStatus(unit, "anchored") then
        return false, "anchored"
    end
    distance = distance or 1
    collisionDamage = collisionDamage or 1
    for _ = 1, distance do
        local nx = unit.x + dx
        local ny = unit.y + dy
        local ok, reason = self:canEnter(nx, ny, unit.id, unit.x, unit.y)
        if not ok then
            self:damageUnit(unit, math.max(0, collisionDamage - bracedReduction(unit)), { ignoreStatusBonus = true })
            local occupant = self:inBounds(nx, ny) and self:unitAt(nx, ny) or nil
            if occupant and occupant.id ~= unit.id then
                self:damageUnit(occupant, math.max(0, collisionDamage - bracedReduction(occupant)), { ignoreStatusBonus = true })
            end
            return false, reason
        end
        unit.x = nx
        unit.y = ny
        self:damageObjectiveAt(unit.x, unit.y, collisionDamage)
        self:resolveThreatAt(unit)
    end
    return true
end

function State:dashUnit(unitId, direction, distance, previewOnly)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    expect(unit.alive and not unit.evacuated, "unit is not active")
    expect(not self:movementBlocked(unit), "unit movement blocked")
    local delta = Grid.directions[direction]
    expect(delta, "unknown direction " .. tostring(direction))
    distance = distance or 2
    expect(distance > 0, "dash distance must be positive")
    local steps = {}
    local x = unit.x
    local y = unit.y
    for _ = 1, distance do
        x = x + delta.x
        y = y + delta.y
        local ok, reason = self:canEnter(x, y, unit.id, unit.x, unit.y)
        if not ok then
            error("dash rejected: " .. reason, 2)
        end
        steps[#steps + 1] = { x = x, y = y }
    end
    if previewOnly then
        return steps
    end
    for _, step in ipairs(steps) do
        self:moveUnitTo(unit, step.x, step.y)
        if not unit.alive then
            break
        end
    end
end

function State:vaultUnit(unitId, direction, previewOnly)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    expect(unit.alive and not unit.evacuated, "unit is not active")
    expect(not self:movementBlocked(unit), "unit movement blocked")
    local delta = Grid.directions[direction]
    expect(delta, "unknown direction " .. tostring(direction))
    local fromTile = self:tileAt(unit.x, unit.y)
    local nx = unit.x + delta.x
    local ny = unit.y + delta.y
    local toTile = self:tileAt(nx, ny)
    local cover = (fromTile.coverEdges and fromTile.coverEdges[direction]) or (toTile.coverEdges and toTile.coverEdges[oppositeDirection[direction]]) or "none"
    expect(cover == "half", "vault requires half cover edge")
    local ok, reason = self:canEnter(nx, ny, unit.id, unit.x, unit.y)
    if not ok then
        error("vault rejected: " .. reason, 2)
    end
    if previewOnly then
        return { x = nx, y = ny }
    end
    self:moveUnitTo(unit, nx, ny)
end

function State:climbUnit(unitId, direction, maxClimb, previewOnly)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    expect(unit.alive and not unit.evacuated, "unit is not active")
    expect(not self:movementBlocked(unit), "unit movement blocked")
    local delta = Grid.directions[direction]
    expect(delta, "unknown direction " .. tostring(direction))
    local fromHeight = self:tileAt(unit.x, unit.y).height or 0
    local nx = unit.x + delta.x
    local ny = unit.y + delta.y
    local toHeight = self:tileAt(nx, ny).height or 0
    expect(toHeight > fromHeight and toHeight - fromHeight <= (maxClimb or 1), "climb height rejected")
    local ok, reason = self:canEnter(nx, ny, unit.id, unit.x, unit.y)
    if not ok then
        error("climb rejected: " .. reason, 2)
    end
    if previewOnly then
        return { x = nx, y = ny }
    end
    self:moveUnitTo(unit, nx, ny)
end

function State:dropUnit(unitId, direction, maxDrop, previewOnly)
    local unit = expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    expect(unit.alive and not unit.evacuated, "unit is not active")
    expect(not self:movementBlocked(unit), "unit movement blocked")
    local delta = Grid.directions[direction]
    expect(delta, "unknown direction " .. tostring(direction))
    local fromHeight = self:tileAt(unit.x, unit.y).height or 0
    local nx = unit.x + delta.x
    local ny = unit.y + delta.y
    local toHeight = self:tileAt(nx, ny).height or 0
    expect(toHeight < fromHeight and fromHeight - toHeight <= (maxDrop or 2), "drop height rejected")
    local ok, reason = self:canEnter(nx, ny, unit.id, unit.x, unit.y)
    if not ok then
        error("drop rejected: " .. reason, 2)
    end
    if previewOnly then
        return { x = nx, y = ny }
    end
    self:moveUnitTo(unit, nx, ny)
end

function State:swapUnits(aId, bId)
    local a = expect(self.units[aId], "unknown unit " .. tostring(aId))
    local b = expect(self.units[bId], "unknown unit " .. tostring(bId))
    expect(a.alive and not a.evacuated, "unit is not active")
    expect(b.alive and not b.evacuated, "target is not active")
    a.x, b.x = b.x, a.x
    a.y, b.y = b.y, a.y
    self:resolveThreatAt(a)
    self:resolveThreatAt(b)
end

local function pullDelta(actor, target)
    local dx = actor.x - target.x
    local dy = actor.y - target.y
    if math.abs(dx) >= math.abs(dy) and dx ~= 0 then
        return dx > 0 and 1 or -1, 0
    end
    if dy ~= 0 then
        return 0, dy > 0 and 1 or -1
    end
    return 0, 0
end

function State:step()
    local command = table.remove(self.pending, 1)
    if not command then
        return false
    end
    self:apply(command)
    return true
end

function State:apply(command)
    expect(type(command) == "table", "command must be a table")
    local kind = expect(command.type, "command type required")
    if kind == "move" then
        local unit = expect(self.units[command.unit], "unknown unit " .. tostring(command.unit))
        expect(unit.alive and not unit.evacuated, "unit is not active")
        expect(not self:movementBlocked(unit), "unit movement blocked")
        local delta = Grid.directions[command.direction]
        expect(delta, "unknown direction " .. tostring(command.direction))
        local nx = unit.x + delta.x
        local ny = unit.y + delta.y
        local ok, reason = self:canEnter(nx, ny, unit.id, unit.x, unit.y)
        if not ok then
            error("move rejected: " .. reason, 2)
        end
        self:spendAP(unit.id, command.cost or self.rules.moveApCost)
        self:moveUnitTo(unit, nx, ny)
    elseif kind == "wait" then
        expect(self.units[command.unit], "unknown unit " .. tostring(command.unit))
        self:spendAP(command.unit, command.cost or 0)
    elseif kind == "select" then
        self:selectUnit(command.unit)
    elseif kind == "spend" then
        self:spendAP(command.unit, command.amount or 0)
    elseif kind == "endTurn" then
        self:startTurn(command.nextSide or command.side or self.phase)
    elseif kind == "attack" then
        expect(self.units[command.target], "unknown target " .. tostring(command.target))
        local resolved = self:attackResolution(command.unit, command.target, command.damage or 1)
        self:spendAP(command.unit, command.cost or 1)
        self:damageUnit(command.target, resolved.damage)
    elseif kind == "heal" then
        expect(self.units[command.target], "unknown target " .. tostring(command.target))
        self:spendAP(command.unit, command.cost or 1)
        self:healUnit(command.target, command.amount or 1)
    elseif kind == "aoe" then
        self:spendAP(command.unit, command.cost or 1)
        local tiles = normalizeTileList(command.tiles)
        for _, unit in pairs(self.units) do
            if unit.alive and tileInList(tiles, unit.x, unit.y) then
                self:damageUnit(unit, command.damage or 1)
            end
        end
    elseif kind == "shove" then
        expect(self.units[command.target], "unknown target " .. tostring(command.target))
        local delta = Grid.directions[command.direction]
        expect(delta, "unknown direction " .. tostring(command.direction))
        self:spendAP(command.unit, command.cost or 1)
        self:displaceUnit(command.target, delta.x, delta.y, command.distance or 1, command.collisionDamage or 1)
    elseif kind == "pull" then
        local actor = expect(self.units[command.unit], "unknown unit " .. tostring(command.unit))
        local target = expect(self.units[command.target], "unknown target " .. tostring(command.target))
        local dx, dy = pullDelta(actor, target)
        expect(dx ~= 0 or dy ~= 0, "target already adjacent to pull source")
        self:spendAP(command.unit, command.cost or 1)
        self:displaceUnit(target, dx, dy, command.distance or 1, command.collisionDamage or 1)
    elseif kind == "swap" then
        expect(self.units[command.target], "unknown target " .. tostring(command.target))
        self:spendAP(command.unit, command.cost or 1)
        self:swapUnits(command.unit, command.target)
    elseif kind == "dash" then
        self:dashUnit(command.unit, command.direction, command.distance, true)
        self:spendAP(command.unit, command.cost or 1)
        self:dashUnit(command.unit, command.direction, command.distance)
    elseif kind == "vault" then
        self:vaultUnit(command.unit, command.direction, true)
        self:spendAP(command.unit, command.cost or 1)
        self:vaultUnit(command.unit, command.direction)
    elseif kind == "climb" then
        self:climbUnit(command.unit, command.direction, command.maxClimb, true)
        self:spendAP(command.unit, command.cost or 1)
        self:climbUnit(command.unit, command.direction, command.maxClimb)
    elseif kind == "drop" then
        self:dropUnit(command.unit, command.direction, command.maxDrop, true)
        self:spendAP(command.unit, command.cost or 1)
        self:dropUnit(command.unit, command.direction, command.maxDrop)
    elseif kind == "overwatch" then
        local unit = expect(self.units[command.unit], "unknown unit " .. tostring(command.unit))
        expect(not self:hasStatus(unit, "blinded"), "unit is blinded")
        if command.cone then
            self:threatZoneTiles(command.unit, "cone", { direction = command.facing or command.direction, length = command.range or command.length, width = command.arc or command.width })
        elseif command.shape then
            self:threatZoneTiles(command.unit, command.shape, { direction = command.direction, length = command.length, width = command.width })
        else
            normalizeTileList(command.tiles)
        end
        self:spendAP(command.unit, command.cost or 1)
        if command.cone then
            self:declareOverwatch(command.unit, { facing = command.facing or command.direction, range = command.range or command.length, arc = command.arc or command.width, reaction = command.reaction, reactionKind = command.reactionKind, damage = command.damage, turns = command.turns, amount = command.amount, limit = command.limit, label = command.label })
        elseif command.shape then
            self:addThreatZoneShape(command.unit, command.shape, { direction = command.direction, length = command.length, width = command.width, damage = command.damage, limit = command.limit, label = command.label, reaction = command.reaction, triggerPhase = command.triggerPhase })
        else
            self:addThreatZone(command.unit, command.tiles, { damage = command.damage, limit = command.limit, label = command.label, reaction = command.reaction })
        end
    elseif kind == "damageTile" then
        self:spendAP(command.unit, command.cost or 1)
        self:damageTile(expectInteger(command.x, "tile x"), expectInteger(command.y, "tile y"), command.damage or 1)
    elseif kind == "intent" then
        self:declareIntent(command.unit, command.intent)
    elseif kind == "damageObjective" then
        expect(self.objectives[command.objective], "unknown objective " .. tostring(command.objective))
        self:spendAP(command.unit, command.cost or 0)
        self:damageObjective(command.objective, command.damage or 1)
    elseif kind == "repairObjective" then
        expect(self.objectives[command.objective], "unknown objective " .. tostring(command.objective))
        self:spendAP(command.unit, command.cost or 1)
        self:repairObjective(command.objective, command.amount or 1)
    elseif kind == "relocateObjective" then
        expect(self.objectives[command.objective], "unknown objective " .. tostring(command.objective))
        expect(self:inBounds(expectInteger(command.x, "objective x"), expectInteger(command.y, "objective y")), "objective relocation out of bounds")
        expect(not self:tileAt(command.x, command.y).blocker, "objective relocation blocked")
        self:spendAP(command.unit, command.cost or 1)
        self:relocateObjective(command.objective, command.x, command.y)
    elseif kind == "extractObjective" then
        local objective = expect(self.objectives[command.objective], "unknown objective " .. tostring(command.objective))
        expect(not objective.failed, "objective already failed")
        self:spendAP(command.unit, command.cost or 1)
        self:extractObjective(command.objective)
    elseif kind == "extractCargo" then
        expect(self.objectives[command.objective], "unknown objective " .. tostring(command.objective))
        self:spendAP(command.unit, command.cost or 1)
        self:extractCargo(command.unit, command.objective)
    elseif kind == "disableObjective" then
        expect(self.objectives[command.objective], "unknown objective " .. tostring(command.objective))
        self:spendAP(command.unit, command.cost or 1)
        self:disableObjective(command.objective, command.reason)
    elseif kind == "tickHoldObjective" then
        self:tickHoldObjective(command.objective)
    elseif kind == "tickEvacuationObjective" then
        self:tickEvacuationObjective(command.objective)
    elseif kind == "activateSplitObjective" then
        self:spendAP(command.unit, command.cost or 1)
        self:activateSplitObjective(command.objective, command.switch, command.unit)
    elseif kind == "stealthReadObjective" then
        self:spendAP(command.unit, command.cost or 1)
        self:stealthReadObjective(command.objective, command.unit, command.amount)
    elseif kind == "chooseSacrificeObjective" then
        self:chooseSacrificeObjective(command.objective, command.choice)
    elseif kind == "counterBossProcedureObjective" then
        self:counterBossProcedureObjective(command.objective, command.step, command.options)
    elseif kind == "sacrificeObjective" then
        expect(self.objectives[command.objective], "unknown objective " .. tostring(command.objective))
        self:spendAP(command.unit, command.cost or 0)
        self:sacrificeObjective(command.objective, command.reason)
    elseif kind == "evacuate" then
        local unit = expect(self.units[command.unit], "unknown unit " .. tostring(command.unit))
        local objective = expect(self.objectives[command.objective], "unknown objective " .. tostring(command.objective))
        expect(unit.alive and not unit.evacuated, "unit cannot evacuate")
        expect(unit.x == objective.evacuateAt.x and unit.y == objective.evacuateAt.y, "unit is not on evacuation tile")
        expect(self:evaluateObjective(objective) ~= "failed", "objective already failed")
        self:spendAP(command.unit, command.cost or 1)
        self:evacuateUnit(command.unit, command.objective)
    elseif kind == "carryCargo" then
        local unit = expect(self.units[command.unit], "unknown unit " .. tostring(command.unit))
        local cargo = expect(self.cargo[command.cargo], "unknown cargo " .. tostring(command.cargo))
        expect(unit.alive and not unit.evacuated, "unit is not active")
        expect(not unit.carryingCargo, "unit already carrying cargo")
        expect(not cargo.carriedBy and not cargo.extracted and not cargo.failed, "cargo is not available")
        expect(adjacentOrSame(unit, cargo), "cargo is not adjacent")
        self:spendAP(command.unit, command.cost or 1)
        self:carryCargo(command.unit, command.cargo)
    elseif kind == "dropCargo" then
        local unit = expect(self.units[command.unit], "unknown unit " .. tostring(command.unit))
        local cargoId = expect(unit.carryingCargo, "unit is not carrying cargo")
        local x = unit.x
        local y = unit.y
        if command.direction then
            local delta = Grid.directions[command.direction]
            expect(delta, "unknown direction " .. tostring(command.direction))
            x = x + delta.x
            y = y + delta.y
        end
        expect(self.cargo[cargoId], "unknown cargo " .. tostring(cargoId))
        expect(self:inBounds(x, y), "drop tile out of bounds")
        expect(not self:cargoAt(x, y), "drop tile has cargo")
        self:spendAP(command.unit, command.cost or 0)
        self:dropCargo(command.unit, command.direction)
    elseif kind == "dragCargo" then
        local unit = expect(self.units[command.unit], "unknown unit " .. tostring(command.unit))
        local cargo = expect(self.cargo[command.cargo], "unknown cargo " .. tostring(command.cargo))
        local delta = Grid.directions[command.direction]
        expect(unit.alive and not unit.evacuated, "unit is not active")
        expect(not cargo.carriedBy and not cargo.extracted and not cargo.failed, "cargo is not available")
        expect(Grid.manhattan(unit.x, unit.y, cargo.x, cargo.y) == 1, "cargo is not adjacent")
        expect(delta, "unknown direction " .. tostring(command.direction))
        expect(self:inBounds(cargo.x + delta.x, cargo.y + delta.y), "drag tile out of bounds")
        expect(not self:cargoAt(cargo.x + delta.x, cargo.y + delta.y), "drag tile has cargo")
        self:spendAP(command.unit, command.cost or 1)
        self:dragCargo(command.unit, command.cargo, command.direction)
    elseif kind == "interactTile" then
        local unit = expect(self.units[command.unit], "unknown unit " .. tostring(command.unit))
        local x = expectInteger(command.x, "interact x")
        local y = expectInteger(command.y, "interact y")
        expect(unit.alive and not unit.evacuated, "unit is not active")
        expect(self:inBounds(x, y), "interact tile out of bounds")
        expect(Grid.manhattan(unit.x, unit.y, x, y) <= 1, "interact tile is not adjacent")
        local tile = self.board.tiles[tileKey(x, y)] or normalizeTile()
        expect(interactionKinds[tile.interact.kind or tile.kind], "unsupported interaction " .. tostring(tile.interact.kind or tile.kind))
        self:spendAP(command.unit, command.cost or 1)
        self:interactTile(command.unit, command.x, command.y)
    elseif kind == "convertTile" then
        expect(terrainConversions[command.conversion], "unsupported terrain conversion " .. tostring(command.conversion))
        expect(self:inBounds(expectInteger(command.x, "convert x"), expectInteger(command.y, "convert y")), "convert tile out of bounds")
        self:spendAP(command.unit, command.cost or 1)
        self:convertTile(command.x, command.y, command.conversion)
    elseif kind == "obscurant" then
        if command.unit then
            self:spendAP(command.unit, command.cost or 1)
        end
        self:addObscurant(command.x, command.y, command.kind, command.countdown)
    elseif kind == "tickObscurants" then
        self:tickObscurants()
    elseif kind == "status" then
        expect(self.units[command.target], "unknown unit " .. tostring(command.target))
        expect(statusRules[command.status], "unsupported status " .. tostring(command.status))
        self:spendAP(command.unit, command.cost or 1)
        self:applyStatus(command.target, command.status, command.turns, command.amount)
    elseif kind == "tickStatuses" then
        self:tickStatuses(command.unit)
    elseif kind == "tickIntentFuse" then
        self:tickIntentFuse(command.unit)
    elseif kind == "resolveConditionalIntent" then
        self:resolveConditionalIntent(command.unit)
    elseif kind == "interruptIntent" then
        self:interruptIntent(command.unit, command.interrupt)
    elseif kind == "advanceIntentPressure" then
        self:advanceIntentPressure(command.unit, command.outcome)
    elseif kind == "reduceIntent" then
        expect(self.units[command.target], "unknown unit " .. tostring(command.target))
        self:spendAP(command.unit, command.cost or 1)
        self:reduceIntent(command.target, command.amount or 1)
    elseif kind == "advanceBossIntentMask" then
        self:advanceBossIntentMask(command.unit, command.context)
    elseif kind == "classReveal" then
        self:spendAP(command.unit, command.cost or 1)
        self:classReveal(command.unit, command.options)
    elseif kind == "reward" then
        self:grantReward(command.reward)
    else
        error("unknown command " .. tostring(kind), 2)
    end
    self.tick = self.tick + 1
    self.log[#self.log + 1] = copyMap(command)
end

function State:snapshot()
    local tiles = {}
    for _, key in ipairs(sortedKeys(self.board.tiles)) do
        tiles[key] = copyMap(self.board.tiles[key])
    end
    local units = {}
    for _, id in ipairs(self.unitOrder) do
        units[#units + 1] = copyMap(self.units[id])
    end
    local objectives = {}
    for _, id in ipairs(self.objectiveOrder) do
        objectives[#objectives + 1] = copyMap(self.objectives[id])
    end
    local cargo = {}
    for _, id in ipairs(self.cargoOrder) do
        cargo[#cargo + 1] = copyMap(self.cargo[id])
    end
    return {
        version = 1,
        tick = self.tick,
        phase = self.phase,
        exposure = self.exposure,
        selectedUnitId = self.selectedUnitId,
        unlocks = copyMap(self.unlocks),
        rules = copyMap(self.rules),
        threatZones = copyMap(self.threatZones),
        intents = copyMap(self.intents),
        objectives = objectives,
        cargo = cargo,
        board = {
            width = self.board.width,
            height = self.board.height,
            expanse = self.board.expanse,
            regions = copyValue(self.board.regions),
            districts = copyValue(self.board.districts),
            softGates = copyValue(self.board.softGates),
            landmarks = copyValue(self.board.landmarks),
            metrics = copyValue(self.board.metrics),
            heightBands = copyValue(self.board.heightBands),
            coverFields = copyValue(self.board.coverFields),
            sightBreaks = copyValue(self.board.sightBreaks),
            verticalRoutes = copyValue(self.board.verticalRoutes),
            sightlines = copyValue(self.board.sightlines),
            megaStructures = copyValue(self.board.megaStructures),
            terrainTypes = copyValue(self.board.terrainTypes),
            generationTechniques = copyValue(self.board.generationTechniques),
            tiles = tiles,
        },
        units = units,
        log = copyList(self.log),
    }
end

function commands.move(unitId, direction, cost)
    return { type = "move", unit = unitId, direction = direction, cost = cost }
end

function commands.wait(unitId)
    return { type = "wait", unit = unitId }
end

function commands.select(unitId)
    return { type = "select", unit = unitId }
end

function commands.spend(unitId, amount, reason)
    return { type = "spend", unit = unitId, amount = amount, reason = reason }
end

function commands.endTurn(nextSide)
    return { type = "endTurn", nextSide = nextSide }
end

function commands.attack(unitId, targetId, damage, cost)
    return { type = "attack", unit = unitId, target = targetId, damage = damage, cost = cost }
end

function commands.heal(unitId, targetId, amount, cost)
    return { type = "heal", unit = unitId, target = targetId, amount = amount, cost = cost }
end

function commands.aoe(unitId, tiles, damage, cost)
    return { type = "aoe", unit = unitId, tiles = tiles, damage = damage, cost = cost }
end

function commands.shove(unitId, targetId, direction, distance, collisionDamage, cost)
    return { type = "shove", unit = unitId, target = targetId, direction = direction, distance = distance, collisionDamage = collisionDamage, cost = cost }
end

function commands.pull(unitId, targetId, distance, collisionDamage, cost)
    return { type = "pull", unit = unitId, target = targetId, distance = distance, collisionDamage = collisionDamage, cost = cost }
end

function commands.swap(unitId, targetId, cost)
    return { type = "swap", unit = unitId, target = targetId, cost = cost }
end

function commands.dash(unitId, direction, distance, cost)
    return { type = "dash", unit = unitId, direction = direction, distance = distance, cost = cost }
end

function commands.vault(unitId, direction, cost)
    return { type = "vault", unit = unitId, direction = direction, cost = cost }
end

function commands.climb(unitId, direction, maxClimb, cost)
    return { type = "climb", unit = unitId, direction = direction, maxClimb = maxClimb, cost = cost }
end

function commands.drop(unitId, direction, maxDrop, cost)
    return { type = "drop", unit = unitId, direction = direction, maxDrop = maxDrop, cost = cost }
end

function commands.overwatch(unitId, tiles, damage, limit, cost)
    return { type = "overwatch", unit = unitId, tiles = tiles, damage = damage, limit = limit, cost = cost }
end

function commands.threatZone(unitId, shape, direction, length, width, damage, limit, cost)
    return { type = "overwatch", unit = unitId, shape = shape, direction = direction, length = length, width = width, damage = damage, limit = limit, cost = cost }
end

function commands.overwatchCone(unitId, facing, range, arc, reaction, cost)
    return { type = "overwatch", unit = unitId, cone = true, facing = facing, range = range, arc = arc, reaction = reaction, cost = cost }
end

function commands.damageTile(unitId, x, y, damage, cost)
    return { type = "damageTile", unit = unitId, x = x, y = y, damage = damage, cost = cost }
end

function commands.intent(unitId, intent)
    return { type = "intent", unit = unitId, intent = intent }
end

function commands.damageObjective(unitId, objectiveId, damage, cost)
    return { type = "damageObjective", unit = unitId, objective = objectiveId, damage = damage, cost = cost }
end

function commands.repairObjective(unitId, objectiveId, amount, cost)
    return { type = "repairObjective", unit = unitId, objective = objectiveId, amount = amount, cost = cost }
end

function commands.relocateObjective(unitId, objectiveId, x, y, cost)
    return { type = "relocateObjective", unit = unitId, objective = objectiveId, x = x, y = y, cost = cost }
end

function commands.extractObjective(unitId, objectiveId, cost)
    return { type = "extractObjective", unit = unitId, objective = objectiveId, cost = cost }
end

function commands.extractCargo(unitId, objectiveId, cost)
    return { type = "extractCargo", unit = unitId, objective = objectiveId, cost = cost }
end

function commands.disableObjective(unitId, objectiveId, reason, cost)
    return { type = "disableObjective", unit = unitId, objective = objectiveId, reason = reason, cost = cost }
end

function commands.tickHoldObjective(objectiveId)
    return { type = "tickHoldObjective", objective = objectiveId }
end

function commands.tickEvacuationObjective(objectiveId)
    return { type = "tickEvacuationObjective", objective = objectiveId }
end

function commands.activateSplitObjective(unitId, objectiveId, switchId, cost)
    return { type = "activateSplitObjective", unit = unitId, objective = objectiveId, switch = switchId, cost = cost }
end

function commands.stealthReadObjective(unitId, objectiveId, amount, cost)
    return { type = "stealthReadObjective", unit = unitId, objective = objectiveId, amount = amount, cost = cost }
end

function commands.chooseSacrificeObjective(objectiveId, choiceId)
    return { type = "chooseSacrificeObjective", objective = objectiveId, choice = choiceId }
end

function commands.counterBossProcedureObjective(objectiveId, stepId, options)
    return { type = "counterBossProcedureObjective", objective = objectiveId, step = stepId, options = copyMap(options) }
end

function commands.sacrificeObjective(unitId, objectiveId, reason, cost)
    return { type = "sacrificeObjective", unit = unitId, objective = objectiveId, reason = reason, cost = cost }
end

function commands.evacuate(unitId, objectiveId, cost)
    return { type = "evacuate", unit = unitId, objective = objectiveId, cost = cost }
end

function commands.carryCargo(unitId, cargoId, cost)
    return { type = "carryCargo", unit = unitId, cargo = cargoId, cost = cost }
end

function commands.dropCargo(unitId, direction, cost)
    return { type = "dropCargo", unit = unitId, direction = direction, cost = cost }
end

function commands.dragCargo(unitId, cargoId, direction, cost)
    return { type = "dragCargo", unit = unitId, cargo = cargoId, direction = direction, cost = cost }
end

function commands.interactTile(unitId, x, y, cost)
    return { type = "interactTile", unit = unitId, x = x, y = y, cost = cost }
end

function commands.convertTile(unitId, x, y, conversion, cost)
    return { type = "convertTile", unit = unitId, x = x, y = y, conversion = conversion, cost = cost }
end

function commands.obscurant(unitId, x, y, kind, countdown, cost)
    return { type = "obscurant", unit = unitId, x = x, y = y, kind = kind, countdown = countdown, cost = cost }
end

function commands.tickObscurants()
    return { type = "tickObscurants" }
end

function commands.status(unitId, targetId, status, turns, amount, cost)
    return { type = "status", unit = unitId, target = targetId, status = status, turns = turns, amount = amount, cost = cost }
end

function commands.tickStatuses(unitId)
    return { type = "tickStatuses", unit = unitId }
end

function commands.tickIntentFuse(unitId)
    return { type = "tickIntentFuse", unit = unitId }
end

function commands.resolveConditionalIntent(unitId)
    return { type = "resolveConditionalIntent", unit = unitId }
end

function commands.interruptIntent(unitId, interrupt, options)
    options = options or {}
    local payload = type(interrupt) == "table" and copyMap(interrupt) or copyMap(options)
    payload.kind = payload.kind or interrupt
    return { type = "interruptIntent", unit = unitId, interrupt = payload }
end

function commands.advanceIntentPressure(unitId, outcome)
    return { type = "advanceIntentPressure", unit = unitId, outcome = outcome }
end

function commands.reduceIntent(unitId, targetId, amount, cost)
    return { type = "reduceIntent", unit = unitId, target = targetId, amount = amount, cost = cost }
end

function commands.advanceBossIntentMask(unitId, context)
    return { type = "advanceBossIntentMask", unit = unitId, context = copyMap(context) }
end

function commands.classReveal(unitId, options, cost)
    return { type = "classReveal", unit = unitId, options = copyMap(options), cost = cost }
end

function commands.reward(reward)
    return { type = "reward", reward = reward }
end

State.commands = commands

return State
