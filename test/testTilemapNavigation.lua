local tilemap = require("thoth.game.tilemap")
local navigation = require("thoth.game.navigation")

local map = tilemap.new(4, 3, 16, 16)
map:addLayer("ground", {
    {1, 1, 1, 1},
    {1, 0, 1, 1},
    {1, 1, 1, 1},
})

assert(map:getTile("ground", 2, 2) == 0)
map:setTile("ground", 2, 2, 1)
assert(map:getTile("ground", 2, 2) == 1)
map:setTile("ground", 2, 2, 0)
assert(not map:isWalkable("ground", 2, 2))

local wx, wy = map:cellToWorld(3, 2)
assert(wx == 32 and wy == 16)
local cx, cy = map:worldToCell(wx + 4, wy + 8)
assert(cx == 3 and cy == 2)

local path, distance = navigation.findPath(map, "ground", {x = 1, y = 1}, {x = 4, y = 3})
assert(path ~= nil and #path > 0)
assert(distance > 0)

local graph = navigation.toWaypointGraph(map, "ground")
local graphPath, graphDistance = graph:shortestPath("1:1", "4:3")
assert(graphPath ~= nil and graphPath[1] == "1:1" and graphPath[#graphPath] == "4:3")
assert(graphDistance == 5)
