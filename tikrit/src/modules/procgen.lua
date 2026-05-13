local CONFIG = require("config")
local Items = require("modules/items")
local Utils = require("modules/utils")
local World = require("modules/world")

local ProcGen = {}

local function gridHeight(grid)
    return #grid
end

local function gridWidth(grid)
    return #(grid[1] or {})
end

local function newGrid(width, height)
    width = width or CONFIG.WORLD_GRID_WIDTH or CONFIG.GRID_WIDTH
    height = height or CONFIG.WORLD_GRID_HEIGHT or CONFIG.GRID_HEIGHT
    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            grid[y][x] = "snow"
        end
    end
    return grid
end

local function inBounds(grid, x, y)
    return x >= 1 and x <= gridWidth(grid) and y >= 1 and y <= gridHeight(grid)
end

local function setTile(grid, x, y, tile)
    if inBounds(grid, x, y) then
        grid[y][x] = tile
    end
end

local function fillRect(grid, x, y, w, h, tile)
    for gy = y, y + h - 1 do
        for gx = x, x + w - 1 do
            setTile(grid, gx, gy, tile)
        end
    end
end

local function carvePath(grid, x1, y1, x2, y2)
    local x = x1
    local y = y1
    while x ~= x2 do
        setTile(grid, x, y, "path")
        x = x + (x2 > x and 1 or -1)
    end
    while y ~= y2 do
        setTile(grid, x, y, "path")
        y = y + (y2 > y and 1 or -1)
    end
    setTile(grid, x, y, "path")
end

local function buildBorder(grid)
    local width = gridWidth(grid)
    local height = gridHeight(grid)
    for x = 1, width do
        setTile(grid, x, 1, x % 2 == 0 and "rock" or "tree")
        setTile(grid, x, height, x % 2 == 0 and "tree" or "rock")
    end
    for y = 1, height do
        setTile(grid, 1, y, y % 2 == 0 and "rock" or "tree")
        setTile(grid, width, y, y % 2 == 0 and "tree" or "rock")
    end
end

local function worldCoord(gridX, gridY)
    return {(gridX - 1) * CONFIG.TILE_SIZE, (gridY - 1) * CONFIG.TILE_SIZE}
end

local function annotatedCoord(gridX, gridY, metadata)
    local coord = worldCoord(gridX, gridY)
    for key, value in pairs(metadata or {}) do
        coord[key] = value
    end
    return coord
end

local function zoneCenter(zone)
    return {
        (zone.x + math.floor(zone.width / 2)) * CONFIG.TILE_SIZE,
        (zone.y + math.floor(zone.height / 2)) * CONFIG.TILE_SIZE,
    }
end

local function makeZone(x, y, width, height)
    return {x = x, y = y, width = width, height = height}
end

local function addCabin(grid, x, y, name, w, h)
    w = math.max(6, w or 6)
    h = math.max(5, h or 5)
    for gy = y, y + h - 1 do
        for gx = x, x + w - 1 do
            local border = gy == y or gy == y + h - 1 or gx == x or gx == x + w - 1
            setTile(grid, gx, gy, border and "cabin_wall" or "cabin_floor")
        end
    end

    local doorX = x + math.floor(w / 2)
    local doorY = y + h - 1
    local bedX = x + 1
    local bedY = y + 1
    local stoveX = x + w - 2
    local stoveY = y + 1
    local workbenchX = x + 1
    local workbenchY = y + h - 2

    setTile(grid, doorX, doorY, "path")
    setTile(grid, bedX, bedY, "cabin_bed")
    setTile(grid, stoveX, stoveY, "cabin_stove")
    setTile(grid, workbenchX, workbenchY, "cabin_workbench")

    return {
        type = "cabin",
        name = name or "Cabin",
        x = x,
        y = y,
        w = w,
        h = h,
        door = {x = doorX, y = doorY},
        bed = {x = bedX, y = bedY},
        stove = {x = stoveX, y = stoveY},
        workbench = {x = workbenchX, y = workbenchY},
        doorOpen = false,
    }
end

local function addCave(grid, x, y, w, h)
    w = math.max(7, w or 7)
    h = math.max(5, h or 5)
    for gy = y, y + h - 1 do
        for gx = x, x + w - 1 do
            local border = gy == y or gy == y + h - 1 or gx == x or gx == x + w - 1
            setTile(grid, gx, gy, border and "cave_wall" or "cave_floor")
        end
    end

    local mouthX = x + math.floor(w / 2)
    local mouthY = y + h - 1
    local bedX = x + math.max(1, math.floor(w / 2) - 1)
    local bedY = y + math.max(1, math.floor(h / 2))

    setTile(grid, mouthX, mouthY, "path")

    return {
        type = "cave",
        x = x,
        y = y,
        w = w,
        h = h,
        mouth = {x = mouthX, y = mouthY},
        bed = {x = bedX, y = bedY},
    }
end

local function canPlaceResource(grid, x, y)
    local tile = grid[y] and grid[y][x]
    return tile == "snow" or tile == "path" or tile == "fire_safe" or tile == "cabin_floor" or tile == "cave_floor"
end

local function addResourceNode(list, nodeType, x, y, payload)
    local node = {
        type = nodeType,
        coord = worldCoord(x, y),
        opened = false,
    }
    if payload then
        for key, value in pairs(payload) do
            node[key] = value
        end
    end
    table.insert(list, node)
end

