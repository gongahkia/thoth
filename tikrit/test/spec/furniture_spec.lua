local TestRunner = require("test_runner")
local EntitySystem = require("entity_system")
local Furniture = require("furniture")
local Items = require("items")
local Survival = require("survival")
local World = require("world")

local describe = TestRunner.describe
local it = TestRunner.it

local function smallWorld(tile)
    return {
        grid = {
            {"rock", "rock", "rock", "rock"},
            {"rock", tile or "snow", "snow", "rock"},
            {"rock", "snow", "snow", "rock"},
            {"rock", "rock", "rock", "rock"},
        },
        weather = {current = "clear", hoursUntilChange = 1},
        hazardZones = {},
        mappedTiles = {},
    }
end

describe("Furniture", function()
    it("spawns furniture into the entity index and blocks movement when solid", function()
        local level = {
            depth = 0,
            grid = {
                {"rock", "rock", "rock", "rock"},
                {"rock", "snow", "snow", "rock"},
                {"rock", "snow", "snow", "rock"},
                {"rock", "rock", "rock", "rock"},
            },
        }
        Furniture.spawn(level, "chest", {40, 20}, {solid = true})
        local player = EntitySystem.spawn(level, "player", {20, 20}, {solid = true})

        TestRunner.assertTrue(#EntitySystem.getTileEntities(level, 3, 2) >= 1)
        TestRunner.assertFalse(EntitySystem.moveEntity(level, player, 20, 0))
    end)

    it("interacts with a faced cache and transfers loot once", function()
        local run = {
            world = smallWorld(),
            player = {coord = {20, 20}, lastMoveX = 1, lastMoveY = 0, inventory = {}},
            runtime = {},
        }
        World.attachRun(run)
        local level = World.currentLevel(run)
        Furniture.spawn(level, "chest", {40, 20}, {
            inventory = {Items.create("matches", 2), Items.create("cloth", 1)},
        })

        local ok = World.interactFacing(run)
        TestRunner.assertTrue(ok)
        TestRunner.assertEqual(Items.count(run.player.inventory, "matches"), 2)
        TestRunner.assertEqual(Items.count(run.player.inventory, "cloth"), 1)

        World.interactFacing(run)
        TestRunner.assertEqual(Items.count(run.player.inventory, "matches"), 2)
    end)

    it("keeps mirrored cache furniture idempotent after attach and opening", function()
        local run = {
            world = smallWorld(),
            player = {coord = {20, 20}, lastMoveX = 1, lastMoveY = 0, inventory = {}},
            runtime = {},
        }
        local resourceNodes = World.activeCollection(run, "resourceNodes")
        resourceNodes[1] = {type = "cache", coord = {40, 20}, opened = false, loot = {Items.create("matches", 1)}}
        World.attachRun(run)
        World.attachRun(run)

        local level = World.currentLevel(run)
        local entity
        for _, candidate in ipairs(level.entities or {}) do
            if candidate._furnitureKey == resourceNodes[1]._entityKey then
                entity = candidate
                break
            end
        end
        TestRunner.assertType(entity, "table")
        Furniture.interact(entity, run, level)
        World.attachRun(run)

        local count = 0
        for _, candidate in ipairs(level.entities or {}) do
            if candidate.container and candidate.kind == "chest" then
                count = count + 1
            end
        end
        TestRunner.assertEqual(count, 1)
        TestRunner.assertTrue(resourceNodes[1].opened)
        TestRunner.assertTrue(entity.opened)
        TestRunner.assertEqual(Items.count(run.player.inventory, "matches"), 1)
    end)

    it("renders furniture through entity callbacks", function()
        local run = {
            world = smallWorld("cabin_workbench"),
            player = {coord = {20, 20}, inventory = {}},
            runtime = {},
        }
        local resourceNodes = World.activeCollection(run, "resourceNodes")
        resourceNodes[1] = {type = "cache", coord = {40, 20}, opened = false, loot = {}}
        World.attachRun(run)
        local level = World.currentLevel(run)
        local stations = 0
        local caches = 0

        EntitySystem.render(level, {
            drawStation = function()
                stations = stations + 1
            end,
            drawResourceNode = function()
                caches = caches + 1
            end,
        })

        TestRunner.assertTrue(stations >= 1)
        TestRunner.assertEqual(caches, 1)
    end)

    it("filters recipes by active station while keeping inventory recipes available", function()
        local run = {
            world = smallWorld("cabin_stove"),
            player = {coord = {20, 20}, lastMoveX = 1, lastMoveY = 0, inventory = {}},
            runtime = {},
        }
        Items.add(run.player.inventory, "snow", 1)
        Items.add(run.player.inventory, "cloth", 1)
        World.attachRun(run)

        local station = Survival.currentCraftStation(run)
        TestRunner.assertEqual(station.station, "stove")

        local recipes = Survival.availableCraftRecipes(run)
        local foundBandage = false
        local foundMeltSnow = false
        local foundArrow = false
        for _, recipe in ipairs(recipes) do
            foundBandage = foundBandage or recipe.key == "bandage"
            foundMeltSnow = foundMeltSnow or recipe.key == "melt_snow"
            foundArrow = foundArrow or recipe.key == "arrow"
        end
        TestRunner.assertTrue(foundBandage)
        TestRunner.assertTrue(foundMeltSnow)
        TestRunner.assertFalse(foundArrow)

        local ok = Survival.craftRecipe(run, "melt_snow")
        TestRunner.assertTrue(ok)
        TestRunner.assertEqual(Items.count(run.player.inventory, "water"), 1)
    end)

    it("hits faced furniture before tiles and removes broken furniture once", function()
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
            runtime = {},
        }
        World.attachRun(run)
        local level = World.currentLevel(run)
        Furniture.spawn(level, "chest", {40, 20}, {
            inventory = {Items.create("matches", 1)},
        })

        local firstOk = World.hitFacing(run)
        local secondOk = World.hitFacing(run)

        TestRunner.assertTrue(firstOk)
        TestRunner.assertTrue(secondOk)
        TestRunner.assertEqual(World.activeGrid(run)[2][3], "tree")
        TestRunner.assertEqual(Items.count(run.player.inventory, "matches"), 1)
        TestRunner.assertTrue(Items.count(run.player.inventory, "sticks") >= 2)
        TestRunner.assertEqual(#EntitySystem.getTileEntities(level, 3, 2), 0)
    end)

    it("breaks portable furniture into drops and keeps fixed tile stations in place", function()
        local kinds = {"workbench", "lantern", "bedroll", "snow_shelter"}
        for index, kind in ipairs(kinds) do
            local run = {
                world = smallWorld(),
                player = {
                    coord = {20, 20},
                    lastMoveX = 1,
                    lastMoveY = 0,
                    equippedTool = "hatchet",
                    inventory = {},
                    stamina = 20,
                },
                runtime = {},
            }
            World.attachRun(run)
            local level = World.currentLevel(run)
            Furniture.spawn(level, kind, {40, 20})

            for _ = 1, 3 do
                World.hitFacing(run)
            end

            TestRunner.assertEqual(#EntitySystem.getTileEntities(level, 3, 2), 0)
            TestRunner.assertTrue(#run.player.inventory > 0, "expected drops for " .. kind .. " at " .. index)
        end

        local fixedRun = {
            world = {
                grid = {
                    {"rock", "rock", "rock", "rock"},
                    {"rock", "snow", "cabin_workbench", "rock"},
                    {"rock", "snow", "snow", "rock"},
                    {"rock", "rock", "rock", "rock"},
                },
                weather = {current = "clear", hoursUntilChange = 1},
                hazardZones = {},
                mappedTiles = {},
            },
            player = {coord = {20, 20}, lastMoveX = 1, lastMoveY = 0, equippedTool = "hatchet", inventory = {}},
            runtime = {},
        }
        World.attachRun(fixedRun)
        local fixedEntity = World.facingEntity(fixedRun)
        local pickupOk = Furniture.pickup(fixedEntity, fixedRun, World.currentLevel(fixedRun))
        local hitOk = World.hitFacing(fixedRun)

        TestRunner.assertFalse(pickupOk)
        TestRunner.assertFalse(hitOk)
        TestRunner.assertType(World.facingEntity(fixedRun), "table")
    end)

    it("keeps partial furniture damage across attach and depth changes", function()
        local surface = smallWorld()
        local cave = smallWorld()
        surface.depth = 0
        cave.depth = -1
        local run = {
            world = {levels = {[0] = surface, [-1] = cave}, currentDepth = 0},
            player = {
                coord = {20, 20},
                lastMoveX = 1,
                lastMoveY = 0,
                equippedTool = "hatchet",
                inventory = {},
                stamina = 20,
            },
            runtime = {},
        }
        World.attachRun(run)
        local level = World.currentLevel(run)
        local entity = Furniture.spawn(level, "workbench", {40, 20})

        local ok = World.hitFacing(run)
        TestRunner.assertTrue(ok)
        TestRunner.assertTrue(entity.damage > 0)
        local damage = entity.damage

        World.attachRun(run)
        World.changeDepth(run, -1, {20, 20})
        World.changeDepth(run, 0, {20, 20})

        local restored = World.facingEntity(run)
        TestRunner.assertTrue(restored == entity)
        TestRunner.assertEqual(restored.damage, damage)
    end)
end)
