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

checkOrder("item", Defs.itemOrder, Defs.items)
checkOrder("trinket", Defs.trinketOrder, Defs.trinkets)
checkOrder("quirk", Defs.quirkOrder, Defs.quirks)
checkOrder("hero class", Defs.heroClassOrder, Defs.heroClasses)
checkOrder("skill", Defs.skillOrder, Defs.skills)
checkOrder("enemy skill", Defs.enemySkillOrder, Defs.enemySkills)
checkOrder("enemy", Defs.enemyOrder, Defs.enemies)
checkOrder("affliction", Defs.afflictionOrder, Defs.afflictions)
checkOrder("curio", Defs.curioOrder, Defs.curios)
checkOrder("encounter", Defs.encounterOrder, Defs.encounters)
checkOrder("location", Defs.locationOrder, Defs.locations)
checkOrder("mission", Defs.missionOrder, Defs.missions)
checkOrder("camp skill", Defs.campSkillOrder, Defs.campSkills)
checkOrder("estate building", Defs.estateBuildingOrder, Defs.estateBuildings)

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
end

for key, trinket in pairs(Defs.trinkets) do
    expect(trinket.name and trinket.name ~= "", "trinket missing name " .. key)
end

for key, quirk in pairs(Defs.quirks) do
    expect(quirk.name and (quirk.kind == "positive" or quirk.kind == "negative"), "quirk missing data " .. key)
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
    expect(enemy.damage and enemy.damage[1] <= enemy.damage[2], "enemy bad damage " .. key)
    expect(type(enemy.skills) == "table" and #enemy.skills > 0, "enemy missing skills " .. key)
    for _, skillKey in ipairs(enemy.skills) do
        expect(Defs.enemySkill(skillKey), "enemy references missing skill " .. skillKey)
    end
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
    if curio.item then
        expect(Defs.item(curio.item), "curio item missing " .. curio.item)
    end
    for item in pairs(curio.loot or {}) do
        expect(Defs.item(item), "curio loot missing item " .. item)
    end
end

for key, encounter in pairs(Defs.encounters) do
    expect(#encounter > 0, "encounter empty " .. key)
    for _, enemyKey in ipairs(encounter) do
        expect(Defs.enemy(enemyKey), "encounter missing enemy " .. enemyKey)
    end
end

for key, location in pairs(Defs.locations) do
    expect(location.name and location.start and location.objectiveRooms > 0, "location missing data " .. key)
    for _, encounterKey in pairs(location.encounters or {}) do
        expect(Defs.encounter(encounterKey), "location missing encounter " .. encounterKey)
    end
end

for key, mission in pairs(Defs.missions) do
    expect(mission.name and Defs.location(mission.location), "mission missing location " .. key)
    expect(mission.kind == "scout" or mission.kind == "cleanse" or mission.kind == "boss", "mission bad kind " .. key)
    if mission.reward and mission.reward.trinket then
        expect(Defs.trinket(mission.reward.trinket), "mission reward missing trinket " .. mission.reward.trinket)
    end
end

for key, skill in pairs(Defs.campSkills) do
    expect(skill.name and skill.cost >= 0, "camp skill missing data " .. key)
    expect(skill.target == "ally" or skill.target == "party", "camp skill bad target " .. key)
end

for key, building in pairs(Defs.estateBuildings) do
    expect(building.name and building.maxLevel >= 1 and building.heirloomCost >= 0, "building missing data " .. key)
end

print("registry checks passed")
