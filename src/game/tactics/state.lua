local Grid = require("src.core.grid")

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

local function normalizeTile(tile)
    tile = tile or {}
    local destructibleHp = tile.destructibleHp
    if destructibleHp == nil then
        destructibleHp = tile.hp
    end
    return {
        kind = tile.kind or tile.id or "floor",
        material = tile.material or tile.zoneMaterial or "archive",
        state = tile.state,
        height = expectInteger(tile.height or 0, "tile height"),
        coverEdges = normalizeCoverEdges(tile.coverEdges or tile.cover),
        blocker = tile.blocker == true,
        losBlocker = tile.losBlocker == true,
        destructibleHp = destructibleHp,
        hazard = copyMap(tile.hazard),
        objective = copyMap(tile.objective),
        interact = copyMap(tile.interact),
        revealed = tile.revealed ~= false,
        destroyed = tile.destroyed == true,
        rotationMarks = normalizeRotationMarks(tile.rotationMarks or tile.marks),
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
        category = category,
        target = intent.target,
        targetTiles = normalizeTileList(intent.tiles or intent.targetTiles),
        path = normalizeTileList(intent.path),
        damage = intent.damage or 0,
        effect = intent.effect,
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
    return {
        mode = mode,
        category = category,
        source = intent.source,
        sourceTile = copyMap(intent.sourceTile),
        target = intent.target,
        targetTiles = tiles,
        path = normalizeTileList(intent.path),
        damage = intent.damage or 0,
        effect = intent.effect,
        collision = copyMap(intent.collision),
        objectiveImpact = intent.objectiveImpact,
        countdown = countdown,
        anchor = anchor,
        trigger = trigger,
        branches = branches,
        revealed = intent.revealed == true,
        revealRotations = normalizeRotationList(intent.revealRotations),
        revealActions = copyList(intent.revealActions),
        revealClasses = copyList(intent.revealClasses),
        stage = intent.stage,
        stageCount = intent.stageCount,
        mask = intent.mask,
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

local function normalizeObjective(objective, index)
    expect(type(objective) == "table", "objective must be a table")
    local id = objective.id or ("objective_" .. tostring(index))
    expect(type(id) == "string" and id ~= "", "objective id must be a non-empty string")
    local kind = objective.kind or "protect_route_machinery"
    expect(kind == "protect_route_machinery", "unsupported objective kind " .. tostring(kind))
    local integrity = objective.integrity or objective.maxIntegrity or 1
    local evacuateAt = objective.evacuateAt or objective.exit
    expect(evacuateAt and evacuateAt.x and evacuateAt.y, "objective needs evacuation tile")
    return {
        id = id,
        kind = kind,
        x = expectInteger(objective.x, "objective x"),
        y = expectInteger(objective.y, "objective y"),
        integrity = integrity,
        maxIntegrity = objective.maxIntegrity or integrity,
        evacuateAt = { x = expectInteger(evacuateAt.x, "evacuation x"), y = expectInteger(evacuateAt.y, "evacuation y") },
        evacuationsRequired = objective.evacuationsRequired or 1,
        evacuatedUnits = copyList(objective.evacuatedUnits),
        extracted = objective.extracted == true,
        relocated = objective.relocated == true,
        sacrificed = objective.sacrificed == true,
        allowPartial = objective.allowPartial == true,
        failureCarryover = copyMap(objective.failureCarryover),
        complete = objective.complete == true,
        failed = objective.failed == true,
    }
end

local cargoKinds = {
    civilian = true,
    body = true,
    machinery_core = true,
    loot_crate = true,
    wounded_hero = true,
}

local cargoDefaultWeight = {
    civilian = 1,
    body = 1,
    machinery_core = 2,
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
    filed = {},
    redacted = {},
    sealed = {},
    stunned = {},
    blinded = {},
    braced = { amount = 1 },
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
    return {
        id = id,
        side = unit.side or "player",
        x = expectInteger(unit.x, "unit x"),
        y = expectInteger(unit.y, "unit y"),
        hp = unit.hp or 1,
        maxHp = unit.maxHp or unit.hp or 1,
        maxAp = maxAp,
        ap = unit.ap ~= nil and unit.ap or maxAp,
        alive = unit.alive ~= false,
        evacuated = unit.evacuated == true,
        carryingObjective = unit.carryingObjective,
        carryingCargo = unit.carryingCargo,
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
        },
        board = {
            width = width,
            height = height,
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

function State:unitAt(x, y)
    for _, id in ipairs(self.unitOrder) do
        local unit = self.units[id]
        if unit and unit.alive and not unit.evacuated and unit.x == x and unit.y == y then
            return unit
        end
    end
    return nil
end

function State:canEnter(x, y, movingUnitId)
    if not self:inBounds(x, y) then
        return false, "out_of_bounds"
    end
    if self:tileAt(x, y).blocker then
        return false, "blocked_tile"
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

local function tileHazardCost(tile)
    local hazard = tile and tile.hazard or nil
    if not hazard then
        return 0
    end
    return hazard.apCost or hazard.cost or hazard.damage or 0
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
        reachable[#reachable + 1] = {
            x = node.x,
            y = node.y,
            apCost = node.apCost,
            hazardCost = hazardCost,
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
            local ok, reason = self:canEnter(nx, ny, unit.id)
            if not ok then
                local key = tostring(node.x) .. ":" .. tostring(node.y) .. ":" .. direction
                if not collisionSeen[key] then
                    collisionSeen[key] = true
                    collisions[#collisions + 1] = { fromX = node.x, fromY = node.y, x = nx, y = ny, direction = direction, result = reason }
                end
            else
                local nextCost = node.apCost + stepCost
                local key = tileKey(nx, ny)
                if nextCost <= maxCost and (seen[key] == nil or nextCost < seen[key]) then
                    seen[key] = nextCost
                    local path = copyValue(node.path)
                    path[#path + 1] = direction
                    queue[#queue + 1] = { x = nx, y = ny, apCost = nextCost, path = path }
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
    unit.hp = math.max(0, (unit.hp or 0) - amount)
    if unit.hp <= 0 then
        unit.alive = false
        unit.ap = 0
    end
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
        tile.coverEdges = emptyCoverEdges()
        tile.destroyed = true
    end
    return tile.destructibleHp
end

local function tileInList(tiles, x, y)
    for _, tile in ipairs(tiles or {}) do
        if tile.x == x and tile.y == y then
            return true
        end
    end
    return false
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
    options = options or {}
    local zone = {
        unit = unitId,
        side = unit.side,
        tiles = normalizeTileList(tiles),
        damage = options.damage or 1,
        remaining = options.limit or options.remaining or 1,
        label = options.label or "overwatch",
    }
    expect(#zone.tiles > 0, "threat zone needs at least one tile")
    expect(zone.remaining > 0, "threat zone limit must be positive")
    self.threatZones[#self.threatZones + 1] = zone
    return zone
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
        category = intent.category,
        source = intent.source,
        sourceTile = copyMap(intent.sourceTile),
        target = intent.target,
        damage = intent.damage,
        effect = intent.effect,
        collision = copyMap(intent.collision),
        objectiveImpact = intent.objectiveImpact,
        countdown = intent.countdown,
        anchor = copyMap(intent.anchor),
        trigger = copyMap(intent.trigger),
        branches = copyValue(intent.branches),
        revealed = intent.revealed == true,
        revealRotations = copyList(intent.revealRotations),
        revealActions = copyList(intent.revealActions),
        revealClasses = copyList(intent.revealClasses),
        stage = intent.stage,
        stageCount = intent.stageCount,
        mask = intent.mask,
        label = intent.label,
    }
    if intent.mode == "exact" or intent.mode == "fuse" or (intent.mode == "hiddenFootprint" and reveal) or (intent.mode == "bossStage" and not intent.mask) then
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
    if #(objective.evacuatedUnits or {}) >= (objective.evacuationsRequired or 1) then
        objective.complete = true
        return "complete"
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
        relocated = objective.relocated == true,
        sacrificed = objective.sacrificed == true,
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
        if source and source.alive and zone.side ~= unit.side and (zone.remaining or 0) > 0 and tileInList(zone.tiles, unit.x, unit.y) then
            self:damageUnit(unit, zone.damage or 1)
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
    distance = distance or 1
    collisionDamage = collisionDamage or 1
    for _ = 1, distance do
        local nx = unit.x + dx
        local ny = unit.y + dy
        local ok, reason = self:canEnter(nx, ny, unit.id)
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
        local ok, reason = self:canEnter(x, y, unit.id)
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
    local ok, reason = self:canEnter(nx, ny, unit.id)
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
    local ok, reason = self:canEnter(nx, ny, unit.id)
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
    local ok, reason = self:canEnter(nx, ny, unit.id)
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
        local ok, reason = self:canEnter(nx, ny, unit.id)
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
        self:spendAP(command.unit, command.cost or 1)
        self:damageUnit(command.target, command.damage or 1)
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
        if command.shape then
            self:threatZoneTiles(command.unit, command.shape, { direction = command.direction, length = command.length, width = command.width })
        else
            normalizeTileList(command.tiles)
        end
        self:spendAP(command.unit, command.cost or 1)
        if command.shape then
            self:addThreatZoneShape(command.unit, command.shape, { direction = command.direction, length = command.length, width = command.width, damage = command.damage, limit = command.limit, label = command.label })
        else
            self:addThreatZone(command.unit, command.tiles, { damage = command.damage, limit = command.limit, label = command.label })
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
            tiles = tiles,
        },
        units = units,
        log = copyList(self.log),
    }
end

function commands.move(unitId, direction)
    return { type = "move", unit = unitId, direction = direction }
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

function commands.reward(reward)
    return { type = "reward", reward = reward }
end

State.commands = commands

return State
