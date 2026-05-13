local TestRunner = require("test_runner")
local Fire = require("fire")
local Survival = require("survival")
local Items = require("items")
local World = require("world")

local describe = TestRunner.describe
local it = TestRunner.it

local function buildRun(tile, weather)
    local run = {
        difficultyName = "normal",
        player = Survival.createPlayer({}),
        world = {
            grid = {
                {tile, tile, tile},
                {tile, tile, tile},
                {tile, tile, tile},
            },
            fires = {},
            weather = {current = weather, hoursUntilChange = 3},
            timeOfDay = 12,
            dayCount = 1,
            snowShelters = {},
        },
        stats = {
            firesLit = 0,
            meatCooked = 0,
            waterBoiled = 0,
        },
        feats = {},
    }
    run.player.coord = {20, 20}
    Items.add(run.player.inventory, "accelerant", 1)
    return run
end

describe("Fire", function()
    it("starts sheltered fires and tracks burn time", function()
        local run = buildRun("cabin_floor", "blizzard")
        local ok = Fire.start(run, true)
        local fires = World.readActiveCollection(run, "fires")
        local level = World.currentLevel(run)
        TestRunner.assertTrue(ok)
        TestRunner.assertEqual(#fires, 1)
        TestRunner.assertType(fires[1]._entityKey, "string")
        Fire.update(run, 3.2)
        TestRunner.assertEqual(#fires, 1)
        Fire.update(run, 1.2)
        TestRunner.assertEqual(#fires, 0)
        TestRunner.assertEqual(#level.entities, 0)
    end)

    it("creates fires on the active depth only", function()
        local surface = buildRun("cabin_floor", "clear").world
        local cave = buildRun("cabin_floor", "clear").world
        surface.depth = 0
        cave.depth = -1
        local run = buildRun("cabin_floor", "clear")
        run.world = {
            levels = {[0] = surface, [-1] = cave},
            currentDepth = -1,
            weather = {current = "clear", hoursUntilChange = 3},
        }
        World.attachRun(run)

        local ok = Fire.start(run, true)

        TestRunner.assertTrue(ok)
        TestRunner.assertEqual(#run.world.levels[0].fires, 0)
        TestRunner.assertEqual(#run.world.levels[-1].fires, 1)
    end)

    it("blocks exposed fires during blizzards", function()
        local run = buildRun("snow", "blizzard")
        local ok = Fire.start(run, false)
        local fires = World.readActiveCollection(run, "fires")
        TestRunner.assertFalse(ok)
        TestRunner.assertEqual(#fires, 0)
    end)

    it("cooks meat and boils water at an active fire", function()
        local run = buildRun("cabin_floor", "clear")
        Fire.start(run, true)
        Items.add(run.player.inventory, "raw_meat", 1)
        local ok = Fire.interact(run)
        TestRunner.assertTrue(ok)
        TestRunner.assertEqual(Items.count(run.player.inventory, "cooked_meat"), 1)

        Items.add(run.player.inventory, "snow", 1)
        Fire.interact(run)
        TestRunner.assertTrue(Items.count(run.player.inventory, "water") >= 3)
    end)
end)
