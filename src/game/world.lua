local Defs = require("src.game.defs")
local Grid = require("src.core.grid")
local Rng = require("src.core.rng")

local World = {}
World.__index = World

local function tile(id, data)
    return { id = id, data = data or 0 }
end

local function cloneTile(value)
    return { id = value.id, data = value.data or 0 }
end

function World.new(seed, overrides)
    return setmetatable({ seed = seed or 1, overrides = overrides or {} }, World)
end

function World:generatedTile(x, y, z)
    z = z or 0
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
    return tile("grass")
end

function World:getTile(x, y, z)
    local key = Grid.key(x, y, z or 0)
    local override = self.overrides[key]
    if override then
        return cloneTile(override)
    end
    return self:generatedTile(x, y, z or 0)
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
