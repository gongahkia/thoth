package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Defs = require("src.game.defs")

local function expect(value, message)
    if not value then
        error(message or "registry expectation failed", 2)
    end
end

local expected = {
    tiles = {
        "grass", "dirt", "sand", "beach", "snow", "ice", "mud", "reeds", "cactus", "stone", "basalt", "crystal",
        "tree", "water", "deep_water", "coral", "iron_ore", "copper_ore", "coal_ore", "floor", "wall",
        "plank_wall", "door", "stairs_up", "stairs_down", "bed", "dungeon_floor", "dungeon_wall", "lair_hearth",
        "recovery_crate",
    },
    items = {
        "none", "wood", "stone", "coal", "iron_ore", "iron_plate", "copper_ore", "copper_plate", "sand",
        "sand_glass", "reed_fiber", "cactus_fiber", "kelp", "shell", "coral_shard", "ice_shard", "basalt",
        "crystal", "hide", "bone", "slime", "venom", "scrap", "marsh_heart", "glass_heart", "warden_core",
        "frost_core", "rift_crown", "archive_fragment", "marsh_fragment", "desert_fragment", "badlands_fragment",
        "frost_fragment", "crystal_fragment", "rift_fragment", "power_shard", "stone_shot", "copper_coil",
        "crystal_charge", "frost_cell", "rift_shell", "belt", "inserter", "burner_miner", "furnace", "chest",
        "workbench", "science_pack", "assembler", "lab", "fast_belt", "generator", "power_pole", "electric_miner",
        "circuit_board", "advanced_science_pack", "circuit_inserter", "provider_chest", "requester_chest",
        "logistic_port", "logistic_drone", "beacon_core", "archive_terminal", "splitter", "train_stop",
        "water_barrel", "pipe", "offshore_pump", "rift_gate", "guard_tower", "outpost_beacon", "repair_pylon",
        "pressure_relay", "arc_tower", "wall", "plank_wall", "door", "stairs_up", "stairs_down", "boat", "bed",
        "lair_hearth", "recovery_crate",
    },
    machines = {
        "belt", "fast_belt", "inserter", "burner_miner", "furnace", "chest", "workbench", "assembler", "lab",
        "generator", "power_pole", "electric_miner", "circuit_inserter", "provider_chest", "requester_chest",
        "logistic_port", "archive_terminal", "splitter", "train_stop", "pipe", "offshore_pump", "rift_gate",
        "guard_tower", "outpost_beacon", "repair_pylon", "pressure_relay", "arc_tower",
    },
    recipes = {
        "workbench", "furnace", "chest", "belt", "inserter", "burner_miner", "assembler", "lab", "iron_plate",
        "copper_plate", "sand_glass", "boat", "plank_wall", "wall", "basalt_wall", "door", "stairs_up",
        "stairs_down", "bed", "salvage_iron_plate", "salvage_copper_plate", "stone_shot", "copper_coil",
        "crystal_charge", "frost_cell", "rift_shell", "lair_hearth", "science_pack", "reed_science_pack",
        "fast_belt", "generator", "power_pole", "electric_miner", "circuit_board", "advanced_science_pack",
        "crystal_lens", "basalt_circuit_board", "circuit_inserter", "provider_chest", "requester_chest",
        "logistic_port", "logistic_drone", "splitter", "pipe", "offshore_pump", "beacon_core", "rift_beacon_core",
        "archive_terminal", "train_stop", "rift_gate", "guard_tower", "outpost_beacon", "repair_pylon",
        "pressure_relay", "arc_tower", "dry_copper_plate", "washed_iron_plate",
    },
    techs = { "logistics_1", "automation_control", "logistic_network" },
}

local function checkExpectedKeys(name, defs)
    for _, key in ipairs(expected[name]) do
        expect(defs[key] ~= nil, name .. " missing legacy key " .. key)
    end
end

local function checkOrder(name, order, defs)
    local seen = {}
    for _, key in ipairs(order) do
        expect(defs[key] ~= nil, name .. " order references missing key " .. key)
        expect(not seen[key], name .. " order repeats key " .. key)
        seen[key] = true
    end
end

local function recipeUnlocked(recipeKey)
    local archiveUnlockedRecipes = {
        reed_science_pack = true,
        dry_copper_plate = true,
        washed_iron_plate = true,
        basalt_circuit_board = true,
        rift_beacon_core = true,
    }
    if archiveUnlockedRecipes[recipeKey] then
        return true
    end
    for _, tech in pairs(Defs.techs) do
        for _, unlock in ipairs(tech.unlocks or {}) do
            if unlock == recipeKey then
                return true
            end
        end
    end
    return false
end

