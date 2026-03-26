local api = require("thoth.core.api")

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
    local denom = fromMax - fromMin
    if denom == 0 then return nil, "division by zero: fromMax equals fromMin" end
    return toMin + (toMax - toMin) * ((val - fromMin) / denom)
end

-- @param lower bound of interpolation range, upper bound of interpolation range, value to be interpolated
-- @return interpolated value 
function mathModule.Smooth(low, upp, val)
    local denom = upp - low
    if denom == 0 then return nil, "division by zero: upp equals low" end
    val = mathModule.Clamp((val - low) / denom, 0, 1)
    return val * val * (3 - 2 * val)
end

function mathModule.Approach(value, target, delta) -- move value toward target by at most delta
    if value < target then
        return math.min(value + delta, target)
    end
    if value > target then
        return math.max(value - delta, target)
    end
    return target
end

function mathModule.Round(value) -- symmetric rounding (banker's)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function mathModule.Sign(value) -- returns -1, 0, or 1
    if value > 0 then return 1 end
    if value < 0 then return -1 end
    return 0
end

function mathModule.WrapAngle(angle) -- normalize angle to [0, 2π)
    local tau = math.pi * 2
    angle = angle % tau
    if angle < 0 then
        angle = angle + tau
    end
    return angle
end

return api.withSnakeCaseAliases(mathModule)
