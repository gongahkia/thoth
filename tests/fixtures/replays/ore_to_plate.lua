return {
    name = "ore_to_plate",
    seed = 101,
    finalTick = 240,
    setup = function(sim)
        sim.world:setTile(0, 0, 0, { id = "iron_ore", data = 20 })
        local miner = sim:addMachine("burner_miner", 0, 0, "east")
        miner.inventory:add("coal", 10)
        sim:addMachine("belt", 1, 0, "east")
        sim:addMachine("inserter", 2, 0, "east")
        local furnace = sim:addMachine("furnace", 3, 0, "east")
        furnace.inventory:add("coal", 10)
        sim:addMachine("inserter", 4, 0, "east")
        sim:addMachine("chest", 5, 0, "south")
    end,
    validate = function(sim, expect)
        expect(sim.productionTotals.iron_plate > 0, "ore_to_plate should produce iron plates")
        expect(sim:machineAt(5, 0, 0).inventory:count("iron_plate") > 0, "ore_to_plate should store iron plates")
    end,
}
