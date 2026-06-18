local Registry = require("src.game.data.registry")

local Defs = {
    tiles = Registry.tiles,
    items = Registry.items,
    itemOrder = Registry.itemOrder,
    inventoryPanelOrder = Registry.inventoryPanelOrder,
    machines = Registry.machines,
    recipes = Registry.recipes,
    recipeOrder = Registry.recipeOrder,
    buildRecipeOrder = Registry.buildRecipeOrder,
    machineRecipes = Registry.machineRecipes,
    machineRecipeOrder = Registry.machineRecipeOrder,
    techs = Registry.techs,
}

function Defs.tile(id)
    return Defs.tiles[id] or Defs.tiles.grass
end

function Defs.item(id)
    return Defs.items[id]
end

function Defs.machine(id)
    return Defs.machines[id]
end

function Defs.recipe(id)
    return Defs.recipes[id]
end

function Defs.machineRecipe(kind, id)
    local recipes = Defs.machineRecipes[kind]
    return recipes and recipes[id]
end

function Defs.tech(id)
    return Defs.techs[id]
end

return Defs
