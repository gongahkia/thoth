local mathModule = {}

-- @param specified value to be clamped, minimum value of the clamp range, maximum value of the clamp range
-- @return clamped value within the specified range
function mathModule.Clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

-- @param specified position in fibonacci sequence
-- @return the nth fibonnaci number
function mathModule.Fibonacci(n)
    if n <= 1 then return n end
    local a, b = 0, 1
    for i = 2, n do
        a, b = b, a + b
    end
    return b
end

-- @param start value for interpolation, end value for interpolation, interpolation factor (usually between 0 and 1)
-- @return linearly interpolated value between a and b based on t
function mathModule.Lerp(a, b, t)
    return a + (b - a) * t
end

-- @param angle in degrees
-- @return angle in radians
function mathModule.DegreeToRadian(d)
    return d * math.pi / 180
end

-- @param angle in radians
-- @return angle in degrees
function mathModule.RadianToDegree(r)
    return r * 180 / math.pi
end

-- @param minimum value of the range, maximum value of the range
-- @return random integer within specified min max range
function mathModule.RandRange(min, max)
    return math.random() * (max - min) + min
end

-- @param value to be remapped, lower bound of original range, upper bound of original range, lower bound of target range, upper bound of target range
-- @return value remapped within target range.
function mathModule.ScaleBy(val, fromMin, fromMax, toMin, toMax)
    return toMin+ (toMax - toMin) * ((val - fromMin) / (fromMax- fromMin))
end

-- @param lower bound of interpolation range, upper bound of interpolation range, value to be interpolated
-- @return interpolated value 
function mathModule.Smooth(low, upp, val)
    val = mathModule.Clamp((val - low) / (upp - low), 0, 1)
    return val * val * (3 - 2 * val)
end

return mathModule