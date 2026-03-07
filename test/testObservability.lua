local runtimeModule = require("thoth.game.runtime")
local contract = require("thoth.adapters.contract")
local tween = require("thoth.game.tween")

local runtime = runtimeModule.new(contract.nullAdapter(), {
    fixedDelta = 0.1,
    maxFrameDelta = 1,
    traceLimit = 32,
    metricsHistoryLimit = 8,
})

local taskRuns = 0
runtime.tasks:after(0.1, function()
    taskRuns = taskRuns + 1
end, "once")

runtime.timeline:addTimer(tween.newTimer(0.1, function()
end, 1))

runtime:registerSystem({
    name = "observe",
    fixedUpdate = function() end,
    update = function() end,
    draw = function() end,
})

local inspectedTasks = runtime:inspectTasks()
assert(#inspectedTasks == 1, "Task inspection should expose active scheduled tasks")
assert(inspectedTasks[1].name == "once")

runtime:update(0.1)
runtime:dispatchInput("keypressed", "space")
runtime:draw()

assert(taskRuns == 1, "Scheduled task should still execute normally")

local metrics = runtime:getMetrics()
assert(metrics.lastFrame ~= nil, "Runtime metrics should expose the last frame summary")
assert(metrics.lastFrame.systems.observe ~= nil, "Per-system metrics should include named systems")
assert(metrics.lastFrame.systems.observe.fixed >= 0)
assert(metrics.lastFrame.systems.observe.update >= 0)
assert(metrics.lastFrame.systems.observe.draw >= 0)
assert(#metrics.history >= 1, "Metrics history should retain recent frames")

local trace = runtime:getTrace()
assert(#trace >= 1, "Trace log should collect runtime events")

local seenUpdateStart = false
local seenTaskComplete = false
local seenTimerComplete = false
local seenInputDispatch = false
for _, entry in ipairs(trace) do
    if entry.event == "update.start" then
        seenUpdateStart = true
    elseif entry.event == "tasks.complete" then
        seenTaskComplete = true
    elseif entry.event == "timeline.timer_complete" then
        seenTimerComplete = true
    elseif entry.event == "input.dispatch" then
        seenInputDispatch = true
    end
end

assert(seenUpdateStart, "Trace log should include frame boundaries")
assert(seenTaskComplete, "Trace log should include task completion events")
assert(seenTimerComplete, "Trace log should include timeline completion events")
assert(seenInputDispatch, "Trace log should include dispatched input events")

local lines = runtime:getDebugHudLines()
assert(#lines >= 3, "Debug HUD lines should summarize runtime state")

local drawn = {}
assert(runtime:drawDebugHud(function(text, x, y)
    drawn[#drawn + 1] = {text = text, x = x, y = y}
end, 4, 6, 10))
assert(#drawn == #lines, "Debug HUD renderer should receive one call per line")

runtime:clearTrace()
assert(#runtime:getTrace() == 0, "Trace log should be clearable")
