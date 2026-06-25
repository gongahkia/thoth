local TileAtlas = {}

local tileWidth = 16
local tileHeight = 16
local columns = 4
local rows = 3

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

local aliases = {
    floor = "archive_floor",
    archive_wall = "blocker",
    boundary_wall = "blocker",
    sealed_archive_mass = "blocker",
    sunken_water = "brine_pool",
    root_screen = "root_tangle",
    bell_stone = "temple_stone",
    ash_glass = "temple_stone",
    ritual_pillar = "blocker",
    claim_desk = "objective",
}

local byTerrain = {}
local ordered = {}
for key, entry in pairs(entries) do
    entry.id = key
    byTerrain[entry.terrain] = entry
    ordered[#ordered + 1] = entry
end
for key, id in pairs(aliases) do
    byTerrain[key] = entries[id]
end
table.sort(ordered, function(a, b)
    return a.id < b.id
end)

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[key] = copy(child)
    end
    return result
end

function TileAtlas.meta()
    return {
        image = "assets/tiles/thoth_tile_atlas.png",
        generated = true,
        tileWidth = tileWidth,
        tileHeight = tileHeight,
        columns = columns,
        rows = rows,
    }
end

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

function TileAtlas.uvRect(entry, atlasWidth, atlasHeight, pad)
    entry = entry or entries.archive_floor
    atlasWidth = atlasWidth or columns * tileWidth
    atlasHeight = atlasHeight or rows * tileHeight
    pad = pad == nil and 0.5 or pad
    local x = (entry.uv[1] or 0) * tileWidth
    local y = (entry.uv[2] or 0) * tileHeight
    return {
        u0 = (x + pad) / atlasWidth,
        v0 = (y + pad) / atlasHeight,
        u1 = (x + tileWidth - pad) / atlasWidth,
        v1 = (y + tileHeight - pad) / atlasHeight,
        entry = entry.id,
    }
end

function TileAtlas.loadManifest(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    local chunk, err = loadstring(text)
    if not chunk then
        return nil, err
    end
    local ok, value = pcall(chunk)
    if not ok or type(value) ~= "table" then
        return nil, value
    end
    return value
end

local function clamp(value)
    if value < 0 then
        return 0
    end
    if value > 255 then
        return 255
    end
    return value
end

local function shade(color, delta)
    return { clamp((color[1] or 255) + delta), clamp((color[2] or 255) + delta), clamp((color[3] or 255) + delta) }
end

local function setPixel(data, x, y, color)
    data:setPixel(x, y, (color[1] or 255) / 255, (color[2] or 255) / 255, (color[3] or 255) / 255, 1)
end

local function drawEntry(data, entry)
    local ox = (entry.uv[1] or 0) * tileWidth
    local oy = (entry.uv[2] or 0) * tileHeight
    local base = entry.color
    for y = 0, tileHeight - 1 do
        for x = 0, tileWidth - 1 do
            local grain = ((x * 17 + y * 11 + (entry.uv[1] or 0) * 23 + (entry.uv[2] or 0) * 31) % 17) - 8
            local edge = (x == 0 or y == 0 or x == tileWidth - 1 or y == tileHeight - 1) and -20 or 0
            local crack = ((entry.id == "archive_floor" or entry.id == "archive_rubble" or entry.id == "temple_stone") and ((x + y * 2) % 13 == 0)) and -30 or 0
            local stripe = (entry.id == "hazard" and (x + y) % 6 < 3) and 34 or 0
            local ripple = (entry.id == "brine_pool" and (x * 2 + y) % 7 == 0) and 28 or 0
            local void = (entry.id == "archive_chasm" and x > 3 and x < 12 and y > 3 and y < 12) and -18 or 0
            setPixel(data, ox + x, oy + y, shade(base, grain + edge + crack + stripe + ripple + void))
        end
    end
end

function TileAtlas.makeImageData(loveImage)
    local data = loveImage.newImageData(columns * tileWidth, rows * tileHeight)
    for _, entry in ipairs(ordered) do
        drawEntry(data, entry)
    end
    return data, columns, rows
end

TileAtlas.entriesById = copy(entries)

return TileAtlas
