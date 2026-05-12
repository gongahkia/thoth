local TestRunner = require("test_runner")
local CONFIG = require("config")
local EntitySystem = require("entity_system")
local ProcGen = require("procgen")
local Utils = require("utils")
local World = require("world")

local describe = TestRunner.describe
local it = TestRunner.it

local function countNodes(nodes, nodeType)
    local total = 0
    for _, node in ipairs(nodes or {}) do
        if node.type == nodeType then
            total = total + 1
        end
    end
    return total
end

local function coordToTile(coord)
    return math.floor(coord[1] / CONFIG.TILE_SIZE) + 1, math.floor(coord[2] / CONFIG.TILE_SIZE) + 1
end

local function worldCoord(x, y)
    return {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE}
end

local function isWalkable(tile)
    return tile ~= nil
        and tile ~= "tree"
        and tile ~= "rock"
        and tile ~= "cabin_wall"
        and tile ~= "cave_wall"
end

local function canReach(grid, startCoord, targetCoord)
    local startX, startY = coordToTile(startCoord)
    local targetX, targetY = coordToTile(targetCoord)
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
            if not visited[key] and isWalkable((grid[nextY] or {})[nextX]) then
                visited[key] = true
                table.insert(queue, {x = nextX, y = nextY})
            end
        end
    end

    return false
end

local function findPOI(region, name)
    for _, poi in ipairs(region.pointsOfInterest or {}) do
        if poi.name == name then
            return poi
        end
    end
    return nil
end

local function findById(list, id)
    for _, entry in ipairs(list or {}) do
        if entry.id == id then
            return entry
        end
    end
    return nil
end

local function tileCounts(level)
    local counts = {}
    for y = 1, #level.grid do
        for x = 1, #(level.grid[y] or {}) do
            local tile = level.grid[y][x]
            counts[tile] = (counts[tile] or 0) + 1
        end
    end
    return counts
end

local function firstTile(level, tileName)
    for y = 1, #level.grid do
        for x = 1, #(level.grid[y] or {}) do
            if level.grid[y][x] == tileName then
                return x, y
            end
        end
    end
    return nil
end

local function assertValidStairs(level)
    for _, match in ipairs(World.findTiles(level, function(tile)
        return tile == "stair_up" or tile == "stair_down"
    end)) do
        TestRunner.assertTrue(match.x > 1 and match.x < CONFIG.WORLD_GRID_WIDTH)
        TestRunner.assertTrue(match.y > 1 and match.y < CONFIG.WORLD_GRID_HEIGHT)
        TestRunner.assertNotEqual(match.tile, "weak_ice")
        TestRunner.assertTrue(isWalkable(match.tile), "stair should be walkable")
    end
end

local function listHasId(list, id)
    for _, entry in ipairs(list or {}) do
        if entry.id == id or entry.biomeId == id then
            return true
        end
    end
    return false
end

local function coordFromEntry(entry)
    if entry.coord then
        return entry.coord
    end
    return entry
end

local function tileAtCoord(level, coord)
    local x, y = coordToTile(coord)
    return level.grid[y] and level.grid[y][x], x, y
end

local function isInvalidAnchorTile(tile)
    return tile == nil
        or tile == "tree"
        or tile == "rock"
        or tile == "lake"
        or tile == "cabin_wall"
        or tile == "cave_wall"
        or tile == "weak_ice"
        or tile == "thermal_fissure"
end

local function assertValidLayerAnchors(level)
    for _, match in ipairs(World.findTiles(level, function(tile)
        return tile == "stair_up" or tile == "stair_down"
    end)) do
        TestRunner.assertFalse(isInvalidAnchorTile(match.tile), "stair on invalid tile")
    end

    for _, poi in ipairs(level.pointsOfInterest or {}) do
        local tile = tileAtCoord(level, poi.coord)
        TestRunner.assertFalse(isInvalidAnchorTile(tile), poi.name .. " on invalid tile")
        TestRunner.assertType(poi.biomeId, "string")
    end

    for _, node in ipairs(level.resourceNodes or {}) do
        local tile = tileAtCoord(level, node.coord)
        TestRunner.assertFalse(isInvalidAnchorTile(tile), (node.name or node.type) .. " on invalid tile")
        TestRunner.assertType(node.biomeId, "string")
    end

    for _, spot in ipairs(level.safeSleepSpots or {}) do
        local coord = coordFromEntry(spot)
        local tile = tileAtCoord(level, coord)
        TestRunner.assertFalse(isInvalidAnchorTile(tile), "safe sleep spot on invalid tile")
        TestRunner.assertType(spot.biomeId, "string")
    end
