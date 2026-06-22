local Serialize = require("src.core.serialize")

local Replay = {}
local currentVersion = 2

local function validateReplay(data)
    if type(data) ~= "table" then
        return nil, "bad replay body"
    end
    if tonumber(data.version) ~= currentVersion then
        return nil, "unsupported replay version " .. tostring(data.version)
    end
    if type(data.seed) ~= "number" or type(data.finalTick) ~= "number" or type(data.frames) ~= "table" then
        return nil, "bad replay body"
    end
    return data
end

function Replay.run(seed, frames, finalTick, setup)
    local sim = {
        seed = seed,
        tick = 0,
        mode = "tactical",
        status = "replay data only",
        frames = {},
        commandQueue = {},
        queue = function(self, command)
            self.commandQueue[#self.commandQueue + 1] = command
        end,
        step = function(self)
            self.tick = self.tick + 1
            self.commandQueue = {}
        end,
    }
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

function Replay.runData(data, setup)
    return Replay.run(data.seed, data.frames, data.finalTick, setup)
end

function Replay.toText(seed, frames, finalTick)
    return "THOTH_LUA_REPLAY " .. tostring(currentVersion) .. "\n" .. Serialize.encode({ version = currentVersion, seed = seed, frames = frames, finalTick = finalTick }) .. "\n"
end

function Replay.fromText(text)
    local version, body = text:match("^THOTH_LUA_REPLAY%s+(%d+)%s+(.+)$")
    if not version then
        return nil, "bad replay header"
    end
    if tonumber(version) ~= currentVersion then
        return nil, "unsupported replay version " .. tostring(version)
    end
    local data, err = Serialize.decode(body)
    if not data then
        return nil, err
    end
    return validateReplay(data)
end

function Replay.write(path, seedOrData, frames, finalTick)
    local text
    if type(seedOrData) == "table" then
        text = Replay.toText(seedOrData.seed, seedOrData.frames, seedOrData.finalTick)
    else
        text = Replay.toText(seedOrData, frames, finalTick)
    end
    if love and love.filesystem then
        return love.filesystem.write(path, text)
    end
    local file, err = io.open(path, "w")
    if not file then
        return false, err
    end
    file:write(text)
    file:close()
    return true
end

function Replay.read(path)
    local text
    if love and love.filesystem then
        text = love.filesystem.read(path)
    else
        local file, err = io.open(path, "r")
        if not file then
            return nil, err
        end
        text = file:read("*a")
        file:close()
    end
    if not text then
        return nil, "replay not found"
    end
    return Replay.fromText(text)
end

function Replay.summary(data)
    if not data then
        return "no replay"
    end
    return "replay seed " .. tostring(data.seed) .. " / tick " .. tostring(data.finalTick) .. " / frames " .. tostring(#(data.frames or {}))
end

return Replay
