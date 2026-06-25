local Rng = require("src.core.rng")

local Noise = {}

local function frac(value)
    return value - math.floor(value)
end

local function hashNoise(seed, x, y, salt)
    return Rng.hash(seed or 1, math.floor((x or 0) * 4096), math.floor((y or 0) * 4096), salt or 0) / 4294967295
end

local function loveNoise(seed, x, y, salt)
    if love and love.math and love.math.noise then
        return love.math.noise((x or 0) + (seed or 1) * 0.013, (y or 0) + (salt or 0) * 0.017)
    end
    return hashNoise(seed, x, y, salt)
end

function Noise.sample(kind, seed, x, y, options)
    options = options or {}
    kind = kind or "perlin"
    local scale = options.scale or 1
    local salt = options.salt or 0
    if kind == "fractal" or kind == "fbm" then
        return Noise.fractal(seed, x, y, options)
    end
    if kind == "simplex" then
        return loveNoise((seed or 1) + 7919, (x or 0) * scale + 0.37, (y or 0) * scale - 0.23, salt + 1543)
    end
    if kind == "hash" then
        return hashNoise(seed, (x or 0) * scale, (y or 0) * scale, salt)
    end
    return loveNoise(seed, (x or 0) * scale, (y or 0) * scale, salt)
end

function Noise.fractal(seed, x, y, options)
    options = options or {}
    local octaves = options.octaves or 4
    local frequency = options.frequency or options.scale or 0.18
    local lacunarity = options.lacunarity or 2
    local gain = options.gain or 0.5
    local amplitude = options.amplitude or 0.5
    local total = 0
    local norm = 0
    local source = options.source or "perlin"
    for octave = 1, octaves do
        total = total + Noise.sample(source, (seed or 1) + octave * 97, (x or 0) * frequency, (y or 0) * frequency, { scale = 1, salt = (options.salt or 0) + octave * 13 }) * amplitude
        norm = norm + amplitude
        amplitude = amplitude * gain
        frequency = frequency * lacunarity
    end
    return norm > 0 and total / norm or 0
end

function Noise.legacy(seed, x, y, salt)
    return frac(math.sin((x or 0) * 127.1 + (y or 0) * 311.7 + (seed or 1) * 74.7 + (salt or 0) * 19.19) * 43758.5453)
end

return Noise
