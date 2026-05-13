local TestRunner = require("test_runner")
local TileRegistry = require("tile_registry")

local describe = TestRunner.describe
local it = TestRunner.it

describe("TileRegistry", function()
    it("exposes Microcraft-style behavior hooks for known tiles", function()
        local tree = TileRegistry.get("tree")

        TestRunner.assertTrue(tree:isSolid())
        TestRunner.assertTrue(tree:isDestructible())
        TestRunner.assertType(tree.collides, "function")
        TestRunner.assertType(tree.step, "function")
        TestRunner.assertType(tree.bump, "function")
        TestRunner.assertType(tree.hit, "function")
        TestRunner.assertType(tree.interact, "function")
        TestRunner.assertType(tree.randomTick, "function")
        TestRunner.assertFalse(TileRegistry.isWalkable("tree"))
        TestRunner.assertTrue(TileRegistry.isWalkable("snow"))
    end)

    it("tracks tile damage, swaps base tiles, and returns drops", function()
        local level = {
            depth = 0,
            grid = {
                {"snow", "snow", "snow"},
                {"snow", "tree", "snow"},
                {"snow", "snow", "snow"},
            },
            data = {},
        }
        local entity = {tileDamage = 10}
        local ok, drops = TileRegistry.hit(level, 2, 2, entity)

        TestRunner.assertTrue(ok)
        TestRunner.assertEqual(level.grid[2][2], "snow")
        TestRunner.assertTrue(#drops >= 1)
    end)

    it("records weather-aware environmental random tick state", function()
        local level = {
            depth = 0,
            grid = {
                {"snow", "snow", "snow"},
                {"snow", "snow", "fire_safe"},
                {"snow", "snow", "snow"},
            },
            data = {},
        }
        local run = {world = {weather = {current = "blizzard"}}}

        TileRegistry.randomTick(level, 2, 2, run)
        TileRegistry.randomTick(level, 3, 2, run)

        TestRunner.assertType(level.snowCover, "table")
        TestRunner.assertType(level.shelterWear, "table")
        TestRunner.assertEqual(level.snowCover["2:2"], 2)
        TestRunner.assertEqual(level.shelterWear["3:2"], 2)
        TestRunner.assertEqual(level.warmthPockets["3:2"], 1)
    end)

    it("refreezes weak ice deterministically under cold weather", function()
        local level = {
            depth = -1,
            grid = {
                {"snow", "snow", "snow"},
                {"snow", "weak_ice", "snow"},
                {"snow", "snow", "snow"},
            },
            data = {},
        }
        local run = {world = {weather = {current = "snow"}}}

        TileRegistry.randomTick(level, 2, 2, run)
        TileRegistry.randomTick(level, 2, 2, run)
        TileRegistry.randomTick(level, 2, 2, run)

        TestRunner.assertEqual(level.grid[2][2], "ice")
        TestRunner.assertEqual(level.data[2][2], 0)
        TestRunner.assertTrue(level.iceState["2:2"].refrozen)
    end)

    it("tracks thermal warmth but only warms nearby players", function()
        local level = {
            depth = -2,
            grid = {
                {"shale", "shale", "shale"},
                {"shale", "thermal_fissure", "shale"},
                {"shale", "shale", "shale"},
            },
        }
        local run = {
            world = {weather = {current = "clear"}},
            player = {coord = {20, 20}, warmth = 50},
        }

        TileRegistry.randomTick(level, 2, 2, run)
        TestRunner.assertEqual(level.thermalWarmth["2:2"], 1)
        TestRunner.assertEqual(run.player.warmth, 51)

        run.player.coord = {400, 400}
        TileRegistry.randomTick(level, 2, 2, run)
        TestRunner.assertEqual(level.thermalWarmth["2:2"], 2)
        TestRunner.assertEqual(run.player.warmth, 51)
    end)
end)
