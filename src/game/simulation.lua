local Defs = require("src.game.defs")
local Grid = require("src.core.grid")
local Inventory = require("src.game.inventory")
local Rng = require("src.core.rng")
local World = require("src.game.world")

local Simulation = {}
Simulation.__index = Simulation

local machineOutputs = {
    burner_miner = Defs.itemOrder,
    furnace = { "iron_plate", "copper_plate", "sand_glass" },
    assembler = { "science_pack", "advanced_science_pack", "circuit_board", "beacon_core" },
    chest = Defs.itemOrder,
}
local pressureWeights = {
    lab = 28,
    assembler = 28,
    archive_terminal = 28,
    rift_gate = 28,
    generator = 16,
    electric_miner = 16,
    logistic_port = 16,
    outpost_beacon = 16,
    guard_tower = 8,
    arc_tower = 8,
    pressure_relay = 8,
    repair_pylon = 8,
    belt = 6,
    fast_belt = 6,
    inserter = 6,
    circuit_inserter = 6,
    splitter = 6,
    train_stop = 6,
    pipe = 6,
    offshore_pump = 6,
    burner_miner = 6,
    furnace = 6,
    chest = 2,
    provider_chest = 2,
    requester_chest = 2,
    workbench = 2,
    power_pole = 2,
}
local guardTowerAmmo = { "copper_coil", "frost_cell", "stone_shot" }
local arcTowerAmmo = { "rift_shell", "crystal_charge", "copper_coil" }
local outpostBeaconTicks = 80
local outpostDeliveryTicks = 100
local outpostRouteWindowTicks = 600
local outpostRouteStableThreshold = 3
local scoutDispatchTicks = 120
local archiveTerminalTicks = 360
local riftGateTicks = 180
local riftOffset = 4096
local riftStormBaseTicks = 120
local riftStormCooldownTicks = 300
local requiredOutpostBiomes = { "marsh", "desert", "badlands", "snowfield", "crystal_field" }
local scoutBiomes = { "marsh", "desert", "badlands", "snowfield", "crystal_field", "rift" }
local outpostActivationItems = {
    marsh = "water_barrel",
    desert = "sand_glass",
    badlands = "basalt",
    snowfield = "ice_shard",
    crystal_field = "crystal",
    rift = "beacon_core",
    grassland = "stone",
}
local scoutRewards = {
    marsh = "reed_fiber",
    desert = "cactus_fiber",
    badlands = "basalt",
    snowfield = "ice_shard",
    crystal_field = "crystal",
    rift = "scrap",
    grassland = "wood",
}
local scoutFragments = {
    marsh = "marsh_fragment",
    desert = "desert_fragment",
    badlands = "badlands_fragment",
    snowfield = "frost_fragment",
    crystal_field = "crystal_fragment",
    rift = "rift_fragment",
    grassland = "archive_fragment",
}
local archiveChoiceDefs = {
    { key = "reed_science", recipeKey = "reed_science_pack", fragment = "marsh_fragment", fragmentCost = 1, scienceCost = 1 },
    { key = "dry_copper", recipeKey = "dry_copper_plate", fragment = "desert_fragment", fragmentCost = 1, scienceCost = 1 },
    { key = "washed_iron", recipeKey = "washed_iron_plate", fragment = "archive_fragment", fragmentCost = 2, scienceCost = 2 },
    { key = "basalt_circuit", recipeKey = "basalt_circuit_board", fragment = "badlands_fragment", fragmentCost = 1, scienceCost = 2 },
    { key = "rift_beacon", recipeKey = "rift_beacon_core", fragment = "rift_fragment", fragmentCost = 1, scienceCost = 3 },
}
local archiveFragmentItems = {
    archive_fragment = true,
    marsh_fragment = true,
    desert_fragment = true,
    badlands_fragment = true,
    frost_fragment = true,
    crystal_fragment = true,
    rift_fragment = true,
}
local machineDurability = {
    wall = 12,
    plank_wall = 8,
    door = 8,
    chest = 8,
    provider_chest = 8,
    requester_chest = 8,
    guard_tower = 12,
    arc_tower = 12,
    repair_pylon = 12,
    pressure_relay = 12,
}
local tileDurability = {
    wall = 10,
    plank_wall = 6,
    door = 6,
}

local function machineMaxDurability(kind)
    return machineDurability[kind] or 10
end

local function tileMaxDurability(id)
    return tileDurability[id] or 0
end

local function isDamageableStructureTile(id)
    return tileMaxDurability(id) > 0
end

local function isRepairableWallGap(id)
    return id == "floor" or id == "dungeon_floor" or id == "grass" or id == "dirt"
end

local function repairMaterialForTile(id)
    if id == "plank_wall" then
        return "plank_wall"
    end
    if id == "door" then
        return "iron_plate"
    end
    return "wall"
end

local function outpostBiomeKey(prefix, biome)
    return prefix .. "_" .. tostring(biome or "grassland")
end

local function outpostActivationItem(biome)
    return outpostActivationItems[biome] or "stone"
end

local function scoutRewardForBiome(biome)
    return scoutRewards[biome] or "wood"
end

local function scoutRewardCountForBiome(biome)
    if biome == "rift" or biome == "crystal_field" then
        return 1
    end
    return 2
end

local function scoutBiomeForReward(item)
    for biome, reward in pairs(scoutRewards) do
        if reward == item then
            return biome
        end
    end
    return nil
end

local function fragmentForBiome(biome)
    return scoutFragments[biome] or "archive_fragment"
end

local function copySet(values)
    local result = {}
    for key, value in pairs(values or {}) do
        result[key] = value
    end
    return result
end

