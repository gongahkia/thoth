local TestRunner = require("test_runner")
local EntitySystem = require("entity_system")
local Items = require("items")
local World = require("world")

local describe = TestRunner.describe
local it = TestRunner.it

local function generatedWorld()
    return {
        grid = {
            {"rock", "rock", "rock"},
            {"rock", "snow", "rock"},
            {"rock", "rock", "rock"},
        },
        weather = {current = "clear", hoursUntilChange = 1},
        hazardZones = {},
        mappedTiles = {},
    }
end

describe("World", function()
    it("initializes layered levels while preserving active grid aliases", function()
        local world = World.initialize(generatedWorld())

        TestRunner.assertType(world.levels[0], "table")
        TestRunner.assertType(world.levels[-1], "table")
        TestRunner.assertType(world.levels[-2], "table")
        TestRunner.assertType(world.levels[1], "table")
        TestRunner.assertTrue(world.grid == world.levels[0].grid)
        TestRunner.assertEqual(world.currentDepth, 0)
    end)

    it("changes active depth and keeps player depth in sync", function()
        local run = {
            world = generatedWorld(),
            player = {coord = {20, 20}, lastSafeCoord = {20, 20}},
        }
        World.attachRun(run)
        local ok = World.changeDepth(run, -1, {40, 40})

        TestRunner.assertTrue(ok)
        TestRunner.assertEqual(run.world.currentDepth, -1)
        TestRunner.assertEqual(run.player.depth, -1)
        TestRunner.assertEqual(run.player.coord[1], 40)
        TestRunner.assertTrue(run.world.grid == run.world.levels[-1].grid)
    end)

    it("resolves facing tiles from the player's last movement direction", function()
        local run = {
            world = generatedWorld(),
            player = {coord = {20, 20}, lastMoveX = 1, lastMoveY = 0},
        }
        World.attachRun(run)
        run.world.grid[2][3] = "tree"

        local tile, _level, x, y, behavior = World.facingTile(run)

        TestRunner.assertEqual(tile, "tree")
        TestRunner.assertEqual(x, 3)
        TestRunner.assertEqual(y, 2)
        TestRunner.assertEqual(behavior.name, "tree")
    end)

    it("returns the entity occupying the faced tile", function()
        local run = {
            world = generatedWorld(),
            player = {coord = {20, 20}, lastMoveX = 1, lastMoveY = 0},
        }
        World.attachRun(run)
        local level = World.currentLevel(run)
        local entity = EntitySystem.spawn(level, "crate", {40, 20}, {solid = true})

        TestRunner.assertTrue(World.facingEntity(run) == entity)
    end)

    it("interacts with stairs to move between layered depths", function()
        local surface = {
            depth = 0,
            grid = {
                {"rock", "rock", "rock", "rock"},
                {"rock", "snow", "stair_down", "rock"},
                {"rock", "snow", "snow", "rock"},
                {"rock", "rock", "rock", "rock"},
            },
        }
        local cave = {
            depth = -1,
            grid = {
                {"rock", "rock", "rock", "rock"},
                {"rock", "snow", "stair_up", "rock"},
                {"rock", "snow", "snow", "rock"},
                {"rock", "rock", "rock", "rock"},
            },
        }
        local run = {
            world = {levels = {[0] = surface, [-1] = cave}, currentDepth = 0},
            player = {coord = {20, 20}, lastSafeCoord = {20, 20}, lastMoveX = 1, lastMoveY = 0},
        }
        World.attachRun(run)

        local descended = World.interactFacing(run)
        TestRunner.assertTrue(descended)
        TestRunner.assertEqual(run.world.currentDepth, -1)
        TestRunner.assertEqual(run.player.depth, -1)

        local ascended = World.interactFacing(run)
        TestRunner.assertTrue(ascended)
        TestRunner.assertEqual(run.world.currentDepth, 0)
        TestRunner.assertEqual(run.player.depth, 0)
    end)

    it("hits the faced tile with the equipped tool and adds tile drops", function()
        local run = {
            world = {
                grid = {
                    {"rock", "rock", "rock", "rock"},
                    {"rock", "snow", "tree", "rock"},
                    {"rock", "snow", "snow", "rock"},
                    {"rock", "rock", "rock", "rock"},
                },
            },
            player = {
                coord = {20, 20},
                lastMoveX = 1,
                lastMoveY = 0,
                equippedTool = "hatchet",
                inventory = {},
                stamina = 10,
            },
        }
        World.attachRun(run)

        local firstOk = World.hitFacingTile(run)
        local secondOk = World.hitFacingTile(run)

        TestRunner.assertTrue(firstOk)
        TestRunner.assertTrue(secondOk)
        TestRunner.assertEqual(run.world.grid[2][3], "snow")
        TestRunner.assertTrue(Items.count(run.player.inventory, "sticks") >= 2)
        TestRunner.assertTrue(Items.count(run.player.inventory, "firewood") >= 1)
    end)
end)
