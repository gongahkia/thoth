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

function frame.new(options)
    return Scheduler.new(options)
end

return frame
