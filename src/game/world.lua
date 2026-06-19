local Defs = require("src.game.defs")
local Grid = require("src.core.grid")
local Rng = require("src.core.rng")

local World = {}
World.__index = World
World.chunkSize = 32

local function tile(id, data)
    return { id = id, data = data or 0 }
end

local function cloneTile(value)
    return { id = value.id, data = value.data or 0 }
end

local rooms = {
    { key = "0:0", x = 0, y = 0, w = 3, h = 3 },
    { key = "8:0", x = 8, y = 0, w = 3, h = 3 },
    { key = "16:0", x = 16, y = 0, w = 3, h = 3 },
    { key = "24:0", x = 24, y = 0, w = 3, h = 3 },
    { key = "8:6", x = 8, y = 6, w = 3, h = 3 },
    { key = "16:6", x = 16, y = 6, w = 3, h = 3 },
    { key = "24:6", x = 24, y = 6, w = 3, h = 3 },
}

local corridors = {
    { ax = 0, ay = 0, bx = 8, by = 0 },
    { ax = 8, ay = 0, bx = 16, by = 0 },
    { ax = 16, ay = 0, bx = 24, by = 0 },
    { ax = 8, ay = 0, bx = 8, by = 6 },
    { ax = 8, ay = 6, bx = 16, by = 6 },
    { ax = 16, ay = 6, bx = 24, by = 6 },
    { ax = 24, ay = 0, bx = 24, by = 6 },
}

local specialTiles = {
    [Grid.key(0, 0, 0)] = "archive_floor",
    [Grid.key(-2, 2, 0)] = "exit_gate",
    [Grid.key(4, 0, 0)] = "wire_snare",
    [Grid.key(8, 6, 0)] = "camp_marker",
    [Grid.key(16, 0, 0)] = "relic_cache",
    [Grid.key(16, 6, 0)] = "whispering_idol",
    [Grid.key(24, 0, 0)] = "boss_sigil",
}

local function inRoom(x, y, room)
    return math.abs(x - room.x) <= room.w and math.abs(y - room.y) <= room.h
end

local function inCorridor(x, y, corridor)
    if corridor.ay == corridor.by and y == corridor.ay then
        return x >= math.min(corridor.ax, corridor.bx) and x <= math.max(corridor.ax, corridor.bx)
    end
    if corridor.ax == corridor.bx and x == corridor.ax then
        return y >= math.min(corridor.ay, corridor.by) and y <= math.max(corridor.ay, corridor.by)
    end
    return false
end

function World.new(seed, overrides)
    return setmetatable({ seed = seed or 1, overrides = overrides or {}, chunks = {}, chunkRevisions = {} }, World)
end

function World.floorDiv(value, divisor)
    return math.floor(value / divisor)
end

function World.floorMod(value, divisor)
    return value - World.floorDiv(value, divisor) * divisor
end

function World.chunkKey(cx, cy, z)
    return tostring(z or 0) .. ":" .. tostring(cx) .. ":" .. tostring(cy)
end

function World:roomAt(x, y)
    for _, room in ipairs(rooms) do
        if inRoom(x, y, room) then
            return room.key, room
        end
    end
    return nil, nil
end

