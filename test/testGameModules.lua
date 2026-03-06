local pathfinding = require("thoth.game.pathfinding")
local spatial = require("thoth.game.spatial")
local tasks = require("thoth.game.tasks")

local grid = {
    {1, 1, 1, 1},
    {0, 0, 1, 0},
    {1, 1, 1, 1},
}

local path, distance = pathfinding.findPathGrid(grid, {x = 1, y = 1}, {x = 4, y = 3})
assert(path ~= nil, "Grid path should exist")
assert(distance > 0, "Grid path distance should be > 0")

local diagonalGrid = {
    {1, 1, 1},
    {1, 1, 1},
    {1, 1, 1},
}
local diagonalPath = pathfinding.findPathGrid(diagonalGrid, {x = 1, y = 1}, {x = 3, y = 3}, {diagonal = true})
assert(diagonalPath ~= nil, "Diagonal path should exist when diagonal option is enabled")

local weightedGrid = {
    {1, 1, 1},
    {1, 9, 1},
    {1, 1, 1},
}
local weightedPath, weightedDistance = pathfinding.findPathGrid(weightedGrid, {x = 1, y = 2}, {x = 3, y = 2}, {
    cost = function(_from, _to, cellValue)
        return cellValue
    end
})
assert(weightedPath ~= nil, "Weighted path should exist")
assert(weightedDistance < 10, "Weighted path should avoid expensive center tile")

local hash = spatial.newSpatialHash(16)
hash:insert("a", 0, 0, 10, 10, {kind = "player"})
hash:insert("b", 20, 20, 10, 10, {kind = "enemy"})
local results = hash:queryRange(0, 0, 15, 15)
assert(#results == 1 and results[1].id == "a", "Spatial hash query should return only overlapping object")

local nearest = hash:queryNearest(1, 1, 64, 1)
assert(#nearest == 1 and nearest[1].id == "a", "Nearest query should return closest object first")

local scheduler = tasks.new()
local calls = 0
scheduler:after(0.1, function() calls = calls + 1 end)
scheduler:update(0.05)
assert(calls == 0, "Task should not fire early")
scheduler:update(0.06)
assert(calls == 1, "Task should fire after delay")
