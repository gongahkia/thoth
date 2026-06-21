local State = require("src.game.tactics.state")

local Replay = {}

Replay.debugOnly = true

function Replay.fromSnapshot(snapshot)
    return State.fromSnapshot(snapshot)
end

function Replay.run(initialState, commands)
    local state = initialState
    for _, command in ipairs(commands or {}) do
        state:apply(command)
    end
    return state
end

function Replay.snapshot(state)
    return state:snapshot()
end

function Replay.record(initialState)
    return {
        debugOnly = true,
        initial = initialState:snapshot(),
        commands = {},
        snapshots = { initialState:snapshot() },
    }
end

function Replay.apply(recording, command)
    local state = State.fromSnapshot(recording.snapshots[#recording.snapshots])
    state:apply(command)
    recording.commands[#recording.commands + 1] = command
    recording.snapshots[#recording.snapshots + 1] = state:snapshot()
    return state
end

function Replay.rewind(recording, step)
    local index = (step or 0) + 1
    return State.fromSnapshot(recording.snapshots[index])
end

return Replay
