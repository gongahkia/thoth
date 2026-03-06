local heaps = require("thoth.core.heaps")

local pathfinding = {}

local function defaultKey(node)
    if type(node) == "table" then
        if node.id ~= nil then
            return tostring(node.id)
        end
        if node.x ~= nil and node.y ~= nil then
            return tostring(node.x) .. ":" .. tostring(node.y)
        end
    end
    return tostring(node)
end

local function reconstructPath(previousKey, nodesByKey, startKey, goalKey)
    local path = {}
    local cursor = goalKey
    while cursor do
        table.insert(path, 1, nodesByKey[cursor])
        cursor = previousKey[cursor]
    end
    if #path == 0 or defaultKey(path[1]) ~= startKey then
        return nil
    end
    return path
end

function pathfinding.astar(config)
    assert(type(config) == "table", "A* config must be a table")
    assert(config.start ~= nil, "A* requires config.start")
    assert(config.goal ~= nil, "A* requires config.goal")
    assert(type(config.neighbors) == "function", "A* requires config.neighbors(current)")

    local keyFn = config.key or defaultKey
    local heuristic = config.heuristic or function() return 0 end

    local start = config.start
    local goal = config.goal
    local startKey = keyFn(start)
    local goalKey = keyFn(goal)

    local openSet = heaps.newMinHeap(function(a, b) return a.f < b.f end)
    local closed = {}
    local previousKey = {}
    local nodesByKey = {}
    local gScore = {}

    gScore[startKey] = 0
    nodesByKey[startKey] = start
    nodesByKey[goalKey] = goal

    openSet:push({
        node = start,
        key = startKey,
        f = heuristic(start, goal),
    })

    while not openSet:isEmpty() do
        local current = openSet:pop()
        if not closed[current.key] then
            if current.key == goalKey then
                local path = reconstructPath(previousKey, nodesByKey, startKey, goalKey)
                return path, gScore[current.key]
            end

            closed[current.key] = true
            for _, entry in ipairs(config.neighbors(current.node)) do
                local neighbor = entry
                local stepCost = 1
                if type(entry) == "table" and entry.node ~= nil then
                    neighbor = entry.node
                    stepCost = entry.cost or 1
                end

                local neighborKey = keyFn(neighbor)
                if not closed[neighborKey] then
                    nodesByKey[neighborKey] = neighbor
                    local tentative = gScore[current.key] + stepCost
                    if gScore[neighborKey] == nil or tentative < gScore[neighborKey] then
                        gScore[neighborKey] = tentative
                        previousKey[neighborKey] = current.key
                        local estimate = tentative + heuristic(neighbor, goal)
                        openSet:push({
                            node = neighbor,
                            key = neighborKey,
                            f = estimate,
                        })
                    end
                end
            end
        end
    end

    return nil, math.huge
end

function pathfinding.findPathGraph(graph, start, goal, heuristic)
    return pathfinding.astar({
        start = start,
        goal = goal,
        heuristic = heuristic or function() return 0 end,
        neighbors = function(node)
            local neighbors = {}
            for _, nextNode in ipairs(graph:getNeighbors(node)) do
                table.insert(neighbors, {
                    node = nextNode,
                    cost = graph:getWeight(node, nextNode) or 1
                })
            end
            return neighbors
        end,
    })
end

function pathfinding.findPathGrid(grid, start, goal, options)
    options = options or {}
    local rows = #grid
    local cols = #grid[1]
    local walkable = options.walkable or function(value) return value ~= 0 and value ~= false end

    local function inBounds(x, y)
        return x >= 1 and x <= cols and y >= 1 and y <= rows
    end

    local directions = {
        {x = 1, y = 0},
        {x = -1, y = 0},
        {x = 0, y = 1},
        {x = 0, y = -1},
    }

    return pathfinding.astar({
        start = start,
        goal = goal,
        key = function(node) return node.x .. ":" .. node.y end,
        heuristic = options.heuristic or function(a, b)
            return math.abs(a.x - b.x) + math.abs(a.y - b.y)
        end,
        neighbors = function(node)
            local neighbors = {}
            for _, dir in ipairs(directions) do
                local nx, ny = node.x + dir.x, node.y + dir.y
                if inBounds(nx, ny) and walkable(grid[ny][nx]) then
                    table.insert(neighbors, {
                        node = {x = nx, y = ny},
                        cost = 1
                    })
                end
            end
            return neighbors
        end,
    })
end

return pathfinding
