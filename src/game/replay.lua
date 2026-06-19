local Serialize = require("src.core.serialize")
local Simulation = require("src.game.simulation")

local Replay = {}

function Replay.run(seed, frames, finalTick, setup)
    local sim = Simulation.new(seed)
    if setup then
        setup(sim)
    end
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
    return "THOTH_LUA_REPLAY 2\n" .. Serialize.encode({ version = 2, seed = seed, frames = frames, finalTick = finalTick }) .. "\n"
end

function Replay.fromText(text)
    local version, body = text:match("^THOTH_LUA_REPLAY%s+(%d+)%s+(.+)$")
    if not version then
        return nil, "bad replay header"
    end
    if tonumber(version) ~= 2 then
        return nil, "unsupported replay version " .. tostring(version)
    end
    return Serialize.decode(body)
end

return Replay
