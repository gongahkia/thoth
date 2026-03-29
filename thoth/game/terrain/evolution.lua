local serialize = require("thoth.core.serialize")
local randomModule = require("thoth.game.random")
local registry = require("thoth.game.terrain.registry")
local grid = require("thoth.game.terrain.grid")

local evolution = {}

local DEFAULTS = {
    pop_size = 16,
    max_generations = 20,
    mutation_rate = 0.15,
    tournament_size = 3,
    elitism = 2,
}

local function evolvableParams(id)
    local descriptor = registry.describe(id)
    local out = {}
    for _, definition in ipairs(descriptor.params or {}) do
        if definition.evolve ~= false and (definition.type == "int" or definition.type == "float") then
            out[#out + 1] = definition
        end
    end
    return out
end

local function cloneGenome(genome)
    return serialize.deepCopy(genome)
end

local function countBoxes(source, boxSize)
    local width, height = grid.dimensions(source)
    local occupied = 0
    for by = 1, height, boxSize do
        for bx = 1, width, boxSize do
            local first = source[by][bx]
            local hasEdge = false
            for dy = 0, boxSize - 1 do
                for dx = 0, boxSize - 1 do
                    local x = bx + dx
                    local y = by + dy
                    if x <= width and y <= height and source[y][x] ~= first then
                        hasEdge = true
                        break
                    end
                end
                if hasEdge then
                    break
                end
            end
            if hasEdge then
                occupied = occupied + 1
            end
        end
    end
    return occupied
end

local function tournamentSelect(population, fitnesses, size, rng)
    local bestIndex = rng:random(1, #population)
    local bestFitness = fitnesses[bestIndex]
    for _ = 2, size do
        local index = rng:random(1, #population)
        if fitnesses[index] > bestFitness then
            bestIndex = index
            bestFitness = fitnesses[index]
        end
    end
    return population[bestIndex]
end

function evolution.paramDefinitions(id)
    return evolvableParams(id)
end

function evolution.createGenome(id, rng)
    local definitions = evolvableParams(id)
    if #definitions == 0 then
        return {}
    end

    rng = rng or randomModule.new(1)
    local genome = {}
    for index, definition in ipairs(definitions) do
        if definition.type == "int" then
            genome[index] = rng:random(definition.min, definition.max)
        else
            genome[index] = rng:random(definition.min, definition.max)
        end
    end
    return genome
end

function evolution.genomeToParams(id, genome)
    local defaults = registry.defaultParams(id)
    local definitions = evolvableParams(id)
    genome = genome or {}

    for index, definition in ipairs(definitions) do
        local value = tonumber(genome[index]) or definition.default
        if definition.type == "int" then
            value = math.floor(value + 0.5)
        end
        if definition.min ~= nil and value < definition.min then
            value = definition.min
        end
        if definition.max ~= nil and value > definition.max then
            value = definition.max
        end
        defaults[definition.name] = value
    end

    return defaults
end

function evolution.evaluateFitness(source)
    local width, height = grid.dimensions(source)
    local counts = grid.countTypes(source)
    local totalCells = width * height

    local entropy = 0
    local kinds = 0
    for _, count in pairs(counts) do
        kinds = kinds + 1
        local p = count / totalCells
        if p > 0 then
            entropy = entropy - (p * math.log(p))
        end
    end
    local diversity = kinds <= 1 and 0 or entropy / math.log(kinds)

    local threshold = totalCells * 0.05
    local connectivityScores = {}
    for symbol, count in pairs(counts) do
        if count >= threshold then
            local regions = grid.countConnectedRegions(source, symbol, {diagonal = true})
            connectivityScores[#connectivityScores + 1] = 1 / (1 + math.max(0, regions - 1))
        end
    end

    local connectivity = 0.5
    if #connectivityScores > 0 then
        connectivity = 0
        for _, score in ipairs(connectivityScores) do
            connectivity = connectivity + score
        end
        connectivity = connectivity / #connectivityScores
    end

    local edgeCount = 0
    for y = 1, height do
        for x = 1, width do
            if grid.countNeighbors(source, x, y, function(value)
                return value ~= source[y][x]
            end) > 0 then
                edgeCount = edgeCount + 1
            end
        end
    end
    local edgeRatio = edgeCount / totalCells
    local edgeComplexity = 1 - math.abs(edgeRatio - 0.5) * 2

    local countSmall = countBoxes(source, 4)
    local countLarge = countBoxes(source, 8)
    local fractal = 0.5
    if countSmall > 0 and countLarge > 0 then
        local dimension = math.log(countSmall / countLarge) / math.log(2)
        fractal = math.max(0, 1 - math.abs(dimension - 1.5) / 1.5)
    end

    return (0.3 * diversity) + (0.25 * connectivity) + (0.25 * edgeComplexity) + (0.2 * fractal)
end

function evolution.crossover(a, b, rng)
    rng = rng or randomModule.new(1)
    local child = {}
    if #a == 0 then
        return child
    end
    local point = rng:random(1, #a)
    for index = 1, #a do
        child[index] = index <= point and a[index] or b[index]
    end
    return child
end

function evolution.mutate(id, genome, rate, rng)
    local definitions = evolvableParams(id)
    rng = rng or randomModule.new(1)
    rate = tonumber(rate) or DEFAULTS.mutation_rate
    local mutated = {}

    for index, value in ipairs(genome) do
        local definition = definitions[index]
        if definition and rng:random() < rate then
            local span = definition.max - definition.min
            value = value + (rng:random(-span * 0.2, span * 0.2))
            if definition.type == "int" then
                value = math.floor(value + 0.5)
            end
            if definition.min ~= nil and value < definition.min then
                value = definition.min
            end
            if definition.max ~= nil and value > definition.max then
                value = definition.max
            end
        end
        mutated[index] = value
    end

    return mutated
end

function evolution.runGeneration(state)
    local population = state.population
    local fitnesses = {}
    local bestFitness = -math.huge
    local bestGenome = nil
    local bestTerrain = nil

    if not population or #population == 0 then
        population = {}
        for index = 1, state.pop_size do
            population[index] = evolution.createGenome(state.id, state.random)
        end
    end

    for index, genome in ipairs(population) do
        local seed = state.random:random(1, 2147483646)
        local params = evolution.genomeToParams(state.id, genome)
        local terrain = registry.generate(state.id, state.width, state.height, {
            seed = seed,
            params = params,
        })
        local fitness = evolution.evaluateFitness(terrain)
        fitnesses[index] = fitness
        if fitness > bestFitness then
            bestFitness = fitness
            bestGenome = cloneGenome(genome)
            bestTerrain = grid.clone(terrain)
        end
    end

    local indices = {}
    for index = 1, #population do
        indices[index] = index
    end
    table.sort(indices, function(a, b)
        return fitnesses[a] > fitnesses[b]
    end)

    local sortedPopulation = {}
    local sortedFitness = {}
    for rank, index in ipairs(indices) do
        sortedPopulation[rank] = population[index]
        sortedFitness[rank] = fitnesses[index]
    end

    local nextPopulation = {}
    for index = 1, math.min(state.elitism, #sortedPopulation) do
        nextPopulation[index] = cloneGenome(sortedPopulation[index])
    end

    for index = (#nextPopulation + 1), state.pop_size do
        local a = tournamentSelect(sortedPopulation, sortedFitness, state.tournament_size, state.random)
        local b = tournamentSelect(sortedPopulation, sortedFitness, state.tournament_size, state.random)
        local child = evolution.crossover(a, b, state.random)
        child = evolution.mutate(state.id, child, state.mutation_rate, state.random)
        nextPopulation[index] = child
    end

    state.population = nextPopulation
    state.best_genome = bestGenome
    state.best_params = evolution.genomeToParams(state.id, bestGenome)
    state.best_fitness = bestFitness
    state.best_terrain = bestTerrain

    return state
end

function evolution.init(id, width, height, options)
    registry.describe(id)
    options = options or {}
    local state = {
        id = id,
        width = width,
        height = height,
        generation = 0,
        max_generations = tonumber(options.max_generations) or DEFAULTS.max_generations,
        pop_size = tonumber(options.pop_size) or DEFAULTS.pop_size,
        mutation_rate = tonumber(options.mutation_rate) or DEFAULTS.mutation_rate,
        tournament_size = tonumber(options.tournament_size) or DEFAULTS.tournament_size,
        elitism = tonumber(options.elitism) or DEFAULTS.elitism,
        population = serialize.deepCopy(options.population),
        best_genome = nil,
        best_params = nil,
        best_fitness = 0,
        best_terrain = nil,
        done = false,
        random = randomModule.new(options.seed or 1),
    }
    return state
end

function evolution.step(state)
    if state.done then
        return state
    end

    evolution.runGeneration(state)
    state.generation = state.generation + 1
    if state.generation >= state.max_generations then
        state.done = true
    end
    return state
end

function evolution.snapshot(state)
    return {
        id = state.id,
        width = state.width,
        height = state.height,
        generation = state.generation,
        max_generations = state.max_generations,
        pop_size = state.pop_size,
        mutation_rate = state.mutation_rate,
        tournament_size = state.tournament_size,
        elitism = state.elitism,
        population = serialize.deepCopy(state.population),
        best_genome = cloneGenome(state.best_genome),
        best_params = serialize.deepCopy(state.best_params),
        best_fitness = state.best_fitness,
        best_terrain = state.best_terrain and grid.clone(state.best_terrain) or nil,
        done = state.done,
        random_state = state.random:getState(),
    }
end

function evolution.restore(snapshot)
    local state = evolution.init(snapshot.id, snapshot.width, snapshot.height, {
        seed = snapshot.random_state and snapshot.random_state.initialSeed or 1,
        max_generations = snapshot.max_generations,
        pop_size = snapshot.pop_size,
        mutation_rate = snapshot.mutation_rate,
        tournament_size = snapshot.tournament_size,
        elitism = snapshot.elitism,
        population = snapshot.population,
    })
    state.generation = tonumber(snapshot.generation) or 0
    state.best_genome = cloneGenome(snapshot.best_genome)
    state.best_params = serialize.deepCopy(snapshot.best_params)
    state.best_fitness = tonumber(snapshot.best_fitness) or 0
    state.best_terrain = snapshot.best_terrain and grid.clone(snapshot.best_terrain) or nil
    state.done = snapshot.done == true
    if snapshot.random_state then
        state.random:setState(snapshot.random_state)
    end
    return state
end

function evolution.saveGenome(filename, id, genome)
    local file, err = io.open(filename, "w")
    if not file then
        return nil, err
    end
    local payload = serialize.toJSON({
        id = id,
        genome = genome,
    }, 2)
    file:write(payload)
    file:close()
    return true
end

function evolution.loadGenome(filename)
    local file, err = io.open(filename, "r")
    if not file then
        return nil, err
    end
    local content = file:read("*a")
    file:close()
    local decoded, decodeErr = serialize.fromJSON(content)
    if not decoded then
        return nil, decodeErr
    end
    return decoded
end

evolution.DEFAULTS = DEFAULTS

return evolution
