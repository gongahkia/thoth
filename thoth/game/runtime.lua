local frame = require("thoth.game.frame")
local serialize = require("thoth.core.serialize")
local inputModule = require("thoth.game.input")
local randomModule = require("thoth.game.random")
local stateModule = require("thoth.game.state")
local tweenModule = require("thoth.game.tween")
local tasksModule = require("thoth.game.tasks")
local contract = require("thoth.adapters.contract")

local runtime = {}

local Runtime = {}
Runtime.__index = Runtime

local function shallowCopy(tbl)
    local copy = {}
    for key, value in pairs(tbl) do
        copy[key] = value
    end
    return copy
end

local function normalizeRecording(recording)
    assert(type(recording) == "table", "Recording must be a table")
    assert(type(recording.frames) == "table", "Recording must include a frames array")
    return recording
end

local function callSnapshotHook(target, runtime)
    if target and type(target.snapshot) == "function" then
        return target:snapshot(runtime)
    end
    return nil
end

local function callRestoreHook(target, runtime, snapshot)
    if target and snapshot ~= nil and type(target.restore) == "function" then
        target:restore(runtime, snapshot)
    end
end

local function sortSystems(systems)
    table.sort(systems, function(a, b)
        local pa = a.priority or 0
        local pb = b.priority or 0
        if pa == pb then
            return (a.name or "") < (b.name or "")
        end
        return pa < pb
    end)
end

function Runtime.new(adapter, options)
    options = options or {}
    if adapter == nil then
        adapter = contract.nullAdapter()
    end
    contract.assertValid(adapter)

    local self = setmetatable({}, Runtime)
    self.adapter = adapter
    self.scheduler = frame.new(options)
    self.systems = {}
    self.input = inputModule.new(adapter)
    self.random = randomModule.new(options.seed)
    self.state = stateModule.new()
    self.timeline = tweenModule.newTimeline()
    self.tasks = tasksModule.new()
    self.context = options.context or {}
    self.frameInfo = {
        index = 0,
        time = 0,
        fixedIndex = 0,
        fixedTime = 0,
        lastDelta = 0,
        fixedDelta = self.scheduler.fixedDelta,
        fixedStepsLastFrame = 0,
        alpha = 0,
    }
    self.recording = nil
    self.replay = nil
    self.traceLimit = options.traceLimit or 64
    self.metricsHistoryLimit = options.metricsHistoryLimit or 32
    self.traceLog = {}
    self.metrics = {
        lastFrame = nil,
        history = {},
    }

    self.tasks:setObserver(function(eventName, data)
        self:_trace("tasks." .. eventName, data)
    end)
    self.timeline:setObserver(function(eventName, data)
        self:_trace("timeline." .. eventName, data)
    end)
    return self
end

function Runtime:getFrameInfo()
    return shallowCopy(self.frameInfo)
end

function Runtime:getSeed()
    return self.random:getInitialSeed()
end

function Runtime:setSeed(seed)
    return self.random:setSeed(seed)
end

function Runtime:randomNumber(min, max)
    return self.random:random(min, max)
end

function Runtime:randomChoice(values)
    return self.random:choice(values)
end

function Runtime:_trace(eventName, data)
    self.traceLog[#self.traceLog + 1] = {
        frame = self.frameInfo.index,
        event = eventName,
        data = serialize.deepCopy(data or {}),
    }

    if #self.traceLog > self.traceLimit then
        table.remove(self.traceLog, 1)
    end
end

