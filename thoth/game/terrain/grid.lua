local serialize = require("thoth.core.serialize")
local tilemapModule = require("thoth.game.tilemap")

local grid = {}

local function copyValue(value)
    if type(value) == "table" then
        return serialize.deepCopy(value)
    end
    return value
end

local function makeMatcher(matcher)
    if matcher == nil then
        return function(value)
            return value ~= nil and value ~= false and value ~= 0
        end
    end

    if type(matcher) == "function" then
        return matcher
    end

    return function(value)
        return value == matcher
    end
end

function grid.new(width, height, fillValue)
    assert(type(width) == "number" and width > 0, "width must be > 0")
    assert(type(height) == "number" and height > 0, "height must be > 0")

    local out = {}
    for y = 1, height do
        out[y] = {}
        for x = 1, width do
            out[y][x] = copyValue(fillValue)
        end
    end
    return out
end

function grid.clone(source)
    assert(type(source) == "table", "grid must be a table")
    return serialize.deepCopy(source)
end

function grid.dimensions(source)
    assert(type(source) == "table" and type(source[1]) == "table", "grid must be a non-empty 2D table")
    return #source[1], #source
end

function grid.inBounds(source, x, y)
    local width, height = grid.dimensions(source)
    return x >= 1 and x <= width and y >= 1 and y <= height
end

function grid.toStrings(source)
    local lines = {}
    for y = 1, #source do
        lines[y] = table.concat(source[y])
    end
    return lines
end

function grid.fromStrings(lines)
    assert(type(lines) == "table", "lines must be a table")
    local out = {}
    for y, line in ipairs(lines) do
        assert(type(line) == "string", "line entries must be strings")
        out[y] = {}
        for char in line:gmatch(".") do
            out[y][#out[y] + 1] = char
        end
    end
    return out
end

function grid.countNeighbors(source, x, y, matcher, options)
    options = options or {}
    local match = makeMatcher(matcher)
    local width, height = grid.dimensions(source)
    local total = 0

    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local nx = x + dx
                local ny = y + dy

                if options.clamp then
                    nx = math.max(1, math.min(width, nx))
                    ny = math.max(1, math.min(height, ny))
                end

                if nx >= 1 and nx <= width and ny >= 1 and ny <= height and match(source[ny][nx], nx, ny) then
                    total = total + 1
                end
            end
        end
    end

    return total
end

function grid.countTypes(source)
    local counts = {}
    for y = 1, #source do
        for x = 1, #source[y] do
            local value = source[y][x]
            counts[value] = (counts[value] or 0) + 1
        end
    end
    return counts
end

function grid.runCellularAutomaton(source, iterations, birth, survive, options)
    assert(type(iterations) == "number" and iterations >= 0, "iterations must be >= 0")
    birth = birth or {}
    survive = survive or {}
    options = options or {}

    local current = grid.clone(source)
    local width, height = grid.dimensions(current)

    for _ = 1, iterations do
        local nextGrid = {}
        for y = 1, height do
            nextGrid[y] = {}
            for x = 1, width do
                local count = grid.countNeighbors(current, x, y, options.aliveValue or 1, {
                    clamp = options.clampEdges,
                })
                local alive = current[y][x] == (options.aliveValue or 1)
                nextGrid[y][x] = alive and (survive[count] and (options.aliveValue or 1) or (options.deadValue or 0))
                    or (birth[count] and (options.aliveValue or 1) or (options.deadValue or 0))
            end
        end
        current = nextGrid
    end

    return current
end

function grid.generateVoronoiSeeds(width, height, count, rng, factory)
    assert(type(width) == "number" and width > 0, "width must be > 0")
    assert(type(height) == "number" and height > 0, "height must be > 0")
    assert(type(count) == "number" and count >= 0, "count must be >= 0")

    local seeds = {}
    factory = factory or function()
        return {}
    end

    for _ = 1, count do
        local seed = factory() or {}
        seed.x = seed.x or rng:random(1, width)
        seed.y = seed.y or rng:random(1, height)
        seeds[#seeds + 1] = seed
    end

    return seeds
end

function grid.nearestVoronoiSeed(x, y, seeds)
    local bestSeed = nil
    local bestDistance = math.huge

    for _, seed in ipairs(seeds or {}) do
        local dx = x - seed.x
        local dy = y - seed.y
        local distance = dx * dx + dy * dy
        if distance < bestDistance then
            bestDistance = distance
            bestSeed = seed
        end
    end

    return bestSeed, bestDistance
end

function grid.countConnectedRegions(source, matcher, options)
    options = options or {}
    local match = makeMatcher(matcher)
    local width, height = grid.dimensions(source)
    local visited = {}
    local regions = 0
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

    for y = 1, height do
        visited[y] = {}
    end

    for y = 1, height do
        for x = 1, width do
            if not visited[y][x] and match(source[y][x], x, y) then
                regions = regions + 1
                local stack = {{x = x, y = y}}
                visited[y][x] = true

                while #stack > 0 do
                    local node = table.remove(stack)
                    for _, direction in ipairs(directions) do
                        local nx = node.x + direction.x
                        local ny = node.y + direction.y
                        if nx >= 1 and nx <= width and ny >= 1 and ny <= height and not visited[ny][nx]
                            and match(source[ny][nx], nx, ny) then
                            visited[ny][nx] = true
                            stack[#stack + 1] = {x = nx, y = ny}
                        end
                    end
                end
            end
        end
    end

    return regions
end

function grid.toTilemap(source, layerName, tileWidth, tileHeight)
    local width, height = grid.dimensions(source)
    local tilemap = tilemapModule.new(width, height, tileWidth or 1, tileHeight or tileWidth or 1)
    tilemap:addLayer(layerName or "terrain", grid.clone(source))
    return tilemap
end

function grid.fromTilemap(tilemap, layerName)
    assert(type(tilemap) == "table" and type(tilemap.getLayer) == "function", "tilemap must be a Tilemap")
    return grid.clone(assert(tilemap:getLayer(layerName or "terrain"), "terrain layer not found"))
end

return grid
