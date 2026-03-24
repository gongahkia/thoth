local status = {}

local Manager = {}
Manager.__index = Manager

local function cloneTags(tags)
    local out = {}
    for i, tag in ipairs(tags or {}) do
        assert(type(tag) == "string" and #tag > 0, "Status tags must be non-empty strings")
        out[i] = tag
    end
    table.sort(out)
    return out
end

local function cloneEntry(entry)
    if not entry then
        return nil
    end
    return {
        remaining = entry.remaining,
        stacks = entry.stacks,
        tags = cloneTags(entry.tags),
    }
end

function Manager.new(snapshot)
    local self = setmetatable({}, Manager)
    self.entries = {}

    if snapshot then
        self:restore(snapshot)
    end

    return self
end

function Manager:apply(name, duration, options)
    assert(type(name) == "string" and #name > 0, "Status name must be a non-empty string")
    assert(type(duration) == "number" and duration >= 0, "duration must be a number >= 0")

    options = options or {}
    local stackDelta = options.stacks or 1
    assert(type(stackDelta) == "number" and stackDelta >= 0, "stacks must be a number >= 0")

    local maxStacks = options.maxStacks or math.huge
    assert(type(maxStacks) == "number" and maxStacks >= 1, "maxStacks must be a number >= 1")

    local entry = self.entries[name]
    if not entry then
        entry = {
            remaining = 0,
            stacks = 0,
            tags = {},
        }
        self.entries[name] = entry
    end

    entry.remaining = duration
    entry.stacks = math.min(maxStacks, entry.stacks + stackDelta)
    entry.tags = cloneTags(options.tags or entry.tags)

    if entry.remaining <= 0 then
        self.entries[name] = nil
        return nil
    end

    return cloneEntry(entry)
end

function Manager:has(name)
    return self.entries[name] ~= nil
end

function Manager:get(name)
    return cloneEntry(self.entries[name])
end

function Manager:stacks(name)
    local entry = self.entries[name]
    return entry and entry.stacks or 0
end

function Manager:findByTag(tag)
    assert(type(tag) == "string" and #tag > 0, "Tag must be a non-empty string")

    local matches = {}
    for name, entry in pairs(self.entries) do
        for _, item in ipairs(entry.tags) do
            if item == tag then
                matches[#matches + 1] = name
                break
            end
        end
    end

    table.sort(matches)
    return matches
end

function Manager:clear(name)
    local existed = self.entries[name] ~= nil
    self.entries[name] = nil
    return existed
end

function Manager:update(dt)
    assert(type(dt) == "number" and dt >= 0, "dt must be a number >= 0")

    for name, entry in pairs(self.entries) do
        entry.remaining = entry.remaining - dt
        if entry.remaining <= 0 then
            self.entries[name] = nil
        end
    end

    return self
end

function Manager:snapshot()
    local snapshot = {}
    for name, entry in pairs(self.entries) do
        snapshot[name] = cloneEntry(entry)
    end
    return snapshot
end

function Manager:restore(snapshot)
    assert(type(snapshot) == "table", "Status snapshot must be a table")

    self.entries = {}
    for name, entry in pairs(snapshot) do
        if type(entry) == "table" and type(entry.remaining) == "number" and entry.remaining > 0 then
            self.entries[name] = {
                remaining = entry.remaining,
                stacks = tonumber(entry.stacks) or 1,
                tags = cloneTags(entry.tags),
            }
        end
    end

    return self
end

status.Manager = Manager

function status.new(snapshot)
    return Manager.new(snapshot)
end

return status
