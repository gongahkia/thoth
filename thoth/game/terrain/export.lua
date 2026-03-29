local serialize = require("thoth.core.serialize")
local grid = require("thoth.game.terrain.grid")

local export = {}

local function bundle(source, metadata)
    local width, height = grid.dimensions(source)
    return {
        metadata = serialize.deepCopy(metadata or {}),
        width = width,
        height = height,
        terrain = grid.toStrings(source),
    }
end

local function writeFile(filename, content)
    local file, err = io.open(filename, "w")
    if not file then
        return nil, err
    end
    file:write(content)
    file:close()
    return true
end

local function readFile(filename)
    local file, err = io.open(filename, "r")
    if not file then
        return nil, err
    end
    local content = file:read("*a")
    file:close()
    return content
end

function export.bundle(source, metadata)
    return bundle(source, metadata)
end

function export.toJSON(source, metadata, pretty)
    return serialize.toJSON(bundle(source, metadata), pretty and 2 or 0)
end

function export.toCSV(source)
    local rows = {}
    for y = 1, #source do
        rows[y] = table.concat(source[y], ",")
    end
    return table.concat(rows, "\n")
end

function export.saveJSON(filename, source, metadata, pretty)
    return writeFile(filename, export.toJSON(source, metadata, pretty))
end

function export.saveCSV(filename, source)
    return writeFile(filename, export.toCSV(source))
end

function export.loadJSON(filename)
    local content, err = readFile(filename)
    if not content then
        return nil, err
    end

    local decoded, decodeErr = serialize.fromJSON(content)
    if not decoded then
        return nil, decodeErr
    end

    if type(decoded.terrain) == "table" then
        decoded.grid = grid.fromStrings(decoded.terrain)
    end

    return decoded
end

function export.loadCSV(filename)
    local content, err = readFile(filename)
    if not content then
        return nil, err
    end

    local rows = {}
    for line in content:gmatch("[^\n]+") do
        rows[#rows + 1] = line:gsub(",", "")
    end
    return {
        terrain = rows,
        grid = grid.fromStrings(rows),
    }
end

return export
