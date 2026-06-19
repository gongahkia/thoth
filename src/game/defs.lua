local Registry = require("src.game.data.registry")

local Defs = {
    registry = Registry,
    applyRegistryOverrides = Registry.applyOverrides,
    contentRules = Registry.contentRules,
    tiles = Registry.tiles,
    tileOrder = Registry.tileOrder,
    items = Registry.items,
    itemOrder = Registry.itemOrder,
    inventoryPanelOrder = Registry.inventoryPanelOrder,
    heroClasses = Registry.heroClasses,
    heroClassOrder = Registry.heroClassOrder,
    classUnlocks = Registry.classUnlocks,
    classUnlockOrder = Registry.classUnlockOrder,
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
    factionPressureRules = Registry.factionPressureRules,
    factionPressureRuleOrder = Registry.factionPressureRuleOrder,
    dreadRules = Registry.dreadRules,
    dreadRuleOrder = Registry.dreadRuleOrder,
    campaignTimers = Registry.campaignTimers,
    campaignTimerOrder = Registry.campaignTimerOrder,
    endingRoutes = Registry.endingRoutes,
    endingRouteOrder = Registry.endingRouteOrder,
    endingRouters = Registry.endingRouters,
    endingRouterOrder = Registry.endingRouterOrder,
    documentTypes = Registry.documentTypes,
    documentTypeOrder = Registry.documentTypeOrder,
    documentRegistries = Registry.documentRegistries,
    documentRegistryOrder = Registry.documentRegistryOrder,
    documents = Registry.documents,
    documentOrder = Registry.documentOrder,
    documentBanks = Registry.documentBanks,
    documentBankOrder = Registry.documentBankOrder,
    documentDropRules = Registry.documentDropRules,
    documentDropRuleOrder = Registry.documentDropRuleOrder,
    fixtureDocumentBarks = Registry.fixtureDocumentBarks,
    fixtureDocumentBarkOrder = Registry.fixtureDocumentBarkOrder,
    glossaryTerms = Registry.glossaryTerms,
    glossaryTermOrder = Registry.glossaryTermOrder,
    panelCopy = Registry.panelCopy,
    panelCopyOrder = Registry.panelCopyOrder,
    fixtureVisitBarks = Registry.fixtureVisitBarks,
    fixtureVisitBarkOrder = Registry.fixtureVisitBarkOrder,
    enclaveLeaderBarks = Registry.enclaveLeaderBarks,
    enclaveLeaderBarkOrder = Registry.enclaveLeaderBarkOrder,
    wardenVoices = Registry.wardenVoices,
    wardenVoiceOrder = Registry.wardenVoiceOrder,
    originBarks = Registry.originBarks,
    originBarkOrder = Registry.originBarkOrder,
    threatBehaviors = Registry.threatBehaviors,
    threatBehaviorOrder = Registry.threatBehaviorOrder,
    alphaRules = Registry.alphaRules,
    alphaRuleOrder = Registry.alphaRuleOrder,
    scoutTooltips = Registry.scoutTooltips,
    scoutTooltipOrder = Registry.scoutTooltipOrder,
    expeditionCommands = Registry.expeditionCommands,
    expeditionCommandOrder = Registry.expeditionCommandOrder,
    pressureRules = Registry.pressureRules,
    pressureRuleOrder = Registry.pressureRuleOrder,
    injuryCureTooltips = Registry.injuryCureTooltips,
    injuryCureTooltipOrder = Registry.injuryCureTooltipOrder,
    weakPointRules = Registry.weakPointRules,
    weakPointRuleOrder = Registry.weakPointRuleOrder,
    supportRules = Registry.supportRules,
    supportRuleOrder = Registry.supportRuleOrder,
    rewardRules = Registry.rewardRules,
    rewardRuleOrder = Registry.rewardRuleOrder,
    recoveryRules = Registry.recoveryRules,
    recoveryRuleOrder = Registry.recoveryRuleOrder,
    ambushRules = Registry.ambushRules,
    ambushRuleOrder = Registry.ambushRuleOrder,
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

function Defs.classUnlock(id)
    return Defs.classUnlocks[id]
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

function Defs.factionPressureRule(id)
    return Defs.factionPressureRules[id]
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

function Defs.documentType(id)
    return Defs.documentTypes[id]
end

function Defs.documentRegistry(id)
    return Defs.documentRegistries[id]
end

function Defs.document(id)
    return Defs.documents[id]
end

function Defs.documentBank(id)
    return Defs.documentBanks[id]
end

function Defs.documentDropRule(id)
    return Defs.documentDropRules[id]
end

function Defs.fixtureDocumentBark(id)
    return Defs.fixtureDocumentBarks[id]
end

function Defs.glossary(id)
    return Defs.glossaryTerms[id]
end

function Defs.panelCopyFor(id)
    return Defs.panelCopy[id]
end

function Defs.fixtureVisitBark(id)
    return Defs.fixtureVisitBarks[id]
end

function Defs.enclaveLeaderBark(id)
    return Defs.enclaveLeaderBarks[id]
end

function Defs.wardenVoice(id)
    return Defs.wardenVoices[id]
end

function Defs.originBark(id)
    return Defs.originBarks[id]
end

function Defs.threatBehavior(id)
    return Defs.threatBehaviors[id]
end

function Defs.alphaRule(id)
    return Defs.alphaRules[id]
end

function Defs.scoutTooltip(id)
    return Defs.scoutTooltips[id]
end

function Defs.expeditionCommand(id)
    return Defs.expeditionCommands[id]
end

function Defs.pressureRule(id)
    return Defs.pressureRules[id]
end

function Defs.injuryCureTooltip(id)
    return Defs.injuryCureTooltips[id]
end

function Defs.weakPointRule(id)
    return Defs.weakPointRules[id]
end

function Defs.supportRule(id)
    return Defs.supportRules[id]
end

function Defs.rewardRule(id)
    return Defs.rewardRules[id]
end

function Defs.recoveryRule(id)
    return Defs.recoveryRules[id]
end

function Defs.ambushRule(id)
    return Defs.ambushRules[id]
end

function Defs.narrationFor(id)
    return Defs.narration[id]
end

return Defs
