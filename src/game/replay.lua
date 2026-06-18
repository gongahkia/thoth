local Serialize = require("src.core.serialize")
local Simulation = require("src.game.simulation")

local Replay = {}

function Replay.run(seed, frames, finalTick)
    local sim = Simulation.new(seed)
    local byTick = {}
    for _, frame in ipairs(frames or {}) do
        byTick[frame.tick] = byTick[frame.tick] or {}
        byTick[frame.tick][#byTick[frame.tick] + 1] = frame.command
    end
    while sim.tick < finalTick do
        for _, command in ipairs(byTick[sim.tick] or {}) do
            sim:queue(command)
        end
        sim:step()
    end
    return sim
end

function Replay.toText(seed, frames, finalTick)
    return "THOTH_LUA_REPLAY 1\n" .. Serialize.encode({ seed = seed, frames = frames, finalTick = finalTick }) .. "\n"
end

function Replay.fromText(text)
    local header, body = text:match("^(THOTH_LUA_REPLAY%s+1)%s+(.+)$")
    if not header then
        return nil, "bad replay header"
    end
    return Serialize.decode(body)
end

return Replay
