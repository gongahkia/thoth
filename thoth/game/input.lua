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

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local out = {}
    seen[value] = out
    for key, item in pairs(value) do
        out[deepCopy(key, seen)] = deepCopy(item, seen)
    end
    return out
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
    self.contexts = {
        default = {}
    }
    self.contextStack = {"default"}
    self.bindings = self.contexts.default
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

function Manager:_activeContextName()
    return self.contextStack[#self.contextStack] or "default"
end

function Manager:_ensureContext(name)
    assert(type(name) == "string" and #name > 0, "Context name must be a non-empty string")
    if not self.contexts[name] then
        self.contexts[name] = {}
    end
    return self.contexts[name]
end

function Manager:_resolveBindings()
    local resolved = {}
    for _, contextName in ipairs(self.contextStack) do
        local contextBindings = self.contexts[contextName]
        if contextBindings then
            for action, binding in pairs(contextBindings) do
                resolved[action] = binding
            end
        end
    end
    return resolved
end

function Manager:_syncStates()
    local activeBindings = self:_resolveBindings()

    for action in pairs(self.current) do
        if not activeBindings[action] then
            self.current[action] = nil
            self.previous[action] = nil
        end
    end

    for action in pairs(activeBindings) do
        if not self.current[action] then
            self.current[action] = {down = false, value = 0}
        end
        if not self.previous[action] then
            self.previous[action] = {down = false, value = 0}
        end
    end

    return activeBindings
end

function Manager:setContext(name)
    self:_ensureContext(name)
    self.contextStack = {name}
    self.bindings = self.contexts[name]
    self:_syncStates()
    return self
end

function Manager:pushContext(name)
    self:_ensureContext(name)
    table.insert(self.contextStack, name)
    self.bindings = self.contexts[name]
    self:_syncStates()
    return self
end

function Manager:popContext()
    if #self.contextStack <= 1 then
        return self:_activeContextName()
    end

    local removed = table.remove(self.contextStack)
    self.bindings = self.contexts[self:_activeContextName()]
    self:_syncStates()
    return removed
end

function Manager:getContextStack()
    return deepCopy(self.contextStack)
end

function Manager:exportBindings()
    return {
        contexts = deepCopy(self.contexts),
        contextStack = deepCopy(self.contextStack)
    }
end

function Manager:importBindings(profile, replace)
    assert(type(profile) == "table", "Binding profile must be a table")

    local incomingContexts = profile.contexts
    if type(incomingContexts) ~= "table" then
        incomingContexts = {default = {}}
    end

    if replace == nil or replace == true then
        self.contexts = {}
    end

    for contextName, contextBindings in pairs(incomingContexts) do
        self.contexts[contextName] = deepCopy(contextBindings)
    end

    if not next(self.contexts) then
        self.contexts.default = {}
    end

    local incomingStack = profile.contextStack
    local stack = {}
    if type(incomingStack) == "table" and #incomingStack > 0 then
        for _, contextName in ipairs(incomingStack) do
            if type(contextName) == "string" and #contextName > 0 then
                self:_ensureContext(contextName)
                stack[#stack + 1] = contextName
            end
        end
    end

    if #stack == 0 then
        stack = {"default"}
        self:_ensureContext("default")
    end

    self.contextStack = stack
    self.bindings = self.contexts[self:_activeContextName()]
    self:_syncStates()
    return self
end

function Manager:setAdapter(adapter)
    self.adapter = adapter
    return self
end

function Manager:bind(action, bindingSpec)
    local context = self:_ensureContext(self:_activeContextName())
    context[action] = normalizeBindings(bindingSpec)
    self.bindings = context

    if not self.current[action] then
        self.current[action] = {down = false, value = 0}
    end
    if not self.previous[action] then
        self.previous[action] = {down = false, value = 0}
    end
    return self
end

function Manager:unbind(action)
    local context = self:_ensureContext(self:_activeContextName())
    context[action] = nil
    if context == self.bindings then
        self.bindings[action] = nil
    end
    self:_syncStates()
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
    self.previous = {}
    for action, state in pairs(self.current) do
        self.previous[action] = cloneActionState(state)
    end

    local activeBindings = self:_syncStates()
    for action, bindings in pairs(activeBindings) do
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

function Manager:captureFrame()
    return {
        actions = deepCopy(self.current),
        contextStack = deepCopy(self.contextStack),
    }
end

function Manager:applyRecordedFrame(frame)
    assert(type(frame) == "table", "Recorded frame must be a table")

    local restoredStack = {}
    if type(frame.contextStack) == "table" and #frame.contextStack > 0 then
        for _, contextName in ipairs(frame.contextStack) do
            if type(contextName) == "string" and #contextName > 0 then
                self:_ensureContext(contextName)
                restoredStack[#restoredStack + 1] = contextName
            end
        end
    end

    if #restoredStack > 0 then
        self.contextStack = restoredStack
        self.bindings = self.contexts[self:_activeContextName()]
    end

    self.previous = {}
    for action, state in pairs(self.current) do
        self.previous[action] = cloneActionState(state)
    end

    self.current = {}
    for action, state in pairs(frame.actions or {}) do
        self.current[action] = cloneActionState(state)
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

function input.setContext(...)
    return defaultManager:setContext(...)
end

function input.pushContext(...)
    return defaultManager:pushContext(...)
end

function input.popContext(...)
    return defaultManager:popContext(...)
end

function input.getContextStack(...)
    return defaultManager:getContextStack(...)
end

function input.exportBindings(...)
    return defaultManager:exportBindings(...)
end

function input.importBindings(...)
    return defaultManager:importBindings(...)
end

function input.update(...)
    return defaultManager:update(...)
end

function input.captureFrame(...)
    return defaultManager:captureFrame(...)
end

function input.applyRecordedFrame(...)
    return defaultManager:applyRecordedFrame(...)
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
