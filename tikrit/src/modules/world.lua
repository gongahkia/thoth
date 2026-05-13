local CONFIG = require("config")
local EntitySystem = require("modules/entity_system")
local Furniture = require("modules/furniture")
local Items = require("modules/items")
local TileRegistry = require("modules/tile_registry")
local Utils = require("modules/utils")
local WorldObjects = require("modules/world_objects")

local World = {}

local function newDataGrid(grid)
    local data = {}
    for y = 1, #grid do
        data[y] = {}
        for x = 1, #(grid[y] or {}) do
            data[y][x] = 0
        end
    end
    return data
end

local function cloneGrid(grid)
    local copy = {}
    for y = 1, #grid do
        copy[y] = {}
        for x = 1, #(grid[y] or {}) do
            copy[y][x] = grid[y][x]
        end
    end
    return copy
end

local function makeFilledGrid(width, height, tile)
    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            local border = x == 1 or y == 1 or x == width or y == height
            grid[y][x] = border and "rock" or tile
        end
    end
    return grid
end

local function ensureLevel(level, depth)
    level.depth = level.depth or depth or 0
    level.grid = level.grid or makeFilledGrid(CONFIG.WORLD_GRID_WIDTH, CONFIG.WORLD_GRID_HEIGHT, "snow")
    level.data = level.data or newDataGrid(level.grid)
    level.entities = level.entities or {}
    level.tileEntities = level.tileEntities or {}
    level.spawnRules = level.spawnRules or {}
    level.hazards = level.hazards or {}
    level.discovered = level.discovered or {}
    level.structures = level.structures or {}
    level.resourceNodes = level.resourceNodes or {}
    level.pointsOfInterest = level.pointsOfInterest or {}
    level.hazardZones = level.hazardZones or level.hazards or {}
    level.safeSleepSpots = level.safeSleepSpots or {}
    level.temperatureBands = level.temperatureBands or {}
    level.biomes = level.biomes or {}
    level.workbenches = level.workbenches or {}
    level.curingStations = level.curingStations or {}
    level.mapNodes = level.mapNodes or {}
    level.climbNodes = level.climbNodes or {}
    level.fishingSpots = level.fishingSpots or {}
    level.rabbitZones = level.rabbitZones or {}
    level.carcasses = level.carcasses or {}
    level.snowShelters = level.snowShelters or {}
    level.fires = level.fires or {}
    level.traps = level.traps or {}
    level.curing = level.curing or {}
    level.gates = level.gates or {}
    level.npcEncounters = level.npcEncounters or {}
    level.wildlife = level.wildlife or {wolves = {}, rabbits = {}, deer = {}, raiders = {}}
    level.goals = level.goals or {}
    level.snowCover = level.snowCover or {}
    level.iceState = level.iceState or {}
    level.shelterWear = level.shelterWear or {}
    level.warmthPockets = level.warmthPockets or {}
    level.thermalWarmth = level.thermalWarmth or {}
    return level
end

