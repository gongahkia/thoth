local TestRunner = require("test_runner")
local Wildlife = require("wildlife")
local Survival = require("survival")

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
