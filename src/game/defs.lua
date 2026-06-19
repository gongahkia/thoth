local Registry = require("src.game.data.registry")

local Defs = {
    contentRules = Registry.contentRules,
    tiles = Registry.tiles,
    items = Registry.items,
    itemOrder = Registry.itemOrder,
    inventoryPanelOrder = Registry.inventoryPanelOrder,
    heroClasses = Registry.heroClasses,
    heroClassOrder = Registry.heroClassOrder,
    trinkets = Registry.trinkets,
    trinketOrder = Registry.trinketOrder,
    trinketSets = Registry.trinketSets,
    trinketSetOrder = Registry.trinketSetOrder,
    quirks = Registry.quirks,
    quirkOrder = Registry.quirkOrder,
    diseases = Registry.diseases,
    diseaseOrder = Registry.diseaseOrder,
    injuries = Registry.injuries,
    injuryOrder = Registry.injuryOrder,
    skills = Registry.skills,
    skillOrder = Registry.skillOrder,
    enemySkills = Registry.enemySkills,
    enemySkillOrder = Registry.enemySkillOrder,
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
    missions = Registry.missions,
    missionOrder = Registry.missionOrder,
    campSkills = Registry.campSkills,
    campSkillOrder = Registry.campSkillOrder,
    estateBuildings = Registry.estateBuildings,
    estateBuildingOrder = Registry.estateBuildingOrder,
    estateActivities = Registry.estateActivities,
    estateActivityOrder = Registry.estateActivityOrder,
    townEvents = Registry.townEvents,
    townEventOrder = Registry.townEventOrder,
    estateCopy = Registry.estateCopy,
    estateCopyOrder = Registry.estateCopyOrder,
    classLore = Registry.classLore,
    classLoreOrder = Registry.classLoreOrder,
    classLoreBanks = Registry.classLoreBanks,
    classLoreBankOrder = Registry.classLoreBankOrder,
    recruitBarks = Registry.recruitBarks,
    recruitBarkOrder = Registry.recruitBarkOrder,
    barkBanks = Registry.barkBanks,
    barkBankOrder = Registry.barkBankOrder,
    graveyardEpitaphs = Registry.graveyardEpitaphs,
    graveyardEpitaphOrder = Registry.graveyardEpitaphOrder,
    epitaphBanks = Registry.epitaphBanks,
    epitaphBankOrder = Registry.epitaphBankOrder,
    estateFixtures = Registry.estateFixtures,
    estateFixtureOrder = Registry.estateFixtureOrder,
    enclaveLeaders = Registry.enclaveLeaders,
    enclaveLeaderOrder = Registry.enclaveLeaderOrder,
    factions = Registry.factions,
    factionOrder = Registry.factionOrder,
    factionHazards = Registry.factionHazards,
    factionHazardOrder = Registry.factionHazardOrder,
    dreadRules = Registry.dreadRules,
    dreadRuleOrder = Registry.dreadRuleOrder,
    campaignTimers = Registry.campaignTimers,
    campaignTimerOrder = Registry.campaignTimerOrder,
    endingRoutes = Registry.endingRoutes,
    endingRouteOrder = Registry.endingRouteOrder,
    endingRouters = Registry.endingRouters,
    endingRouterOrder = Registry.endingRouterOrder,
    narration = Registry.narration,
    narrationOrder = Registry.narrationOrder,
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

function Defs.trinket(id)
    return Defs.trinkets[id]
end

function Defs.trinketSet(id)
    return Defs.trinketSets[id]
end

function Defs.quirk(id)
    return Defs.quirks[id]
end

function Defs.disease(id)
    return Defs.diseases[id]
end

function Defs.injury(id)
    return Defs.injuries[id]
end

function Defs.skill(id)
    return Defs.skills[id]
end

function Defs.enemySkill(id)
    return Defs.enemySkills[id]
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

function Defs.mission(id)
    return Defs.missions[id]
end

function Defs.campSkill(id)
    return Defs.campSkills[id]
end

function Defs.estateBuilding(id)
    return Defs.estateBuildings[id]
end

function Defs.estateActivity(id)
    return Defs.estateActivities[id]
end

function Defs.townEvent(id)
    return Defs.townEvents[id]
end

function Defs.estateCopyFor(id)
    return Defs.estateCopy[id]
end

function Defs.classLoreFor(id)
    return Defs.classLore[id]
end

function Defs.classLoreBank(id)
    return Defs.classLoreBanks[id]
end

function Defs.recruitBarksFor(id)
    return Defs.recruitBarks[id]
end

function Defs.barkBank(id)
    return Defs.barkBanks[id]
end

function Defs.graveyardEpitaphsFor(id)
    return Defs.graveyardEpitaphs[id]
end

function Defs.epitaphBank(id)
    return Defs.epitaphBanks[id]
end

function Defs.estateFixture(id)
    return Defs.estateFixtures[id]
end

function Defs.enclaveLeader(id)
    return Defs.enclaveLeaders[id]
end

function Defs.faction(id)
    return Defs.factions[id]
end

function Defs.factionHazard(id)
    return Defs.factionHazards[id]
end

function Defs.dreadRule(id)
    return Defs.dreadRules[id]
end

function Defs.campaignTimer(id)
    return Defs.campaignTimers[id]
end

function Defs.endingRoute(id)
    return Defs.endingRoutes[id]
end

function Defs.endingRouter(id)
    return Defs.endingRouters[id]
end

function Defs.narrationFor(id)
    return Defs.narration[id]
end

return Defs
