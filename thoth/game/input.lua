local input = {}

local function hasValues(tbl)
    return tbl and #tbl > 0
end

local function cloneActionState(state)
    return {
        down = state and state.down or false,
        value = state and state.value or 0
    }
end

local function callAdapter(adapter, methodName, ...)
    if not adapter then
        return nil
    end
    local fn = adapter[methodName]
    if type(fn) ~= "function" then
        return nil
    end
    return fn(adapter, ...)
end

local Manager = {}
Manager.__index = Manager

function Manager.new(adapter)
    local self = setmetatable({}, Manager)
    self.adapter = adapter
    self.bindings = {}
    self.current = {}
    self.previous = {}
    return self
end

local function normalizeBindings(bindingSpec)
    if type(bindingSpec) == "string" then
        return {
            digital = {
                {kind = "key", id = bindingSpec}
            },
            axis = {}
        }
    end

    bindingSpec = bindingSpec or {}
    local normalized = {
        digital = {},
        axis = {}
    }

    if bindingSpec.key then
        table.insert(normalized.digital, {kind = "key", id = bindingSpec.key})
    end

    if hasValues(bindingSpec.keys) then
        for _, key in ipairs(bindingSpec.keys) do
            table.insert(normalized.digital, {kind = "key", id = key})
        end
    end

    if bindingSpec.button then
        table.insert(normalized.digital, {kind = "mouse", id = bindingSpec.button})
    end

    if hasValues(bindingSpec.buttons) then
        for _, button in ipairs(bindingSpec.buttons) do
            table.insert(normalized.digital, {kind = "mouse", id = button})
        end
    end

    if bindingSpec.axis then
        if type(bindingSpec.axis) == "string" then
            table.insert(normalized.axis, {name = bindingSpec.axis})
        elseif type(bindingSpec.axis) == "table" and (bindingSpec.axis.name or bindingSpec.axis.positive or bindingSpec.axis.negative) then
            table.insert(normalized.axis, bindingSpec.axis)
        elseif hasValues(bindingSpec.axis) then
            for _, axisBinding in ipairs(bindingSpec.axis) do
                table.insert(normalized.axis, axisBinding)
            end
        end
    end

    if bindingSpec.positive or bindingSpec.negative then
        table.insert(normalized.axis, {
            positive = bindingSpec.positive,
            negative = bindingSpec.negative
        })
    end

    return normalized
end

function Manager:setAdapter(adapter)
    self.adapter = adapter
    return self
end

function Manager:bind(action, bindingSpec)
    self.bindings[action] = normalizeBindings(bindingSpec)
    if not self.current[action] then
        self.current[action] = {down = false, value = 0}
    end
    if not self.previous[action] then
        self.previous[action] = {down = false, value = 0}
    end
    return self
end

function Manager:unbind(action)
    self.bindings[action] = nil
    self.current[action] = nil
    self.previous[action] = nil
end

function Manager:_digitalDown(binding)
    return callAdapter(self.adapter, "isDown", binding) == true
end

function Manager:_axisValue(binding)
    local value = callAdapter(self.adapter, "getAxis", binding)
    if type(value) == "number" then
        return value
    end

    local positiveDown = false
    local negativeDown = false
    if binding.positive then
        positiveDown = self:_digitalDown({kind = "key", id = binding.positive})
    end
    if binding.negative then
        negativeDown = self:_digitalDown({kind = "key", id = binding.negative})
    end

    if positiveDown and not negativeDown then
        return 1
    elseif negativeDown and not positiveDown then
        return -1
    end
    return 0
end

function Manager:update()
    for action, state in pairs(self.current) do
        self.previous[action] = cloneActionState(state)
    end

    for action, bindings in pairs(self.bindings) do
        local down = false
        local axisValue = 0

        for _, binding in ipairs(bindings.digital) do
            if self:_digitalDown(binding) then
                down = true
                break
            end
        end

        for _, axisBinding in ipairs(bindings.axis) do
            local value = self:_axisValue(axisBinding)
            if math.abs(value) > math.abs(axisValue) then
                axisValue = value
            end
        end

        self.current[action] = {
            down = down or (axisValue ~= 0),
            value = axisValue
        }
    end
end

function Manager:down(action)
    return self.current[action] and self.current[action].down or false
end

function Manager:pressed(action)
    local current = self.current[action]
    local previous = self.previous[action]
    return (current and current.down or false) and not (previous and previous.down or false)
end

function Manager:released(action)
    local current = self.current[action]
    local previous = self.previous[action]
    return not (current and current.down or false) and (previous and previous.down or false)
end

function Manager:axis(action)
    return self.current[action] and self.current[action].value or 0
end

input.Manager = Manager

function input.new(adapter)
    return Manager.new(adapter)
end

local defaultManager = Manager.new(nil)

function input.configure(adapter)
    defaultManager = Manager.new(adapter)
    return defaultManager
end

function input.bind(...)
    return defaultManager:bind(...)
end

function input.unbind(...)
    return defaultManager:unbind(...)
end

function input.update(...)
    return defaultManager:update(...)
end

function input.down(...)
    return defaultManager:down(...)
end

function input.pressed(...)
    return defaultManager:pressed(...)
end

function input.released(...)
    return defaultManager:released(...)
end

function input.axis(...)
    return defaultManager:axis(...)
end

function input.default()
    return defaultManager
end

return input
