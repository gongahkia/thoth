local State = require("src.game.tactics.state")

local Replay = {}

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

return Replay
