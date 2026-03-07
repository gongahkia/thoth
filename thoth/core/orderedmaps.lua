local orderedmaps = {}

local OrderedMap = {}
OrderedMap.__index = OrderedMap

function OrderedMap.new()
    local self = setmetatable({}, OrderedMap)
    self.order = {}
    self.index = {}
    self.values = {}
    return self
end

function OrderedMap:set(key, value)
    if self.index[key] == nil then
        self.order[#self.order + 1] = key
        self.index[key] = #self.order
    end
    self.values[key] = value
    return self
end

function OrderedMap:get(key)
    return self.values[key]
end

function OrderedMap:has(key)
    return self.index[key] ~= nil
end

function OrderedMap:remove(key)
    local position = self.index[key]
    if not position then
        return nil
    end
    local value = self.values[key]
    table.remove(self.order, position)
    self.index[key] = nil
    self.values[key] = nil
    for i = position, #self.order do
        self.index[self.order[i]] = i
    end
    return value
end

function OrderedMap:keys()
    local keys = {}
    for i, key in ipairs(self.order) do
        keys[i] = key
    end
    return keys
end

function OrderedMap:items()
    local items = {}
    for i, key in ipairs(self.order) do
        items[i] = {key = key, value = self.values[key]}
    end
    return items
end

function OrderedMap:size()
    return #self.order
end

orderedmaps.OrderedMap = OrderedMap

function orderedmaps.new()
    return OrderedMap.new()
end

return orderedmaps