function World:roomCenters()
    local result = {}
    for _, room in ipairs(rooms) do
        result[#result + 1] = { key = room.key, x = room.x, y = room.y }
    end
    return result
end

function World:connectedRooms(roomKey)
    local result = {}
    local seen = {}
    for _, corridor in ipairs(corridors) do
        local a = tostring(corridor.ax) .. ":" .. tostring(corridor.ay)
        local b = tostring(corridor.bx) .. ":" .. tostring(corridor.by)
        local other = nil
        if a == roomKey then
            other = b
        elseif b == roomKey then
            other = a
        end
        if other and not seen[other] then
            seen[other] = true
            result[#result + 1] = other
        end
    end
    table.sort(result)
    return result
end

function World:generateChunk(cx, cy, z)
    local chunk = { cx = cx, cy = cy, z = z or 0, tiles = {} }
    for localY = 0, World.chunkSize - 1 do
        for localX = 0, World.chunkSize - 1 do
            local worldX = cx * World.chunkSize + localX
            local worldY = cy * World.chunkSize + localY
            chunk.tiles[localY * World.chunkSize + localX + 1] = self:generatedTile(worldX, worldY, z or 0)
        end
    end
    return chunk
end

function World:chunkForTile(x, y, z)
    local cx = World.floorDiv(x, World.chunkSize)
    local cy = World.floorDiv(y, World.chunkSize)
    local key = World.chunkKey(cx, cy, z or 0)
    if not self.chunks[key] then
        self.chunks[key] = self:generateChunk(cx, cy, z or 0)
    end
    return self.chunks[key]
end

function World:loadedChunkCount()
    local count = 0
    for _ in pairs(self.chunks) do
        count = count + 1
    end
    return count
end

function World:clearLoadedChunks()
    self.chunks = {}
end

function World:generatedTile(x, y, z)
    if (z or 0) ~= 0 then
        return tile("archive_wall")
    end
    local special = specialTiles[Grid.key(x, y, z)]
    if special then
        return tile(special)
    end
    for _, corridor in ipairs(corridors) do
        if inCorridor(x, y, corridor) then
            return tile("corridor")
        end
    end
    for _, room in ipairs(rooms) do
        if inRoom(x, y, room) then
            if math.abs(x - room.x) == room.w or math.abs(y - room.y) == room.h then
                return tile("archive_wall")
            end
            if Rng.hash(self.seed + 11017, x, y, z) % 71 == 0 then
                return tile("black_water")
            end
            return tile("archive_floor")
        end
    end
    return tile("archive_wall")
end

function World:getTile(x, y, z)
    return cloneTile(self:peekTile(x, y, z))
end

function World:peekTile(x, y, z)
    local key = Grid.key(x, y, z or 0)
    local override = self.overrides[key]
    if override then
        return override
    end
    local chunk = self:chunkForTile(x, y, z or 0)
    local localX = World.floorMod(x, World.chunkSize)
    local localY = World.floorMod(y, World.chunkSize)
    return chunk.tiles[localY * World.chunkSize + localX + 1]
end

function World:setTile(x, y, z, value)
    z = z or 0
    self.overrides[Grid.key(x, y, z)] = cloneTile(value)
    local cx = World.floorDiv(x, World.chunkSize)
    local cy = World.floorDiv(y, World.chunkSize)
    local key = World.chunkKey(cx, cy, z)
    self.chunkRevisions[key] = (self.chunkRevisions[key] or 0) + 1
end

function World:chunkRevision(cx, cy, z)
    return self.chunkRevisions[World.chunkKey(cx, cy, z or 0)] or 0
end

function World:isWalkable(x, y, z)
    return Defs.tile(self:getTile(x, y, z).id).walkable == true
end

function World:snapshot()
    local tiles = {}
    for key, value in pairs(self.overrides) do
        tiles[#tiles + 1] = { key = key, id = value.id, data = value.data or 0 }
    end
    table.sort(tiles, function(a, b)
        return a.key < b.key
    end)
    local chunks = {}
    for key, chunk in pairs(self.chunks) do
        chunks[#chunks + 1] = { key = key, cx = chunk.cx, cy = chunk.cy, z = chunk.z }
    end
    table.sort(chunks, function(a, b)
        return a.key < b.key
    end)
    return { seed = self.seed, chunks = chunks, tiles = tiles }
end

function World.fromSnapshot(snapshot)
    local overrides = {}
    for _, value in ipairs(snapshot.tiles or {}) do
        overrides[value.key] = tile(value.id, value.data)
    end
    local world = World.new(snapshot.seed, overrides)
    for _, chunk in ipairs(snapshot.chunks or {}) do
        local key = chunk.key or World.chunkKey(chunk.cx, chunk.cy, chunk.z or 0)
        world.chunks[key] = world:generateChunk(chunk.cx, chunk.cy, chunk.z or 0)
    end
    return world
end

return World
