-- estate persistence layer: roster, memorial, recruits, economy, post-mission ingestion
local Registry = require("src.game.data.registry")
local Bonds = require("src.game.tactics.bonds")
local Identity = require("src.game.tactics.identity")
local Rng = require("src.core.rng")

local Estate = {}

Estate.startingGold = 100
Estate.startingHeirlooms = 0
Estate.startingDread = 0

local function copyList(values)
    local result = {}
    for _, v in ipairs(values or {}) do result[#result + 1] = v end
    return result
end

local function copyMap(values)
    local result = {}
    for k, v in pairs(values or {}) do result[k] = v end
    return result
end

function Estate.new(options)
    options = options or {}
    return {
        gold = options.gold or Estate.startingGold,
        heirlooms = options.heirlooms or Estate.startingHeirlooms,
        dread = options.dread or Estate.startingDread,
        week = options.week or 0,
        roster = {}, -- unitId -> persistent unit record
        rosterOrder = {},
        memorial = {}, -- list of fallen units
        recruits = {}, -- pending recruits
        bonds = Bonds.new(),
        buildings = { -- estate buildings; level 0 = unbuilt
            stagecoach = 0,
            guild = 0,
            forge = 0,
            infirmary = 0,
        },
    }
end

function Estate.addUnit(estate, unit)
    if not unit or not unit.id then return end
    if not estate.roster[unit.id] then
        estate.rosterOrder[#estate.rosterOrder + 1] = unit.id
    end
    estate.roster[unit.id] = {
        id = unit.id,
        classId = unit.classId or unit.class,
        name = unit.name or unit.id,
        portrait = unit.portrait,
        quirks = copyList(unit.quirks),
        hp = unit.hp,
        maxHp = unit.maxHp or unit.hp,
        stress = unit.stress or 0,
        injuries = copyList(unit.injuries),
        afflictions = copyList(unit.afflictions),
        missions = unit.missions or 0,
        alive = true,
    }
end

function Estate.rosterUnit(estate, unitId)
    return estate.roster[unitId]
end

function Estate.livingRoster(estate)
    local result = {}
    for _, id in ipairs(estate.rosterOrder) do
        local u = estate.roster[id]
        if u and u.alive then result[#result + 1] = u end
    end
    return result
end

-- map tactical statuses/HP to persistent injuries
local statusToInjury = {
    burning = "lamp_burn",
    flooded = "salt_bloat",
    corroded = "glass_scarring",
    shredded = "torn_shoulder",
    pinned = "crushed_hand",
}

local function hpInjuriesFor(unit)
    local injuries = {}
    if unit.hp and unit.maxHp and unit.hp <= math.floor(unit.maxHp / 3) then
        injuries[#injuries + 1] = "cracked_ribs" -- critical HP returns with injury
    end
    return injuries
end

function Estate.ingestMissionResult(estate, options)
    options = options or {}
    local survivors = options.survivors or {}
    local fallen = options.fallen or {}
    local missionId = options.missionId or "mission"
    local week = options.week
    if week then estate.week = week end
    for _, unit in ipairs(survivors) do
        local record = estate.roster[unit.id]
        if record then
            record.hp = unit.hp or record.hp
            record.stress = (record.stress or 0) + (unit.stress or 0)
            record.missions = (record.missions or 0) + 1
            for status, injuryId in pairs(statusToInjury) do
                if unit.statuses and unit.statuses[status] then
                    record.injuries = record.injuries or {}
                    record.injuries[#record.injuries + 1] = injuryId
                end
            end
            for _, inj in ipairs(hpInjuriesFor(unit)) do
                record.injuries = record.injuries or {}
                record.injuries[#record.injuries + 1] = inj
            end
        end
    end
    for _, unit in ipairs(fallen) do
        local record = estate.roster[unit.id]
        if record then
            record.alive = false
            estate.memorial[#estate.memorial + 1] = {
                id = unit.id, name = record.name, classId = record.classId,
                portrait = record.portrait, missionId = missionId, week = estate.week,
                cause = unit.cause or "killed in action",
            }
        end
    end
    -- pair cohesion: every survivor pair that completed together gains cohesion
    for i = 1, #survivors do
        for j = i + 1, #survivors do
            Bonds.gainCohesion(estate.bonds, survivors[i].id, survivors[j].id, Bonds.cohesionPerMission)
        end
    end
    return estate
end

function Estate.healInfirmary(estate, unitId, options)
    local record = estate.roster[unitId]
    if not record or not record.alive then return false, "no_living_unit" end
    options = options or {}
    local cost = options.cost or (Registry.estateBuildings.infirmary or {}).recoverCost or 25
    if (estate.gold or 0) < cost then return false, "insufficient_gold" end
    estate.gold = estate.gold - cost
    record.hp = record.maxHp
    record.stress = 0
    record.injuries = {}
    return true
end

function Estate.upgradeBuilding(estate, id)
    local def = Registry.estateBuildings[id]
    if not def then return false, "unknown_building" end
    local current = estate.buildings[id] or 0
    if current >= (def.maxLevel or 1) then return false, "max_level" end
    local heirlooms = def.heirloomCost or 0
    if (estate.heirlooms or 0) < heirlooms then return false, "insufficient_heirlooms" end
    estate.heirlooms = estate.heirlooms - heirlooms
    estate.buildings[id] = current + 1
    return true
end

function Estate.generateRecruits(estate, seed, count)
    estate.recruits = {}
    local stagecoachLevel = (estate.buildings and estate.buildings.stagecoach) or 0
    local def = Registry.estateBuildings.stagecoach or { recruitSlots = 3, slotsPerLevel = 1 }
    local slots = count or ((def.recruitSlots or 3) + (def.slotsPerLevel or 0) * stagecoachLevel)
    local classes = { "warden", "duelist", "mender", "harrier", "arcanist", "lamplighter" }
    local rng = Rng.new(Rng.hash(seed or estate.week or 1, slots, 7, 11))
    for i = 1, slots do
        local classId = classes[rng:range(1, #classes)]
        local id = string.format("recruit_w%d_%d", estate.week or 0, i)
        local identity = Identity.generate(rng:next(), classId)
        estate.recruits[#estate.recruits + 1] = {
            id = id, classId = classId, name = identity.name, portrait = identity.portrait,
            quirks = identity.quirks,
            cost = (def.recruitCost or 20) - ((def.discountPerLevel or 0) * stagecoachLevel),
        }
    end
    return estate.recruits
end

function Estate.hireRecruit(estate, recruitId)
    for i, r in ipairs(estate.recruits or {}) do
        if r.id == recruitId then
            if (estate.gold or 0) < (r.cost or 0) then return false, "insufficient_gold" end
            estate.gold = estate.gold - (r.cost or 0)
            table.remove(estate.recruits, i)
            Estate.addUnit(estate, {
                id = r.id, classId = r.classId, name = r.name, portrait = r.portrait, quirks = r.quirks,
                hp = (Registry.heroClasses[r.classId] or {}).maxHp or 4, maxHp = (Registry.heroClasses[r.classId] or {}).maxHp or 4,
            })
            return true
        end
    end
    return false, "unknown_recruit"
end

function Estate.applyActivity(estate, unitId, activityId)
    local record = estate.roster[unitId]
    if not record or not record.alive then return false, "no_living_unit" end
    local def = Registry.estateActivities[activityId]
    if not def then return false, "unknown_activity" end
    local cost = def.cost or 0
    if (estate.gold or 0) < cost then return false, "insufficient_gold" end
    estate.gold = estate.gold - cost
    record.stress = math.max(0, (record.stress or 0) - (def.stressHeal or 0))
    return true
end

function Estate.weeklyTick(estate, options)
    options = options or {}
    estate.week = (estate.week or 0) + 1
    local income = options.income or 30 -- baseline weekly income
    estate.gold = (estate.gold or 0) + income
    if options.dreadDelta then estate.dread = (estate.dread or 0) + options.dreadDelta end
    -- regenerate recruits each week
    Estate.generateRecruits(estate, options.seed or (estate.week * 1009 + 17))
    return estate
end

function Estate.applyMissionReward(estate, reward)
    if not reward then return end
    estate.gold = (estate.gold or 0) + (reward.gold or 0)
    estate.heirlooms = (estate.heirlooms or 0) + (reward.heirlooms or 0)
    if reward.dreadDelta then estate.dread = (estate.dread or 0) + reward.dreadDelta end
end

function Estate.snapshot(estate)
    if not estate then return nil end
    local roster = {}
    for id, record in pairs(estate.roster or {}) do
        roster[id] = {
            id = id, classId = record.classId, name = record.name, portrait = record.portrait,
            quirks = copyList(record.quirks), hp = record.hp, maxHp = record.maxHp,
            stress = record.stress, injuries = copyList(record.injuries),
            afflictions = copyList(record.afflictions), missions = record.missions,
            alive = record.alive,
        }
    end
    return {
        gold = estate.gold, heirlooms = estate.heirlooms, dread = estate.dread, week = estate.week,
        roster = roster, rosterOrder = copyList(estate.rosterOrder),
        memorial = (function() local m = {}; for _, e in ipairs(estate.memorial or {}) do m[#m + 1] = copyMap(e) end; return m end)(),
        recruits = (function() local r = {}; for _, e in ipairs(estate.recruits or {}) do r[#r + 1] = copyMap(e) end; return r end)(),
        bonds = Bonds.snapshot(estate.bonds),
        buildings = copyMap(estate.buildings),
    }
end

function Estate.fromSnapshot(snap)
    if not snap then return Estate.new() end
    local estate = Estate.new({ gold = snap.gold, heirlooms = snap.heirlooms, dread = snap.dread, week = snap.week })
    estate.rosterOrder = copyList(snap.rosterOrder)
    for id, record in pairs(snap.roster or {}) do
        estate.roster[id] = {
            id = id, classId = record.classId, name = record.name, portrait = record.portrait,
            quirks = copyList(record.quirks), hp = record.hp, maxHp = record.maxHp,
            stress = record.stress, injuries = copyList(record.injuries),
            afflictions = copyList(record.afflictions), missions = record.missions,
            alive = record.alive ~= false,
        }
    end
    for _, e in ipairs(snap.memorial or {}) do estate.memorial[#estate.memorial + 1] = copyMap(e) end
    for _, e in ipairs(snap.recruits or {}) do estate.recruits[#estate.recruits + 1] = copyMap(e) end
    estate.bonds = Bonds.fromSnapshot(snap.bonds)
    if snap.buildings then estate.buildings = copyMap(snap.buildings) end
    return estate
end

return Estate
