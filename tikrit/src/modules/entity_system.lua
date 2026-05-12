local CONFIG = require("config")
local TileRegistry = require("modules/tile_registry")
local Utils = require("modules/utils")

local EntitySystem = {}

local nextEntityId = 1

local function key(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function bounds(entity, x, y)
    x = x or entity.coord[1]
    y = y or entity.coord[2]
    local width = entity.width or CONFIG.TILE_SIZE - 2
    local height = entity.height or CONFIG.TILE_SIZE - 2
    return x, y, x + width, y + height
end

local function tileRange(entity, x, y)
    local x0, y0, x1, y1 = bounds(entity, x, y)
    local tx0, ty0 = Utils.pixelToGrid(x0, y0)
    local tx1, ty1 = Utils.pixelToGrid(x1, y1)
    return tx0 + 1, ty0 + 1, tx1 + 1, ty1 + 1
end

local function ensureStore(level)
    level.entities = level.entities or {}
    level.tileEntities = level.tileEntities or {}
end

function EntitySystem.add(level, entity)
    ensureStore(level)
    entity.id = entity.id or nextEntityId
    nextEntityId = math.max(nextEntityId, entity.id + 1)
    entity.coord = entity.coord or {0, 0}
    entity.depth = entity.depth or level.depth or 0
    table.insert(level.entities, entity)
    EntitySystem.updateTileIndex(level, entity)
    return entity
end

function EntitySystem.spawn(level, kind, coord, options)
    options = options or {}
    local entity = {
        kind = kind,
        coord = {coord[1], coord[2]},
        width = options.width or CONFIG.TILE_SIZE - 2,
        height = options.height or CONFIG.TILE_SIZE - 2,
        solid = options.solid ~= false,
        depth = level.depth or 0,
        tick = options.tick,
        render = options.render,
    }
    for keyName, value in pairs(options) do
        entity[keyName] = value
    end
    return EntitySystem.add(level, entity)
end

function EntitySystem.remove(level, entityOrId)
    ensureStore(level)
    local id = type(entityOrId) == "table" and entityOrId.id or entityOrId
    for index = #level.entities, 1, -1 do
        if level.entities[index].id == id then
            table.remove(level.entities, index)
        end
    end
    EntitySystem.rebuildTileIndex(level)
end

function EntitySystem.rebuildTileIndex(level)
    ensureStore(level)
    level.tileEntities = {}
    for _, entity in ipairs(level.entities) do
        EntitySystem.updateTileIndex(level, entity)
    end
end

function EntitySystem.updateTileIndex(level, entity)
    ensureStore(level)
    if entity._tileKey then
        local list = level.tileEntities[entity._tileKey]
        if list then
            for index = #list, 1, -1 do
                if list[index] == entity then
                    table.remove(list, index)
                end
            end
        end
    end

    local gx, gy = Utils.pixelToGrid(entity.coord[1] + ((entity.width or 0) / 2), entity.coord[2] + ((entity.height or 0) / 2))
    entity.tileX = gx + 1
    entity.tileY = gy + 1
    entity._tileKey = key(entity.tileX, entity.tileY)
    level.tileEntities[entity._tileKey] = level.tileEntities[entity._tileKey] or {}
    table.insert(level.tileEntities[entity._tileKey], entity)
end

function EntitySystem.getTileEntities(level, x, y)
    ensureStore(level)
    return level.tileEntities[key(x, y)] or {}
end

local function aabbOverlap(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
    return ax0 < bx1 and ax1 > bx0 and ay0 < by1 and ay1 > by0
end

function EntitySystem.getCollisions(level, entity, x, y)
    ensureStore(level)
    local collisions = {}
    local ex0, ey0, ex1, ey1 = bounds(entity, x, y)
    local tx0, ty0, tx1, ty1 = tileRange(entity, x, y)
    for ty = ty0, ty1 do
        for tx = tx0, tx1 do
            for _, other in ipairs(EntitySystem.getTileEntities(level, tx, ty)) do
                if other ~= entity and other.solid ~= false then
                    local ox0, oy0, ox1, oy1 = bounds(other)
                    if aabbOverlap(ex0, ey0, ex1, ey1, ox0, oy0, ox1, oy1) then
                        table.insert(collisions, other)
                    end
                end
            end
        end
    end
    return collisions
end

local function collidesWithTiles(level, entity, x, y)
    local tx0, ty0, tx1, ty1 = tileRange(entity, x, y)
    for ty = ty0, ty1 do
        for tx = tx0, tx1 do
            local row = level.grid and level.grid[ty]
            local tile = row and row[tx]
            if not tile or TileRegistry.get(tile):collides(level, tx, ty, entity) then
                return true
            end
        end
    end
    return false
end

local function tryMoveAxis(level, entity, dx, dy)
    if dx == 0 and dy == 0 then
        return false
    end
    local nextX = entity.coord[1] + dx
    local nextY = entity.coord[2] + dy
    if collidesWithTiles(level, entity, nextX, nextY) then
        return false
    end
    if #EntitySystem.getCollisions(level, entity, nextX, nextY) > 0 then
        return false
    end
    entity.coord[1] = nextX
    entity.coord[2] = nextY
    return true
end

function EntitySystem.moveEntity(level, entity, dx, dy)
    local movedX = tryMoveAxis(level, entity, dx, 0)
    local movedY = tryMoveAxis(level, entity, 0, dy)
    if movedX or movedY then
        EntitySystem.updateTileIndex(level, entity)
        local gx, gy = Utils.pixelToGrid(entity.coord[1] + ((entity.width or 0) / 2), entity.coord[2] + ((entity.height or 0) / 2))
        local tile = level.grid[gy + 1] and level.grid[gy + 1][gx + 1]
        TileRegistry.get(tile):step(level, gx + 1, gy + 1, entity)
    end
    return movedX or movedY
end

function EntitySystem.tick(level, run)
    ensureStore(level)
    for _, entity in ipairs(level.entities) do
        if entity.tick then
            entity:tick(level, run)
        end
    end
end

function EntitySystem.render(level, ...)
    ensureStore(level)
    for _, entity in ipairs(level.entities) do
        if entity.render then
            entity:render(...)
        end
    end
end

return EntitySystem
