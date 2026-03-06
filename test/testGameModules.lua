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

local hash = spatial.newSpatialHash(16)
hash:insert("a", 0, 0, 10, 10, {kind = "player"})
hash:insert("b", 20, 20, 10, 10, {kind = "enemy"})
local results = hash:queryRange(0, 0, 15, 15)
assert(#results == 1 and results[1].id == "a", "Spatial hash query should return only overlapping object")

local scheduler = tasks.new()
local calls = 0
scheduler:after(0.1, function() calls = calls + 1 end)
scheduler:update(0.05)
assert(calls == 0, "Task should not fire early")
scheduler:update(0.06)
assert(calls == 1, "Task should fire after delay")
