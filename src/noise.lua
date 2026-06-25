local Rng = require("src.rng")

local Noise = {}

local function floor(value)
    return math.floor(value)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function smooth(t)
    return t * t * (3 - 2 * t)
end

function Noise.value(seed, x, y, salt)
    local ix, iy = floor(x), floor(y)
    local fx, fy = smooth(x - ix), smooth(y - iy)
    local a = Rng.unit(seed, ix, iy, salt or 0)
    local b = Rng.unit(seed, ix + 1, iy, salt or 0)
    local c = Rng.unit(seed, ix, iy + 1, salt or 0)
    local d = Rng.unit(seed, ix + 1, iy + 1, salt or 0)
    return lerp(lerp(a, b, fx), lerp(c, d, fx), fy)
end

function Noise.fbm(seed, x, y, options)
    options = options or {}
    local octaves = options.octaves or 5
    local frequency = options.frequency or 0.01
    local lacunarity = options.lacunarity or 2
    local gain = options.gain or 0.5
    local amplitude = 1
    local total = 0
    local norm = 0
    for octave = 1, octaves do
        total = total + Noise.value(seed + octave * 101, x * frequency, y * frequency, (options.salt or 0) + octave * 17) * amplitude
        norm = norm + amplitude
        frequency = frequency * lacunarity
        amplitude = amplitude * gain
    end
    return norm > 0 and total / norm or 0
end

function Noise.ridge(seed, x, y, options)
    return 1 - math.abs(Noise.fbm(seed, x, y, options) * 2 - 1)
end

function Noise.warp(seed, x, y, options)
    options = options or {}
    local amount = options.amount or 32
    local frequency = options.frequency or 0.005
    local wx = Noise.fbm(seed + 7001, x, y, { frequency = frequency, octaves = 3, salt = 41 }) * 2 - 1
    local wy = Noise.fbm(seed + 9001, x, y, { frequency = frequency, octaves = 3, salt = 53 }) * 2 - 1
    return x + wx * amount, y + wy * amount
end

return Noise
