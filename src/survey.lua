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

local function sortedEntries(tableValue)
    local entries = {}
    for entryKey, value in pairs(tableValue or {}) do
        local copy = { key = entryKey }
        for k, v in pairs(value) do copy[k] = v end
        entries[#entries + 1] = copy
    end
    table.sort(entries, function(a, b) return tostring(a.key) < tostring(b.key) end)
    return entries
end

function Survey.snapshot(history)
    history = history or Survey.new()
    return {
        cells = sortedEntries(history.cells),
        discoveries = sortedEntries(history.discoveries),
        lastCellKey = history.lastCellKey,
    }
end

function Survey.fromSnapshot(snapshot)
    local history = Survey.new()
    for _, item in ipairs((snapshot and snapshot.cells) or {}) do
        local entryKey = item.key or key(item.scale, item.x, item.y)
        local copy = {}
        for k, v in pairs(item) do if k ~= "key" then copy[k] = v end end
        history.cells[entryKey] = copy
        history.cellCount = history.cellCount + 1
    end
    for _, item in ipairs((snapshot and snapshot.discoveries) or {}) do
        local entryKey = item.key or key(item.kind, item.id)
        local copy = {}
        for k, v in pairs(item) do if k ~= "key" then copy[k] = v end end
        history.discoveries[entryKey] = copy
        history.discoveryCount = history.discoveryCount + 1
    end
    history.lastCellKey = snapshot and snapshot.lastCellKey or nil
    return history
end

return Survey
