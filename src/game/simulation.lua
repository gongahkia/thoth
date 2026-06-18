local Defs = require("src.game.defs")
local Grid = require("src.core.grid")
local Inventory = require("src.game.inventory")
local World = require("src.game.world")

local Simulation = {}
Simulation.__index = Simulation

local machineOutputs = {
    burner_miner = Defs.itemOrder,
    furnace = { "iron_plate", "copper_plate", "sand_glass" },
    assembler = { "science_pack", "advanced_science_pack", "circuit_board", "beacon_core" },
    chest = Defs.itemOrder,
}

local function copySet(values)
    local result = {}
    for key, value in pairs(values or {}) do
        result[key] = value
    end
    return result
end

local function recipeUnlockedDefaults()
    local result = {}
    for key, recipe in pairs(Defs.recipes) do
        result[key] = recipe.default == true
    end
    return result
end

local function newMachine(id, kind, x, y, direction)
    return {
        id = id,
        kind = kind,
        x = x,
        y = y,
        z = 0,
        direction = direction or "south",
        inventory = Inventory.new(),
        progress = 0,
        fuel = 0,
        carriedItem = nil,
        outputItem = nil,
        recipeKey = kind == "assembler" and "science_pack" or kind == "furnace" and "iron_plate" or nil,
        filterItem = nil,
        circuitComparator = "always",
        circuitThreshold = 0,
        status = "idle",
    }
end

function Simulation.new(seed)
    local self = setmetatable({
        seed = seed or 1,
        tick = 0,
        world = World.new(seed or 1),
        player = {
            x = 0,
            y = 0,
            z = 0,
            facing = "south",
            inventory = Inventory.new(),
            hotbar = {},
            selectedHotbar = 1,
            hp = 20,
        },
        machines = {},
        nextMachineId = 1,
        commandQueue = {},
        unlockedRecipes = recipeUnlockedDefaults(),
        completedTechs = {},
        activeTech = "logistics_1",
        researchProgress = 0,
        productionTotals = {
            iron_plate = 0,
            copper_plate = 0,
            science_pack = 0,
        },
    }, Simulation)
    return self
end

Simulation.commands = {}

function Simulation.commands.face(direction)
    return { type = "face", direction = direction }
end

function Simulation.commands.move(direction)
    return { type = "move", direction = direction }
end

function Simulation.commands.mine(direction)
    return { type = "mine", direction = direction }
end

function Simulation.commands.place(direction, item, orientation)
    return { type = "place", direction = direction, item = item, orientation = orientation or direction }
end

function Simulation.commands.craft(recipeKey)
    return { type = "craft", recipeKey = recipeKey }
end

function Simulation.commands.deposit(direction, item)
    return { type = "deposit", direction = direction, item = item }
end

function Simulation.commands.selectHotbar(index)
    return { type = "select_hotbar", index = index }
end

function Simulation.commands.assignHotbar(index, item)
    return { type = "assign_hotbar", index = index, item = item }
end

function Simulation.commands.setMachineRecipe(machineId, recipeKey)
    return { type = "set_machine_recipe", machineId = machineId, recipeKey = recipeKey }
end

function Simulation.commands.depositMachine(machineId, item, count)
    return { type = "deposit_machine", machineId = machineId, item = item, count = count or 1 }
end

function Simulation.commands.withdrawMachine(machineId, item, count)
    return { type = "withdraw_machine", machineId = machineId, item = item, count = count or 1 }
end

function Simulation.commands.configureCircuit(machineId, filterItem, comparator, threshold)
    return {
        type = "configure_circuit",
        machineId = machineId,
        filterItem = filterItem,
        comparator = comparator or "always",
        threshold = threshold or 0,
    }
end