checkExpectedKeys("tiles", Defs.tiles)
checkExpectedKeys("items", Defs.items)
checkExpectedKeys("machines", Defs.machines)
checkExpectedKeys("recipes", Defs.recipes)
checkExpectedKeys("techs", Defs.techs)
checkOrder("item", Defs.itemOrder, Defs.items)
checkOrder("recipe", Defs.recipeOrder, Defs.recipes)
checkOrder("tech", Defs.techOrder, Defs.techs)

for key, tile in pairs(Defs.tiles) do
    expect(tile.name and tile.name ~= "", "tile " .. key .. " missing name")
    expect(type(tile.walkable) == "boolean", "tile " .. key .. " missing walkable")
    expect(type(tile.buildable) == "boolean", "tile " .. key .. " missing buildable")
    expect(type(tile.color) == "table" and #tile.color == 3, "tile " .. key .. " missing color")
    if tile.drop then
        expect(Defs.items[tile.drop] ~= nil, "tile " .. key .. " drops missing item " .. tile.drop)
    end
    if tile.resource then
        expect(Defs.items[tile.resource] ~= nil, "tile " .. key .. " has missing resource " .. tile.resource)
    end
end

for key, item in pairs(Defs.items) do
    expect(item.name and item.name ~= "", "item " .. key .. " missing name")
    if key == "none" then
        expect(item.stack == 0, "item none must have stack 0")
    else
        expect(type(item.stack) == "number" and item.stack > 0, "item " .. key .. " has bad stack size")
    end
    if item.tile then
        expect(Defs.tiles[item.tile] ~= nil, "item " .. key .. " places missing tile " .. item.tile)
    end
    if item.machine then
        expect(Defs.machines[item.machine] ~= nil, "item " .. key .. " places missing machine " .. item.machine)
    end
    expect(not (item.tile and item.machine), "item " .. key .. " places both tile and machine")
end

for key, machine in pairs(Defs.machines) do
    expect(machine.name and machine.name ~= "", "machine " .. key .. " missing name")
    expect(machine.inventory == nil or machine.inventory >= 0, "machine " .. key .. " has bad inventory size")
    local placeable = false
    for _, item in pairs(Defs.items) do
        placeable = placeable or item.machine == key
    end
    expect(placeable, "machine " .. key .. " has no placeable item")
end

for key, recipe in pairs(Defs.recipes) do
    expect(recipe.station == "hand" or recipe.station == "workbench" or recipe.station == "furnace" or recipe.station == "assembler", "recipe " .. key .. " has bad station")
    expect(type(recipe.ticks) == "number" and recipe.ticks > 0, "recipe " .. key .. " has bad ticks")
    expect(type(recipe.inputs) == "table" and next(recipe.inputs) ~= nil, "recipe " .. key .. " has no inputs")
    for item, count in pairs(recipe.inputs) do
        expect(Defs.items[item] ~= nil, "recipe " .. key .. " input missing item " .. item)
        expect(type(count) == "number" and count > 0, "recipe " .. key .. " has bad input count for " .. item)
    end
    expect(recipe.output and Defs.items[recipe.output.item] ~= nil, "recipe " .. key .. " output missing item")
    expect(type(recipe.output.count) == "number" and recipe.output.count > 0, "recipe " .. key .. " has bad output count")
    if recipe.default == false then
        expect(recipeUnlocked(key), "locked recipe " .. key .. " has no tech unlock")
    end
end

for kind, order in pairs(Defs.machineRecipeOrder) do
    expect(Defs.machines[kind] ~= nil, "machine recipe order missing machine " .. kind)
    for _, recipeKey in ipairs(order) do
        local recipe = Defs.machineRecipe(kind, recipeKey)
        expect(recipe ~= nil, "machine recipe " .. kind .. "/" .. recipeKey .. " is missing")
        expect(recipe.station == kind, "machine recipe " .. recipeKey .. " has station " .. tostring(recipe.station))
    end
end

for key, tech in pairs(Defs.techs) do
    expect(tech.name and tech.name ~= "", "tech " .. key .. " missing name")
    expect(type(tech.inputs) == "table" and next(tech.inputs) ~= nil, "tech " .. key .. " has no inputs")
    for item, count in pairs(tech.inputs) do
        expect(Defs.items[item] ~= nil, "tech " .. key .. " input missing item " .. item)
        expect(type(count) == "number" and count > 0, "tech " .. key .. " has bad input count for " .. item)
    end
    local unlockSeen = {}
    for _, recipeKey in ipairs(tech.unlocks or {}) do
        expect(Defs.recipes[recipeKey] ~= nil, "tech " .. key .. " unlocks missing recipe " .. recipeKey)
        expect(not unlockSeen[recipeKey], "tech " .. key .. " repeats unlock " .. recipeKey)
        unlockSeen[recipeKey] = true
    end
end

print("registry checks passed")
