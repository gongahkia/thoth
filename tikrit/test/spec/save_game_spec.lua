local TestRunner = require("test_runner")
local EntitySystem = require("entity_system")
local SaveGame = require("save_game")
local Survival = require("survival")
local World = require("world")

local describe = TestRunner.describe
local it = TestRunner.it

local originalLove = _G.love
local files = {}
local directories = {}

_G.love = {
    filesystem = {
        createDirectory = function(path)
            directories[path] = true
        end,
        getDirectoryItems = function(path)
            local items = {}
            for filePath in pairs(files) do
                local item = filePath:match("^" .. path .. "/(.+)$")
                if item then
                    table.insert(items, item)
                end
            end
            table.sort(items)
            return items
        end,
        read = function(path)
            return files[path]
        end,
        write = function(path, contents)
            files[path] = contents
            return true
        end,
        remove = function(path)
            if files[path] then
                files[path] = nil
                return true
            end
            return false
        end,
    },
}

local function grid()
    return {
        {"rock", "rock", "rock", "rock", "rock"},
        {"rock", "snow", "snow", "snow", "rock"},
        {"rock", "snow", "cabin_workbench", "snow", "rock"},
        {"rock", "snow", "snow", "snow", "rock"},
        {"rock", "rock", "rock", "rock", "rock"},
    }
end

local function buildRun()
    local surface = {
        depth = 0,
        name = "Surface",
        grid = grid(),
        resourceNodes = {
            {
                type = "cache",
                coord = {40, 40},
                opened = true,
                loot = {},
                damage = 2,
            },
        },
        fires = {
            {coord = {20, 20}, remainingBurnHours = 1, remainingEmbersHours = 0},
        },
        traps = {
            {coord = {60, 20}, state = "set", hoursUntilCatch = 2},
        },
        carcasses = {
            {kind = "rabbit", coord = {60, 60}, drops = {}, harvestHours = 0.5},
        },
        wildlife = {
            wolves = {
                {
                    kind = "wolf",
                    coord = {60, 40},
                    state = "roam",
                    aiState = "roam",
                    facingX = 1,
                    facingY = 0,
                    moving = false,
                    territory = {x = 2, y = 2, width = 2, height = 2},
                    territoryCenter = {50, 50},
                },
            },
            rabbits = {},
            deer = {},
            raiders = {},
        },
        spawnRules = {
            {id = "surface_wolf", kind = "wolf", listName = "wolves", cap = 2, chancePerHour = 0.1},
        },
        spawnState = {
            surface_wolf = {cooldownHours = 1.5, spawned = 1},
        },
        snowCover = {["2:2"] = 3},
        iceState = {["2:3"] = {stability = 2, refrozen = true}},
        shelterWear = {["3:3"] = 4},
        warmthPockets = {["3:3"] = 2},
        thermalWarmth = {["4:3"] = 5},
    }
    local cave = {
        depth = -1,
        name = "Cave",
        grid = grid(),
        resourceNodes = {},
        wildlife = {wolves = {}, rabbits = {}, deer = {}, raiders = {}},
        spawnRules = {},
        spawnState = {},
        snowCover = {["2:2"] = 1},
        iceState = {["2:2"] = {stability = 5}},
        shelterWear = {},
        warmthPockets = {},
        thermalWarmth = {["3:3"] = 1},
    }
    local run = {
        difficultyName = "normal",
        mode = "survival",
        sourceMode = "survival",
        seed = 1234,
        world = {
            levels = {[0] = surface, [-1] = cave},
            currentDepth = -1,
            weather = {current = "snow", hoursUntilChange = 2},
            timeOfDay = 13,
            dayCount = 2,
        },
        player = Survival.createPlayer({}),
        runtime = {
            endgameActivated = true,
            success = true,
            endgameDepth = 1,
        },
        stats = {
            daysSurvived = 2,
            wolvesRepelled = 1,
        },
    }
    run.player.coord = {40, 40}
    run.player.depth = -1
    World.attachRun(run)
    return run
end

