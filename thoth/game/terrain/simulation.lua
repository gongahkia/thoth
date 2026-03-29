local serialize = require("thoth.core.serialize")
local randomModule = require("thoth.game.random")
local grid = require("thoth.game.terrain.grid")

local simulation = {}

local rulesets = {
    forest = {
        {from = "F", to = "Q", condition = "neighbor_count", char = "Q", min = 2},
        {from = "E", to = "Q", condition = "neighbor_count", char = "Q", min = 2},
        {from = "T", to = "Q", condition = "neighbor_count", char = "Q", min = 1},
        {from = "Q", to = "D", condition = "always"},
        {from = "D", to = "G", condition = "age", ticks = 5},
        {from = "G", to = "F", condition = "age", ticks = 8},
        {from = "F", to = "Q", condition = "random", chance = 0.001},
        {from = "E", to = "Q", condition = "random", chance = 0.001},
    },
    tundra = {
        {from = "N", to = "I", condition = "neighbor_count", char = "I", min = 3},
        {from = "N", to = "I", condition = "neighbor_count", char = "Z", min = 3},
        {from = "I", to = "Z", condition = "age", ticks = 4},
        {from = "Z", to = "N", condition = "neighbor_count_lt", char = "Z", max = 2},
        {from = "A", to = "N", condition = "neighbor_count", char = "N", min = 5},
        {from = "N", to = "A", condition = "neighbor_count", char = "A", min = 4},
    },
    volcano = {
        {from = "Q", to = "Q", condition = "neighbor_count", char = "Q", min = 1},
        {from = "G", to = "Q", condition = "neighbor_count", char = "Q", min = 3},
        {from = "S", to = "Q", condition = "neighbor_count", char = "Q", min = 2},
        {from = "Q", to = "R", condition = "age", ticks = 8},
        {from = "R", to = "Q", condition = "neighbor_count", char = "Q", min = 4},
        {from = "V", to = "Q", condition = "neighbor_count", char = "Q", min = 2},
    },
    swamp = {
        {from = "V", to = "W", condition = "neighbor_count", char = "W", min = 4},
        {from = "W", to = "V", condition = "neighbor_count_lt", char = "W", max = 2},
        {from = "B", to = "W", condition = "neighbor_count", char = "W", min = 3},
        {from = "W", to = "B", condition = "age", ticks = 10},
        {from = "F", to = "W", condition = "neighbor_count", char = "W", min = 5},
        {from = "T", to = "W", condition = "neighbor_count", char = "W", min = 6},
    },
    cave = {
        {from = "-", to = "E", condition = "neighbor_count", char = "T", min = 1, random_gate = 0.2},
        {from = "E", to = "-", condition = "neighbor_count", char = "E", min = 5},
        {from = "-", to = "E", condition = "neighbor_count", char = "E", min = 2, random_gate = 0.1},
        {from = "E", to = "-", condition = "age", ticks = 12},
    },
    desert = {
        {from = "S", to = "O", condition = "random", chance = 0.01},
        {from = "O", to = "S", condition = "random", chance = 0.01},
        {from = "O", to = "S", condition = "age", ticks = 6},
        {from = "Y", to = "S", condition = "random", chance = 0.005},
        {from = "S", to = "Y", condition = "random", chance = 0.003},
    },
    coral = {
        {from = "C", to = "S", condition = "neighbor_count_lt", char = "C", max = 2},
        {from = "S", to = "C", condition = "neighbor_count", char = "C", min = 3},
        {from = "F", to = "F", condition = "random", chance = 0.3},
        {from = "W", to = "F", condition = "random", chance = 0.002},
        {from = "F", to = "W", condition = "random", chance = 0.05},
    },
    urban = {
        {from = "-", to = "U", condition = "neighbor_count", char = "U", min = 3},
        {from = "-", to = "U", condition = "neighbor_count", char = "J", min = 3},
        {from = "H", to = "J", condition = "neighbor_count", char = "U", min = 5},
        {from = "F", to = "J", condition = "neighbor_count", char = "U", min = 5},
        {from = "U", to = "X", condition = "random", chance = 0.002},
    },
    farm = {
        {from = "C", to = "H", condition = "age", ticks = 6},
        {from = "H", to = "Y", condition = "age", ticks = 6},
        {from = "Y", to = "C", condition = "age", ticks = 3},
        {from = "C", to = "Y", condition = "neighbor_count_lt", char = "W", max = 0},
        {from = "C", to = "D", condition = "random", chance = 0.005},
        {from = "W", to = "W", condition = "always"},
    },
    apocalypse = {
        {from = "X", to = "P", condition = "neighbor_count", char = "P", min = 1, random_gate = 0.05},
        {from = "Q", to = "X", condition = "age", ticks = 10},
        {from = "J", to = "X", condition = "neighbor_count", char = "P", min = 2},
        {from = "X", to = "F", condition = "random", chance = 0.001},
    },
    archipelago = {
        {from = "S", to = "W", condition = "neighbor_count", char = "W", min = 3},
        {from = "G", to = "S", condition = "neighbor_count", char = "W", min = 2, random_gate = 0.1},
        {from = "F", to = "S", condition = "neighbor_count", char = "W", min = 3, random_gate = 0.05},
        {from = "W", to = "S", condition = "neighbor_count", char = "S", min = 4, random_gate = 0.02},
    },
    badlands = {
        {from = "R", to = "K", condition = "age", ticks = 8},
        {from = "K", to = "O", condition = "age", ticks = 8},
        {from = "O", to = "S", condition = "age", ticks = 8},
        {from = "W", to = "S", condition = "age", ticks = 3},
        {from = "S", to = "W", condition = "tick_mod", mod = 20, random_gate = 0.1},
    },
    canyon = {
        {from = "S", to = "D", condition = "neighbor_count", char = "W", min = 2},
        {from = "D", to = "W", condition = "neighbor_count", char = "W", min = 3},
        {from = "W", to = "S", condition = "neighbor_count_lt", char = "W", max = 1},
        {from = "W", to = "W", condition = "tick_range", start = 0, stop = 15, mod = 30},
    },
    coast = {
        {from = "O", to = "W", condition = "tick_range", start = 0, stop = 10, mod = 20},
        {from = "W", to = "O", condition = "tick_range", start = 10, stop = 20, mod = 20},
        {from = "S", to = "W", condition = "neighbor_count", char = "W", min = 5, random_gate = 0.1},
        {from = "G", to = "S", condition = "neighbor_count", char = "W", min = 4, random_gate = 0.05},
    },
    glacier = {
        {from = "N", to = "Z", condition = "neighbor_count", char = "Z", min = 3},
        {from = "H", to = "Z", condition = "neighbor_count", char = "Z", min = 3},
        {from = "D", to = "Z", condition = "neighbor_count", char = "Z", min = 3},
        {from = "Z", to = "K", condition = "neighbor_count_lt", char = "Z", max = 2},
        {from = "K", to = "N", condition = "age", ticks = 10},
    },
    island = {
        {from = "R", to = "-", condition = "neighbor_count_lt", char = "R", max = 2},
        {from = "G", to = "-", condition = "neighbor_count_lt", char = "R", max = 1},
        {from = "-", to = "X", condition = "neighbor_count", char = "R", min = 1, random_gate = 0.02},
        {from = "M", to = "M", condition = "always"},
    },
    mega = {
        {from = "P", to = "Q", condition = "tick_even"},
        {from = "Q", to = "P", condition = "tick_odd"},
        {from = "-", to = "C", condition = "neighbor_count", char = "C", min = 2, random_gate = 0.1},
        {from = "C", to = "-", condition = "neighbor_count_lt", char = "C", max = 1},
    },
    mountain = {
        {from = "A", to = "M", condition = "neighbor_count", char = "M", min = 2, random_gate = 0.15},
        {from = "A", to = "M", condition = "neighbor_count", char = "R", min = 2, random_gate = 0.1},
        {from = "M", to = "A", condition = "neighbor_count", char = "A", min = 3},
        {from = "R", to = "X", condition = "random", chance = 0.01},
    },
    river = {
        {from = "S", to = "W", condition = "tick_range", start = 0, stop = 5, mod = 15},
        {from = "D", to = "W", condition = "tick_range", start = 0, stop = 5, mod = 15},
        {from = "W", to = "S", condition = "tick_range", start = 5, stop = 15, mod = 15},
        {from = "W", to = "S", condition = "neighbor_count", char = "R", min = 2, random_gate = 0.1},
    },
    temple = {
        {from = "S", to = "F", condition = "random", chance = 0.03},
        {from = "J", to = "X", condition = "neighbor_count", char = "F", min = 4},
        {from = "C", to = "F", condition = "neighbor_count", char = "F", min = 3, random_gate = 0.05},
        {from = "A", to = "F", condition = "random", chance = 0.01},
    },
}

