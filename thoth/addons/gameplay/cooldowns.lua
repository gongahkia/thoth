local cooldowns = {}

local Manager = {}
Manager.__index = Manager

local function normalizeNumber(value, fieldName)
    assert(type(value) == "number", fieldName .. " must be a number")
    return value
end

function Manager.new(snapshot)
    local self = setmetatable({}, Manager)
    self.entries = {}

    if snapshot then
        self:restore(snapshot)
    end

    return self
end

function Manager:start(name, duration)
    assert(type(name) == "string" and #name > 0, "Cooldown name must be a non-empty string")
    duration = normalizeNumber(duration, "duration")
    assert(duration >= 0, "duration must be >= 0")

    if duration == 0 then
        self.entries[name] = nil
        return 0
    end

    self.entries[name] = duration
    return duration
end

function Manager:ready(name)
    return self:remaining(name) == 0
end

function Manager:remaining(name)
    return self.entries[name] or 0
end

function Manager:clear(name)
    local existed = self.entries[name] ~= nil
    self.entries[name] = nil
    return existed
end

function Manager:update(dt)
    dt = normalizeNumber(dt, "dt")
    assert(dt >= 0, "dt must be >= 0")

    for name, remaining in pairs(self.entries) do
        remaining = remaining - dt
        if remaining <= 0 then
            self.entries[name] = nil
        else
            self.entries[name] = remaining
        end
    end

    return self
end

function Manager:snapshot()
    local snapshot = {}
    for name, remaining in pairs(self.entries) do
        snapshot[name] = remaining
    end
    return snapshot
end

function Manager:restore(snapshot)
    assert(type(snapshot) == "table", "Cooldown snapshot must be a table")

    self.entries = {}
    for name, remaining in pairs(snapshot) do
        remaining = normalizeNumber(remaining, "remaining")
        if remaining > 0 then
            self.entries[name] = remaining
        end
    end

    return self
end

cooldowns.Manager = Manager

function cooldowns.new(snapshot)
    return Manager.new(snapshot)
end

return cooldowns
