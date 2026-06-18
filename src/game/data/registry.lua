local Registry = {}

Registry.tiles = {
    grass = { name = "Grass", walkable = true, buildable = true, color = { 83, 170, 86 } },
    floor = { name = "Floor", walkable = true, buildable = true, color = { 132, 122, 100 }, drop = "stone" },
    tree = { name = "Tree", walkable = false, buildable = false, color = { 54, 124, 58 }, drop = "wood", hardness = 2 },
    stone = { name = "Stone", walkable = true, buildable = true, color = { 130, 138, 134 }, drop = "stone", hardness = 3 },
    coal_ore = { name = "Coal Ore", walkable = true, buildable = false, color = { 55, 58, 61 }, drop = "coal", hardness = 3, resource = "coal" },
    iron_ore = { name = "Iron Ore", walkable = true, buildable = false, color = { 166, 128, 92 }, drop = "iron_ore", hardness = 3, resource = "iron_ore" },
    copper_ore = { name = "Copper Ore", walkable = true, buildable = false, color = { 178, 104, 66 }, drop = "copper_ore", hardness = 3, resource = "copper_ore" },
    water = { name = "Water", walkable = false, buildable = false, color = { 62, 140, 190 } },
}

Registry.items = {
    wood = { name = "Wood", stack = 100 },
    stone = { name = "Stone", stack = 100, tile = "floor" },
    coal = { name = "Coal", stack = 100 },
    iron_ore = { name = "Iron Ore", stack = 100 },
    copper_ore = { name = "Copper Ore", stack = 100 },
    iron_plate = { name = "Iron Plate", stack = 100 },
    copper_plate = { name = "Copper Plate", stack = 100 },
    science_pack = { name = "Science Pack", stack = 100 },
    workbench = { name = "Workbench", stack = 50, machine = "workbench" },
    burner_miner = { name = "Burner Miner", stack = 50, machine = "burner_miner" },
    belt = { name = "Belt", stack = 100, machine = "belt" },
    inserter = { name = "Inserter", stack = 100, machine = "inserter" },
    furnace = { name = "Furnace", stack = 50, machine = "furnace" },
    chest = { name = "Chest", stack = 50, machine = "chest" },
    assembler = { name = "Assembler", stack = 50, machine = "assembler" },
    lab = { name = "Lab", stack = 50, machine = "lab" },
    fast_belt = { name = "Fast Belt", stack = 100, machine = "fast_belt" },
}

Registry.itemOrder = {
    "wood", "stone", "coal", "iron_ore", "iron_plate", "copper_ore", "copper_plate", "science_pack",
    "workbench", "burner_miner", "belt", "inserter", "furnace", "chest", "assembler", "lab", "fast_belt",
}

Registry.machines = {
    workbench = { name = "Workbench", blocks = false },
    burner_miner = { name = "Burner Miner", resource = true, inventory = 2 },
    belt = { name = "Belt", belt = true },
    fast_belt = { name = "Fast Belt", belt = true, fast = true },
    inserter = { name = "Inserter", inserter = true },
    furnace = { name = "Furnace", inventory = 4 },
    chest = { name = "Chest", inventory = 16 },
    assembler = { name = "Assembler", inventory = 6 },
    lab = { name = "Lab", inventory = 4 },
}

Registry.recipes = {
    workbench = { station = "hand", ticks = 20, inputs = { wood = 6, stone = 2 }, output = { item = "workbench", count = 1 }, default = true },
    furnace = { station = "workbench", ticks = 30, inputs = { stone = 8 }, output = { item = "furnace", count = 1 }, default = true },
    chest = { station = "workbench", ticks = 20, inputs = { wood = 8 }, output = { item = "chest", count = 1 }, default = true },
    belt = { station = "workbench", ticks = 15, inputs = { stone = 1 }, output = { item = "belt", count = 2 }, default = true },
    inserter = { station = "workbench", ticks = 20, inputs = { stone = 1, wood = 1 }, output = { item = "inserter", count = 1 }, default = true },
    burner_miner = { station = "workbench", ticks = 45, inputs = { stone = 4, wood = 2 }, output = { item = "burner_miner", count = 1 }, default = true },
    assembler = { station = "workbench", ticks = 60, inputs = { stone = 4, wood = 2, iron_plate = 2 }, output = { item = "assembler", count = 1 }, default = true },
    lab = { station = "workbench", ticks = 60, inputs = { stone = 4, wood = 4, iron_plate = 2, copper_plate = 2 }, output = { item = "lab", count = 1 }, default = true },
    fast_belt = { station = "workbench", ticks = 30, inputs = { belt = 1, iron_plate = 1 }, output = { item = "fast_belt", count = 1 }, default = false },
    science_pack = { station = "assembler", ticks = 45, inputs = { iron_plate = 1, copper_plate = 1 }, output = { item = "science_pack", count = 1 }, default = true },
}

Registry.recipeOrder = {
    "workbench", "furnace", "chest", "belt", "inserter", "burner_miner", "assembler", "lab", "science_pack", "fast_belt",
}

Registry.machineRecipes = {
    furnace = {
        iron_plate = { name = "Iron Plate", inputs = { iron_ore = 1, coal = 1 }, output = { item = "iron_plate", count = 1 }, ticks = 60 },
        copper_plate = { name = "Copper Plate", inputs = { copper_ore = 1, coal = 1 }, output = { item = "copper_plate", count = 1 }, ticks = 60 },
    },
    assembler = {
        science_pack = Registry.recipes.science_pack,
    },
}

Registry.machineRecipeOrder = {
    furnace = { "iron_plate", "copper_plate" },
    assembler = { "science_pack" },
}

Registry.techs = {
    logistics_1 = { name = "Logistics 1", inputs = { science_pack = 3 }, unlocks = { "fast_belt" } },
}

return Registry
