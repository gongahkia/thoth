local Rng = {}
Rng.__index = Rng

local mod = 2147483647

local function norm(value)
    return math.floor(tonumber(value) or 0) % mod
end

local function mix(h, value, salt)
    h = (h + norm(value) * salt) % mod
    h = (h * 48271 + 1) % mod
    return h
end

function Rng.hash(seed, a, b, c, d)
    local h = norm(seed or 1)
    h = mix(h, a or 0, 73856093)
    h = mix(h, b or 0, 19349663)
    h = mix(h, c or 0, 83492791)
    h = mix(h, d or 0, 26544357)
    return h
end

function Rng.unitAt(seed, a, b, c, d)
    return Rng.hash(seed, a, b, c, d) / mod
end

function Rng.signed(seed, a, b, c, d)
    return Rng.unitAt(seed, a, b, c, d) * 2 - 1
end

function Rng.new(seed)
    return setmetatable({ state = norm(seed or 1) }, Rng)
end

function Rng:next()
    self.state = (self.state * 48271 + 1) % mod
    return self.state
end

function Rng:unit()
    return self:next() / mod
end

function Rng:range(minValue, maxValue)
    return minValue + (self:next() % (maxValue - minValue + 1))
end

return Rng
