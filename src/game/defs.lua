local Registry = require("src.game.data.registry")

local Defs = {
    tiles = Registry.tiles,
    items = Registry.items,
    itemOrder = Registry.itemOrder,
    inventoryPanelOrder = Registry.inventoryPanelOrder,
    heroClasses = Registry.heroClasses,
    heroClassOrder = Registry.heroClassOrder,
    skills = Registry.skills,
    skillOrder = Registry.skillOrder,
    enemies = Registry.enemies,
    enemyOrder = Registry.enemyOrder,
    afflictions = Registry.afflictions,
    afflictionOrder = Registry.afflictionOrder,
    virtues = Registry.virtues,
    virtueOrder = Registry.virtueOrder,
    curios = Registry.curios,
    curioOrder = Registry.curioOrder,
    encounters = Registry.encounters,
    encounterOrder = Registry.encounterOrder,
    locations = Registry.locations,
    locationOrder = Registry.locationOrder,
    campSkills = Registry.campSkills,
    campSkillOrder = Registry.campSkillOrder,
}

function Defs.tile(id)
    return Defs.tiles[id] or Defs.tiles.archive_wall
end

function Defs.item(id)
    return Defs.items[id]
end

function Defs.heroClass(id)
    return Defs.heroClasses[id]
end

function Defs.skill(id)
    return Defs.skills[id]
end

function Defs.enemy(id)
    return Defs.enemies[id]
end

function Defs.affliction(id)
    return Defs.afflictions[id]
end

function Defs.virtue(id)
    return Defs.virtues[id]
end

function Defs.curio(id)
    return Defs.curios[id]
end

function Defs.encounter(id)
    return Defs.encounters[id]
end

function Defs.location(id)
    return Defs.locations[id]
end

function Defs.campSkill(id)
    return Defs.campSkills[id]
end

return Defs
