local terrain = require("thoth.game.terrain")

local function signature(source)
    return table.concat(terrain.grid.toStrings(source), "\n")
end

local originalLove = rawget(_G, "love")
_G.love = nil

local generated = terrain.generate("archipelago", 18, 12, {seed = 99})
assert(#generated == 12 and #generated[1] == 18, "Terrain generation should not depend on Love2D globals")

local strings = terrain.grid.toStrings(generated)
local restored = terrain.grid.fromStrings(strings)
assert(signature(generated) == signature(restored), "Grid string conversion should round-trip")

local components = terrain.grid.countConnectedRegions({
    {"G", "G", "W"},
    {"W", "G", "W"},
    {"G", "W", "G"},
}, "G")
assert(components == 3, "Connected-region counting should use four-direction adjacency by default")

local tilemap = terrain.grid.toTilemap(generated, "terrain", 2, 3)
assert(tilemap.width == 18 and tilemap.height == 12, "Grid-to-tilemap conversion should preserve dimensions")
assert(signature(terrain.grid.fromTilemap(tilemap, "terrain")) == signature(generated), "Tilemap conversion should round-trip")

local jsonPath = "test_tmp_terrain.json"
local csvPath = "test_tmp_terrain.csv"
local genomePath = "test_tmp_genome.json"

local ok, err = terrain.export.saveJSON(jsonPath, generated, {id = "archipelago", seed = 99}, true)
assert(ok, err)
ok, err = terrain.export.saveCSV(csvPath, generated)
assert(ok, err)

local loadedJson = assert(terrain.export.loadJSON(jsonPath))
local loadedCsv = assert(terrain.export.loadCSV(csvPath))
assert(signature(loadedJson.grid) == signature(generated), "JSON export should be readable without Love2D filesystem helpers")
assert(signature(loadedCsv.grid) == signature(generated), "CSV export should be readable without Love2D filesystem helpers")

local simulationMap = terrain.generate("coast", 18, 12, {seed = 21})
local simulation = assert(terrain.simulation.init("coast", simulationMap, {seed = 3, tick_rate = 0.1}))
local simulationSnapshot = terrain.simulation.snapshot(simulation)
terrain.simulation.step(simulation, 1)
assert(simulation.tick == 1, "Simulation stepping should advance the tick")
local restoredSimulation = terrain.simulation.restore(simulationSnapshot)
assert(restoredSimulation.tick == 0, "Simulation restore should restore tick state")
assert(signature(restoredSimulation.grid) == signature(simulationSnapshot.grid), "Simulation restore should restore the grid")

local evolution = terrain.evolution.init("forest", 18, 12, {
    seed = 5,
    pop_size = 4,
    max_generations = 1,
})
terrain.evolution.step(evolution)
assert(evolution.generation == 1 and evolution.done, "Evolution sessions should finish after the configured generation count")
assert(type(evolution.best_genome) == "table" and #evolution.best_genome > 0, "Evolution should track the best genome")
assert(type(evolution.best_params) == "table" and evolution.best_params.tree_density ~= nil, "Evolution should materialize best parameters")

ok, err = terrain.evolution.saveGenome(genomePath, "forest", evolution.best_genome)
assert(ok, err)
local savedGenome = assert(terrain.evolution.loadGenome(genomePath))
assert(savedGenome.id == "forest", "Genome persistence should preserve the terrain id")
assert(#savedGenome.genome == #evolution.best_genome, "Genome persistence should preserve genome values")

os.remove(jsonPath)
os.remove(csvPath)
os.remove(genomePath)
_G.love = originalLove
