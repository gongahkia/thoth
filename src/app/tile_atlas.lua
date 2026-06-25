local TileAtlas = {}

local entries = {
    archive_floor = { terrain = "archive_floor", color = { 86, 78, 64 }, uv = { 0, 0 } },
    archive_terrace = { terrain = "archive_terrace", color = { 108, 96, 74 }, uv = { 1, 0 } },
    archive_rubble = { terrain = "archive_rubble", color = { 96, 86, 78 }, uv = { 2, 0 } },
    archive_chasm = { terrain = "archive_chasm", color = { 22, 20, 28 }, uv = { 3, 0 } },
    brine_pool = { terrain = "brine_pool", color = { 44, 94, 104 }, uv = { 0, 1 } },
    index_miasma = { terrain = "index_miasma", color = { 92, 70, 110 }, uv = { 1, 1 } },
    heat_vent = { terrain = "heat_vent", color = { 156, 70, 42 }, uv = { 2, 1 } },
    root_tangle = { terrain = "root_tangle", color = { 66, 92, 58 }, uv = { 3, 1 } },
    temple_stone = { terrain = "temple_stone", color = { 110, 112, 102 }, uv = { 0, 2 } },
    blocker = { terrain = "blocker", color = { 42, 40, 45 }, uv = { 1, 2 } },
    objective = { terrain = "objective", color = { 168, 126, 48 }, uv = { 2, 2 } },
    hazard = { terrain = "hazard", color = { 164, 58, 46 }, uv = { 3, 2 } },
}

local byTerrain = {}
local ordered = {}
for key, entry in pairs(entries) do
    entry.id = key
    byTerrain[entry.terrain] = entry
    ordered[#ordered + 1] = entry
end
table.sort(ordered, function(a, b)
    return a.id < b.id
end)

function TileAtlas.entries()
    return ordered
end

function TileAtlas.entryFor(tile)
    if tile and tile.objective and next(tile.objective) then
        return entries.objective
    end
    if tile and tile.hazard and next(tile.hazard) then
        return entries.hazard
    end
    if tile and tile.blocker then
        return entries.blocker
    end
    return byTerrain[tile and tile.terrainType] or byTerrain[tile and tile.kind] or entries.archive_floor
end

function TileAtlas.makeImageData(loveImage)
    local columns = 4
    local rows = 3
    local data = loveImage.newImageData(columns, rows)
    for _, entry in ipairs(ordered) do
        local x, y = entry.uv[1], entry.uv[2]
        local color = entry.color
        data:setPixel(x, y, (color[1] or 255) / 255, (color[2] or 255) / 255, (color[3] or 255) / 255, 1)
    end
    return data, columns, rows
end

return TileAtlas
