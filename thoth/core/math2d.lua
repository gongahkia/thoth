-- All vectors and positions use array indices: {[1]=x, [2]=y}
local api = require("thoth.core.api")

local math2DModule = {}

local function atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end
    return 0
end

function math2DModule.AngleBetween(ety1, ety2)
    return atan2(ety2[2] - ety1[2], ety2[1] - ety1[1])
end

function math2DModule.EuclideanDistance(ety1, ety2)
    return ((ety2[1] - ety1[1]) ^ 2 + (ety2[2] - ety1[2]) ^ 2) ^ 0.5
end

function math2DModule.ManhattanDistance(ety1, ety2)
    return math.abs(ety2[1] - ety1[1]) + math.abs(ety2[2] - ety1[2])
end

function math2DModule.VectorAdd(vec1, vec2)
    return {vec1[1] + vec2[1], vec1[2] + vec2[2]}
end

function math2DModule.VectorMagnitude(vec)
    return math.sqrt(vec[1] ^ 2 + vec[2] ^ 2)
end

function math2DModule.VectorNormalize(vec)
    local magnitude = math2DModule.VectorMagnitude(vec)
    if magnitude ~= 0 then
        return {vec[1] / magnitude, vec[2] / magnitude}
    end
    return {0, 0}
end

function math2DModule.VectorScale(vec, scalar)
    return {vec[1] * scalar, vec[2] * scalar}
end

function math2DModule.VectorSubtract(vec1, vec2)
    return {vec1[1] - vec2[1], vec1[2] - vec2[2]}
end

math2DModule.CardinalDirections = {
    {name = "north", dx = 0, dy = -1, angle = -math.pi * 0.5},
    {name = "east", dx = 1, dy = 0, angle = 0.0},
    {name = "south", dx = 0, dy = 1, angle = math.pi * 0.5},
    {name = "west", dx = -1, dy = 0, angle = math.pi},
}

local cardinalByName = {}
for _, dir in ipairs(math2DModule.CardinalDirections) do
    cardinalByName[dir.name] = dir
end

function math2DModule.DistanceToSegment(point, segA, segB) -- returns distance, closestX, closestY
    local vx = segB[1] - segA[1]
    local vy = segB[2] - segA[2]
    local wx = point[1] - segA[1]
    local wy = point[2] - segA[2]
    local lensq = vx * vx + vy * vy
    local t = 0
    if lensq > 0 then
        t = math.max(0, math.min(1, (wx * vx + wy * vy) / lensq))
    end
    local cx = segA[1] + vx * t
    local cy = segA[2] + vy * t
    local dx = point[1] - cx
    local dy = point[2] - cy
    return math.sqrt(dx * dx + dy * dy), cx, cy
end

function math2DModule.SampleLine(a, b, callback, steps) -- parametric line walk; callback(x, y, t) returning false stops early
    local dx = b[1] - a[1]
    local dy = b[2] - a[2]
    steps = steps or math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy)) * 12))
    for i = 0, steps do
        local t = i / steps
        local x = a[1] + dx * t
        local y = a[2] + dy * t
        if callback(x, y, t) == false then
            return false
        end
    end
    return true
end

function math2DModule.SegmentNormal(a, b) -- perpendicular normal of segment a->b
    local vx = b[1] - a[1]
    local vy = b[2] - a[2]
    local len = math.sqrt(vx * vx + vy * vy)
    if len == 0 then return {0, 0} end
    return {-vy / len, vx / len}
end

function math2DModule.FacingCardinal(angle) -- snap angle to nearest cardinal direction
    local tau = math.pi * 2
    angle = angle % tau
    if angle < math.pi * 0.25 or angle >= math.pi * 1.75 then
        return cardinalByName.east
    elseif angle < math.pi * 0.75 then
        return cardinalByName.south
    elseif angle < math.pi * 1.25 then
        return cardinalByName.west
    end
    return cardinalByName.north
end

function math2DModule.CellKey(x, y) -- coordinate string hash for grid lookups
    return string.format("%d:%d", x, y)
end

function math2DModule.EdgeKey(ax, ay, bx, by) -- canonical undirected edge key (sorted)
    local left = math2DModule.CellKey(ax, ay)
    local right = math2DModule.CellKey(bx, by)
    if left < right then
        return left .. "|" .. right
    end
    return right .. "|" .. left
end

math2DModule = api.withSnakeCaseAliases(math2DModule)
package.loaded["thoth.core.math2D"] = math2DModule
package.loaded["thoth.core.math2d"] = math2DModule

return math2DModule
