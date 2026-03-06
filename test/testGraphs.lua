local graphs = require("thoth.core.graphs")

local g = graphs.new(false)
g:addEdge("A", "B", 5)
g:addEdge("B", "C", 2)
g:addEdge("A", "C", 20)

assert(g:hasEdge("A", "B"))
assert(g:getWeight("A", "B") == 5)

local visited = g:bfs("A")
assert(visited["A"] == 0)
assert(visited["C"] ~= nil)

local path, distance = g:shortestPath("A", "C")
assert(distance == 7)
assert(path[1] == "A" and path[#path] == "C")
