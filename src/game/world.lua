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
    if y == corridor.ay and x >= math.min(corridor.ax, corridor.bx) and x <= math.max(corridor.ax, corridor.bx) then
        return true
    end
    if x == corridor.bx and y >= math.min(corridor.ay, corridor.by) and y <= math.max(corridor.ay, corridor.by) then
        return true
    end
    return false
end

function World.new(seed, locationKey, overrides)
    if type(locationKey) == "table" and overrides == nil then
        overrides = locationKey
        locationKey = "buried_archive"
    end
    return setmetatable({ seed = seed or 1, location = locationKey or "buried_archive", overrides = overrides or {}, chunks = {}, chunkRevisions = {} }, World)
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

function World:layout()
    local location = Defs.location(self.location) or Defs.location("buried_archive")
    return location.layout
end

function World:floorTile()
    return self:layout().floorTile or "archive_floor"
end

function World:wallTile()
    return self:layout().wallTile or "archive_wall"
end

function World:roomAt(x, y)
    for _, room in ipairs(self:layout().rooms or {}) do
        if inRoom(x, y, room) then
            return room.key, room
        end
    end
    return nil, nil
end

function World:roomCenters()
    local result = {}
    for _, room in ipairs(self:layout().rooms or {}) do
        result[#result + 1] = { key = room.key, x = room.x, y = room.y }
    end
    return result
end

function World:connectedRooms(roomKey)
    local result = {}
    local seen = {}
    for _, corridor in ipairs(self:layout().corridors or {}) do
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

function World:specialAt(x, y, z)
    for _, special in ipairs(self:layout().specials or {}) do
        if special.x == x and special.y == y and (special.z or 0) == (z or 0) then
            return special
        end
    end
    return nil
end

function World:specialsInRect(minX, maxX, minY, maxY, z)
    local result = {}
    for _, special in ipairs(self:layout().specials or {}) do
        if special.x >= minX and special.x <= maxX and special.y >= minY and special.y <= maxY and (special.z or 0) == (z or 0) then
            result[#result + 1] = {
                x = special.x,
                y = special.y,
                z = special.z or 0,
                tile = special.tile,
                roomKey = special.roomKey,
            }
        end
    end
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
        return tile(self:wallTile())
    end
    local special = self:specialAt(x, y, z)
    if special then
        return tile(special.tile)
    end
    local layout = self:layout()
    for _, corridor in ipairs(layout.corridors or {}) do
        if inCorridor(x, y, corridor) then
            return tile(layout.corridorTile or "corridor")
        end
    end
    for _, room in ipairs(layout.rooms or {}) do
        if inRoom(x, y, room) then
            if math.abs(x - room.x) == room.w or math.abs(y - room.y) == room.h then
                return tile(layout.wallTile or "archive_wall")
            end
            if layout.obstacleTile and layout.obstacleModulo and Rng.hash(self.seed + 11017, x, y, z) % layout.obstacleModulo == 0 then
                return tile(layout.obstacleTile)
            end
            return tile(layout.floorTile or "archive_floor")
        end
    end
    return tile(layout.wallTile or "archive_wall")
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
    return { seed = self.seed, location = self.location, chunks = chunks, tiles = tiles }
end

function World.fromSnapshot(snapshot)
    local overrides = {}
    for _, value in ipairs(snapshot.tiles or {}) do
        overrides[value.key] = tile(value.id, value.data)
    end
    local world = World.new(snapshot.seed, snapshot.location or "buried_archive", overrides)
    for _, chunk in ipairs(snapshot.chunks or {}) do
        local key = chunk.key or World.chunkKey(chunk.cx, chunk.cy, chunk.z or 0)
        world.chunks[key] = world:generateChunk(chunk.cx, chunk.cy, chunk.z or 0)
    end
    return world
end

return World
