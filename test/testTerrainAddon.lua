local runtimeModule = require("thoth.game.runtime")
local contract = require("thoth.adapters.contract")
local terrainAddon = require("thoth.addons.terrain")
local terrain = require("thoth.game.terrain")

local function signature(source)
    return table.concat(terrain.grid.toStrings(source), "\n")
end

local runtime = runtimeModule.new(contract.nullAdapter(), {
    fixedDelta = 0.1,
    maxFrameDelta = 1,
})

local handle = runtime:use("terrain", terrainAddon, {
    id = "coast",
    width = 18,
    height = 12,
    generate = {seed = 7},
})

assert(handle == runtime:getExtension("terrain"), "Runtime should expose the terrain extension handle")
assert(handle.id == "coast" and handle.metadata.seed == 7, "Terrain addon should preserve metadata from generation")

local baseline = signature(handle:getGrid())
local started = assert(handle:startSimulation({seed = 2, tick_rate = 0.1}))
assert(started.tick == 0, "Simulation should start from tick 0")

local snapshot = runtime:snapshot()
runtime:update(0.1)
assert(handle.simulation.tick == 1, "Runtime fixed updates should advance terrain simulations")
assert(signature(handle:getGrid()) ~= baseline, "Coast simulation should mutate the grid on update")

runtime:restore(snapshot)
assert(handle.simulation.tick == 0, "Runtime restore should restore terrain simulation tick state")
assert(signature(handle:getGrid()) == baseline, "Runtime restore should restore the terrain grid")

local evolution = assert(handle:startEvolution({
    seed = 9,
    pop_size = 4,
    max_generations = 1,
}))
assert(evolution.generation == 0, "Evolution should start before any generations have run")

handle:stepEvolution()
assert(handle.evolution.done and handle.evolution.best_genome ~= nil, "Terrain addon should run evolution sessions")

local applied, metadata = assert(handle:applyBestGenome(15))
assert(#applied == 12 and #applied[1] == 18, "Applying a best genome should regenerate a grid")
assert(metadata.seed == 15, "Applying a best genome should respect explicit seeds")
