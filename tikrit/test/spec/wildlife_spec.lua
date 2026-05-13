local TestRunner = require("test_runner")
local EntitySystem = require("entity_system")
local Items = require("items")
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
        local wildlife = World.activeWildlife(run)

        TestRunner.assertEqual(#wildlife.wolves, 1)
        TestRunner.assertEqual(#level.entities, 1)
        TestRunner.assertTrue(#EntitySystem.getTileEntities(level, 3, 3) >= 1)
    end)

    it("stays idempotent across repeated attach, depth changes, and updates", function()
        local run = buildRun()
        World.attachRun(run)
        Wildlife.update(run, 0)
        World.attachRun(run)
        World.changeDepth(run, -1)
        World.changeDepth(run, 0)
        Wildlife.update(run, 0)

        local level = World.currentLevel(run)
        local wildlife = World.activeWildlife(run)
        local mirrored = 0
        for _, entity in ipairs(level.entities or {}) do
            if entity._wildlifeEntity and entity.kind == "wolf" then
                mirrored = mirrored + 1
            end
        end
        TestRunner.assertEqual(#wildlife.wolves, 1)
        TestRunner.assertEqual(mirrored, 1)
    end)

    it("renders mirrored wildlife through EntitySystem", function()
        local run = buildRun()
        World.attachRun(run)
        local level = World.currentLevel(run)
        Wildlife.mirrorLevel(level)
        local draws = 0

        EntitySystem.render(level, {
            drawWildlife = function(actor)
                if actor.kind == "wolf" then
                    draws = draws + 1
                end
            end,
        })

        TestRunner.assertEqual(draws, 1)
    end)

    it("removes hostile entities once killed and leaves one loot node", function()
        local run = buildRun()
        run.player.equippedWeapon = "sword"
        run.player.lastMoveX = 1
        run.player.lastMoveY = 0
        local wildlife = World.activeWildlife(run)
        wildlife.wolves[1].coord = {80, 40}
        wildlife.wolves[1].health = 1
        World.attachRun(run)

        local ok = Wildlife.playerMeleeAttack(run)
        local level = World.currentLevel(run)
        local mirrored = 0
        for _, entity in ipairs(level.entities or {}) do
            if entity._wildlifeEntity and entity.kind == "wolf" then
                mirrored = mirrored + 1
            end
        end

        TestRunner.assertTrue(ok)
        TestRunner.assertEqual(#wildlife.wolves, 0)
        TestRunner.assertEqual(mirrored, 0)
        local resourceNodes = World.readActiveCollection(run, "resourceNodes")
        TestRunner.assertEqual(#resourceNodes, 1)
        TestRunner.assertType(resourceNodes[1]._entityKey, "string")
    end)

    it("places traps and carcasses on the active depth only", function()
        local surface = {
            depth = 0,
            grid = {
                {"snow", "snow", "snow"},
                {"snow", "snow", "snow"},
                {"snow", "snow", "snow"},
            },
            traps = {},
            carcasses = {},
            rabbitZones = {{x = 1, y = 1, width = 3, height = 3}},
        }
        local cave = {
            depth = -1,
            grid = {
                {"snow", "snow", "snow"},
                {"snow", "snow", "snow"},
                {"snow", "snow", "snow"},
            },
            traps = {},
            carcasses = {},
            rabbitZones = {{x = 1, y = 1, width = 3, height = 3}},
        }
        local run = buildRun()
        run.world = {levels = {[0] = surface, [-1] = cave}, currentDepth = -1}
        run.player.coord = {20, 20}
        Items.add(run.player.inventory, "snare", 1)
        World.attachRun(run)

        local placed = Wildlife.placeSnare(run)
        local traps = World.activeCollection(run, "traps")
        TestRunner.assertTrue(placed)
        TestRunner.assertEqual(#run.world.levels[0].traps, 0)
        TestRunner.assertEqual(#run.world.levels[-1].traps, 1)
        TestRunner.assertType(run.world.levels[-1].traps[1]._entityKey, "string")

        traps[1].state = "caught"
        local collected = Wildlife.collectTrap(run)
        TestRunner.assertTrue(collected)
        TestRunner.assertEqual(#run.world.levels[-1].traps, 0)
        TestRunner.assertEqual(#run.world.levels[-1].carcasses, 1)
        TestRunner.assertType(run.world.levels[-1].carcasses[1]._entityKey, "string")
    end)

    it("melee combat and hostile loot affect the active depth only", function()
        local surface = {
            depth = 0,
            grid = {
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
            },
            wildlife = {
                wolves = {{kind = "wolf", coord = {60, 40}, health = 1, territoryCenter = {60, 40}, state = "roam"}},
                rabbits = {},
                deer = {},
                raiders = {},
            },
            resourceNodes = {},
        }
        local cave = {
            depth = -1,
            grid = {
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
            },
            wildlife = {
                wolves = {{kind = "wolf", coord = {60, 40}, health = 1, territoryCenter = {60, 40}, state = "roam"}},
                rabbits = {},
                deer = {},
                raiders = {},
            },
            resourceNodes = {},
        }
        local run = buildRun()
        run.world = {levels = {[0] = surface, [-1] = cave}, currentDepth = -1}
        run.player.coord = {40, 40}
        run.player.equippedWeapon = "sword"
        run.player.lastMoveX = 1
        run.player.lastMoveY = 0
        World.attachRun(run)

        local ok = Wildlife.playerMeleeAttack(run)

        TestRunner.assertTrue(ok)
        TestRunner.assertEqual(#run.world.levels[0].wildlife.wolves, 1)
        TestRunner.assertEqual(#run.world.levels[0].resourceNodes, 0)
        TestRunner.assertEqual(#run.world.levels[-1].wildlife.wolves, 0)
        TestRunner.assertEqual(#run.world.levels[-1].resourceNodes, 1)
    end)

    it("bow hunting creates carcasses on the active depth only", function()
        local surface = {
            depth = 0,
            grid = {
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
            },
            wildlife = {
                wolves = {},
                rabbits = {{kind = "rabbit", coord = {80, 40}, zone = {x = 2, y = 2, width = 3, height = 3}}},
                deer = {},
                raiders = {},
            },
            carcasses = {},
        }
        local cave = {
            depth = -1,
            grid = {
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
                {"snow", "snow", "snow", "snow", "snow"},
            },
            wildlife = {
                wolves = {},
                rabbits = {{kind = "rabbit", coord = {80, 40}, zone = {x = 2, y = 2, width = 3, height = 3}}},
                deer = {},
                raiders = {},
            },
            carcasses = {},
        }
        local run = buildRun()
        run.world = {levels = {[0] = surface, [-1] = cave}, currentDepth = -1}
        run.player.coord = {40, 40}
        run.player.equippedWeapon = "bow"
        run.player.lastMoveX = 1
        run.player.lastMoveY = 0
        Items.add(run.player.inventory, "arrow", 1)
        World.attachRun(run)

        local ok = Wildlife.fireBow(run)

        TestRunner.assertTrue(ok)
        TestRunner.assertEqual(#run.world.levels[0].wildlife.rabbits, 1)
        TestRunner.assertEqual(#run.world.levels[0].carcasses, 0)
        TestRunner.assertEqual(#run.world.levels[-1].wildlife.rabbits, 0)
        TestRunner.assertEqual(#run.world.levels[-1].carcasses, 1)
        TestRunner.assertEqual(run.world.levels[-1].carcasses[1].kind, "rabbit")
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
        local wildlife = World.activeWildlife(run)

        TestRunner.assertEqual(#wildlife.wolves, 2)
        TestRunner.assertTrue(#World.currentLevel(run).entities >= 2)
    end)

    it("honors spawn rule cooldowns and stores actor AI metadata", function()
        local run = buildRun()
        local wildlife = World.activeWildlife(run)
        wildlife.wolves = {}
        run.player.coord = {20, 20}
        run.world.spawnRules = {
            {
                id = "test_wolf_rule",
                kind = "wolf",
                listName = "wolves",
                cap = 2,
                chancePerHour = 1,
                cooldownHours = 2,
                zone = {x = 4, y = 4, width = 1, height = 1},
                minDistanceTiles = 1,
                allowedTiles = {"snow"},
                awarenessRadiusTiles = 12,
            },
        }
        math.randomseed(11)
        World.attachRun(run)

        Wildlife.update(run, 1)
        Wildlife.update(run, 1)
        wildlife = World.activeWildlife(run)
        local wolf = wildlife.wolves[1]

        TestRunner.assertEqual(#wildlife.wolves, 1)
        TestRunner.assertEqual(wolf.spawnRuleId, "test_wolf_rule")
        TestRunner.assertEqual(wolf.aiState, wolf.state)
        TestRunner.assertType(wolf.homeZone, "table")
        TestRunner.assertType(wolf.moving, "boolean")
        TestRunner.assertEqual(wolf.awarenessRadiusTiles, 12)

        Wildlife.update(run, 1.1)
        TestRunner.assertEqual(#wildlife.wolves, 2)
    end)

    it("spawns deterministically from fixed seed depth rules", function()
        local function seededRun()
            local run = buildRun()
            local wildlife = World.activeWildlife(run)
            wildlife.wolves = {}
            run.player.coord = {20, 20}
            run.world.spawnRules = {
                {
                    id = "deterministic_wolf",
                    kind = "wolf",
                    listName = "wolves",
                    cap = 1,
                    chancePerHour = 1,
                    zone = {x = 3, y = 3, width = 2, height = 2},
                    minDistanceTiles = 1,
                    allowedTiles = {"snow"},
                },
            }
            return run
        end

        math.randomseed(4242)
        local first = seededRun()
        Wildlife.update(first, 1)
        math.randomseed(4242)
        local second = seededRun()
        Wildlife.update(second, 1)

        local firstWildlife = World.activeWildlife(first)
        local secondWildlife = World.activeWildlife(second)
        TestRunner.assertTableEqual(firstWildlife.wolves[1].coord, secondWildlife.wolves[1].coord)
        TestRunner.assertEqual(firstWildlife.wolves[1].spawnRuleId, secondWildlife.wolves[1].spawnRuleId)
    end)

    it("keeps wildlife spawning on the active depth only", function()
        local surface = {
            depth = 0,
            grid = {
                {"rock", "rock", "rock", "rock", "rock"},
                {"rock", "snow", "snow", "snow", "rock"},
                {"rock", "snow", "snow", "snow", "rock"},
                {"rock", "snow", "snow", "snow", "rock"},
                {"rock", "rock", "rock", "rock", "rock"},
            },
            wildlife = {wolves = {}, rabbits = {}, deer = {}, raiders = {}},
            spawnRules = {
                {id = "surface_wolf", kind = "wolf", listName = "wolves", cap = 1, chancePerHour = 1, zone = {x = 4, y = 4, width = 1, height = 1}, minDistanceTiles = 1},
            },
        }
        local cave = {
            depth = -1,
            grid = {
                {"rock", "rock", "rock", "rock", "rock"},
                {"rock", "snow", "snow", "snow", "rock"},
                {"rock", "snow", "snow", "snow", "rock"},
                {"rock", "snow", "snow", "snow", "rock"},
                {"rock", "rock", "rock", "rock", "rock"},
            },
            wildlife = {wolves = {}, rabbits = {}, deer = {}, raiders = {}},
            spawnRules = {
                {id = "cave_raider", kind = "raider", listName = "raiders", cap = 1, chancePerHour = 1, zone = {x = 4, y = 4, width = 1, height = 1}, minDistanceTiles = 1},
            },
        }
        local run = buildRun()
        run.world = {levels = {[0] = surface, [-1] = cave}, currentDepth = -1}
        run.player.coord = {20, 20}
        World.attachRun(run)

        Wildlife.update(run, 1)

        TestRunner.assertEqual(#run.world.levels[0].wildlife.wolves, 0)
        TestRunner.assertEqual(#run.world.levels[-1].wildlife.raiders, 1)
        TestRunner.assertEqual(run.world.levels[-1].wildlife.raiders[1].depth, -1)
    end)

    it("rejects spawns on blocked hazard zones and invalid tiles", function()
        local run = buildRun()
        local wildlife = World.activeWildlife(run)
        wildlife.wolves = {}
        run.player.coord = {20, 20}
        local hazardZones = World.activeCollection(run, "hazardZones")
        hazardZones[1] = {type = "weak_ice", zone = {x = 4, y = 4, width = 1, height = 1}}
        World.attachRun(run)

        local hazardSpawn = World.spawnOffscreen(run, "wolf", {
            cap = 1,
            zone = {x = 4, y = 4, width = 1, height = 1},
            minDistanceTiles = 1,
            allowedTiles = {"snow"},
            blockedHazards = {"weak_ice"},
        })
        local grid = World.activeGrid(run)
        grid[4][4] = "weak_ice"
        local tileSpawn = World.spawnOffscreen(run, "wolf", {
            cap = 1,
            zone = {x = 4, y = 4, width = 1, height = 1},
            minDistanceTiles = 1,
            allowedTiles = {"snow"},
        })

        TestRunner.assertEqual(hazardSpawn, nil)
        TestRunner.assertEqual(tileSpawn, nil)
    end)

    it("updates entity movement state and facing during tile-aware passive AI", function()
        local run = buildRun()
        local wildlife = World.activeWildlife(run)
        wildlife.wolves = {}
        wildlife.rabbits = {
            {
                kind = "rabbit",
                coord = {60, 40},
                zone = {x = 2, y = 2, width = 3, height = 3},
                speed = 20,
            },
        }
        run.player.coord = {20, 40}
        World.attachRun(run)

        Wildlife.update(run, 0.01)
        local rabbit = wildlife.rabbits[1]

        TestRunner.assertTrue(rabbit.moving)
        TestRunner.assertTrue(rabbit.facingX > 0)
        TestRunner.assertEqual(rabbit.aiState, rabbit.state)
        TestRunner.assertEqual(rabbit.depth, 0)
        TestRunner.assertTrue(rabbit.awareness.seesPlayer)
        TestRunner.assertEqual(rabbit.state, "flee")
    end)

    it("lets hostiles watch from awareness range before charging", function()
        local run = buildRun()
        World.attachRun(run)
        local level = World.currentLevel(run)
        level.grid = {
            {"snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow"},
            {"snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow"},
            {"snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow"},
            {"snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow"},
        }
        World.attachRun(run)
        local wildlife = World.activeWildlife(run)
        wildlife.wolves = {}
        wildlife.raiders = {
            {
                kind = "raider",
                coord = {40, 40},
                territory = {x = 2, y = 2, width = 4, height = 2},
                territoryCenter = {70, 50},
                state = "roam",
                aggroRadius = 2,
                weaponRange = 1,
                awarenessRadiusTiles = 6,
            },
        }
        run.player.coord = {120, 40}
        World.attachRun(run)

        Wildlife.update(run, 0.01)
        local raider = wildlife.raiders[1]

        TestRunner.assertEqual(raider.state, "watch")
        TestRunner.assertTrue(raider.awareness.seesPlayer)
        TestRunner.assertTableEqual(raider.awareness.lastSeenCoord, {120, 40})
    end)

    it("patrols home zones when the player is outside awareness", function()
        local run = buildRun()
        World.attachRun(run)
        local level = World.currentLevel(run)
        level.grid = {
            {"snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow"},
            {"snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow"},
            {"snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow"},
            {"snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow", "snow"},
        }
        World.attachRun(run)
        local wildlife = World.activeWildlife(run)
        wildlife.wolves = {}
        wildlife.raiders = {
            {
                kind = "raider",
                coord = {40, 40},
                territory = {x = 2, y = 2, width = 4, height = 2},
                territoryCenter = {70, 50},
                state = "roam",
                aggroRadius = 2,
                awarenessRadiusTiles = 3,
            },
        }
        run.player.coord = {220, 40}
        World.attachRun(run)

        Wildlife.update(run, 0.01)
        local raider = wildlife.raiders[1]

        TestRunner.assertEqual(raider.state, "patrol")
        TestRunner.assertType(raider.patrolPoints, "table")
        TestRunner.assertType(raider.target, "table")
        TestRunner.assertFalse(raider.awareness.seesPlayer)
    end)

    it("moves wolves from roaming into stalking and charging", function()
        local run = buildRun()
        local wildlife = World.activeWildlife(run)
        Wildlife.update(run, 0.001)
        TestRunner.assertTrue(
            wildlife.wolves[1].state == "stalk"
            or wildlife.wolves[1].state == "charge"
            or wildlife.wolves[1].state == "windup"
        )

        run.player.coord = {42, 40}
        Wildlife.update(run, 0.001)
        TestRunner.assertTrue(
            wildlife.wolves[1].state == "charge"
            or wildlife.wolves[1].state == "retreat"
            or wildlife.wolves[1].state == "windup"
            or wildlife.wolves[1].state == "recover"
        )
    end)

    it("lets dodging avoid a hostile windup and supports raider updates", function()
        local run = buildRun()
        run.player.invulnTimer = 1
        local wildlife = World.activeWildlife(run)
        wildlife.wolves[1].coord = {40, 40}
        Wildlife.update(run, 0.01)
        TestRunner.assertEqual(run.player.condition, Survival.createPlayer({}).condition)

        wildlife.raiders = {
            {
                kind = "raider",
                coord = {20, 40},
                territory = {x = 1, y = 1, width = 4, height = 4},
                territoryCenter = {40, 40},
                state = "roam",
            },
        }
        Wildlife.update(run, 0.01)
        TestRunner.assertTrue(wildlife.raiders[1].state == "charge" or wildlife.raiders[1].state == "windup" or wildlife.raiders[1].state == "recover")
    end)

    it("repels wolves with fire and applies struggle damage on contact", function()
        local run = buildRun()
        local fires = World.activeCollection(run, "fires")
        local wildlife = World.activeWildlife(run)
        table.insert(fires, {
            coord = {44, 40},
            remainingBurnHours = 2,
            remainingEmbersHours = 0,
        })
        Wildlife.update(run, 0.1)
        TestRunner.assertEqual(wildlife.wolves[1].state, "retreat")

        local struggleRun = buildRun()
        struggleRun.player.coord = {40, 40}
        local startCondition = struggleRun.player.condition
        Wildlife.update(struggleRun, 0.1)
        Wildlife.update(struggleRun, 0.1)
        TestRunner.assertTrue(struggleRun.player.condition < startCondition)
    end)
end)
