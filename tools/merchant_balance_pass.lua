package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Defs = require("src.game.defs")
local Simulation = require("src.game.simulation")

local function contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
end

local function copyList(list)
    local result = {}
    for index, value in ipairs(list or {}) do
        result[index] = value
    end
    return result
end

local function className(classKey)
    return (Defs.heroClass(classKey) or {}).name or classKey
end

local function configureHero(sim, rank, classKey, level, stress)
    local hero = sim:heroAtRank(rank)
    local class = Defs.heroClass(classKey)
    assert(hero and class, "bad hero config")
    hero.class = classKey
    hero.name = className(classKey)
    hero.level = level
    hero.xp = 0
    hero.weapon = math.max(0, level - 1)
    hero.armor = math.max(0, level - 1)
    hero.skills = copyList(class.skills)
    hero.skillLevels = {}
    for _, skillKey in ipairs(hero.skills) do
        hero.skillLevels[skillKey] = level
    end
    hero.hp = sim:maxHp(hero)
    hero.stress = stress or 0
    hero.alive = true
    hero.deathsDoor = false
    hero.guard = 0
    hero.statuses = {}
    hero.affliction = nil
    hero.virtue = nil
end

local function configureParty(sim, classes, level, stress)
    for rank, classKey in ipairs(classes) do
        configureHero(sim, rank, classKey, level, stress)
    end
end

local function enemyMaxHp(enemy)
    return ((enemy and Defs.enemy(enemy.kind)) or {}).maxHp or 1
end

local function activePart(enemy)
    for _, part in ipairs((enemy and enemy.parts) or {}) do
        if not part.disabled and (part.hp or 0) > 0 then
            return part.key
        end
    end
    return nil
end

local function lowestHpAllyRank(sim, skill, kind)
    local bestRank = nil
    local bestScore = -1
    for rank = 1, 4 do
        if contains(skill.targetRanks, rank) then
            local hero = sim:heroAtRank(rank)
            if hero and hero.alive then
                local maxHp = sim:maxHp(hero)
                local score = 0
                if kind == "stress" then
                    score = hero.stress or 0
                else
                    score = maxHp - (hero.hp or maxHp)
                end
                if score > bestScore then
                    bestScore = score
                    bestRank = rank
                end
            end
        end
    end
    return bestRank, bestScore
end

