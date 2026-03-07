local random = {}

local MODULUS = 2147483647
local MULTIPLIER = 48271

local Generator = {}
Generator.__index = Generator

local function normalizeSeed(seed)
    seed = math.floor(math.abs(tonumber(seed) or 1))
    seed = seed % MODULUS
    if seed == 0 then
        seed = 1
    end
    return seed
end

function Generator.new(seed)
    local normalized = normalizeSeed(seed)
    local self = setmetatable({}, Generator)
    self.initialSeed = normalized
    self.seed = normalized
    return self
end

function Generator:setSeed(seed)
    local normalized = normalizeSeed(seed)
    self.initialSeed = normalized
    self.seed = normalized
    return self.seed
end

function Generator:getSeed()
    return self.seed
end

function Generator:getInitialSeed()
    return self.initialSeed
end

function Generator:nextInt()
    self.seed = (self.seed * MULTIPLIER) % MODULUS
    return self.seed
end

function Generator:random(min, max)
    local value = self:nextInt() / MODULUS
    if min == nil then
        return value
    end

    if max == nil then
        max = min
        min = 1
    end

    assert(type(min) == "number" and type(max) == "number", "random bounds must be numbers")
    assert(min <= max, "random lower bound must be <= upper bound")

    if math.floor(min) == min and math.floor(max) == max then
        return min + math.floor(value * (max - min + 1))
    end

    return min + ((max - min) * value)
end

function Generator:choice(values)
    assert(type(values) == "table" and #values > 0, "choice expects a non-empty array")
    return values[self:random(1, #values)]
end

function Generator:getState()
    return {
        seed = self.seed,
        initialSeed = self.initialSeed,
    }
end

function Generator:setState(state)
    assert(type(state) == "table", "random state must be a table")
    self.initialSeed = normalizeSeed(state.initialSeed or state.seed)
    self.seed = normalizeSeed(state.seed or self.initialSeed)
    return self
end

random.Generator = Generator

function random.new(seed)
    return Generator.new(seed)
end

return random
