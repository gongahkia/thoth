package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Serialize = require("src.core.serialize")
local Simulation = require("src.game.simulation")
local Save = require("src.game.save")
local Replay = require("src.game.replay")

local function expect(value, message)
    if not value then
        error(message or "expectation failed", 2)
    end
end

local function sameSnapshot(a, b)
    return Serialize.encode(a:snapshot()) == Serialize.encode(b:snapshot())
end

local function runSteps(sim, count)
    for _ = 1, count do
        sim:step()
    end
end

local tests = {}

tests[#tests + 1] = function()
    local a = Simulation.new(42)
    local b = Simulation.new(42)
    local commands = {
        Simulation.commands.face("west"),
        Simulation.commands.mine("west"),
        Simulation.commands.move("east"),
        Simulation.commands.move("east"),
        Simulation.commands.mine("east"),
    }
    for _, command in ipairs(commands) do
        a:queue(command)
        b:queue(command)
        a:step()
        b:step()
    end
    expect(sameSnapshot(a, b), "same seed and commands diverged")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(7)
    sim:queue(Simulation.commands.face("west"))
    sim:queue(Simulation.commands.mine("west"))
    sim:step()
    expect(sim:itemCount("wood") == 1, "mining tree should add wood")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(9)
    sim:addItem("wood", 20)
    sim:addItem("stone", 20)
    expect(sim:craft("workbench"), "workbench craft failed")
    sim:queue(Simulation.commands.place("south", "workbench", "south"))
    sim:step()
    expect(sim:machineAt(0, 1, 0).kind == "workbench", "workbench not placed")
    expect(sim:craft("furnace"), "workbench-gated furnace craft failed")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(11)
    sim.world:setTile(0, 0, 0, { id = "iron_ore", data = 20 })
    local miner = sim:addMachine("burner_miner", 0, 0, "east")
    miner.inventory:add("coal", 10)
    sim:addMachine("belt", 1, 0, "east")
    sim:addMachine("inserter", 2, 0, "east")
    local furnace = sim:addMachine("furnace", 3, 0, "east")
    furnace.inventory:add("coal", 10)
    sim:addMachine("inserter", 4, 0, "east")
    local chest = sim:addMachine("chest", 5, 0, "south")
    runSteps(sim, 240)
    expect(chest.inventory:count("iron_plate") > 0, "starter line did not produce iron plate")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(12)
    local lab = sim:addMachine("lab", 0, 0, "south")
    lab.inventory:add("science_pack", 3)
    runSteps(sim, 80)
    expect(sim:isTechCompleted("logistics_1"), "lab did not complete logistics_1")
    expect(sim:isRecipeUnlocked("fast_belt"), "research did not unlock fast_belt")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(13)
    sim:addItem("wood", 3)
    sim:addMachine("chest", 2, 0, "south").inventory:add("stone", 5)
    sim:queue(Simulation.commands.assignHotbar(3, "wood"))
    sim:queue(Simulation.commands.assignHotbar(1, nil))
    runSteps(sim, 3)
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(sameSnapshot(sim, loaded), "save/load snapshot mismatch")
    expect(loaded.player.hotbar[3] == "wood", "assigned hotbar slot did not persist")
    expect(loaded.player.hotbar[1] == nil, "cleared hotbar slot did not persist")
end

tests[#tests + 1] = function()
    local frames = {
        { tick = 0, command = Simulation.commands.face("west") },
        { tick = 0, command = Simulation.commands.mine("west") },
        { tick = 1, command = Simulation.commands.move("east") },
    }
    local direct = Simulation.new(14)
    direct:queue(frames[1].command)
    direct:queue(frames[2].command)
    direct:step()
    direct:queue(frames[3].command)
    direct:step()
    while direct.tick < 5 do
        direct:step()
    end
    local replayed = Replay.run(14, frames, 5)
    expect(sameSnapshot(direct, replayed), "replay result mismatch")
    local doc = assert(Replay.fromText(Replay.toText(14, frames, 5)))
    expect(doc.finalTick == 5 and #doc.frames == 3, "replay serialization failed")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(15)
    local chest = sim:addMachine("chest", 0, 0, "south")
    sim:addItem("wood", 8)
    sim:queue(Simulation.commands.depositMachine(chest.id, "wood", 5))
    sim:step()
    expect(chest.inventory:count("wood") == 5, "panel deposit failed")
    expect(sim:itemCount("wood") == 3, "panel deposit did not consume player items")
    sim:queue(Simulation.commands.withdrawMachine(chest.id, "wood", "all"))
    sim:step()
    expect(chest.inventory:count("wood") == 0, "panel withdraw failed")
    expect(sim:itemCount("wood") == 8, "panel withdraw did not return items")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(16)
    local furnace = sim:addMachine("furnace", 0, 0, "south")
    local blocked = sim:addMachine("furnace", 1, 0, "south")
    blocked.inventory:add("coal", 1)
    furnace.inventory:add("coal", 1)
    furnace.inventory:add("copper_ore", 1)
    sim:queue(Simulation.commands.setMachineRecipe(furnace.id, "copper_plate"))
    sim:queue(Simulation.commands.setMachineRecipe(blocked.id, "copper_plate"))
    sim:step()
    runSteps(sim, 60)
    expect(furnace.inventory:count("copper_plate") == 1, "furnace recipe selector did not smelt copper")
    expect(blocked.inventory:count("coal") == 1, "furnace consumed fuel without selected ore")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(17)
    expect(sim:nextStepText() == "Mine west trees for workbench wood", "initial next step should point at wood")
    sim:addItem("wood", 6)
    sim:addItem("stone", 8)
    sim:addMachine("workbench", 0, 1, "south")
    expect(sim:nextStepText() == "Craft and place a burner miner on ore", "next step should advance past starter materials")
    local checklist = sim:objectiveChecklist()
    expect(checklist[1].title == "First" and checklist[2].title == "Science", "objective checklist groups missing")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(18)
    local splitter = sim:addMachine("splitter", 0, 0, "east")
    local left = sim:addMachine("chest", 0, -1, "south")
    local right = sim:addMachine("chest", 0, 1, "south")
    expect(sim:acceptItem(splitter, "iron_ore"), "splitter should accept first item")
    sim:step()
    expect(left.inventory:count("iron_ore") == 1, "splitter did not send first item left")
    expect(sim:acceptItem(splitter, "copper_ore"), "splitter should accept second item")
    sim:step()
    expect(right.inventory:count("copper_ore") == 1, "splitter did not alternate right")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(19)
    local source = sim:addMachine("chest", -1, 0, "south")
    local inserter = sim:addMachine("circuit_inserter", 0, 0, "east")
    local target = sim:addMachine("chest", 1, 0, "south")
    source.inventory:add("iron_ore", 5)
    source.inventory:add("copper_ore", 5)
    sim:queue(Simulation.commands.configureCircuit(inserter.id, "iron_ore", "less_than", 2))
    runSteps(sim, 90)
    expect(target.inventory:count("iron_ore") == 2, "circuit inserter ignored less-than threshold")
    expect(target.inventory:count("copper_ore") == 0, "circuit inserter ignored item filter")
    expect(source.inventory:count("iron_ore") == 3, "circuit inserter moved too many filtered items")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(20)
    local provider = sim:addMachine("provider_chest", 0, 0, "south")
    local requester = sim:addMachine("requester_chest", 1, 0, "south")
    expect(sim:acceptItem(provider, "wood"), "provider chest should accept items")
    expect(sim:extractItem(provider) == "wood", "provider chest should expose stored items")
    expect(sim:acceptItem(requester, "stone"), "requester chest should accept items")
    expect(sim:extractItem(requester) == "stone", "requester chest should expose stored items")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(21)
    local port = sim:addMachine("logistic_port", 0, 0, "south")
    expect(sim:acceptItem(port, "logistic_drone"), "logistic port should accept drones")
    expect(not sim:acceptItem(port, "wood"), "logistic port should reject non-drone items")
    expect(port.inventory:count("logistic_drone") == 1, "logistic port did not retain drone")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(22)
    local stop = sim:addMachine("train_stop", 0, 0, "south")
    expect(sim:acceptItem(stop, "iron_plate"), "train stop should accept freight")
    expect(sim:extractItem(stop) == "iron_plate", "train stop should expose freight")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(23)
    sim.world:setTile(0, -1, 0, { id = "water", data = 0 })
    sim:addMachine("offshore_pump", 0, 0, "east")
    sim:addMachine("pipe", 1, 0, "east")
    local chest = sim:addMachine("chest", 2, 0, "south")
    runSteps(sim, 40)
    expect(chest.inventory:count("water_barrel") == 1, "pump and pipe did not move water barrel")
    expect(sim.productionTotals.water_barrel == 1, "water barrel production was not counted")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(24)
    sim.world:setTile(6, 0, 0, { id = "iron_ore", data = 10 })
    local generator = sim:addMachine("generator", 0, 0, "east")
    generator.inventory:add("coal", 1)
    sim:addMachine("power_pole", 1, 0, "south")
    sim:addMachine("power_pole", 5, 0, "south")
    local miner = sim:addMachine("electric_miner", 6, 0, "east")
    local chest = sim:addMachine("chest", 7, 0, "south")
    runSteps(sim, 10)
    expect(sim:isMachinePowered(miner.id), "electric miner was not powered through pole chain")
    expect(chest.inventory:count("iron_ore") == 1, "powered electric miner did not output ore")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(25)
    local generator = sim:addMachine("generator", 0, 1, "east")
    generator.inventory:add("coal", 1)
    sim:addMachine("power_pole", 0, 0, "south")
    local miners = {
        sim:addMachine("electric_miner", 1, 0, "east"),
        sim:addMachine("electric_miner", -1, 0, "east"),
        sim:addMachine("electric_miner", 0, -1, "east"),
    }
    for index, miner in ipairs(miners) do
        sim.world:setTile(miner.x, miner.y, 0, { id = "iron_ore", data = 10 + index })
    end
    runSteps(sim, 2)
    for _, miner in ipairs(miners) do
        expect(not sim:isMachinePowered(miner.id), "under-supplied network powered a consumer")
        expect(miner.status == "missing_power", "under-supplied electric miner did not stop")
    end
end

tests[#tests + 1] = function()
    local sim = Simulation.new(26)
    local chest = sim:addMachine("chest", 4, -2, "south")
    expect(sim:machineAt(4, -2, 0) == chest, "machineByCell index missed placed machine")
    expect(sim:machineById(chest.id) == chest, "machineById index missed placed machine")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:machineAt(4, -2, 0).kind == "chest", "machineByCell index did not rebuild on load")
    expect(loaded:machineById(chest.id).kind == "chest", "machineById index did not rebuild on load")
    expect(loaded:removeMachineById(chest.id), "machine removal failed")
    expect(loaded:machineAt(4, -2, 0) == nil, "machineByCell index did not clear removed machine")
    expect(loaded:machineById(chest.id) == nil, "machineById index did not clear removed machine")
end

local function addPoweredPortLine(sim)
    local generator = sim:addMachine("generator", 0, 0, "east")
    generator.inventory:add("coal", 5)
    sim:addMachine("power_pole", 1, 0, "south")
    local port = sim:addMachine("logistic_port", 2, 0, "south")
    port.inventory:add("logistic_drone", 1)
    return port
end

tests[#tests + 1] = function()
    local sim = Simulation.new(27)
    addPoweredPortLine(sim)
    local provider = sim:addMachine("provider_chest", 3, 0, "south")
    local requester = sim:addMachine("requester_chest", 4, 0, "south")
    provider.inventory:add("wood", 3)
    sim:queue(Simulation.commands.configureRequest(requester.id, "wood", 2))
    runSteps(sim, 30)
    expect(requester.inventory:count("wood") == 2, "logistic delivery did not satisfy requester threshold")
    expect(provider.inventory:count("wood") == 1, "logistic delivery consumed wrong provider count")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(28)
    addPoweredPortLine(sim)
    local provider = sim:addMachine("provider_chest", 3, 0, "south")
    local requester = sim:addMachine("requester_chest", 4, 0, "south")
    provider.inventory:add("stone", 1)
    sim:queue(Simulation.commands.configureRequest(requester.id, "stone", 1))
    runSteps(sim, 2)
    expect(#sim.logisticJobs == 1, "logistic job was not in flight before save")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    runSteps(loaded, 15)
    expect(loaded:machineById(requester.id).inventory:count("stone") == 1, "in-flight logistic job did not persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(29)
    local port = sim:addMachine("logistic_port", 0, 0, "south")
    port.inventory:add("logistic_drone", 1)
    local provider = sim:addMachine("provider_chest", 1, 0, "south")
    local requester = sim:addMachine("requester_chest", 2, 0, "south")
    provider.inventory:add("wood", 1)
    sim:queue(Simulation.commands.configureRequest(requester.id, "wood", 1))
    runSteps(sim, 30)
    expect(requester.inventory:count("wood") == 0, "unpowered logistic port delivered item")
    expect(provider.inventory:count("wood") == 1, "unpowered logistic port consumed provider item")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(30)
    local first = sim:addMachine("train_stop", 0, 0, "south")
    local second = sim:addMachine("train_stop", 5, 0, "south")
    first.inventory:add("iron_plate", 1)
    runSteps(sim, 95)
    expect(first.inventory:count("iron_plate") == 0, "train stop did not consume source cargo")
    expect(second.inventory:count("iron_plate") == 1, "train stop did not receive cargo")
    expect(sim.productionTotals.train_deliveries == 1, "train delivery counter did not increment")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(31)
    sim:addItem("iron_plate", 3)
    sim:queue(Simulation.commands.submitSupplyContract("iron_supply"))
    sim:step()
    local contract = sim:supplyContract("iron_supply")
    expect(contract.delivered == 3, "supply contract did not accept partial delivery")
    expect(not contract.complete, "partial supply contract should stay incomplete")
    expect(sim:itemCount("iron_plate") == 0, "supply contract did not consume player items")
    sim:addItem("iron_plate", 2)
    sim:queue(Simulation.commands.submitSupplyContract("iron_supply"))
    sim:step()
    expect(contract.delivered == 5 and contract.complete, "supply contract did not complete at target")
    sim:addItem("iron_plate", 1)
    expect(not sim:submitSupplyContract("iron_supply"), "completed supply contract accepted extra delivery")
    expect(sim:itemCount("iron_plate") == 1, "completed supply contract consumed extra item")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    local loadedContract = loaded:supplyContract("iron_supply")
    expect(loadedContract.delivered == 5 and loadedContract.complete, "supply contract state did not persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(32)
    expect(sim:totalSupplyContracts() == 3, "supply contract count should be explicit")
    expect(sim:completedSupplyContracts() == 0, "fresh simulation should have no completed contracts")
    expect(sim:currentSupplyContractText():find("Iron Plate") ~= nil, "first contract should ask for iron plates")
    sim:addItem("iron_plate", 5)
    sim:addItem("science_pack", 3)
    sim:addItem("logistic_drone", 1)
    for _, contractId in ipairs({ "iron_supply", "science_supply", "drone_supply" }) do
        sim:queue(Simulation.commands.submitSupplyContract(contractId))
        sim:step()
    end
    expect(sim:completedSupplyContracts() == sim:totalSupplyContracts(), "all submitted contracts should complete")
    expect(sim:currentSupplyContractText():find("contract complete") ~= nil, "completed contract text should show completion")
    expect(not sim:mainObjectiveComplete(), "main objective should wait for final tech")
    sim.completedTechs.logistics_1 = true
    sim.completedTechs.automation_control = true
    sim.completedTechs.logistic_network = true
    sim.activeTech = nil
    expect(sim:mainObjectiveComplete(), "completed contracts and tech should complete the main objective")
    expect(sim:nextStepText():find("Main objective complete") == 1, "next step should surface objective completion")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:mainObjectiveComplete(), "main objective completion did not survive save/load")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(33)
    local rates = sim:productionRatePanels()
    expect(#rates == 5, "production rate panels should expose tracked outputs")
    expect(rates[1].key == "iron_plate" and rates[1].blocked, "iron rate target should start blocked")
    expect(sim:productionRateText():find("rates: Iron/min 0/3") == 1, "production rate text should surface first blocked target")
    sim.productionTotals.iron_plate = 4
    sim.productionTotals.copper_plate = 4
    sim.productionTotals.science_pack = 3
    sim.tick = 3600
    expect(not sim:productionRatePanels()[1].blocked, "met iron rate target should unblock")
    expect(sim:productionRateText() == "rates: tracked production meets current targets", "met rate targets should summarize stable production")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(34)
    local function findPanel(panels, key)
        for _, panel in ipairs(panels) do
            if panel.key == key then
                return panel
            end
        end
        return nil
    end
    local panels = sim:factoryDashboard()
    expect(findPanel(panels, "power") ~= nil, "dashboard should include power panel")
    expect(findPanel(panels, "progression") ~= nil, "dashboard should include progression panel")
    expect(findPanel(panels, "rates") ~= nil, "dashboard should include rates panel")
    expect(sim:factoryDashboardText():find("dashboard: next Progression") == 1, "dashboard should surface first incomplete panel")
    sim.world:setTile(1, 0, 0, { id = "iron_ore", data = 10 })
    sim:addMachine("power_pole", 0, 0, "south")
    sim:addMachine("electric_miner", 1, 0, "east")
    sim:step()
    local power = findPanel(sim:factoryDashboard(), "power")
    expect(power.urgent and power.status == "underpowered", "dashboard should flag underpowered networks")
    expect(sim:factoryDashboardText():find("dashboard: urgent Power") == 1, "dashboard should prioritize urgent power panel")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(35)
    sim.productionTotals.iron_plate = 1
    sim.productionTotals.copper_plate = 1
    sim.productionTotals.science_pack = 1
    sim.completedTechs.logistics_1 = true
    sim.supplyContracts[1].complete = true
    local progress = sim:achievementProgress()
    expect(#progress == 6, "achievement progress should expose all definitions")
    expect(progress[1].current >= progress[1].required, "achievement progress should derive from totals")
    expect(sim:unlockedAchievementCount() == 0, "achievements should not unlock before a step")
    sim:step()
    expect(sim:unlockedAchievementCount() == 5, "seeded achievements should unlock after a step")
    expect(sim:isAchievementUnlocked("first_iron_plate"), "first plate achievement should unlock")
    sim:step()
    expect(sim:unlockedAchievementCount() == 5, "achievement updates should not duplicate unlocks")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:unlockedAchievementCount() == 5, "unlocked achievements should persist")
    expect(loaded:isAchievementUnlocked("first_supply_contract"), "supply achievement should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(36, true)
    local function stepComplete(state, key)
        for _, step in ipairs(state:tutorialProgress()) do
            if step.key == key then
                return step.complete
            end
        end
        return false
    end
    expect(sim.world:getTile(0, 0, 2).id == "floor", "tutorial spawn should be floor")
    expect(sim.world:getTile(-3, 0, 2).id == "tree", "tutorial room should contain a tree")
    expect(sim.world:getTile(-2, 2, 2).id == "stone", "tutorial room should contain stone")
    expect(sim.world:getTile(5, 0, 2).id == "stairs_down", "tutorial room should contain an exit")
    expect(sim.world:getTile(6, 0, 2).id == "dungeon_wall", "tutorial room should be isolated")
    expect(sim:tutorialState().active and not sim:tutorialState().completed, "tutorial start state should be active")
    expect(sim.player.z == 2 and sim:machineAt(3, 0, 2) ~= nil, "tutorial should spawn player and chest on tutorial layer")
    sim.world:setTile(0, -1, 2, { id = "grass", data = 0 })
    sim:queue(Simulation.commands.mine("north"))
    sim:step()
    expect(not stepComplete(sim, "mine"), "failed mine should not complete tutorial mine step")
    sim:queue(Simulation.commands.move("east"))
    sim:step()
    expect(stepComplete(sim, "move"), "successful move should complete tutorial move step")
    sim.player.x = -2
    sim.player.y = 0
    sim:queue(Simulation.commands.mine("west"))
    sim:step()
    expect(stepComplete(sim, "mine"), "successful mine should complete tutorial mine step")
    sim:addItem("wood", 5)
    sim:addItem("stone", 2)
    sim:queue(Simulation.commands.craft("workbench"))
    sim:step()
    expect(stepComplete(sim, "craft"), "successful craft should complete tutorial craft step")
    sim.player.x = 0
    sim.player.y = 0
    sim:queue(Simulation.commands.place("south", "workbench", "south"))
    sim:step()
    expect(stepComplete(sim, "place"), "successful place should complete tutorial place step")
    sim.player.x = 2
    sim.player.y = 0
    sim:addItem("wood", 1)
    sim:queue(Simulation.commands.deposit("east", "wood"))
    sim:step()
    expect(stepComplete(sim, "deposit"), "successful deposit should complete tutorial deposit step")
    expect(sim:tutorialExitReady(), "tutorial exit should unlock after checklist completion")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:tutorialExitReady(), "tutorial checklist should persist")
    loaded.player.x = 4
    loaded.player.y = 0
    loaded:queue(Simulation.commands.move("east"))
    loaded:step()
    expect(not loaded:tutorialState().active and loaded:tutorialState().completed, "tutorial exit should complete tutorial")
    expect(loaded.player.z == 0, "tutorial exit should return to real layer")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(31)
    local lab = sim:addMachine("lab", 0, 0, "south")
    lab.inventory:add("science_pack", 7)
    runSteps(sim, 180)
    expect(sim:isTechCompleted("logistics_1"), "logistics_1 was not completed")
    expect(sim:isTechCompleted("automation_control"), "automation_control was not completed")
    expect(sim.activeTech == "logistic_network", "active tech did not advance to logistic_network")
    for _, recipe in ipairs({ "fast_belt", "generator", "power_pole", "electric_miner", "splitter", "pipe" }) do
        expect(sim:isRecipeUnlocked(recipe), "logistics_1 unlock path missing " .. recipe)
    end
    for _, recipe in ipairs({ "circuit_board", "advanced_science_pack", "crystal_lens", "circuit_inserter", "offshore_pump", "guard_tower", "repair_pylon" }) do
        expect(sim:isRecipeUnlocked(recipe), "automation_control unlock path missing " .. recipe)
    end
    lab.inventory:add("advanced_science_pack", 5)
    runSteps(sim, 120)
    expect(sim:isTechCompleted("logistic_network"), "logistic_network was not completed")
    for _, recipe in ipairs({
        "provider_chest", "requester_chest", "logistic_port", "logistic_drone", "beacon_core", "archive_terminal",
        "train_stop", "rift_gate", "outpost_beacon", "pressure_relay", "arc_tower",
    }) do
        expect(sim:isRecipeUnlocked(recipe), "logistic_network unlock path missing " .. recipe)
    end
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.activeTech == nil, "completed tech chain should stay complete after load")
    expect(loaded:isRecipeUnlocked("rift_gate"), "final tech unlocks did not persist")
end

for index, test in ipairs(tests) do
    local ok, err = pcall(test)
    if not ok then
        io.stderr:write("not ok ", index, " - ", tostring(err), "\n")
        os.exit(1)
    end
    io.stdout:write("ok ", index, "\n")
end

io.stdout:write("tests passed: ", #tests, "\n")
