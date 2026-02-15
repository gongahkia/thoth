-- All vectors and positions use array indices: {[1]=x, [2]=y}
local math2DModule = {}

-- @param entity1 table with coordinates {x,y}, entity2 table with coordinates {x,y}
-- @return angle formed between coordinates of both entities
function math2DModule.AngleBetween(ety1, ety2)
    return math.atan2(ety2[2] - ety1[2], ety2[1]- ety1[1])
end

-- @param entity1 table with coordinates {x,y}, entity2 table with coordinates {x,y}
-- @return euclidean straight-line distance between coordinates of both entities
function math2DModule.EuclideanDistance(ety1, ety2)
    return ((ety2[1]-ety1[1])^2 + (ety2[2]-ety1[2])^2)^0.5
end

-- @param entity1 table with coordinates {x,y}, entity2 table with coordinates {x,y}
-- @return manhattan distance between coordinates of both entities
function math2DModule.ManhattanDistance(ety1, ety2)
    return math.abs(ety2[1] - ety1[1]) + math.abs(ety2[2] - ety1[2])
end

-- @param 2D vector1 as a table {x,y}, 2D vector2 as a table {x,y}, 
-- @return added result vector
function math2DModule.VectorAdd(vec1, vec2)
    return {vec1[1] + vec2[1], vec1[2] + vec2[2]}
end

-- @param 2D vector as a table {x,y}
-- @return magnitude of the vector as an integer
function math2DModule.VectorMagnitude(vec)
    return math.sqrt(vec[1]^2 + vec[2]^2)
end

-- @param 2D vector as a table {x,y}
-- @return normalized 2D vector as a table {x/magnitude,y/magnitude}
function math2DModule.VectorNormalize(vec)
    local magnitude = math2DModule.VectorMagnitude(vec)
    if magnitude ~= 0 then
        return {vec[1]/magnitude, vec[2]/magnitude}
    else
        return {0, 0}
    end
end

-- @param vector as a table {x,y}, scalar value to scale the vector by
-- @return scaled result vector
function math2DModule.VectorScale(vec, scalar)
    return {vec[1] * scalar, vec[2] * scalar}
end

-- @param 2D vector1 as a table {x,y}, 2D vector2 as a table {x,y}, 
-- @return subtracted result vector
function math2DModule.VectorSubtract(vec1, vec2)
    return {vec1[1] - vec2[1], vec1[2] - vec2[2]}
end

return math2DModule