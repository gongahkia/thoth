-- @param minimum value of the range, maximum value of the range
-- @return random integer within specified min max range

function randomRange(min, max)
    return math.random() * (max - min) + min
end