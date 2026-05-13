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

    it("rejects the wrong tool for tile harvesting", function()
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
                equippedTool = "knife",
                inventory = {},
                stamina = 10,
            },
        }
        World.attachRun(run)

        local ok = World.hitFacingTile(run)

        TestRunner.assertFalse(ok)
        TestRunner.assertEqual(run.world.grid[2][3], "tree")
        TestRunner.assertEqual(Items.count(run.player.inventory, "sticks"), 0)
    end)

    it("spawns offscreen entities on valid tiles and respects caps", function()
        local run = {
            world = {
                grid = {
                    {"rock", "rock", "rock", "rock", "rock"},
                    {"rock", "snow", "snow", "snow", "rock"},
                    {"rock", "snow", "rock", "snow", "rock"},
                    {"rock", "snow", "snow", "snow", "rock"},
                    {"rock", "rock", "rock", "rock", "rock"},
                },
            },
            player = {coord = {20, 20}, lastSafeCoord = {20, 20}},
        }
        World.attachRun(run)

        local first = World.spawnOffscreen(run, "wolf", {
            cap = 1,
            zone = {x = 4, y = 4, width = 1, height = 1},
            minDistanceTiles = 1,
        })
        local second = World.spawnOffscreen(run, "wolf", {
            cap = 1,
            zone = {x = 4, y = 4, width = 1, height = 1},
            minDistanceTiles = 1,
        })

        TestRunner.assertType(first, "table")
        TestRunner.assertEqual(second, nil)
        TestRunner.assertEqual(first.depth, 0)
    end)

    it("ticks environmental simulation state conservatively", function()
        local run = {
            world = {
                grid = {
                    {"rock", "rock", "rock"},
                    {"rock", "snow", "rock"},
                    {"rock", "rock", "rock"},
                },
                weather = {current = "blizzard", hoursUntilChange = 1},
                snowShelters = {
                    {coord = {20, 20}, integrity = 100},
                },
                fires = {
                    {coord = {20, 20}, remainingBurnHours = 1, remainingEmbersHours = 0},
                },
                resourceNodes = {
                    {type = "loot", coord = {20, 20}, opened = true, regrowHours = 0.5},
                },
            },
            player = {coord = {20, 20}, lastSafeCoord = {20, 20}},
        }
        World.attachRun(run)

        World.tick(run, 1)

        TestRunner.assertTrue(run.world.snowShelters[1].integrity < 100)
        TestRunner.assertFalse(run.world.resourceNodes[1].opened)
        TestRunner.assertTrue(run.world.resourceNodes[1].regrown)
        TestRunner.assertEqual(run.world.resourceNodes[1].lastRegrowDepth, 0)
        TestRunner.assertEqual(run.world.fires[1].decayTicks, 1)
        TestRunner.assertEqual(run.world.fires[1].lastTickDepth, 0)
        TestRunner.assertType(run.world.snowCover, "table")
    end)

    it("returns active level collections through compatibility helpers", function()
        local run = {
            world = {
                grid = {
                    {"rock", "rock", "rock"},
                    {"rock", "snow", "rock"},
                    {"rock", "rock", "rock"},
                },
                resourceNodes = {},
            },
            player = {coord = {20, 20}, lastSafeCoord = {20, 20}},
        }
        World.attachRun(run)

        local resources, level = World.activeCollection(run, "resourceNodes")
        table.insert(resources, {type = "loot", coord = {20, 20}})
        local readResources = World.readActiveCollection(run, "resourceNodes")
        local missing = World.readActiveCollection(run, "uncreatedCollection")

        TestRunner.assertTrue(resources == level.resourceNodes)
        TestRunner.assertTrue(readResources == resources)
        TestRunner.assertTrue(run.world.resourceNodes == resources)
        TestRunner.assertEqual(#run.world.resourceNodes, 1)
        TestRunner.assertEqual(#missing, 0)
        TestRunner.assertEqual(level.uncreatedCollection, nil)
    end)

    it("batch-initializes active collections without touching inactive levels", function()
        local surface = {
            depth = 0,
            grid = {
                {"rock", "rock", "rock"},
                {"rock", "snow", "rock"},
                {"rock", "rock", "rock"},
            },
            traps = {},
        }
        local cave = {
            depth = -1,
            grid = {
                {"rock", "rock", "rock"},
                {"rock", "cave_floor", "rock"},
                {"rock", "rock", "rock"},
            },
        }
        local run = {
            world = {levels = {[0] = surface, [-1] = cave}, currentDepth = -1},
            player = {coord = {20, 20}, lastSafeCoord = {20, 20}},
        }
        World.attachRun(run)

        local collections, level = World.ensureActiveCollections(run, {"traps", "mapNodes", "curing"})
        table.insert(collections.traps, {coord = {20, 20}})

        TestRunner.assertTrue(level == cave)
        TestRunner.assertTrue(run.world.traps == cave.traps)
        TestRunner.assertEqual(#cave.traps, 1)
        TestRunner.assertEqual(#surface.traps, 0)
        TestRunner.assertType(cave.mapNodes, "table")
        TestRunner.assertType(cave.curing, "table")
    end)

    it("returns active wildlife and grid without leaking surface aliases", function()
        local surface = {
            depth = 0,
            grid = {
                {"rock", "rock", "rock"},
                {"rock", "snow", "rock"},
                {"rock", "rock", "rock"},
            },
            wildlife = {wolves = {{kind = "wolf"}}, rabbits = {}, deer = {}, raiders = {}},
        }
        local cave = {
            depth = -1,
            grid = {
                {"rock", "rock", "rock"},
                {"rock", "cave_floor", "rock"},
                {"rock", "rock", "rock"},
            },
            wildlife = {wolves = {}, rabbits = {{kind = "rabbit"}}, deer = {}, raiders = {}},
        }
        local run = {
            world = {levels = {[0] = surface, [-1] = cave}, currentDepth = -1},
            player = {coord = {20, 20}, lastSafeCoord = {20, 20}},
        }
        World.attachRun(run)

        local wildlife, level = World.activeWildlife(run)
        local grid = World.activeGrid(run)

        TestRunner.assertTrue(level == cave)
        TestRunner.assertTrue(run.world.wildlife == cave.wildlife)
        TestRunner.assertEqual(#wildlife.wolves, 0)
        TestRunner.assertEqual(#wildlife.rabbits, 1)
        TestRunner.assertEqual(grid[2][2], "cave_floor")
        TestRunner.assertEqual(#surface.wildlife.wolves, 1)
    end)

    it("summarizes active tile simulation state without mutating collections", function()
        local cave = {
            depth = -1,
            grid = {
                {"rock", "rock", "rock"},
                {"rock", "cave_floor", "rock"},
                {"rock", "rock", "rock"},
            },
            snowCover = {["2:2"] = 2},
            iceState = {["2:2"] = {stability = 4}},
            shelterWear = {["3:2"] = 1},
            warmthPockets = {},
            thermalWarmth = {["2:3"] = 3, ["3:3"] = 2},
        }
        local run = {
            world = {levels = {[-1] = cave}, currentDepth = -1},
            player = {coord = {20, 20}, lastSafeCoord = {20, 20}},
        }
        World.attachRun(run)

        local summary = World.activeSimulationSummary(run)

        TestRunner.assertEqual(summary.snowCoverTiles, 1)
        TestRunner.assertEqual(summary.iceStateTiles, 1)
        TestRunner.assertEqual(summary.shelterWearTiles, 1)
        TestRunner.assertEqual(summary.warmthPocketTiles, 0)
        TestRunner.assertEqual(summary.thermalWarmthTiles, 2)
        TestRunner.assertTrue(run.world.iceState == cave.iceState)
        TestRunner.assertTrue(run.world.thermalWarmth == cave.thermalWarmth)
    end)

    it("activates the ridge weather station with survey readiness", function()
        local ridge = {
            depth = 1,
            name = "Exposed Ridge",
            grid = {
                {"rock", "rock", "rock", "rock"},
                {"rock", "cabin_floor", "cabin_workbench", "rock"},
                {"rock", "snow", "snow", "rock"},
                {"rock", "rock", "rock", "rock"},
            },
            pointsOfInterest = {
                {name = "Ridge Weather Station", coord = {20, 20}},
            },
            goals = {
                {id = "activate_ridge_weather_station", completed = false},
            },
        }
        local run = {
            world = {levels = {[1] = ridge}, currentDepth = 1},
            player = {
                coord = {20, 20},
                lastSafeCoord = {20, 20},
                inventory = {},
            },
            runtime = {},
            stats = {},
        }
        Items.add(run.player.inventory, "survey_kit", 1)
        World.attachRun(run)

        local ok = World.activateEndgame(run)

        TestRunner.assertTrue(ok)
        TestRunner.assertTrue(run.runtime.endgameActivated)
        TestRunner.assertTrue(run.runtime.success)
        TestRunner.assertTrue(run.world.goals[1].completed)
        TestRunner.assertTrue(run.stats.weatherStationActivated)
        TestRunner.assertEqual(#run.runtime.replayEvents, 1)

        local again = World.activateEndgame(run)
        TestRunner.assertTrue(again)
        TestRunner.assertEqual(#run.runtime.replayEvents, 1)
    end)
end)
