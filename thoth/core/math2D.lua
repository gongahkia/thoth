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

math2DModule = api.withSnakeCaseAliases(math2DModule)
package.loaded["thoth.core.math2D"] = math2DModule
package.loaded["thoth.core.math2d"] = math2DModule

return math2DModule
