local animation = {}

local Machine = {}
Machine.__index = Machine

function Machine.new(initialState)
    local self = setmetatable({}, Machine)
    self.states = {}
    self.transitions = {}
    self.current = nil
    self.timeInState = 0
    self.context = {}
    if initialState then
        self.initialState = initialState
    end
    return self
end

function Machine:addState(name, definition)
    self.states[name] = definition or {}
    if not self.current and self.initialState == nil then
        self.initialState = name
    end
    return self
end

function Machine:addTransition(fromState, toState, condition)
    self.transitions[#self.transitions + 1] = {
        fromState = fromState,
        toState = toState,
        condition = condition,
    }
    return self
end

function Machine:setState(name, context)
    assert(self.states[name], "Animation state '" .. tostring(name) .. "' not found")
    local previous = self.current and self.states[self.current] or nil
    if previous and type(previous.onExit) == "function" then
        previous.onExit(context or self.context, self.current, name)
    end

    self.current = name
    self.timeInState = 0

    local state = self.states[name]
    if type(state.onEnter) == "function" then
        state.onEnter(context or self.context, name)
    end
    return self.current
end

function Machine:getState()
    return self.current
end

function Machine:getTimeInState()
    return self.timeInState
end

function Machine:update(dt, context)
    context = context or self.context
    if not self.current then
        assert(self.initialState, "Animation machine has no initial state")
        self:setState(self.initialState, context)
    end

    dt = dt or 0
    self.timeInState = self.timeInState + dt

    local state = self.states[self.current]
    if type(state.onUpdate) == "function" then
        state.onUpdate(context, dt, self.current)
    end

    for _, transition in ipairs(self.transitions) do
        if transition.fromState == self.current and transition.condition(context, self.timeInState, self.current) then
            self:setState(transition.toState, context)
            break
        end
    end

    return self.current
end

animation.Machine = Machine

function animation.new(initialState)
    return Machine.new(initialState)
end

return animation