end

local function assertReachablePois(level, entryCoord)
    for _, poi in ipairs(level.pointsOfInterest or {}) do
        if poi.rewardTier ~= "hazard" then
            TestRunner.assertTrue(World.isReachable(level, entryCoord, poi.coord), poi.name .. " should be reachable")
        end
    end
end

local function buildEditorLayout()
    local rows = {}
    for y = 1, 30 do
        rows[y] = {}
        for x = 1, 30 do
            rows[y][x] = "."
        end
    end

    for x = 1, 30 do
        rows[1][x] = "#"
        rows[30][x] = "#"
    end
    for y = 1, 30 do
        rows[y][1] = "#"
        rows[y][30] = "#"
    end

    rows[6][6] = "@"
    for y = 4, 8 do
        for x = 4, 9 do
            rows[y][x] = "C"
        end
    end
    for y = 4, 8 do
        for x = 20, 26 do
            rows[y][x] = "V"
        end
    end
    for y = 14, 18 do
        for x = 12, 17 do
            rows[y][x] = "L"
        end
    end
    rows[15][14] = "W"
    rows[16][15] = "W"
    rows[10][10] = "O"
    rows[11][10] = "O"
    rows[12][10] = "O"
    rows[22][8] = "R"
    rows[22][9] = "R"
    rows[24][22] = "D"
    rows[24][23] = "D"
    rows[18][23] = "K"
    rows[18][24] = "K"
    rows[9][7] = "H"
    rows[20][7] = "F"
    rows[6][8] = "B"
    rows[12][14] = "I"
    rows[5][12] = "M"
    rows[7][13] = "P"
    rows[9][9] = "Q"

    local lines = {}
    for y = 1, 30 do
        lines[y] = table.concat(rows[y])
    end
    return {lines = lines}
end

