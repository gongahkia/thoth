local tasks = {}

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    local self = setmetatable({}, Scheduler)
    self.time = 0
    self.nextId = 1
    self.tasks = {}
    return self
end

local function makeTask(id, name, co, wakeTime)
    return {
        id = id,
        name = name or ("task-" .. id),
        coroutine = co,
        wakeTime = wakeTime or 0,
        cancelled = false
    }
end

function Scheduler:spawn(fn, name, ...)
    assert(type(fn) == "function", "Task function must be callable")
    local co = coroutine.create(fn)
    local id = self.nextId
    self.nextId = self.nextId + 1
    local task = makeTask(id, name, co, self.time)
    task.args = {...}
    self.tasks[id] = task
    return id
end

function Scheduler:cancel(id)
    local task = self.tasks[id]
    if task then
        task.cancelled = true
    end
end

function Scheduler:after(delay, fn, name)
    return self:spawn(function()
        coroutine.yield(delay)
        fn()
    end, name or "after")
end

function Scheduler:every(interval, fn, name, maxRuns)
    return self:spawn(function()
        local runs = 0
        while true do
            coroutine.yield(interval)
            runs = runs + 1
            fn(runs)
            if maxRuns and runs >= maxRuns then
                return
            end
        end
    end, name or "every")
end

function Scheduler:count()
    local count = 0
    for _ in pairs(self.tasks) do
        count = count + 1
    end
    return count
end

function Scheduler:update(dt)
    self.time = self.time + (dt or 0)

    for id, task in pairs(self.tasks) do
        if task.cancelled then
            self.tasks[id] = nil
        elseif self.time >= task.wakeTime then
            local ok, yielded = coroutine.resume(task.coroutine, table.unpack(task.args or {}))
            task.args = nil

            if not ok then
                error("Task '" .. task.name .. "' failed: " .. tostring(yielded))
            end

            if coroutine.status(task.coroutine) == "dead" then
                self.tasks[id] = nil
            else
                local waitTime = tonumber(yielded) or 0
                task.wakeTime = self.time + math.max(0, waitTime)
            end
        end
    end
end

tasks.Scheduler = Scheduler

function tasks.new()
    return Scheduler.new()
end

return tasks
