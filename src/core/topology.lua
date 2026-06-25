local Topology = {}

local squareDirections = { "north", "east", "south", "west" }
local hexDirections = { "east", "northeast", "northwest", "west", "southwest", "southeast" }
local allEdges = { "north", "east", "south", "west", "northeast", "northwest", "southwest", "southeast" }

local squareDelta = {
    north = { x = 0, y = -1 },
    east = { x = 1, y = 0 },
    south = { x = 0, y = 1 },
    west = { x = -1, y = 0 },
}

local hexEvenDelta = {
    east = { x = 1, y = 0 },
    northeast = { x = 0, y = -1 },
    northwest = { x = -1, y = -1 },
    west = { x = -1, y = 0 },
    southwest = { x = -1, y = 1 },
    southeast = { x = 0, y = 1 },
}

local hexOddDelta = {
    east = { x = 1, y = 0 },
    northeast = { x = 1, y = -1 },
    northwest = { x = 0, y = -1 },
    west = { x = -1, y = 0 },
    southwest = { x = 0, y = 1 },
    southeast = { x = 1, y = 1 },
}

local aliases = {
    triangle = "triangle",
    tri = "triangle",
    square = "square",
    quad = "square",
    hex = "hex",
    hexagon = "hex",
}

function Topology.normalize(value)
    return aliases[value or "square"] or "square"
end

function Topology.edgeCount(kind)
    if kind == "pentagon" or kind == "pent" then
        return 5
    end
    kind = Topology.normalize(kind)
    if kind == "triangle" then
        return 3
    end
    if kind == "hex" then
        return 6
    end
    return 4
end

function Topology.edgeIds()
    return allEdges
end

function Topology.trianglePointsUp(x, y)
    return ((x or 0) + (y or 0)) % 2 == 0
end

function Topology.directions(kind, x, y)
    kind = Topology.normalize(kind)
    if kind == "hex" then
        return hexDirections
    end
    if kind == "triangle" then
        return Topology.trianglePointsUp(x, y) and { "west", "east", "south" } or { "west", "east", "north" }
    end
    return squareDirections
end

function Topology.delta(kind, direction, x, y)
    kind = Topology.normalize(kind)
    if kind == "hex" then
        local deltas = ((y or 0) % 2 == 0) and hexEvenDelta or hexOddDelta
        return deltas[direction]
    end
    if kind == "triangle" then
        if direction == "west" or direction == "east" then
            return squareDelta[direction]
        end
        if Topology.trianglePointsUp(x, y) then
            return direction == "south" and squareDelta.south or nil
        end
        return direction == "north" and squareDelta.north or nil
    end
    return squareDelta[direction]
end

function Topology.neighbors(kind, x, y)
    local result = {}
    for _, direction in ipairs(Topology.directions(kind, x, y)) do
        local delta = Topology.delta(kind, direction, x, y)
        if delta then
            result[#result + 1] = { direction = direction, x = x + delta.x, y = y + delta.y }
        end
    end
    return result
end

local function hexAxial(x, y)
    local q = x - math.floor(y / 2)
    return q, y
end

function Topology.distance(kind, ax, ay, bx, by)
    kind = Topology.normalize(kind)
    if kind == "hex" then
        local aq, ar = hexAxial(ax, ay)
        local bq, br = hexAxial(bx, by)
        return (math.abs(aq - bq) + math.abs(aq + ar - bq - br) + math.abs(ar - br)) / 2
    end
    return math.abs(ax - bx) + math.abs(ay - by)
end

function Topology.line(kind, fromX, fromY, toX, toY)
    local points = {}
    local x = fromX
    local y = fromY
    local dx = math.abs(toX - fromX)
    local dy = math.abs(toY - fromY)
    local sx = fromX < toX and 1 or -1
    local sy = fromY < toY and 1 or -1
    local err = dx - dy
    while not (x == toX and y == toY) do
        local e2 = err * 2
        if e2 > -dy then
            err = err - dy
            x = x + sx
        end
        if e2 < dx then
            err = err + dx
            y = y + sy
        end
        points[#points + 1] = { x = x, y = y }
    end
    return points
end

function Topology.vertices(kind, x, y, inset)
    kind = Topology.normalize(kind)
    inset = inset or 0
    local left = x + inset
    local right = x + 1 - inset
    local top = y + inset
    local bottom = y + 1 - inset
    if kind == "triangle" then
        if Topology.trianglePointsUp(x, y) then
            return { { left, top }, { right, top }, { x + 0.5, bottom } }
        end
        return { { x + 0.5, top }, { right, bottom }, { left, bottom } }
    end
    if kind == "hex" then
        local cx = x + 0.5
        local cy = y + 0.5
        local rx = 0.48 - inset
        local ry = 0.42 - inset
        return {
            { cx + rx, cy },
            { cx + rx * 0.5, cy + ry },
            { cx - rx * 0.5, cy + ry },
            { cx - rx, cy },
            { cx - rx * 0.5, cy - ry },
            { cx + rx * 0.5, cy - ry },
        }
    end
    return { { left, top }, { right, top }, { right, bottom }, { left, bottom } }
end

function Topology.cellAtPoint(kind, worldX, worldY, originX, originY)
    return math.floor(worldX - (originX or 0)), math.floor(worldY - (originY or 0))
end

function Topology.center(kind, x, y)
    return x + 0.5, y + 0.5
end

return Topology