function Simulation:queue(command)
    self.commandQueue[#self.commandQueue + 1] = command
end

function Simulation:step()
    local queue = self.commandQueue
    self.commandQueue = {}
    for _, command in ipairs(queue) do
        self:apply(command)
    end
    self:updateMachines()
    self.tick = self.tick + 1
end

function Simulation:selectedItem()
    return self.player.hotbar[self.player.selectedHotbar]
end

function Simulation:itemCount(item)
    return self.player.inventory:count(item)
end

function Simulation:addItem(item, count)
    if self.player.inventory:add(item, count) then
        self:assignFirstHotbar(item)
        return true
    end
    return false
end

function Simulation:consumeItem(item, count)
    return self.player.inventory:consume(item, count)
end

function Simulation:assignFirstHotbar(item)
    for i = 1, 10 do
        if self.player.hotbar[i] == item then
            return
        end
    end
    for i = 1, 10 do
        if not self.player.hotbar[i] then
            self.player.hotbar[i] = item
            return
        end
    end
end

function Simulation:machineAt(x, y, z)
    z = z or 0
    for _, machine in ipairs(self.machines) do
        if machine.x == x and machine.y == y and (machine.z or 0) == z then
            return machine
        end
    end
    return nil
end

function Simulation:machineById(id)
    for _, machine in ipairs(self.machines) do
        if machine.id == id then
            return machine
        end
    end
    return nil
end

function Simulation:hasMachine(kind)
    for _, machine in ipairs(self.machines) do
        if machine.kind == kind then
            return true
        end
    end
    return false
end

function Simulation:anyItemCount(item)
    local total = self:itemCount(item)
    for _, machine in ipairs(self.machines) do
        total = total + machine.inventory:count(item)
        if machine.carriedItem == item then
            total = total + 1
        end
        if machine.outputItem == item then
            total = total + 1
        end
    end
    return total
end

function Simulation:machineItemCount(kind, item)
    local total = 0
    for _, machine in ipairs(self.machines) do
        if machine.kind == kind then
            total = total + machine.inventory:count(item)
        end
    end
    return total
end

function Simulation:isWalkable(x, y, z)
    return self.world:isWalkable(x, y, z or 0) and self:machineAt(x, y, z or 0) == nil
end

function Simulation:addMachine(kind, x, y, direction)
    local machine = newMachine(self.nextMachineId, kind, x, y, direction)
    self.nextMachineId = self.nextMachineId + 1
    self.machines[#self.machines + 1] = machine
    table.sort(self.machines, function(a, b)
        return a.id < b.id
    end)
    return machine
end

function Simulation:canPlaceMachine(kind, x, y, z)
    if self:machineAt(x, y, z or 0) then
        return false
    end
    local machineDef = Defs.machine(kind)
    if not machineDef then
        return false
    end
    local tile = self.world:getTile(x, y, z or 0)
    local tileDef = Defs.tile(tile.id)
    if machineDef.resource then
        return tileDef.resource ~= nil
    end
    return tileDef.buildable == true
end

function Simulation:apply(command)
    if command.type == "face" then
        self.player.facing = command.direction or self.player.facing
        return
    end
    if command.type == "move" then
        self:move(command.direction)
        return
    end
    if command.type == "mine" then
        self:mine(command.direction)
        return
    end
    if command.type == "place" then
        self:place(command.direction, command.item, command.orientation)
        return
    end
    if command.type == "craft" then
        self:craft(command.recipeKey)
        return
    end
    if command.type == "deposit" then
        self:deposit(command.direction, command.item)
        return
    end
    if command.type == "select_hotbar" then
        self.player.selectedHotbar = math.max(1, math.min(10, command.index or 1))
        return
    end
    if command.type == "assign_hotbar" then
        self.player.hotbar[math.max(1, math.min(10, command.index or 1))] = command.item
        return
    end
    if command.type == "set_machine_recipe" then
        self:setMachineRecipe(command.machineId, command.recipeKey)
        return
    end
    if command.type == "deposit_machine" then
        self:depositToMachine(command.machineId, command.item, command.count)
        return
    end
    if command.type == "withdraw_machine" then
        self:withdrawFromMachine(command.machineId, command.item, command.count)
        return
    end
    if command.type == "configure_circuit" then
        self:configureCircuit(command.machineId, command.filterItem, command.comparator, command.threshold)
    end
end

function Simulation:move(direction)
    direction = direction or self.player.facing
    self.player.facing = direction
    local x, y = Grid.front(self.player.x, self.player.y, direction)
    if self:isWalkable(x, y, self.player.z) then
        self.player.x = x
        self.player.y = y
    end
end

function Simulation:mine(direction)
    direction = direction or self.player.facing
    self.player.facing = direction
    local x, y = Grid.front(self.player.x, self.player.y, direction)
    local drop = self.world:mineTile(x, y, self.player.z)
    if drop then
        self:addItem(drop, 1)
        return true
    end
    return false
end

function Simulation:place(direction, item, orientation)
    if not item or self:itemCount(item) <= 0 then
        return false
    end
    direction = direction or self.player.facing
    self.player.facing = direction
    local x, y = Grid.front(self.player.x, self.player.y, direction)
    local itemDef = Defs.item(item)
    if not itemDef then
        return false
    end
    if itemDef.machine then
        if not self:canPlaceMachine(itemDef.machine, x, y, self.player.z) then
            return false
        end
        if not self:consumeItem(item, 1) then
            return false
        end
        self:addMachine(itemDef.machine, x, y, orientation or direction)
        return true
    end
    if itemDef.tile then
        local tileDef = Defs.tile(self.world:getTile(x, y, self.player.z).id)
        if not tileDef.buildable or self:machineAt(x, y, self.player.z) then
            return false
        end
        if not self:consumeItem(item, 1) then
            return false
        end
        self.world:setTile(x, y, self.player.z, { id = itemDef.tile, data = 0 })
        return true
    end
    return false
end

function Simulation:hasAdjacentWorkbench()
    for _, machine in ipairs(self.machines) do
        if machine.kind == "workbench" and Grid.manhattan(machine.x, machine.y, self.player.x, self.player.y) <= 1 then
            return true
        end
    end
    return false
end

function Simulation:isRecipeUnlocked(recipeKey)
    return self.unlockedRecipes[recipeKey] == true
end

function Simulation:isTechCompleted(techKey)
    return self.completedTechs[techKey] == true
end

function Simulation:craft(recipeKey)
    local recipe = Defs.recipe(recipeKey)
    if not recipe or not self:isRecipeUnlocked(recipeKey) then
        return false
    end
    if recipe.station == "workbench" and not self:hasAdjacentWorkbench() then
        return false
    end
    if recipe.station ~= "hand" and recipe.station ~= "workbench" then
        return false
    end
    if not self.player.inventory:consumeAll(recipe.inputs) then
        return false
    end
    self:addItem(recipe.output.item, recipe.output.count)
    return true
end

function Simulation:deposit(direction, item)
    direction = direction or self.player.facing
    self.player.facing = direction
    item = item or self:selectedItem()
    if not item or self:itemCount(item) <= 0 then
        return false
    end
    local x, y = Grid.front(self.player.x, self.player.y, direction)
    local target = self:machineAt(x, y, self.player.z)
    if not target or not self:acceptItem(target, item) then
        return false
    end
    self:consumeItem(item, 1)
    return true
end

local function normalizedCount(count, available)
    if count == "all" then
        return available
    end
    return math.max(1, math.min(available, tonumber(count) or 1))
end

function Simulation:depositToMachine(machineId, item, count)
    local target = self:machineById(machineId)
    local available = item and self:itemCount(item) or 0
    if not target or available <= 0 then
        return false
    end
    local moved = 0
    local wanted = normalizedCount(count, available)
    while moved < wanted and self:itemCount(item) > 0 do
        if not self:acceptItem(target, item) then
            break
        end
        self:consumeItem(item, 1)
        moved = moved + 1
    end
    return moved > 0
end

function Simulation:withdrawFromMachine(machineId, item, count)
    local target = self:machineById(machineId)
    if not target or not item then
        return false
    end
    if (target.kind == "belt" or target.kind == "fast_belt") and target.carriedItem == item then
        target.carriedItem = nil
        self:addItem(item, 1)
        return true
    end
    local available = target.inventory:count(item)
    if available <= 0 then
        return false
    end
    local moved = 0
    local wanted = normalizedCount(count, available)
    while moved < wanted and target.inventory:consume(item, 1) do
        self:addItem(item, 1)
        moved = moved + 1
    end
    return moved > 0
end

function Simulation:setMachineRecipe(machineId, recipeKey)
    local machine = self:machineById(machineId)
    if not machine or not Defs.machineRecipe(machine.kind, recipeKey) then
        return false
    end
    machine.recipeKey = recipeKey
    machine.progress = 0
    machine.outputItem = nil
    machine.status = "idle"
    return true
end

function Simulation:configureCircuit(machineId, filterItem, comparator, threshold)
    local machine = self:machineById(machineId)
    if not machine or machine.kind ~= "circuit_inserter" then
        return false
    end
    machine.filterItem = Defs.item(filterItem) and filterItem or nil
    if comparator == "less_than" or comparator == "greater_or_equal" then
        machine.circuitComparator = comparator
    else
        machine.circuitComparator = "always"
    end
    machine.circuitThreshold = math.max(0, tonumber(threshold) or 0)
    return true
end

function Simulation:updateMachines()
    for _, machine in ipairs(self.machines) do
        if machine.kind == "burner_miner" then
            self:updateMiner(machine)
        elseif machine.kind == "belt" or machine.kind == "fast_belt" then
            self:updateBelt(machine)
        elseif machine.kind == "splitter" then
            self:updateSplitter(machine)
        elseif machine.kind == "inserter" or machine.kind == "circuit_inserter" then
            self:updateInserter(machine)
        elseif machine.kind == "furnace" then
            self:updateFurnace(machine)
        elseif machine.kind == "assembler" then
            self:updateAssembler(machine)
        elseif machine.kind == "lab" then
            self:updateLab(machine)
        end
    end
end

function Simulation:refuel(machine)
    if machine.fuel > 0 then
        return true
    end
    if machine.inventory:consume("coal", 1) then
        machine.fuel = 120
        return true
    end
    return false
end

function Simulation:updateMiner(machine)
    if not self:refuel(machine) then
        machine.status = "missing_fuel"
        return
    end
    machine.fuel = machine.fuel - 1
    machine.progress = machine.progress + 1
    machine.status = "working"
    if machine.progress < 30 then
        return
    end
    machine.progress = 0
    local item = self.world:consumeResource(machine.x, machine.y, machine.z or 0)
    if not item then
        machine.status = "missing_resource"
        return
    end
    local x, y = Grid.front(machine.x, machine.y, machine.direction)
    if not self:acceptItemAt(x, y, machine.z or 0, item) then
        machine.inventory:add(item, 1)
    end
end

function Simulation:updateBelt(machine)
    if not machine.carriedItem then
        machine.status = "idle"
        return
    end
    local period = machine.kind == "fast_belt" and 6 or 12
    if self.tick % period ~= 0 then
        machine.status = "working"
        return
    end
    local x, y = Grid.front(machine.x, machine.y, machine.direction)
    if self:acceptItemAt(x, y, machine.z or 0, machine.carriedItem) then
        machine.carriedItem = nil
        machine.status = "working"
    else
        machine.status = "output_blocked"
    end
end

function Simulation:updateSplitter(machine)
    if not machine.carriedItem then
        machine.status = "idle"
        return
    end
    local first = machine.progress % 2 == 0 and Grid.left(machine.direction) or Grid.right(machine.direction)
    local last = machine.progress % 2 == 0 and Grid.right(machine.direction) or Grid.left(machine.direction)
    local outputs = { first, machine.direction, last }
    for _, direction in ipairs(outputs) do
        local x, y = Grid.front(machine.x, machine.y, direction)
        if self:acceptItemAt(x, y, machine.z or 0, machine.carriedItem) then
            machine.carriedItem = nil
            machine.progress = (machine.progress + 1) % 2
            machine.status = "working"
            return
        end
    end
    machine.status = "output_blocked"
end

function Simulation:countMachineItem(machine, item)
    if not item then
        local total = 0
        for _, stack in ipairs(machine.inventory:stacks()) do
            total = total + stack.count
        end
        return total + (machine.carriedItem and 1 or 0) + (machine.outputItem and 1 or 0)
    end
    local total = machine.inventory:count(item)
    if machine.carriedItem == item then
        total = total + 1
    end
    if machine.outputItem == item then
        total = total + 1
    end
    return total
end

function Simulation:circuitAllows(machine, target)
    if machine.kind ~= "circuit_inserter" or machine.circuitComparator == "always" then
        return true
    end
    if not target then
        return false
    end
    local count = self:countMachineItem(target, machine.filterItem)
    if machine.circuitComparator == "less_than" then
        return count < machine.circuitThreshold
    end
    if machine.circuitComparator == "greater_or_equal" then
        return count >= machine.circuitThreshold
    end
    return true
end

function Simulation:updateInserter(machine)
    machine.progress = machine.progress + 1
    if machine.progress < 15 then
        return
    end
    machine.progress = 0
    if machine.carriedItem then
        local x, y = Grid.front(machine.x, machine.y, machine.direction)
        if self:acceptItemAt(x, y, machine.z or 0, machine.carriedItem) then
            machine.carriedItem = nil
            machine.status = "working"
        else
            machine.status = "output_blocked"
        end
        return
    end
    local x, y = Grid.back(machine.x, machine.y, machine.direction)
    local source = self:machineAt(x, y, machine.z or 0)
    if not source then
        machine.status = "missing_input"
        return
    end
    local tx, ty = Grid.front(machine.x, machine.y, machine.direction)
    if not self:circuitAllows(machine, self:machineAt(tx, ty, machine.z or 0)) then
        machine.status = "idle"
        return
    end
    machine.carriedItem = self:extractItem(source, machine.kind == "circuit_inserter" and machine.filterItem or nil)
    machine.status = machine.carriedItem and "working" or "missing_input"
end

function Simulation:updateFurnace(machine)
    local recipe = Defs.machineRecipe("furnace", machine.recipeKey or "iron_plate")
    if not recipe then
        machine.status = "missing_input"
        return
    end
    if machine.progress > 0 then
        machine.progress = machine.progress - 1
        machine.status = "working"
        if machine.progress == 0 and machine.outputItem then
            machine.inventory:add(machine.outputItem, 1)
            self:recordProduced(machine.outputItem)
            machine.outputItem = nil
        end
        return
    end
    if not machine.inventory:canConsume(recipe.inputs) then
        machine.status = "missing_input"
        return
    end
    machine.inventory:consumeAll(recipe.inputs)
    machine.outputItem = recipe.output.item
    machine.progress = recipe.ticks or 60
    machine.status = "working"
end

function Simulation:updateAssembler(machine)
    local recipe = Defs.recipe(machine.recipeKey or "science_pack")
    if not recipe then
        machine.status = "missing_input"
        return
    end
    if machine.progress > 0 then
        machine.progress = machine.progress - 1
        machine.status = "working"
        if machine.progress == 0 then
            machine.inventory:add(recipe.output.item, recipe.output.count)
            self:recordProduced(recipe.output.item)
        end
        return
    end
    if not machine.inventory:consumeAll(recipe.inputs) then
        machine.status = "missing_input"
        return
    end
    machine.progress = recipe.ticks
    machine.status = "working"
end

function Simulation:updateLab(machine)
    if self:isTechCompleted(self.activeTech) then
        machine.status = "idle"
        return
    end
    if machine.progress > 0 then
        machine.progress = machine.progress - 1
        machine.status = "working"
        if machine.progress == 0 then
            self.researchProgress = self.researchProgress + 1
            self:completeResearchIfReady()
        end
        return
    end
    if not machine.inventory:consume("science_pack", 1) then
        machine.status = "missing_input"
        return
    end
    machine.progress = 20
    machine.status = "working"
end

function Simulation:completeResearchIfReady()
    local tech = Defs.tech(self.activeTech)
    if not tech then
        return
    end
    local needed = tech.inputs.science_pack or 0
    if self.researchProgress < needed then
        return
    end
    self.completedTechs[self.activeTech] = true
    for _, recipeKey in ipairs(tech.unlocks) do
        self.unlockedRecipes[recipeKey] = true
    end
end

function Simulation:acceptItemAt(x, y, z, item)
    local target = self:machineAt(x, y, z or 0)
    if not target then
        return false
    end
    return self:acceptItem(target, item)
end

function Simulation:acceptItem(machine, item)
    if machine.kind == "belt" or machine.kind == "fast_belt" or machine.kind == "splitter" then
        if machine.carriedItem then
            return false
        end
        machine.carriedItem = item
        return true
    end
    if machine.kind == "burner_miner" then
        return item == "coal" and machine.inventory:add(item, 1)
    end
    if machine.kind == "furnace" then
        local recipe = Defs.machineRecipe("furnace", machine.recipeKey or "iron_plate")
        return recipe and recipe.inputs[item] ~= nil and machine.inventory:add(item, 1)
    end
    if machine.kind == "assembler" then
        local recipe = Defs.recipe(machine.recipeKey or "science_pack")
        return recipe and recipe.inputs[item] ~= nil and machine.inventory:add(item, 1)
    end
    if machine.kind == "lab" then
        return item == "science_pack" and machine.inventory:add(item, 1)
    end
    if machine.kind == "logistic_port" then
        return item == "logistic_drone" and machine.inventory:add(item, 1)
    end
    if machine.kind == "chest" or machine.kind == "provider_chest" or machine.kind == "requester_chest" or machine.kind == "train_stop" then
        return machine.inventory:add(item, 1)
    end
    return false
end

function Simulation:extractItem(machine, filterItem)
    if machine.kind == "belt" or machine.kind == "fast_belt" or machine.kind == "splitter" then
        local item = machine.carriedItem
        if filterItem and item ~= filterItem then
            return nil
        end
        machine.carriedItem = nil
        return item
    end
    local outputs = machineOutputs[machine.kind] or Defs.itemOrder
    if filterItem then
        outputs = { filterItem }
    end
    for _, item in ipairs(outputs) do
        if machine.inventory:consume(item, 1) then
            return item
        end
    end
    return nil
end

function Simulation:recordProduced(item)
    if self.productionTotals[item] ~= nil then
        self.productionTotals[item] = self.productionTotals[item] + 1
    end
end

function Simulation:objectiveChecklist()
    local hasBench = self:hasMachine("workbench")
    local hasMiner = self:hasMachine("burner_miner")
    local hasFurnace = self:hasMachine("furnace")
    return {
        {
            title = "First",
            items = {
                { label = "wood", done = self:anyItemCount("wood") >= 6 or hasBench or hasMiner, next = "Mine west trees for workbench wood" },
                { label = "stone", done = self:anyItemCount("stone") >= 8 or hasFurnace or hasMiner, next = "Mine southern stone for furnace and belts" },
                { label = "bench", done = hasBench, next = "Craft and place a workbench" },
                { label = "miner", done = hasMiner, next = "Craft and place a burner miner on ore" },
                { label = "plate", done = self.productionTotals.iron_plate > 0, next = "Fuel miner and furnace, then route ore into smelting" },
            },
        },
        {
            title = "Science",
            items = {
                { label = "assembler", done = self:hasMachine("assembler"), next = "Craft and place an assembler near plate supply" },
                { label = "lab", done = self:hasMachine("lab"), next = "Craft and place a lab" },
                { label = "pack", done = self:anyItemCount("science_pack") > 0 or self.productionTotals.science_pack > 0, next = "Feed iron and copper plates into an assembler for science" },
                { label = "logistics", done = self:isTechCompleted("logistics_1"), next = "Move science packs into a lab for Logistics 1" },
            },
        },
        {
            title = "Power",
            items = {
                { label = "science base", done = self:isTechCompleted("logistics_1"), next = "Finish Logistics 1 before the power chain" },
                { label = "generator", done = false, blocked = true, next = "Generator unlock is scheduled for automation parity" },
            },
        },
        {
            title = "Supply",
            items = {
                { label = "chest", done = self:hasMachine("chest"), next = "Craft a chest for plate output" },
                { label = "coal", done = self:anyItemCount("coal") > 0 or self:machineItemCount("burner_miner", "coal") > 0, next = "Mine coal and deposit it into burner machines" },
                { label = "stored plate", done = self:machineItemCount("chest", "iron_plate") > 0, next = "Use inserters to store iron plates in a chest" },
            },
        },
        {
            title = "Biome",
            items = {
                { label = "grassland", done = true, next = "Use the starter grassland to bootstrap production" },
                { label = "coal patch", done = self.world:getTile(3, 0, 0).id == "coal_ore", next = "Build toward the eastern coal patch" },
                { label = "ore patches", done = self.world:getTile(0, -3, 0).id == "iron_ore" and self.world:getTile(3, -3, 0).id == "copper_ore", next = "Use northern iron and copper starter patches" },
            },
        },
    }
end

function Simulation:nextStepText()
    for _, group in ipairs(self:objectiveChecklist()) do
        for _, item in ipairs(group.items) do
            if not item.done and not item.blocked then
                return item.next
            end
        end
    end
    return "Scale science and continue the next roadmap phase"
end

function Simulation:objectiveText()
    return self:nextStepText()
end

function Simulation:snapshot()
    local machines = {}
    for _, machine in ipairs(self.machines) do
        machines[#machines + 1] = {
            id = machine.id,
            kind = machine.kind,
            x = machine.x,
            y = machine.y,
            z = machine.z or 0,
            direction = machine.direction,
            inventory = machine.inventory:stacks(),
            progress = machine.progress,
            fuel = machine.fuel,
            carriedItem = machine.carriedItem,
            outputItem = machine.outputItem,
            recipeKey = machine.recipeKey,
            filterItem = machine.filterItem,
            circuitComparator = machine.circuitComparator,
            circuitThreshold = machine.circuitThreshold,
            status = machine.status,
        }
    end
    return {
        seed = self.seed,
        tick = self.tick,
        world = self.world:snapshot(),
        player = {
            x = self.player.x,
            y = self.player.y,
            z = self.player.z,
            facing = self.player.facing,
            inventory = self.player.inventory:stacks(),
            hotbar = self.player.hotbar,
            selectedHotbar = self.player.selectedHotbar,
            hp = self.player.hp,
        },
        machines = machines,
        nextMachineId = self.nextMachineId,
        unlockedRecipes = copySet(self.unlockedRecipes),
        completedTechs = copySet(self.completedTechs),
        activeTech = self.activeTech,
        researchProgress = self.researchProgress,
        productionTotals = copySet(self.productionTotals),
    }
end

function Simulation.fromSnapshot(snapshot)
    local self = Simulation.new(snapshot.seed)
    self.seed = snapshot.seed
    self.tick = snapshot.tick or 0
    self.world = World.fromSnapshot(snapshot.world or { seed = snapshot.seed, tiles = {} })
    self.player.x = snapshot.player.x
    self.player.y = snapshot.player.y
    self.player.z = snapshot.player.z or 0
    self.player.facing = snapshot.player.facing or "south"
    self.player.inventory = Inventory.new(snapshot.player.inventory or {})
    self.player.hotbar = snapshot.player.hotbar or {}
    self.player.selectedHotbar = snapshot.player.selectedHotbar or 1
    self.player.hp = snapshot.player.hp or 20
    self.machines = {}
    for _, value in ipairs(snapshot.machines or {}) do
        local machine = newMachine(value.id, value.kind, value.x, value.y, value.direction)
        machine.z = value.z or 0
        machine.inventory = Inventory.new(value.inventory or {})
        machine.progress = value.progress or 0
        machine.fuel = value.fuel or 0
        machine.carriedItem = value.carriedItem
        machine.outputItem = value.outputItem
        machine.recipeKey = value.recipeKey or (value.kind == "furnace" and "iron_plate" or value.kind == "assembler" and "science_pack" or nil)
        machine.filterItem = value.filterItem
        machine.circuitComparator = value.circuitComparator or "always"
        machine.circuitThreshold = value.circuitThreshold or 0
        machine.status = value.status or "idle"
        self.machines[#self.machines + 1] = machine
    end
    self.nextMachineId = snapshot.nextMachineId or (#self.machines + 1)
    self.unlockedRecipes = copySet(snapshot.unlockedRecipes or recipeUnlockedDefaults())
    self.completedTechs = copySet(snapshot.completedTechs or {})
    self.activeTech = snapshot.activeTech or "logistics_1"
    self.researchProgress = snapshot.researchProgress or 0
    self.productionTotals = copySet(snapshot.productionTotals or {})
    return self
end

return Simulation