local function randomLoot()
    local options = {
        {"canned_food", 1},
        {"water", 1},
        {"cloth", 1},
        {"tea", 1},
        {"bandage", 1},
        {"painkillers", 1},
        {"antiseptic", 1},
        {"antibiotics", 1},
        {"tinder", 2},
        {"matches", 3},
        {"sticks", 2},
        {"firewood", 1},
        {"snow", 1},
        {"raw_meat", 1},
        {"raw_fish", 1},
        {"torch", 1},
        {"flare", 1},
        {"accelerant", 1},
        {"charcoal", 1},
        {"arrow", 2},
        {"rope_bolt", 1},
        {"signal_bolt", 1},
        {"fishing_tackle", 1},
        {"bow", 1},
        {"sword", 1},
        {"bridge_kit", 1},
        {"survey_kit", 1},
        {"snare", 1},
    }
    local choice = options[math.random(#options)]
    return {Items.create(choice[1], choice[2])}
end

local function zoneContainsTile(zone, x, y)
    local width = zone.width or zone.w
    local height = zone.height or zone.h
    return x >= zone.x and x < zone.x + width and y >= zone.y and y < zone.y + height
end

local function biomeForTile(biomes, x, y)
    for _, biome in ipairs(biomes or {}) do
        if zoneContainsTile(biome.zone, x, y) then
            return biome
        end
    end
    return nil
end

local function makeFishingSpot(x, y, name)
    return {
        coord = worldCoord(x, y),
        name = name or "Fishing Hole",
    }
end

local function makeMapNode(x, y, name)
    return {
        coord = worldCoord(x, y),
        name = name or "Overlook",
    }
end

local function makeClimbNode(x, y, targetX, targetY, name)
    return {
        coord = worldCoord(x, y),
        targetCoord = worldCoord(targetX, targetY),
        name = name or "Rope Climb",
    }
end

local function makeWorkbench(x, y, name)
    return {
        coord = worldCoord(x, y),
        name = name or "Workbench",
    }
end

local function makeCuringStation(x, y, name)
    return {
        coord = worldCoord(x, y),
        name = name or "Curing Rack",
    }
end

local function makeCarcass(kind, x, y)
    return {
        kind = kind,
        coord = worldCoord(x, y),
        meat = kind == "deer" and 3 or 1,
        hide = kind == "deer" and 1 or 1,
        gut = kind == "deer" and 2 or (kind == "rabbit" and 1 or 0),
        feathers = kind == "fish" and 0 or 2,
    }
end

local function placeLake(grid)
    local weakIceTiles = {}
    local lakeArea = {x = 22, y = 19, w = 18, h = 12}

    fillRect(grid, lakeArea.x, lakeArea.y, lakeArea.w, lakeArea.h, "ice")

    local candidates = {}
    for y = lakeArea.y, lakeArea.y + lakeArea.h - 1 do
        for x = lakeArea.x, lakeArea.x + lakeArea.w - 1 do
            table.insert(candidates, {x = x, y = y})
        end
    end
    Utils.shuffle(candidates)

    local weakIceCount = math.random(math.max(CONFIG.WEAK_ICE_MIN, 14), math.max(CONFIG.WEAK_ICE_MAX, 22))
    for index = 1, weakIceCount do
        local tile = candidates[index]
        setTile(grid, tile.x, tile.y, "weak_ice")
        table.insert(weakIceTiles, {x = tile.x, y = tile.y})
    end

    return weakIceTiles, lakeArea
end

local function noiseValue(x, y, seed)
    local value = math.sin((x * 127.1) + (y * 311.7) + ((seed or 1) * 17.13)) * 43758.5453
    return value - math.floor(value)
end

local function makeDataGrid(grid)
    local data = {}
    for y = 1, #grid do
        data[y] = {}
        for x = 1, #(grid[y] or {}) do
            data[y][x] = 0
        end
    end
    return data
end

local function countLayerTiles(level)
    local counts = {}
    for y = 1, #level.grid do
        for x = 1, #(level.grid[y] or {}) do
            local tile = level.grid[y][x]
            counts[tile] = (counts[tile] or 0) + 1
        end
    end
    return counts
end

local function makeLayerGrid(width, height, floorTile, wallTile, seed, wallThreshold)
    local grid = newGrid(width, height)
    for y = 1, height do
        for x = 1, width do
            local border = x == 1 or y == 1 or x == width or y == height
            if border then
                grid[y][x] = wallTile
            else
                local edge = math.max(math.abs(x - (width / 2)) / (width / 2), math.abs(y - (height / 2)) / (height / 2))
                local roughness = (noiseValue(x, y, seed) * 0.55)
                    + (noiseValue(math.floor(x / 3), math.floor(y / 3), seed + 13) * 0.35)
                    + (edge * 0.25)
                grid[y][x] = roughness > wallThreshold and wallTile or floorTile
            end
        end
    end
    return grid
end

local function smoothLayer(grid, floorTile, wallTile, passes)
    local directions = {
        {-1, -1}, {0, -1}, {1, -1},
        {-1, 0},           {1, 0},
        {-1, 1},  {0, 1},  {1, 1},
    }

    for _ = 1, passes do
        local nextGrid = {}
        for y = 1, gridHeight(grid) do
            nextGrid[y] = {}
            for x = 1, gridWidth(grid) do
                if x == 1 or y == 1 or x == gridWidth(grid) or y == gridHeight(grid) then
                    nextGrid[y][x] = wallTile
                else
                    local walls = 0
                    for _, direction in ipairs(directions) do
                        local tile = grid[y + direction[2]] and grid[y + direction[2]][x + direction[1]]
                        if tile == wallTile or tile == nil then
                            walls = walls + 1
                        end
                    end
                    if walls >= 5 then
                        nextGrid[y][x] = wallTile
                    elseif walls <= 2 then
                        nextGrid[y][x] = floorTile
                    else
                        nextGrid[y][x] = grid[y][x]
                    end
                end
            end
        end
        grid = nextGrid
    end
    return grid
end

local function paintNoisePatch(grid, area, tile, seed, threshold)
    for y = area.y, area.y + area.height - 1 do
        for x = area.x, area.x + area.width - 1 do
            if inBounds(grid, x, y) and noiseValue(x, y, seed) >= threshold then
                setTile(grid, x, y, tile)
            end
        end
    end
end

local function carvePathAs(grid, x1, y1, x2, y2, tile)
    local x = x1
    local y = y1
    while x ~= x2 do
        setTile(grid, x, y, tile)
        x = x + (x2 > x and 1 or -1)
    end
    while y ~= y2 do
        setTile(grid, x, y, tile)
        y = y + (y2 > y and 1 or -1)
    end
    setTile(grid, x, y, tile)
end

local function protectLayerAnchors(grid, anchors)
    for _, anchor in ipairs(anchors or {}) do
        setTile(grid, anchor.x, anchor.y, anchor.tile or anchor.floorTile or "path")
    end
end

local function addLayerResource(nodes, nodeType, x, y, loot, label, options)
    options = options or {}
    addResourceNode(nodes, nodeType, x, y, {
        loot = loot,
        biome = label,
        biomeId = options.biomeId,
        name = options.name,
        rewardTier = nodeType == "cache" and "high" or "medium",
    })
end

local function makeLayerBase(depth, name, grid, payload)
    payload = payload or {}
    payload.depth = depth
    payload.name = name
    payload.grid = grid
    payload.data = makeDataGrid(grid)
    payload.entities = payload.entities or {}
    payload.tileEntities = payload.tileEntities or {}
    payload.spawnRules = payload.spawnRules or {}
    payload.discovered = payload.discovered or {}
    payload.structures = payload.structures or {}
    payload.resourceNodes = payload.resourceNodes or {}
    payload.pointsOfInterest = payload.pointsOfInterest or {}
    payload.safeSleepSpots = payload.safeSleepSpots or {}
    payload.hazardZones = payload.hazardZones or {}
    payload.biomes = payload.biomes or {}
    payload.workbenches = payload.workbenches or {}
    payload.curingStations = payload.curingStations or {}
    payload.mapNodes = payload.mapNodes or {}
    payload.climbNodes = payload.climbNodes or {}
    payload.fishingSpots = payload.fishingSpots or {}
    payload.carcasses = payload.carcasses or {}
    payload.snowShelters = payload.snowShelters or {}
    payload.fires = payload.fires or {}
    payload.traps = payload.traps or {}
    payload.curing = payload.curing or {}
    payload.gates = payload.gates or {}
    payload.npcEncounters = payload.npcEncounters or {}
    payload.wildlife = payload.wildlife or {wolves = {}, rabbits = {}, deer = {}, raiders = {}}
    return payload
end

local function makeIceCaveLevel(width, height, seed)
    local grid = smoothLayer(makeLayerGrid(width, height, "cave_floor", "cave_wall", seed, 0.66), "cave_floor", "cave_wall", 2)
    local entrance = {x = 80, y = 22}
    local descent = {x = 82, y = 24}
    local warmPocket = makeZone(72, 17, 14, 10)
    local icePocket = makeZone(54, 31, 24, 14)
    local frozenTunnel = makeZone(70, 16, 18, 12)
    local coalPocket = makeZone(66, 17, 14, 9)
    local brittleShelf = makeZone(76, 24, 16, 11)

    fillRect(grid, frozenTunnel.x, frozenTunnel.y, frozenTunnel.width, frozenTunnel.height, "cave_floor")
    paintNoisePatch(grid, frozenTunnel, "ice", seed + 14, 0.82)
    fillRect(grid, warmPocket.x, warmPocket.y, warmPocket.width, warmPocket.height, "cave_floor")
    fillRect(grid, coalPocket.x, coalPocket.y, coalPocket.width, coalPocket.height, "cave_floor")
    paintNoisePatch(grid, coalPocket, "rock", seed + 15, 0.86)
    fillRect(grid, icePocket.x, icePocket.y, icePocket.width, icePocket.height, "ice")
    paintNoisePatch(grid, icePocket, "weak_ice", seed + 1, 0.76)
    fillRect(grid, brittleShelf.x, brittleShelf.y, brittleShelf.width, brittleShelf.height, "ice")
    paintNoisePatch(grid, brittleShelf, "weak_ice", seed + 16, 0.7)
    carvePathAs(grid, entrance.x, entrance.y, descent.x, descent.y, "cave_floor")
    carvePathAs(grid, entrance.x, entrance.y, 60, 36, "cave_floor")
    carvePathAs(grid, 60, 36, 72, 22, "cave_floor")
    carvePathAs(grid, 74, 21, 66, 40, "cave_floor")
    fillRect(grid, 76, 19, 5, 4, "fire_safe")
    protectLayerAnchors(grid, {
        {x = entrance.x, y = entrance.y, tile = "stair_up"},
        {x = descent.x, y = descent.y, tile = "stair_down"},
        {x = 74, y = 21, tile = "cave_floor"},
        {x = 60, y = 36, tile = "cave_floor"},
        {x = 84, y = 26, tile = "cave_floor"},
        {x = 66, y = 40, tile = "cave_floor"},
        {x = 78, y = 21, tile = "fire_safe"},
    })
    setTile(grid, entrance.x, entrance.y, "stair_up")
    setTile(grid, descent.x, descent.y, "stair_down")

    local resourceNodes = {}
    addLayerResource(resourceNodes, "loot", 74, 21, {Items.create("charcoal", 2), Items.create("torch", 1)}, "Coal Pockets", {biomeId = "coal_pockets", name = "Blackened Coal Seam"})
    addLayerResource(resourceNodes, "cache", 60, 36, {Items.create("matches", 2), Items.create("cloth", 1), Items.create("water", 1)}, "Subglacial Pools", {biomeId = "subglacial_pools", name = "Buried Ice Cache"})
    addLayerResource(resourceNodes, "loot", 84, 26, {Items.create("firewood", 1), Items.create("tinder", 2)}, "Brittle Ice Shelves", {biomeId = "brittle_ice_shelves", name = "Old Camp Scraps"})
    addLayerResource(resourceNodes, "loot", 66, 40, {Items.create("charcoal", 1), Items.create("flare", 1)}, "Frozen Tunnels", {biomeId = "frozen_tunnels", name = "Lost Survey Pack"})

    return makeLayerBase(-1, "Ice Caves", grid, {
        resourceNodes = resourceNodes,
        safeSleepSpots = {
            annotatedCoord(78, 21, {biome = "Warm Refuge Pockets", biomeId = "warm_refuge_pockets"}),
        },
        pointsOfInterest = {
            {name = "Ice Cave Mouth", coord = worldCoord(entrance.x, entrance.y), biome = "Frozen Tunnels", biomeId = "frozen_tunnels", rewardTier = "route", depth = -1},
            {name = "Coal Pocket", coord = worldCoord(74, 21), biome = "Coal Pockets", biomeId = "coal_pockets", rewardTier = "medium", depth = -1},
            {name = "Subglacial Cache", coord = worldCoord(60, 36), biome = "Subglacial Pools", biomeId = "subglacial_pools", rewardTier = "high", depth = -1},
            {name = "Brittle Ice Shelf", coord = worldCoord(84, 26), biome = "Brittle Ice Shelves", biomeId = "brittle_ice_shelves", rewardTier = "medium", depth = -1},
            {name = "Lower Descent", coord = worldCoord(descent.x, descent.y), biome = "Frozen Tunnels", biomeId = "frozen_tunnels", rewardTier = "route", depth = -1},
        },
        hazardZones = {
            {type = "weak_ice", name = "Subglacial Pool", zone = icePocket, biomeId = "subglacial_pools"},
            {type = "weak_ice", name = "Brittle Ice Shelf", zone = brittleShelf, biomeId = "brittle_ice_shelves"},
            {type = "cave_cold", name = "Frozen Tunnels", zone = makeZone(2, 2, width - 2, height - 2), exposureModifier = -4, biomeId = "frozen_tunnels"},
        },
        temperatureBands = {
            {type = "warm_pocket", zone = warmPocket, modifier = 5, biomeId = "warm_refuge_pockets"},
        },
        biomes = {
            {id = "frozen_tunnels", name = "Frozen Tunnels", zone = frozenTunnel, hazardType = "cave_cold", traversalTags = {"underground", "route"}},
            {id = "subglacial_pools", name = "Subglacial Pools", zone = icePocket, hazardType = "weak_ice", traversalTags = {"ice", "hazard"}},
            {id = "coal_pockets", name = "Coal Pockets", zone = coalPocket, resourceType = "charcoal", traversalTags = {"resource", "scarce"}},
            {id = "brittle_ice_shelves", name = "Brittle Ice Shelves", zone = brittleShelf, hazardType = "weak_ice", traversalTags = {"ice", "high-risk"}},
            {id = "warm_refuge_pockets", name = "Warm Refuge Pockets", zone = warmPocket, resourceType = "shelter", traversalTags = {"safe", "rest"}},
        },
        spawnRules = {
            {id = "ice_cave_wolves", kind = "wolf", listName = "wolves", cap = 2, chancePerHour = 0.04, cooldownHours = 1.5, zone = frozenTunnel, minDistanceTiles = 8, allowedTiles = {"cave_floor", "ice", "fire_safe"}, blockedTiles = {"weak_ice", "thermal_fissure"}, blockedHazards = {"weak_ice"}},
            {id = "warm_refuge_rabbits", kind = "rabbit", listName = "rabbits", cap = 1, chancePerHour = 0.02, cooldownHours = 2, zone = warmPocket, minDistanceTiles = 6, allowedTiles = {"cave_floor", "fire_safe"}, blockedHazards = {"weak_ice"}},
        },
        links = {
            {kind = "stair", fromDepth = -1, toDepth = 0, x = entrance.x, y = entrance.y},
            {kind = "stair", fromDepth = -1, toDepth = -2, x = descent.x, y = descent.y},
        },
    })
end

local function makeDeepRuinsLevel(width, height, seed)
    local grid = smoothLayer(makeLayerGrid(width, height, "shale", "cave_wall", seed, 0.62), "shale", "cave_wall", 2)
    local ascent = {x = 82, y = 24}
    local cache = {x = 94, y = 34}
    local supply = {x = 72, y = 42}
    local shelter = {x = 92, y = 32}
    local fissureZone = makeZone(88, 28, 18, 12)
    local ruinZone = makeZone(72, 22, 28, 20)
    local collapsedMine = makeZone(62, 32, 22, 18)
    local shaleChamber = makeZone(80, 18, 18, 12)
    local shelterZone = makeZone(89, 30, 8, 6)

    fillRect(grid, ruinZone.x, ruinZone.y, ruinZone.width, ruinZone.height, "shale")
    fillRect(grid, collapsedMine.x, collapsedMine.y, collapsedMine.width, collapsedMine.height, "shale")
    paintNoisePatch(grid, collapsedMine, "rock", seed + 4, 0.84)
    fillRect(grid, shaleChamber.x, shaleChamber.y, shaleChamber.width, shaleChamber.height, "shale")
    paintNoisePatch(grid, shaleChamber, "cave_wall", seed + 5, 0.9)
    paintNoisePatch(grid, fissureZone, "thermal_fissure", seed + 7, 0.68)
    carvePathAs(grid, ascent.x, ascent.y, cache.x, cache.y, "shale")
    carvePathAs(grid, cache.x, cache.y, supply.x, supply.y, "shale")
    carvePathAs(grid, shelter.x, shelter.y, cache.x, cache.y, "shale")
    fillRect(grid, shelterZone.x, shelterZone.y, shelterZone.width, shelterZone.height, "fire_safe")
    protectLayerAnchors(grid, {
        {x = ascent.x, y = ascent.y, tile = "stair_up"},
        {x = cache.x, y = cache.y, tile = "shale"},
        {x = supply.x, y = supply.y, tile = "shale"},
        {x = shelter.x, y = shelter.y, tile = "fire_safe"},
        {x = 86, y = 22, tile = "shale"},
    })

    local resourceNodes = {}
    addLayerResource(resourceNodes, "cache", cache.x, cache.y, {
        Items.create("signal_bolt", 1),
        Items.create("charcoal", 2),
        Items.create("accelerant", 1),
    }, "Supply Caches", {biomeId = "supply_caches", name = "Thermal Cache"})
    addLayerResource(resourceNodes, "loot", supply.x, supply.y, {Items.create("antiseptic", 1), Items.create("arrow", 2)}, "Collapsed Mine Corridors", {biomeId = "collapsed_mine_corridors", name = "Abandoned Mine Pack"})
    addLayerResource(resourceNodes, "loot", 86, 22, {Items.create("charcoal", 2), Items.create("tinder", 1)}, "Shale Chambers", {biomeId = "shale_chambers", name = "Dry Shale Niche"})

    return makeLayerBase(-2, "Deep Ruins", grid, {
        resourceNodes = resourceNodes,
        safeSleepSpots = {
            annotatedCoord(shelter.x, shelter.y, {biome = "Ruin Shelters", biomeId = "ruin_shelters"}),
        },
        pointsOfInterest = {
            {name = "Deep Ruin Ascent", coord = worldCoord(ascent.x, ascent.y), biome = "Shale Chambers", biomeId = "shale_chambers", rewardTier = "route", depth = -2},
            {name = "Thermal Cache", coord = worldCoord(cache.x, cache.y), biome = "Supply Caches", biomeId = "supply_caches", rewardTier = "high", depth = -2},
            {name = "Collapsed Mine Pack", coord = worldCoord(supply.x, supply.y), biome = "Collapsed Mine Corridors", biomeId = "collapsed_mine_corridors", rewardTier = "medium", depth = -2},
            {name = "Ruin Shelter", coord = worldCoord(shelter.x, shelter.y), biome = "Ruin Shelters", biomeId = "ruin_shelters", rewardTier = "safe", depth = -2},
        },
        hazardZones = {
            {type = "thermal_fissure", name = "Thermal Fissure Fields", zone = fissureZone, exposureModifier = 4, biomeId = "thermal_fissure_fields"},
            {type = "collapse", name = "Collapsed Mine Corridors", zone = collapsedMine, sprainMultiplier = 1.6, biomeId = "collapsed_mine_corridors"},
            {type = "deep_dark", name = "Deep Ruins", zone = makeZone(2, 2, width - 2, height - 2), visibilityPenalty = 2, exposureModifier = -5, biomeId = "shale_chambers"},
        },
        temperatureBands = {
            {type = "thermal_fissure", zone = fissureZone, modifier = 8, biomeId = "thermal_fissure_fields"},
            {type = "shelter", zone = shelterZone, modifier = 5, biomeId = "ruin_shelters"},
        },
        biomes = {
            {id = "collapsed_mine_corridors", name = "Collapsed Mine Corridors", zone = collapsedMine, hazardType = "collapse", traversalTags = {"underground", "blocked"}},
            {id = "shale_chambers", name = "Shale Chambers", zone = shaleChamber, hazardType = "deep_dark", traversalTags = {"underground", "route"}},
            {id = "thermal_fissure_fields", name = "Thermal Fissure Fields", zone = fissureZone, hazardType = "thermal_fissure", traversalTags = {"thermal", "high-risk"}},
            {id = "supply_caches", name = "Supply Caches", zone = makeZone(cache.x - 2, cache.y - 2, 6, 5), resourceType = "cache", traversalTags = {"resource", "endurance"}},
            {id = "ruin_shelters", name = "Ruin Shelters", zone = shelterZone, resourceType = "shelter", traversalTags = {"safe", "rest"}},
        },
        spawnRules = {
            {id = "deep_ruin_raiders", kind = "raider", listName = "raiders", cap = 2, chancePerHour = 0.035, cooldownHours = 1.75, zone = collapsedMine, minDistanceTiles = 8, allowedTiles = {"shale", "fire_safe"}, blockedTiles = {"rock", "cave_wall", "thermal_fissure"}, blockedHazards = {"thermal_fissure"}},
            {id = "shale_chamber_wolves", kind = "wolf", listName = "wolves", cap = 1, chancePerHour = 0.025, cooldownHours = 2.25, zone = shaleChamber, minDistanceTiles = 8, allowedTiles = {"shale", "fire_safe"}, blockedTiles = {"cave_wall", "thermal_fissure"}, blockedHazards = {"thermal_fissure"}},
        },
        links = {
            {kind = "stair", fromDepth = -2, toDepth = -1, x = ascent.x, y = ascent.y},
        },
    })
end

local function makeRidgeLevel(width, height, seed)
    local grid = makeLayerGrid(width, height, "snow", "rock", seed, 0.78)
    local entry = {x = 100, y = 20}
    local station = {x = 112, y = 28}
    local cache = {x = 120, y = 36}
    local ridgeZone = makeZone(94, 14, 30, 24)
    local pathZone = makeZone(96, 18, 22, 12)
    local breakZone = makeZone(100, 22, 22, 14)
    local driftZone = makeZone(88, 34, 28, 16)
    local stationZone = makeZone(station.x - 2, station.y - 2, 7, 5)
    local cacheZone = makeZone(cache.x - 2, cache.y - 2, 6, 5)

    fillRect(grid, ridgeZone.x, ridgeZone.y, ridgeZone.width, ridgeZone.height, "snow")
    paintNoisePatch(grid, ridgeZone, "rock", seed + 11, 0.82)
    fillRect(grid, pathZone.x, pathZone.y, pathZone.width, pathZone.height, "snow")
    paintNoisePatch(grid, pathZone, "path", seed + 10, 0.72)
    paintNoisePatch(grid, breakZone, "tree", seed + 12, 0.9)
    paintNoisePatch(grid, breakZone, "rock", seed + 13, 0.88)
    paintNoisePatch(grid, driftZone, "ice", seed + 14, 0.84)
    paintNoisePatch(grid, driftZone, "weak_ice", seed + 15, 0.91)
    carvePathAs(grid, entry.x, entry.y, station.x, station.y, "path")
    carvePathAs(grid, station.x, station.y, cache.x, cache.y, "path")
    setTile(grid, entry.x, entry.y, "stair_down")
    fillRect(grid, stationZone.x, stationZone.y, stationZone.width, stationZone.height, "cabin_floor")
    setTile(grid, station.x + 1, station.y, "cabin_workbench")
    setTile(grid, station.x + 2, station.y, "cabin_stove")
    protectLayerAnchors(grid, {
        {x = entry.x, y = entry.y, tile = "stair_down"},
        {x = station.x, y = station.y, tile = "cabin_floor"},
        {x = station.x + 1, y = station.y, tile = "cabin_workbench"},
        {x = station.x + 2, y = station.y, tile = "cabin_stove"},
        {x = cache.x, y = cache.y, tile = "path"},
        {x = 106, y = 30, tile = "snow"},
    })

    local resourceNodes = {}
    addLayerResource(resourceNodes, "cache", station.x + 2, station.y + 1, {
        Items.create("survey_kit", 1),
        Items.create("water", 1),
        Items.create("canned_food", 1),
    }, "Weather Station Grounds", {biomeId = "weather_station_grounds", name = "Weather Station Locker"})
    addLayerResource(resourceNodes, "loot", cache.x, cache.y, {Items.create("flare", 1), Items.create("charcoal", 1)}, "Emergency Caches", {biomeId = "emergency_caches", name = "Ridge Emergency Cache"})
    addLayerResource(resourceNodes, "wood", 106, 30, {Items.create("sticks", 2), Items.create("firewood", 1)}, "Tree and Rock Breaks", {biomeId = "tree_rock_breaks", name = "Windbreak Deadfall"})

    return makeLayerBase(1, "Exposed Ridge", grid, {
        resourceNodes = resourceNodes,
        safeSleepSpots = {
            annotatedCoord(station.x, station.y, {biome = "Weather Station Grounds", biomeId = "weather_station_grounds"}),
        },
        pointsOfInterest = {
            {name = "Ridge Approach", coord = worldCoord(entry.x, entry.y), biome = "Wind-Scoured Paths", biomeId = "wind_scoured_paths", rewardTier = "route", depth = 1},
            {name = "Ridge Weather Station", coord = worldCoord(station.x, station.y), biome = "Weather Station Grounds", biomeId = "weather_station_grounds", rewardTier = "endgame", depth = 1},
            {name = "Ridge Emergency Cache", coord = worldCoord(cache.x, cache.y), biome = "Emergency Caches", biomeId = "emergency_caches", rewardTier = "medium", depth = 1},
            {name = "Exposed Drift Field", coord = worldCoord(96, 40), biome = "Exposed Drifts", biomeId = "exposed_drifts", rewardTier = "hazard", depth = 1},
        },
        hazardZones = {
            {type = "exposed_blizzard", name = "Exposed Ridge", zone = ridgeZone, exposureModifier = -8, visibilityPenalty = 1, biomeId = "wind_scoured_paths"},
            {type = "weak_ice", name = "Exposed Drift Field", zone = driftZone, exposureModifier = -3, biomeId = "exposed_drifts"},
        },
        temperatureBands = {
            {type = "shelter", zone = stationZone, modifier = 7, biomeId = "weather_station_grounds"},
        },
        biomes = {
            {id = "wind_scoured_paths", name = "Wind-Scoured Paths", zone = pathZone, hazardType = "exposed_blizzard", traversalTags = {"route", "open"}},
            {id = "tree_rock_breaks", name = "Tree and Rock Breaks", zone = breakZone, resourceType = "wood", traversalTags = {"resource", "windbreak"}},
            {id = "exposed_drifts", name = "Exposed Drifts", zone = driftZone, hazardType = "weak_ice", traversalTags = {"hazard", "open"}},
            {id = "weather_station_grounds", name = "Weather Station Grounds", zone = stationZone, resourceType = "shelter", traversalTags = {"endgame", "safe"}},
            {id = "emergency_caches", name = "Emergency Caches", zone = cacheZone, resourceType = "cache", traversalTags = {"resource", "route"}},
        },
        spawnRules = {
            {id = "ridge_scavenger_raiders", kind = "raider", listName = "raiders", cap = 1, chancePerHour = 0.02, cooldownHours = 2, zone = breakZone, minDistanceTiles = 10, allowedTiles = {"snow", "path"}, blockedTiles = {"rock", "tree", "weak_ice"}, blockedHazards = {"weak_ice"}},
            {id = "ridge_deer", kind = "deer", listName = "deer", cap = 1, chancePerHour = 0.015, cooldownHours = 2.5, zone = ridgeZone, minDistanceTiles = 10, allowedTiles = {"snow", "path", "ice"}, blockedTiles = {"rock", "tree", "weak_ice"}, blockedHazards = {"weak_ice"}},
        },
        links = {
            {kind = "stair", fromDepth = 1, toDepth = 0, x = entry.x, y = entry.y},
        },
        goals = {
            {id = "activate_ridge_weather_station", label = "Activate the ridge weather station", poi = "Ridge Weather Station", completed = false},
        },
    })
end

local function makeSurfaceLevel(generated)
    return makeLayerBase(0, "Frozen Surface", generated.grid, {
        data = makeDataGrid(generated.grid),
        structures = generated.structures,
        resourceNodes = generated.resourceNodes,
        fires = generated.fires,
        traps = generated.traps,
        carcasses = generated.carcasses,
        fishingSpots = generated.fishingSpots,
        climbNodes = generated.climbNodes,
        mapNodes = generated.mapNodes,
        workbenches = generated.workbenches,
        curingStations = generated.curingStations,
        curing = generated.curing,
        snowShelters = generated.snowShelters,
        gates = generated.gates,
        npcEncounters = generated.npcEncounters,
        wildlife = generated.wildlife,
        pointsOfInterest = generated.pointsOfInterest,
        safeSleepSpots = generated.safeSleepSpots,
        hazardZones = generated.hazardZones,
        temperatureBands = generated.temperatureBands,
        biomes = generated.biomes,
        spawnRules = generated.spawnRules,
        goals = generated.goals,
        links = {
            {kind = "stair", fromDepth = 0, toDepth = -1, x = 80, y = 22},
            {kind = "stair", fromDepth = 0, toDepth = 1, x = 100, y = 20},
        },
    })
end

local function buildLayeredLevels(generated, width, height)
    local seed = math.random(100000, 999999)
    local levels = {
        [0] = makeSurfaceLevel(generated),
        [-1] = makeIceCaveLevel(width, height, seed + 1),
        [-2] = makeDeepRuinsLevel(width, height, seed + 2),
        [1] = makeRidgeLevel(width, height, seed + 3),
    }

    setTile(levels[0].grid, 80, 22, "stair_down")
    setTile(levels[0].grid, 100, 20, "stair_up")
    return levels
end

local function generateProceduralRunData(difficultyName)
    local difficultyKey = CONFIG.DIFFICULTY_ALIASES[difficultyName] or difficultyName
    local difficulty = CONFIG.DIFFICULTY_SETTINGS[difficultyKey] or CONFIG.DIFFICULTY_SETTINGS.voyageur
    local width = CONFIG.WORLD_GRID_WIDTH
    local height = CONFIG.WORLD_GRID_HEIGHT
    local grid = newGrid(width, height)
    buildBorder(grid)

    local frontierZone = makeZone(6, 8, 22, 18)
    local wetlandZone = makeZone(30, 8, 24, 24)
    local highlandZone = makeZone(58, 8, 24, 20)
    local glacierZone = makeZone(88, 8, 28, 20)
    local forestZone = makeZone(14, 42, 28, 30)
    local basinZone = makeZone(52, 40, 32, 28)
    local ashZone = makeZone(90, 42, 32, 26)
    local hiddenValeZone = makeZone(108, 78, 24, 18)

    local regions = {
        {
            id = "frontier_reach",
            name = "Frontier Reach",
            biome = "Boreal Forest",
            role = "safe_fringe",
            zone = frontierZone,
            shelterDensity = "high",
            visibilityPressure = 1,
            hazardIntensity = 1,
            traversalRequirements = {},
        },
        {
            id = "frozen_wetlands",
            name = "Frozen Wetlands",
            biome = "Frozen Wetlands",
            role = "hostile_transit",
            zone = wetlandZone,
            shelterDensity = "low",
            visibilityPressure = 2,
            hazardIntensity = 3,
            traversalRequirements = {},
        },
        {
            id = "ravine_highlands",
            name = "Ravine Highlands",
            biome = "Rocky Highlands",
            role = "landmark",
            zone = highlandZone,
            shelterDensity = "medium",
            visibilityPressure = 2,
            hazardIntensity = 3,
            traversalRequirements = {},
        },
        {
            id = "glacial_step",
            name = "Glacial Step",
            biome = "Glacial Shelf",
            role = "hostile_transit",
            zone = glacierZone,
            shelterDensity = "low",
            visibilityPressure = 3,
            hazardIntensity = 4,
            traversalRequirements = {},
        },
        {
            id = "old_forest",
            name = "Old Forest",
            biome = "Boreal Forest",
            role = "resource_dead_end",
            zone = forestZone,
            shelterDensity = "medium",
            visibilityPressure = 2,
            hazardIntensity = 2,
            traversalRequirements = {},
        },
        {
            id = "shattered_basin",
            name = "Shattered Basin",
            biome = "Shale Basin",
            role = "resource_dead_end",
            zone = basinZone,
            shelterDensity = "low",
            visibilityPressure = 2,
            hazardIntensity = 4,
            traversalRequirements = {"rope_bolt", "bridge_kit"},
        },
        {
            id = "ash_barrens",
            name = "Ash Barrens",
            biome = "Ash Barrens",
            role = "landmark",
            zone = ashZone,
            shelterDensity = "low",
            visibilityPressure = 1,
            hazardIntensity = 5,
            traversalRequirements = {},
        },
        {
            id = "hidden_vale",
            name = "Hidden Vale",
            biome = "Hidden Vale",
            role = "gated_shortcut",
            zone = hiddenValeZone,
            shelterDensity = "low",
            visibilityPressure = 1,
            hazardIntensity = 3,
            traversalRequirements = {"signal_bolt"},
        },
    }

    local biomes = {
        {
            id = "boreal_forest",
            name = "Boreal Forest",
            zone = forestZone,
            hazardType = "dense_woods",
            spawnTables = {loot = "forager", wildlife = {"rabbit", "wolf"}, npc = {"injured_survivor", "roaming_trader"}},
            traversalTags = {"cover", "wood-rich"},
        },
        {
            id = "frontier_boreal",
            name = "Boreal Frontier",
            zone = frontierZone,
            hazardType = "shelter",
            spawnTables = {loot = "starter", wildlife = {"rabbit"}, npc = {"rumor_giver"}},
            traversalTags = {"safe", "mapped"},
        },
        {
            id = "frozen_wetlands",
            name = "Frozen Wetlands",
            zone = wetlandZone,
            hazardType = "weak_ice",
            spawnTables = {loot = "survival_cache", wildlife = {"deer"}, npc = {"rival_explorer"}},
            traversalTags = {"slick", "exposed"},
        },
        {
            id = "rocky_highlands",
            name = "Rocky Highlands",
            zone = highlandZone,
            hazardType = "ridge",
            spawnTables = {loot = "climber", wildlife = {"wolf"}, npc = {"rumor_giver"}},
            traversalTags = {"chokepoint", "elevation"},
        },
        {
            id = "glacial_shelf",
            name = "Glacial Shelf",
            zone = glacierZone,
            hazardType = "exposed_blizzard",
            spawnTables = {loot = "survey", wildlife = {"wolf"}, npc = {"rival_explorer"}},
            traversalTags = {"open", "survey"},
        },
        {
            id = "shale_basin",
            name = "Shale Basin",
            zone = basinZone,
            hazardType = "ridge",
            spawnTables = {loot = "bridge", wildlife = {"raider"}, npc = {"scavenger"}},
            traversalTags = {"broken", "scarce"},
        },
        {
            id = "ash_barrens",
            name = "Ash Barrens",
            zone = ashZone,
            hazardType = "ash_barrens",
            spawnTables = {loot = "combat", wildlife = {"raider"}, npc = {"roaming_trader", "scavenger"}},
            traversalTags = {"open", "high-risk"},
        },
        {
            id = "hidden_vale",
            name = "Hidden Vale",
            zone = hiddenValeZone,
            hazardType = "hidden_vale",
            spawnTables = {loot = "cache", wildlife = {"deer"}, npc = {"injured_survivor"}},
            traversalTags = {"hidden", "reward"},
        },
    }

    local function paintZone(zone, tile)
        fillRect(grid, zone.x, zone.y, zone.width, zone.height, tile)
    end

    paintZone(frontierZone, "snow")
    paintZone(wetlandZone, "snow")
    paintZone(highlandZone, "shale")
    paintZone(glacierZone, "ice")
    paintZone(forestZone, "moss")
    paintZone(basinZone, "shale")
    paintZone(ashZone, "ash")
    paintZone(hiddenValeZone, "moss")

    local weakIceTiles = {}
    for y = wetlandZone.y + 2, wetlandZone.y + wetlandZone.height - 3 do
        for x = wetlandZone.x + 2, wetlandZone.x + wetlandZone.width - 3 do
            if (x + y) % 4 == 0 then
                setTile(grid, x, y, "ice")
            end
            if (x * 3 + y) % 11 == 0 then
                setTile(grid, x, y, "weak_ice")
                table.insert(weakIceTiles, {x = x, y = y})
            end
        end
    end
    for y = forestZone.y, forestZone.y + forestZone.height - 1 do
        for x = forestZone.x, forestZone.x + forestZone.width - 1 do
            if (x + y) % 3 == 0 then
                setTile(grid, x, y, "tree")
            end
        end
    end
    for y = frontierZone.y + 1, frontierZone.y + frontierZone.height - 2 do
        for x = frontierZone.x + 1, frontierZone.x + frontierZone.width - 2 do
            if (x + y) % 7 == 0 then
                setTile(grid, x, y, "tree")
            end
        end
    end
    for y = highlandZone.y, highlandZone.y + highlandZone.height - 1 do
        for x = highlandZone.x, highlandZone.x + highlandZone.width - 1 do
            if (x + y) % 5 == 0 then
                setTile(grid, x, y, "rock")
            end
        end
    end
    for y = basinZone.y, basinZone.y + basinZone.height - 1 do
        for x = basinZone.x, basinZone.x + basinZone.width - 1 do
            if (x * 2 + y) % 5 ~= 0 then
                setTile(grid, x, y, "rock")
            end
        end
    end
    for y = ashZone.y, ashZone.y + ashZone.height - 1 do
        for x = ashZone.x, ashZone.x + ashZone.width - 1 do
            if (x + y) % 6 == 0 then
                setTile(grid, x, y, "rock")
            end
        end
    end

    fillRect(grid, 46, 48, 8, 6, "fire_safe")
    fillRect(grid, 104, 54, 6, 5, "fire_safe")

    local structures = {
        addCabin(grid, 9, 11, "Frontier Cabin"),
        addCabin(grid, 22, 57, "Trapline Cabin"),
        addCave(grid, 66, 15, 9, 6),
        addCabin(grid, 104, 50, "Weather Station", 8, 6),
    }

    local route = {
        structures[1].door,
        {x = 24, y = 18},
        {x = 32, y = 20},
        {x = 44, y = 20},
        {x = 58, y = 18},
        structures[3].mouth,
        {x = 86, y = 18},
        {x = 96, y = 18},
        {x = 104, y = 26},
        {x = 106, y = 40},
        structures[4].door,
    }
    for index = 1, #route - 1 do
        carvePath(grid, route[index].x, route[index].y, route[index + 1].x, route[index + 1].y)
    end
    carvePath(grid, 38, 24, 28, 58)
    carvePath(grid, 28, 58, structures[2].door.x, structures[2].door.y)
    carvePath(grid, 74, 22, 98, 22)
    carvePath(grid, 102, 60, 114, 86)
    carvePath(grid, 28, 58, 66, 56)
    carvePath(grid, 56, 58, 66, 56)
    carvePath(grid, 68, 46, 66, 56)

    local regionIdsByCoord = {
        frontier_reach = frontierZone,
        frozen_wetlands = wetlandZone,
        ravine_highlands = highlandZone,
        glacial_step = glacierZone,
        old_forest = forestZone,
        shattered_basin = basinZone,
        ash_barrens = ashZone,
        hidden_vale = hiddenValeZone,
    }

    local gates = {
        {
            id = "anchor_cliff",
            name = "Anchor Cliff",
            kind = "anchored_cliff",
            coord = worldCoord(78, 24),
            targetCoord = worldCoord(68, 46),
            regionId = "ravine_highlands",
            toRegionId = "shattered_basin",
            toolType = "rope_bolt",
            ammoKind = "rope_bolt",
            unlockState = false,
            persistent = true,
            revealed = true,
        },
        {
            id = "broken_bridge",
            name = "Broken Bridge",
            kind = "broken_bridge",
            coord = worldCoord(44, 58),
            targetCoord = worldCoord(56, 58),
            regionId = "old_forest",
            toRegionId = "shattered_basin",
            toolType = "bridge_kit",
            repairCost = {bridge_kit = 1},
            unlockState = false,
            persistent = true,
            revealed = true,
        },
        {
            id = "signal_post",
            name = "Signal Post",
            kind = "signal_post",
            coord = worldCoord(102, 18),
            targetCoord = worldCoord(114, 84),
            regionId = "glacial_step",
            toRegionId = "hidden_vale",
            toolType = "signal_bolt",
            ammoKind = "signal_bolt",
            unlockState = false,
            persistent = true,
            revealed = false,
            hidden = true,
            requiresWeapon = "bow",
        },
    }

    local connections = {
        {fromRegionId = "frontier_reach", toRegionId = "frozen_wetlands", status = "open", critical = true},
        {fromRegionId = "frozen_wetlands", toRegionId = "ravine_highlands", status = "open", critical = true},
        {fromRegionId = "ravine_highlands", toRegionId = "glacial_step", status = "open", critical = true},
        {fromRegionId = "glacial_step", toRegionId = "ash_barrens", status = "open", critical = true},
        {fromRegionId = "frozen_wetlands", toRegionId = "old_forest", status = "open", critical = false},
        {fromRegionId = "ravine_highlands", toRegionId = "shattered_basin", status = "gated", critical = false, gateId = "anchor_cliff"},
        {fromRegionId = "old_forest", toRegionId = "shattered_basin", status = "gated", critical = false, gateId = "broken_bridge"},
        {fromRegionId = "glacial_step", toRegionId = "hidden_vale", status = "hidden", critical = false, gateId = "signal_post"},
    }

    local resourceNodes = {}
    local workbenches = {
        makeWorkbench(structures[1].workbench.x, structures[1].workbench.y, "Frontier Workbench"),
        makeWorkbench(structures[2].workbench.x, structures[2].workbench.y, "Trapline Workbench"),
        makeWorkbench(structures[4].workbench.x, structures[4].workbench.y, "Weather Station Workbench"),
    }
    local curingStations = {
        makeCuringStation(structures[1].workbench.x, structures[1].workbench.y, "Frontier Curing Rack"),
        makeCuringStation(structures[2].workbench.x, structures[2].workbench.y, "Trapline Curing Rack"),
    }
    local mapNodes = {
        makeMapNode(18, 18, "Frontier Survey Point"),
        makeMapNode(70, 20, "Ravine Overlook"),
        makeMapNode(98, 18, "Glacial Survey Point"),
        makeMapNode(108, 52, "Weather Station Antenna"),
    }
    mapNodes[1].survey = true
    mapNodes[2].survey = true
    mapNodes[3].survey = true
    mapNodes[4].survey = true
    local climbNodes = {
        makeClimbNode(70, 22, 70, 34, "Highland Rope"),
    }
    local fishingSpots = {
        makeFishingSpot(38, 18, "Marsh Fishing Hole"),
        makeFishingSpot(48, 24, "Thin Ice Pool"),
    }
    local carcasses = {
        makeCarcass("deer", 34, 24),
        makeCarcass("rabbit", 30, 60),
    }
    local safeSleepSpots = {
        worldCoord(structures[1].bed.x, structures[1].bed.y),
        worldCoord(structures[2].bed.x, structures[2].bed.y),
        worldCoord(structures[3].bed.x, structures[3].bed.y),
        worldCoord(structures[4].bed.x, structures[4].bed.y),
    }

    local pointsOfInterest = {
        {name = "Frontier Cabin", coord = worldCoord(structures[1].bed.x, structures[1].bed.y), biome = "Boreal Frontier", rewardTier = "safe", regionId = "frontier_reach"},
        {name = "Frozen Marsh", coord = worldCoord(40, 20), biome = "Frozen Wetlands", rewardTier = "medium", regionId = "frozen_wetlands"},
        {name = "North Ravine", coord = worldCoord(structures[3].mouth.x, structures[3].mouth.y), biome = "Rocky Highlands", rewardTier = "medium", regionId = "ravine_highlands"},
        {name = "Glacial Beacon", coord = worldCoord(100, 18), biome = "Glacial Shelf", rewardTier = "medium", regionId = "glacial_step"},
        {name = "Trapline Cabin", coord = worldCoord(structures[2].bed.x, structures[2].bed.y), biome = "Boreal Forest", rewardTier = "medium", regionId = "old_forest"},
        {name = "Shattered Basin", coord = worldCoord(66, 56), biome = "Shale Basin", rewardTier = "high", regionId = "shattered_basin"},
        {name = "Weather Station", coord = worldCoord(structures[4].bed.x, structures[4].bed.y), biome = "Ash Barrens", rewardTier = "high", regionId = "ash_barrens"},
        {name = "Hidden Vale Cache", coord = worldCoord(118, 86), biome = "Hidden Vale", rewardTier = "high", regionId = "hidden_vale", hidden = true, revealed = false},
    }
    local landmarks = {
        {name = "Frontier Cabin", coord = worldCoord(structures[1].bed.x, structures[1].bed.y), regionId = "frontier_reach", discoveryValue = "safe"},
        {name = "North Ravine", coord = worldCoord(structures[3].mouth.x, structures[3].mouth.y), regionId = "ravine_highlands", discoveryValue = "path"},
        {name = "Glacial Beacon", coord = worldCoord(100, 18), regionId = "glacial_step", discoveryValue = "survey"},
        {name = "Weather Station", coord = worldCoord(structures[4].bed.x, structures[4].bed.y), regionId = "ash_barrens", discoveryValue = "goal"},
        {name = "Hidden Vale Cache", coord = worldCoord(118, 86), regionId = "hidden_vale", discoveryValue = "secret", hidden = true, revealed = false},
    }
    local traversalRequirements = {
        {toolType = "rope_bolt", label = "Rope Bolts", gateKinds = {"anchored_cliff"}},
        {toolType = "bridge_kit", label = "Bridge Kits", gateKinds = {"broken_bridge"}},
        {toolType = "signal_bolt", label = "Signal Bolts", gateKinds = {"signal_post"}},
    }

    addResourceNode(resourceNodes, "cache", structures[1].x + 3, structures[1].y + 2, {
        loot = {Items.create("canned_food", 1), Items.create("rope_bolt", 1), Items.create("water", 1)},
        biome = "Boreal Frontier",
        rewardTier = "safe",
        regionId = "frontier_reach",
    })
    addResourceNode(resourceNodes, "cache", structures[2].x + 3, structures[2].y + 2, {
        loot = {Items.create("bridge_kit", 1), Items.create("sticks", 2), Items.create("cloth", 1)},
        biome = "Boreal Forest",
        rewardTier = "medium",
        regionId = "old_forest",
    })
    addResourceNode(resourceNodes, "cache", structures[4].x + 4, structures[4].y + 3, {
        loot = {Items.create("signal_bolt", 2), Items.create("survey_kit", 1), Items.create("charcoal", 1)},
        biome = "Ash Barrens",
        rewardTier = "high",
        regionId = "ash_barrens",
    })
    addResourceNode(resourceNodes, "cache", 118, 86, {
        loot = {
            Items.create("canned_food", 2),
            Items.create("water", 2),
            Items.create("matches", 4),
            Items.create("charcoal", 1),
            Items.create("sword", 1),
            Items.create("rope_bolt", 2),
        },
        biome = "Hidden Vale",
        rewardTier = "high",
        regionId = "hidden_vale",
        hidden = true,
        revealed = false,
    })

    local routeLoot = {
        {18, 28}, {34, 34}, {50, 18}, {74, 28}, {98, 24}, {112, 42}, {34, 62}, {72, 60},
    }
    for _, coord in ipairs(routeLoot) do
        local biome = biomeForTile(biomes, coord[1], coord[2])
        addResourceNode(resourceNodes, "loot", coord[1], coord[2], {
            loot = randomLoot(),
            biome = biome and biome.name or "Frontier",
            rewardTier = biome and (biome.id == "ash_barrens" and "high" or "medium") or "medium",
            regionId = biome and (biome.id == "frontier_boreal" and "frontier_reach"
                or biome.id == "frozen_wetlands" and "frozen_wetlands"
                or biome.id == "rocky_highlands" and "ravine_highlands"
                or biome.id == "glacial_shelf" and "glacial_step"
                or biome.id == "shale_basin" and "shattered_basin"
                or biome.id == "ash_barrens" and "ash_barrens"
                or biome.id == "boreal_forest" and "old_forest"
                or biome.id == "hidden_vale" and "hidden_vale"
                or nil),
        })
    end

    local woodCandidates = {}
    for y = 2, gridHeight(grid) - 1 do
        for x = 2, gridWidth(grid) - 1 do
            if canPlaceResource(grid, x, y) then
                local biome = biomeForTile(biomes, x, y)
                if biome and (biome.id == "frontier_boreal" or biome.id == "boreal_forest") then
                    table.insert(woodCandidates, {x = x, y = y, biome = biome.name})
                end
            end
        end
    end
    Utils.shuffle(woodCandidates)
    for index = 1, 16 do
        local candidate = woodCandidates[index]
        if candidate then
            addResourceNode(resourceNodes, "wood", candidate.x, candidate.y, {
                loot = {
                    Items.create("sticks", math.random(2, 4)),
                    Items.create("firewood", 1),
                    Items.create("snow", 1),
                },
                biome = candidate.biome,
                rewardTier = "safe",
            })
        end
    end

    local hazardZones = {
        {type = "weak_ice", name = "Frozen Marsh", zone = wetlandZone},
        {type = "ridge", name = "North Ravine", zone = highlandZone, sprainMultiplier = 1.45},
        {type = "exposed_blizzard", name = "Glacial Step", zone = glacierZone, exposureModifier = -6},
        {type = "dense_woods", name = "Old Forest", zone = forestZone, visibilityPenalty = 3},
        {type = "ridge", name = "Shattered Basin", zone = basinZone, sprainMultiplier = 1.6},
        {type = "ash_barrens", name = "Ash Barrens", zone = ashZone, visibilityPenalty = 1, exposureModifier = -4},
        {type = "hidden_vale", name = "Hidden Vale", zone = hiddenValeZone, visibilityPenalty = 1},
    }
    local temperatureBands = {
        {type = "shelter", zone = makeZone(structures[1].x, structures[1].y, structures[1].w, structures[1].h), modifier = 9},
        {type = "shelter", zone = makeZone(structures[2].x, structures[2].y, structures[2].w, structures[2].h), modifier = 8},
        {type = "cave", zone = makeZone(structures[3].x, structures[3].y, structures[3].w, structures[3].h), modifier = 10},
        {type = "shelter", zone = makeZone(structures[4].x, structures[4].y, structures[4].w, structures[4].h), modifier = 7},
        {type = "wetland", zone = wetlandZone, modifier = -6},
        {type = "exposed_blizzard", zone = glacierZone, modifier = -7},
        {type = "ash_barrens", zone = ashZone, modifier = -4},
    }

    local wolves = {}
    for index = 1, difficulty.wolfCount do
        table.insert(wolves, {
            kind = "wolf",
            coord = worldCoord(32 + index * 2, 58 + index * 2),
            territory = forestZone,
            territoryCenter = zoneCenter(forestZone),
            state = "roam",
            target = nil,
            fearHours = 0,
        })
    end
    table.insert(wolves, {
        kind = "wolf",
        coord = worldCoord(94, 20),
        territory = glacierZone,
        territoryCenter = zoneCenter(glacierZone),
        state = "roam",
        target = nil,
        fearHours = 0,
    })

    local raiders = {
        {
            kind = "raider",
            coord = worldCoord(102, 60),
            territory = ashZone,
            territoryCenter = zoneCenter(ashZone),
            state = "roam",
            target = nil,
        },
        {
            kind = "raider",
            coord = worldCoord(72, 58),
            territory = basinZone,
            territoryCenter = zoneCenter(basinZone),
            state = "roam",
            target = nil,
        },
    }

    local rabbitZones = {
        makeZone(10, 18, 8, 6),
        makeZone(24, 56, 10, 8),
    }
    local rabbits = {}
    for _, zone in ipairs(rabbitZones) do
        table.insert(rabbits, {
            kind = "rabbit",
            zone = zone,
            coord = worldCoord(zone.x + 1, zone.y + 1),
            speed = 20,
        })
    end
    local deerZone = makeZone(34, 16, 14, 10)
    local deer = {
        {
            kind = "deer",
            zone = deerZone,
            coord = worldCoord(deerZone.x + 2, deerZone.y + 1),
            speed = 24,
        },
        {
            kind = "deer",
            zone = hiddenValeZone,
            coord = worldCoord(hiddenValeZone.x + 5, hiddenValeZone.y + 4),
            speed = 24,
        },
    }
    local spawnRules = {
        {id = "surface_forest_rabbits", kind = "rabbit", listName = "rabbits", cap = 5, chancePerHour = 0.04, cooldownHours = 1.25, zone = forestZone, minDistanceTiles = 8, allowedTiles = {"snow", "path"}, blockedTiles = {"tree", "rock", "weak_ice"}},
        {id = "surface_deer", kind = "deer", listName = "deer", cap = 3, chancePerHour = 0.025, cooldownHours = 1.75, zone = deerZone, minDistanceTiles = 9, allowedTiles = {"snow", "path"}, blockedTiles = {"tree", "rock", "weak_ice"}},
        {id = "surface_forest_wolves", kind = "wolf", listName = "wolves", cap = difficulty.wolfCount + 2, chancePerHour = 0.03, cooldownHours = 1.5, zone = forestZone, minDistanceTiles = 10, allowedTiles = {"snow", "path"}, blockedTiles = {"tree", "rock", "weak_ice"}},
        {id = "surface_ash_raiders", kind = "raider", listName = "raiders", cap = 3, chancePerHour = 0.018, cooldownHours = 2, zone = ashZone, minDistanceTiles = 10, allowedTiles = {"snow", "ash", "path"}, blockedTiles = {"tree", "rock", "weak_ice"}},
    }

    local npcEncounters = {
        {
            id = "injured_marsh_scout",
            kind = "injured_survivor",
            coord = worldCoord(40, 26),
            regionId = "frozen_wetlands",
            spawnConditions = {requiresBandage = true},
            inventory = {Items.create("rope_bolt", 1)},
            rumors = {{gateId = "anchor_cliff"}},
            resolutionState = "active",
        },
        {
            id = "forest_trader",
            kind = "roaming_trader",
            coord = worldCoord(28, 60),
            regionId = "old_forest",
            spawnConditions = {requiresTrade = true},
            inventory = {Items.create("bridge_kit", 1)},
            rumors = {{poi = "Shattered Basin"}},
            resolutionState = "active",
        },
        {
            id = "glacial_rival",
            kind = "rival_explorer",
            coord = worldCoord(96, 18),
            regionId = "glacial_step",
            spawnConditions = {surveyRoute = true},
            inventory = {},
            rumors = {{gateId = "signal_post"}, {poi = "Hidden Vale Cache"}},
            resolutionState = "active",
        },
        {
            id = "ash_scavenger",
            kind = "scavenger",
            coord = worldCoord(110, 58),
            regionId = "ash_barrens",
            spawnConditions = {occupiesCache = true},
            inventory = {Items.create("signal_bolt", 1)},
            rumors = {{poi = "Weather Station"}},
            resolutionState = "active",
        },
    }

    local playerStart = worldCoord(structures[1].bed.x, structures[1].bed.y)
    local wolfTerritory = forestZone

    local generated = {
        grid = grid,
        playerStart = playerStart,
        structures = structures,
        resourceNodes = resourceNodes,
        fires = {},
        traps = {},
        spawnRules = spawnRules,
        carcasses = carcasses,
        fishingSpots = fishingSpots,
        climbNodes = climbNodes,
        mapNodes = mapNodes,
        workbenches = workbenches,
        curingStations = curingStations,
        curing = {},
        mappedTiles = {},
        pointsOfInterest = pointsOfInterest,
        landmarks = landmarks,
        regions = regions,
        connections = connections,
        gates = gates,
        traversalRequirements = traversalRequirements,
        npcEncounters = npcEncounters,
        goals = {
            {id = "reach_weather_station", label = "Reach the weather station", poi = "Weather Station", completed = false},
            {id = "chart_glacial_step", label = "Survey the Glacial Step", poi = "Glacial Beacon", completed = false},
            {id = "recover_hidden_vale_cache", label = "Find the Hidden Vale Cache", poi = "Hidden Vale Cache", completed = false},
        },
        wildlife = {
            wolves = wolves,
            rabbits = rabbits,
            deer = deer,
            raiders = raiders,
        },
        weather = {
            current = "clear",
            hoursUntilChange = math.random(CONFIG.WEATHER_CHANGE_MIN_HOURS, CONFIG.WEATHER_CHANGE_MAX_HOURS),
        },
        timeOfDay = 8,
        dayCount = 1,
        temperatureBands = temperatureBands,
        hazardZones = hazardZones,
        safeSleepSpots = safeSleepSpots,
        weakIceTiles = weakIceTiles,
        snowShelters = {},
        biomes = biomes,
        wolfTerritory = wolfTerritory,
        rabbitZones = rabbitZones,
        deerZone = deerZone,
        carcassSites = {
            {coord = worldCoord(34, 24), kind = "deer"},
            {coord = worldCoord(30, 60), kind = "rabbit"},
        },
        source = "procedural",
    }
    generated.levels = buildLayeredLevels(generated, width, height)
    World.initialize(generated)
    return generated
end

local function normalizeLayout(layout)
    local lines = (layout and layout.lines) or {}
    local grid = {}
    for y = 1, CONFIG.GRID_HEIGHT do
        local line = lines[y] or ""
        grid[y] = {}
        for x = 1, CONFIG.GRID_WIDTH do
            local symbol = line:sub(x, x)
            grid[y][x] = symbol ~= "" and symbol or " "
        end
    end
    return grid
end

local function firstSymbol(symbolGrid, symbol)
    for y = 1, CONFIG.GRID_HEIGHT do
        for x = 1, CONFIG.GRID_WIDTH do
            if symbolGrid[y][x] == symbol then
                return x, y
            end
        end
    end
    return nil
end

local function collectComponents(symbolGrid, symbol)
    local components = {}
    local visited = {}
    local directions = {
        {1, 0}, {-1, 0}, {0, 1}, {0, -1},
    }

    for y = 1, CONFIG.GRID_HEIGHT do
        visited[y] = {}
    end

    for y = 1, CONFIG.GRID_HEIGHT do
        for x = 1, CONFIG.GRID_WIDTH do
            if symbolGrid[y][x] == symbol and not visited[y][x] then
                local queue = {{x = x, y = y}}
                local index = 1
                local cells = {}
                local minX, maxX = x, x
                local minY, maxY = y, y
                visited[y][x] = true

                while index <= #queue do
                    local current = queue[index]
                    index = index + 1
                    table.insert(cells, current)
                    minX = math.min(minX, current.x)
                    maxX = math.max(maxX, current.x)
                    minY = math.min(minY, current.y)
                    maxY = math.max(maxY, current.y)

                    for _, direction in ipairs(directions) do
                        local nextX = current.x + direction[1]
                        local nextY = current.y + direction[2]
                        if nextX >= 1 and nextX <= CONFIG.GRID_WIDTH
                            and nextY >= 1 and nextY <= CONFIG.GRID_HEIGHT
                            and symbolGrid[nextY][nextX] == symbol
                            and not visited[nextY][nextX] then
                            visited[nextY][nextX] = true
                            table.insert(queue, {x = nextX, y = nextY})
                        end
                    end
                end

                table.insert(components, {
                    cells = cells,
                    x = minX,
                    y = minY,
                    width = maxX - minX + 1,
                    height = maxY - minY + 1,
                })
            end
        end
    end

    return components
end

local function normalizeBounds(component, minWidth, minHeight)
    local centerX = component.x + math.floor((component.width - 1) / 2)
    local centerY = component.y + math.floor((component.height - 1) / 2)
    local width = math.max(component.width, minWidth)
    local height = math.max(component.height, minHeight)
    local maxX = math.max(2, CONFIG.GRID_WIDTH - width)
    local maxY = math.max(2, CONFIG.GRID_HEIGHT - height)

    return {
        x = Utils.clamp(centerX - math.floor(width / 2), 2, maxX),
        y = Utils.clamp(centerY - math.floor(height / 2), 2, maxY),
        width = width,
        height = height,
    }
end

local function applyLayoutTiles(grid, symbolGrid)
    local weakIceTiles = {}
    local shelterCells = {}

    for y = 1, CONFIG.GRID_HEIGHT do
        for x = 1, CONFIG.GRID_WIDTH do
            local symbol = symbolGrid[y][x]
            if symbol == "#" then
                setTile(grid, x, y, "rock")
            elseif symbol == "." then
                setTile(grid, x, y, "snow")
            elseif symbol == " " then
                setTile(grid, x, y, "path")
            elseif symbol == "F" then
                setTile(grid, x, y, "fire_safe")
            elseif symbol == "L" then
                setTile(grid, x, y, "ice")
            elseif symbol == "W" then
                setTile(grid, x, y, "weak_ice")
                table.insert(weakIceTiles, {x = x, y = y})
            elseif symbol == "B" then
                setTile(grid, x, y, "cabin_workbench")
            elseif symbol == "H" then
                setTile(grid, x, y, "snow")
                table.insert(shelterCells, {x = x, y = y})
            else
                setTile(grid, x, y, "snow")
            end
        end
    end

    return weakIceTiles, shelterCells
end

local function nodeTypeForTile(tile)
    if tile == "cabin_floor" or tile == "cabin_bed" or tile == "cabin_stove" or tile == "cabin_workbench" or tile == "cave_floor" then
        return "cache"
    end
    return "loot"
end

local function generateEditorRunData(difficultyName, layout)
    local symbolGrid = normalizeLayout(layout)
    local grid = newGrid(CONFIG.GRID_WIDTH, CONFIG.GRID_HEIGHT)
    local structures = {}
    local resourceNodes = {}
    local safeSleepSpots = {}
    local temperatureBands = {}
    local snowShelters = {}
    local weakIceTiles, shelterCells = applyLayoutTiles(grid, symbolGrid)
    local workbenches = {}
    local curingStations = {}
    local fishingSpots = {}
    local climbNodes = {}
    local mapNodes = {}
    local carcasses = {}
    local pointsOfInterest = {}

    local cabinCount = 0
    for _, component in ipairs(collectComponents(symbolGrid, "C")) do
        local bounds = normalizeBounds(component, 6, 5)
        cabinCount = cabinCount + 1
        local cabin = addCabin(grid, bounds.x, bounds.y, string.format("Editor Cabin %d", cabinCount), bounds.width, bounds.height)
        table.insert(structures, cabin)
        table.insert(safeSleepSpots, worldCoord(cabin.bed.x, cabin.bed.y))
        table.insert(workbenches, makeWorkbench(cabin.workbench.x, cabin.workbench.y, string.format("Editor Workbench %d", cabinCount)))
        table.insert(curingStations, makeCuringStation(cabin.workbench.x, cabin.workbench.y, string.format("Editor Curing Rack %d", cabinCount)))
        table.insert(pointsOfInterest, {name = cabin.name, coord = worldCoord(cabin.bed.x, cabin.bed.y), biome = "Editor Frontier", rewardTier = "safe"})
        table.insert(temperatureBands, {
            type = "shelter",
            zone = makeZone(bounds.x, bounds.y, bounds.width, bounds.height),
            modifier = 8,
        })
    end

    for _, component in ipairs(collectComponents(symbolGrid, "V")) do
        local bounds = normalizeBounds(component, 7, 5)
        local cave = addCave(grid, bounds.x, bounds.y, bounds.width, bounds.height)
        table.insert(structures, cave)
        table.insert(safeSleepSpots, worldCoord(cave.bed.x, cave.bed.y))
        table.insert(pointsOfInterest, {name = "Editor Cave", coord = worldCoord(cave.mouth.x, cave.mouth.y), biome = "Editor Frontier", rewardTier = "medium"})
        table.insert(temperatureBands, {
            type = "cave",
            zone = makeZone(bounds.x, bounds.y, bounds.width, bounds.height),
            modifier = 10,
        })
    end

    for _, component in ipairs(collectComponents(symbolGrid, "L")) do
        table.insert(temperatureBands, {
            type = "lake",
            zone = makeZone(component.x, component.y, component.width, component.height),
            modifier = -6,
        })
    end

    for _, cell in ipairs(shelterCells) do
        table.insert(snowShelters, {
            coord = worldCoord(cell.x, cell.y),
            integrity = 100,
        })
        table.insert(safeSleepSpots, worldCoord(cell.x, cell.y))
        table.insert(temperatureBands, {
            type = "snow_shelter",
            zone = makeZone(cell.x, cell.y, 1, 1),
            modifier = 6,
        })
    end

    for _, component in ipairs(collectComponents(symbolGrid, "O")) do
        local centerX = component.x + math.floor(component.width / 2)
        local centerY = component.y + math.floor(component.height / 2)
        addResourceNode(resourceNodes, nodeTypeForTile(grid[centerY][centerX]), centerX, centerY, {loot = randomLoot()})
    end

    for _, component in ipairs(collectComponents(symbolGrid, "B")) do
        local centerX = component.x + math.floor(component.width / 2)
        local centerY = component.y + math.floor(component.height / 2)
        table.insert(workbenches, makeWorkbench(centerX, centerY, "Editor Workbench"))
        table.insert(curingStations, makeCuringStation(centerX, centerY, "Editor Curing Rack"))
    end

    for _, component in ipairs(collectComponents(symbolGrid, "I")) do
        local centerX = component.x + math.floor(component.width / 2)
        local centerY = component.y + math.floor(component.height / 2)
        table.insert(fishingSpots, makeFishingSpot(centerX, centerY, "Editor Fishing Hole"))
    end

    for _, component in ipairs(collectComponents(symbolGrid, "M")) do
        local centerX = component.x + math.floor(component.width / 2)
        local centerY = component.y + math.floor(component.height / 2)
        local node = makeMapNode(centerX, centerY, "Editor Overlook")
        node.survey = true
        table.insert(mapNodes, node)
    end

    for _, component in ipairs(collectComponents(symbolGrid, "P")) do
        local centerX = component.x + math.floor(component.width / 2)
        local centerY = component.y + math.floor(component.height / 2)
        table.insert(climbNodes, makeClimbNode(centerX, centerY, math.max(2, centerX - 2), math.max(2, centerY - 2), "Editor Rope"))
    end

    for _, component in ipairs(collectComponents(symbolGrid, "Q")) do
        local centerX = component.x + math.floor(component.width / 2)
        local centerY = component.y + math.floor(component.height / 2)
        table.insert(carcasses, makeCarcass("deer", centerX, centerY))
    end

    local wolfZones = {}
    local wolves = {}
    for _, component in ipairs(collectComponents(symbolGrid, "K")) do
        local zone = makeZone(component.x, component.y, component.width, component.height)
        table.insert(wolfZones, zone)
        table.insert(wolves, {
            kind = "wolf",
            coord = worldCoord(component.x + math.floor(component.width / 2), component.y + math.floor(component.height / 2)),
            territory = zone,
            territoryCenter = zoneCenter(zone),
            state = "roam",
            target = nil,
            fearHours = 0,
        })
    end

    local rabbitZones = {}
    local rabbits = {}
    for _, component in ipairs(collectComponents(symbolGrid, "R")) do
        local zone = makeZone(component.x, component.y, component.width, component.height)
        table.insert(rabbitZones, zone)
        table.insert(rabbits, {
            kind = "rabbit",
            zone = zone,
            coord = worldCoord(component.x + math.floor(component.width / 2), component.y + math.floor(component.height / 2)),
            speed = 20,
        })
    end

    local deerZones = {}
    local deer = {}
    for _, component in ipairs(collectComponents(symbolGrid, "D")) do
        local zone = makeZone(component.x, component.y, component.width, component.height)
        table.insert(deerZones, zone)
        table.insert(deer, {
            kind = "deer",
            zone = zone,
            coord = worldCoord(component.x + math.floor(component.width / 2), component.y + math.floor(component.height / 2)),
            speed = 24,
        })
    end

    local startX, startY = firstSymbol(symbolGrid, "@")
    local playerStart
    if startX and startY then
        playerStart = worldCoord(startX, startY)
    elseif safeSleepSpots[1] then
        playerStart = {safeSleepSpots[1][1], safeSleepSpots[1][2]}
    else
        playerStart = worldCoord(2, 2)
    end

    local generated = {
        grid = grid,
        playerStart = playerStart,
        structures = structures,
        resourceNodes = resourceNodes,
        fires = {},
        traps = {},
        carcasses = carcasses,
        fishingSpots = fishingSpots,
        climbNodes = climbNodes,
        mapNodes = mapNodes,
        workbenches = workbenches,
        curingStations = curingStations,
        curing = {},
        mappedTiles = {},
        pointsOfInterest = pointsOfInterest,
        landmarks = Utils.deepCopy(pointsOfInterest),
        regions = {
            {
                id = "editor_frontier",
                name = "Editor Frontier",
                biome = "Editor Frontier",
                role = "editor",
                zone = makeZone(2, 2, CONFIG.GRID_WIDTH - 2, CONFIG.GRID_HEIGHT - 2),
                shelterDensity = "custom",
                visibilityPressure = 1,
                hazardIntensity = 1,
                traversalRequirements = {},
            },
        },
        connections = {},
        gates = {},
        traversalRequirements = {},
        npcEncounters = {},
        wildlife = {
            wolves = wolves,
            rabbits = rabbits,
            deer = deer,
            raiders = {},
        },
        weather = {
            current = "clear",
            hoursUntilChange = math.random(CONFIG.WEATHER_CHANGE_MIN_HOURS, CONFIG.WEATHER_CHANGE_MAX_HOURS),
        },
        timeOfDay = 8,
        dayCount = 1,
        temperatureBands = temperatureBands,
        safeSleepSpots = safeSleepSpots,
        weakIceTiles = weakIceTiles,
        snowShelters = snowShelters,
        biomes = {
            {
                id = "editor_frontier",
                name = "Editor Frontier",
                zone = makeZone(2, 2, CONFIG.GRID_WIDTH - 2, CONFIG.GRID_HEIGHT - 2),
                spawnTables = {loot = "editor", wildlife = {"wolf", "rabbit", "deer"}},
                traversalTags = {"editor"},
            },
        },
        wolfTerritory = wolfZones[1],
        rabbitZones = rabbitZones,
        deerZone = deerZones[1],
        carcassSites = {},
        source = "editor",
        editorLayout = {
            filename = layout and layout.filename or "custom.txt",
        },
    }
    World.initialize(generated)
    return generated
end

function ProcGen.generateRunData(difficultyName, options)
    options = options or {}
    if options.layout then
        return generateEditorRunData(difficultyName, options.layout)
    end
    return generateProceduralRunData(difficultyName)
end

return ProcGen
