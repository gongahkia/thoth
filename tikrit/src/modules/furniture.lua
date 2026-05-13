local CONFIG = require("config")
local EntitySystem = require("modules/entity_system")
local Items = require("modules/items")
local Utils = require("modules/utils")

local Furniture = {}

local function drops(...)
    local result = {}
    for index = 1, select("#", ...), 2 do
        local kind = select(index, ...)
        local quantity = select(index + 1, ...)
        table.insert(result, Items.create(kind, quantity or 1))
    end
    return result
end

local DEFINITIONS = {
    workbench = {label = "Workbench", station = "workbench", solid = false, health = 6, toolTypes = {axe = true}, drops = drops("sticks", 2, "firewood", 1)},
    stove = {label = "Stove", station = "stove", solid = false},
    curing_rack = {label = "Curing Rack", station = "curing_rack", solid = false, health = 4, toolTypes = {axe = true}, drops = drops("sticks", 2)},
    chest = {label = "Supply Cache", container = true, solid = false, health = 4, toolTypes = {axe = true}, drops = drops("sticks", 2, "cloth", 1)},
    lantern = {label = "Lantern", lightPower = 4, solid = false, health = 3, toolTypes = {axe = true}, pickupKind = "torch", drops = drops("torch", 1)},
    snow_shelter = {label = "Snow Shelter", station = "field_shelter", solid = false, health = 4, toolTypes = {axe = true}, drops = drops("sticks", 3, "cloth", 1)},
    bedroll = {label = "Bedroll", station = "field_shelter", solid = false, health = 3, toolTypes = {axe = true}, pickupKind = "bedroll", drops = drops("cloth", 2)},
}

local STATION_LABELS = {
    workbench = "Workbench",
    stove = "Stove",
    curing_rack = "Curing Rack",
    field_shelter = "Field Shelter",
}
local STATION_ORDER = {"workbench", "curing_rack", "stove", "field_shelter"}

local function coordKey(coord)
    local gx, gy = Utils.pixelToGrid(coord[1], coord[2])
    return tostring(gx + 1) .. ":" .. tostring(gy + 1)
end

local function furnitureKey(kind, coord, options)
    if options and options.mergeKey then
        return options.mergeKey
    end
    local definition = DEFINITIONS[kind] or {}
    local prefix = definition.station and "station" or kind
    return prefix .. ":" .. coordKey(coord)
end

local function stationLabel(stations)
    local labels = {}
    for _, station in ipairs(STATION_ORDER) do
        local label = STATION_LABELS[station]
        if stations[station] then
            table.insert(labels, label)
        end
    end
    return table.concat(labels, " / ")
end

local function findExisting(level, key)
    for _, entity in ipairs(level.entities or {}) do
        if entity._furnitureKey == key then
            return entity
        end
    end
    return nil
end

local function cloneInventory(inventory)
    return Items.cloneInventory(inventory or {})
end

local function cloneDrops(dropList)
    return Items.cloneInventory(dropList or {})
end

local function entityCoord(entity)
    return entity.coord or {0, 0}
end

local function stationView(entity)
    local stations = entity.stations or {[entity.station] = true}
    return {
        coord = entityCoord(entity),
        hasWorkbench = stations.workbench == true,
        hasCuring = stations.curing_rack == true,
        state = "idle",
        overlayOnly = false,
    }
end

local function renderFurniture(entity, context)
    if entity.hidden == true or not context then
        return
    end
    if entity.source and entity.source.hidden == true and entity.source.revealed ~= true then
        return
    end
    if entity.container then
        if context.drawResourceNode then
            context.drawResourceNode({
                type = "cache",
                coord = entity.coord,
                opened = entity.opened,
            })
        end
        return
    end
    if entity.station or entity.stations then
        if context.drawStation then
            context.drawStation(stationView(entity))
        end
        return
    end
    if entity.kind == "snow_shelter" and context.drawTile then
        context.drawTile("snow_shelter", entity.coord[1], entity.coord[2])
    elseif entity.kind == "bedroll" and context.drawTile then
        context.drawTile("cabin_bed", entity.coord[1], entity.coord[2])
    end
end

function Furniture.isStation(entity, station)
    if not entity then
        return false
    end
    if entity.station == station then
        return true
    end
    return entity.stations and entity.stations[station] == true
end

