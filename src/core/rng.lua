local bitlib = bit or require("bit")
local band = bitlib.band
local bxor = bitlib.bxor
local lshift = bitlib.lshift
local rshift = bitlib.rshift

local Rng = {}
Rng.__index = Rng

local function u32(value)
    local result = band(value, 0xffffffff)
    if result < 0 then
        result = result + 4294967296
    end
    return result
end

function Rng.hash(seed, x, y, z)
    local h = u32(seed or 1)
    h = bxor(h, u32((x or 0) * 374761393))
    h = bxor(h, u32((y or 0) * 668265263))
    h = bxor(h, u32((z or 0) * 2246822519))
    h = bxor(h, rshift(h, 13))
    h = u32(h * 1274126177)
    h = bxor(h, rshift(h, 16))
    return u32(h)
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

function Rng:range(minValue, maxValue)
    local span = maxValue - minValue + 1
    return minValue + (self:next() % span)
end

function Rng:unit()
    return self:next() / 4294967295
end

return Rng
