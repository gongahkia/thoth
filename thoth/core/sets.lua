local sets = {}

local Set = {}
Set.__index = Set

function Set.new(values)
    local self = setmetatable({}, Set)
    self.data = {}
    if type(values) == "table" then
        for _, value in ipairs(values) do
            self.data[value] = true
        end
    end
    return self
end

function Set:add(value)
    self.data[value] = true
    return self
end

function Set:remove(value)
    self.data[value] = nil
    return self
end

function Set:has(value)
    return self.data[value] == true
end

function Set:size()
    local count = 0
    for _ in pairs(self.data) do
        count = count + 1
    end
    return count
end

function Set:values()
    local values = {}
    for value in pairs(self.data) do
        values[#values + 1] = value
    end
    return values
end

function Set:union(other)
    local result = Set.new(self:values())
    for value in pairs(other.data) do
        result:add(value)
    end
    return result
end

function Set:intersection(other)
    local result = Set.new()
    for value in pairs(self.data) do
        if other:has(value) then
            result:add(value)
        end
    end
    return result
end

function Set:difference(other)
    local result = Set.new()
    for value in pairs(self.data) do
        if not other:has(value) then
            result:add(value)
        end
    end
    return result
end

sets.Set = Set

function sets.new(values)
    return Set.new(values)
end

return sets
