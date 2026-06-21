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
        height = expectInteger(tile.height or 0, "tile height"),
        coverEdges = normalizeCoverEdges(tile.coverEdges or tile.cover),
        blocker = tile.blocker == true,
        losBlocker = tile.losBlocker == true,
        destructibleHp = destructibleHp,
        hazard = copyMap(tile.hazard),
        objective = copyMap(tile.objective),
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
}

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
    return {
        mode = mode,
        category = category,
        source = intent.source,
        target = intent.target,
        targetTiles = tiles,
        path = normalizeTileList(intent.path),
        damage = intent.damage or 0,
        effect = intent.effect,
        objectiveImpact = intent.objectiveImpact,
        stage = intent.stage,
        stageCount = intent.stageCount,
        mask = intent.mask,
        label = intent.label,
    }
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
        complete = objective.complete == true,
        failed = objective.failed == true,
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
        selectedUnitId = options.selectedUnitId,
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
    return state
end

function State.fromSnapshot(snapshot)
    expect(type(snapshot) == "table", "snapshot must be a table")
    return State.new({
        tick = snapshot.tick or 0,
        phase = snapshot.phase or "player",
        selectedUnitId = snapshot.selectedUnitId,
        rules = snapshot.rules,
        board = snapshot.board or { width = snapshot.width, height = snapshot.height, tiles = snapshot.tiles },
        units = snapshot.units or {},
        threatZones = snapshot.threatZones or {},
        intents = snapshot.intents or {},
        objectives = snapshot.objectives or {},
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

function State:queue(command)
    expect(type(command) == "table", "command must be a table")
    self.pending[#self.pending + 1] = command
end

function State:selectUnit(id)
    local unit = expect(self.units[id], "unknown unit " .. tostring(id))
    expect(unit.alive, "unit is not alive")
    self.selectedUnitId = id
    return unit
end

function State:spendAP(id, amount)
    local unit = expect(self.units[id], "unknown unit " .. tostring(id))
    amount = expectInteger(amount, "ap cost")
    expect(amount >= 0, "ap cost must be non-negative")
    expect((unit.ap or 0) >= amount, "insufficient_ap")
    unit.ap = unit.ap - amount
    return unit.ap
end

function State:damageUnit(unitOrId, amount)
    local unit = type(unitOrId) == "table" and unitOrId or expect(self.units[unitOrId], "unknown unit " .. tostring(unitOrId))
    amount = expectInteger(amount or 0, "damage")
    expect(amount >= 0, "damage must be non-negative")
    if amount == 0 or not unit.alive or unit.evacuated then
        return unit.hp
    end
    unit.hp = math.max(0, (unit.hp or 0) - amount)
    if unit.hp <= 0 then
        unit.alive = false
        unit.ap = 0
    end
    return unit.hp
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

function State:declareIntent(unitId, intent)
    expect(self.units[unitId], "unknown unit " .. tostring(unitId))
    local normalized = normalizeIntent(intent)
    normalized.source = normalized.source or unitId
    self.intents[unitId] = normalized
    return normalized
end

function State:intentPreview(unitId, options)
    local intent = self.intents[unitId]
    if not intent then
        return nil
    end
    options = options or {}
    local reveal = options == true or options.reveal == true
    local preview = {
        mode = intent.mode,
        category = intent.category,
        source = intent.source,
        target = intent.target,
        damage = intent.damage,
        effect = intent.effect,
        objectiveImpact = intent.objectiveImpact,
        stage = intent.stage,
        stageCount = intent.stageCount,
        mask = intent.mask,
        label = intent.label,
    }
    if intent.mode == "exact" or (intent.mode == "hiddenFootprint" and reveal) or (intent.mode == "bossStage" and not intent.mask) then
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

function State:evaluateObjective(objective)
    if objective.failed then
        return "failed"
    end
    if objective.complete then
        return "complete"
    end
    if (objective.integrity or 0) <= 0 then
        objective.failed = true
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
            self:damageUnit(unit, collisionDamage)
            local occupant = self:inBounds(nx, ny) and self:unitAt(nx, ny) or nil
            if occupant and occupant.id ~= unit.id then
                self:damageUnit(occupant, collisionDamage)
            end
            return false, reason
        end
        unit.x = nx
        unit.y = ny
        self:resolveThreatAt(unit)
    end
    return true
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
        expect(unit.alive, "unit is not alive")
        local delta = Grid.directions[command.direction]
        expect(delta, "unknown direction " .. tostring(command.direction))
        local nx = unit.x + delta.x
        local ny = unit.y + delta.y
        local ok, reason = self:canEnter(nx, ny, unit.id)
        if not ok then
            error("move rejected: " .. reason, 2)
        end
        self:spendAP(unit.id, command.cost or self.rules.moveApCost)
        unit.x = nx
        unit.y = ny
        self:resolveThreatAt(unit)
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
    elseif kind == "overwatch" then
        self:spendAP(command.unit, command.cost or 1)
        self:addThreatZone(command.unit, command.tiles, { damage = command.damage, limit = command.limit, label = command.label })
    elseif kind == "damageTile" then
        self:spendAP(command.unit, command.cost or 1)
        self:damageTile(expectInteger(command.x, "tile x"), expectInteger(command.y, "tile y"), command.damage or 1)
    elseif kind == "intent" then
        self:declareIntent(command.unit, command.intent)
    elseif kind == "damageObjective" then
        self:spendAP(command.unit, command.cost or 0)
        self:damageObjective(command.objective, command.damage or 1)
    elseif kind == "evacuate" then
        self:spendAP(command.unit, command.cost or 1)
        self:evacuateUnit(command.unit, command.objective)
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
    return {
        version = 1,
        tick = self.tick,
        phase = self.phase,
        selectedUnitId = self.selectedUnitId,
        rules = copyMap(self.rules),
        threatZones = copyMap(self.threatZones),
        intents = copyMap(self.intents),
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

function commands.overwatch(unitId, tiles, damage, limit, cost)
    return { type = "overwatch", unit = unitId, tiles = tiles, damage = damage, limit = limit, cost = cost }
end

function commands.damageTile(unitId, x, y, damage, cost)
    return { type = "damageTile", unit = unitId, x = x, y = y, damage = damage, cost = cost }
end

function commands.intent(unitId, intent)
    return { type = "intent", unit = unitId, intent = intent }
end

State.commands = commands

return State
