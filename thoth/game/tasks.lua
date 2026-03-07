local tasks = {}

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    local self = setmetatable({}, Scheduler)
    self.time = 0
    self.nextId = 1
    self.tasks = {}
    self.observer = nil
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

    local ok, yielded = coroutine.resume(co, ...)
    if not ok then
        error("Task '" .. tostring(name or id) .. "' failed during spawn: " .. tostring(yielded))
    end

    if coroutine.status(co) ~= "dead" then
        local waitTime = tonumber(yielded) or 0
        local task = makeTask(id, name, co, self.time + math.max(0, waitTime))
        self.tasks[id] = task
        if self.observer then
            self.observer("spawn", {
                id = task.id,
                name = task.name,
                wakeTime = task.wakeTime,
            })
        end
    end
    return id
end

function Scheduler:cancel(id)
    local task = self.tasks[id]
    if task then
        task.cancelled = true
        if self.observer then
            self.observer("cancel", {
                id = task.id,
                name = task.name,
            })
        end
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
            if self.observer then
                self.observer("resume", {
                    id = task.id,
                    name = task.name,
                    time = self.time,
                })
            end
            local ok, yielded = coroutine.resume(task.coroutine)

            if not ok then
                error("Task '" .. task.name .. "' failed: " .. tostring(yielded))
            end

            if coroutine.status(task.coroutine) == "dead" then
                self.tasks[id] = nil
                if self.observer then
                    self.observer("complete", {
                        id = task.id,
                        name = task.name,
                    })
                end
            else
                local waitTime = tonumber(yielded) or 0
                task.wakeTime = self.time + math.max(0, waitTime)
                if self.observer then
                    self.observer("yield", {
                        id = task.id,
                        name = task.name,
                        wakeTime = task.wakeTime,
                    })
                end
            end
        end
    end
end

function Scheduler:setObserver(observer)
    self.observer = observer
    return self
end

function Scheduler:inspect()
    local tasks = {}
    for _, task in pairs(self.tasks) do
        tasks[#tasks + 1] = {
            id = task.id,
            name = task.name,
            wakeTime = task.wakeTime,
            remaining = math.max(0, task.wakeTime - self.time),
            cancelled = task.cancelled == true,
        }
    end
    table.sort(tasks, function(a, b)
        return a.id < b.id
    end)
    return tasks
end

tasks.Scheduler = Scheduler

function tasks.new()
    return Scheduler.new()
end

return tasks
