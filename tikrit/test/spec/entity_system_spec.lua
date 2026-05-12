local TestRunner = require("test_runner")
local EntitySystem = require("entity_system")

local describe = TestRunner.describe
local it = TestRunner.it

local function grid()
    return {
        {"rock", "rock", "rock", "rock"},
        {"rock", "snow", "snow", "rock"},
        {"rock", "snow", "tree", "rock"},
        {"rock", "rock", "rock", "rock"},
    }
end

describe("EntitySystem", function()
    it("adds entities to per-tile buckets and reports collisions", function()
        local level = {depth = 0, grid = grid()}
        local first = EntitySystem.spawn(level, "crate", {20, 20}, {solid = true})
        local second = EntitySystem.spawn(level, "sled", {22, 20}, {solid = true})

        TestRunner.assertEqual(#level.entities, 2)
        TestRunner.assertTrue(#EntitySystem.getTileEntities(level, 2, 2) >= 2)
        TestRunner.assertEqual(#EntitySystem.getCollisions(level, first, first.coord[1], first.coord[2]), 1)
        EntitySystem.remove(level, second.id)
        TestRunner.assertEqual(#level.entities, 1)
    end)

    it("moves one axis at a time and refuses solid tiles", function()
        local level = {depth = 0, grid = grid()}
        local entity = EntitySystem.spawn(level, "player", {20, 20}, {solid = true, width = 10, height = 10})

        TestRunner.assertTrue(EntitySystem.moveEntity(level, entity, 8, 0))
        local afterOpenMoveY = entity.coord[2]
        EntitySystem.moveEntity(level, entity, 20, 20)
        TestRunner.assertEqual(entity.coord[2], afterOpenMoveY)
    end)
end)
