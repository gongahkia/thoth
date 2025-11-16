-- =============================================
-- Graph Data Structure and Algorithms
-- Directed and undirected graphs with common algorithms
-- =============================================

local graphs = {}

-- =============================================
-- Graph Implementation
-- =============================================

---@class Graph
---@field directed boolean
---@field adjacencyList table
---@field weights table
local Graph = {}
Graph.__index = Graph

---Create a new graph
---@param directed boolean Whether the graph is directed (default: false)
---@return Graph
function Graph.new(directed)
    local self = setmetatable({}, Graph)
    self.directed = directed or false
    self.adjacencyList = {}
    self.weights = {}
    return self
end

---Add a vertex to the graph
---@param vertex any Vertex identifier
function Graph:addVertex(vertex)
    if not self.adjacencyList[vertex] then
        self.adjacencyList[vertex] = {}
        self.weights[vertex] = {}
    end
end

---Add an edge between two vertices
---@param from any Source vertex
---@param to any Destination vertex
---@param weight number|nil Optional edge weight (default: 1)
function Graph:addEdge(from, to, weight)
    weight = weight or 1

    -- Ensure vertices exist
    self:addVertex(from)
    self:addVertex(to)

    -- Add edge
    table.insert(self.adjacencyList[from], to)
    self.weights[from][to] = weight

    -- If undirected, add reverse edge
    if not self.directed then
        table.insert(self.adjacencyList[to], from)
        self.weights[to][from] = weight
    end
end

---Remove an edge between two vertices
---@param from any Source vertex
---@param to any Destination vertex
function Graph:removeEdge(from, to)
    if not self.adjacencyList[from] then
        return
    end

    -- Remove forward edge
    for i, vertex in ipairs(self.adjacencyList[from]) do
        if vertex == to then
            table.remove(self.adjacencyList[from], i)
            self.weights[from][to] = nil
            break
        end
    end

    -- If undirected, remove reverse edge
    if not self.directed and self.adjacencyList[to] then
        for i, vertex in ipairs(self.adjacencyList[to]) do
            if vertex == from then
                table.remove(self.adjacencyList[to], i)
                self.weights[to][from] = nil
                break
            end
        end
    end
end

---Get all neighbors of a vertex
---@param vertex any Vertex identifier
---@return table neighbors Array of neighbor vertices
function Graph:getNeighbors(vertex)
    return self.adjacencyList[vertex] or {}
end

---Get the weight of an edge
---@param from any Source vertex
---@param to any Destination vertex
---@return number|nil weight Edge weight or nil if edge doesn't exist
function Graph:getWeight(from, to)
    if self.weights[from] then
        return self.weights[from][to]
    end
    return nil
end

---Check if an edge exists
---@param from any Source vertex
---@param to any Destination vertex
---@return boolean exists
function Graph:hasEdge(from, to)
    if not self.adjacencyList[from] then
        return false
    end

    for _, vertex in ipairs(self.adjacencyList[from]) do
        if vertex == to then
            return true
        end
    end

    return false
end

---Get all vertices in the graph
---@return table vertices Array of all vertices
function Graph:getVertices()
    local vertices = {}
    for vertex in pairs(self.adjacencyList) do
        table.insert(vertices, vertex)
    end
    return vertices
end

---Get the degree of a vertex (number of edges)
---@param vertex any Vertex identifier
---@return number degree
function Graph:getDegree(vertex)
    if not self.adjacencyList[vertex] then
        return 0
    end
    return #self.adjacencyList[vertex]
end

-- =============================================
-- Graph Traversal Algorithms
-- =============================================

---Breadth-First Search (BFS)
---@param start any Starting vertex
---@param callback function|nil Optional callback function(vertex, distance)
---@return table visited Map of {vertex -> distance from start}
function Graph:bfs(start, callback)
    local visited = {}
    local queue = {{vertex = start, distance = 0}}
    local head = 1

    while head <= #queue do
        local current = queue[head]
        head = head + 1

        local vertex = current.vertex
        local distance = current.distance

        if visited[vertex] then
            goto continue
        end

        visited[vertex] = distance

        if callback then
            callback(vertex, distance)
        end

        -- Add neighbors to queue
        for _, neighbor in ipairs(self:getNeighbors(vertex)) do
            if not visited[neighbor] then
                table.insert(queue, {vertex = neighbor, distance = distance + 1})
            end
        end

        ::continue::
    end

    return visited
end

---Depth-First Search (DFS)
---@param start any Starting vertex
---@param callback function|nil Optional callback function(vertex)
---@return table visited Set of visited vertices
function Graph:dfs(start, callback)
    local visited = {}

    local function dfsRecursive(vertex)
        if visited[vertex] then
            return
        end

        visited[vertex] = true

        if callback then
            callback(vertex)
        end

        for _, neighbor in ipairs(self:getNeighbors(vertex)) do
            dfsRecursive(neighbor)
        end
    end

    dfsRecursive(start)
    return visited
