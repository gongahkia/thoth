local TestRunner = require("test_runner")
local EntitySystem = require("entity_system")
local Items = require("items")
local Survival = require("survival")
local Utils = require("utils")
local World = require("world")
local WorldObjects = require("world_objects")

local describe = TestRunner.describe
local it = TestRunner.it

local function levelWithObjects()
    return {
        depth = 0,
        grid = {
            {"rock", "rock", "rock", "rock", "rock"},
            {"rock", "snow", "snow", "snow", "rock"},
            {"rock", "snow", "snow", "snow", "rock"},
            {"rock", "snow", "snow", "snow", "rock"},
            {"rock", "rock", "rock", "rock", "rock"},
        },
        fires = {
            {coord = {20, 20}, remainingBurnHours = 1, remainingEmbersHours = 1},
        },
        traps = {
            {coord = {40, 20}, state = "set"},
        },
        carcasses = {
            {coord = {60, 20}, kind = "rabbit"},
        },
        resourceNodes = {
            {type = "loot", coord = {20, 40}, opened = false, loot = {}},
            {type = "cache", coord = {40, 40}, opened = false, loot = {}},
        },
        fishingSpots = {
            {coord = {60, 40}},
        },
        climbNodes = {
            {coord = {20, 60}, targetCoord = {60, 60}},
        },
        mapNodes = {
            {coord = {40, 60}, survey = true},
        },
        gates = {
            {coord = {60, 60}, targetCoord = {20, 20}, revealed = true, unlockState = true},
            {coord = {20, 20}, targetCoord = {40, 40}, revealed = false, unlockState = true},
        },
        npcEncounters = {
            {coord = {40, 20}, kind = "rumor_giver", resolutionState = "active"},
            {coord = {60, 20}, kind = "rumor_giver", resolutionState = "resolved"},
        },
    }
end

local function countKind(level, kind)
    local total = 0
    for _, entity in ipairs(level.entities or {}) do
        if entity.kind == kind then
            total = total + 1
        end
    end
    return total
end

local function countLegacyFallbackCandidates(list)
    local total = 0
    for _, entry in ipairs(list or {}) do
        if not entry._entityKey then
            total = total + 1
        end
    end
    return total
end