function Runtime:_recordFrameMetrics(metrics)
    self.metrics.lastFrame = metrics
    self.metrics.history[#self.metrics.history + 1] = metrics
    if #self.metrics.history > self.metricsHistoryLimit then
        table.remove(self.metrics.history, 1)
    end
end

function Runtime:getMetrics()
    return serialize.deepCopy(self.metrics)
end

function Runtime:getTrace()
    return serialize.deepCopy(self.traceLog)
end

function Runtime:clearTrace()
    self.traceLog = {}
end

function Runtime:inspectTasks()
    return self.tasks:inspect()
end

function Runtime:inspectTimeline()
    return self.timeline:inspect()
end

function Runtime:getDebugHudLines()
    local frameInfo = self.frameInfo
    local metrics = self.metrics.lastFrame or {
        systems = {},
        input = 0,
        tasks = 0,
        timeline = 0,
        state = 0,
        total = 0,
    }
    local timeline = self:inspectTimeline()
    local lines = {
        string.format("frame=%d fixed=%d steps=%d alpha=%.3f dt=%.4f", frameInfo.index, frameInfo.fixedIndex, frameInfo.fixedStepsLastFrame, frameInfo.alpha, frameInfo.lastDelta),
        string.format("input=%.3fms tasks=%.3fms timeline=%.3fms state=%.3fms total=%.3fms", metrics.input * 1000, metrics.tasks * 1000, metrics.timeline * 1000, metrics.state * 1000, metrics.total * 1000),
        string.format("active_tasks=%d active_tweens=%d active_timers=%d trace=%d", #self:inspectTasks(), #timeline.tweens, #timeline.timers, #self.traceLog),
    }

    local names = {}
    for name in pairs(metrics.systems or {}) do
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local item = metrics.systems[name]
        lines[#lines + 1] = string.format("%s fixed=%.3fms update=%.3fms draw=%.3fms",
            name,
            (item.fixed or 0) * 1000,
            (item.update or 0) * 1000,
            (item.draw or 0) * 1000)
    end

    return lines
end

function Runtime:drawDebugHud(drawText, x, y, lineHeight)
    local lines = self:getDebugHudLines()
    x = x or 8
    y = y or 8
    lineHeight = lineHeight or 14

    if type(drawText) == "function" then
        for i, line in ipairs(lines) do
            drawText(line, x, y + ((i - 1) * lineHeight))
        end
        return true
    end

    if contract.supports(self.adapter, "debugDraw") and type(self.adapter.debugDraw) == "function" then
        for i, line in ipairs(lines) do
            self.adapter:debugDraw("text", line, x, y + ((i - 1) * lineHeight))
        end
        return true
    end

    return false
end

function Runtime:startRecording(metadata)
    self.replay = nil
    self.recording = {
        version = 1,
        seed = self:getSeed(),
        fixedDelta = self.scheduler.fixedDelta,
        metadata = serialize.deepCopy(metadata or {}),
        frames = {},
    }
    return self:getRecording()
end

function Runtime:isRecording()
    return self.recording ~= nil
end

function Runtime:getRecording()
    if not self.recording then
        return nil
    end
    return serialize.deepCopy(self.recording)
end

function Runtime:stopRecording()
    local recording = self:getRecording()
    self.recording = nil
    return recording
end

function Runtime:loadReplay(recording, options)
    options = options or {}
    recording = normalizeRecording(serialize.deepCopy(recording))
    self.recording = nil
    self.replay = {
        recording = recording,
        cursor = 1,
    }
    if recording.seed ~= nil and options.restoreSeed ~= false then
        self:setSeed(recording.seed)
    end
    if type(recording.fixedDelta) == "number" and recording.fixedDelta > 0 then
        self.scheduler.fixedDelta = recording.fixedDelta
        self.frameInfo.fixedDelta = recording.fixedDelta
    end
    return self
end

function Runtime:isReplaying()
    return self.replay ~= nil
end

function Runtime:getReplayCursor()
    if not self.replay then
        return nil
    end
    return self.replay.cursor
end

function Runtime:stopReplay()
    local replay = self.replay and serialize.deepCopy(self.replay.recording) or nil
    self.replay = nil
    return replay
end

function Runtime:snapshot()
    local systemSnapshots = {}
    local taskSnapshot = callSnapshotHook(self.tasks, self)
    local timelineSnapshot = callSnapshotHook(self.timeline, self)

    for index, system in ipairs(self.systems) do
        if type(system.snapshot) == "function" then
            local key = system.name or tostring(index)
            systemSnapshots[key] = system:snapshot(self)
        end
    end

    return {
        version = 1,
        seed = self:getSeed(),
        random = self.random:getState(),
        frameInfo = shallowCopy(self.frameInfo),
        scheduler = self.scheduler:getState(),
        context = serialize.deepCopy(self.context),
        input = self.input:snapshot(),
        state = self.state:snapshot(),
        systems = systemSnapshots,
        services = {
            tasks = taskSnapshot,
            timeline = timelineSnapshot,
        },
    }
end

function Runtime:restore(snapshot)
    assert(type(snapshot) == "table", "Runtime snapshot must be a table")

    if snapshot.random then
        self.random:setState(snapshot.random)
    elseif snapshot.seed ~= nil then
        self:setSeed(snapshot.seed)
    end

    if snapshot.scheduler then
        self.scheduler:setState(snapshot.scheduler)
    end

    if snapshot.frameInfo then
        self.frameInfo = shallowCopy(snapshot.frameInfo)
    else
        self.frameInfo.fixedDelta = self.scheduler.fixedDelta
    end
    self.frameInfo.fixedDelta = self.scheduler.fixedDelta

    self.context = serialize.deepCopy(snapshot.context or {})

    if snapshot.input then
        self.input:restore(snapshot.input)
    end

    if snapshot.state then
        self.state:restore(snapshot.state)
    end

    for index, system in ipairs(self.systems) do
        local key = system.name or tostring(index)
        if snapshot.systems and snapshot.systems[key] ~= nil and type(system.restore) == "function" then
            system:restore(self, snapshot.systems[key])
        end
    end

    if snapshot.services then
        callRestoreHook(self.tasks, self, snapshot.services.tasks)
        callRestoreHook(self.timeline, self, snapshot.services.timeline)
    end

    return self
end

function Runtime:saveSnapshot(filename, snapshot, varName)
    return serialize.saveLua(filename, snapshot or self:snapshot(), varName or "snapshot")
end

function Runtime:loadSnapshot(filename, env)
    local snapshot, err = serialize.loadLuaSafe(filename, env)
    if not snapshot then
        return nil, err
    end
    self:restore(snapshot)
    return snapshot
end

function Runtime:rollback(snapshot, recording, fromFrame)
    self:restore(snapshot)

    if recording then
        local replay = normalizeRecording(serialize.deepCopy(recording))
        local startFrame = fromFrame
        if startFrame == nil and snapshot.frameInfo and snapshot.frameInfo.index then
            startFrame = snapshot.frameInfo.index + 1
        end

        if startFrame then
            local slicedFrames = {}
            for i = startFrame, #replay.frames do
                slicedFrames[#slicedFrames + 1] = replay.frames[i]
            end
            replay.frames = slicedFrames
        end

        self:loadReplay(replay, {
            restoreSeed = not (startFrame and startFrame > 1),
        })
    end

    return self
end

function Runtime:registerSystem(system)
    assert(type(system) == "table", "System must be a table")
    assert(type(system.update) == "function" or type(system.fixedUpdate) == "function" or type(system.draw) == "function",
        "System must provide at least one of: update, fixedUpdate, draw")
    if system.enabled == nil then
        system.enabled = true
    end
    table.insert(self.systems, system)
    sortSystems(self.systems)
    return system
end

function Runtime:enableSystem(name, enabled)
    local system = self:getSystem(name)
    if not system then
        return false
    end
    system.enabled = enabled ~= false
    return true
end

function Runtime:removeSystem(name)
    for i, system in ipairs(self.systems) do
        if system.name == name then
            table.remove(self.systems, i)
            return true
        end
    end
    return false
end

function Runtime:getSystem(name)
    for _, system in ipairs(self.systems) do
        if system.name == name then
            return system
        end
    end
    return nil
end

function Runtime:update(dt)
    local replayFrame = nil
    if self.replay then
        replayFrame = self.replay.recording.frames[self.replay.cursor]
        if not replayFrame then
            self.replay = nil
            return false
        end
        if dt == nil then
            dt = replayFrame.dt
        end
    end

    if dt == nil and self.adapter and type(self.adapter.delta) == "function" then
        dt = self.adapter:delta()
    end
    dt = dt or self.scheduler.fixedDelta
    local frameStart = os.clock()
    local metrics = {
        dt = dt,
        systems = {},
        input = 0,
        tasks = 0,
        timeline = 0,
        state = 0,
        total = 0,
    }
    self.frameInfo.index = self.frameInfo.index + 1
    self.frameInfo.lastDelta = dt
    self.frameInfo.time = self.frameInfo.time + dt
    self.frameInfo.fixedDelta = self.scheduler.fixedDelta
    self:_trace("update.start", {
        dt = dt,
        replay = replayFrame ~= nil,
    })

    local inputStart = os.clock()
    if replayFrame then
        self.input:applyRecordedFrame(replayFrame.input or {})
    else
        self.input:update()
        if self.recording then
            self.recording.frames[#self.recording.frames + 1] = {
                dt = dt,
                input = self.input:captureFrame(),
            }
        end
    end
    metrics.input = os.clock() - inputStart

    local tasksStart = os.clock()
    self.tasks:update(dt)
    metrics.tasks = os.clock() - tasksStart

    local timelineStart = os.clock()
    self.timeline:update(dt)
    metrics.timeline = os.clock() - timelineStart

    local stateStart = os.clock()
    self.state:update(dt)
    metrics.state = os.clock() - stateStart

    local steps, alpha = self.scheduler:advance(dt, function(stepDt, stepIndex)
        self:_trace("fixed_step", {
            dt = stepDt,
            index = stepIndex,
        })
        self.frameInfo.fixedIndex = self.frameInfo.fixedIndex + 1
        self.frameInfo.fixedTime = self.frameInfo.fixedTime + stepDt
        for _, system in ipairs(self.systems) do
            if system.enabled ~= false and type(system.fixedUpdate) == "function" then
                local name = system.name or "<anonymous>"
                metrics.systems[name] = metrics.systems[name] or {fixed = 0, update = 0, draw = 0}
                local started = os.clock()
                system.fixedUpdate(self, stepDt, stepIndex)
                metrics.systems[name].fixed = metrics.systems[name].fixed + (os.clock() - started)
            end
        end
    end)
    self.frameInfo.fixedStepsLastFrame = steps
    self.frameInfo.alpha = alpha

    for _, system in ipairs(self.systems) do
        if system.enabled ~= false and type(system.update) == "function" then
            local name = system.name or "<anonymous>"
            metrics.systems[name] = metrics.systems[name] or {fixed = 0, update = 0, draw = 0}
            local started = os.clock()
            system.update(self, dt)
            metrics.systems[name].update = metrics.systems[name].update + (os.clock() - started)
        end
    end

    if self.replay then
        self.replay.cursor = self.replay.cursor + 1
        if self.replay.cursor > #self.replay.recording.frames then
            self.replay = nil
        end
    end

    metrics.total = os.clock() - frameStart
    self:_recordFrameMetrics(metrics)
    self:_trace("update.end", {
        dt = dt,
        fixedSteps = steps,
    })
end

function Runtime:draw(...)
    local drawMetrics = self.metrics.lastFrame
    self.state:draw(...)
    for _, system in ipairs(self.systems) do
        if system.enabled ~= false and type(system.draw) == "function" then
            if drawMetrics then
                local name = system.name or "<anonymous>"
                drawMetrics.systems[name] = drawMetrics.systems[name] or {fixed = 0, update = 0, draw = 0}
                local started = os.clock()
                system.draw(self, ...)
                drawMetrics.systems[name].draw = drawMetrics.systems[name].draw + (os.clock() - started)
            else
                system.draw(self, ...)
            end
        end
    end
end

function Runtime:dispatchInput(eventName, ...)
    self:_trace("input.dispatch", {
        event = eventName,
    })
    for _, system in ipairs(self.systems) do
        if system.enabled ~= false and type(system.onInput) == "function" then
            system.onInput(self, eventName, ...)
        end
    end
    self.state:dispatch(eventName, ...)
end

function Runtime:attachLifecycle(options)
    if not contract.supports(self.adapter, "lifecycle") then
        return nil
    end
    return self.adapter:registerLifecycle(self, options or {})
end

runtime.Runtime = Runtime

function runtime.new(adapter, options)
    return Runtime.new(adapter, options)
end

return runtime
