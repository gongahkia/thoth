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

local function resourceRichness(seed, x, y)
    local distanceBonus = math.min(8, math.floor((math.abs(x) + math.abs(y)) / 64))
    return 8 + (Rng.hash(seed + 5003, x, y, 0) % 5) + distanceBonus
end

local lairRadius = 5
local authoredLairs = {
    { key = "marsh_hive", x = 0, y = 18, material = "reeds" },
    { key = "glass_spire", x = 18, y = -2, material = "cactus" },
    { key = "badlands_foundry", x = 36, y = 20, material = "basalt" },
    { key = "frost_vault", x = -18, y = 0, material = "ice" },
    { key = "crystal_vault", x = -36, y = 20, material = "crystal" },
}

local function authoredLairAt(x, y)
    for _, lair in ipairs(authoredLairs) do
        if math.abs(x - lair.x) <= lairRadius and math.abs(y - lair.y) <= lairRadius then
            return lair
        end
    end
    return nil
end

local generatedLairDefs = {
    { key = "marsh_hive", material = "reeds" },
    { key = "glass_spire", material = "cactus" },
    { key = "badlands_foundry", material = "basalt" },
    { key = "frost_vault", material = "ice" },
    { key = "crystal_vault", material = "crystal" },
}

local function generatedLairAt(seed, x, y)
    if math.abs(x) + math.abs(y) < 160 then
        return nil
    end
    local cellSize = 96
    local cellX = World.floorDiv(x, cellSize)
    local cellY = World.floorDiv(y, cellSize)
    local best
    local bestDistance = math.huge
    for cy = cellY - 1, cellY + 1 do
        for cx = cellX - 1, cellX + 1 do
            local h = Rng.hash(seed + 12001, cx, cy, 0)
            if h % 1000 < 220 then
                local centerX = cx * cellSize + 48 + ((math.floor(h / 16) % 49) - 24)
                local centerY = cy * cellSize + 48 + ((math.floor(h / 2048) % 49) - 24)
                if math.abs(centerX) + math.abs(centerY) >= 160 and not authoredLairAt(centerX, centerY) then
                    local dx = x - centerX
                    local dy = y - centerY
                    local distance = dx * dx + dy * dy
                    if distance <= lairRadius * lairRadius and distance < bestDistance then
                        local def = generatedLairDefs[(h % #generatedLairDefs) + 1]
                        best = { key = def.key, x = centerX, y = centerY, material = def.material }
                        bestDistance = distance
                    end
                end
            end
        end
    end
    return best
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

function World:lairAt(x, y, z)
    z = z or 0
    if z ~= 0 and z ~= -1 then
        return nil
    end
    local lair = authoredLairAt(x, y) or generatedLairAt(self.seed, x, y)
    return lair and lair.key or nil
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
    if z < 0 then
        local lair = authoredLairAt(x, y) or generatedLairAt(self.seed, x, y)
        if lair then
            local localX = math.abs(x - lair.x)
            local localY = math.abs(y - lair.y)
            if localX == lairRadius or localY == lairRadius then
                return tile("dungeon_wall")
            end
            if localX == 0 and localY == 0 then
                return tile("stairs_up")
            end
            if localX == 2 and localY == 0 then
                return tile("lair_hearth")
            end
            if localX == 3 and localY == 1 then
                return tile(lair.material, 2)
            end
            return tile("dungeon_floor")
        end
        local localX = World.floorMod(x, 16)
        local localY = World.floorMod(y, 16)
        local room = inside(localX, 3, 12) and inside(localY, 3, 12)
        local corridor = localX == 8 or localY == 8
        if (World.floorMod(x, 32) == 0 and World.floorMod(y, 32) == 0) or (x == 0 and y == 0) then
            return tile("stairs_up")
        end
        if not room and not corridor then
            return tile("dungeon_wall")
        end
        if Rng.hash(self.seed + 14001, x, y, z) % 1000 < 24 then
            return tile("crystal", 1)
        end
        return tile("dungeon_floor")
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

    local lair = authoredLairAt(x, y) or generatedLairAt(self.seed, x, y)
    if z == 0 and lair then
        local localX = math.abs(x - lair.x)
        local localY = math.abs(y - lair.y)
        if localX == lairRadius or localY == lairRadius then
            return tile("dungeon_wall")
        end
        if localX == 0 and localY == 0 then
            return tile("stairs_down")
        end
        if localX == 2 and localY == 0 then
            return tile("lair_hearth")
        end
        if localX == 3 and localY == 1 then
            return tile(lair.material, 2)
        end
        return tile("dungeon_floor")
    end

    local h = Rng.hash(self.seed, x, y, z)
    local biome = self:biomeAt(x, y, z)
    if h % 97 == 0 then
        return tile("water")
    end
    if biome ~= "grassland" and h % 211 == 0 then
        return tile("recovery_crate")
    end
    if biome == "desert" and h % 31 == 0 then
        return tile("cactus", 2)
    end
    if biome == "marsh" and h % 23 == 0 then
        return tile("reeds", 2)
    end
    if biome == "snowfield" and h % 29 == 0 then
        return tile("ice", 2)
    end
    if biome == "badlands" and h % 19 == 0 then
        return tile("basalt", 3)
    end
    if biome == "crystal_field" and h % 17 == 0 then
        return tile("crystal", 2)
    end
    if biome == "rift" and h % 13 == 0 then
        return tile("crystal", 3)
    end
    if h % 43 == 0 then
        return tile("tree")
    end
    if h % 37 == 0 then
        return tile("stone")
    end
    if h % 89 == 0 then
        return tile("iron_ore", resourceRichness(self.seed, x, y))
    end
    if h % 101 == 0 then
        return tile("copper_ore", resourceRichness(self.seed, x, y))
    end
    if h % 113 == 0 then
        return tile("coal_ore", resourceRichness(self.seed, x, y))
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
