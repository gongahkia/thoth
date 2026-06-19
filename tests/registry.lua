package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Defs = require("src.game.defs")

local function expect(value, message)
    if not value then
        error(message or "registry expectation failed", 2)
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

local function rankList(value, label)
    expect(type(value) == "table" and #value > 0, label .. " needs ranks")
    for _, rank in ipairs(value) do
        expect(type(rank) == "number" and rank >= 1 and rank <= 4, label .. " rank out of range")
    end
end

local function listHas(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

local rules = Defs.contentRules
expect(type(rules) == "table", "content rules missing")
for _, key in ipairs({ "global", "buried_archive", "salt_cistern", "ember_warrens", "estate", "encounter", "narration" }) do
    expect(type(rules.namingPrefixes[key]) == "string" and rules.namingPrefixes[key] ~= "", "naming prefix missing " .. key)
end
for _, key in ipairs({ "salvage", "medicine", "light", "key", "ritual_reagent" }) do
    expect(rules.itemTaxonomy[key] and rules.itemTaxonomy[key].role, "item taxonomy missing " .. key)
end
for _, key in ipairs({ "scout", "guard", "caster", "trapper", "swarm", "elite", "support", "alpha", "boss" }) do
    expect(rules.enemyRoleTaxonomy[key] and rules.enemyRoleTaxonomy[key].role, "enemy role taxonomy missing " .. key)
end
for _, key in ipairs({ "survey", "extract", "repair", "seal", "rescue", "cleanse", "activate", "boss" }) do
    expect(rules.missionTagTaxonomy[key] and rules.missionTagTaxonomy[key].role, "mission tag taxonomy missing " .. key)
end
for _, key in ipairs({ "safe_use", "greedy_use", "repair_use", "leave_alone" }) do
    expect(rules.curioOutcomeTaxonomy[key] and rules.curioOutcomeTaxonomy[key].role, "curio outcome taxonomy missing " .. key)
end

checkOrder("item", Defs.itemOrder, Defs.items)
checkOrder("trinket", Defs.trinketOrder, Defs.trinkets)
checkOrder("trinket set", Defs.trinketSetOrder, Defs.trinketSets)
checkOrder("quirk", Defs.quirkOrder, Defs.quirks)
checkOrder("disease", Defs.diseaseOrder, Defs.diseases)
checkOrder("injury", Defs.injuryOrder, Defs.injuries)
checkOrder("hero class", Defs.heroClassOrder, Defs.heroClasses)
expect(Defs.heroClass("mender").name == "Apothecary", "mender display name should be Apothecary")
expect(Defs.heroClass("harrier").name == "Thief", "harrier display name should be Thief")
checkOrder("skill", Defs.skillOrder, Defs.skills)
checkOrder("enemy skill", Defs.enemySkillOrder, Defs.enemySkills)
checkOrder("enemy", Defs.enemyOrder, Defs.enemies)
checkOrder("affliction", Defs.afflictionOrder, Defs.afflictions)
checkOrder("virtue", Defs.virtueOrder, Defs.virtues)
checkOrder("curio", Defs.curioOrder, Defs.curios)
checkOrder("encounter", Defs.encounterOrder, Defs.encounters)
checkOrder("location", Defs.locationOrder, Defs.locations)
checkOrder("mission", Defs.missionOrder, Defs.missions)
checkOrder("camp skill", Defs.campSkillOrder, Defs.campSkills)
checkOrder("estate building", Defs.estateBuildingOrder, Defs.estateBuildings)
checkOrder("estate activity", Defs.estateActivityOrder, Defs.estateActivities)
checkOrder("town event", Defs.townEventOrder, Defs.townEvents)
checkOrder("estate copy", Defs.estateCopyOrder, Defs.estateCopy)
checkOrder("class lore", Defs.classLoreOrder, Defs.classLore)
checkOrder("fixture", Defs.estateFixtureOrder, Defs.estateFixtures)
checkOrder("enclave leader", Defs.enclaveLeaderOrder, Defs.enclaveLeaders)
checkOrder("faction", Defs.factionOrder, Defs.factions)
checkOrder("dread rule", Defs.dreadRuleOrder, Defs.dreadRules)
checkOrder("campaign timer", Defs.campaignTimerOrder, Defs.campaignTimers)
checkOrder("ending route", Defs.endingRouteOrder, Defs.endingRoutes)
checkOrder("document type", Defs.documentTypeOrder, Defs.documentTypes)
checkOrder("document registry", Defs.documentRegistryOrder, Defs.documentRegistries)
checkOrder("document", Defs.documentOrder, Defs.documents)
checkOrder("document bank", Defs.documentBankOrder, Defs.documentBanks)
checkOrder("document drop rule", Defs.documentDropRuleOrder, Defs.documentDropRules)
checkOrder("fixture document bark", Defs.fixtureDocumentBarkOrder, Defs.fixtureDocumentBarks)
checkOrder("glossary term", Defs.glossaryTermOrder, Defs.glossaryTerms)
checkOrder("panel copy", Defs.panelCopyOrder, Defs.panelCopy)
checkOrder("fixture visit bark", Defs.fixtureVisitBarkOrder, Defs.fixtureVisitBarks)
checkOrder("enclave leader bark", Defs.enclaveLeaderBarkOrder, Defs.enclaveLeaderBarks)
checkOrder("warden voice", Defs.wardenVoiceOrder, Defs.wardenVoices)
checkOrder("origin bark", Defs.originBarkOrder, Defs.originBarks)
checkOrder("threat behavior", Defs.threatBehaviorOrder, Defs.threatBehaviors)
checkOrder("alpha rule", Defs.alphaRuleOrder, Defs.alphaRules)
checkOrder("scout tooltip", Defs.scoutTooltipOrder, Defs.scoutTooltips)
checkOrder("expedition command", Defs.expeditionCommandOrder, Defs.expeditionCommands)
checkOrder("pressure rule", Defs.pressureRuleOrder, Defs.pressureRules)
checkOrder("injury cure tooltip", Defs.injuryCureTooltipOrder, Defs.injuryCureTooltips)
checkOrder("weak point rule", Defs.weakPointRuleOrder, Defs.weakPointRules)
checkOrder("support rule", Defs.supportRuleOrder, Defs.supportRules)
checkOrder("reward rule", Defs.rewardRuleOrder, Defs.rewardRules)
checkOrder("recovery rule", Defs.recoveryRuleOrder, Defs.recoveryRules)
checkOrder("ambush rule", Defs.ambushRuleOrder, Defs.ambushRules)

for key, tile in pairs(Defs.tiles) do
    expect(tile.name and tile.name ~= "", "tile missing name " .. key)
    expect(type(tile.walkable) == "boolean", "tile missing walkable " .. key)
    expect(type(tile.color) == "table" and #tile.color == 3, "tile missing color " .. key)
    if tile.curio then
        expect(Defs.curio(tile.curio), "tile curio missing " .. tile.curio)
    end
    if tile.encounter then
        expect(Defs.encounter(tile.encounter), "tile encounter missing " .. tile.encounter)
    end
end

for key, item in pairs(Defs.items) do
    expect(item.name and item.name ~= "", "item missing name " .. key)
    expect(type(item.stack) == "number" and item.stack > 0, "item bad stack " .. key)
    if item.taxonomy then
        expect(rules.itemTaxonomy[item.taxonomy], "item taxonomy unknown " .. key)
    end
    if item.provision then
        expect(type(item.cost) == "number" and item.cost > 0, "provision missing cost " .. key)
    end
end
for _, taxonomy in ipairs({ "salvage", "medicine", "light", "key", "ritual_reagent" }) do
    local covered = false
    for _, item in pairs(Defs.items) do
        covered = covered or item.taxonomy == taxonomy
    end
    expect(covered, "item taxonomy unused " .. taxonomy)
end
expect(Defs.item("bait_chime").provision and Defs.item("bait_chime").taxonomy == "light", "bait chime provision missing")

for key, trinket in pairs(Defs.trinkets) do
    expect(trinket.name and trinket.name ~= "", "trinket missing name " .. key)
    expect(type(trinket.value) == "number" and trinket.value > 0, "trinket missing value " .. key)
end
for key, set in pairs(Defs.trinketSets) do
    expect(set.name and #set.pieces == 4, "trinket set missing pieces " .. key)
    for _, trinketKey in ipairs(set.pieces) do
        expect(Defs.trinket(trinketKey), "trinket set piece missing " .. key .. "/" .. trinketKey)
    end
    expect(set.twoPiece and set.fourPiece and set.cost, "trinket set effects missing " .. key)
end

for key, quirk in pairs(Defs.quirks) do
    expect(quirk.name and (quirk.kind == "positive" or quirk.kind == "negative"), "quirk missing data " .. key)
end
for _, key in ipairs({ "quirk_salt_marked", "quirk_stamp_shy", "quirk_vigil_held", "quirk_bound_by_page" }) do
    expect(Defs.quirk(key), "estate quirk missing " .. key)
end

for key, disease in pairs(Defs.diseases) do
    expect(disease.name and disease.name ~= "", "disease missing name " .. key)
end

for key, injury in pairs(Defs.injuries) do
    expect(injury.name and injury.name ~= "", "injury missing name " .. key)
end
for _, key in ipairs({ "crushed_hand", "salt_bloat", "glass_scarring", "nerve_burn" }) do
    expect(Defs.injury(key), "encounter injury missing " .. key)
end

do
    expect(Defs.threatBehavior("visible_threat_behaviors").call_help.encounter == "archive_ambush", "visible threat behavior missing")
    expect(Defs.alphaRule("alpha_marker").marker == "alpha", "alpha marker rule missing")
    expect(Defs.scoutTooltip("scout_odds_tooltip").low, "scout odds tooltip missing")
    expect(Defs.expeditionCommand("stealth_approach").torchCost == 10, "stealth approach command missing")
    expect(Defs.pressureRule("noise_decay").camp == 2, "noise decay rule missing")
    expect(Defs.injuryCureTooltip("injury_cure_tooltips").bandage, "injury cure tooltip missing")
    expect(Defs.weakPointRule("part_disable_log").includeDisabledSkill, "part disable log rule missing")
    expect(Defs.weakPointRule("weak_point_chain").disabledParts == 2, "weak point chain rule missing")
    expect(Defs.supportRule("part_repair_skill").heal == 4, "part repair skill rule missing")
    expect(Defs.rewardRule("alpha_reward").coin == 45 and Defs.rewardRule("merchant_cut").packDreadTier == 2, "reward rules missing")
    expect(Defs.recoveryRule("survivor_trinket_debt").trinkets == 1, "survivor trinket debt rule missing")
    expect(Defs.alphaRule("alpha_stalk_corridor").state == "stalked", "alpha stalk corridor rule missing")
    expect(Defs.ambushRule("camp_ambush_noise").encounter == "archive_ambush", "camp ambush noise rule missing")
    expect(Defs.ambushRule("stealth_downgrade").fullTorch == 70, "stealth downgrade rule missing")
end

for key, activity in pairs(Defs.estateActivities) do
    expect(activity.name and activity.cost and activity.stressHeal and activity.weeks, "estate activity missing data " .. key)
    expect(activity.cost >= 0 and activity.stressHeal > 0 and activity.weeks >= 1, "estate activity bad values " .. key)
end

for key, class in pairs(Defs.heroClasses) do
    expect(class.name and class.maxHp and class.speed and class.resolve, "class missing stats " .. key)
    expect(#class.skills == 3, "class should expose three v1 skills " .. key)
    for _, skillKey in ipairs(class.skills) do
        local skill = Defs.skill(skillKey)
        expect(skill and skill.class == key, "class skill mismatch " .. key .. "/" .. tostring(skillKey))
    end
end

for key, skill in pairs(Defs.skills) do
    expect(Defs.heroClass(skill.class), "skill class missing " .. key)
    rankList(skill.userRanks, "skill " .. key)
    expect(skill.target == "enemy" or skill.target == "ally" or skill.target == "self" or skill.target == "party", "skill bad target " .. key)
    if skill.target == "enemy" or skill.target == "ally" then
        rankList(skill.targetRanks, "skill target " .. key)
    end
    if skill.damage then
        expect(skill.damage[1] <= skill.damage[2] and skill.damage[1] > 0, "skill bad damage " .. key)
    end
    if skill.heal then
        expect(skill.heal[1] <= skill.heal[2] and skill.heal[1] > 0, "skill bad heal " .. key)
    end
end

for key, enemy in pairs(Defs.enemies) do
    expect(enemy.name and enemy.maxHp > 0 and enemy.speed >= 0, "enemy missing stats " .. key)
    expect(type(enemy.roles) == "table" and #enemy.roles > 0, "enemy missing roles " .. key)
    for _, role in ipairs(enemy.roles) do
        expect(rules.enemyRoleTaxonomy[role], "enemy role unknown " .. key .. "/" .. role)
    end
    expect(enemy.damage and enemy.damage[1] <= enemy.damage[2], "enemy bad damage " .. key)
    expect(enemy.bestiary and enemy.bestiary.behaviorHint and enemy.bestiary.weakPointHint, "enemy bestiary copy missing " .. key)
    expect(type(enemy.skills) == "table" and #enemy.skills > 0, "enemy missing skills " .. key)
    for _, skillKey in ipairs(enemy.skills) do
        expect(Defs.enemySkill(skillKey), "enemy references missing skill " .. skillKey)
    end
    for _, part in ipairs(enemy.parts or {}) do
        expect(part.key and part.name and part.hp > 0, "enemy part missing data " .. key)
        for _, skillKey in ipairs(part.skillLocks or {}) do
            expect(Defs.enemySkill(skillKey), "enemy part references missing skill " .. skillKey)
        end
    end
end
expect(#Defs.enemyOrder >= 26, "enemy roster should include expanded enemy types")
for _, role in ipairs({ "scout", "guard", "caster", "trapper", "swarm", "elite", "support", "alpha", "boss" }) do
    local covered = false
    for _, enemy in pairs(Defs.enemies) do
        covered = covered or listHas(enemy.roles or {}, role)
    end
    expect(covered, "enemy role unused " .. role)
end

for key, skill in pairs(Defs.enemySkills) do
    expect(skill.name and (skill.target == "hero" or skill.target == "party"), "enemy skill missing target " .. key)
    if skill.target == "hero" then
        rankList(skill.targetRanks, "enemy skill target " .. key)
    end
    if skill.damage then
        expect(skill.damage[1] <= skill.damage[2] and skill.damage[1] > 0, "enemy skill bad damage " .. key)
    end
    if skill.status then
        expect(skill.status.kind and skill.status.turns > 0, "enemy skill bad status " .. key)
    end
end

for key, curio in pairs(Defs.curios) do
    expect(curio.name and curio.name ~= "", "curio missing name " .. key)
    expect(type(curio.outcomes) == "table" and #curio.outcomes > 0, "curio missing outcomes " .. key)
    expect(curio.copy and curio.copy.observe and curio.copy.safe_use and curio.copy.greedy_use and curio.copy.repair_use and curio.copy.result, "curio copy missing " .. key)
    for _, outcome in ipairs(curio.outcomes) do
        expect(rules.curioOutcomeTaxonomy[outcome], "curio outcome unknown " .. key .. "/" .. outcome)
    end
    if curio.item then
        expect(Defs.item(curio.item), "curio item missing " .. curio.item)
    end
    if curio.questGather then
        expect(Defs.item(curio.questGather.item), "curio quest gather missing item " .. curio.questGather.item)
    end
    for item in pairs(curio.loot or {}) do
        expect(Defs.item(item), "curio loot missing item " .. item)
    end
end
for _, outcome in ipairs({ "safe_use", "greedy_use", "repair_use", "leave_alone" }) do
    local covered = false
    for _, curio in pairs(Defs.curios) do
        covered = covered or listHas(curio.outcomes or {}, outcome)
    end
    expect(covered, "curio outcome unused " .. outcome)
end

for key, encounter in pairs(Defs.encounters) do
    expect(#encounter > 0, "encounter empty " .. key)
    for _, enemyKey in ipairs(encounter) do
        expect(Defs.enemy(enemyKey), "encounter missing enemy " .. enemyKey)
    end
end

for key, location in pairs(Defs.locations) do
    expect(location.name and location.start and location.objectiveRooms > 0, "location missing data " .. key)
    expect(location.layout and #location.layout.rooms >= 7 and #location.layout.corridors > 0, "location missing layout " .. key)
    expect(Defs.tile(location.layout.floorTile), "location missing floor tile " .. key)
    expect(Defs.tile(location.layout.wallTile), "location missing wall tile " .. key)
    expect(Defs.tile(location.layout.corridorTile), "location missing corridor tile " .. key)
    if location.layout.generator then
        expect(location.layout.roles and location.layout.grammar and location.layout.templates, "generated location missing grammar data " .. key)
    end
    if location.layout.obstacleTile then
        expect(Defs.tile(location.layout.obstacleTile), "location missing obstacle tile " .. key)
    end
    expect(location.provisions and #location.provisions > 0, "location missing provision kit " .. key)
    for _, stack in ipairs(location.provisions or {}) do
        expect(Defs.item(stack.item) and Defs.item(stack.item).provision and stack.count > 0, "location bad provision kit " .. key)
    end
    for _, special in ipairs(location.layout.specials or {}) do
        expect(Defs.tile(special.tile), "location special missing tile " .. tostring(special.tile))
    end
    for _, encounterKey in pairs(location.encounters or {}) do
        expect(Defs.encounter(encounterKey), "location missing encounter " .. encounterKey)
    end
    for _, threat in ipairs(location.layout.threats or {}) do
        expect(threat.key and threat.roomRole and Defs.encounter(threat.encounter), "location bad threat " .. key)
    end
end

do
    local archive = Defs.location("buried_archive")
    for _, key in ipairs({ "intake_branch", "misfile_court", "sealed_register" }) do
        expect(archive.tiers[key], "archive tier missing " .. key)
    end
    expect(archive.tiers.intake_branch.unlock == "default", "archive tier I unlock missing")
    expect(archive.tiers.misfile_court.unlock == "first_archive_mission", "archive tier II unlock missing")
    expect(archive.tiers.sealed_register.unlock == "codex_reeve", "archive tier III warden unlock missing")
    for _, key in ipairs({
        "intake_desk", "debt_chancel", "misfiled_morgue", "evidence_well",
        "witness_drawer_court", "debt_vault", "bound_scriptorium", "sealed_atrium",
    }) do
        expect(archive.layout.roomTemplates[key], "archive room template missing " .. key)
    end
    for _, key in ipairs({ "audit_lane", "shelf_crawl", "writ_run" }) do
        expect(archive.layout.corridorRoles[key], "archive corridor role missing " .. key)
    end
    local threatKeys = {}
    for _, threat in ipairs(archive.layout.threats) do
        threatKeys[threat.key] = true
    end
    expect(threatKeys.shelf_warden and threatKeys.codex_reeve, "archive visible alpha threats missing")
    for _, key in ipairs({
        "archive_names", "archive_false_index", "archive_page_bearer", "archive_intake_map",
        "archive_audit_page_bearer", "archive_silence_reeve", "archive_witness_confession",
        "archive_remand_scribe", "archive_misfiled_dead",
    }) do
        expect(Defs.mission(key), "archive v2 mission missing " .. key)
    end
    for _, key in ipairs({
        "audit_hound", "vellum_leech", "staple_saint", "footnote_snare", "errata_twins",
        "shelf_warden", "codex_reeve", "margin_auditor", "bailiff_in_wax", "ink_drowner",
        "index_worm", "pressed_witness",
    }) do
        expect(Defs.enemy(key), "archive v2 enemy missing " .. key)
    end
    for _, key in ipairs({
        "witness_drawer", "clerk_cocoon", "name_press", "open_register", "stamped_confessional",
    }) do
        expect(Defs.curio(key), "archive v2 curio missing " .. key)
    end
    expect(Defs.trinket("wax_seal_remand") and Defs.trinket("copper_folio_hook"), "archive v2 trinkets missing")
    expect(Defs.narrationFor("archive_voice_v2"), "archive v2 narration missing")
    local ossuary = Defs.enemy("ossuary_lectern")
    expect(ossuary.parts[1].name == "Open Register" and ossuary.parts[2].name == "Rib Clasps", "archive ossuary weak-point names missing")
    local redRegent = Defs.enemy("regent_in_red")
    expect(redRegent and redRegent.boss and redRegent.parts[1].skillLocks[1] == "red_stress_clause", "regent in red weak point missing")
end

do
    local cistern = Defs.location("salt_cistern")
    expect(cistern.layout.grammar.id == "cistern_grammar_v1", "cistern grammar missing")
    for _, key in ipairs({ "pump_forest_tier", "drowned_market_tier", "deep_sluice_tier" }) do
        expect(cistern.tiers[key], "cistern tier missing " .. key)
    end
    expect(cistern.tiers.pump_forest_tier.unlock == "default", "cistern tier I unlock missing")
    expect(cistern.tiers.drowned_market_tier.unlock == "first_cistern_mission", "cistern tier II unlock missing")
    expect(cistern.tiers.deep_sluice_tier.unlock == "pearl_choir", "cistern tier III warden unlock missing")
    for _, key in ipairs({
        "pump_forest", "brine_intake", "drowned_market", "sluice_chapel",
        "cyst_chamber", "filter_shrine", "bell_diver_gate",
    }) do
        expect(cistern.layout.roomTemplates[key], "cistern room template missing " .. key)
    end
    for _, key in ipairs({ "pressure_walk", "maintenance_siphon", "undertow_walk" }) do
        expect(cistern.layout.corridorRoles[key], "cistern corridor role missing " .. key)
    end
    local threatKeys = {}
    for _, threat in ipairs(cistern.layout.threats) do
        threatKeys[threat.key] = true
    end
    expect(threatKeys.depth_bailiff and threatKeys.pearl_choir, "cistern visible alpha threats missing")
    for _, key in ipairs({
        "cistern_low_reservoir", "cistern_salt_register", "cistern_gatekeepers",
        "cistern_silence_choir", "cistern_drain_market", "cistern_tov_child",
        "cistern_flood_bailiff", "cistern_open_deep_sluice",
    }) do
        expect(Defs.mission(key), "cistern v2 mission missing " .. key)
    end
    for _, key in ipairs({
        "valve_thrall", "brine_midwife", "sluice_eel", "salt_choir", "pearl_cyst",
        "depth_bailiff", "pearl_choir", "halocline_tender", "drowned_pilgrim",
        "reed_mouth_diver", "silt_mother", "cyst_burst",
    }) do
        expect(Defs.enemy(key), "cistern v2 enemy missing " .. key)
    end
    for _, key in ipairs({ "shutoff_shrine", "silted_cradle", "pressure_bell", "brine_reliquary" }) do
        expect(Defs.curio(key), "cistern v2 curio missing " .. key)
    end
    expect(Defs.trinket("filtered_tooth"), "cistern trinket missing")
    expect(Defs.narrationFor("cistern_voice_v2"), "cistern narration missing")
    local floodToll = Defs.enemy("bell_diver_flood_toll")
    expect(floodToll and floodToll.boss and floodToll.parts[1].key == "bell_lung", "bell diver flood-toll weak point missing")
end

do
    local ember = Defs.location("ember_warrens")
    expect(ember.layout.grammar.id == "ember_grammar_v1", "ember grammar missing")
    for _, key in ipairs({ "fuel_branch_tier", "vitrified_cloister_tier", "white_furnace_tier" }) do
        expect(ember.tiers[key], "ember tier missing " .. key)
    end
    expect(ember.tiers.fuel_branch_tier.unlock == "default", "ember tier I unlock missing")
    expect(ember.tiers.vitrified_cloister_tier.unlock == "first_ember_mission", "ember tier II unlock missing")
    expect(ember.tiers.white_furnace_tier.unlock == "kiln_vicar", "ember tier III warden unlock missing")
    for _, key in ipairs({
        "kiln_nave", "vitrified_dormitory", "ash_confessional", "bellows_choir",
        "vitrifying_procession", "ash_archive", "furnace_antechamber",
    }) do
        expect(ember.layout.roomTemplates[key], "ember room template missing " .. key)
    end
    for _, key in ipairs({ "clinker_run", "bellows_spine", "soot_creep" }) do
        expect(ember.layout.corridorRoles[key], "ember corridor role missing " .. key)
    end
    local threatKeys = {}
    for _, threat in ipairs(ember.layout.threats) do
        threatKeys[threat.key] = true
    end
    expect(threatKeys.white_furnace and threatKeys.kiln_vicar, "ember visible alpha threats missing")
    for _, key in ipairs({
        "ember_vow_kilns", "ember_ash_names", "ember_warm_dead",
        "warrens_douse_vicar", "warrens_burn_false_vow", "warrens_warm_ledger",
        "warrens_aron_boy", "warrens_open_furnace",
    }) do
        expect(Defs.mission(key), "ember v2 mission missing " .. key)
    end
    for _, key in ipairs({
        "kiln_nurse", "glass_penitent", "ash_wasp_cloud", "bellows_acolyte",
        "clinker_butcher", "white_furnace", "kiln_vicar", "vow_burned_friar",
        "slag_bearer", "char_mouth_pup", "glass_choirmaster", "cinder_penitent",
        "cinder_prioress_glass",
    }) do
        expect(Defs.enemy(key), "ember v2 enemy missing " .. key)
    end
    for _, key in ipairs({ "ash_lung_reliquary", "fuse_saint", "halo_vent", "vitrified_cot" }) do
        expect(Defs.curio(key), "ember v2 curio missing " .. key)
    end
    expect(Defs.trinket("cinder_lens"), "ember trinket missing")
    expect(Defs.narrationFor("ember_voice_v2"), "ember narration missing")
    local prioress = Defs.enemy("cinder_prioress_glass")
    expect(prioress and prioress.boss and prioress.parts[1].key == "halo_vent", "cinder prioress glass weak point missing")
end

for key, mission in pairs(Defs.missions) do
    expect(mission.name and Defs.location(mission.location), "mission missing location " .. key)
    expect(mission.kind == "scout" or mission.kind == "cleanse" or mission.kind == "boss" or mission.kind == "gather" or mission.kind == "activate", "mission bad kind " .. key)
    expect(type(mission.tags) == "table" and #mission.tags > 0, "mission missing tags " .. key)
    for _, tag in ipairs(mission.tags) do
        expect(rules.missionTagTaxonomy[tag], "mission tag unknown " .. key .. "/" .. tag)
    end
    expect(mission.difficulty == "apprentice" or mission.difficulty == "veteran" or mission.difficulty == "champion", "mission bad difficulty " .. key)
    expect(mission.resolveLevel == 1 or mission.resolveLevel == 3 or mission.resolveLevel == 5, "mission bad resolve level " .. key)
    for item in pairs(mission.objectiveItems or {}) do
        expect(Defs.item(item), "mission objective missing item " .. item)
    end
    for _, stack in ipairs(mission.questProvision or {}) do
        expect(Defs.item(stack.item) and stack.count > 0, "mission quest provision invalid " .. tostring(stack.item))
    end
    expect(mission.intro and mission.intro.brief and mission.intro.sting, "mission intro missing " .. key)
    if mission.reward and mission.reward.trinket then
        expect(Defs.trinket(mission.reward.trinket), "mission reward missing trinket " .. mission.reward.trinket)
    end
    if mission.kind == "boss" then
        expect(Defs.encounter(mission.bossEncounter), "mission boss encounter missing " .. key)
        expect(Defs.encounter(mission.bossVariantEncounter), "mission boss variant missing " .. key)
        expect(type(mission.variantDread) == "number", "mission boss variant dread missing " .. key)
    end
end

for key, skill in pairs(Defs.campSkills) do
    expect(skill.name and skill.cost >= 0, "camp skill missing data " .. key)
    expect(skill.target == "ally" or skill.target == "party", "camp skill bad target " .. key)
    for item in pairs(skill.itemCost or {}) do
        expect(Defs.item(item), "camp skill item cost missing item " .. item)
    end
    if skill.trinketCost then
        expect(skill.trinketCost > 0, "camp skill bad trinket cost " .. key)
    end
    for factionKey in pairs(skill.factionCost or {}) do
        expect(Defs.faction(factionKey), "camp skill faction cost missing faction " .. key .. "/" .. factionKey)
    end
end
for _, key in ipairs({ "camp_witness_vigil", "camp_salt_wash", "camp_ember_quench", "audit_books", "cancel_debt" }) do
    expect(Defs.campSkill(key), "estate camp ritual missing " .. key)
end

for key, building in pairs(Defs.estateBuildings) do
    expect(building.name and building.maxLevel >= 1 and building.heirloomCost >= 0, "building missing data " .. key)
end

for key, event in pairs(Defs.townEvents) do
    expect(event.name and event.name ~= "", "town event missing name " .. key)
    expect(event.summary and #event.summary >= 40 and event.effect and event.effect ~= "", "town event missing polished copy " .. key)
    for item in pairs(event.provisions or {}) do
        expect(Defs.item(item), "town event provision missing item " .. item)
    end
    if event.heirlooms then
        expect(type(event.heirlooms) == "number", "town event bad heirlooms " .. key)
    end
    if event.openMission then
        expect(Defs.mission(event.openMission), "town event open mission missing " .. key)
    end
    for factionKey in pairs(event.faction or {}) do
        expect(Defs.faction(factionKey), "town event faction missing " .. key .. "/" .. factionKey)
    end
end
for _, key in ipairs({
    "survey_quota", "enclave_petition", "archive_tithe_v2", "salt_rationing", "ash_vigil_demand",
    "audit_notice", "lamplighter_strike", "drowned_banns", "pyre_demand", "estate_reckoning", "enclave_compact_signed",
}) do
    expect(Defs.townEvent(key), "estate town event missing " .. key)
end

expect(Defs.estateCopyFor("survey_office_copy"), "survey office copy missing")
expect(Defs.classLoreBank("class_origins") and Defs.barkBank("recruit_barks") and Defs.epitaphBank("zone_epitaphs"), "estate lore bank ids missing")
for _, classKey in ipairs(Defs.heroClassOrder) do
    expect(Defs.classLoreFor(classKey) and Defs.recruitBarksFor(classKey), "class lore/barks missing " .. classKey)
end
expect(Defs.classLoreFor("merchant").origin:find("debt", 1, true), "merchant class lore missing")
for _, key in ipairs(Defs.graveyardEpitaphOrder) do
    expect(#Defs.graveyardEpitaphsFor(key) >= 2, "graveyard epitaphs missing " .. key)
end
for _, key in ipairs(Defs.estateFixtureOrder) do
    local fixture = Defs.estateFixture(key)
    expect(fixture and #fixture.barks >= 2, "estate fixture barks missing " .. key)
    expect(fixture.barks[1] ~= fixture.barks[2], "estate fixture visit barks should be unique " .. key)
end
for _, key in ipairs(Defs.enclaveLeaderOrder) do
    local leader = Defs.enclaveLeader(key)
    expect(leader and Defs.location(leader.zone) and leader.branch and #leader.barks >= 4, "enclave leader bad data " .. key)
    local seenBarks = {}
    for _, bark in ipairs(leader.barks) do
        expect(bark ~= "" and not seenBarks[bark], "enclave leader duplicate/empty bark " .. key)
        seenBarks[bark] = true
    end
end
for _, key in ipairs(Defs.factionOrder) do
    local faction = Defs.faction(key)
    expect(faction and #faction.states >= 3, "faction states missing " .. key)
end
for key, documentType in pairs(Defs.documentTypes) do
    expect(documentType.name and (documentType.location == "global" or Defs.location(documentType.location)), "document type bad data " .. key)
end
expect(#Defs.documentTypeOrder == 5 and Defs.documentRegistry("document_registry_v1"), "document registry missing")
for key, document in pairs(Defs.documents) do
    expect(document.title and document.abstract and document.text, "document missing copy " .. key)
    expect(#document.text >= 120 and document.text ~= document.abstract, "document body copy too thin " .. key)
    expect(Defs.documentType(document.type), "document type missing " .. key)
    expect(Defs.location(document.location), "document location missing " .. key)
end
expect(#Defs.documentOrder == 27, "document bank should expose 27 documents")
for key, bank in pairs(Defs.documentBanks) do
    expect(Defs.location(bank.location) and #bank.documents == 9, "document bank bad data " .. key)
    for _, documentKey in ipairs(bank.documents) do
        expect(Defs.document(documentKey), "document bank missing document " .. documentKey)
    end
end
expect(Defs.documentBank("archive_documents_v1").documents[1] == "archive_writ_01", "archive document bank missing")
expect(Defs.documentBank("cistern_documents_v1").documents[1] == "cistern_valve_01", "cistern document bank missing")
expect(Defs.documentBank("warrens_documents_v1").documents[1] == "warrens_confession_01", "warrens document bank missing")
local dropRule = Defs.documentDropRule("document_drop_rules")
expect(dropRule.curio and dropRule.roomLoot and dropRule.warden and dropRule.bankByLocation.buried_archive == "archive_documents_v1", "document drop rule missing")
local fixtureBarks = Defs.fixtureDocumentBark("fixture_document_barks")
for _, typeKey in ipairs(Defs.documentTypeOrder) do
    local bark = fixtureBarks[typeKey]
    expect(bark and Defs.estateFixture(bark.fixture) and bark.text ~= "", "fixture document bark missing " .. typeKey)
end
local glossary = Defs.glossary("terms_v1")
for _, key in ipairs({ "dread", "noise", "injury", "alpha", "repair", "extraction" }) do
    expect(glossary[key] and glossary[key] ~= "", "glossary term missing " .. key)
end
expect(Defs.panelCopyFor("faction_panel_copy").body and Defs.panelCopyFor("timer_panel_copy").body, "panel copy missing")
local endingCopy = Defs.panelCopyFor("ending_screen_copy")
for _, key in ipairs(Defs.endingRouteOrder) do
    expect(endingCopy[key], "ending screen copy missing " .. key)
end
expect(Defs.fixtureVisitBark("fixture_visit_barks").greeting and Defs.fixtureVisitBark("fixture_visit_barks").farewell, "fixture visit barks missing")
expect(Defs.fixtureVisitBark("fixture_visit_barks").greeting ~= Defs.fixtureVisitBark("fixture_visit_barks").farewell, "fixture visit greeting/farewell should differ")
expect(Defs.enclaveLeaderBark("enclave_leader_barks").low and Defs.enclaveLeaderBark("enclave_leader_barks").high, "enclave leader barks missing")
local wardenVoice = Defs.wardenVoice("warden_voice_v1")
for _, key in ipairs({ "codex_reeve", "pearl_choir", "kiln_vicar" }) do
    expect(wardenVoice[key] and wardenVoice[key].intro and wardenVoice[key].defeat, "warden voice missing " .. key)
end
local originBarks = Defs.originBark("origin_barks_v1")
for _, classKey in ipairs(Defs.heroClassOrder) do
    local bark = originBarks[classKey]
    expect(bark and bark.arrival and bark.firstDeath and bark.factionShift, "origin bark missing " .. classKey)
end
local dreadRules = Defs.dreadRule("dread_rules_v1")
for _, key in ipairs({ "greedy_extract", "hero_death", "abandoned_mission", "repair_mission", "vigil", "enclave_compact" }) do
    expect(type(dreadRules[key]) == "number", "dread rule missing " .. key)
end
expect(Defs.campaignTimer("twin_timer_v1").weekCap == 14 and Defs.campaignTimer("twin_timer_v1").dreadCap == 18, "twin timer caps missing")
expect(Defs.endingRouter("ending_router") and #Defs.endingRouter("ending_router").routes == 4, "ending router missing")
for _, key in ipairs({ "estate_seal", "repair_compact", "extraction_collapse", "quiet_failure" }) do
    expect(Defs.endingRoute(key), "ending route missing " .. key)
end

for _, key in ipairs(Defs.narrationOrder) do
    local lines = Defs.narrationFor(key)
    expect(lines and #lines >= 2, "narration missing lines " .. key)
    for index, line in ipairs(lines) do
        expect(type(line) == "table" and line.id and line.text, "narration line missing id/text " .. key)
        expect(line.id:match("^nar_"), "narration id missing prefix " .. key .. "/" .. tostring(index))
        expect(line.text ~= "", "narration line empty " .. key .. "/" .. tostring(index))
    end
end

local todo = assert(io.open("TODO.md", "r"))
for line in todo:lines() do
    local hasContentMetadata = line:match("%+%w+") or line:match("@%w+") or line:match("type:%w+") or line:match("zone:%w+") or line:match("id:[%w_]+")
    if line:match("^%- %[[ xX]%]") and hasContentMetadata then
        expect(line:match("%+%w+"), "TODO task missing +Project metadata")
        expect(line:match("@%w+"), "TODO task missing @context metadata")
        expect(line:match("type:%w+"), "TODO task missing type metadata")
        expect(line:match("zone:%w+"), "TODO task missing zone metadata")
        expect(line:match("id:[%w_]+"), "TODO task missing id metadata")
    end
end
todo:close()

print("registry checks passed")
