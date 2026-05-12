local CONFIG = require("config")
local EntitySystem = require("modules/entity_system")
local Items = require("modules/items")
local TileRegistry = require("modules/tile_registry")
local Utils = require("modules/utils")

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
    level.carcasses = level.carcasses or {}
    level.snowShelters = level.snowShelters or {}
    level.fires = level.fires or {}
    level.traps = level.traps or {}
    level.curing = level.curing or {}
    level.gates = level.gates or {}
    level.npcEncounters = level.npcEncounters or {}
    level.wildlife = level.wildlife or {wolves = {}, rabbits = {}, deer = {}, raiders = {}}
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
    world.carcasses = level.carcasses
    world.snowShelters = level.snowShelters
    world.fires = level.fires
    world.traps = level.traps
    world.curing = level.curing
    world.gates = level.gates
    world.npcEncounters = level.npcEncounters
    world.wildlife = level.wildlife
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
        carcasses = world.carcasses,
        snowShelters = world.snowShelters,
        fires = world.fires,
        traps = world.traps,
        curing = world.curing,
        gates = world.gates,
        npcEncounters = world.npcEncounters,
        wildlife = world.wildlife,
    }
    world.levels[0] = ensureLevel(surface, 0)
    world.levels[-1] = ensureLevel(world.levels[-1] or makeCompanionLevel(world.levels[0], -1, "Ice Caves", "cave_floor"), -1)
    world.levels[-2] = ensureLevel(world.levels[-2] or makeCompanionLevel(world.levels[0], -2, "Deep Ruins", "shale"), -2)
    world.levels[1] = ensureLevel(world.levels[1] or makeCompanionLevel(world.levels[0], 1, "Exposed Ridge", "snow"), 1)
    ensureDepthLinks(world)
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

function World.hitFacingTile(run, toolKind)
    World.attachRun(run)
    toolKind = toolKind or run.player.equippedTool
    if not toolKind then
        return false, "Ready a tool first."
    end
    local definition = Items.getDefinition(toolKind)
    if not definition or definition.equipSlot ~= "tool" then
        return false, "Ready a tool first."
    end

    local tile, level, x, y, behavior = World.facingTile(run)
    if not tile or not level then
        return false, "Nothing useful is in reach."
    end
    if not behavior:isDestructible() then
        return false, "That tool finds no purchase."
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
    local staminaCost = definition.staminaCost or 0
    if run.player.stamina then
        run.player.stamina = math.max(0, run.player.stamina - staminaCost)
    end
    if not ok then
        return false, "The " .. Items.describe(toolKind) .. " has no effect."
    end
    if #(drops or {}) > 0 then
        return true, "You break down the " .. behavior.name .. "."
    end
    return true, "You work at the " .. behavior.name .. "."
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

function World.tick(run, hours)
    World.attachRun(run)
    local level = World.currentLevel(run)
    EntitySystem.tick(level, run)
    local attempts = math.max(1, math.floor((#level.grid * #(level.grid[1] or {})) / 256))
    for _ = 1, attempts do
        local x = math.random(2, math.max(2, #(level.grid[1] or {}) - 1))
        local y = math.random(2, math.max(2, #level.grid - 1))
        TileRegistry.randomTick(level, x, y, run)
    end
    return hours
end

return World
