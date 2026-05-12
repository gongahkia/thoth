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
end)
