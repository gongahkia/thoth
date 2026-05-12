local CONFIG = require("config")
local Items = require("modules/items")

local TileRegistry = {
    tiles = {},
}

local function noop()
    return false
end

local function defaultDrops()
    return {}
end

local function defaultRender(tileName)
    return function(bundle, x, y, settings)
        if bundle and bundle.drawTile then
            bundle.drawTile(tileName, x, y, settings)
        end
    end
end

local function baseDefinition(name)
    local definition = {
        name = name,
        solid = false,
        destructible = false,
        maxHealth = 0,
        baseTile = nil,
        dropItems = defaultDrops,
    }

    function definition:isSolid()
        return self.solid == true
    end

    function definition:isDestructible()
        return self.destructible == true
    end

    function definition:health()
        return self.maxHealth or 0
    end

    function definition:collides(_level, _x, _y, entity)
        if self.liquid and entity and entity.canSwim then
            return false
        end
        return self.solid == true
    end

    function definition:drops(level, x, y, entity)
        return self.dropItems(level, x, y, entity)
    end

    definition.step = noop
    definition.bump = noop
    definition.interact = noop
    definition.randomTick = noop
    definition.render = defaultRender(name)

    function definition:hit(level, x, y, entity, run)
        if not self:isDestructible() then
            return false, {}
        end

        level.data = level.data or {}
        level.data[y] = level.data[y] or {}
        local toolDamage = (entity and entity.tileDamage) or 1
        local nextDamage = (level.data[y][x] or 0) + toolDamage
        if nextDamage < self:health(level, x, y, entity) then
            level.data[y][x] = nextDamage
            return true, {}
        end

        level.data[y][x] = 0
        if level.grid and level.grid[y] then
            level.grid[y][x] = self.baseTile or "snow"
        end
        if run and run.world and run.world.grid == level.grid then
            run.world.grid[y][x] = self.baseTile or "snow"
        end
        return true, self:drops(level, x, y, entity)
    end

    return definition
end

function TileRegistry.register(name, options)
    options = options or {}
    local definition = baseDefinition(name)
    for key, value in pairs(options) do
        definition[key] = value
    end
    TileRegistry.tiles[name] = definition
    return definition
end

function TileRegistry.get(tile)
    if type(tile) == "table" and tile.name then
        return tile
    end
    return TileRegistry.tiles[tile] or TileRegistry.tiles.unknown
end

function TileRegistry.isWalkable(tile, level, x, y, entity)
    local definition = TileRegistry.get(tile)
    return not definition:collides(level, x, y, entity)
end

function TileRegistry.hit(level, x, y, entity, run)
    local tile = level and level.grid and level.grid[y] and level.grid[y][x]
    return TileRegistry.get(tile):hit(level, x, y, entity, run)
end

function TileRegistry.interact(level, x, y, entity, run)
    local tile = level and level.grid and level.grid[y] and level.grid[y][x]
    return TileRegistry.get(tile):interact(level, x, y, entity, run)
end

function TileRegistry.randomTick(level, x, y, run)
    local tile = level and level.grid and level.grid[y] and level.grid[y][x]
    return TileRegistry.get(tile):randomTick(level, x, y, run)
end

local function itemDrops(...)
    local result = {}
    for index = 1, select("#", ...), 2 do
        local kind = select(index, ...)
        local quantity = select(index + 1, ...)
        table.insert(result, Items.create(kind, quantity or 1))
    end
    return result
end

TileRegistry.register("unknown", {solid = true})
TileRegistry.register("snow")
TileRegistry.register("path")
TileRegistry.register("ash")
TileRegistry.register("moss")
TileRegistry.register("shale")
TileRegistry.register("ice")
TileRegistry.register("weak_ice", {
    randomTick = function(self, level, x, y)
        level.data = level.data or {}
        level.data[y] = level.data[y] or {}
        level.data[y][x] = math.min(3, (level.data[y][x] or 0) + 1)
        if level.data[y][x] >= 3 and math.random(6) == 1 then
            level.grid[y][x] = "ice"
            level.data[y][x] = 0
        end
        return true
    end,
})
TileRegistry.register("fire_safe")
TileRegistry.register("thermal_fissure", {
    randomTick = function(_self, _level, _x, _y, run)
        if run and run.player and run.player.warmth then
            run.player.warmth = math.min(CONFIG.MAX_WARMTH, run.player.warmth + 1)
        end
        return true
    end,
})

TileRegistry.register("tree", {
    solid = true,
    destructible = true,
    maxHealth = 6,
    baseTile = "snow",
    dropItems = function()
        return itemDrops("sticks", 2, "firewood", 1)
    end,
})
TileRegistry.register("rock", {
    solid = true,
    destructible = true,
    maxHealth = 8,
    baseTile = "shale",
    dropItems = function()
        return itemDrops("charcoal", 1)
    end,
})
TileRegistry.register("cabin_wall", {solid = true})
TileRegistry.register("cave_wall", {solid = true})
TileRegistry.register("cabin_floor")
TileRegistry.register("cave_floor")
TileRegistry.register("cabin_bed")
TileRegistry.register("cabin_stove")
TileRegistry.register("cabin_workbench")
TileRegistry.register("snow_shelter")
TileRegistry.register("stair_up", {
    step = function(_self, _level, x, y, entity)
        if entity then
            entity.moveDepth = {depth = (entity.depth or 0) + 1, x = x, y = y}
        end
        return true
    end,
})
TileRegistry.register("stair_down", {
    step = function(_self, _level, x, y, entity)
        if entity then
            entity.moveDepth = {depth = (entity.depth or 0) - 1, x = x, y = y}
        end
        return true
    end,
})

return TileRegistry