function Furniture.interact(entity, run, _level)
    if not entity then
        return false, nil
    end

    if entity.container then
        if entity.opened then
            return true, (entity.label or "The cache") .. " is empty."
        end
        local loot = entity.inventory or {}
        for _, item in ipairs(loot) do
            Items.add(run.player.inventory, item.kind, item.quantity or 1)
        end
        Items.sortInventory(run.player.inventory)
        run.player.carryWeight = Items.totalWeight(run.player.inventory)
        entity.inventory = {}
        entity.opened = true
        if entity.source then
            entity.source.opened = true
            entity.source.loot = {}
        end
        return true, "You open " .. (entity.label or "the cache") .. "."
    end

    if entity.station or entity.stations then
        run.runtime = run.runtime or {}
        run.runtime.currentCraftStation = {
            station = entity.station or next(entity.stations),
            stations = entity.stations,
            label = entity.label or stationLabel(entity.stations or {[entity.station] = true}),
            entity = entity,
        }
        return true, "You ready the " .. run.runtime.currentCraftStation.label .. "."
    end

    return true, entity.label and ("You inspect " .. entity.label .. ".") or "You inspect it."
end

local function sourceMatches(entity, source)
    return source == entity.source or source._entityKey == entity._furnitureKey
end

local function removeSourceFromCollection(list, entity)
    for index = #list, 1, -1 do
        if sourceMatches(entity, list[index]) then
            table.remove(list, index)
            return true
        end
    end
    return false
end

local function removeFurniture(level, entity)
    if entity.source then
        entity.source._entity = nil
        entity.source._entityKey = nil
    end
    removeSourceFromCollection(level.resourceNodes or {}, entity)
    removeSourceFromCollection(level.workbenches or {}, entity)
    removeSourceFromCollection(level.curingStations or {}, entity)
    removeSourceFromCollection(level.snowShelters or {}, entity)
    EntitySystem.remove(level, entity)
end

local function addDrops(run, dropList)
    for _, item in ipairs(dropList or {}) do
        Items.add(run.player.inventory, item.kind, item.quantity or 1)
    end
    Items.sortInventory(run.player.inventory)
    run.player.carryWeight = Items.totalWeight(run.player.inventory)
end

local function breakDrops(entity)
    local result = cloneDrops(entity.drops)
    if entity.container and entity.opened ~= true then
        for _, item in ipairs(entity.inventory or {}) do
            table.insert(result, Items.create(item.kind, item.quantity or 1))
        end
    end
    return result
end

function Furniture.hit(entity, run, level, toolDefinition)
    if not entity then
        return false, nil
    end
    if entity.fixed or entity.breakable == false or not entity.health then
        return false, (entity.label or "That") .. " is fixed in place."
    end
    if entity.toolTypes and (not toolDefinition or not entity.toolTypes[toolDefinition.toolType]) then
        return false, "The " .. (toolDefinition and toolDefinition.label or "tool") .. " is the wrong tool for that."
    end

    local damage = toolDefinition and toolDefinition.tileDamage or 1
    entity.damage = (entity.damage or 0) + damage
    if entity.source then
        entity.source.damage = entity.damage
    end
    if entity.damage < entity.health then
        return true, "You work at the " .. (entity.label or entity.kind) .. "."
    end

    addDrops(run, breakDrops(entity))
    removeFurniture(level, entity)
    return true, "You break down the " .. (entity.label or entity.kind) .. "."
end

function Furniture.pickup(entity, run, level)
    if not entity then
        return false, nil
    end
    if entity.fixed or entity.pickup == false or not entity.pickupKind then
        return false, (entity.label or "That") .. " is fixed in place."
    end

    Items.add(run.player.inventory, entity.pickupKind, 1)
    Items.sortInventory(run.player.inventory)
    run.player.carryWeight = Items.totalWeight(run.player.inventory)
    removeFurniture(level, entity)
    return true, "You pick up the " .. Items.describe(entity.pickupKind) .. "."
end

