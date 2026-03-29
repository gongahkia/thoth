local terrain = require("thoth.game.terrain")

local function gridSignature(source)
    return table.concat(terrain.grid.toStrings(source), "\n")
end

local validSymbols = {}
for _, symbol in ipairs(terrain.palette.symbols()) do
    validSymbols[symbol] = true
end

local ids = terrain.list()
for _, id in ipairs(ids) do
    local first, metadata = terrain.generate(id, 20, 15, {seed = 42})
    local second = terrain.generate(id, 20, 15, {seed = 42})
    local varied = terrain.generate(id, 20, 15, {seed = 43})

    assert(#first == 15 and #first[1] == 20, id .. " should honor requested dimensions")
    assert(metadata.id == id and metadata.seed == 42, id .. " metadata should preserve generator and seed")

    for y = 1, #first do
        for x = 1, #first[y] do
            assert(validSymbols[first[y][x]], id .. " should only emit symbols from the terrain palette")
        end
    end

    assert(gridSignature(first) == gridSignature(second), id .. " should be deterministic for a fixed seed")
    assert(gridSignature(first) ~= gridSignature(varied), id .. " should vary when the seed changes")
end

local mountain = terrain.generate("mountain", 30, 20, {seed = 10})
local mountainCounts = terrain.grid.countTypes(mountain)
assert((mountainCounts.A or 0) > 0, "Mountain terrain should include snowcaps")
assert((mountainCounts.M or 0) > 0, "Mountain terrain should include mid-elevation peaks")

local forest = terrain.generate("forest", 30, 20, {seed = 11})
local forestCounts = terrain.grid.countTypes(forest)
assert((forestCounts.F or 0) > 0 or (forestCounts.E or 0) > 0, "Forest terrain should include trees")
assert((forestCounts.W or 0) > 0, "Forest terrain should include river water")

local archipelago = terrain.generate("archipelago", 40, 30, {seed = 12})
local archipelagoCounts = terrain.grid.countTypes(archipelago)
assert((archipelagoCounts.B or 0) > 0, "Archipelago should include deep water")
assert((archipelagoCounts.O or 0) + (archipelagoCounts.S or 0) + (archipelagoCounts.F or 0)
    + (archipelagoCounts.R or 0) + (archipelagoCounts.M or 0) > 0, "Archipelago should include land")

local urban = terrain.generate("urban", 30, 20, {seed = 13})
local urbanCounts = terrain.grid.countTypes(urban)
assert((urbanCounts.J or 0) > 0, "Urban terrain should include roads")
assert((urbanCounts.U or 0) + (urbanCounts.C or 0) + (urbanCounts.H or 0) > 0, "Urban terrain should include developed blocks")
