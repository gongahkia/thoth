-- Test file for graphs module

local graphs = require("src.graphs")

print("=== Testing Graphs Module ===\n")

-- Test Graph Creation
print("Testing Graph creation...")
local g = graphs.new(false) -- undirected

g:addVertex("A")
g:addVertex("B")
g:addVertex("C")

local vertices = g:getVertices()
assert(#vertices == 3, "Should have 3 vertices")
print("✓ Graph creation works\n")

-- Test Add Edge
print("Testing addEdge...")
g:addEdge("A", "B", 5)
g:addEdge("B", "C", 3)
g:addEdge("A", "C", 10)

assert(g:hasEdge("A", "B"), "Should have edge A-B")
assert(g:hasEdge("B", "A"), "Undirected: should have reverse edge")
assert(g:getWeight("A", "B") == 5, "Should have correct weight")
print("✓ addEdge works\n")

-- Test Neighbors
print("Testing getNeighbors...")
local neighbors = g:getNeighbors("A")
assert(#neighbors == 2, "A should have 2 neighbors")
print("✓ getNeighbors works\n")

-- Test BFS
print("Testing BFS...")
local visited = g:bfs("A")
assert(visited["A"] == 0, "Start node distance 0")
assert(visited["B"] ~= nil, "Should visit B")
assert(visited["C"] ~= nil, "Should visit C")
print("✓ BFS works\n")

-- Test DFS
print("Testing DFS...")
local dfsVisited = g:dfs("A")
assert(dfsVisited["A"] == true, "Should visit A")
assert(dfsVisited["B"] == true, "Should visit B")
assert(dfsVisited["C"] == true, "Should visit C")
print("✓ DFS works\n")

-- Test Dijkstra
print("Testing Dijkstra...")
local distances, previous = g:dijkstra("A")
assert(distances["A"] == 0, "Start distance is 0")
assert(distances["B"] == 5, "Shortest path to B is 5")
assert(distances["C"] == 8, "Shortest path to C is 8 (via B)")
print("✓ Dijkstra works\n")

-- Test Shortest Path
print("Testing shortestPath...")
local path, distance = g:shortestPath("A", "C")
assert(distance == 8, "Shortest distance A to C is 8")
assert(#path == 3, "Path should have 3 nodes")
assert(path[1] == "A" and path[3] == "C", "Path should start at A and end at C")
print("Path: " .. table.concat(path, " -> "))
print("✓ shortestPath works\n")

-- Test Directed Graph
print("Testing directed graph...")
local dg = graphs.new(true) -- directed

dg:addEdge("X", "Y", 1)
dg:addEdge("Y", "Z", 1)

assert(dg:hasEdge("X", "Y"), "Should have edge X->Y")
assert(not dg:hasEdge("Y", "X"), "Directed: should not have reverse edge")
print("✓ Directed graph works\n")

-- Test isConnected
print("Testing isConnected...")
local g2 = graphs.new(false)
g2:addEdge("1", "2")
g2:addEdge("2", "3")
assert(g2:isConnected(), "Connected graph should return true")

g2:addVertex("4") -- isolated vertex
assert(not g2:isConnected(), "Graph with isolated vertex should return false")
print("✓ isConnected works\n")

-- Test hasCycle
print("Testing hasCycle...")
local g3 = graphs.new(false)
g3:addEdge("A", "B")
g3:addEdge("B", "C")
assert(not g3:hasCycle(), "Tree should have no cycle")

g3:addEdge("C", "A") -- create cycle
assert(g3:hasCycle(), "Should detect cycle")
print("✓ hasCycle works\n")

-- Test Topological Sort
print("Testing topologicalSort...")
local dag = graphs.new(true) -- directed acyclic graph
dag:addEdge("shirt", "tie")
dag:addEdge("tie", "jacket")
dag:addEdge("shirt", "jacket")
dag:addEdge("pants", "shoes")

local sorted = dag:topologicalSort()
assert(sorted ~= nil, "Should return topological order")
print("Topological order: " .. table.concat(sorted, " -> "))
print("✓ topologicalSort works\n")

-- Test Remove Edge
print("Testing removeEdge...")
local g4 = graphs.new(false)
g4:addEdge("A", "B")
assert(g4:hasEdge("A", "B"), "Should have edge")

g4:removeEdge("A", "B")
assert(not g4:hasEdge("A", "B"), "Should not have edge after removal")
print("✓ removeEdge works\n")

-- Test Degree
print("Testing getDegree...")
local g5 = graphs.new(false)
g5:addEdge("A", "B")
g5:addEdge("A", "C")
g5:addEdge("A", "D")

assert(g5:getDegree("A") == 3, "A should have degree 3")
print("✓ getDegree works\n")

print("=== All Graph Tests Passed ===")