local function makeCompanionLevel(source, depth, name, baseTile)
    local grid = makeFilledGrid(#(source.grid[1] or {}), #source.grid, baseTile)
    for y = 2, #grid - 1 do
        for x = 2, #grid[y] - 1 do
            if depth < 0 and ((x * 7 + y * 3 + math.abs(depth)) % 11 == 0) then
                grid[y][x] = depth == -2 and "cave_wall" or "rock"
            elseif depth == 1 and ((x + y) % 17 == 0) then
                grid[y][x] = "tree"
            elseif depth == -2 and ((x * 5 + y) % 29 == 0) then
                grid[y][x] = "thermal_fissure"
            end
        end
    end
    return ensureLevel({
        depth = depth,
        name = name,
        grid = grid,
        weather = source.weather and Utils.deepCopy(source.weather) or nil,
        hazards = {},
        discovered = {},
    }, depth)
end

local function applyActiveAliases(world, level)
    world.grid = level.grid
    world.data = level.data
    world.entities = level.entities
    world.tileEntities = level.tileEntities
    world.spawnRules = level.spawnRules
    world.hazards = level.hazards
    world.discovered = level.discovered
    world.structures = level.structures
    world.resourceNodes = level.resourceNodes
    world.pointsOfInterest = level.pointsOfInterest
    world.hazardZones = level.hazardZones
    world.safeSleepSpots = level.safeSleepSpots
    world.temperatureBands = level.temperatureBands
    world.biomes = level.biomes
    world.workbenches = level.workbenches
    world.curingStations = level.curingStations
    world.mapNodes = level.mapNodes
    world.climbNodes = level.climbNodes
    world.fishingSpots = level.fishingSpots
    world.rabbitZones = level.rabbitZones
    world.carcasses = level.carcasses
    world.snowShelters = level.snowShelters
    world.fires = level.fires
    world.traps = level.traps
    world.curing = level.curing
    world.gates = level.gates
    world.npcEncounters = level.npcEncounters
    world.wildlife = level.wildlife
    world.goals = level.goals
    world.snowCover = level.snowCover
    world.iceState = level.iceState
    world.shelterWear = level.shelterWear
    world.warmthPockets = level.warmthPockets
    world.thermalWarmth = level.thermalWarmth
end

function World.levelSize(level)
    return #(level.grid[1] or {}), #level.grid
end

function World.findTiles(level, predicate)
    local matches = {}
    for y = 1, #level.grid do
        for x = 1, #(level.grid[y] or {}) do
            local tile = level.grid[y][x]
            if predicate(tile, x, y, level) then
                table.insert(matches, {x = x, y = y, tile = tile, coord = {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE}})
            end
        end
    end
    return matches
end

function World.isReachable(level, startCoord, targetCoord)
    if not level or not level.grid or not startCoord or not targetCoord then
        return false
    end

    local startGX, startGY = Utils.pixelToGrid(startCoord[1], startCoord[2])
    local targetGX, targetGY = Utils.pixelToGrid(targetCoord[1], targetCoord[2])
    local startX, startY = startGX + 1, startGY + 1
    local targetX, targetY = targetGX + 1, targetGY + 1
    if not level.grid[startY] or not level.grid[startY][startX] or not level.grid[targetY] or not level.grid[targetY][targetX] then
        return false
    end

    local queue = {{x = startX, y = startY}}
    local visited = {[startX .. ":" .. startY] = true}
    local index = 1
    local directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

    while index <= #queue do
        local current = queue[index]
        index = index + 1
        if current.x == targetX and current.y == targetY then
            return true
        end

        for _, direction in ipairs(directions) do
            local nextX = current.x + direction[1]
            local nextY = current.y + direction[2]
            local key = nextX .. ":" .. nextY
            local tile = level.grid[nextY] and level.grid[nextY][nextX]
            if not visited[key] and tile and TileRegistry.isWalkable(tile, level, nextX, nextY, nil) then
                visited[key] = true
                table.insert(queue, {x = nextX, y = nextY})
            end
        end
    end

    return false
end

local function setIfOpen(level, x, y, tile)
    if level and level.grid and level.grid[y] and level.grid[y][x] then
        level.grid[y][x] = tile
        level.data = level.data or newDataGrid(level.grid)
        level.data[y] = level.data[y] or {}
        level.data[y][x] = 0
    end
end

local function ensureDepthLinks(world)
    setIfOpen(world.levels[0], 80, 22, "stair_down")
    setIfOpen(world.levels[-1], 80, 22, "stair_up")
    setIfOpen(world.levels[-1], 82, 24, "stair_down")
    setIfOpen(world.levels[-2], 82, 24, "stair_up")
    setIfOpen(world.levels[0], 100, 20, "stair_up")
    setIfOpen(world.levels[1], 100, 20, "stair_down")
end

function World.initialize(world)
    world.levels = world.levels or {}
    local surface = world.levels[0] or {
        depth = 0,
        name = "Frozen Surface",
        grid = world.grid and cloneGrid(world.grid) or nil,
        data = world.data,
        entities = world.entities,
        tileEntities = world.tileEntities,
        spawnRules = world.spawnRules,
        hazards = world.hazardZones,
        discovered = world.mappedTiles,
        structures = world.structures,
        resourceNodes = world.resourceNodes,
        pointsOfInterest = world.pointsOfInterest,
        safeSleepSpots = world.safeSleepSpots,
        hazardZones = world.hazardZones,
        temperatureBands = world.temperatureBands,
        biomes = world.biomes,
        workbenches = world.workbenches,
        curingStations = world.curingStations,
        mapNodes = world.mapNodes,
        climbNodes = world.climbNodes,
        fishingSpots = world.fishingSpots,
        rabbitZones = world.rabbitZones,
        carcasses = world.carcasses,
        snowShelters = world.snowShelters,
        fires = world.fires,
        traps = world.traps,
        curing = world.curing,
        gates = world.gates,
        npcEncounters = world.npcEncounters,
        wildlife = world.wildlife,
        goals = world.goals,
    }
    world.levels[0] = ensureLevel(surface, 0)
    world.levels[-1] = ensureLevel(world.levels[-1] or makeCompanionLevel(world.levels[0], -1, "Ice Caves", "cave_floor"), -1)
    world.levels[-2] = ensureLevel(world.levels[-2] or makeCompanionLevel(world.levels[0], -2, "Deep Ruins", "shale"), -2)
    world.levels[1] = ensureLevel(world.levels[1] or makeCompanionLevel(world.levels[0], 1, "Exposed Ridge", "snow"), 1)
    ensureDepthLinks(world)
    for _, level in pairs(world.levels) do
        Furniture.mirrorLevel(level)
        WorldObjects.mirrorLevel(level)
    end
    world.currentDepth = world.currentDepth or 0
    applyActiveAliases(world, world.levels[world.currentDepth])
    return world
end

function World.attachRun(run)
    run.world = World.initialize(run.world or {})
    run.player.depth = run.player.depth or run.world.currentDepth or 0
    return run.world
end

function World.currentLevel(run)
    local world = run and run.world or run
    if not world then
        return nil
    end
    World.initialize(world)
    return world.levels[world.currentDepth or 0]
end

function World.activeCollection(run, keyName)
    local world = World.attachRun(run)
    local level = world.levels[world.currentDepth or 0]
    if not level[keyName] then
        level[keyName] = {}
    end
    world[keyName] = level[keyName]
    return level[keyName], level
end

function World.readActiveCollection(run, keyName)
    local world = World.attachRun(run)
    local level = world.levels[world.currentDepth or 0]
    local collection = level and level[keyName]
    if type(collection) ~= "table" then
        return {}, level
    end
    return collection, level
end

function World.ensureActiveCollections(run, keyNames)
    local collections = {}
    local level
    for _, keyName in ipairs(keyNames or {}) do
        collections[keyName], level = World.activeCollection(run, keyName)
    end
    return collections, level
end

function World.activeWildlife(run)
    local wildlife, level = World.activeCollection(run, "wildlife")
    wildlife.wolves = wildlife.wolves or {}
    wildlife.rabbits = wildlife.rabbits or {}
    wildlife.deer = wildlife.deer or {}
    wildlife.raiders = wildlife.raiders or {}
    run.world.wildlife = wildlife
    return wildlife, level
end

function World.activeGrid(run)
    local world = World.attachRun(run)
    local level = world.levels[world.currentDepth or 0]
    return level and level.grid or {}, level
end

local function tableCount(tbl)
    local total = 0
    for _ in pairs(tbl or {}) do
        total = total + 1
    end
    return total
end

function World.simulationSummary(level)
    return {
        snowCoverTiles = tableCount(level and level.snowCover),
        iceStateTiles = tableCount(level and level.iceState),
        shelterWearTiles = tableCount(level and level.shelterWear),
        warmthPocketTiles = tableCount(level and level.warmthPockets),
        thermalWarmthTiles = tableCount(level and level.thermalWarmth),
    }
end

function World.activeSimulationSummary(run)
    World.attachRun(run)
    return World.simulationSummary(World.currentLevel(run))
end

function World.tileAt(run, depth, x, y)
    local world = run.world or run
    World.initialize(world)
    local level = world.levels[depth or world.currentDepth or 0]
    local row = level and level.grid[y]
    return row and row[x], level
end

function World.trySetTile(run, depth, x, y, tile)
    local current, level = World.tileAt(run, depth, x, y)
    if not current then
        return false
    end
    level.grid[y][x] = tile
    return true
end

local function countEntities(level, kind)
    local total = 0
    for _, entity in ipairs(level.entities or {}) do
        if entity.kind == kind and entity.hidden ~= true then
            total = total + 1
        end
    end
    return total
end

local function listAllows(list, value)
    if not list then
        return true
    end
    if list[value] == true then
        return true
    end
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

local function listBlocks(list, value)
    if not list then
        return false
    end
    if list[value] == true then
        return true
    end
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

local function coordInZone(x, y, zone)
    return zone
        and x >= zone.x
        and y >= zone.y
        and x <= zone.x + zone.width
        and y <= zone.y + zone.height
end

local function blockedByHazard(level, x, y, rules)
    local blockedHazards = rules and (rules.blockedHazards or rules.avoidHazards)
    if not blockedHazards then
        return false
    end
    for _, hazard in ipairs(level.hazardZones or level.hazards or {}) do
        if listBlocks(blockedHazards, hazard.type) and coordInZone(x, y, hazard.zone) then
            return true
        end
    end
    return false
end

local function validSpawnTile(level, x, y, rules)
    local tile = level.grid[y] and level.grid[y][x]
    local allowedTiles = rules and (rules.allowedTiles or rules.validTiles)
    local blockedTiles = rules and (rules.blockedTiles or rules.avoidTiles)
    return tile
        and listAllows(allowedTiles, tile)
        and not listBlocks(blockedTiles, tile)
        and tile ~= "weak_ice"
        and tile ~= "thermal_fissure"
        and tile ~= "lake"
        and not blockedByHazard(level, x, y, rules)
        and TileRegistry.isWalkable(tile, level, x, y, nil)
end

function World.spawnOffscreen(run, kind, rules)
    World.attachRun(run)
    rules = rules or {}
    local depth = rules.depth or run.world.currentDepth or 0
    local level = run.world.levels[depth]
    if not level then
        return nil, "No level for spawn."
    end
    if rules.cap and countEntities(level, kind) >= rules.cap then
        return nil, "Spawn cap reached."
    end

    local width, height = World.levelSize(level)
    local zone = rules.zone or {x = 2, y = 2, width = width - 2, height = height - 2}
    local minDistance = (rules.minDistanceTiles or CONFIG.VISIBLE_RADIUS_DAY or 8) * CONFIG.TILE_SIZE
    for _ = 1, rules.attempts or 80 do
        local x = math.random(zone.x, math.max(zone.x, zone.x + zone.width - 1))
        local y = math.random(zone.y, math.max(zone.y, zone.y + zone.height - 1))
        if x > 1 and y > 1 and x < width and y < height and validSpawnTile(level, x, y, rules) then
            local coord = {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE}
            local sameDepth = depth == (run.world.currentDepth or 0)
            local distance = Utils.distance(run.player.coord[1], run.player.coord[2], coord[1], coord[2])
            if not sameDepth or distance >= minDistance then
                return EntitySystem.spawn(level, kind, coord, {
                    solid = false,
                    width = rules.width or CONFIG.TILE_SIZE - 4,
                    height = rules.height or CONFIG.TILE_SIZE - 4,
                    spawned = true,
                    depth = depth,
                    spawnRuleId = rules.id or rules.spawnRuleId,
                    homeZone = rules.zone,
                    aiState = rules.aiState or "roam",
                    state = rules.state or rules.aiState or "roam",
                    moving = false,
                    facingX = 1,
                    facingY = 0,
                })
            end
        end
    end
    return nil, "No valid offscreen spawn."
end

function World.moveEntity(run, entity, dx, dy)
    local world = run.world or run
    local level = world.levels[entity.depth or world.currentDepth or 0]
    return EntitySystem.moveEntity(level, entity, dx, dy)
end

function World.changeDepth(run, depth, coord)
    World.attachRun(run)
    if not run.world.levels[depth] then
        return false, "No route leads there."
    end
    run.world.currentDepth = depth
    run.player.depth = depth
    if coord then
        run.player.coord = {coord[1], coord[2]}
        run.player.lastSafeCoord = {coord[1], coord[2]}
    end
    applyActiveAliases(run.world, run.world.levels[depth])
    local gx, gy = Utils.pixelToGrid(run.player.coord[1], run.player.coord[2])
    run.player._lastStepTileKey = string.format("%d:%d:%d", depth, gx + 1, gy + 1)
    return true
end

local function facingDirection(player)
    local dx = player.lastMoveX or player.combatFacingX or 1
    local dy = player.lastMoveY or player.combatFacingY or 0
    if dx == 0 and dy == 0 then
        return 1, 0
    end
    if math.abs(dx) >= math.abs(dy) then
        return dx >= 0 and 1 or -1, 0
    end
    return 0, dy >= 0 and 1 or -1
end

local function tilePixelCoord(x, y)
    return {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE}
end

local function tileKey(depth, x, y)
    return string.format("%d:%d:%d", depth or 0, x or 0, y or 0)
end

local function stairTargetDepth(tile, depth)
    if tile == "stair_up" then
        return (depth or 0) + 1
    elseif tile == "stair_down" then
        return (depth or 0) - 1
    end
    return nil
end

local function useStair(run, tile, x, y)
    local currentDepth = run.world.currentDepth or run.player.depth or 0
    local targetDepth = stairTargetDepth(tile, currentDepth)
    if not targetDepth then
        return false, nil
    end
    local ok, message = World.changeDepth(run, targetDepth, tilePixelCoord(x, y))
    if ok then
        return true, targetDepth < currentDepth and "You descend into colder dark." or "You climb to harsher air."
    end
    return false, message
end

local function findPoi(level, name)
    for _, poi in ipairs(level.pointsOfInterest or {}) do
        if poi.name == name then
            return poi
        end
    end
    return nil
end

local function completeGoal(list, goalId)
    local changed = false
    for _, goal in ipairs(list or {}) do
        if goal.id == goalId then
            goal.completed = true
            changed = true
        end
    end
    return changed
end

local function hasMappedRoute(run)
    for _ in pairs(run.world.mappedTiles or run.world.discovered or {}) do
        return true
    end
    return false
end

function World.activateEndgame(run, probe)
    World.attachRun(run)
    local level = World.currentLevel(run)
    run.runtime = run.runtime or {}
    if run.runtime.endgameActivated then
        if probe then
            return true, nil
        end
        return true, "The weather station beacon is already active."
    end
    if (run.world.currentDepth or 0) ~= 1 then
        if probe then
            return false, nil
        end
        return false, "The weather station is on the ridge."
    end
    local poi = findPoi(level, "Ridge Weather Station") or findPoi(level, "Weather Station")
    if not poi then
        if probe then
            return false, nil
        end
        return false, "No station equipment is here."
    end

    local distance = Utils.distance(run.player.coord[1], run.player.coord[2], poi.coord[1], poi.coord[2])
    if distance > CONFIG.TILE_SIZE * 2.2 then
        if probe then
            return false, nil
        end
        return false, "Get closer to the weather station."
    end
    if Items.count(run.player.inventory, "survey_kit") < 1 and not hasMappedRoute(run) then
        return false, "You need survey gear or a mapped route to align the station."
    end

    completeGoal(level.goals, "activate_ridge_weather_station")
    completeGoal(run.world.goals, "activate_ridge_weather_station")
    run.runtime.endgameActivated = true
    run.runtime.success = true
    run.runtime.endgameDepth = run.world.currentDepth
    run.runtime.replayEvents = run.runtime.replayEvents or {}
    table.insert(run.runtime.replayEvents, {
        type = "weather_station_activated",
        depth = run.world.currentDepth,
        coord = {poi.coord[1], poi.coord[2]},
    })
    run.stats = run.stats or {}
    run.stats.weatherStationActivated = true
    return true, "You activate the weather station beacon."
end

function World.currentTile(run)
    World.attachRun(run)
    local gx, gy = Utils.pixelToGrid(run.player.coord[1], run.player.coord[2])
    local x = gx + 1
    local y = gy + 1
    local tile, level = World.tileAt(run, run.world.currentDepth, x, y)
    return tile, level, x, y
end

function World.facingTile(run)
    World.attachRun(run)
    local _, _, currentX, currentY = World.currentTile(run)
    local dx, dy = facingDirection(run.player)
    local x = currentX + dx
    local y = currentY + dy
    local tile, level = World.tileAt(run, run.world.currentDepth, x, y)
    return tile, level, x, y, TileRegistry.get(tile), dx, dy
end

function World.facingEntity(run)
    World.attachRun(run)
    local _, level, x, y = World.facingTile(run)
    if not level then
        return nil
    end
    for _, entity in ipairs(EntitySystem.getTileEntities(level, x, y)) do
        if entity ~= run.player and entity.hidden ~= true then
            return entity
        end
    end
    return nil
end

function World.interactFacing(run)
    World.attachRun(run)
    local currentTile, currentLevel, currentX, currentY = World.currentTile(run)
    local currentStairDepth = stairTargetDepth(currentTile, run.world.currentDepth)
    if currentStairDepth then
        return useStair(run, currentTile, currentX, currentY)
    end

    local endgameOk, endgameMessage = World.activateEndgame(run, true)
    if endgameOk or endgameMessage then
        return endgameOk, endgameMessage
    end

    local entity = World.facingEntity(run)
    if entity then
        if entity.interact then
            local ok, message = entity:interact(run, currentLevel)
            return ok ~= false, message or "You interact."
        end
        return true, entity.label and ("You inspect " .. entity.label .. ".") or "You inspect it."
    end

    local tile, level, x, y = World.facingTile(run)
    if not tile or not level then
        return false, nil
    end
    local ok, message = TileRegistry.interact(level, x, y, run.player, run)
    if ok or message then
        return ok, message
    end
    local targetDepth = stairTargetDepth(tile, run.world.currentDepth)
    if targetDepth then
        return useStair(run, tile, x, y)
    end
    return false, nil
end

local function equippedToolDefinition(run, toolKind)
    toolKind = toolKind or run.player.equippedTool
    if not toolKind then
        return nil, nil, "Ready a tool first."
    end
    local definition = Items.getDefinition(toolKind)
    if not definition or definition.equipSlot ~= "tool" then
        return nil, nil, "Ready a tool first."
    end
    return toolKind, definition, nil
end

local function spendToolStamina(run, definition)
    local staminaCost = definition and definition.staminaCost or 0
    if run.player.stamina then
        run.player.stamina = math.max(0, run.player.stamina - staminaCost)
    end
end

local function hitFacingTileOnly(run, toolKind, definition)
    local resolvedToolKind, resolvedDefinition, errorMessage = equippedToolDefinition(run, toolKind)
    toolKind = resolvedToolKind
    definition = definition or resolvedDefinition
    if errorMessage then
        return false, errorMessage
    end

    local tile, level, x, y, behavior = World.facingTile(run)
    if not tile or not level then
        return false, "Nothing useful is in reach."
    end
    if not behavior:isDestructible() then
        return false, "That tool finds no purchase."
    end
    if behavior.toolTypes and not behavior.toolTypes[definition.toolType] then
        return false, "The " .. Items.describe(toolKind) .. " is the wrong tool for that."
    end

    local entity = {
        depth = run.world.currentDepth or 0,
        toolKind = toolKind,
        tileDamage = definition.tileDamage or 1,
    }
    local ok, drops = TileRegistry.hit(level, x, y, entity, run)
    for _, item in ipairs(drops or {}) do
        Items.add(run.player.inventory, item.kind, item.quantity or 1)
    end
    if #(drops or {}) > 0 then
        Items.sortInventory(run.player.inventory)
    end
    if not ok then
        return false, "The " .. Items.describe(toolKind) .. " has no effect."
    end
    spendToolStamina(run, definition)
    if #(drops or {}) > 0 then
        return true, "You break down the " .. behavior.name .. "."
    end
    return true, "You work at the " .. behavior.name .. "."
end

function World.hitFacingTile(run, toolKind)
    World.attachRun(run)
    return hitFacingTileOnly(run, toolKind)
end

function World.hitFacing(run, toolKind)
    World.attachRun(run)
    local resolvedToolKind, definition, errorMessage = equippedToolDefinition(run, toolKind)
    if errorMessage then
        return false, errorMessage
    end

    local tile, level = World.facingTile(run)
    local entity = World.facingEntity(run)
    if entity then
        if entity.hit then
            local ok, message = entity:hit(run, level, definition)
            if ok then
                spendToolStamina(run, definition)
            end
            return ok, message or (ok and "You work at it." or "That tool has no effect.")
        end
        return false, entity.label and ("Use another approach for " .. entity.label .. ".") or "Use another approach for that."
    end
    if not tile then
        return false, "Nothing useful is in reach."
    end
    return hitFacingTileOnly(run, resolvedToolKind, definition)
end

function World.stepPlayer(run)
    World.attachRun(run)
    local tile, _level, x, y = World.currentTile(run)
    local key = tileKey(run.world.currentDepth, x, y)
    if run.player._lastStepTileKey == key then
        return false, nil
    end
    run.player._lastStepTileKey = key
    local targetDepth = stairTargetDepth(tile, run.world.currentDepth)
    if targetDepth then
        return useStair(run, tile, x, y)
    end
    return false, nil
end

local function updateLevelSimulation(level, run, hours)
    local blizzard = run.world.weather and run.world.weather.current == "blizzard"
    for _, shelter in ipairs(level.snowShelters or {}) do
        if shelter.integrity and shelter.integrity > 0 then
            local wear = ((level.depth or 0) == 1 or blizzard) and 2.0 or 0.35
            shelter.integrity = math.max(0, shelter.integrity - (wear * hours))
        end
    end
    for _, fire in ipairs(level.fires or {}) do
        fire.tickHours = (fire.tickHours or 0) + hours
        fire.decayTicks = (fire.decayTicks or 0) + 1
        fire.lastTickDepth = level.depth or run.world.currentDepth or 0
    end
    for _, node in ipairs(level.resourceNodes or {}) do
        if node.opened and node.regrowHours then
            node.regrowHours = math.max(0, node.regrowHours - hours)
            if node.regrowHours <= 0 then
                node.opened = false
                node.regrown = true
                node.lastRegrowDepth = level.depth or run.world.currentDepth or 0
            end
        end
    end
end

function World.tick(run, hours)
    World.attachRun(run)
    local level = World.currentLevel(run)
    EntitySystem.tick(level, run)
    updateLevelSimulation(level, run, hours)
    local attempts = math.max(1, math.floor((#level.grid * #(level.grid[1] or {})) / 256))
    for _ = 1, attempts do
        local x = math.random(2, math.max(2, #(level.grid[1] or {}) - 1))
        local y = math.random(2, math.max(2, #level.grid - 1))
        TileRegistry.randomTick(level, x, y, run)
    end
    return hours
end

return World
