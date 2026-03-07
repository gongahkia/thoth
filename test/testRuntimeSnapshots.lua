local runtimeModule = require("thoth.game.runtime")
local love2d = require("thoth.adapters.love2d")

local function newRuntime(seed)
    local adapter = love2d.new(nil)
    local runtime = runtimeModule.new(adapter, {
        fixedDelta = 0.1,
        maxFrameDelta = 1,
        seed = seed,
        context = {
            player = {x = 0},
        },
    })

    runtime.input:bind("move_x", {axis = {positive = "right", negative = "left"}})

    local system
    system = {
        name = "snapshot-system",
        total = 0,
        snapshot = function(self)
            return {total = self.total}
        end,
        restore = function(self, _runtime, snapshot)
            self.total = snapshot.total
        end,
        fixedUpdate = function(rt)
            system.total = system.total + rt:randomNumber(1, 5)
            rt.context.player.x = rt.context.player.x + rt.input:axis("move_x")
            local currentState = rt.state:getCurrent()
            currentState.phase = currentState.phase + 1
        end,
    }

    runtime:registerSystem(system)
    runtime.state:add("play", {
        name = "play",
        phase = 0,
        snapshot = function(self)
            return {phase = self.phase}
        end,
        restore = function(self, _manager, snapshot)
            self.phase = snapshot.phase
        end,
    })
    runtime.state:switch("play")

    return runtime, adapter, system
end

local runtime, adapter, system = newRuntime(55)

runtime:startRecording({label = "snapshot-rollback"})
runtime:update(0.1)

adapter.state.keys.right = true
runtime:update(0.1)

local snapshot = runtime:snapshot()
assert(snapshot.frameInfo.index == 2, "Snapshot should capture the frame index")
assert(snapshot.context.player.x == 1, "Snapshot should capture runtime context")
assert(snapshot.systems["snapshot-system"].total == system.total, "Snapshot should capture system hook state")
assert(snapshot.state.current == "play", "Snapshot should capture the active state")
assert(snapshot.state.states.play.phase == 2, "Snapshot should capture state hook data")

runtime:update(0.1)
adapter.state.keys.right = false
runtime:update(0.1)
local recording = runtime:stopRecording()

local expectedTotal = system.total
local expectedX = runtime.context.player.x
local expectedPhase = runtime.state:getCurrent().phase
local expectedFrame = runtime:getFrameInfo().index

runtime:rollback(snapshot, recording, snapshot.frameInfo.index + 1)
while runtime:isReplaying() do
    runtime:update()
end

assert(system.total == expectedTotal, "Rollback and replay should reproduce the same system state")
assert(runtime.context.player.x == expectedX, "Rollback and replay should reproduce the same context state")
assert(runtime.state:getCurrent().phase == expectedPhase, "Rollback and replay should reproduce the same state data")
assert(runtime:getFrameInfo().index == expectedFrame, "Rollback and replay should reproduce frame metadata")

local file = "test_tmp_snapshot.lua"
local ok, err = runtime:saveSnapshot(file, snapshot)
assert(ok, err)

local restoredRuntime, _restoredAdapter, restoredSystem = newRuntime(1)
local loaded, loadErr = restoredRuntime:loadSnapshot(file)
assert(loaded, loadErr)
assert(restoredRuntime:getFrameInfo().index == snapshot.frameInfo.index, "Loaded snapshot should restore frame index")
assert(restoredRuntime.context.player.x == snapshot.context.player.x, "Loaded snapshot should restore runtime context")
assert(restoredSystem.total == snapshot.systems["snapshot-system"].total, "Loaded snapshot should restore system hook state")
assert(restoredRuntime.state:getCurrent().phase == snapshot.state.states.play.phase, "Loaded snapshot should restore state hook data")

os.remove(file)
