local CONFIG = require("config")
local EntitySystem = require("modules/entity_system")
local Items = require("modules/items")
local Utils = require("modules/utils")

local Furniture = {}

local DEFINITIONS = {
    workbench = {label = "Workbench", station = "workbench", solid = false},
    stove = {label = "Stove", station = "stove", solid = false},
    curing_rack = {label = "Curing Rack", station = "curing_rack", solid = false},
    chest = {label = "Supply Cache", container = true, solid = false},
    lantern = {label = "Lantern", lightPower = 4, solid = false},
    snow_shelter = {label = "Snow Shelter", station = "field_shelter", solid = false},
    bedroll = {label = "Bedroll", station = "field_shelter", solid = false},
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

function Furniture.spawn(level, kind, coord, options)
    options = options or {}
    level.entities = level.entities or {}
    level.tileEntities = level.tileEntities or {}

    local definition = DEFINITIONS[kind] or {}
    local key = furnitureKey(kind, coord, options)
    local entity = findExisting(level, key)
    local station = options.station or definition.station

    if entity then
        entity.hidden = options.hidden == true
        entity.source = options.source or entity.source
        if station then
            entity.stations = entity.stations or {}
            entity.stations[station] = true
            entity.station = entity.station or station
            entity.label = options.label or stationLabel(entity.stations)
        end
        if options.inventory then
            entity.inventory = cloneInventory(options.inventory)
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
        source = options.source,
        _furnitureKey = key,
        interact = function(self, run, currentLevel)
            return Furniture.interact(self, run, currentLevel)
        end,
    })

    if entity.stations then
        entity.label = options.label or stationLabel(entity.stations)
    end

    return entity
end

local function mirrorTileStations(level)
    for y = 1, #(level.grid or {}) do
        for x = 1, #(level.grid[y] or {}) do
            local tile = level.grid[y][x]
            if tile == "cabin_workbench" then
                Furniture.spawn(level, "workbench", {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE})
            elseif tile == "cabin_stove" then
                Furniture.spawn(level, "stove", {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE})
            elseif tile == "snow_shelter" then
                Furniture.spawn(level, "snow_shelter", {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE})
            elseif tile == "cabin_bed" then
                Furniture.spawn(level, "bedroll", {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE})
            end
        end
    end
end

function Furniture.mirrorLevel(level)
    if not level then
        return level
    end
    if level._furnitureMirrored then
        return level
    end

    for _, workbench in ipairs(level.workbenches or {}) do
        Furniture.spawn(level, "workbench", workbench.coord, {label = workbench.name or "Workbench"})
    end
    for _, rack in ipairs(level.curingStations or {}) do
        Furniture.spawn(level, "curing_rack", rack.coord, {label = rack.name or "Curing Rack"})
    end
    for _, shelter in ipairs(level.snowShelters or {}) do
        Furniture.spawn(level, "snow_shelter", shelter.coord, {source = shelter})
    end
    for _, node in ipairs(level.resourceNodes or {}) do
        if node.type == "cache" then
            Furniture.spawn(level, "chest", node.coord, {
                label = node.name or "Supply Cache",
                inventory = node.loot,
                opened = node.opened == true,
                hidden = node.hidden == true and node.revealed ~= true,
                source = node,
            })
        end
    end
    mirrorTileStations(level)
    EntitySystem.rebuildTileIndex(level)
    level._furnitureMirrored = true
    return level
end

return Furniture
