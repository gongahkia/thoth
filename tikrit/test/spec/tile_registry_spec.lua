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

    it("records conservative environmental random tick state", function()
        local level = {
            depth = 0,
            grid = {
                {"snow", "snow", "snow"},
                {"snow", "snow", "fire_safe"},
                {"snow", "snow", "snow"},
            },
            data = {},
        }

        TileRegistry.randomTick(level, 2, 2)
        TileRegistry.randomTick(level, 3, 2)

        TestRunner.assertType(level.snowCover, "table")
        TestRunner.assertType(level.shelterWear, "table")
        TestRunner.assertEqual(level.snowCover["2:2"], 1)
        TestRunner.assertEqual(level.shelterWear["3:2"], 1)
    end)
end)
