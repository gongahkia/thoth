local serialize = require("thoth.core.serialize")

local commands = {}

local Manager = {}
Manager.__index = Manager

local function sortedIds(queue)
    local ids = {}
    for id in pairs(queue) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    return ids
end

function Manager.new(handlers)
    local self = setmetatable({}, Manager)
    self.handlers = handlers or {}
    self.queue = {}
    self.nextId = 1
    return self
end

function Manager:register(name, handler)
    assert(type(name) == "string" and #name > 0, "Command name must be a non-empty string")
    assert(type(handler) == "function", "Command handler must be a function")
    self.handlers[name] = handler
    return self
end

function Manager:schedule(name, delay, payload)
    assert(type(name) == "string" and #name > 0, "Command name must be a non-empty string")
    assert(type(delay) == "number" and delay >= 0, "delay must be a number >= 0")

    local id = self.nextId
    self.nextId = self.nextId + 1
    self.queue[id] = {
        id = id,
        name = name,
        remaining = delay,
        payload = serialize.deepCopy(payload),
    }
    return id
end

function Manager:enqueue(name, payload)
    return self:schedule(name, 0, payload)
end

function Manager:cancel(id)
    local existed = self.queue[id] ~= nil
    self.queue[id] = nil
    return existed
end

function Manager:inspect()
    local items = {}
    for _, id in ipairs(sortedIds(self.queue)) do
        local entry = self.queue[id]
        items[#items + 1] = {
            id = entry.id,
            name = entry.name,
            remaining = entry.remaining,
            payload = serialize.deepCopy(entry.payload),
        }
    end
    return items
end

function Manager:update(dt, context)
    assert(type(dt) == "number" and dt >= 0, "dt must be a number >= 0")

    local ready = {}
    for _, id in ipairs(sortedIds(self.queue)) do
        local entry = self.queue[id]
        entry.remaining = entry.remaining - dt
        if entry.remaining <= 0 then
            ready[#ready + 1] = entry
        end
    end

    local executed = {}
    for _, entry in ipairs(ready) do
        self.queue[entry.id] = nil
        local handler = assert(self.handlers[entry.name], "No handler registered for command '" .. entry.name .. "'")
        handler(serialize.deepCopy(entry.payload), context, {
            id = entry.id,
            name = entry.name,
        })
        executed[#executed + 1] = {
            id = entry.id,
            name = entry.name,
            payload = serialize.deepCopy(entry.payload),
        }
    end

    return executed
end

function Manager:snapshot()
    return {
        nextId = self.nextId,
        queue = self:inspect(),
    }
end

function Manager:restore(snapshot)
    assert(type(snapshot) == "table", "Command snapshot must be a table")

    self.nextId = tonumber(snapshot.nextId) or 1
    self.queue = {}

    for _, entry in ipairs(snapshot.queue or {}) do
        self.queue[entry.id] = {
            id = entry.id,
            name = entry.name,
            remaining = entry.remaining,
            payload = serialize.deepCopy(entry.payload),
        }
    end

    return self
end

commands.Manager = Manager

function commands.new(handlers)
    return Manager.new(handlers)
end

return commands
