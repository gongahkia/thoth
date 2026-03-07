local runtimeModule = require("thoth.game.runtime")
local love2d = require("thoth.adapters.love2d")
local contract = require("thoth.adapters.contract")

local function attachGameplay(runtime)
    local state = {
        x = 0,
        pressed = 0,
        released = 0,
        trace = {},
    }

    runtime.input:bind("confirm", "space")
    runtime.input:bind("move_x", {axis = {positive = "right", negative = "left"}})

    runtime:registerSystem({
        name = "recorded-input",
        fixedUpdate = function(rt)
            if rt.input:pressed("confirm") then
                state.pressed = state.pressed + 1
            end
            if rt.input:released("confirm") then
                state.released = state.released + 1
            end
            state.x = state.x + rt.input:axis("move_x")
            state.trace[#state.trace + 1] = {
                confirm = rt.input:down("confirm"),
                moveX = rt.input:axis("move_x"),
                pressed = rt.input:pressed("confirm"),
                released = rt.input:released("confirm"),
            }
        end,
    })

    return state
end

local adapter = love2d.new(nil)
local runtime = runtimeModule.new(adapter, {
    fixedDelta = 0.1,
    maxFrameDelta = 1,
    seed = 77,
})
local state = attachGameplay(runtime)

runtime:startRecording({label = "input-replay"})
runtime:update(0.1)

adapter.state.keys.space = true
adapter.state.keys.right = true
runtime:update(0.1)

adapter.state.keys.space = false
runtime:update(0.1)

adapter.state.keys.right = false
runtime:update(0.1)

local recording = runtime:stopRecording()
assert(recording ~= nil, "Stopping a recording should return the captured session")
assert(recording.seed == 77, "Recording metadata should capture the runtime seed")
assert(recording.fixedDelta == 0.1, "Recording metadata should capture fixed delta")
assert(#recording.frames == 4, "Recording should include one frame per update")
assert(recording.frames[2].input.actions.confirm.down == true)
assert(recording.frames[2].input.actions.move_x.value == 1)
assert(recording.frames[3].input.actions.confirm.down == false)
assert(recording.frames[4].input.actions.move_x.value == 0)

local replayRuntime = runtimeModule.new(contract.nullAdapter(), {
    fixedDelta = 0.1,
    maxFrameDelta = 1,
    seed = 1,
})
local replayState = attachGameplay(replayRuntime)

replayRuntime:loadReplay(recording)
assert(replayRuntime:isReplaying(), "Loading a replay should enter replay mode")
assert(replayRuntime:getSeed() == 77, "Replay should restore the recording seed")

for _ = 1, #recording.frames do
    replayRuntime:update()
end

assert(not replayRuntime:isReplaying(), "Replay mode should stop after the final frame")
assert(replayState.x == state.x, "Replay should reproduce axis-driven state changes")
assert(replayState.pressed == state.pressed, "Replay should reproduce pressed transitions")
assert(replayState.released == state.released, "Replay should reproduce released transitions")
assert(#replayState.trace == #state.trace, "Replay should reproduce the same number of fixed steps")
for i = 1, #state.trace do
    assert(replayState.trace[i].confirm == state.trace[i].confirm)
    assert(replayState.trace[i].moveX == state.trace[i].moveX)
    assert(replayState.trace[i].pressed == state.trace[i].pressed)
    assert(replayState.trace[i].released == state.trace[i].released)
end
