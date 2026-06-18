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

for index, test in ipairs(tests) do
    local ok, err = pcall(test)
    if not ok then
        io.stderr:write("not ok ", index, " - ", tostring(err), "\n")
        os.exit(1)
    end
    io.stdout:write("ok ", index, "\n")
end

io.stdout:write("tests passed: ", #tests, "\n")
