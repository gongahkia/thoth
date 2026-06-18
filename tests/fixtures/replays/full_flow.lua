local Simulation = require("src.game.simulation")

local fixture = {
    name = "full_flow",
    seed = 103,
    finalTick = 240,
    frames = {
        { tick = 0, command = Simulation.commands.submitSupplyContract("iron_supply") },
        { tick = 0, command = Simulation.commands.submitSupplyContract("science_supply") },
        { tick = 0, command = Simulation.commands.submitSupplyContract("drone_supply") },
    },
}

local function plateLine(sim, ore, y)
    sim.world:setTile(0, y, 0, { id = ore, data = 20 })
    local miner = sim:addMachine("burner_miner", 0, y, "east")
    miner.inventory:add("coal", 10)
    sim:addMachine("belt", 1, y, "east")
    sim:addMachine("inserter", 2, y, "east")
    local furnace = sim:addMachine("furnace", 3, y, "east")
    furnace.inventory:add("coal", 10)
    if ore == "copper_ore" then
        furnace.recipeKey = "copper_plate"
    end
    sim:addMachine("inserter", 4, y, "east")
    sim:addMachine("chest", 5, y, "south")
end

fixture.setup = function(sim)
    sim:addItem("iron_plate", 5)
    sim:addItem("science_pack", 3)
    sim:addItem("logistic_drone", 1)
    plateLine(sim, "iron_ore", -2)
    plateLine(sim, "copper_ore", 2)

    local lab = sim:addMachine("lab", -2, 0, "south")
    lab.inventory:add("science_pack", 7)
    lab.inventory:add("advanced_science_pack", 5)

    local generator = sim:addMachine("generator", 8, 0, "east")
    generator.inventory:add("coal", 20)
    sim:addMachine("power_pole", 9, 0, "south")
    local port = sim:addMachine("logistic_port", 10, 0, "south")
    port.inventory:add("logistic_drone", 1)
    local provider = sim:addMachine("provider_chest", 11, 0, "south")
    provider.inventory:add("wood", 2)
    local requester = sim:addMachine("requester_chest", 12, 0, "south")
    sim:addMachine("power_pole", 13, 0, "south")
    sim.world:setTile(14, 0, 0, { id = "iron_ore", data = 10 })
    sim:addMachine("electric_miner", 14, 0, "east")
    sim:addMachine("chest", 15, 0, "south")
    sim:configureRequest(requester.id, "wood", 1)
end

local function firstMachine(sim, kind)
    for _, machine in ipairs(sim.machines) do
        if machine.kind == kind then
            return machine
        end
    end
    return nil
end

fixture.validate = function(sim, expect)
    expect(sim.productionTotals.iron_plate > 0, "full_flow should produce iron plates")
    expect(sim.productionTotals.copper_plate > 0, "full_flow should produce copper plates")
    expect(sim:isTechCompleted("logistic_network"), "full_flow should complete the tech chain")
    expect(sim:isRecipeUnlocked("archive_terminal"), "full_flow should unlock archive prep")
    expect(sim:isRecipeUnlocked("rift_gate"), "full_flow should unlock rift prep")
    expect(sim:completedSupplyContracts() == sim:totalSupplyContracts(), "full_flow should complete supply contracts")
    expect(sim:mainObjectiveComplete(), "full_flow should complete the main objective")
    expect(sim:isMachinePowered(firstMachine(sim, "logistic_port").id), "full_flow should power logistics")
    expect(firstMachine(sim, "requester_chest").inventory:count("wood") > 0, "full_flow should deliver logistics cargo")
end

return fixture