end

-- =============================================
-- Shortest Path Algorithms
-- =============================================

---Dijkstra's algorithm for shortest paths
---@param start any Starting vertex
---@param target any|nil Optional target vertex (if nil, finds paths to all vertices)
---@return table distances Map of {vertex -> shortest distance from start}
---@return table previous Map of {vertex -> previous vertex in shortest path}
function Graph:dijkstra(start, target)
    local distances = {}
    local previous = {}
    local unvisited = {}

    -- Initialize distances
    for _, vertex in ipairs(self:getVertices()) do
        distances[vertex] = math.huge
        unvisited[vertex] = true
    end
    distances[start] = 0

    while next(unvisited) do
        -- Find vertex with minimum distance
        local current = nil
        local minDistance = math.huge

        for vertex in pairs(unvisited) do
            if distances[vertex] < minDistance then
                minDistance = distances[vertex]
                current = vertex
            end
        end

        if not current or minDistance == math.huge then
            break
        end

        -- If we reached the target, we can stop
        if target and current == target then
            break
        end

        unvisited[current] = nil

        -- Update distances to neighbors
        for _, neighbor in ipairs(self:getNeighbors(current)) do
            if unvisited[neighbor] then
                local weight = self:getWeight(current, neighbor)
                local alt = distances[current] + weight

                if alt < distances[neighbor] then
                    distances[neighbor] = alt
                    previous[neighbor] = current
                end
            end
        end
    end

    return distances, previous
end

---Reconstruct path from Dijkstra's previous map
---@param previous table Map from dijkstra
---@param start any Starting vertex
---@param target any Target vertex
---@return table|nil path Array of vertices in path, or nil if no path exists
function Graph:reconstructPath(previous, start, target)
    local path = {}
    local current = target

    -- Build path backwards
    while current do
        table.insert(path, 1, current)
        current = previous[current]
    end

    -- Check if path is valid
    if path[1] ~= start then
        return nil
    end

    return path
end

---Find shortest path between two vertices
---@param start any Starting vertex
---@param target any Target vertex
---@return table|nil path Array of vertices in path, or nil if no path exists
---@return number distance Total distance of the path
function Graph:shortestPath(start, target)
    local distances, previous = self:dijkstra(start, target)
    local path = self:reconstructPath(previous, start, target)

    if not path then
        return nil, math.huge
    end

    return path, distances[target]
end

-- =============================================
-- Graph Properties and Analysis
-- =============================================

---Check if the graph is connected
---@return boolean connected
function Graph:isConnected()
    local vertices = self:getVertices()

    if #vertices == 0 then
        return true
    end

    local visited = self:bfs(vertices[1])
    local visitedCount = 0

    for _ in pairs(visited) do
        visitedCount = visitedCount + 1
    end

    return visitedCount == #vertices
end

---Detect if the graph has a cycle
---@return boolean hasCycle
function Graph:hasCycle()
    local visited = {}
    local recursionStack = {}

    local function hasCycleUtil(vertex, parent)
        visited[vertex] = true
        recursionStack[vertex] = true

        for _, neighbor in ipairs(self:getNeighbors(vertex)) do
            if not visited[neighbor] then
                if hasCycleUtil(neighbor, vertex) then
                    return true
                end
            elseif recursionStack[neighbor] and (self.directed or neighbor ~= parent) then
                return true
            end
        end

        recursionStack[vertex] = false
        return false
    end

    for _, vertex in ipairs(self:getVertices()) do
        if not visited[vertex] then
            if hasCycleUtil(vertex, nil) then
                return true
            end
        end
    end

    return false
end

---Topological sort (only for directed acyclic graphs)
---@return table|nil sorted Array of vertices in topological order, or nil if graph has cycle
function Graph:topologicalSort()
    if not self.directed then
        return nil
    end

    local visited = {}
    local stack = {}

    local function topologicalSortUtil(vertex)
        visited[vertex] = true

        for _, neighbor in ipairs(self:getNeighbors(vertex)) do
            if not visited[neighbor] then
                topologicalSortUtil(neighbor)
            end
        end

        table.insert(stack, 1, vertex)
    end

    for _, vertex in ipairs(self:getVertices()) do
        if not visited[vertex] then
            topologicalSortUtil(vertex)
        end
    end

    return stack
end

-- =============================================
-- Factory Function
-- =============================================

---Create a new graph
---@param directed boolean Whether the graph is directed
---@return Graph
function graphs.new(directed)
    return Graph.new(directed)
end

return graphs
