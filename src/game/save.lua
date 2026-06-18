local Serialize = require("src.core.serialize")
local Simulation = require("src.game.simulation")

local Save = {}

function Save.toText(simulation)
    return "THOTH_LUA_SAVE 1\n" .. Serialize.encode(simulation:snapshot()) .. "\n"
end

function Save.fromText(text)
    local header, body = text:match("^(THOTH_LUA_SAVE%s+1)%s+(.+)$")
    if not header then
        return nil, "bad save header"
    end
    local snapshot, err = Serialize.decode(body)
    if not snapshot then
        return nil, err
    end
    return Simulation.fromSnapshot(snapshot)
end

function Save.write(simulation, path)
    local text = Save.toText(simulation)
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

function Save.read(path)
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
        return nil, "save not found"
    end
    return Save.fromText(text)
end

return Save