describe("ProcGen", function()
    it("creates deterministic regions for a fixed seed", function()
        Utils.setGameSeed(false, 12345)
        local first = ProcGen.generateRunData("normal")
        Utils.setGameSeed(false, 12345)
        local second = ProcGen.generateRunData("normal")

        TestRunner.assertTableEqual(first.playerStart, second.playerStart)
        TestRunner.assertEqual(#first.resourceNodes, #second.resourceNodes)
        TestRunner.assertEqual(#first.weakIceTiles, #second.weakIceTiles)
        TestRunner.assertEqual(#first.wildlife.wolves, #second.wildlife.wolves)
        TestRunner.assertTableEqual(tileCounts(first.levels[-1]), tileCounts(second.levels[-1]))
        TestRunner.assertTableEqual(tileCounts(first.levels[-2]), tileCounts(second.levels[-2]))
        TestRunner.assertTableEqual(tileCounts(first.levels[1]), tileCounts(second.levels[1]))
    end)

    it("guarantees shelters, weak ice, resource nodes, and wildlife zones", function()
        Utils.setGameSeed(false, 77)
        local region = ProcGen.generateRunData("hard")

        TestRunner.assertTrue(#region.structures >= 4)
        TestRunner.assertTrue(#region.safeSleepSpots >= 3)
        TestRunner.assertTrue(#region.weakIceTiles >= 6)
        TestRunner.assertTrue(countNodes(region.resourceNodes, "wood") >= 8)
        TestRunner.assertTrue(countNodes(region.resourceNodes, "loot") + countNodes(region.resourceNodes, "cache") >= 6)
        TestRunner.assertTrue(#region.wildlife.wolves >= 2)
        TestRunner.assertTrue(#region.wildlife.rabbits >= 2)
        TestRunner.assertTrue(#region.wildlife.deer >= 1)
        TestRunner.assertTrue(#region.wildlife.raiders >= 1)
        TestRunner.assertTrue(#region.fishingSpots >= 1)
        TestRunner.assertTrue(#region.climbNodes >= 1)
        TestRunner.assertTrue(#region.workbenches >= 1)
        TestRunner.assertTrue(#region.mapNodes >= 1)
        TestRunner.assertTrue(#region.carcasses >= 1)
        TestRunner.assertTrue(#region.biomes >= 4)
        TestRunner.assertTrue(#region.regions >= 7)
        TestRunner.assertTrue(#region.connections >= 7)
        TestRunner.assertTrue(#region.gates >= 3)
        TestRunner.assertTrue(#region.landmarks >= 4)
        TestRunner.assertTrue(#region.npcEncounters >= 4)
        TestRunner.assertTrue(#region.traversalRequirements >= 3)
        TestRunner.assertType(region.levels[0], "table")
        TestRunner.assertType(region.levels[-1], "table")
        TestRunner.assertType(region.levels[-2], "table")
        TestRunner.assertType(region.levels[1], "table")
        TestRunner.assertEqual(region.currentDepth, 0)
    end)

    it("generates a bordered macro-world with reachable critical expedition POIs", function()
        Utils.setGameSeed(false, 2026)
        local region = ProcGen.generateRunData("normal")

        TestRunner.assertEqual(#region.grid, CONFIG.WORLD_GRID_HEIGHT)
        TestRunner.assertEqual(#region.grid[1], CONFIG.WORLD_GRID_WIDTH)
        for x = 1, CONFIG.WORLD_GRID_WIDTH do
            TestRunner.assertFalse(isWalkable(region.grid[1][x]))
            TestRunner.assertFalse(isWalkable(region.grid[CONFIG.WORLD_GRID_HEIGHT][x]))
        end
        for y = 1, CONFIG.WORLD_GRID_HEIGHT do
            TestRunner.assertFalse(isWalkable(region.grid[y][1]))
            TestRunner.assertFalse(isWalkable(region.grid[y][CONFIG.WORLD_GRID_WIDTH]))
        end

        local requiredPOIs = {
            "Frontier Cabin",
            "Frozen Marsh",
            "North Ravine",
            "Glacial Beacon",
            "Trapline Cabin",
            "Weather Station",
            "Shattered Basin",
        }
        for _, name in ipairs(requiredPOIs) do
            local poi = findPOI(region, name)
            TestRunner.assertType(poi, "table")
            TestRunner.assertTrue(canReach(region.grid, region.playerStart, poi.coord), name .. " should be reachable")
        end

        TestRunner.assertTrue(#region.hazardZones >= 5)
        TestRunner.assertTrue(#region.goals >= 2)
        TestRunner.assertTrue(findPOI(region, "Weather Station").biome == "Ash Barrens")
        TestRunner.assertTrue(findPOI(region, "Hidden Vale Cache").hidden)
        TestRunner.assertFalse(findPOI(region, "Hidden Vale Cache").revealed)
        TestRunner.assertEqual(findById(region.regions, "frontier_reach").role, "safe_fringe")
        TestRunner.assertEqual(findById(region.regions, "hidden_vale").role, "gated_shortcut")
        TestRunner.assertEqual(findById(region.gates, "signal_post").toolType, "signal_bolt")
        TestRunner.assertFalse(findById(region.gates, "signal_post").revealed)
    end)

    it("creates coherent traversal gates and exploration encounters", function()
        Utils.setGameSeed(false, 8080)
        local region = ProcGen.generateRunData("hard")

        local anchorCliff = findById(region.gates, "anchor_cliff")
        local brokenBridge = findById(region.gates, "broken_bridge")
        local signalPost = findById(region.gates, "signal_post")
        TestRunner.assertType(anchorCliff, "table")
        TestRunner.assertType(brokenBridge, "table")
        TestRunner.assertType(signalPost, "table")
        TestRunner.assertEqual(anchorCliff.ammoKind, "rope_bolt")
        TestRunner.assertEqual(brokenBridge.repairCost.bridge_kit, 1)
        TestRunner.assertEqual(signalPost.requiresWeapon, "bow")

        local hiddenConnection = nil
        for _, connection in ipairs(region.connections) do
            if connection.gateId == "signal_post" then
                hiddenConnection = connection
                break
            end
        end
        TestRunner.assertType(hiddenConnection, "table")
        TestRunner.assertEqual(hiddenConnection.status, "hidden")

        local encounterKinds = {}
        for _, encounter in ipairs(region.npcEncounters) do
            encounterKinds[encounter.kind] = true
            TestRunner.assertEqual(encounter.resolutionState, "active")
            TestRunner.assertType(findById(region.regions, encounter.regionId), "table")
        end
        TestRunner.assertTrue(encounterKinds.injured_survivor)
        TestRunner.assertTrue(encounterKinds.roaming_trader)
        TestRunner.assertTrue(encounterKinds.rival_explorer)
        TestRunner.assertTrue(encounterKinds.scavenger)
    end)

    it("generates distinct reachable layered depths with constrained stairs", function()
        Utils.setGameSeed(false, 9090)
        local region = ProcGen.generateRunData("normal")
        local levels = region.levels

        TestRunner.assertEqual(levels[0].name, "Frozen Surface")
        TestRunner.assertEqual(levels[-1].name, "Ice Caves")
        TestRunner.assertEqual(levels[-2].name, "Deep Ruins")
        TestRunner.assertEqual(levels[1].name, "Exposed Ridge")

        local caveCounts = tileCounts(levels[-1])
        local deepCounts = tileCounts(levels[-2])
        local ridgeCounts = tileCounts(levels[1])
        TestRunner.assertTrue((caveCounts.cave_floor or 0) > 100)
        TestRunner.assertTrue((caveCounts.ice or 0) > 20)
        TestRunner.assertTrue((deepCounts.thermal_fissure or 0) > 0)
        TestRunner.assertTrue((deepCounts.shale or 0) > 100)
        TestRunner.assertTrue((ridgeCounts.snow or 0) > 100)
        TestRunner.assertTrue((ridgeCounts.cabin_floor or 0) > 0)

        assertValidStairs(levels[0])
        assertValidStairs(levels[-1])
        assertValidStairs(levels[-2])
        assertValidStairs(levels[1])

        local surfaceDownX, surfaceDownY = firstTile(levels[0], "stair_down")
        local caveDownX, caveDownY = firstTile(levels[-1], "stair_down")
        local deepUpX, deepUpY = firstTile(levels[-2], "stair_up")
        local ridgeDownX, ridgeDownY = firstTile(levels[1], "stair_down")
        TestRunner.assertType(surfaceDownX, "number")
        TestRunner.assertType(caveDownX, "number")
        TestRunner.assertType(deepUpX, "number")
        TestRunner.assertType(ridgeDownX, "number")

        TestRunner.assertTrue(World.isReachable(levels[0], region.playerStart, worldCoord(surfaceDownX, surfaceDownY)))
        TestRunner.assertTrue(World.isReachable(levels[-1], worldCoord(80, 22), worldCoord(caveDownX, caveDownY)))
        TestRunner.assertTrue(World.isReachable(levels[-2], worldCoord(deepUpX, deepUpY), levels[-2].pointsOfInterest[2].coord))
        TestRunner.assertTrue(World.isReachable(levels[1], worldCoord(ridgeDownX, ridgeDownY), levels[1].pointsOfInterest[2].coord))

        TestRunner.assertTrue(#levels[-1].hazardZones >= 2)
        TestRunner.assertTrue(#levels[-2].resourceNodes >= 2)
        TestRunner.assertTrue(#levels[1].pointsOfInterest >= 2)
    end)

    it("adds rich sub-biomes with valid reachable anchors on companion depths", function()
        Utils.setGameSeed(false, 4242)
        local region = ProcGen.generateRunData("normal")
        local levels = region.levels

        TestRunner.assertTrue(#levels[-1].biomes >= 5)
        TestRunner.assertTrue(#levels[-2].biomes >= 5)
        TestRunner.assertTrue(#levels[1].biomes >= 5)

        for _, biomeId in ipairs({
            "frozen_tunnels",
            "subglacial_pools",
            "coal_pockets",
            "brittle_ice_shelves",
            "warm_refuge_pockets",
        }) do
            TestRunner.assertTrue(listHasId(levels[-1].biomes, biomeId), biomeId)
        end

        for _, biomeId in ipairs({
            "collapsed_mine_corridors",
            "shale_chambers",
            "thermal_fissure_fields",
            "supply_caches",
            "ruin_shelters",
        }) do
            TestRunner.assertTrue(listHasId(levels[-2].biomes, biomeId), biomeId)
        end

        for _, biomeId in ipairs({
            "wind_scoured_paths",
            "tree_rock_breaks",
            "exposed_drifts",
            "weather_station_grounds",
            "emergency_caches",
        }) do
            TestRunner.assertTrue(listHasId(levels[1].biomes, biomeId), biomeId)
        end

        assertValidLayerAnchors(levels[-1])
        assertValidLayerAnchors(levels[-2])
        assertValidLayerAnchors(levels[1])

        assertReachablePois(levels[-1], worldCoord(80, 22))
        assertReachablePois(levels[-2], worldCoord(82, 24))
        assertReachablePois(levels[1], worldCoord(100, 20))

        TestRunner.assertTrue(listHasId(levels[-1].hazardZones, "brittle_ice_shelves"))
        TestRunner.assertTrue(listHasId(levels[-2].hazardZones, "thermal_fissure_fields"))
        TestRunner.assertTrue(listHasId(levels[1].resourceNodes, "tree_rock_breaks"))
    end)

    it("adds distinct depth spawn rules for entity wildlife migration", function()
        Utils.setGameSeed(false, 5151)
        local region = ProcGen.generateRunData("normal")

        TestRunner.assertTrue(#region.levels[0].spawnRules >= 3)
        TestRunner.assertTrue(#region.levels[-1].spawnRules >= 1)
        TestRunner.assertTrue(#region.levels[-2].spawnRules >= 1)
        TestRunner.assertTrue(#region.levels[1].spawnRules >= 1)

        local caveWolf = false
        for _, rule in ipairs(region.levels[-1].spawnRules) do
            caveWolf = caveWolf or rule.kind == "wolf"
            TestRunner.assertType(rule.cap, "number")
            TestRunner.assertType(rule.zone, "table")
        end
        TestRunner.assertTrue(caveWolf)
    end)

    it("mirrors generated stations and caches into furniture entities", function()
        Utils.setGameSeed(false, 6060)
        local region = ProcGen.generateRunData("normal")
        local level = region.levels[0]
        local workbench = region.workbenches[1]
        local cache = nil
        for _, node in ipairs(region.resourceNodes) do
            if node.type == "cache" then
                cache = node
                break
            end
        end

        local workbenchX, workbenchY = coordToTile(workbench.coord)
        local cacheX, cacheY = coordToTile(cache.coord)
        local hasWorkbench = false
        local hasCache = false
        for _, entity in ipairs(EntitySystem.getTileEntities(level, workbenchX, workbenchY)) do
            hasWorkbench = hasWorkbench or entity.station == "workbench"
        end
        for _, entity in ipairs(EntitySystem.getTileEntities(level, cacheX, cacheY)) do
            hasCache = hasCache or entity.kind == "chest"
        end

        TestRunner.assertTrue(hasWorkbench)
        TestRunner.assertTrue(hasCache)
    end)

    it("builds runtime world data from editor-authored layouts", function()
        local region = ProcGen.generateRunData("normal", {
            layout = buildEditorLayout(),
        })

        TestRunner.assertEqual(region.source, "editor")
        TestRunner.assertTrue(#region.structures >= 2)
        TestRunner.assertTrue(#region.safeSleepSpots >= 2)
        TestRunner.assertTrue(#region.weakIceTiles >= 2)
        TestRunner.assertTrue(countNodes(region.resourceNodes, "loot") + countNodes(region.resourceNodes, "cache") >= 1)
        TestRunner.assertEqual(#region.wildlife.wolves, 1)
        TestRunner.assertEqual(#region.wildlife.rabbits, 1)
        TestRunner.assertEqual(#region.wildlife.deer, 1)
        TestRunner.assertEqual(#region.wildlife.raiders, 0)
        TestRunner.assertTrue(#region.fishingSpots >= 1)
        TestRunner.assertTrue(#region.climbNodes >= 1)
        TestRunner.assertTrue(#region.mapNodes >= 1)
        TestRunner.assertTrue(#region.workbenches >= 1)
        TestRunner.assertTrue(#region.carcasses >= 1)
        TestRunner.assertEqual(#region.biomes, 1)

        local startTileX = math.floor(region.playerStart[1] / 20) + 1
        local startTileY = math.floor(region.playerStart[2] / 20) + 1
        TestRunner.assertNotEqual(region.grid[startTileY][startTileX], "rock")
        TestRunner.assertNotEqual(region.grid[startTileY][startTileX], "lake")
    end)
end)
