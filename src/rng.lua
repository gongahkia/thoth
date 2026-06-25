local bitlib = bit or bit32
local band = bitlib.band
local bxor = bitlib.bxor
local lshift = bitlib.lshift
local rshift = bitlib.rshift

local Rng = {}
Rng.__index = Rng

local function u32(value)
    local result = band(math.floor(value or 0), 0xffffffff)
    if result < 0 then result = result + 4294967296 end
    return result
end

function Rng.hash(seed, a, b, c, d)
    local h = u32(seed or 1)
    h = bxor(h, u32((a or 0) * 374761393))
    h = bxor(h, u32((b or 0) * 668265263))
    h = bxor(h, u32((c or 0) * 2246822519))
    h = bxor(h, u32((d or 0) * 3266489917))
    h = bxor(h, rshift(h, 13))
    h = u32(h * 1274126177)
    h = bxor(h, rshift(h, 16))
    return u32(h)
end

function Rng.unitAt(seed, a, b, c, d)
    return Rng.hash(seed, a, b, c, d) / 4294967295
end

function Rng.signed(seed, a, b, c, d)
    return Rng.unitAt(seed, a, b, c, d) * 2 - 1
end

function Rng.new(seed)
    return setmetatable({ state = u32(seed or 1) }, Rng)
end

function Rng:next()
    local x = self.state
    x = bxor(x, lshift(x, 13))
    x = bxor(x, rshift(x, 17))
    x = bxor(x, lshift(x, 5))
    self.state = u32(x)
    return self.state
end

function Rng:unit()
    return self:next() / 4294967295
end

function Rng:range(minValue, maxValue)
    return minValue + (self:next() % (maxValue - minValue + 1))
end

return Rng