describe("WorldObjects", function()
    it("mirrors live runtime lists into entities without duplicates", function()
        local level = levelWithObjects()

        WorldObjects.mirrorLevel(level)
        WorldObjects.mirrorLevel(level)

        TestRunner.assertEqual(countKind(level, "fire"), 1)
        TestRunner.assertEqual(countKind(level, "snare_trap"), 1)
        TestRunner.assertEqual(countKind(level, "carcass"), 1)
        TestRunner.assertEqual(countKind(level, "loot_marker"), 1)
        TestRunner.assertEqual(countKind(level, "fishing_spot"), 1)
        TestRunner.assertEqual(countKind(level, "climb_node"), 1)
        TestRunner.assertEqual(countKind(level, "map_node"), 1)
        TestRunner.assertEqual(countKind(level, "traversal_gate"), 2)
        TestRunner.assertEqual(countKind(level, "npc_encounter"), 1)
        TestRunner.assertType(level.fires[1]._entityKey, "string")
        TestRunner.assertType(level.traps[1]._entityKey, "string")
        TestRunner.assertType(level.carcasses[1]._entityKey, "string")
        TestRunner.assertType(level.resourceNodes[1]._entityKey, "string")
        TestRunner.assertEqual(level.resourceNodes[2]._entityKey, nil)
        TestRunner.assertType(level.fishingSpots[1]._entityKey, "string")
        TestRunner.assertType(level.climbNodes[1]._entityKey, "string")
        TestRunner.assertType(level.mapNodes[1]._entityKey, "string")
        TestRunner.assertType(level.gates[1]._entityKey, "string")
        TestRunner.assertType(level.npcEncounters[1]._entityKey, "string")
        TestRunner.assertEqual(level.npcEncounters[2]._entityKey, nil)
    end)

    it("renders mirrored objects and markers through EntitySystem", function()
        local level = levelWithObjects()
        WorldObjects.mirrorLevel(level)
        local draws = {fires = 0, traps = 0, carcasses = 0, loot = 0, markers = 0}

        EntitySystem.render(level, {
            drawFire = function() draws.fires = draws.fires + 1 end,
            drawTrap = function() draws.traps = draws.traps + 1 end,
            drawCarcass = function() draws.carcasses = draws.carcasses + 1 end,
            drawResourceNode = function() draws.loot = draws.loot + 1 end,
            drawWorldMarker = function() draws.markers = draws.markers + 1 end,
        })

        TestRunner.assertEqual(draws.fires, 1)
        TestRunner.assertEqual(draws.traps, 1)
        TestRunner.assertEqual(draws.carcasses, 1)
        TestRunner.assertEqual(draws.loot, 1)
        TestRunner.assertEqual(draws.markers, 5)
        TestRunner.assertEqual(countLegacyFallbackCandidates(level.fires), 0)
        TestRunner.assertEqual(countLegacyFallbackCandidates(level.traps), 0)
        TestRunner.assertEqual(countLegacyFallbackCandidates(level.carcasses), 0)
        TestRunner.assertEqual(countLegacyFallbackCandidates(level.fishingSpots), 0)
        TestRunner.assertEqual(countLegacyFallbackCandidates(level.climbNodes), 0)
        TestRunner.assertEqual(countLegacyFallbackCandidates(level.mapNodes), 0)
        TestRunner.assertEqual(countLegacyFallbackCandidates({level.gates[1]}), 0)
        TestRunner.assertEqual(countLegacyFallbackCandidates({level.npcEncounters[1]}), 0)
    end)

    it("prunes stale mirrored entities and remains deep-copyable", function()
        local level = levelWithObjects()
        WorldObjects.mirrorLevel(level)
        table.remove(level.fires, 1)
        table.remove(level.traps, 1)
        WorldObjects.mirrorLevel(level)

        TestRunner.assertEqual(countKind(level, "fire"), 0)
        TestRunner.assertEqual(countKind(level, "snare_trap"), 0)
        TestRunner.assertType(Utils.deepCopy(level), "table")
    end)

    it("interacts with faced marker entities through existing systems", function()
        local function runWithMarker(collection, source)
            local run = {
                world = {
                    grid = {
                        {"rock", "rock", "rock", "rock"},
                        {"rock", "snow", "snow", "rock"},
                        {"rock", "snow", "snow", "rock"},
                        {"rock", "rock", "rock", "rock"},
                    },
                    weather = {current = "clear", hoursUntilChange = 4},
                    timeOfDay = 10,
                    dayCount = 1,
                    mappedTiles = {},
                    discoveredPOIs = {},
                    pointsOfInterest = {},
                    landmarks = {},
                    regions = {},
                    connections = {},
                    gates = {},
                    mapNodes = {},
                    climbNodes = {},
                    fishingSpots = {},
                    npcEncounters = {},
                },
                player = Survival.createPlayer({}),
                runtime = {},
                stats = {daysSurvived = 1},
            }
            run.world[collection] = {source}
            run.player.coord = {20, 20}
            run.player.lastSafeCoord = {20, 20}
            run.player.lastMoveX = 1
            run.player.lastMoveY = 0
            World.attachRun(run)
            return run
        end

        local fishRun = runWithMarker("fishingSpots", {coord = {40, 20}})
        local fishOk, fishMessage = World.interactFacing(fishRun)
        TestRunner.assertFalse(fishOk)
        TestRunner.assertEqual(fishMessage, "You need fishing tackle.")

        local climbRun = runWithMarker("climbNodes", {coord = {40, 20}, targetCoord = {60, 20}})
        local climbOk = World.interactFacing(climbRun)
        TestRunner.assertTrue(climbOk)
        TestRunner.assertTableEqual(climbRun.player.coord, {60, 20})
        TestRunner.assertEqual(climbRun.runtime.pendingSound, "rope_climb")

        local mapRun = runWithMarker("mapNodes", {coord = {40, 20}})
        Items.add(mapRun.player.inventory, "charcoal", 1)
        local mapOk = World.interactFacing(mapRun)
        TestRunner.assertTrue(mapOk)
        TestRunner.assertTrue(next(mapRun.world.mappedTiles) ~= nil)
        TestRunner.assertEqual(mapRun.runtime.pendingSound, "map_reveal")

        local gateRun = runWithMarker("gates", {coord = {40, 20}, targetCoord = {60, 20}, revealed = true, unlockState = true})
        local gateOk = World.interactFacing(gateRun)
        TestRunner.assertTrue(gateOk)
        TestRunner.assertTableEqual(gateRun.player.coord, {60, 20})

        local npcRun = runWithMarker("npcEncounters", {coord = {40, 20}, kind = "rumor_giver", resolutionState = "active"})
        local npcOk = World.interactFacing(npcRun)
        TestRunner.assertTrue(npcOk)
        TestRunner.assertEqual(npcRun.world.npcEncounters[1].resolutionState, "resolved")
    end)
end)
