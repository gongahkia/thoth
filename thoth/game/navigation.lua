local graphs = require("thoth.core.graphs")
local pathfinding = require("thoth.game.pathfinding")

local navigation = {}

local function defaultWalkable(value)
    return value ~= 0 and value ~= false and value ~= nil
end

local function defaultCost(_from, _to, value)
    if type(value) == "number" then
        return value
    end
    return 1
end

function navigation.buildGrid(tilemap, layerName)
    local grid = {}
    tilemap:eachCell(layerName, function(x, y, value)
        grid[y] = grid[y] or {}
        grid[y][x] = value
    end)
    return grid
end

function navigation.findPath(tilemap, layerName, start, goal, options)
    options = options or {}
    local grid = navigation.buildGrid(tilemap, layerName)
    return pathfinding.findPathGrid(grid, start, goal, {
        diagonal = options.diagonal,
        walkable = options.walkable or defaultWalkable,
        heuristic = options.heuristic,
        cost = options.cost,
    })
end

function navigation.toWaypointGraph(tilemap, layerName, options)
    options = options or {}
    local graph = graphs.new(false)
    local walkable = options.walkable or defaultWalkable
    local cost = options.cost or defaultCost
    local directions = {
        {x = 1, y = 0},
        {x = -1, y = 0},
        {x = 0, y = 1},
        {x = 0, y = -1},
    }

    if options.diagonal then
        directions[#directions + 1] = {x = 1, y = 1}
        directions[#directions + 1] = {x = 1, y = -1}
        directions[#directions + 1] = {x = -1, y = 1}
        directions[#directions + 1] = {x = -1, y = -1}
    end

    tilemap:eachCell(layerName, function(x, y, value)
        if walkable(value, x, y) then
            local node = x .. ":" .. y
            graph:addVertex(node)
            for _, direction in ipairs(directions) do
                local nx = x + direction.x
                local ny = y + direction.y
                if nx >= 1 and nx <= tilemap.width and ny >= 1 and ny <= tilemap.height then
                    local nextValue = tilemap:getTile(layerName, nx, ny)
                    if walkable(nextValue, nx, ny) then
                        local weight = cost({x = x, y = y}, {x = nx, y = ny}, nextValue)
                        graph:addEdge(node, nx .. ":" .. ny, weight)
                    end
                end
            end
        end
    end)

    return graph
end

return navigation
