local inventory = {}
local Manager = {}
Manager.__index = Manager

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function cloneItem(item)
    local copy = {}
    for key, value in pairs(item) do
        if type(value) == "table" then
            local nested = {}
            for k, v in pairs(value) do nested[k] = v end
            copy[key] = nested
        else
            copy[key] = value
        end
    end
    return copy
end

function Manager.new(config)
    config = config or {}
    local self = setmetatable({}, Manager)
    self.definitions = {}
    self.aliases = {}
    for kind, def in pairs(config.definitions or {}) do
        self.definitions[kind] = def
    end
    for alias, canonical in pairs(config.aliases or {}) do
        self.aliases[alias] = canonical
    end
    return self
end

function Manager:define(kind, definition)
    assert(type(kind) == "string" and #kind > 0, "Item kind must be a non-empty string")
    assert(type(definition) == "table", "Item definition must be a table")
    self.definitions[kind] = definition
end

function Manager:alias(aliasName, canonical)
    self.aliases[aliasName] = canonical
end

local function normalizeKind(self, kind)
    return self.aliases[kind] or kind
end

function Manager:getDefinition(kind)
    return self.definitions[normalizeKind(self, kind)]
end

function Manager:describe(kind)
    local normalized = normalizeKind(self, kind)
    local def = self:getDefinition(normalized)
    return def and def.label or tostring(normalized)
end

function Manager:isPerishable(kind)
    local def = self:getDefinition(kind)
    return def and def.perishable == true
end

function Manager:create(kind, quantity)
    local normalized = normalizeKind(self, kind)
    local def = self:getDefinition(normalized)
    local item = {kind = normalized, quantity = quantity or 1}
    if def and def.perishable then
        item.condition = 100
    end
    return item
end

function Manager:cloneInventory(inv)
    local copy = {}
    for i, item in ipairs(inv or {}) do
        copy[i] = cloneItem(item)
    end
    return copy
end

function Manager:add(inv, kind, quantity)
    inv = inv or {}
    quantity = quantity or 1
    local normalized = normalizeKind(self, kind)
    local def = self:getDefinition(normalized)
    if def and def.stackable ~= false then
        for _, item in ipairs(inv) do
            if normalizeKind(self, item.kind) == normalized then
                item.kind = normalized
                item.quantity = item.quantity + quantity
                if def.perishable and item.condition == nil then
                    item.condition = 100
                end
                return item
            end
        end
    end
    local item = self:create(normalized, quantity)
    table.insert(inv, item)
    return item
end

function Manager:remove(inv, kind, quantity)
    inv = inv or {}
    quantity = quantity or 1
    local normalized = normalizeKind(self, kind)
    for index = #inv, 1, -1 do
        local item = inv[index]
        if normalizeKind(self, item.kind) == normalized then
            item.kind = normalized
            local amount = math.min(quantity, item.quantity or 1)
            item.quantity = (item.quantity or 1) - amount
            quantity = quantity - amount
            if item.quantity <= 0 then
                table.remove(inv, index)
            end
            if quantity <= 0 then return true end
        end
    end
    return false
end

function Manager:count(inv, kind)
    local total = 0
    local normalized = normalizeKind(self, kind)
    for _, item in ipairs(inv or {}) do
        if normalizeKind(self, item.kind) == normalized then
            total = total + (item.quantity or 1)
        end
    end
    return total
end

function Manager:totalWeight(inv)
    local total = 0
    for _, item in ipairs(inv or {}) do
        local def = self:getDefinition(item.kind)
        if def then
            total = total + (def.weight * (item.quantity or 1))
        end
    end
    return total
end

function Manager:findIndex(inv, kind)
    local normalized = normalizeKind(self, kind)
    for index, item in ipairs(inv or {}) do
        if normalizeKind(self, item.kind) == normalized then
            return index
        end
    end
    return nil
end

function Manager:findItem(inv, kind)
    local index = self:findIndex(inv, kind)
    return index and inv[index] or nil, index
end

function Manager:adjustCondition(item, delta)
    if not item then return nil end
    item.condition = clamp((item.condition or 100) + delta, 0, 100)
    return item.condition
end

function Manager:sortInventory(inv)
    local mgr = self
    table.sort(inv, function(left, right)
        local ll = mgr:describe(left.kind)
        local rl = mgr:describe(right.kind)
        if ll == rl then
            local lc = left.condition or 101
            local rc = right.condition or 101
            if lc == rc then
                return (left.quantity or 1) > (right.quantity or 1)
            end
            return lc > rc
        end
        return ll < rl
    end)
end

function Manager:decayPerishables(inv, hours, multiplier)
    multiplier = multiplier or 1.0
    for i = #inv, 1, -1 do
        local item = inv[i]
        local def = self:getDefinition(item.kind)
        if def and def.perishable and def.decayPerHour and item.condition then
            item.condition = clamp(item.condition - def.decayPerHour * hours * multiplier, 0, 100)
        end
    end
end

function Manager:snapshot(inv)
    return self:cloneInventory(inv)
end

function Manager:restore(snapshot)
    return self:cloneInventory(snapshot)
end

inventory.Manager = Manager

function inventory.new(config)
    return Manager.new(config)
end

return inventory
