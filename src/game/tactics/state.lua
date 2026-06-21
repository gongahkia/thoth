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

local function copyMap(values)
    local result = {}
    for key, value in pairs(values or {}) do
        if type(value) == "table" then
            local nested = {}
            for nestedKey, nestedValue in pairs(value) do
                if type(nestedValue) == "table" then
                    nested[nestedKey] = copyList(nestedValue)
                else
                    nested[nestedKey] = nestedValue
                end
            end
            result[key] = nested
        else
            result[key] = value
        end
    end
    return result
end

local function tileKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function normalizeTile(tile)
    tile = tile or {}
    return {
        kind = tile.kind or tile.id or "floor",
        height = tile.height or 0,
        blocker = tile.blocker == true,
        tags = copyList(tile.tags),
    }
end

local function normalizeUnit(unit, index)
    expect(type(unit) == "table", "unit must be a table")
    local id = unit.id or ("unit_" .. tostring(index))
    expect(type(id) == "string" and id ~= "", "unit id must be a non-empty string")
    return {
        id = id,
        side = unit.side or "player",
        x = expectInteger(unit.x, "unit x"),
        y = expectInteger(unit.y, "unit y"),
        hp = unit.hp or 1,
        maxHp = unit.maxHp or unit.hp or 1,
        ap = unit.ap or 0,
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
        local normalized = normalizeUnit(unit, index)
        expect(state:inBounds(normalized.x, normalized.y), "unit " .. normalized.id .. " starts out of bounds")
        expect(not state:unitAt(normalized.x, normalized.y), "unit " .. normalized.id .. " starts on occupied tile")
        state.units[normalized.id] = normalized
        state.unitOrder[#state.unitOrder + 1] = normalized.id
    end
    return state
end

function State.fromSnapshot(snapshot)
    expect(type(snapshot) == "table", "snapshot must be a table")
    return State.new({
        tick = snapshot.tick or 0,
        phase = snapshot.phase or "player",
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
        unit.x = nx
        unit.y = ny
    elseif kind == "wait" then
        expect(self.units[command.unit], "unknown unit " .. tostring(command.unit))
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

State.commands = commands

return State