local function cloneRuleTable(rules)
    return serialize.deepCopy(rules)
end

local function initializeAgeMap(source)
    local width, height = grid.dimensions(source)
    local out = {}
    for y = 1, height do
        out[y] = {}
        for x = 1, width do
            out[y][x] = 0
        end
    end
    return out
end

local function evaluateCondition(rule, state, x, y, char)
    if rule.from ~= char then
        return false
    end

    if rule.random_gate and state.random:random() > rule.random_gate then
        return false
    end

    if rule.condition == "always" then
        return true
    elseif rule.condition == "neighbor_count" then
        return grid.countNeighbors(state.grid, x, y, rule.char) >= rule.min
    elseif rule.condition == "neighbor_count_lt" then
        return grid.countNeighbors(state.grid, x, y, rule.char) <= rule.max
    elseif rule.condition == "age" then
        return state.age_map[y][x] >= rule.ticks
    elseif rule.condition == "random" then
        return state.random:random() < rule.chance
    elseif rule.condition == "tick_mod" then
        return state.tick % rule.mod == 0
    elseif rule.condition == "tick_range" then
        local phase = state.tick % rule.mod
        return phase >= rule.start and phase < rule.stop
    elseif rule.condition == "tick_even" then
        return state.tick % 2 == 0
    elseif rule.condition == "tick_odd" then
        return state.tick % 2 == 1
    end

    return false