describe("SaveGame", function()
    it("snapshots layered runs without transient entity mirrors", function()
        local run = buildRun()
        World.changeDepth(run, 0, {40, 40})
        local level = World.currentLevel(run)
        TestRunner.assertTrue(#level.entities > 0)

        local snapshot = SaveGame.snapshotRun(run)
        TestRunner.assertEqual(snapshot.world.currentDepth, 0)
        TestRunner.assertEqual(snapshot.player.depth, 0)
        TestRunner.assertEqual(snapshot.world.levels[0].entities, nil)
        TestRunner.assertEqual(snapshot.world.levels[0].tileEntities, nil)
        TestRunner.assertEqual(snapshot.world.levels[0].resourceNodes[1]._entityKey, nil)
        TestRunner.assertEqual(snapshot.world.levels[0].wildlife.wolves[1]._wildlifeEntity, nil)
        TestRunner.assertEqual(snapshot.world.levels[0].spawnState.surface_wolf.cooldownHours, 1.5)
        TestRunner.assertEqual(snapshot.world.levels[0].snowCover["2:2"], 3)
        TestRunner.assertEqual(snapshot.world.levels[0].iceState["2:3"].stability, 2)
        TestRunner.assertEqual(snapshot.world.levels[0].thermalWarmth["4:3"], 5)
    end)

    it("round-trips save data and rebuilds active-depth aliases and mirrors", function()
        local run = buildRun()
        World.changeDepth(run, 0, {40, 40})
        TestRunner.assertTrue(SaveGame.saveRun("phase12_slot", run))

        local restored = SaveGame.loadRun("phase12_slot")
        TestRunner.assertType(restored, "table")
        TestRunner.assertEqual(restored.world.currentDepth, 0)
        TestRunner.assertEqual(restored.player.depth, 0)
        TestRunner.assertTrue(restored.world.grid == restored.world.levels[0].grid)
        TestRunner.assertTrue(restored.runtime.endgameActivated)
        TestRunner.assertTrue(restored.runtime.success)
        TestRunner.assertEqual(restored.world.levels[0].resourceNodes[1].opened, true)
        TestRunner.assertEqual(restored.world.levels[0].resourceNodes[1].damage, 2)
        TestRunner.assertEqual(restored.world.levels[0].spawnState.surface_wolf.spawned, 1)
        TestRunner.assertEqual(restored.world.levels[0].snowCover["2:2"], 3)
        TestRunner.assertEqual(restored.world.levels[0].iceState["2:3"].stability, 2)
        TestRunner.assertEqual(restored.world.levels[0].shelterWear["3:3"], 4)
        TestRunner.assertEqual(restored.world.levels[0].warmthPockets["3:3"], 2)
        TestRunner.assertEqual(restored.world.levels[0].thermalWarmth["4:3"], 5)
        TestRunner.assertTrue(restored.world.snowCover == restored.world.levels[0].snowCover)
        TestRunner.assertTrue(restored.world.iceState == restored.world.levels[0].iceState)
        TestRunner.assertTrue(restored.world.thermalWarmth == restored.world.levels[0].thermalWarmth)

        World.attachRun(restored)
        World.attachRun(restored)
        local mirrored = 0
        for _, entity in ipairs(World.currentLevel(restored).entities or {}) do
            if entity._furnitureEntity or entity._worldObjectKey or entity._wildlifeEntity then
                mirrored = mirrored + 1
            end
        end
        TestRunner.assertTrue(mirrored > 0)
        TestRunner.assertEqual(#EntitySystem.getTileEntities(World.currentLevel(restored), 3, 3), 2)
    end)

    it("lists and inspects saved slots", function()
        local run = buildRun()
        TestRunner.assertTrue(SaveGame.saveRun("phase12_list_a", run))
        TestRunner.assertTrue(SaveGame.saveRun("phase12_list_b", run))

        local saves = SaveGame.listSaves()
        local seen = {}
        for _, save in ipairs(saves) do
            seen[save] = true
        end
        TestRunner.assertTrue(seen["phase12_list_a.lua"])
        TestRunner.assertTrue(seen["phase12_list_b.lua"])

        local inspected = SaveGame.inspect("phase12_list_a")
        TestRunner.assertEqual(inspected.seed, 1234)
        TestRunner.assertEqual(inspected.world.currentDepth, -1)
    end)

    it("manages named save slots and deletes selected saves", function()
        local run = buildRun()
        TestRunner.assertEqual(SaveGame.normalizeSlot("Ridge Camp #1"), "Ridge_Camp__1.lua")
        TestRunner.assertTrue(SaveGame.saveRun("ridge camp", run, {label = "Ridge Camp"}))

        local inspected = SaveGame.inspect("ridge camp")
        TestRunner.assertEqual(inspected.slot, "ridge_camp.lua")
        TestRunner.assertEqual(inspected.slotLabel, "Ridge Camp")

        local entries = SaveGame.listSaveEntries()
        local found
        for _, entry in ipairs(entries) do
            if entry.slot == "ridge_camp.lua" then
                found = entry
                break
            end
        end
        TestRunner.assertType(found, "table")
        TestRunner.assertEqual(found.label, "Ridge Camp")
        TestRunner.assertEqual(found.world.currentDepth, -1)

        TestRunner.assertTrue(SaveGame.delete("ridge camp"))
        TestRunner.assertEqual(SaveGame.inspect("ridge camp"), nil)
        TestRunner.assertFalse(SaveGame.delete("ridge camp"))
    end)
end)

_G.love = originalLove
