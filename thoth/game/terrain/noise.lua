local noise = {}

local Noise = {}
Noise.__index = Noise

local function fract(value)
    return value - math.floor(value)
end

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

local function smoothstep(t)
    return t * t * (3 - (2 * t))
end

local function lattice(seed, x, y, z)
    local value = math.sin((x * 157.31) + (y * 789.221) + (z * 313.37) + (seed * 101.79)) * 43758.5453123
    return fract(value)
end

function Noise.new(seed)
    local self = setmetatable({}, Noise)
    self.seed = tonumber(seed) or 1
    return self
end

function Noise:setSeed(seed)
    self.seed = tonumber(seed) or 1
    return self
end

function Noise:sample(x, y, z)
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    z = tonumber(z) or 0

    local x0 = math.floor(x)
    local y0 = math.floor(y)
    local z0 = math.floor(z)
    local x1 = x0 + 1
    local y1 = y0 + 1
    local z1 = z0 + 1

    local tx = smoothstep(x - x0)
    local ty = smoothstep(y - y0)
    local tz = smoothstep(z - z0)

    local c000 = lattice(self.seed, x0, y0, z0)
    local c100 = lattice(self.seed, x1, y0, z0)
    local c010 = lattice(self.seed, x0, y1, z0)
    local c110 = lattice(self.seed, x1, y1, z0)
    local c001 = lattice(self.seed, x0, y0, z1)
    local c101 = lattice(self.seed, x1, y0, z1)
    local c011 = lattice(self.seed, x0, y1, z1)
    local c111 = lattice(self.seed, x1, y1, z1)

    local c00 = lerp(c000, c100, tx)
    local c10 = lerp(c010, c110, tx)
    local c01 = lerp(c001, c101, tx)
    local c11 = lerp(c011, c111, tx)

    local c0 = lerp(c00, c10, ty)
    local c1 = lerp(c01, c11, ty)

    return lerp(c0, c1, tz)
end

function Noise:octave(x, y, octaves, persistence, lacunarity, z)
    octaves = octaves or 1
    persistence = persistence or 0.5
    lacunarity = lacunarity or 2

    local total = 0
    local amplitude = 1
    local frequency = 1
    local maxValue = 0

    for _ = 1, octaves do
        total = total + (self:sample(x * frequency, y * frequency, (z or 0) * frequency) * amplitude)
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
    end

    if maxValue == 0 then
        return 0
    end

    return total / maxValue
end

function Noise:radial(centerX, centerY, x, y, scale)
    local dx = x - centerX
    local dy = y - centerY
    return self:sample(math.sqrt((dx * dx) + (dy * dy)) * (scale or 1), 0, 0)
end

noise.Noise = Noise

function noise.new(seed)
    return Noise.new(seed)
end

return noise
