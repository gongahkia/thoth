local TestRunner = require("test_runner")
local EntitySystem = require("entity_system")
local Wildlife = require("wildlife")
local Survival = require("survival")
local World = require("world")

local describe = TestRunner.describe
local it = TestRunner.it

local function buildRun()
    local run = {
        difficultyName = "normal",
        player = Survival.createPlayer({}),
        world = {
            grid = {
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
            },
            spawnRules = {},
            fires = {},
            wildlife = {
                wolves = {
                    {
                        coord = {40, 40},
                        territory = {x = 1, y = 1, width = 4, height = 4},
                        territoryCenter = {40, 40},
                        state = "roam",
                    },
                },
                rabbits = {},
                deer = {},
            },
        },
        runtime = {},
        stats = {
            wolvesRepelled = 0,
        },
    }
    run.player.coord = {60, 40}
    return run
end

describe("Wildlife", function()
    it("mirrors legacy wildlife into entity buckets without duplicates", function()
        local run = buildRun()
        World.attachRun(run)
        local level = World.currentLevel(run)

        Wildlife.mirrorLevel(level)
        Wildlife.mirrorLevel(level)

        TestRunner.assertEqual(#run.world.wildlife.wolves, 1)
        TestRunner.assertEqual(#level.entities, 1)
        TestRunner.assertTrue(#EntitySystem.getTileEntities(level, 3, 3) >= 1)
    end)

    it("spawns capped offscreen wildlife through depth rules", function()
        local run = buildRun()
        run.player.coord = {20, 20}
        run.world.spawnRules = {
            {kind = "wolf", listName = "wolves", cap = 2, chancePerHour = 1, zone = {x = 4, y = 4, width = 1, height = 1}, minDistanceTiles = 1},
        }
        World.attachRun(run)

        Wildlife.update(run, 1)
        Wildlife.update(run, 1)

        TestRunner.assertEqual(#run.world.wildlife.wolves, 2)
        TestRunner.assertTrue(#World.currentLevel(run).entities >= 2)
    end)

    it("moves wolves from roaming into stalking and charging", function()
        local run = buildRun()
        Wildlife.update(run, 0.001)
        TestRunner.assertTrue(
            run.world.wildlife.wolves[1].state == "stalk"
            or run.world.wildlife.wolves[1].state == "charge"
            or run.world.wildlife.wolves[1].state == "windup"
        )

        run.player.coord = {42, 40}
        Wildlife.update(run, 0.001)
        TestRunner.assertTrue(
            run.world.wildlife.wolves[1].state == "charge"
            or run.world.wildlife.wolves[1].state == "retreat"
            or run.world.wildlife.wolves[1].state == "windup"
            or run.world.wildlife.wolves[1].state == "recover"
        )
    end)

    it("lets dodging avoid a hostile windup and supports raider updates", function()
        local run = buildRun()
        run.player.invulnTimer = 1
        run.world.wildlife.wolves[1].coord = {40, 40}
        Wildlife.update(run, 0.01)
        TestRunner.assertEqual(run.player.condition, Survival.createPlayer({}).condition)

        run.world.wildlife.raiders = {
            {
                kind = "raider",
                coord = {20, 40},
                territory = {x = 1, y = 1, width = 4, height = 4},
                territoryCenter = {40, 40},
                state = "roam",
            },
        }
        Wildlife.update(run, 0.01)
        TestRunner.assertTrue(run.world.wildlife.raiders[1].state == "charge" or run.world.wildlife.raiders[1].state == "windup" or run.world.wildlife.raiders[1].state == "recover")
    end)

    it("repels wolves with fire and applies struggle damage on contact", function()
        local run = buildRun()
        table.insert(run.world.fires, {
            coord = {44, 40},
            remainingBurnHours = 2,
            remainingEmbersHours = 0,
        })
        Wildlife.update(run, 0.1)
        TestRunner.assertEqual(run.world.wildlife.wolves[1].state, "retreat")

        local struggleRun = buildRun()
        struggleRun.player.coord = {40, 40}
        local startCondition = struggleRun.player.condition
        Wildlife.update(struggleRun, 0.1)
        Wildlife.update(struggleRun, 0.1)
        TestRunner.assertTrue(struggleRun.player.condition < startCondition)
    end)
end)
