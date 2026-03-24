local resources = {}

local Manager = {}
Manager.__index = Manager

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function normalizeNumber(value, fieldName)
    assert(type(value) == "number", fieldName .. " must be a number")
    return value
end

function Manager.new(definitions)
    local self = setmetatable({}, Manager)
    self.pools = {}

    for name, spec in pairs(definitions or {}) do
        self:set(name, spec.current, spec.max)
    end

    return self
end

function Manager:set(name, current, maximum)
    assert(type(name) == "string" and #name > 0, "Resource name must be a non-empty string")

    local existing = self.pools[name]
    local resolvedMaximum = maximum
    if resolvedMaximum == nil then
        resolvedMaximum = existing and existing.max or current
    end

    current = normalizeNumber(current, "current")
    resolvedMaximum = normalizeNumber(resolvedMaximum, "max")
    assert(resolvedMaximum >= 0, "max must be >= 0")

    self.pools[name] = {
        current = clamp(current, 0, resolvedMaximum),
        max = resolvedMaximum,
    }

    return self.pools[name].current, self.pools[name].max
end

function Manager:add(name, amount)
    local pool = assert(self.pools[name], "Unknown resource '" .. tostring(name) .. "'")
    amount = normalizeNumber(amount, "amount")
    pool.current = clamp(pool.current + amount, 0, pool.max)
    return pool.current
end

function Manager:spend(name, amount)
    local pool = assert(self.pools[name], "Unknown resource '" .. tostring(name) .. "'")
    amount = normalizeNumber(amount, "amount")
    assert(amount >= 0, "amount must be >= 0")

    if pool.current < amount then
        return false, pool.current
    end

    pool.current = pool.current - amount
    return true, pool.current
end

function Manager:current(name)
    local pool = assert(self.pools[name], "Unknown resource '" .. tostring(name) .. "'")
    return pool.current
end

function Manager:max(name)
    local pool = assert(self.pools[name], "Unknown resource '" .. tostring(name) .. "'")
    return pool.max
end

function Manager:snapshot()
    local snapshot = {}
    for name, pool in pairs(self.pools) do
        snapshot[name] = {
            current = pool.current,
            max = pool.max,
        }
    end
    return snapshot
end

function Manager:restore(snapshot)
    assert(type(snapshot) == "table", "Resource snapshot must be a table")

    self.pools = {}
    for name, pool in pairs(snapshot) do
        self:set(name, pool.current, pool.max)
    end

    return self
end

resources.Manager = Manager

function resources.new(definitions)
    return Manager.new(definitions)
end

return resources
