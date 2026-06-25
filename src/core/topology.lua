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

local triangleHeight = math.sqrt(3) / 2
local hexWidth = 1
local hexRadius = hexWidth / math.sqrt(3)
local hexRowStep = hexRadius * 1.5

local function polygonCenter(points)
    local cx = 0
    local cy = 0
    for _, point in ipairs(points) do
        cx = cx + point[1]
        cy = cy + point[2]
    end
    return cx / #points, cy / #points
end

local function insetPolygon(points, inset)
    inset = tonumber(inset) or 0
    if inset <= 0 then
        return points
    end
    local cx, cy = polygonCenter(points)
    local scale = math.max(0.05, 1 - inset * 2)
    local result = {}
    for index, point in ipairs(points) do
        result[index] = { cx + (point[1] - cx) * scale, cy + (point[2] - cy) * scale }
    end
    return result
end

local function pointInPolygon(px, py, points)
    local inside = false
    local j = #points
    for i = 1, #points do
        local xi, yi = points[i][1], points[i][2]
        local xj, yj = points[j][1], points[j][2]
        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / ((yj - yi) == 0 and 1e-9 or (yj - yi)) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

function Topology.vertices(kind, x, y, inset, originX, originY)
    kind = Topology.normalize(kind)
    inset = inset or 0
    originX = originX or 0
    originY = originY or 0
    if kind == "triangle" then
        local left = originX + 1 + (x - 1) * 0.5
        local top = originY + 1 + (y - 1) * triangleHeight
        local points
        if Topology.trianglePointsUp(x, y) then
            points = { { left, top + triangleHeight }, { left + 1, top + triangleHeight }, { left + 0.5, top } }
        else
            points = { { left, top }, { left + 1, top }, { left + 0.5, top + triangleHeight } }
        end
        return insetPolygon(points, inset)
    end
    if kind == "hex" then
        local cx, cy = Topology.center(kind, x, y, originX, originY)
        local points = {}
        for index = 0, 5 do
            local angle = math.rad(-90 + index * 60)
            points[#points + 1] = { cx + math.cos(angle) * hexRadius, cy + math.sin(angle) * hexRadius }
        end
        return insetPolygon(points, inset)
    end
    local left = originX + x + inset
    local right = originX + x + 1 - inset
    local top = originY + y + inset
    local bottom = originY + y + 1 - inset
    return { { left, top }, { right, top }, { right, bottom }, { left, bottom } }
end

local function nearestCell(kind, px, py, approxX, approxY, originX, originY)
    local bestX = approxX
    local bestY = approxY
    local bestDistance = math.huge
    for y = approxY - 3, approxY + 3 do
        for x = approxX - 3, approxX + 3 do
            if pointInPolygon(px, py, Topology.vertices(kind, x, y, 0, originX, originY)) then
                return x, y
            end
            local cx, cy = Topology.center(kind, x, y, originX, originY)
            local dx = cx - px
            local dy = cy - py
            local distance = dx * dx + dy * dy
            if distance < bestDistance then
                bestX = x
                bestY = y
                bestDistance = distance
            end
        end
    end
    return bestX, bestY
end

function Topology.cellAtPoint(kind, worldX, worldY, originX, originY)
    kind = Topology.normalize(kind)
    originX = originX or 0
    originY = originY or 0
    if kind == "triangle" then
        local approxY = math.floor((worldY - originY - 1) / triangleHeight) + 1
        local approxX = math.floor((worldX - originX - 1) * 2) + 1
        return nearestCell(kind, worldX, worldY, approxX, approxY, originX, originY)
    end
    if kind == "hex" then
        local approxY = math.floor((worldY - originY - 0.5) / hexRowStep) + 1
        local rowOffset = (approxY % 2 == 1) and 0.5 or 0
        local approxX = math.floor(worldX - originX - rowOffset)
        return nearestCell(kind, worldX, worldY, approxX, approxY, originX, originY)
    end
    return math.floor(worldX - originX), math.floor(worldY - originY)
end

function Topology.center(kind, x, y, originX, originY)
    kind = Topology.normalize(kind)
    originX = originX or 0
    originY = originY or 0
    if kind == "triangle" then
        return polygonCenter(Topology.vertices(kind, x, y, 0, originX, originY))
    end
    if kind == "hex" then
        local rowOffset = (y % 2 == 1) and 0.5 or 0
        return originX + x + 0.5 + rowOffset, originY + 0.5 + y * hexRowStep
    end
    return originX + x + 0.5, originY + y + 0.5
end

function Topology.boardBounds(kind, width, height, originX, originY)
    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge
    for y = 1, height or 0 do
        for x = 1, width or 0 do
            for _, point in ipairs(Topology.vertices(kind, x, y, 0, originX, originY)) do
                minX = math.min(minX, point[1])
                minY = math.min(minY, point[2])
                maxX = math.max(maxX, point[1])
                maxY = math.max(maxY, point[2])
            end
        end
    end
    if minX == math.huge then
        return originX or 0, originY or 0, originX or 0, originY or 0
    end
    return minX, minY, maxX, maxY
end

function Topology.centerBounds(kind, width, height, originX, originY)
    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge
    for y = 1, height or 0 do
        for x = 1, width or 0 do
            local cx, cy = Topology.center(kind, x, y, originX, originY)
            minX = math.min(minX, cx)
            minY = math.min(minY, cy)
            maxX = math.max(maxX, cx)
            maxY = math.max(maxY, cy)
        end
    end
    if minX == math.huge then
        return originX or 0, originY or 0, originX or 0, originY or 0
    end
    return minX, minY, maxX, maxY
end

return Topology