function Furniture.spawn(level, kind, coord, options)
    options = options or {}
    level.entities = level.entities or {}
    level.tileEntities = level.tileEntities or {}

    local definition = DEFINITIONS[kind] or {}
    local key = furnitureKey(kind, coord, options)
    local entity = findExisting(level, key)
    local station = options.station or definition.station
    local fixed = options.fixed == true
    local breakable = options.breakable
    if breakable == nil then
        breakable = not fixed and definition.health ~= nil
    end

    if entity then
        entity.hidden = options.hidden == true
        entity.source = options.source or entity.source
        entity.fixed = fixed or entity.fixed
        entity.breakable = breakable
        entity.health = options.health or entity.health or definition.health
        entity.toolTypes = options.toolTypes or entity.toolTypes or definition.toolTypes
        entity.drops = options.drops and cloneDrops(options.drops) or entity.drops or cloneDrops(definition.drops)
        entity.pickupKind = options.pickupKind or entity.pickupKind or definition.pickupKind
        entity.pickup = options.pickup ~= nil and options.pickup or entity.pickup
        entity.damage = options.damage or (entity.source and entity.source.damage) or entity.damage or 0
        if station then
            entity.stations = entity.stations or {}
            entity.stations[station] = true
            entity.station = entity.station or station
            entity.label = options.label or stationLabel(entity.stations)
        end
        if options.inventory then
            entity.inventory = cloneInventory(options.inventory)
        end
        entity.opened = options.opened == true
        entity.render = entity.render or renderFurniture
        entity.hit = entity.hit or function(self, run, currentLevel, toolDefinition)
            return Furniture.hit(self, run, currentLevel, toolDefinition)
        end
        if entity.source then
            entity.source._entity = nil
            entity.source._entityKey = entity._furnitureKey
        end
        return entity
    end

    local stations = nil
    if station then
        stations = {[station] = true}
    end

    entity = EntitySystem.spawn(level, kind, coord, {
        width = options.width or CONFIG.TILE_SIZE - 2,
        height = options.height or CONFIG.TILE_SIZE - 2,
        solid = options.solid ~= nil and options.solid or definition.solid,
        label = options.label or definition.label or kind,
        station = station,
        stations = stations,
        container = options.container ~= nil and options.container or definition.container,
        inventory = cloneInventory(options.inventory),
        opened = options.opened == true,
        hidden = options.hidden == true,
        lightPower = options.lightPower or definition.lightPower,
        fixed = fixed,
        breakable = breakable,
        health = options.health or definition.health,
        damage = options.damage or (options.source and options.source.damage) or 0,
        toolTypes = options.toolTypes or definition.toolTypes,
        drops = options.drops and cloneDrops(options.drops) or cloneDrops(definition.drops),
        pickupKind = options.pickupKind or definition.pickupKind,
        pickup = options.pickup ~= nil and options.pickup or definition.pickup,
        source = options.source,
        _furnitureEntity = true,
        _furnitureKey = key,
        render = renderFurniture,
        interact = function(self, run, currentLevel)
            return Furniture.interact(self, run, currentLevel)
        end,
        hit = function(self, run, currentLevel, toolDefinition)
            return Furniture.hit(self, run, currentLevel, toolDefinition)
        end,
    })

    if entity.stations then
        entity.label = options.label or stationLabel(entity.stations)
    end
    if entity.source then
        entity.source._entity = nil
        entity.source._entityKey = entity._furnitureKey
    end

    return entity
end

local function mirrorTileStations(level)
    for y = 1, #(level.grid or {}) do
        for x = 1, #(level.grid[y] or {}) do
            local tile = level.grid[y][x]
            if tile == "cabin_workbench" then
                Furniture.spawn(level, "workbench", {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE}, {fixed = true, breakable = false, pickup = false})
            elseif tile == "cabin_stove" then
                Furniture.spawn(level, "stove", {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE}, {fixed = true, breakable = false, pickup = false})
            elseif tile == "snow_shelter" then
                Furniture.spawn(level, "snow_shelter", {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE}, {fixed = true, breakable = false, pickup = false})
            elseif tile == "cabin_bed" then
                Furniture.spawn(level, "bedroll", {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE}, {fixed = true, breakable = false, pickup = false})
            end
        end
    end
end

function Furniture.mirrorLevel(level)
    if not level then
        return level
    end

    for _, workbench in ipairs(level.workbenches or {}) do
        local entity = Furniture.spawn(level, "workbench", workbench.coord, {label = workbench.name or "Workbench", source = workbench})
        workbench._entity = nil
        workbench._entityKey = entity._furnitureKey
    end
    for _, rack in ipairs(level.curingStations or {}) do
        local entity = Furniture.spawn(level, "curing_rack", rack.coord, {label = rack.name or "Curing Rack", source = rack})
        rack._entity = nil
        rack._entityKey = entity._furnitureKey
    end
    for _, shelter in ipairs(level.snowShelters or {}) do
        local entity = Furniture.spawn(level, "snow_shelter", shelter.coord, {source = shelter})
        shelter._entity = nil
        shelter._entityKey = entity._furnitureKey
    end
    for _, node in ipairs(level.resourceNodes or {}) do
        if node.type == "cache" then
            local entity = Furniture.spawn(level, "chest", node.coord, {
                label = node.name or "Supply Cache",
                inventory = node.loot,
                opened = node.opened == true,
                hidden = node.hidden == true and node.revealed ~= true,
                source = node,
            })
            node._entity = nil
            node._entityKey = entity._furnitureKey
        end
    end
    mirrorTileStations(level)
    EntitySystem.rebuildTileIndex(level)
    level._furnitureMirrored = true
    return level
end

return Furniture