local function enemyActions(sim, heroRank, skillKey, skill)
    local actions = {}
    for rank = 1, 4 do
        if contains(skill.targetRanks, rank) then
            local enemy = sim:enemyAtRank(rank)
            if enemy then
                local def = Defs.enemy(enemy.kind) or {}
                local partKey = (skill.damage or skill.stressDamage) and activePart(enemy) or nil
                local missing = enemyMaxHp(enemy) - (enemy.hp or 0)
                local score = 40 + missing
                if def.boss then
                    score = score + 25
                end
                if contains(def.roles, "support") or def.supportHeal or def.supportStressRestore then
                    score = score + 90
                end
                if def.armor and def.armor > 0 then
                    score = score + 10
                end
                if skill.status and skill.status.kind == "marked" then
                    if sim:hasStatus(enemy, "marked") then
                        score = score - 40
                    else
                        score = score + 30
                    end
                end
                if skill.damage or skill.stressDamage then
                    local lowRoll = (skill.damage and skill.damage[1] or 0) + (skill.stressDamage or 0) + math.max(0, (sim:heroAtRank(heroRank).weapon or 0))
                    if lowRoll >= (enemy.hp or 0) then
                        score = score + 45
                    end
                    if partKey then
                        score = score + 35
                    end
                end
                actions[#actions + 1] = { score = score, skill = skillKey, targetRank = rank, side = "enemy", partKey = partKey }
            end
        end
    end
    return actions
end

local function legalActions(sim)
    local hero = sim:activeHero()
    if not hero then
        return {}
    end
    local heroRank = sim:heroRank(hero.id)
    local actions = {}
    for _, skillKey in ipairs(hero.skills or {}) do
        local skill = Defs.skill(skillKey)
        if skill and skill.class == hero.class and contains(skill.userRanks, heroRank) then
            if skill.target == "enemy" then
                local enemyChoices = enemyActions(sim, heroRank, skillKey, skill)
                for _, action in ipairs(enemyChoices) do
                    actions[#actions + 1] = action
                end
            elseif skill.target == "ally" then
                local healRank, missingHp = lowestHpAllyRank(sim, skill, "hp")
                if healRank and skill.heal and missingHp >= 10 then
                    actions[#actions + 1] = { score = 55 + missingHp, skill = skillKey, targetRank = healRank, side = "ally" }
                end
                local stressRank, stress = lowestHpAllyRank(sim, skill, "stress")
                if stressRank and skill.stressHeal and stress >= 55 then
                    actions[#actions + 1] = { score = 35 + stress, skill = skillKey, targetRank = stressRank, side = "ally" }
                end
            elseif skill.target == "party" then
                local stress = 0
                for rank = 1, 4 do
                    local ally = sim:heroAtRank(rank)
                    if ally and ally.alive then
                        stress = stress + (ally.stress or 0)
                    end
                end
                if skill.stressHeal and stress >= 160 then
                    actions[#actions + 1] = { score = 45 + stress, skill = skillKey }
                end
                if skill.torch and sim.expedition and (sim.expedition.torch or 0) <= 45 then
                    actions[#actions + 1] = { score = 60, skill = skillKey }
                end
            else
                local score = skill.guard and 12 or 20
                if skill.stressHeal and (hero.stress or 0) >= 8 then
                    score = score + math.floor((hero.stress or 0) / 2)
                end
                actions[#actions + 1] = { score = score, skill = skillKey }
            end
        end
    end
    table.sort(actions, function(a, b)
        if a.score == b.score then
            return a.skill < b.skill
        end
        return a.score > b.score
    end)
    return actions
end

local function resolveCombat(sim, encounterKey, roomKey)
    assert(sim:startCombat(encounterKey, roomKey), "combat failed to start: " .. encounterKey)
    local turns = 0
    while sim.mode == "combat" and sim.combat do
        turns = turns + 1
        if turns > 220 then
            io.stderr:write("timeout=", encounterKey, "\n")
            for index, enemy in ipairs(sim.combat.enemies or {}) do
                local def = Defs.enemy(enemy.kind) or {}
                local parts = {}
                for _, part in ipairs(enemy.parts or {}) do
                    parts[#parts + 1] = part.key .. ":" .. tostring(part.hp) .. ":" .. tostring(part.disabled)
                end
                io.stderr:write("enemy", index, "=", enemy.kind, " rank=", tostring(enemy.rank), " hp=", tostring(enemy.hp), " roles=", table.concat(def.roles or {}, ","), " parts=", table.concat(parts, ","), "\n")
            end
            for rank = 1, 4 do
                local hero = sim:heroAtRank(rank)
                if hero then
                    io.stderr:write("hero", rank, "=", hero.class, " hp=", tostring(hero.hp), " stress=", tostring(hero.stress), "\n")
                end
            end
            local firstLog = math.max(1, #(sim.log or {}) - 20)
            for index = firstLog, #(sim.log or {}) do
                io.stderr:write("log", index, "=", tostring(sim.log[index]), "\n")
            end
            error("combat timeout: " .. encounterKey)
        end
        local actions = legalActions(sim)
        local acted = false
        for _, action in ipairs(actions) do
            if sim:combatSkill(action.skill, action.targetRank, action.side, action.partKey) then
                acted = true
                break
            end
        end
        if not acted then
            assert(sim:passTurn(), "pass turn failed")
        end
    end
    return turns, sim.mode == "expedition"
end

local scenarios = {
    { id = "archive_t1_entry", seed = 6101, level = 1, dread = 0, mission = "archive_cleansing", encounters = { "entry", "stacks" }, merchant = { "warden", "duelist", "mender", "merchant" }, baseline = { "warden", "duelist", "mender", "harrier" } },
    { id = "archive_t1_pack", seed = 6102, level = 1, dread = 9, mission = "archive_cleansing", encounters = { "entry", "archive_branch" }, merchant = { "warden", "duelist", "mender", "merchant" }, baseline = { "warden", "duelist", "mender", "harrier" } },
    { id = "archive_t3_reeve", seed = 6103, level = 3, dread = 4, mission = "archive_silence_reeve", encounters = { "archive_reeve" }, merchant = { "warden", "duelist", "chirurgeon", "merchant" }, baseline = { "warden", "duelist", "chirurgeon", "arcanist" } },
    { id = "archive_t3_witness", seed = 6104, level = 3, dread = 9, mission = "archive_witness_confession", encounters = { "archive_witness", "archive_bailiff" }, merchant = { "warden", "duelist", "mender", "merchant" }, baseline = { "warden", "duelist", "mender", "arcanist" } },
    { id = "archive_t3_regent", seed = 6105, level = 3, dread = 9, mission = "archive_regent", encounters = { "regent" }, merchant = { "warden", "duelist", "mender", "merchant" }, baseline = { "warden", "duelist", "mender", "arcanist" } },
    { id = "cistern_t3_choir", seed = 6106, level = 3, dread = 9, mission = "cistern_silence_choir", encounters = { "cistern_choir" }, merchant = { "warden", "exile", "chirurgeon", "merchant" }, baseline = { "warden", "exile", "chirurgeon", "lamplighter" } },
    { id = "cistern_t3_bell", seed = 6107, level = 3, dread = 13, mission = "cistern_bell", encounters = { "matron" }, merchant = { "warden", "duelist", "mender", "merchant" }, baseline = { "warden", "duelist", "mender", "lamplighter" } },
    { id = "ember_t5_route", seed = 6108, level = 5, dread = 13, mission = "ember_cleansing", encounters = { "ember_entry", "ember_branch" }, merchant = { "exile", "duelist", "chirurgeon", "merchant" }, baseline = { "exile", "duelist", "chirurgeon", "lamplighter" } },
    { id = "ember_t5_vicar", seed = 6109, level = 5, dread = 16, mission = "warrens_douse_vicar", encounters = { "ember_vicar" }, merchant = { "warden", "exile", "mender", "merchant" }, baseline = { "warden", "exile", "mender", "lamplighter" } },
    { id = "ember_t5_prioress", seed = 6110, level = 5, dread = 18, dreadLimit = 20, mission = "ember_prioress", encounters = { "prioress_ember" }, merchant = { "warden", "duelist", "chirurgeon", "merchant" }, baseline = { "warden", "duelist", "chirurgeon", "lamplighter" } },
}

local function runScenario(row, kind)
    local sim = Simulation.new(row.seed + (kind == "merchant" and 1000 or 2000), { startInEstate = true })
    sim.estate.campaign.dreadLimit = row.dreadLimit or 18
    sim.estate.campaign.dread = row.dread or 0
    sim.estate.campaign.flags.merchant_ledger_accepted = kind == "merchant" or nil
    configureParty(sim, row[kind], row.level, row.startStress or 0)
    assert(sim:startExpedition(row.mission), "mission failed to start: " .. row.mission)
    local packSlots = sim.expedition.packSlots
    local packCut = sim.expedition.merchantCutPackApplied == true
    local turns = 0
    for index, encounterKey in ipairs(row.encounters) do
        local combatTurns, won = resolveCombat(sim, encounterKey, row.id .. "_" .. index)
        turns = turns + combatTurns
        assert(won, "combat lost: " .. row.id .. " " .. encounterKey)
    end
    assert(sim.expedition.objectiveComplete, "objective incomplete: " .. row.id)
    local loot = sim.expedition.loot:count("coin")
    local relic = sim.expedition.loot:count("relic")
    local lootCut = sim.expedition.merchantCutLootClaimed == true
    assert(sim:endExpedition(false), "end expedition failed: " .. row.id)
    local deaths = #sim.estate.graveyard
    local maxStress = 0
    local minHpPct = 100
    for rank = 1, 4 do
        local hero = sim:heroAtRank(rank)
        if hero then
            maxStress = math.max(maxStress, hero.stress or 0)
            minHpPct = math.min(minHpPct, math.floor(((hero.hp or 0) / sim:maxHp(hero)) * 100))
        end
    end
    local success = sim.estate.campaign.completedMissions[row.mission] == true
    return {
        id = row.id,
        kind = kind,
        seed = row.seed + (kind == "merchant" and 1000 or 2000),
        mission = row.mission,
        level = row.level,
        dread = row.dread,
        turns = turns,
        success = success,
        deaths = deaths,
        maxStress = maxStress,
        minHpPct = minHpPct,
        loot = loot,
        relic = relic,
        packSlots = packSlots,
        packCut = packCut,
        lootCut = lootCut,
    }
end

local results = {}
for _, scenario in ipairs(scenarios) do
    results[#results + 1] = runScenario(scenario, "merchant")
    results[#results + 1] = runScenario(scenario, "baseline")
end

local failures = 0
for _, result in ipairs(results) do
    if not result.success or result.deaths > 0 then
        failures = failures + 1
    end
end

print("merchant_balance_pass=" .. (failures == 0 and "ok" or "failed"))
print("passes=" .. tostring(#results))
print("merchant_passes=10")
print("baseline_passes=10")
print("failures=" .. tostring(failures))
print("")
print("| id | kind | seed | mission | lvl | dread | turns | hp% min | stress max | loot | pack | cut |")
print("|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|")
for _, result in ipairs(results) do
    local cut = {}
    if result.packCut then
        cut[#cut + 1] = "pack"
    end
    if result.lootCut then
        cut[#cut + 1] = "loot"
    end
    print(string.format(
        "| %s | %s | %d | %s | %d | %d | %d | %d | %d | %d+%dr | %d | %s |",
        result.id,
        result.kind,
        result.seed,
        result.mission,
        result.level,
        result.dread,
        result.turns,
        result.minHpPct,
        result.maxStress,
        result.loot,
        result.relic,
        result.packSlots,
        #cut > 0 and table.concat(cut, ",") or "-"
    ))
end

assert(failures == 0, "balance pass failures: " .. tostring(failures))
