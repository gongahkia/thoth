local state = {}

local Manager = {}
Manager.__index = Manager

function Manager.new()
    local self = setmetatable({}, Manager)
    self.states = {}
    self.current = nil
    self.stack = {}
    return self
end

local function resolveState(nameOrState, maybeState)
    if type(nameOrState) == "table" and maybeState == nil then
        assert(nameOrState.name, "State table must include a 'name' field")
        return nameOrState.name, nameOrState
    end
    return nameOrState, maybeState
end

function Manager:add(nameOrState, maybeState)
    local name, resolved = resolveState(nameOrState, maybeState)
    assert(type(name) == "string", "State name must be a string")
    assert(type(resolved) == "table", "State must be a table")
    resolved.name = resolved.name or name
    self.states[name] = resolved
    return self
end

function Manager:get(name)
    return self.states[name]
end

function Manager:getCurrent()
    return self.current
end

function Manager:switch(name, ...)
    local nextState = self.states[name]
    assert(nextState, "State '" .. tostring(name) .. "' not found")

    local previous = self.current
    if previous and type(previous.exit) == "function" then
        previous:exit(nextState, ...)
    end

    self.current = nextState
    if type(nextState.enter) == "function" then
        nextState:enter(previous, ...)
    end
    return self.current
end

function Manager:push(name, ...)
    local nextState = self.states[name]
    assert(nextState, "State '" .. tostring(name) .. "' not found")

    if self.current then
        table.insert(self.stack, self.current)
        if type(self.current.exit) == "function" then
            self.current:exit(nextState, ...)
        end
    end

    local previous = self.current
    self.current = nextState
    if type(nextState.enter) == "function" then
        nextState:enter(previous, ...)
    end
    return self.current
end

function Manager:pop(...)
    if #self.stack == 0 then
        return nil
    end

    local previous = table.remove(self.stack)
    if self.current and type(self.current.exit) == "function" then
        self.current:exit(previous, ...)
    end

    self.current = previous
    if self.current and type(self.current.enter) == "function" then
        self.current:enter(nil, ...)
    end
    return self.current
end

function Manager:update(dt)
    if self.current and type(self.current.update) == "function" then
        self.current:update(dt)
    end
end

function Manager:draw(...)
    if self.current and type(self.current.draw) == "function" then
        self.current:draw(...)
    end
end

function Manager:dispatch(eventName, ...)
    if not self.current then
        return
    end

    local fn = self.current[eventName]
    if type(fn) == "function" then
        return fn(self.current, ...)
    end

    if type(self.current.onEvent) == "function" then
        return self.current:onEvent(eventName, ...)
    end
end

function Manager:snapshot()
    local snapshot = {
        current = self.current and self.current.name or nil,
        stack = {},
        states = {},
    }

    for i, stateEntry in ipairs(self.stack) do
        snapshot.stack[i] = stateEntry.name
    end

    for name, stateEntry in pairs(self.states) do
        if type(stateEntry.snapshot) == "function" then
            snapshot.states[name] = stateEntry:snapshot(self)
        end
    end

    return snapshot
end

function Manager:restore(snapshot)
    assert(type(snapshot) == "table", "State snapshot must be a table")

    for name, stateData in pairs(snapshot.states or {}) do
        local stateEntry = self.states[name]
        if stateEntry and type(stateEntry.restore) == "function" then
            stateEntry:restore(self, stateData)
        end
    end

    self.stack = {}
    for _, stateName in ipairs(snapshot.stack or {}) do
        local stateEntry = self.states[stateName]
        if stateEntry then
            self.stack[#self.stack + 1] = stateEntry
        end
    end

    self.current = nil
    if snapshot.current ~= nil then
        self.current = self.states[snapshot.current]
        assert(self.current, "State '" .. tostring(snapshot.current) .. "' not found during restore")
    end

    return self.current
end

state.Manager = Manager

function state.new()
    return Manager.new()
end

return state
