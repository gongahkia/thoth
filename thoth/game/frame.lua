local frame = {}

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new(options)
    options = options or {}
    local self = setmetatable({}, Scheduler)
    self.fixedDelta = options.fixedDelta or (1 / 60)
    self.maxSubsteps = options.maxSubsteps or 8
    self.maxFrameDelta = options.maxFrameDelta or 0.25
    self.accumulator = 0
    self.alpha = 0
    return self
end

function Scheduler:advance(dt, onFixedStep)
    dt = dt or self.fixedDelta
    if dt < 0 then
        dt = 0
    end
    if dt > self.maxFrameDelta then
        dt = self.maxFrameDelta
    end

    self.accumulator = self.accumulator + dt
    local steps = 0
    while self.accumulator >= self.fixedDelta and steps < self.maxSubsteps do
        steps = steps + 1
        self.accumulator = self.accumulator - self.fixedDelta
        if onFixedStep then
            onFixedStep(self.fixedDelta, steps)
        end
    end

    self.alpha = self.accumulator / self.fixedDelta
    return steps, self.alpha
end

function Scheduler:reset()
    self.accumulator = 0
    self.alpha = 0
end

function Scheduler:getState()
    return {
        fixedDelta = self.fixedDelta,
        maxSubsteps = self.maxSubsteps,
        maxFrameDelta = self.maxFrameDelta,
        accumulator = self.accumulator,
        alpha = self.alpha,
    }
end

function Scheduler:setState(state)
    assert(type(state) == "table", "Scheduler state must be a table")
    if type(state.fixedDelta) == "number" and state.fixedDelta > 0 then
        self.fixedDelta = state.fixedDelta
    end
    if type(state.maxSubsteps) == "number" and state.maxSubsteps > 0 then
        self.maxSubsteps = state.maxSubsteps
    end
    if type(state.maxFrameDelta) == "number" and state.maxFrameDelta > 0 then
        self.maxFrameDelta = state.maxFrameDelta
    end
    self.accumulator = tonumber(state.accumulator) or 0
    self.alpha = tonumber(state.alpha) or 0
    return self
end

function frame.new(options)
    return Scheduler.new(options)
end

return frame
