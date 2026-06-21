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
        rotationMarks = normalizeRotationMarks(tile.rotationMarks or tile.marks),
        tags = copyList(tile.tags),
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
        if unit and unit.side == side and unit.alive then
            result[#result + 1] = unit
        end
    end
    return result
end

function State:unitAt(x, y)
    for _, id in ipairs(self.unitOrder) do
        local unit = self.units[id]
        if unit and unit.alive and unit.x == x and unit.y == y then
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

function State:startTurn(side)
    self.phase = side or self.phase
    for _, unit in ipairs(self:unitsForSide(self.phase)) do
        unit.ap = unit.maxAp or self.rules.defaultAp
    end
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
    elseif kind == "wait" then
        expect(self.units[command.unit], "unknown unit " .. tostring(command.unit))
        self:spendAP(command.unit, command.cost or 0)
    elseif kind == "select" then
        self:selectUnit(command.unit)
    elseif kind == "spend" then
        self:spendAP(command.unit, command.amount or 0)
    elseif kind == "endTurn" then
        self:startTurn(command.nextSide or command.side or self.phase)
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

State.commands = commands

return State
