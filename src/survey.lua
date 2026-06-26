local Survey = {}

local function key(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = tostring(select(index, ...))
    end
    return table.concat(parts, ":")
end

function Survey.new()
    return {
        cells = {},
        discoveries = {},
        cellCount = 0,
        discoveryCount = 0,
    }
end

function Survey.mark(history, world, x, y, scale)
    history = history or Survey.new()
    scale = scale or "local"
    local cell = world:sample(math.floor(x), math.floor(y), scale)
    local cellKey = key(scale, cell.x, cell.y)
    if not history.cells[cellKey] then
        history.cells[cellKey] = {
            x = cell.x,
            y = cell.y,
            scale = scale,
            biome = cell.biome,
            basinId = cell.basinId,
            watershedId = cell.watershedId,
            ridgeId = cell.ridgeId,
            mountainRangeId = cell.mountainRangeId,
        }
        history.cellCount = history.cellCount + 1
    end
    for _, discovery in ipairs(world:discoveriesAt(cell.x, cell.y, scale)) do
        local discoveryKey = key(discovery.kind, discovery.id)
        if not history.discoveries[discoveryKey] then
            history.discoveries[discoveryKey] = discovery
            history.discoveryCount = history.discoveryCount + 1
        end
    end
    history.lastCellKey = cellKey
    return history.cells[cellKey]
end

return Survey
