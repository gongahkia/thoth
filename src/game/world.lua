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

local function inside(value, minValue, maxValue)
    return value >= minValue and value <= maxValue
end

local function baseTerrain(biome, roll)
    if biome == "desert" then
        return roll < 880 and "sand" or "dirt"
    end
    if biome == "snowfield" then
        return roll < 850 and "snow" or "grass"
    end
    if biome == "marsh" then
        return roll < 720 and "mud" or (roll < 900 and "grass" or "dirt")
    end
    if biome == "badlands" then
        return roll < 520 and "basalt" or (roll < 780 and "sand" or "stone")
    end
    if biome == "crystal_field" then
        return roll < 560 and "stone" or (roll < 760 and "basalt" or "dirt")
    end
    if biome == "rift" then
        return roll < 650 and "stone" or "dirt"
    end
    return roll < 230 and "dirt" or "grass"
end

function World.new(seed, overrides)
    return setmetatable({ seed = seed or 1, overrides = overrides or {}, chunks = {} }, World)
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

function World:biomeAt(x, y, z)
    z = z or 0
    if math.abs(x) >= 3840 then
        return "rift"
    end
    if inside(x, 10, 24) and inside(y, -12, 8) then
        return "desert"
    end
    if inside(x, -24, -10) and inside(y, -10, 10) then
        return "snowfield"
    end
    if inside(x, -8, 8) and inside(y, 8, 22) then
        return "marsh"
    end
    if inside(x, 28, 44) and inside(y, 12, 28) then
        return "badlands"
    end
    if inside(x, -44, -28) and inside(y, 12, 28) then
        return "crystal_field"
    end
    if inside(x, -9, 9) and inside(y, -7, 7) then
        return "grassland"
    end

    local cellX = World.floorDiv(x, 64)
    local cellY = World.floorDiv(y, 64)
    local roll = Rng.hash(self.seed + 7001, cellX, cellY, z) % 1000
    if roll < 90 then
        return "desert"
    end
    if roll < 170 then
        return "snowfield"
    end
    if roll < 250 then
        return "marsh"
    end
    if roll < 320 then
        return "badlands"
    end
    if roll < 380 then
        return "crystal_field"
    end
    return "grassland"
end

function World:generatedTile(x, y, z)
    z = z or 0
    if z == 2 then
        if x < -6 or x > 6 or y < -5 or y > 5 then
            return tile("dungeon_wall")
        end
        if x == -6 or x == 6 or y == -5 or y == 5 then
            return tile("dungeon_wall")
        end
        if x == 5 and y == 0 then
            return tile("stairs_down")
        end
        if x == -3 and y == 0 then
            return tile("tree")
        end
        if x == -2 and y == 2 then
            return tile("stone")
        end
        return tile("floor")
    end
    if z ~= 0 then
        return tile("grass")
    end
    if x == -1 and y == 0 or x == -2 and y == 0 or x == -1 and y == -1 or x == -3 and y == 1 then
        return tile("tree")
    end
    if x == 0 and y == 3 or x == -1 and y == 3 or x == 1 and y == 4 then
        return tile("stone")
    end
    if x == 3 and y == 0 or x == 4 and y == 0 then
        return tile("coal_ore", 18)
    end
    if x == 0 and y == -3 or x == 1 and y == -3 then
        return tile("iron_ore", 22)
    end
    if x == 3 and y == -3 or x == 4 and y == -3 then
        return tile("copper_ore", 22)
    end

    local h = Rng.hash(self.seed, x, y, z)
    local biome = self:biomeAt(x, y, z)
    if h % 97 == 0 then
        return tile("water")
    end
    if h % 43 == 0 then
        return tile("tree")
    end
    if h % 37 == 0 then
        return tile("stone")
    end
    if h % 89 == 0 then
        return tile("iron_ore", 12 + (h % 20))
    end
    if h % 101 == 0 then
        return tile("copper_ore", 12 + (h % 20))
    end
    if h % 113 == 0 then
        return tile("coal_ore", 12 + (h % 20))
    end
    return tile(baseTerrain(biome, Rng.hash(self.seed + 9001, x, y, z) % 1000))
end

function World:getTile(x, y, z)
    local key = Grid.key(x, y, z or 0)
    local override = self.overrides[key]
    if override then
        return cloneTile(override)
    end
    local chunk = self:chunkForTile(x, y, z or 0)
    local localX = World.floorMod(x, World.chunkSize)
    local localY = World.floorMod(y, World.chunkSize)
    return cloneTile(chunk.tiles[localY * World.chunkSize + localX + 1])
end

function World:setTile(x, y, z, value)
    self.overrides[Grid.key(x, y, z or 0)] = cloneTile(value)
end

function World:isWalkable(x, y, z)
    return Defs.tile(self:getTile(x, y, z).id).walkable == true
end

function World:mineTile(x, y, z)
    local current = self:getTile(x, y, z)
    local def = Defs.tile(current.id)
    if not def.drop then
        return nil
    end
    if def.resource and current.data and current.data > 1 then
        current.data = current.data - 1
        self:setTile(x, y, z, current)
    else
        self:setTile(x, y, z, tile("grass"))
    end
    return def.drop
end

function World:consumeResource(x, y, z)
    local current = self:getTile(x, y, z)
    local def = Defs.tile(current.id)
    if not def.resource or (current.data or 0) <= 0 then
        return nil
    end
    current.data = current.data - 1
    if current.data <= 0 then
        self:setTile(x, y, z, tile("grass"))
    else
        self:setTile(x, y, z, current)
    end
    return def.resource
end

function World:snapshot()
    local tiles = {}
    for key, value in pairs(self.overrides) do
        tiles[#tiles + 1] = { key = key, id = value.id, data = value.data or 0 }
    end
    table.sort(tiles, function(a, b)
        return a.key < b.key
    end)
    return { seed = self.seed, tiles = tiles }
end

function World.fromSnapshot(snapshot)
    local overrides = {}
    for _, value in ipairs(snapshot.tiles or {}) do
        overrides[value.key] = tile(value.id, value.data)
    end
    return World.new(snapshot.seed, overrides)
end

return World