end

function simulation.listRulesets()
    local names = {}
    for name in pairs(rulesets) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function simulation.getRuleset(id)
    if not rulesets[id] then
        return nil
    end
    return cloneRuleTable(rulesets[id])
end

function simulation.init(id, source, options)
    assert(type(id) == "string" and id ~= "", "id must be a non-empty string")
    assert(type(source) == "table", "grid must be a table")
    local ruleset = rulesets[id]
    if not ruleset then
        return nil
    end

    options = options or {}
    local width, height = grid.dimensions(source)
    local state = {
        id = id,
        width = width,
        height = height,
        grid = grid.clone(source),
        age_map = initializeAgeMap(source),
        tick = 0,
        tick_rate = tonumber(options.tick_rate) or 0.3,
        accumulator = tonumber(options.accumulator) or 0,
        paused = options.paused == true,
        ruleset = cloneRuleTable(ruleset),
        random = randomModule.new(options.seed or 1),
    }

    return state
end

function simulation.step(state, steps)
    assert(type(state) == "table", "state must be a table")
    steps = math.max(1, tonumber(steps) or 1)

    for _ = 1, steps do
        local nextGrid = {}
        local nextAgeMap = {}

        for y = 1, state.height do
            nextGrid[y] = {}
            nextAgeMap[y] = {}
            for x = 1, state.width do
                local current = state.grid[y][x]
                local changed = false
                for _, rule in ipairs(state.ruleset) do
                    if evaluateCondition(rule, state, x, y, current) then
                        nextGrid[y][x] = rule.to
                        nextAgeMap[y][x] = rule.to == current and (state.age_map[y][x] + 1) or 0
                        changed = true
                        break
                    end
                end
                if not changed then
                    nextGrid[y][x] = current
                    nextAgeMap[y][x] = state.age_map[y][x] + 1
                end
            end
        end

        state.grid = nextGrid
        state.age_map = nextAgeMap
        state.tick = state.tick + 1
    end

    return state
end

function simulation.update(state, dt)
    assert(type(dt) == "number" and dt >= 0, "dt must be a number >= 0")
    if state.paused then
        return state
    end

    state.accumulator = state.accumulator + dt
    while state.accumulator >= state.tick_rate do
        state.accumulator = state.accumulator - state.tick_rate
        simulation.step(state, 1)
    end
    return state
end

function simulation.snapshot(state)
    return {
        id = state.id,
        width = state.width,
        height = state.height,
        grid = grid.clone(state.grid),
        age_map = serialize.deepCopy(state.age_map),
        tick = state.tick,
        tick_rate = state.tick_rate,
        accumulator = state.accumulator,
        paused = state.paused,
        random_state = state.random:getState(),
    }
end

function simulation.restore(snapshot)
    local state = simulation.init(snapshot.id, snapshot.grid, {
        seed = snapshot.random_state and snapshot.random_state.initialSeed or 1,
        tick_rate = snapshot.tick_rate,
        accumulator = snapshot.accumulator,
        paused = snapshot.paused,
    })
    if not state then
        return nil
    end
    state.age_map = serialize.deepCopy(snapshot.age_map or initializeAgeMap(snapshot.grid))
    state.tick = tonumber(snapshot.tick) or 0
    if snapshot.random_state then
        state.random:setState(snapshot.random_state)
    end
    return state
end

return simulation