local function copyList(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[#result + 1] = value
    end
    return result
end

local achievementDefs = {
    { key = "first_iron_plate", title = "First Plate", description = "Produce an iron plate", required = 1 },
    { key = "first_copper_plate", title = "Copper Flow", description = "Produce a copper plate", required = 1 },
    { key = "first_science_pack", title = "Lab Sample", description = "Produce a science pack", required = 1 },
    { key = "logistics_one", title = "Logistics Online", description = "Complete Logistics 1 research", required = 1 },
    { key = "first_supply_contract", title = "Supply Proven", description = "Complete a supply contract", required = 1 },
    { key = "main_objective", title = "Rift Prep", description = "Complete the main progression objective", required = 1 },
}

local tutorialLayer = 2
local entityDefs = {
    slime = { hp = 2, hostile = true },
    glass_skitter = { hp = 3, hostile = true },
    sun_scarab = { hp = 4, hostile = true },
    skeleton = { hp = 4, hostile = true },
    cave_crawler = { hp = 4, hostile = true },
    frost_crawler = { hp = 4, hostile = true },
    null_wisp = { hp = 5, hostile = true },
    dungeon_sentinel = { hp = 6, hostile = true },
    rift_stalker = { hp = 8, hostile = true },
    marsh_broodheart = { hp = 14, hostile = true, boss = true, drop = "marsh_heart", unlocks = { "repair_pylon" } },
    glass_maw = { hp = 16, hostile = true, boss = true, drop = "glass_heart", unlocks = { "pressure_relay" } },
    badlands_warden = { hp = 18, hostile = true, boss = true, drop = "warden_core", unlocks = { "guard_tower" } },
    frost_nullifier = { hp = 20, hostile = true, boss = true, drop = "frost_core", unlocks = { "arc_tower" } },
    rift_signal_tyrant = { hp = 24, hostile = true, boss = true, drop = "rift_crown", unlocks = { "outpost_beacon" } },
}
local biomeEnemyKinds = {
    marsh = { "slime" },
    desert = { "glass_skitter", "sun_scarab" },
    badlands = { "skeleton", "cave_crawler" },
    snowfield = { "frost_crawler" },
    crystal_field = { "null_wisp" },
    rift = { "rift_stalker" },
}
local bossSummonDefsByLair = {
    marsh_hive = { kind = "marsh_broodheart", biome = "marsh", cost = { water_barrel = 1, reed_fiber = 3, science_pack = 1 } },
    glass_spire = { kind = "glass_maw", biome = "desert", cost = { sand_glass = 3, cactus_fiber = 3, science_pack = 1 } },
    badlands_foundry = { kind = "badlands_warden", biome = "badlands", cost = { basalt = 4, iron_plate = 4, advanced_science_pack = 1 } },
    frost_vault = { kind = "frost_nullifier", biome = "snowfield", cost = { ice_shard = 4, circuit_board = 2, advanced_science_pack = 1 } },
    crystal_vault = { kind = "rift_signal_tyrant", biome = "crystal_field", cost = { beacon_core = 1, crystal = 2, advanced_science_pack = 2 } },
}
local bossSummonOffsets = {
    { -2, 0 },
    { 2, 0 },
    { 0, -2 },
    { 0, 2 },
    { -2, -1 },
    { 2, 1 },
    { -1, 2 },
    { 1, -2 },
}
local pressureSpawnOffsets = {
    { 9, 0 },
    { -9, 0 },
    { 0, 9 },
    { 0, -9 },
    { 7, 5 },
    { -7, 5 },
    { 7, -5 },
    { -7, -5 },
    { 4, 9 },
    { -4, 9 },
    { 9, -4 },
    { -9, -4 },
}
local bossExamDefs = {
    marsh_broodheart = { production = "water_barrel", required = 3 },
    glass_maw = { item = "sand_glass", required = 3 },
    badlands_warden = { production = "powered_ore", required = 8 },
    frost_nullifier = { production = "logistic_deliveries", required = 3 },
    rift_signal_tyrant = { rift = true, required = 5 },
}
local relicSocketRules = {
    repair_pylon = { marsh_heart = true },
    pressure_relay = { glass_heart = true },
    guard_tower = { warden_core = true },
    arc_tower = { frost_core = true, warden_core = true },
    rift_gate = { rift_crown = true },
    outpost_beacon = { rift_crown = true },
}

local tutorialSteps = {
    { key = "move", label = "Move with WASD" },
    { key = "mine", label = "Mine a resource" },
    { key = "craft", label = "Craft a workbench" },
    { key = "place", label = "Place a machine" },
    { key = "deposit", label = "Deposit into the chest" },
}

local function completedTutorialActions()
    local actions = {}
    for _, step in ipairs(tutorialSteps) do
        actions[step.key] = true
    end
    return actions
end

local function copyTutorial(tutorial)
    local source = tutorial or {}
    return {
        active = source.active == true,
        completed = source.completed ~= false,
        actions = copySet(source.actions or (source.completed == false and {} or completedTutorialActions())),
        realSpawnX = source.realSpawnX or 0,
        realSpawnY = source.realSpawnY or 0,
        realSpawnZ = source.realSpawnZ or 0,
    }
end

local function recipeUnlockedDefaults()
    local result = {}
    for key, recipe in pairs(Defs.recipes) do
        result[key] = recipe.default == true
    end
    return result
end

local function defaultSupplyContracts()
    return {
        { id = "iron_supply", item = "iron_plate", target = 5, delivered = 0, complete = false },
        { id = "science_supply", item = "science_pack", target = 3, delivered = 0, complete = false },
        { id = "drone_supply", item = "logistic_drone", target = 1, delivered = 0, complete = false },
    }
end

local function copyContracts(contracts)
    local result = {}
    for _, contract in ipairs(contracts or {}) do
        result[#result + 1] = {
            id = contract.id,
            item = contract.item,
            target = contract.target or 0,
            delivered = contract.delivered or 0,
            complete = contract.complete == true,
        }
    end
    return result
end

local function copyOutpostRoutes(routes)
    local result = {}
    for _, route in ipairs(routes or {}) do
        result[#result + 1] = {
            biome = route.biome,
            deliveredInWindow = route.deliveredInWindow or 0,
            requiredPerWindow = route.requiredPerWindow or 2,
            stability = route.stability or 0,
            windowStartTick = route.windowStartTick or 0,
            lastDeliveryTick = route.lastDeliveryTick or 0,
        }
    end
    return result
end

local function copyRiftStorm(storm)
    local source = storm or {}
    return {
        severity = source.severity or 0,
        ticksRemaining = source.ticksRemaining or 0,
        cooldownTicks = source.cooldownTicks or 0,
    }
end

local function copyGhostBuilds(ghosts)
    local result = {}
    for _, ghost in ipairs(ghosts or {}) do
        result[#result + 1] = {
            id = ghost.id,
            item = ghost.item,
            machine = ghost.machine == true,
            tile = ghost.tile,
            x = ghost.x,
            y = ghost.y,
            z = ghost.z or 0,
            direction = ghost.direction or "south",
            fulfilled = ghost.fulfilled == true,
            progress = ghost.progress or 0,
            blockedReason = ghost.blockedReason,
        }
    end
    return result
end

local function newMachine(id, kind, x, y, direction, z)
    return {
        id = id,
        kind = kind,
        x = x,
        y = y,
        z = z or 0,
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
        requestItem = nil,
        requestThreshold = 0,
        socketedRelic = nil,
        durability = machineMaxDurability(kind),
        status = "idle",
    }
end

local function newEntity(id, kind, x, y, z, hp)
    return {
        id = id,
        kind = kind,
        x = x,
        y = y,
        z = z or 0,
        hp = hp or 3,
        attackCooldown = 0,
        pressureSpawn = false,
    }
end

function Simulation.new(seed, startInTutorial)
    local self = setmetatable({
        seed = seed or 1,
        tick = 0,
        gameMode = "survival",
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
            inBoat = false,
        },
        machines = {},
        machineByCell = {},
        machineByIdIndex = {},
        nextMachineId = 1,
        entities = {},
        nextEntityId = 1,
        commandQueue = {},
        unlockedRecipes = recipeUnlockedDefaults(),
        completedTechs = {},
        activeTech = "logistics_1",
        researchProgress = 0,
        powerNetworks = {},
        poweredMachineIds = {},
        powerDirty = true,
        logisticDirty = true,
        logisticIndex = { providerIds = {}, requesterIds = {}, portIds = {} },
        logisticJobs = {},
        nextLogisticJobId = 1,
        ghostBuilds = {},
        nextGhostId = 1,
        supplyContracts = defaultSupplyContracts(),
        outpostRoutes = {},
        riftStorm = { severity = 0, ticksRemaining = 0, cooldownTicks = 0 },
        unlockedAchievements = {},
        unlockedAchievementSet = {},
        tutorial = {
            active = false,
            completed = true,
            actions = completedTutorialActions(),
            realSpawnX = 0,
            realSpawnY = 0,
            realSpawnZ = 0,
        },
        productionTotals = {
            iron_plate = 0,
            copper_plate = 0,
            science_pack = 0,
            advanced_science_pack = 0,
            water_barrel = 0,
            train_deliveries = 0,
            powered_ore = 0,
            logistic_deliveries = 0,
            archive_signals = 0,
            rift_jumps = 0,
            rift_storms_triggered = 0,
            rift_storms_survived = 0,
            outposts_activated = 0,
            outpost_deliveries = 0,
            scout_dispatches = 0,
            scout_materials_recovered = 0,
            pressure_waves_repelled = 0,
            pressure_enemies_defeated = 0,
            pressure_wave_rewards_claimed = 0,
            scrap_recovered = 0,
            scrap_recycled = 0,
            dungeon_chests_opened = 0,
            creatures_defeated = 0,
            bosses_defeated = 0,
            boss_relics_claimed = 0,
        },
    }, Simulation)
    if startInTutorial then
        self:beginTutorial()
    end
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

function Simulation.commands.placeGhost(direction, item, orientation)
    return { type = "place_ghost", direction = direction, item = item, orientation = orientation or direction }
end

function Simulation.commands.cancelGhost(direction)
    return { type = "cancel_ghost", direction = direction }
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

function Simulation.commands.configureRequest(machineId, requestItem, threshold)
    return { type = "configure_request", machineId = machineId, requestItem = requestItem, threshold = threshold or 0 }
end

function Simulation.commands.submitSupplyContract(contractId)
    return { type = "submit_supply_contract", contractId = contractId }
end

function Simulation.commands.damagePlayer(amount)
    return { type = "damage_player", amount = amount or 0 }
end

function Simulation.commands.healPlayer(amount)
    return { type = "heal_player", amount = amount or 0 }
end

function Simulation.commands.attack(direction)
    return { type = "attack", direction = direction }
end

function Simulation.commands.summonBoss(direction)
    return { type = "summon_boss", direction = direction }
end

function Simulation.commands.socketRelic(machineId, item)
    return { type = "socket_relic", machineId = machineId, item = item }
end

function Simulation.commands.selectArchiveChoice(machineId, choiceIndex)
    return { type = "select_archive_choice", machineId = machineId, choiceIndex = choiceIndex }
end

function Simulation.commands.togglePlanningMode()
    return { type = "toggle_planning_mode" }
end

function Simulation:queue(command)
    self.commandQueue[#self.commandQueue + 1] = command
end

function Simulation:step()
    self:ensureLocalEntities()
    local queue = self.commandQueue
    self.commandQueue = {}
    for _, command in ipairs(queue) do
        self:apply(command)
    end
    self:updateMachines()
    self:updateRiftStorms()
    self:ensureFactoryPressureEntity()
    self:updateEntities()
    self:updateAchievements()
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
    if self:isPlanningMode() then
        return true
    end
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
    return self.machineByCell[Grid.key(x, y, z or 0)]
end

function Simulation:machineById(id)
    return self.machineByIdIndex[id]
end

function Simulation:rebuildMachineIndexes()
    self.machineByCell = {}
    self.machineByIdIndex = {}
    for _, machine in ipairs(self.machines) do
        self.machineByCell[Grid.key(machine.x, machine.y, machine.z or 0)] = machine
        self.machineByIdIndex[machine.id] = machine
    end
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
    if self:machineAt(x, y, z or 0) then
        return false
    end
    local tile = self.world:getTile(x, y, z or 0)
    if Defs.tile(tile.id).walkable == true then
        return true
    end
    return (tile.id == "water" or tile.id == "deep_water") and self:itemCount("boat") > 0
end

function Simulation:addMachine(kind, x, y, direction, z)
    local machine = newMachine(self.nextMachineId, kind, x, y, direction, z)
    self.nextMachineId = self.nextMachineId + 1
    self.machines[#self.machines + 1] = machine
    table.sort(self.machines, function(a, b)
        return a.id < b.id
    end)
    self:rebuildMachineIndexes()
    self.powerDirty = true
    self.logisticDirty = true
    return machine
end

function Simulation:removeMachineById(id)
    for index, machine in ipairs(self.machines) do
        if machine.id == id then
            table.remove(self.machines, index)
            self:rebuildMachineIndexes()
            self.powerDirty = true
            self.logisticDirty = true
            return true
        end
    end
    return false
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
        if self:move(command.direction) then
            self:recordTutorialAction("move")
        end
        return
    end
    if command.type == "mine" then
        if self:mine(command.direction) then
            self:recordTutorialAction("mine")
        end
        return
    end
    if command.type == "place" then
        if self:place(command.direction, command.item, command.orientation) then
            self:recordTutorialAction("place")
        end
        return
    end
    if command.type == "place_ghost" then
        self:placeGhost(command.direction, command.item, command.orientation)
        return
    end
    if command.type == "cancel_ghost" then
        self:cancelGhost(command.direction)
        return
    end
    if command.type == "craft" then
        if self:craft(command.recipeKey) then
            self:recordTutorialAction("craft")
        end
        return
    end
    if command.type == "deposit" then
        if self:deposit(command.direction, command.item) then
            self:recordTutorialAction("deposit")
        end
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
        if self:depositToMachine(command.machineId, command.item, command.count) then
            self:recordTutorialAction("deposit")
        end
        return
    end
    if command.type == "withdraw_machine" then
        self:withdrawFromMachine(command.machineId, command.item, command.count)
        return
    end
    if command.type == "configure_circuit" then
        self:configureCircuit(command.machineId, command.filterItem, command.comparator, command.threshold)
        return
    end
    if command.type == "configure_request" then
        self:configureRequest(command.machineId, command.requestItem, command.threshold)
        return
    end
    if command.type == "submit_supply_contract" then
        self:submitSupplyContract(command.contractId)
        return
    end
    if command.type == "damage_player" then
        self:damagePlayer(command.amount)
        return
    end
    if command.type == "heal_player" then
        self:healPlayer(command.amount)
        return
    end
    if command.type == "attack" then
        self:attack(command.direction)
        return
    end
    if command.type == "summon_boss" then
        self:trySummonBoss(command.direction)
        return
    end
    if command.type == "socket_relic" then
        self:socketRelic(command.machineId, command.item)
        return
    end
    if command.type == "select_archive_choice" then
        self:selectArchiveChoice(command.machineId, command.choiceIndex)
        return
    end
    if command.type == "toggle_planning_mode" then
        self:togglePlanningMode()
    end
end

function Simulation:isPlanningMode()
    return self.gameMode == "planning"
end

function Simulation:togglePlanningMode()
    self.gameMode = self:isPlanningMode() and "survival" or "planning"
    return self.gameMode
end

function Simulation:gameModeText()
    return "mode: " .. self.gameMode
end

function Simulation:damagePlayer(amount)
    self.player.hp = math.max(0, self.player.hp - math.max(0, amount or 0))
    return self.player.hp
end

function Simulation:healPlayer(amount)
    self.player.hp = math.min(20, self.player.hp + math.max(0, amount or 0))
    return self.player.hp
end

function Simulation:addEntity(kind, x, y, z, hp)
    local entity = newEntity(self.nextEntityId, kind, x, y, z or 0, hp or self:entityMaxHp(kind))
    self.nextEntityId = self.nextEntityId + 1
    self.entities[#self.entities + 1] = entity
    table.sort(self.entities, function(a, b)
        return a.id < b.id
    end)
    return entity
end

function Simulation:entityAt(x, y, z)
    for _, entity in ipairs(self.entities) do
        if entity.x == x and entity.y == y and (entity.z or 0) == (z or 0) then
            return entity
        end
    end
    return nil
end

function Simulation:removeEntityById(id)
    for index, entity in ipairs(self.entities) do
        if entity.id == id then
            table.remove(self.entities, index)
            return true
        end
    end
    return false
end

function Simulation:damageEntity(entity, amount)
    if not entity then
        return false
    end
    entity.hp = math.max(0, entity.hp - math.max(0, amount or 0))
    if entity.hp <= 0 then
        self:defeatEntity(entity)
    end
    return true
end

function Simulation:entityDrop(kind)
    local def = entityDefs[kind]
    return def and def.drop or nil
end

function Simulation:defeatEntity(entity)
    local drop = self:entityDrop(entity.kind)
    if drop then
        self:addItem(drop, 1)
    end
    if entity.pressureSpawn then
        self.productionTotals.pressure_enemies_defeated = (self.productionTotals.pressure_enemies_defeated or 0) + 1
        self.productionTotals.scrap_recovered = (self.productionTotals.scrap_recovered or 0) + 1
        self:addItem("scrap", 1)
        if self.productionTotals.pressure_enemies_defeated % 3 == 0 then
            local reward = self:factoryPressureLevel() >= 220 and "advanced_science_pack" or "science_pack"
            self.productionTotals[reward] = (self.productionTotals[reward] or 0) + 1
            self.productionTotals.pressure_wave_rewards_claimed = (self.productionTotals.pressure_wave_rewards_claimed or 0) + 1
            self:addItem(reward, 1)
        end
    end
    for _, recipeKey in ipairs((entityDefs[entity.kind] and entityDefs[entity.kind].unlocks) or {}) do
        self.unlockedRecipes[recipeKey] = true
    end
    self.productionTotals.creatures_defeated = (self.productionTotals.creatures_defeated or 0) + 1
    if self:isBossKind(entity.kind) then
        self.productionTotals.bosses_defeated = (self.productionTotals.bosses_defeated or 0) + 1
        self.productionTotals.boss_relics_claimed = (self.productionTotals.boss_relics_claimed or 0) + 1
    end
    return self:removeEntityById(entity.id)
end

function Simulation:playerAttackDamage(entity)
    if entity.kind == "glass_maw" and (self.productionTotals.pressure_waves_repelled or 0) == 0 and self.tick % 80 < 40 then
        return 1
    end
    if self:isBossKind(entity.kind) then
        return 2
    end
    return 1
end

function Simulation:attack(direction)
    direction = direction or self.player.facing
    self.player.facing = direction
    local x, y = Grid.front(self.player.x, self.player.y, direction)
    local entity = self:entityAt(x, y, self.player.z)
    return self:damageEntity(entity, entity and self:playerAttackDamage(entity) or 0)
end

function Simulation:isHostileEntity(entity)
    local def = entityDefs[entity.kind]
    return def == nil or def.hostile == true
end

function Simulation:entityMaxHp(kind)
    local def = entityDefs[kind]
    return def and def.hp or 3
end

function Simulation:isBossKind(kind)
    local def = entityDefs[kind]
    return def and def.boss == true
end

function Simulation:entityAttackDamage(entity)
    if entity.kind == "slime" then
        return 1
    end
    return 1
end

function Simulation:updateBossPhases()
    if self.tick == 0 then
        return
    end
    local spawns = {}
    local frostPulses = {}
    for _, entity in ipairs(self.entities) do
        if (entity.z or 0) == self.player.z then
            if entity.kind == "marsh_broodheart" and entity.hp <= math.floor(self:entityMaxHp(entity.kind) / 2) and self.tick % 90 == 0 then
                spawns[#spawns + 1] = { x = entity.x, y = entity.y, z = entity.z or 0, kind = "slime", range = 3 }
            elseif entity.kind == "frost_nullifier" and self.tick % 120 == 0 then
                frostPulses[#frostPulses + 1] = { x = entity.x, y = entity.y, z = entity.z or 0 }
            elseif entity.kind == "rift_signal_tyrant" and (self.productionTotals.outposts_activated or 0) < 5 and self.tick % 90 == 0 then
                spawns[#spawns + 1] = { x = entity.x, y = entity.y, z = entity.z or 0, kind = "rift_stalker", range = 3 }
            end
        end
    end
    for _, pulse in ipairs(frostPulses) do
        for _, machine in ipairs(self.machines) do
            if (machine.z or 0) == pulse.z and Grid.manhattan(machine.x, machine.y, pulse.x, pulse.y) <= 3 then
                machine.progress = 0
                machine.status = "missing_power"
            end
        end
    end
    for _, spawn in ipairs(spawns) do
        self:spawnEntityNear(spawn.x, spawn.y, spawn.z, spawn.kind, spawn.range)
    end
end

function Simulation:updateEntities()
    self:updateBossPhases()
    for _, entity in ipairs(self.entities) do
        if entity.attackCooldown > 0 then
            entity.attackCooldown = entity.attackCooldown - 1
        end
        if self:isHostileEntity(entity) then
            if (entity.z or 0) == self.player.z and Grid.manhattan(entity.x, entity.y, self.player.x, self.player.y) <= 1 and entity.attackCooldown <= 0 then
                self:damagePlayer(self:entityAttackDamage(entity))
                entity.attackCooldown = 30
            elseif entity.attackCooldown <= 0 and self:damageAdjacentStructure(entity, self:isBossKind(entity.kind) and 2 or 1) then
                entity.attackCooldown = 45
            else
                self:moveEntityTowardTarget(entity)
            end
        end
    end
end

function Simulation:entityTarget(entity)
    local target = { x = self.player.x, y = self.player.y, z = self.player.z }
    local bestDistance = (entity.z or 0) == self.player.z and Grid.manhattan(entity.x, entity.y, self.player.x, self.player.y) or math.huge
    for _, machine in ipairs(self.machines) do
        if (machine.z or 0) == (entity.z or 0) then
            local distance = Grid.manhattan(entity.x, entity.y, machine.x, machine.y)
            if distance < bestDistance then
                bestDistance = distance
                target = { x = machine.x, y = machine.y, z = machine.z or 0 }
            end
        end
    end
    return target
end

function Simulation:entityCanMoveTo(entity, x, y)
    if not self.world:isWalkable(x, y, entity.z or 0) or self:machineAt(x, y, entity.z or 0) then
        return false
    end
    return self:entityAt(x, y, entity.z or 0) == nil
end

function Simulation:moveEntityTowardTarget(entity)
    local target = self:entityTarget(entity)
    if target.z ~= (entity.z or 0) or Grid.manhattan(entity.x, entity.y, target.x, target.y) <= 1 then
        return false
    end
    local candidates = {}
    if math.abs(target.x - entity.x) >= math.abs(target.y - entity.y) then
        candidates[#candidates + 1] = { x = entity.x + (target.x > entity.x and 1 or -1), y = entity.y }
        candidates[#candidates + 1] = { x = entity.x, y = entity.y + (target.y > entity.y and 1 or -1) }
    else
        candidates[#candidates + 1] = { x = entity.x, y = entity.y + (target.y > entity.y and 1 or -1) }
        candidates[#candidates + 1] = { x = entity.x + (target.x > entity.x and 1 or -1), y = entity.y }
    end
    for _, candidate in ipairs(candidates) do
        if self:entityCanMoveTo(entity, candidate.x, candidate.y) then
            entity.x = candidate.x
            entity.y = candidate.y
            return true
        end
    end
    return false
end

function Simulation:damageMachine(machine, amount)
    machine.durability = (machine.durability or machineMaxDurability(machine.kind)) - amount
    if machine.durability <= 0 then
        return self:removeMachineById(machine.id)
    end
    return true
end

function Simulation:damageStructureAt(x, y, z, amount)
    local machine = self:machineAt(x, y, z)
    if machine then
        return self:damageMachine(machine, amount)
    end
    local tile = self.world:getTile(x, y, z or 0)
    local maxDurability = tileMaxDurability(tile.id)
    if maxDurability <= 0 then
        return false
    end
    local durability = (tile.data and tile.data > 0 and tile.data or maxDurability) - amount
    if durability <= 0 then
        self.world:setTile(x, y, z or 0, { id = (z or 0) < 0 and "dungeon_floor" or "grass", data = 0 })
    else
        self.world:setTile(x, y, z or 0, { id = tile.id, data = durability })
    end
    return true
end

function Simulation:damageAdjacentStructure(entity, amount)
    for _, direction in ipairs(Grid.order) do
        local x, y = Grid.front(entity.x, entity.y, direction)
        if self:damageStructureAt(x, y, entity.z or 0, amount) then
            return true
        end
    end
    return false
end

function Simulation:repairMachine(machine)
    local maxDurability = machineMaxDurability(machine.kind)
    if (machine.durability or maxDurability) >= maxDurability then
        return false
    end
    machine.durability = maxDurability
    return true
end

function Simulation:repairTileAt(x, y, z)
    local tile = self.world:getTile(x, y, z or 0)
    local maxDurability = tileMaxDurability(tile.id)
    if maxDurability <= 0 or tile.data <= 0 or tile.data >= maxDurability then
        return false
    end
    self.world:setTile(x, y, z or 0, { id = tile.id, data = maxDurability })
    return true
end

function Simulation:repairPylonTarget(machine)
    for _, direction in ipairs(Grid.order) do
        local x, y = Grid.front(machine.x, machine.y, direction)
        local target = self:machineAt(x, y, machine.z or 0)
        if target and target.id ~= machine.id and (target.durability or machineMaxDurability(target.kind)) < machineMaxDurability(target.kind) then
            return { kind = "machine", machineId = target.id, x = x, y = y, z = machine.z or 0, material = "iron_plate" }
        end
    end
    for _, direction in ipairs(Grid.order) do
        local x, y = Grid.front(machine.x, machine.y, direction)
        if not self:machineAt(x, y, machine.z or 0) and not self:entityAt(x, y, machine.z or 0) then
            local tile = self.world:getTile(x, y, machine.z or 0)
            local maxDurability = tileMaxDurability(tile.id)
            if isDamageableStructureTile(tile.id) and tile.data > 0 and tile.data < maxDurability then
                return { kind = "tile", x = x, y = y, z = machine.z or 0, tile = tile.id, material = repairMaterialForTile(tile.id) }
            end
        end
    end
    for _, direction in ipairs(Grid.order) do
        local x, y = Grid.front(machine.x, machine.y, direction)
        if not self:machineAt(x, y, machine.z or 0) and not self:entityAt(x, y, machine.z or 0) then
            local tile = self.world:getTile(x, y, machine.z or 0)
            if isRepairableWallGap(tile.id) then
                return { kind = "gap", x = x, y = y, z = machine.z or 0, material = machine.inventory:count("wall") > 0 and "wall" or "plank_wall" }
            end
        end
    end
    return nil
end

function Simulation:spawnEntityNear(x, y, z, kind, range)
    if #self.entities >= 80 then
        return false
    end
    range = range or 1
    for radius = 1, range do
        for oy = -radius, radius do
            for ox = -radius, radius do
                if math.abs(ox) + math.abs(oy) == radius then
                    local sx = x + ox
                    local sy = y + oy
                    if not (sx == self.player.x and sy == self.player.y and (z or 0) == self.player.z)
                        and not self:machineAt(sx, sy, z or 0)
                        and not self:entityAt(sx, sy, z or 0)
                        and self.world:isWalkable(sx, sy, z or 0) then
                        local entity = self:addEntity(kind, sx, sy, z or 0)
                        entity.attackCooldown = 20
                        return true
                    end
                end
            end
        end
    end
    return false
end

function Simulation:bossSummonDefAt(x, y, z)
    z = z or 0
    if self.world:getTile(x, y, z).id ~= "stairs_down" then
        return nil
    end
    local lair = self.world:lairAt(x, y, z)
    local def = lair and bossSummonDefsByLair[lair] or nil
    if not def or self.world:biomeAt(x, y, z) ~= def.biome then
        return nil
    end
    return def, lair
end

function Simulation:hasEntityKind(kind)
    for _, entity in ipairs(self.entities) do
        if entity.kind == kind then
            return true
        end
    end
    return false
end

function Simulation:trySummonBossAt(x, y, z)
    local def, lair = self:bossSummonDefAt(x, y, z)
    if not def then
        return false
    end
    if self:hasEntityKind(def.kind) then
        return true
    end
    if not self:bossExamComplete(def.kind) then
        return false
    end
    local sx, sy = self:bossSpawnCell(x, y, z, lair)
    if not sx or not self:canConsumeCost(def.cost) then
        return false
    end
    self:consumeCost(def.cost)
    local boss = self:addEntity(def.kind, sx, sy, z or 0)
    boss.attackCooldown = 40
    return true
end

function Simulation:bossSpawnCell(x, y, z, lair)
    for _, offset in ipairs(bossSummonOffsets) do
        local sx = x + offset[1]
        local sy = y + offset[2]
        if self.world:lairAt(sx, sy, z or 0) == lair
            and self.world:isWalkable(sx, sy, z or 0)
            and not self:entityAt(sx, sy, z or 0)
            and not self:machineAt(sx, sy, z or 0) then
            return sx, sy
        end
    end
    return nil, nil
end

function Simulation:canConsumeCost(cost)
    for item, count in pairs(cost or {}) do
        if self:itemCount(item) < count then
            return false
        end
    end
    return true
end

function Simulation:consumeCost(cost)
    for item, count in pairs(cost or {}) do
        self:consumeItem(item, count)
    end
    return true
end

function Simulation:bossExamCurrent(kind)
    local exam = bossExamDefs[kind]
    if not exam then
        return 0
    end
    if exam.rift then
        return ((self.productionTotals.archive_signals or 0) > 0 and 1 or 0)
            + ((self.productionTotals.rift_jumps or 0) > 0 and 1 or 0)
            + math.min(3, self.productionTotals.outposts_activated or 0)
    end
    if exam.item then
        return self:anyItemCount(exam.item)
    end
    return self.productionTotals[exam.production] or 0
end

function Simulation:bossExamComplete(kind)
    local exam = bossExamDefs[kind]
    return not exam or self:bossExamCurrent(kind) >= exam.required
end

function Simulation:bossExamProgress()
    local progress = {}
    for _, kind in ipairs({ "marsh_broodheart", "glass_maw", "badlands_warden", "frost_nullifier", "rift_signal_tyrant" }) do
        local exam = bossExamDefs[kind]
        progress[#progress + 1] = {
            kind = kind,
            current = self:bossExamCurrent(kind),
            required = exam.required,
            complete = self:bossExamComplete(kind),
        }
    end
    return progress
end

function Simulation:trySummonBoss(direction)
    direction = direction or self.player.facing
    self.player.facing = direction
    local x, y = Grid.front(self.player.x, self.player.y, direction)
    return self:trySummonBossAt(x, y, self.player.z)
end

function Simulation:canSocketRelic(kind, item)
    local rules = relicSocketRules[kind]
    return rules and rules[item] == true
end

function Simulation:socketRelic(machineId, item)
    local machine = self:machineById(machineId)
    if not machine or machine.socketedRelic or not self:canSocketRelic(machine.kind, item) then
        return false
    end
    if not self:consumeItem(item, 1) then
        return false
    end
    machine.socketedRelic = item
    return true
end

function Simulation:localEntityKindForTile(x, y, z)
    z = z or 0
    if z == tutorialLayer or not self.world:isWalkable(x, y, z) then
        return nil
    end
    local roll = Rng.hash(self.seed + 16001, x + z * 8192, y, z)
    if z < 0 then
        if roll % 1000 >= 70 then
            return nil
        end
        local kindRoll = math.floor(roll / 65536) % 100
        if kindRoll < 45 then
            return "slime"
        end
        if kindRoll < 78 then
            return "skeleton"
        end
        if kindRoll < 95 then
            return "cave_crawler"
        end
        return "dungeon_sentinel"
    end
    local biome = self.world:biomeAt(x, y, z)
    local kinds = biomeEnemyKinds[biome]
    if not kinds or roll % 1000 >= 120 then
        return nil
    end
    return kinds[(math.floor(roll / 4096) % #kinds) + 1]
end

function Simulation:ensureLocalEntities()
    if #self.entities >= 80 or self.player.z == tutorialLayer then
        return
    end
    if #self.entities > 0 and self.player.z >= 0 then
        return
    end
    local playerBiome = self.world:biomeAt(self.player.x, self.player.y, self.player.z)
    if self.player.z >= 0 and playerBiome == "grassland" then
        return
    end
    local radius = 9
    for y = self.player.y - radius, self.player.y + radius do
        for x = self.player.x - radius, self.player.x + radius do
            if #self.entities >= 80 then
                return
            end
            local canTry = not (x == self.player.x and y == self.player.y)
            if canTry and self.player.z >= 0 and self.world:biomeAt(x, y, self.player.z) ~= playerBiome then
                canTry = false
            end
            if canTry and (self:machineAt(x, y, self.player.z) or self:entityAt(x, y, self.player.z)) then
                canTry = false
            end
            if canTry then
                local kind = self:localEntityKindForTile(x, y, self.player.z)
                if kind then
                    local entity = self:addEntity(kind, x, y, self.player.z)
                    entity.attackCooldown = 20
                end
            end
        end
    end
end

function Simulation:move(direction)
    direction = direction or self.player.facing
    self.player.facing = direction
    local x, y = Grid.front(self.player.x, self.player.y, direction)
    if self.player.z == tutorialLayer and x == 5 and y == 0 and self:tutorialExitReady() then
        self:completeTutorial()
        return true
    end
    local targetTile = self.world:getTile(x, y, self.player.z)
    if self.player.z == tutorialLayer and targetTile.id == "stairs_down" then
        return false
    end
    if not self:machineAt(x, y, self.player.z) and targetTile.id == "stairs_down" then
        self.player.x = x
        self.player.y = y
        self.player.z = self.player.z - 1
        self.player.inBoat = false
        return true
    end
    if not self:machineAt(x, y, self.player.z) and targetTile.id == "stairs_up" then
        self.player.x = x
        self.player.y = y
        self.player.z = self.player.z + 1
        self.player.inBoat = false
        return true
    end
    if self:isWalkable(x, y, self.player.z) then
        self.player.x = x
        self.player.y = y
        local tile = self.world:getTile(x, y, self.player.z)
        self.player.inBoat = tile.id == "water" or tile.id == "deep_water"
        return true
    end
    return false
end

function Simulation:mine(direction)
    direction = direction or self.player.facing
    self.player.facing = direction
    local x, y = Grid.front(self.player.x, self.player.y, direction)
    local z = self.player.z or 0
    local tile = self.world:getTile(x, y, z)
    local drop = self.world:mineTile(x, y, self.player.z)
    if drop then
        self:addItem(drop, 1)
        if tile.id == "recovery_crate" and (z < 0 or self.world:lairAt(x, y, z)) then
            self.productionTotals.dungeon_chests_opened = (self.productionTotals.dungeon_chests_opened or 0) + 1
            if z < 0 then
                self.world:setTile(x, y, z, { id = "dungeon_floor", data = 0 })
            end
        end
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
        self:addMachine(itemDef.machine, x, y, orientation or direction, self.player.z)
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

function Simulation:placeGhost(direction, item, orientation)
    if not item then
        return false
    end
    direction = direction or self.player.facing
    self.player.facing = direction
    local itemDef = Defs.item(item)
    if not itemDef or (not itemDef.machine and not itemDef.tile) then
        return false
    end
    local x, y = Grid.front(self.player.x, self.player.y, direction)
    local z = self.player.z or 0
    for _, ghost in ipairs(self.ghostBuilds) do
        if not ghost.fulfilled and ghost.x == x and ghost.y == y and (ghost.z or 0) == z then
            return false
        end
    end
    local blockedReason = self:ghostBlockedReason(itemDef, x, y, z)
    self.ghostBuilds[#self.ghostBuilds + 1] = {
        id = self.nextGhostId,
        item = item,
        machine = itemDef.machine ~= nil,
        tile = itemDef.tile,
        x = x,
        y = y,
        z = z,
        direction = orientation or direction,
        fulfilled = false,
        progress = 0,
        blockedReason = blockedReason,
    }
    self.nextGhostId = self.nextGhostId + 1
    return true
end

function Simulation:ghostBlockedReason(itemDef, x, y, z)
    if self:machineAt(x, y, z) then
        return "machine"
    end
    if itemDef.machine then
        return self:canPlaceMachine(itemDef.machine, x, y, z) and nil or "terrain"
    end
    if itemDef.tile then
        local tile = self.world:getTile(x, y, z)
        local tileDef = Defs.tile(tile.id)
        return tileDef.buildable and nil or "terrain"
    end
    return "item"
end

function Simulation:cancelGhost(direction)
    direction = direction or self.player.facing
    self.player.facing = direction
    local x, y = Grid.front(self.player.x, self.player.y, direction)
    local z = self.player.z or 0
    for index = #self.ghostBuilds, 1, -1 do
        local ghost = self.ghostBuilds[index]
        if not ghost.fulfilled and ghost.x == x and ghost.y == y and (ghost.z or 0) == z then
            table.remove(self.ghostBuilds, index)
            return true
        end
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
    local planning = self:isPlanningMode()
    if recipe.station == "workbench" and not planning and not self:hasAdjacentWorkbench() then
        return false
    end
    if recipe.station ~= "hand" and recipe.station ~= "workbench" then
        return false
    end
    if not planning and not self.player.inventory:consumeAll(recipe.inputs) then
        return false
    end
    self:addItem(recipe.output.item, recipe.output.count)
    if not planning and (recipe.inputs.scrap or 0) > 0 then
        self.productionTotals.scrap_recycled = (self.productionTotals.scrap_recycled or 0) + recipe.inputs.scrap
    end
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
    if not machine or not Defs.machineRecipe(machine.kind, recipeKey) or not self:isRecipeUnlocked(recipeKey) then
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

function Simulation:configureRequest(machineId, requestItem, threshold)
    local machine = self:machineById(machineId)
    if not machine or machine.kind ~= "requester_chest" then
        return false
    end
    machine.requestItem = Defs.item(requestItem) and requestItem or nil
    machine.requestThreshold = machine.requestItem and math.max(0, tonumber(threshold) or 0) or 0
    return true
end

function Simulation:supplyContract(contractId)
    for _, contract in ipairs(self.supplyContracts) do
        if contract.id == contractId then
            return contract
        end
    end
    return nil
end

function Simulation:submitSupplyContract(contractId)
    local contract = self:supplyContract(contractId)
    if not contract or contract.complete then
        return false
    end
    local remaining = math.max(0, contract.target - contract.delivered)
    local available = self:itemCount(contract.item)
    local moved = math.min(remaining, available)
    if moved <= 0 or not self.player.inventory:consume(contract.item, moved) then
        return false
    end
    contract.delivered = contract.delivered + moved
    contract.complete = contract.delivered >= contract.target
    return true
end

function Simulation:completedSupplyContracts()
    local completed = 0
    for _, contract in ipairs(self.supplyContracts) do
        if contract.complete then
            completed = completed + 1
        end
    end
    return completed
end

function Simulation:markActivatedOutpostBiome(biome)
    self.productionTotals[outpostBiomeKey("outpost_activated", biome)] = 1
end

function Simulation:hasActivatedOutpostBiome(biome)
    return (self.productionTotals[outpostBiomeKey("outpost_activated", biome)] or 0) > 0
end

function Simulation:activatedOutpostBiomeCount()
    local count = 0
    for _, biome in ipairs(requiredOutpostBiomes) do
        if self:hasActivatedOutpostBiome(biome) then
            count = count + 1
        end
    end
    return count
end

function Simulation:activatedOutpostBiomes()
    local biomes = {}
    for _, biome in ipairs(requiredOutpostBiomes) do
        if self:hasActivatedOutpostBiome(biome) then
            biomes[#biomes + 1] = biome
        end
    end
    return biomes
end

function Simulation:markCompletedOutpostDeliveryBiome(biome)
    self.productionTotals[outpostBiomeKey("outpost_delivery", biome)] = 1
end

function Simulation:hasCompletedOutpostDeliveryBiome(biome)
    return (self.productionTotals[outpostBiomeKey("outpost_delivery", biome)] or 0) > 0
end

function Simulation:outpostDeliveryBiomeCount()
    local count = 0
    for _, biome in ipairs(requiredOutpostBiomes) do
        if self:hasCompletedOutpostDeliveryBiome(biome) then
            count = count + 1
        end
    end
    return count
end

function Simulation:outpostRouteByBiome(biome)
    for _, route in ipairs(self.outpostRoutes) do
        if route.biome == biome then
            return route
        end
    end
    return nil
end

function Simulation:outpostRouteForBiome(biome)
    local existing = self:outpostRouteByBiome(biome)
    if existing then
        return existing
    end
    local route = {
        biome = biome,
        deliveredInWindow = 0,
        requiredPerWindow = 2,
        stability = 0,
        windowStartTick = self.tick,
        lastDeliveryTick = 0,
    }
    self.outpostRoutes[#self.outpostRoutes + 1] = route
    return route
end

function Simulation:outpostRoutesProgress()
    local routes = {}
    for _, biome in ipairs(requiredOutpostBiomes) do
        local route = self:outpostRouteByBiome(biome) or { deliveredInWindow = 0, requiredPerWindow = 2, stability = 0 }
        routes[#routes + 1] = {
            biome = biome,
            current = route.deliveredInWindow,
            required = route.requiredPerWindow,
            stability = route.stability,
            active = self:hasActivatedOutpostBiome(biome),
            stable = route.stability >= outpostRouteStableThreshold,
        }
    end
    return routes
end

function Simulation:outpostRouteStability(biome)
    local route = self:outpostRouteByBiome(biome)
    return route and route.stability or 0
end

function Simulation:stableOutpostRouteCount()
    local count = 0
    for _, route in ipairs(self:outpostRoutesProgress()) do
        if route.stable then
            count = count + 1
        end
    end
    return count
end

function Simulation:outpostRouteText()
    for _, route in ipairs(self:outpostRoutesProgress()) do
        if route.active and not route.stable then
            return "outpost route " .. route.biome .. ": " .. route.current .. "/" .. route.required .. " stability " .. route.stability
        end
    end
    return "outpost routes stable: " .. self:stableOutpostRouteCount() .. "/" .. #requiredOutpostBiomes
end

function Simulation:outpostDeliveryProgress()
    local progress = {}
    for _, biome in ipairs(requiredOutpostBiomes) do
        progress[#progress + 1] = {
            biome = biome,
            item = outpostActivationItem(biome),
            current = self:hasCompletedOutpostDeliveryBiome(biome) and 1 or 0,
            target = 1,
            active = self:hasActivatedOutpostBiome(biome),
            complete = self:hasCompletedOutpostDeliveryBiome(biome),
        }
    end
    return progress
end

function Simulation:completedOutpostDeliveryContracts()
    local completed = 0
    for _, delivery in ipairs(self:outpostDeliveryProgress()) do
        if delivery.complete then
            completed = completed + 1
        end
    end
    return completed
end

function Simulation:currentOutpostDeliveryText()
    for index, delivery in ipairs(self:outpostDeliveryProgress()) do
        if delivery.active and not delivery.complete then
            return "outpost delivery " .. index .. "/" .. #requiredOutpostBiomes .. ": " .. delivery.biome .. " " .. delivery.item
        end
    end
    return "outpost deliveries complete: all activated biomes supplied"
end

function Simulation:markScoutedBiome(biome)
    self.productionTotals[outpostBiomeKey("scouted", biome)] = 1
end

function Simulation:hasScoutedBiome(biome)
    return (self.productionTotals[outpostBiomeKey("scouted", biome)] or 0) > 0
end

function Simulation:scoutedBiomeCount()
    local count = 0
    for _, biome in ipairs(scoutBiomes) do
        if self:hasScoutedBiome(biome) then
            count = count + 1
        end
    end
    return count
end

function Simulation:scoutedBiomes()
    local biomes = {}
    for _, biome in ipairs(scoutBiomes) do
        if self:hasScoutedBiome(biome) then
            biomes[#biomes + 1] = biome
        end
    end
    return biomes
end

function Simulation:scoutTargetBiome(port)
    local localBiome = self.world:biomeAt(port.x, port.y, port.z or 0)
    if localBiome ~= "grassland" and (localBiome ~= "rift" or (self.productionTotals.rift_jumps or 0) > 0) and not self:hasScoutedBiome(localBiome) then
        return localBiome
    end
    for _, biome in ipairs(scoutBiomes) do
        if (biome ~= "rift" or (self.productionTotals.rift_jumps or 0) > 0) and not self:hasScoutedBiome(biome) then
            return biome
        end
    end
    local unlocked = (self.productionTotals.rift_jumps or 0) > 0 and #scoutBiomes or (#scoutBiomes - 1)
    return scoutBiomes[((math.floor(self.tick / scoutDispatchTicks) + port.id - 1) % unlocked) + 1]
end

function Simulation:scoutAutomationText()
    local count = self:scoutedBiomeCount() .. "/" .. #scoutBiomes
    for _, machine in ipairs(self.machines) do
        if machine.kind == "logistic_port" and self:isMachinePowered(machine.id) then
            if machine.progress > 0 and machine.carriedItem then
                local biome = scoutBiomeForReward(machine.carriedItem) or self:scoutTargetBiome(machine)
                return "scouts: dispatching " .. biome .. " " .. machine.progress .. "/" .. scoutDispatchTicks .. "; scouted " .. count
            end
            return "scouts: ready; next target " .. self:scoutTargetBiome(machine) .. "; scouted " .. count
        end
    end
    return "scouts: offline; scouted " .. count
end

function Simulation:totalSupplyContracts()
    return #self.supplyContracts
end

function Simulation:currentSupplyContractText()
    for index, contract in ipairs(self.supplyContracts) do
        if not contract.complete then
            local item = Defs.item(contract.item)
            local label = item and item.name or contract.item
            return "contract " .. index .. "/" .. #self.supplyContracts .. ": " .. label .. " " .. math.min(contract.delivered, contract.target) .. "/" .. contract.target
        end
    end
    return "contract complete: supply chain proved"
end

function Simulation:mainObjectiveComplete()
    return self:completedSupplyContracts() >= self:totalSupplyContracts() and self:isTechCompleted("logistic_network")
end

function Simulation:postVictoryExpeditionBoard()
    local unlocked = self:mainObjectiveComplete()
    local entries = {}
    local outpostDeliveries = self:outpostDeliveryProgress()
    local function add(key, label, current, required)
        entries[#entries + 1] = {
            key = key,
            label = label,
            current = current,
            required = required,
            unlocked = unlocked,
            complete = unlocked and current >= required,
        }
    end
    add("cartography", "Map every biome with automated scout dispatches", self:scoutedBiomeCount(), #scoutBiomes)
    add("relic_set", "Claim the full five-relic boss set", self.productionTotals.boss_relics_claimed or 0, 5)
    add("storm_veteran", "Survive three rift storms after opening the gate", self.productionTotals.rift_storms_survived or 0, 3)
    add("outpost_network", "Stabilize all sustained outpost delivery routes", self:stableOutpostRouteCount(), #outpostDeliveries)
    add("pressure_harvest", "Claim five pressure wave rewards", self.productionTotals.pressure_wave_rewards_claimed or 0, 5)
    add("lair_caches", "Open five dungeon or lair caches", self.productionTotals.dungeon_chests_opened or 0, 5)
    add("rift_freight", "Complete twenty train-stop cargo hops for remote freight", self.productionTotals.train_deliveries or 0, 20)
    add("scrap_economy", "Recycle ten scrap into useful factory plates", self.productionTotals.scrap_recycled or 0, 10)
    add("powered_industry", "Extract fifty resources with electric miners", self.productionTotals.powered_ore or 0, 50)
    return entries
end

function Simulation:completedPostVictoryExpeditions()
    local completed = 0
    for _, entry in ipairs(self:postVictoryExpeditionBoard()) do
        if entry.complete then
            completed = completed + 1
        end
    end
    return completed
end

function Simulation:postVictoryExpeditionText()
    local board = self:postVictoryExpeditionBoard()
    if #board == 0 or not board[1].unlocked then
        return "expedition board: locked until the main rift objective is complete"
    end
    for index, entry in ipairs(board) do
        if not entry.complete then
            return "expedition "
                .. index
                .. "/"
                .. #board
                .. ": "
                .. entry.label
                .. " ("
                .. math.min(entry.current, entry.required)
                .. "/"
                .. entry.required
                .. ")"
        end
    end
    return "expedition board complete"
end

function Simulation:machinePressureWeight(machine)
    return pressureWeights[machine.kind] or 0
end

function Simulation:factoryFootprintPressure()
    local total = 0
    for _, machine in ipairs(self.machines) do
        total = total + self:machinePressureWeight(machine)
    end
    return math.floor(total / 4)
end

function Simulation:factoryPressureLevel()
    local productionPressure = (self.productionTotals.iron_plate or 0)
        + (self.productionTotals.copper_plate or 0)
        + (self.productionTotals.science_pack or 0) * 12
        + (self.productionTotals.advanced_science_pack or 0) * 24
        + math.floor((self.productionTotals.powered_ore or 0) / 2)
        + (self.productionTotals.logistic_deliveries or 0) * 8
        + (self.productionTotals.archive_signals or 0) * 50
        + (self.productionTotals.rift_jumps or 0) * 80
    return math.max(0, productionPressure + self:factoryFootprintPressure() - (self.productionTotals.pressure_waves_repelled or 0) * 35)
end

function Simulation:factoryPressureText()
    local pressure = self:factoryPressureLevel()
    if pressure < 60 or (self.productionTotals.science_pack or 0) == 0 then
        return "pressure: quiet (" .. pressure .. ")"
    end
    if pressure < 120 then
        return "pressure: watched (" .. pressure .. ")"
    end
    if pressure < 220 then
        return "pressure: raids possible (" .. pressure .. ")"
    end
    return "pressure: hostile surge (" .. pressure .. ")"
end

function Simulation:pressureMitigationAt(x, y, z)
    local mitigation = 0
    for _, machine in ipairs(self.machines) do
        if machine.kind == "pressure_relay" and (machine.z or 0) == (z or 0) then
            local distance = Grid.manhattan(x, y, machine.x, machine.y)
            if distance <= 8 then
                mitigation = mitigation + (machine.socketedRelic == "glass_heart" and 32 or 20)
            end
        end
    end
    return mitigation
end

function Simulation:localPressureAt(x, y, z)
    local pressure = math.floor(self:factoryPressureLevel() / 8)
    for _, machine in ipairs(self.machines) do
        if (machine.z or 0) == (z or 0) then
            local weight = self:machinePressureWeight(machine)
            local distance = Grid.manhattan(x, y, machine.x, machine.y)
            if weight > 0 and distance <= 18 then
                pressure = pressure + math.max(0, weight - distance)
            end
        end
    end
    return math.max(0, pressure - self:pressureMitigationAt(x, y, z))
end

function Simulation:pressureHotspots()
    local hotspots = {}
    for _, machine in ipairs(self.machines) do
        if (machine.z or 0) == self.player.z and self:machinePressureWeight(machine) > 0 then
            local pressure = self:localPressureAt(machine.x, machine.y, machine.z or 0)
            if pressure > 0 then
                hotspots[#hotspots + 1] = { x = machine.x, y = machine.y, z = machine.z or 0, pressure = pressure }
            end
        end
    end
    table.sort(hotspots, function(a, b)
        if a.pressure ~= b.pressure then
            return a.pressure > b.pressure
        end
        if a.y ~= b.y then
            return a.y < b.y
        end
        return a.x < b.x
    end)
    while #hotspots > 5 do
        table.remove(hotspots)
    end
    return hotspots
end

function Simulation:pressureMapText()
    local hotspots = self:pressureHotspots()
    if #hotspots == 0 then
        return "pressure map: no active hotspot"
    end
    local hotspot = hotspots[1]
    return "pressure map: hotspot x" .. hotspot.x .. " y" .. hotspot.y .. " p" .. hotspot.pressure
end

function Simulation:ticksUntilNextPressureWave()
    if (self.productionTotals.science_pack or 0) == 0 or self:factoryPressureLevel() < 120 then
        return -1
    end
    if self.tick > 0 and self.tick % 300 == 0 then
        return 0
    end
    return 300 - (self.tick % 300)
end

function Simulation:pressureWaveAlertText()
    local ticks = self:ticksUntilNextPressureWave()
    if ticks < 0 then
        return "wave alert: none; pressure below raid threshold"
    end
    local severity = self:factoryPressureLevel() >= 220 and "surge" or "probe"
    if ticks == 0 then
        return "wave alert: " .. severity .. " incoming now"
    end
    return "wave alert: next " .. severity .. " in " .. ticks .. " ticks"
end

function Simulation:pressureWaveSpawnKinds()
    if self:ticksUntilNextPressureWave() ~= 0 then
        return {}
    end
    if self:factoryPressureLevel() >= 220 then
        return { "skeleton", "slime" }
    end
    return { "slime" }
end

function Simulation:pressureAnchor()
    local hotspots = self:pressureHotspots()
    if #hotspots > 0 then
        return hotspots[1]
    end
    return { x = self.player.x, y = self.player.y, z = self.player.z, pressure = self:localPressureAt(self.player.x, self.player.y, self.player.z) }
end

function Simulation:spawnPressureEntity(kind, anchor, spawnIndex)
    for attempt = 1, #pressureSpawnOffsets do
        local offset = pressureSpawnOffsets[((spawnIndex + attempt - 2) % #pressureSpawnOffsets) + 1]
        local x = anchor.x + offset[1]
        local y = anchor.y + offset[2]
        local z = anchor.z or 0
        if not (x == self.player.x and y == self.player.y and z == self.player.z)
            and not self:machineAt(x, y, z)
            and not self:entityAt(x, y, z)
            and self.world:isWalkable(x, y, z) then
            local entity = self:addEntity(kind, x, y, z)
            entity.attackCooldown = 20
            entity.pressureSpawn = true
            return true
        end
    end
    return false
end

function Simulation:ensureFactoryPressureEntity()
    if #self.entities >= 80 or self:ticksUntilNextPressureWave() ~= 0 then
        return false
    end
    local anchor = self:pressureAnchor()
    local spawned = false
    for index, kind in ipairs(self:pressureWaveSpawnKinds()) do
        if self:spawnPressureEntity(kind, anchor, index + math.floor(self.tick / 300)) then
            spawned = true
        end
    end
    return spawned
end

function Simulation:productionRatePanels()
    local minutes = math.max(1, math.floor((self.tick + 3599) / 3600))
    local panels = {}
    local function rate(key)
        return math.floor((self.productionTotals[key] or 0) / minutes)
    end
    local function add(key, label, current, target, detail)
        panels[#panels + 1] = {
            key = key,
            label = label,
            currentPerMinute = current,
            targetPerMinute = target,
            blocked = target > 0 and current < target,
            detail = detail,
        }
    end
    add("iron_plate", "Iron/min", rate("iron_plate"), 3, self:currentSupplyContractText())
    add("copper_plate", "Copper/min", rate("copper_plate"), 3, self:currentSupplyContractText())
    add("science_pack", "Science/min", rate("science_pack"), 2, self.activeTech and ("active tech " .. self.activeTech) or "research complete")
    add("water_barrel", "Water/min", rate("water_barrel"), self:isRecipeUnlocked("pipe") and 1 or 0, "pump water into pipe output")
    add("train_deliveries", "Train/min", rate("train_deliveries"), self:isRecipeUnlocked("train_stop") and 1 or 0, "move freight between train stops")
    return panels
end

function Simulation:productionRateText()
    for _, panel in ipairs(self:productionRatePanels()) do
        if panel.blocked then
            return "rates: " .. panel.label .. " " .. panel.currentPerMinute .. "/" .. panel.targetPerMinute .. "; " .. panel.detail
        end
    end
    return "rates: tracked production meets current targets"
end

function Simulation:factoryDashboard()
    local panels = {}
    local function add(key, label, status, detail, current, target, urgent)
        panels[#panels + 1] = {
            key = key,
            label = label,
            status = status,
            detail = detail,
            current = current,
            target = target,
            urgent = urgent == true,
        }
    end

    local poweredNetworks = 0
    local demandNetworks = 0
    local underpowered = false
    for _, network in ipairs(self.powerNetworks) do
        if network.demand > 0 then
            demandNetworks = demandNetworks + 1
            if network.powered then
                poweredNetworks = poweredNetworks + 1
            else
                underpowered = true
            end
        end
    end
    add(
        "power",
        "Power",
        underpowered and "underpowered" or (demandNetworks > 0 and "powered" or "idle"),
        "networks " .. poweredNetworks .. "/" .. demandNetworks,
        poweredNetworks,
        demandNetworks,
        underpowered)

    add(
        "progression",
        "Progression",
        self:mainObjectiveComplete() and "complete" or "in-progress",
        self:currentSupplyContractText(),
        self:completedSupplyContracts(),
        self:totalSupplyContracts(),
        false)

    local completedTechs = 0
    for _, techKey in ipairs(Defs.techOrder or {}) do
        if self:isTechCompleted(techKey) then
            completedTechs = completedTechs + 1
        end
    end
    add(
        "research",
        "Research",
        self.activeTech and "active" or "complete",
        self.activeTech and ("active tech " .. self.activeTech .. " " .. self.researchProgress) or "research complete",
        completedTechs,
        #(Defs.techOrder or {}),
        false)

    local metRates = 0
    local targetRates = 0
    for _, panel in ipairs(self:productionRatePanels()) do
        if panel.targetPerMinute > 0 then
            targetRates = targetRates + 1
            if not panel.blocked then
                metRates = metRates + 1
            end
        end
    end
    add("rates", "Rates", metRates >= targetRates and "stable" or "blocked", self:productionRateText(), metRates, targetRates, false)

    local droneCapacity = self:poweredDroneCapacity()
    add(
        "logistics",
        "Logistics",
        #self.logisticJobs > 0 and "moving" or (droneCapacity > 0 and "ready" or "idle"),
        "jobs " .. #self.logisticJobs .. "; drones " .. droneCapacity,
        #self.logisticJobs,
        math.max(1, droneCapacity),
        false)

    local storageMachines = 0
    local storedItems = 0
    for _, machine in ipairs(self.machines) do
        if machine.kind == "chest" or machine.kind == "provider_chest" or machine.kind == "requester_chest" or machine.kind == "train_stop" then
            storageMachines = storageMachines + 1
            storedItems = storedItems + self:countMachineItem(machine)
        end
    end
    add(
        "storage",
        "Storage",
        storageMachines > 0 and "ready" or "missing",
        "stores " .. storedItems .. " item(s)",
        storageMachines,
        1,
        false)

    return panels
end

function Simulation:factoryDashboardText()
    for _, panel in ipairs(self:factoryDashboard()) do
        if panel.urgent then
            return "dashboard: urgent " .. panel.label .. " (" .. panel.status .. "); " .. panel.detail
        end
    end
    for _, panel in ipairs(self:factoryDashboard()) do
        if panel.target > 0 and panel.current < panel.target then
            return "dashboard: next " .. panel.label .. " (" .. panel.status .. "); " .. panel.detail
        end
    end
    return "dashboard: all tracked systems stable"
end

function Simulation:achievementCurrent(key)
    if key == "first_iron_plate" then
        return self.productionTotals.iron_plate or 0
    end
    if key == "first_copper_plate" then
        return self.productionTotals.copper_plate or 0
    end
    if key == "first_science_pack" then
        return self.productionTotals.science_pack or 0
    end
    if key == "logistics_one" then
        return self:isTechCompleted("logistics_1") and 1 or 0
    end
    if key == "first_supply_contract" then
        return self:completedSupplyContracts()
    end
    if key == "main_objective" then
        return self:mainObjectiveComplete() and 1 or 0
    end
    return 0
end

function Simulation:isAchievementUnlocked(key)
    return self.unlockedAchievementSet[key] == true
end

function Simulation:unlockAchievement(key)
    if self:isAchievementUnlocked(key) then
        return false
    end
    self.unlockedAchievementSet[key] = true
    self.unlockedAchievements[#self.unlockedAchievements + 1] = key
    return true
end

function Simulation:updateAchievements()
    for _, def in ipairs(achievementDefs) do
        if not self:isAchievementUnlocked(def.key) and self:achievementCurrent(def.key) >= def.required then
            self:unlockAchievement(def.key)
        end
    end
end

function Simulation:achievementProgress()
    local progress = {}
    for _, def in ipairs(achievementDefs) do
        progress[#progress + 1] = {
            key = def.key,
            title = def.title,
            description = def.description,
            current = self:achievementCurrent(def.key),
            required = def.required,
            unlocked = self:isAchievementUnlocked(def.key),
        }
    end
    return progress
end

function Simulation:unlockedAchievementCount()
    return #self.unlockedAchievements
end

function Simulation:beginTutorial()
    self.tutorial.active = true
    self.tutorial.completed = false
    self.tutorial.actions = {}
    self.player.x = 0
    self.player.y = 0
    self.player.z = tutorialLayer
    self.player.facing = "east"
    if not self:machineAt(3, 0, tutorialLayer) then
        self:addMachine("chest", 3, 0, "south", tutorialLayer)
    end
end

function Simulation:completeTutorial()
    self.tutorial.active = false
    self.tutorial.completed = true
    self.tutorial.actions = completedTutorialActions()
    self.player.x = self.tutorial.realSpawnX
    self.player.y = self.tutorial.realSpawnY
    self.player.z = self.tutorial.realSpawnZ
    self.player.facing = "south"
end

function Simulation:recordTutorialAction(action)
    if not self.tutorial.active or self.tutorial.completed or self.player.z ~= tutorialLayer then
        return
    end
    self.tutorial.actions[action] = true
end

function Simulation:tutorialState()
    return self.tutorial
end

function Simulation:tutorialProgress()
    local progress = {}
    for _, step in ipairs(tutorialSteps) do
        progress[#progress + 1] = {
            key = step.key,
            label = step.label,
            complete = self.tutorial.actions[step.key] == true,
        }
    end
    return progress
end

function Simulation:tutorialExitReady()
    for _, step in ipairs(tutorialSteps) do
        if self.tutorial.actions[step.key] ~= true then
            return false
        end
    end
    return true
end

function Simulation:updateMachines()
    self:updatePowerNetworks()
    self:updateOutpostRouteWindows()
    for _, machine in ipairs(self.machines) do
        if machine.kind == "burner_miner" then
            self:updateMiner(machine)
        elseif machine.kind == "electric_miner" then
            self:updateElectricMiner(machine)
        elseif machine.kind == "belt" or machine.kind == "fast_belt" then
            self:updateBelt(machine)
        elseif machine.kind == "splitter" then
            self:updateSplitter(machine)
        elseif machine.kind == "pipe" then
            self:updatePipe(machine)
        elseif machine.kind == "offshore_pump" then
            self:updateOffshorePump(machine)
        elseif machine.kind == "inserter" or machine.kind == "circuit_inserter" then
            self:updateInserter(machine)
        elseif machine.kind == "furnace" then
            self:updateFurnace(machine)
        elseif machine.kind == "assembler" then
            self:updateAssembler(machine)
        elseif machine.kind == "lab" then
            self:updateLab(machine)
        elseif machine.kind == "guard_tower" then
            self:updateGuardTower(machine)
        elseif machine.kind == "arc_tower" then
            self:updateArcTower(machine)
        elseif machine.kind == "repair_pylon" then
            self:updateRepairPylon(machine)
        elseif machine.kind == "pressure_relay" then
            self:updatePressureRelay(machine)
        elseif machine.kind == "outpost_beacon" then
            self:updateOutpostBeacon(machine)
        elseif machine.kind == "archive_terminal" then
            self:updateArchiveTerminal(machine)
        elseif machine.kind == "rift_gate" then
            self:updateRiftGate(machine)
        end
    end
    self:updateLogistics()
    self:updateTrainStops()
end

function Simulation:updateOutpostRouteWindows()
    for _, route in ipairs(self.outpostRoutes) do
        if route.windowStartTick == 0 then
            route.windowStartTick = self.tick
        end
        if self.tick >= route.windowStartTick + outpostRouteWindowTicks then
            if route.deliveredInWindow >= route.requiredPerWindow then
                route.stability = math.min(outpostRouteStableThreshold, route.stability + 1)
            elseif route.stability > 0 then
                route.stability = route.stability - 1
            end
            route.deliveredInWindow = 0
            route.windowStartTick = self.tick
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

function Simulation:isPowerPole(kind)
    return kind == "power_pole"
end

function Simulation:isPowerConsumer(kind)
    return kind == "electric_miner" or kind == "logistic_port" or kind == "archive_terminal" or kind == "rift_gate"
        or kind == "guard_tower" or kind == "outpost_beacon" or kind == "repair_pylon" or kind == "pressure_relay"
        or kind == "arc_tower"
end

function Simulation:powerDemand(kind)
    if kind == "archive_terminal" or kind == "rift_gate" or kind == "arc_tower" then
        return 2
    end
    if self:isPowerConsumer(kind) then
        return 1
    end
    return 0
end

function Simulation:machineDistance(a, b)
    if (a.z or 0) ~= (b.z or 0) then
        return math.huge
    end
    return Grid.manhattan(a.x, a.y, b.x, b.y)
end

function Simulation:isMachinePowered(machineId)
    return self.poweredMachineIds[machineId] == true
end

function Simulation:updatePowerNetworks()
    self.poweredMachineIds = {}
    for _, machine in ipairs(self.machines) do
        if machine.kind == "generator" or machine.kind == "power_pole" then
            machine.status = "idle"
        end
    end

    if self.powerDirty then
        self:rebuildPowerNetworks()
        self.powerDirty = false
    end

    for _, network in ipairs(self.powerNetworks) do
        network.supply = 0
        network.powered = false
        if network.demand > 0 then
            for _, generatorId in ipairs(network.generatorIds) do
                local generator = self:machineById(generatorId)
                if generator and self:refuel(generator) then
                    generator.fuel = generator.fuel - 1
                    generator.status = "working"
                    network.supply = network.supply + 2
                elseif generator then
                    generator.status = "missing_fuel"
                end
            end
        end
        network.powered = network.supply >= network.demand
        if network.powered then
            for _, consumerId in ipairs(network.consumerIds) do
                self.poweredMachineIds[consumerId] = true
            end
        end
    end
end

function Simulation:rebuildPowerNetworks()
    self.powerNetworks = {}

    local poleIndexes = {}
    for index, machine in ipairs(self.machines) do
        if self:isPowerPole(machine.kind) then
            poleIndexes[#poleIndexes + 1] = index
        end
    end

    local assigned = {}
    for start = 1, #poleIndexes do
        if not assigned[start] then
            local group = { start }
            assigned[start] = true
            local network = { id = self.machines[poleIndexes[start]].id, poleIds = {}, generatorIds = {}, consumerIds = {}, supply = 0, demand = 0, powered = false }
            local cursor = 1
            while cursor <= #group do
                local pole = self.machines[poleIndexes[group[cursor]]]
                network.poleIds[#network.poleIds + 1] = pole.id
                network.id = math.min(network.id, pole.id)
                for candidate = 1, #poleIndexes do
                    if not assigned[candidate] then
                        local other = self.machines[poleIndexes[candidate]]
                        if self:machineDistance(pole, other) <= 4 then
                            assigned[candidate] = true
                            group[#group + 1] = candidate
                        end
                    end
                end
                cursor = cursor + 1
            end

            for _, machine in ipairs(self.machines) do
                if not self:isPowerPole(machine.kind) then
                    local connected = false
                    for _, groupIndex in ipairs(group) do
                        if self:machineDistance(machine, self.machines[poleIndexes[groupIndex]]) <= 2 then
                            connected = true
                            break
                        end
                    end
                    if connected then
                        if machine.kind == "generator" then
                            network.generatorIds[#network.generatorIds + 1] = machine.id
                        elseif self:isPowerConsumer(machine.kind) then
                            network.consumerIds[#network.consumerIds + 1] = machine.id
                            network.demand = network.demand + self:powerDemand(machine.kind)
                        end
                    end
                end
            end

            self.powerNetworks[#self.powerNetworks + 1] = network
        end
    end
end

function Simulation:rebuildLogisticIndex()
    self.logisticIndex = { providerIds = {}, requesterIds = {}, portIds = {} }
    for _, machine in ipairs(self.machines) do
        if machine.kind == "provider_chest" then
            self.logisticIndex.providerIds[#self.logisticIndex.providerIds + 1] = machine.id
        elseif machine.kind == "requester_chest" then
            self.logisticIndex.requesterIds[#self.logisticIndex.requesterIds + 1] = machine.id
        elseif machine.kind == "logistic_port" then
            self.logisticIndex.portIds[#self.logisticIndex.portIds + 1] = machine.id
        end
    end
    self.logisticDirty = false
end

function Simulation:poweredDroneCapacity()
    local capacity = 0
    for _, portId in ipairs(self.logisticIndex.portIds) do
        local port = self:machineById(portId)
        if port and self:isMachinePowered(port.id) then
            capacity = capacity + port.inventory:count("logistic_drone")
        end
    end
    return capacity
end

function Simulation:inboundLogisticCount(requesterId, item)
    local total = 0
    for _, job in ipairs(self.logisticJobs) do
        if job.toId == requesterId and job.item == item then
            total = total + job.count
        end
    end
    return total
end

function Simulation:findProviderFor(item)
    for _, providerId in ipairs(self.logisticIndex.providerIds) do
        local provider = self:machineById(providerId)
        if provider and provider.inventory:count(item) > 0 then
            return provider
        end
    end
    return nil
end

function Simulation:updateLogistics()
    if self.logisticDirty then
        self:rebuildLogisticIndex()
    end
    self:updateScoutAutomation()
    local capacity = self:poweredDroneCapacity()
    if capacity <= 0 then
        return
    end

    for index = #self.logisticJobs, 1, -1 do
        local job = self.logisticJobs[index]
        job.remaining = job.remaining - 1
        if job.remaining <= 0 then
            local requester = self:machineById(job.toId)
            if requester then
                requester.inventory:add(job.item, job.count)
                self.productionTotals.logistic_deliveries = (self.productionTotals.logistic_deliveries or 0) + 1
            end
            table.remove(self.logisticJobs, index)
        end
    end

    local activeJobs = #self.logisticJobs
    for _, requesterId in ipairs(self.logisticIndex.requesterIds) do
        if activeJobs >= capacity then
            return
        end
        local requester = self:machineById(requesterId)
        local item = requester and requester.requestItem
        local threshold = requester and requester.requestThreshold or 0
        if item and threshold > 0 then
            local have = requester.inventory:count(item) + self:inboundLogisticCount(requester.id, item)
            if have < threshold then
                local provider = self:findProviderFor(item)
                if provider and provider.inventory:consume(item, 1) then
                    self.logisticJobs[#self.logisticJobs + 1] = {
                        id = self.nextLogisticJobId,
                        fromId = provider.id,
                        toId = requester.id,
                        item = item,
                        count = 1,
                        remaining = 12,
                    }
                    self.nextLogisticJobId = self.nextLogisticJobId + 1
                    activeJobs = activeJobs + 1
                end
            end
        end
    end
end

function Simulation:updateScoutAutomation()
    for _, portId in ipairs(self.logisticIndex.portIds) do
        local port = self:machineById(portId)
        if port and self:isMachinePowered(port.id) then
            local activeScout = port.progress > 0 and port.carriedItem and 1 or 0
            local availableDrones = port.inventory:count("logistic_drone") - activeScout
            if port.progress == 0 and not port.carriedItem then
                if availableDrones <= 0 then
                    port.status = "missing_input"
                elseif port.inventory:consume("science_pack", 1) or port.inventory:consume("advanced_science_pack", 1) then
                    port.carriedItem = scoutRewardForBiome(self:scoutTargetBiome(port))
                else
                    port.status = "missing_input"
                end
            end
            if port.carriedItem then
                port.progress = math.min(port.progress + 1, scoutDispatchTicks)
                port.status = "working"
                if port.progress >= scoutDispatchTicks then
                    local biome = scoutBiomeForReward(port.carriedItem) or self:scoutTargetBiome(port)
                    local recovered = scoutRewardCountForBiome(biome)
                    if self.world:biomeAt(port.x, port.y, port.z or 0) == biome then
                        recovered = recovered + 1
                    end
                    if self:hasActivatedOutpostBiome(biome) then
                        recovered = recovered + 1
                    end
                    if self:outpostRouteStability(biome) >= outpostRouteStableThreshold then
                        recovered = recovered + 1
                    end
                    port.inventory:add(port.carriedItem, recovered)
                    port.inventory:add(fragmentForBiome(biome), 1)
                    self:markScoutedBiome(biome)
                    self.productionTotals.scout_dispatches = (self.productionTotals.scout_dispatches or 0) + 1
                    self.productionTotals.scout_materials_recovered = (self.productionTotals.scout_materials_recovered or 0) + recovered
                    port.progress = 0
                    port.carriedItem = nil
                    port.status = "idle"
                end
            end
        end
    end
end

function Simulation:updateTrainStops()
    local stopIds = {}
    for _, machine in ipairs(self.machines) do
        if machine.kind == "train_stop" then
            stopIds[#stopIds + 1] = machine.id
        end
    end
    table.sort(stopIds)
    if #stopIds < 2 then
        for _, id in ipairs(stopIds) do
            local stop = self:machineById(id)
            if stop then
                stop.status = "missing_input"
            end
        end
        return
    end
    for index, id in ipairs(stopIds) do
        local stop = self:machineById(id)
        local target = self:machineById(stopIds[(index % #stopIds) + 1])
        if stop and target then
            local stacks = stop.inventory:stacks()
            if #stacks == 0 then
                stop.progress = 0
                stop.status = "missing_input"
            else
                stop.progress = stop.progress + 1
                stop.status = "working"
                if stop.progress >= 90 then
                    local item = stacks[1].item
                    if target.inventory:add(item, 1) and stop.inventory:consume(item, 1) then
                        self.productionTotals.train_deliveries = (self.productionTotals.train_deliveries or 0) + 1
                        stop.progress = 0
                        stop.status = "idle"
                    else
                        stop.status = "output_blocked"
                    end
                end
            end
        end
    end
end

function Simulation:nearestHostile(machine, range)
    local best
    local bestDistance = range + 1
    for _, entity in ipairs(self.entities) do
        if (entity.z or 0) == (machine.z or 0) and self:isHostileEntity(entity) then
            local distance = Grid.manhattan(machine.x, machine.y, entity.x, entity.y)
            if distance <= range and distance < bestDistance then
                best = entity
                bestDistance = distance
            end
        end
    end
    return best
end

function Simulation:updateGuardTower(machine)
    if not self:isMachinePowered(machine.id) then
        machine.progress = 0
        machine.status = "missing_power"
        return
    end
    local target = self:nearestHostile(machine, 5)
    if not target then
        machine.progress = 0
        machine.status = "idle"
        return
    end
    machine.progress = machine.progress + 1
    machine.status = "working"
    if machine.progress >= 45 then
        local ammo = self:towerAmmo(machine)
        self:damageEntity(target, self:towerDamage(machine.kind, ammo, target.kind))
        machine.progress = 0
    end
end

function Simulation:updateArcTower(machine)
    if not self:isMachinePowered(machine.id) then
        machine.progress = 0
        machine.status = "missing_power"
        return
    end
    local target = self:nearestHostile(machine, 7)
    if not target then
        machine.progress = 0
        machine.status = "idle"
        return
    end
    machine.progress = machine.progress + 1
    machine.status = "working"
    if machine.progress >= 30 then
        local ammo = self:towerAmmo(machine)
        self:damageEntity(target, self:towerDamage(machine.kind, ammo, target.kind))
        machine.progress = 0
    end
end

function Simulation:towerAmmo(machine)
    local order = machine.kind == "guard_tower" and guardTowerAmmo or arcTowerAmmo
    for _, item in ipairs(order) do
        if machine.inventory:consume(item, 1) then
            return item
        end
    end
    return nil
end

function Simulation:towerDamage(kind, ammo, targetKind)
    if kind == "guard_tower" then
        if ammo == "copper_coil" then
            return targetKind == "glass_maw" and 5 or 4
        end
        if ammo == "frost_cell" then
            return 3
        end
        if ammo == "stone_shot" then
            return 2
        end
        return 1
    end
    if ammo == "rift_shell" then
        return 5
    end
    if ammo == "crystal_charge" then
        return 4
    end
    if ammo == "copper_coil" then
        return 3
    end
    return 2
end

function Simulation:updateRepairPylon(machine)
    if not self:isMachinePowered(machine.id) then
        machine.status = "missing_power"
        return
    end
    local target = self:repairPylonTarget(machine)
    if not target then
        machine.progress = 0
        machine.carriedItem = nil
        machine.status = "idle"
        return
    end
    if machine.progress == 0 then
        if not machine.inventory:consume(target.material, 1) then
            machine.status = "missing_input"
            return
        end
        machine.carriedItem = target.material
    end
    local goal = machine.socketedRelic == "marsh_heart" and 40 or 60
    machine.progress = math.min(machine.progress + 1, goal)
    machine.status = "working"
    if machine.progress < goal then
        return
    end
    if target.kind == "machine" then
        local repaired = self:machineById(target.machineId)
        if repaired then
            self:repairMachine(repaired)
        end
    elseif target.kind == "tile" then
        self:repairTileAt(target.x, target.y, target.z)
    else
        self.world:setTile(target.x, target.y, target.z, { id = machine.carriedItem == "plank_wall" and "plank_wall" or "wall", data = 0 })
    end
    machine.progress = 0
    machine.carriedItem = nil
    machine.status = "idle"
end

function Simulation:updatePressureRelay(machine)
    if not self:isMachinePowered(machine.id) then
        machine.status = "missing_power"
        return
    end
    if machine.progress == 0 and not machine.inventory:consume("advanced_science_pack", 1) then
        machine.status = "missing_input"
        return
    end
    local goal = machine.socketedRelic == "glass_heart" and 90 or 120
    machine.progress = math.min(machine.progress + 1, goal)
    machine.status = "working"
    if machine.progress < goal then
        return
    end
    self.productionTotals.pressure_waves_repelled = (self.productionTotals.pressure_waves_repelled or 0) + (machine.socketedRelic == "glass_heart" and 2 or 1)
    machine.progress = 0
    machine.status = "idle"
end

function Simulation:updateOutpostBeacon(machine)
    if machine.progress >= outpostBeaconTicks then
        if not self:isMachinePowered(machine.id) then
            machine.status = "missing_power"
            return
        end
        local biome = self.world:biomeAt(machine.x, machine.y, machine.z or 0)
        local input = outpostActivationItem(biome)
        if machine.inventory:count(input) <= 0 then
            machine.progress = outpostBeaconTicks
            machine.status = "idle"
            return
        end
        machine.progress = math.min(machine.progress + 1, outpostBeaconTicks + outpostDeliveryTicks)
        machine.status = "working"
        if machine.progress < outpostBeaconTicks + outpostDeliveryTicks then
            return
        end
        machine.inventory:consume(input, 1)
        self.productionTotals.outpost_deliveries = (self.productionTotals.outpost_deliveries or 0) + 1
        self:markCompletedOutpostDeliveryBiome(biome)
        local route = self:outpostRouteForBiome(biome)
        route.deliveredInWindow = route.deliveredInWindow + 1
        route.lastDeliveryTick = self.tick
        if route.deliveredInWindow >= route.requiredPerWindow then
            route.stability = math.min(outpostRouteStableThreshold, route.stability + 1)
            route.deliveredInWindow = 0
            route.windowStartTick = self.tick
        end
        machine.progress = outpostBeaconTicks
        machine.status = "idle"
        return
    end
    if not self:isMachinePowered(machine.id) then
        machine.status = "missing_power"
        return
    end
    local input = outpostActivationItem(self.world:biomeAt(machine.x, machine.y, machine.z or 0))
    if machine.progress == 0 and not machine.inventory:consume(input, 1) then
        machine.status = "missing_input"
        return
    end
    machine.progress = math.min(machine.progress + 1, outpostBeaconTicks)
    machine.status = "working"
    if machine.progress < outpostBeaconTicks then
        return
    end
    self.productionTotals.outposts_activated = (self.productionTotals.outposts_activated or 0) + 1
    self:markActivatedOutpostBiome(self.world:biomeAt(machine.x, machine.y, machine.z or 0))
    machine.status = "idle"
end

function Simulation:updateArchiveTerminal(machine)
    if not self:isMachinePowered(machine.id) then
        machine.status = "missing_power"
        return
    end
    if self:tryArchiveUnlock(machine) then
        machine.progress = 0
        machine.status = "idle"
        return
    end
    if machine.progress == 0 and not machine.inventory:consume("beacon_core", 1) then
        machine.status = "missing_input"
        return
    end
    machine.progress = math.min(machine.progress + 1, archiveTerminalTicks)
    machine.status = "working"
    if machine.progress < archiveTerminalTicks then
        return
    end
    self.productionTotals.archive_signals = (self.productionTotals.archive_signals or 0) + 1
    machine.progress = 0
    machine.status = "idle"
end

function Simulation:updateRiftGate(machine)
    if machine.progress >= riftGateTicks then
        self:completeRiftJump(machine)
        return
    end
    if not self:isMachinePowered(machine.id) then
        machine.status = "missing_power"
        return
    end
    if machine.progress == 0 and not machine.inventory:consume("beacon_core", 1) then
        machine.status = "missing_input"
        return
    end
    machine.progress = math.min(machine.progress + 1 + self:riftStormChargeBonus(machine), riftGateTicks)
    machine.status = "working"
    if machine.progress >= riftGateTicks then
        self:completeRiftJump(machine)
    end
end

function Simulation:completeRiftJump(machine)
    self.player.x = self.player.x + (self.player.x >= (riftOffset / 2) and -riftOffset or riftOffset)
    self.productionTotals.rift_jumps = (self.productionTotals.rift_jumps or 0) + 1
    self:startRiftStorm(self:currentRiftStormSeverity())
    machine.progress = 0
    machine.status = "idle"
end

function Simulation:riftStormActive()
    return (self.riftStorm.ticksRemaining or 0) > 0 and (self.riftStorm.severity or 0) > 0
end

function Simulation:currentRiftStormSeverity()
    local severity = 1 + math.min(3, math.floor((self.productionTotals.rift_jumps or 0) / 2))
    if self:factoryPressureLevel() >= 220 then
        severity = severity + 1
    end
    if self.world:biomeAt(self.player.x, self.player.y, self.player.z) == "rift" then
        severity = severity + 1
    end
    if (self.productionTotals.pressure_waves_repelled or 0) >= 3 then
        severity = severity - 1
    end
    return math.max(1, math.min(4, severity))
end

function Simulation:startRiftStorm(severity)
    local normalized = math.max(1, math.min(4, severity or 1))
    local duration = riftStormBaseTicks + normalized * 30
    self.productionTotals.rift_storms_triggered = (self.productionTotals.rift_storms_triggered or 0) + 1
    self.riftStorm.severity = math.max(self.riftStorm.severity or 0, normalized)
    self.riftStorm.ticksRemaining = math.max(self.riftStorm.ticksRemaining or 0, duration)
    self.riftStorm.cooldownTicks = math.max(self.riftStorm.cooldownTicks or 0, riftStormCooldownTicks)
end

function Simulation:riftStormChargeBonus(machine)
    if not self:riftStormActive() or machine.kind ~= "rift_gate" then
        return 0
    end
    if machine.socketedRelic == "rift_crown" then
        return 1 + math.floor((self.riftStorm.severity or 1) / 2)
    end
    return 1
end

function Simulation:updateRiftStorms()
    if not self:riftStormActive() then
        if (self.riftStorm.cooldownTicks or 0) > 0 then
            self.riftStorm.cooldownTicks = self.riftStorm.cooldownTicks - 1
        end
        return
    end
    local severity = math.max(1, math.min(4, self.riftStorm.severity or 1))
    if self.tick > 0 and self.tick % 45 == 0 and self.world:biomeAt(self.player.x, self.player.y, self.player.z) == "rift" then
        self:spawnEntityNear(self.player.x, self.player.y, self.player.z, "rift_stalker", 7)
    end
    if self.tick > 0 and self.tick % 60 == 0 then
        for _, machine in ipairs(self.machines) do
            if machine.kind == "rift_gate" and machine.progress > 0 then
                if machine.socketedRelic == "rift_crown" then
                    machine.progress = math.min(machine.progress + severity * 2, riftGateTicks)
                    machine.status = "working"
                else
                    machine.progress = math.max(0, machine.progress - severity)
                    machine.status = "output_blocked"
                end
            end
        end
    end
    self.riftStorm.ticksRemaining = math.max(0, (self.riftStorm.ticksRemaining or 0) - 1)
    if self.riftStorm.ticksRemaining == 0 then
        self.riftStorm.severity = 0
        self.productionTotals.rift_storms_survived = (self.productionTotals.rift_storms_survived or 0) + 1
    end
end

function Simulation:riftStormText()
    if not self:riftStormActive() then
        return "rift storm: calm"
    end
    return "rift storm: active severity " .. self.riftStorm.severity .. " for " .. self.riftStorm.ticksRemaining .. " ticks"
end

function Simulation:tryArchiveUnlock(machine)
    local preferred = math.max(0, math.min(#archiveChoiceDefs - 1, machine.requestThreshold or 0))
    for offset = 0, #archiveChoiceDefs - 1 do
        local choice = archiveChoiceDefs[((preferred + offset) % #archiveChoiceDefs) + 1]
        if not self:isRecipeUnlocked(choice.recipeKey) then
            local fragments = machine.inventory:count(choice.fragment)
            if choice.fragment ~= "archive_fragment" then
                fragments = fragments + machine.inventory:count("archive_fragment")
            end
            local science = machine.inventory:count("advanced_science_pack") + machine.inventory:count("science_pack")
            if fragments >= choice.fragmentCost and science >= choice.scienceCost then
                local remainingFragments = choice.fragmentCost
                local specific = math.min(remainingFragments, machine.inventory:count(choice.fragment))
                if specific > 0 then
                    machine.inventory:consume(choice.fragment, specific)
                    remainingFragments = remainingFragments - specific
                end
                if remainingFragments > 0 then
                    machine.inventory:consume("archive_fragment", remainingFragments)
                end
                local remainingScience = choice.scienceCost
                local advanced = math.min(remainingScience, machine.inventory:count("advanced_science_pack"))
                if advanced > 0 then
                    machine.inventory:consume("advanced_science_pack", advanced)
                    remainingScience = remainingScience - advanced
                end
                if remainingScience > 0 then
                    machine.inventory:consume("science_pack", remainingScience)
                end
                self.unlockedRecipes[choice.recipeKey] = true
                machine.requestThreshold = (preferred + offset + 1) % #archiveChoiceDefs
                return true
            end
        end
    end
    return false
end

function Simulation:archiveChoices(machineId)
    local machine = machineId and self:machineById(machineId) or nil
    local choices = {}
    for index, choice in ipairs(archiveChoiceDefs) do
        local fragments = machine and machine.inventory:count(choice.fragment) or 0
        if machine and choice.fragment ~= "archive_fragment" then
            fragments = fragments + machine.inventory:count("archive_fragment")
        end
        local science = machine and (machine.inventory:count("advanced_science_pack") + machine.inventory:count("science_pack")) or 0
        choices[#choices + 1] = {
            index = index - 1,
            key = choice.key,
            recipeKey = choice.recipeKey,
            fragment = choice.fragment,
            fragmentCost = choice.fragmentCost,
            scienceCost = choice.scienceCost,
            selected = machine and (machine.requestThreshold or 0) == index - 1 or false,
            available = fragments >= choice.fragmentCost and science >= choice.scienceCost,
            unlocked = self:isRecipeUnlocked(choice.recipeKey),
        }
    end
    return choices
end

function Simulation:selectArchiveChoice(machineId, choiceIndex)
    local machine = self:machineById(machineId)
    if not machine or machine.kind ~= "archive_terminal" then
        return false
    end
    machine.requestThreshold = math.max(0, math.min(#archiveChoiceDefs - 1, math.floor(tonumber(choiceIndex) or 0)))
    return true
end

function Simulation:isWaterTile(x, y, z)
    local id = self.world:getTile(x, y, z or 0).id
    return id == "water" or id == "deep_water" or id == "coral"
end

function Simulation:hasAdjacentWater(machine)
    for _, direction in ipairs(Grid.order) do
        local x, y = Grid.front(machine.x, machine.y, direction)
        if self:isWaterTile(x, y, machine.z or 0) then
            return true
        end
    end
    return false
end

function Simulation:updateElectricMiner(machine)
    local tile = self.world:getTile(machine.x, machine.y, machine.z or 0)
    local item = Defs.tile(tile.id).resource
    if not item then
        machine.progress = 0
        machine.status = "missing_input"
        return
    end
    if not self:isMachinePowered(machine.id) then
        machine.status = "missing_power"
        return
    end
    machine.progress = machine.progress + 1
    machine.status = "working"
    if machine.progress < 8 then
        return
    end
    local x, y = Grid.front(machine.x, machine.y, machine.direction)
    local mined = self.world:consumeResource(machine.x, machine.y, machine.z or 0)
    if not mined then
        machine.status = "missing_input"
        machine.progress = 0
        return
    end
    if not self:acceptItemAt(x, y, machine.z or 0, mined) then
        machine.inventory:add(mined, 1)
    end
    self:recordProduced(mined)
    if mined:match("_ore$") then
        self.productionTotals.powered_ore = (self.productionTotals.powered_ore or 0) + 1
    end
    machine.progress = 0
end

function Simulation:updateOffshorePump(machine)
    if not self:hasAdjacentWater(machine) then
        machine.progress = 0
        machine.status = "missing_input"
        return
    end
    machine.progress = machine.progress + 1
    machine.status = "working"
    if machine.progress < 30 then
        return
    end
    local x, y = Grid.front(machine.x, machine.y, machine.direction)
    if self:acceptItemAt(x, y, machine.z or 0, "water_barrel") then
        machine.progress = 0
        machine.status = "working"
        self:recordProduced("water_barrel")
    else
        machine.status = "output_blocked"
    end
end

function Simulation:updatePipe(machine)
    if not machine.carriedItem then
        machine.progress = 0
        machine.status = "idle"
        return
    end
    machine.progress = machine.progress + 1
    machine.status = "working"
    if machine.progress < 3 then
        return
    end
    local x, y = Grid.front(machine.x, machine.y, machine.direction)
    if self:acceptItemAt(x, y, machine.z or 0, machine.carriedItem) then
        machine.carriedItem = nil
        machine.progress = 0
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
    local tech = Defs.tech(self.activeTech)
    if not tech or self:isTechCompleted(self.activeTech) then
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
    local inputItem = self:activeTechInput()
    if not inputItem or not machine.inventory:consume(inputItem, 1) then
        machine.status = "missing_input"
        return
    end
    machine.progress = 20
    machine.status = "working"
end

function Simulation:activeTechInput()
    local tech = Defs.tech(self.activeTech)
    if not tech then
        return nil
    end
    for item in pairs(tech.inputs or {}) do
        return item
    end
    return nil
end

function Simulation:nextIncompleteTech()
    for _, techKey in ipairs(Defs.techOrder or {}) do
        if not self:isTechCompleted(techKey) then
            return techKey
        end
    end
    return nil
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
    self.activeTech = self:nextIncompleteTech()
    self.researchProgress = 0
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
    if machine.kind == "pipe" then
        if item ~= "water_barrel" or machine.carriedItem then
            return false
        end
        machine.carriedItem = item
        return true
    end
    if machine.kind == "burner_miner" then
        return item == "coal" and machine.inventory:add(item, 1)
    end
    if machine.kind == "generator" then
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
        return (item == "science_pack" or item == "advanced_science_pack") and machine.inventory:add(item, 1)
    end
    if machine.kind == "logistic_port" then
        return item == "logistic_drone" and machine.inventory:add(item, 1)
    end
    if machine.kind == "guard_tower" then
        return (item == "stone_shot" or item == "copper_coil" or item == "frost_cell") and machine.inventory:add(item, 1)
    end
    if machine.kind == "arc_tower" then
        return (item == "crystal_charge" or item == "rift_shell" or item == "copper_coil") and machine.inventory:add(item, 1)
    end
    if machine.kind == "repair_pylon" then
        return (item == "wall" or item == "plank_wall" or item == "iron_plate") and machine.inventory:add(item, 1)
    end
    if machine.kind == "pressure_relay" then
        return item == "advanced_science_pack" and machine.inventory:add(item, 1)
    end
    if machine.kind == "outpost_beacon" then
        for _, input in pairs(outpostActivationItems) do
            if item == input then
                return machine.inventory:add(item, 1)
            end
        end
        return false
    end
    if machine.kind == "archive_terminal" then
        return (item == "beacon_core" or item == "science_pack" or item == "advanced_science_pack" or archiveFragmentItems[item] == true) and machine.inventory:add(item, 1)
    end
    if machine.kind == "rift_gate" then
        return item == "beacon_core" and machine.inventory:add(item, 1)
    end
    if machine.kind == "chest" or machine.kind == "provider_chest" or machine.kind == "requester_chest" or machine.kind == "train_stop" then
        return machine.inventory:add(item, 1)
    end
    return false
end

function Simulation:extractItem(machine, filterItem)
    if machine.kind == "belt" or machine.kind == "fast_belt" or machine.kind == "splitter" or machine.kind == "pipe" then
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
    if self:mainObjectiveComplete() then
        return "Main objective complete: archive/rift prep stabilized"
    end
    for _, group in ipairs(self:objectiveChecklist()) do
        for _, item in ipairs(group.items) do
            if not item.done and not item.blocked then
                return item.next
            end
        end
    end
    if self:completedSupplyContracts() < self:totalSupplyContracts() then
        return self:currentSupplyContractText()
    end
    if not self:isTechCompleted("logistic_network") then
        return "Research the logistics chain"
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
            requestItem = machine.requestItem,
            requestThreshold = machine.requestThreshold,
            socketedRelic = machine.socketedRelic,
            durability = machine.durability,
            status = machine.status,
        }
    end
    local entities = {}
    for _, entity in ipairs(self.entities) do
        entities[#entities + 1] = {
            id = entity.id,
            kind = entity.kind,
            x = entity.x,
            y = entity.y,
            z = entity.z or 0,
            hp = entity.hp,
            attackCooldown = entity.attackCooldown or 0,
            pressureSpawn = entity.pressureSpawn == true,
        }
    end
    return {
        seed = self.seed,
        tick = self.tick,
        gameMode = self.gameMode,
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
            inBoat = self.player.inBoat,
        },
        machines = machines,
        nextMachineId = self.nextMachineId,
        entities = entities,
        nextEntityId = self.nextEntityId,
        logisticJobs = self.logisticJobs,
        nextLogisticJobId = self.nextLogisticJobId,
        ghostBuilds = copyGhostBuilds(self.ghostBuilds),
        nextGhostId = self.nextGhostId,
        supplyContracts = copyContracts(self.supplyContracts),
        outpostRoutes = copyOutpostRoutes(self.outpostRoutes),
        riftStorm = copyRiftStorm(self.riftStorm),
        unlockedAchievements = copyList(self.unlockedAchievements),
        unlockedRecipes = copySet(self.unlockedRecipes),
        completedTechs = copySet(self.completedTechs),
        activeTech = self.activeTech,
        researchProgress = self.researchProgress,
        tutorial = copyTutorial(self.tutorial),
        productionTotals = copySet(self.productionTotals),
    }
end

function Simulation.fromSnapshot(snapshot)
    local self = Simulation.new(snapshot.seed)
    self.seed = snapshot.seed
    self.tick = snapshot.tick or 0
    self.gameMode = snapshot.gameMode or "survival"
    self.world = World.fromSnapshot(snapshot.world or { seed = snapshot.seed, tiles = {} })
    self.player.x = snapshot.player.x
    self.player.y = snapshot.player.y
    self.player.z = snapshot.player.z or 0
    self.player.facing = snapshot.player.facing or "south"
    self.player.inventory = Inventory.new(snapshot.player.inventory or {})
    self.player.hotbar = snapshot.player.hotbar or {}
    self.player.selectedHotbar = snapshot.player.selectedHotbar or 1
    self.player.hp = snapshot.player.hp or 20
    self.player.inBoat = snapshot.player.inBoat == true
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
        machine.requestItem = value.requestItem
        machine.requestThreshold = value.requestThreshold or 0
        machine.socketedRelic = value.socketedRelic
        machine.durability = value.durability or machine.durability
        machine.status = value.status or "idle"
        self.machines[#self.machines + 1] = machine
    end
    self:rebuildMachineIndexes()
    self.nextMachineId = snapshot.nextMachineId or (#self.machines + 1)
    self.entities = {}
    for _, value in ipairs(snapshot.entities or {}) do
        local entity = newEntity(value.id, value.kind, value.x, value.y, value.z or 0, value.hp or 1)
        entity.attackCooldown = value.attackCooldown or 0
        entity.pressureSpawn = value.pressureSpawn == true
        self.entities[#self.entities + 1] = entity
    end
    table.sort(self.entities, function(a, b)
        return a.id < b.id
    end)
    self.nextEntityId = snapshot.nextEntityId or (#self.entities + 1)
    self.unlockedRecipes = copySet(snapshot.unlockedRecipes or recipeUnlockedDefaults())
    self.completedTechs = copySet(snapshot.completedTechs or {})
    self.activeTech = snapshot.activeTech or self:nextIncompleteTech()
    self.researchProgress = snapshot.researchProgress or 0
    self.tutorial = copyTutorial(snapshot.tutorial)
    self.productionTotals = copySet(snapshot.productionTotals or {})
    self.powerDirty = true
    self.logisticDirty = true
    self.logisticIndex = { providerIds = {}, requesterIds = {}, portIds = {} }
    self.logisticJobs = snapshot.logisticJobs or {}
    self.nextLogisticJobId = snapshot.nextLogisticJobId or (#self.logisticJobs + 1)
    self.ghostBuilds = copyGhostBuilds(snapshot.ghostBuilds or {})
    self.nextGhostId = snapshot.nextGhostId or (#self.ghostBuilds + 1)
    self.supplyContracts = copyContracts(snapshot.supplyContracts or defaultSupplyContracts())
    self.outpostRoutes = copyOutpostRoutes(snapshot.outpostRoutes or {})
    self.riftStorm = copyRiftStorm(snapshot.riftStorm)
    self.unlockedAchievements = {}
    self.unlockedAchievementSet = {}
    for _, key in ipairs(snapshot.unlockedAchievements or {}) do
        if not self.unlockedAchievementSet[key] then
            self.unlockedAchievementSet[key] = true
            self.unlockedAchievements[#self.unlockedAchievements + 1] = key
        end
    end
    return self
end

return Simulation
