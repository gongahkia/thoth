local Defs = require("src.game.defs")
local Grid = require("src.core.grid")
local Inventory = require("src.game.inventory")
local Rng = require("src.core.rng")
local World = require("src.game.world")

local Simulation = {}
Simulation.__index = Simulation

local heroNames = {
    warden = "Mara",
    duelist = "Vey",
    mender = "Orrin",
    arcanist = "Sel",
    harrier = "Kest",
    chirurgeon = "Vand",
    exile = "Rook",
    lamplighter = "Aster",
}

local recruitNames = {
    "Iven", "Sable", "Rusk", "Nera", "Cadmus", "Tamsin", "Orrel", "Voss",
    "Liora", "Bram", "Anik", "Mirel",
}

local defaultQuirks = {
    warden = { "iron_nerves", "brittle" },
    duelist = { "quick_reflexes", "gloomy" },
    mender = { "field_reader", "soft_voice" },
    arcanist = { "steady_hand", "faint_pulse" },
    harrier = { "quick_reflexes", "soft_voice" },
    chirurgeon = { "field_reader", "brittle" },
    exile = { "steady_hand", "gloomy" },
    lamplighter = { "iron_nerves", "faint_pulse" },
}

local function copyList(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[#result + 1] = value
    end
    return result
end

local function copyMap(values)
    local result = {}
    for key, value in pairs(values or {}) do
        result[key] = value
    end
    return result
end

local function contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function newHero(id, classKey, name, quirks)
    local class = Defs.heroClass(classKey)
    local skillLevels = {}
    for _, skillKey in ipairs(class.skills) do
        skillLevels[skillKey] = 1
    end
    return {
        id = id,
        name = name or heroNames[classKey] or class.name,
        class = classKey,
        level = 1,
        xp = 0,
        hp = class.maxHp,
        stress = 0,
        affliction = nil,
        virtue = nil,
        alive = true,
        deathsDoor = false,
        deathblowResist = 67,
        deathblowChecks = 0,
        recovering = 0,
        recoveryActivity = nil,
        guard = 0,
        skills = copyList(class.skills),
        skillLevels = skillLevels,
        weapon = 0,
        armor = 0,
        quirks = copyList(quirks or defaultQuirks[classKey] or {}),
        lockedQuirks = {},
        diseases = {},
        trinkets = { false, false },
        statuses = {},
    }
end

local function recruitCandidate(seed, serial)
    local classes = Defs.heroClassOrder
    local positives = { "iron_nerves", "quick_reflexes", "steady_hand", "field_reader" }
    local negatives = { "gloomy", "brittle", "faint_pulse", "soft_voice" }
    local classKey = classes[(Rng.hash(seed + 2101, serial, 1, 0) % #classes) + 1]
    local name = recruitNames[(Rng.hash(seed + 2101, serial, 2, 0) % #recruitNames) + 1]
    local positive = positives[(Rng.hash(seed + 2101, serial, 3, 0) % #positives) + 1]
    local negative = negatives[(Rng.hash(seed + 2101, serial, 4, 0) % #negatives) + 1]
    return { class = classKey, name = name, quirks = { positive, negative } }
end

local function trinketOffer(seed, week, index)
    local order = Defs.trinketOrder
    local trinketKey = order[(Rng.hash(seed + 6101, week or 1, index or 1, 0) % #order) + 1]
    local trinket = Defs.trinket(trinketKey)
    return { trinket = trinketKey, price = (trinket.value or 0) * 2 }
end

local function appendUnique(list, value)
    if not contains(list, value) then
        list[#list + 1] = value
    end
end

local function combatHasBoss(combat)
    for _, enemy in ipairs((combat and combat.enemies) or {}) do
        local def = Defs.enemy(enemy.kind)
        if def and def.boss then
            return true
        end
    end
    return false
end

local function combatEnemyNames(combat)
    local names = {}
    for _, enemy in ipairs((combat and combat.enemies) or {}) do
        local def = Defs.enemy(enemy.kind)
        names[#names + 1] = def and def.name or enemy.kind
    end
    return names
end

local function newEnemy(id, kind, rank)
    local def = Defs.enemy(kind)
    local parts = {}
    for _, part in ipairs(def.parts or {}) do
        parts[#parts + 1] = {
            key = part.key,
            name = part.name,
            hp = part.hp,
            maxHp = part.hp,
            disabled = false,
            skillLocks = copyList(part.skillLocks),
            stressPenalty = part.stressPenalty or 0,
            exposeDamage = part.exposeDamage or 0,
        }
    end
    return { id = id, kind = kind, rank = rank, hp = def.maxHp, stress = 0, statuses = {}, guard = 0, parts = parts }
end

local function cloneEnemy(enemy)
    local statuses = {}
    for _, status in ipairs(enemy.statuses or {}) do
        statuses[#statuses + 1] = { kind = status.kind, amount = status.amount or 0, turns = status.turns or 0 }
    end
    local parts = {}
    for _, part in ipairs(enemy.parts or {}) do
        parts[#parts + 1] = {
            key = part.key,
            name = part.name,
            hp = part.hp,
            maxHp = part.maxHp,
            disabled = part.disabled == true,
            skillLocks = copyList(part.skillLocks),
            stressPenalty = part.stressPenalty or 0,
            exposeDamage = part.exposeDamage or 0,
        }
    end
    return {
        id = enemy.id,
        kind = enemy.kind,
        rank = enemy.rank,
        hp = enemy.hp,
        stress = enemy.stress or 0,
        statuses = statuses,
        guard = enemy.guard or 0,
        parts = parts,
    }
end

local function inventoryFromStacks(stacks)
    return Inventory.new(stacks or {})
end

local function newCampaign()
    return { renown = 0, dread = 0, completedMissions = {}, locationProgress = {}, bossKills = {}, victory = false, finalSeal = false, lost = false, lossReason = nil, weekLimit = 48, deathLimit = 8, dreadLimit = 18 }
end

function Simulation.new(seed)
    local roster = {}
    for index = 1, 4 do
        local classKey = Defs.heroClassOrder[index]
        roster[#roster + 1] = newHero(index, classKey)
    end
    local self = setmetatable({
        seed = seed or 1,
        tick = 0,
        rollIndex = 0,
        mode = "estate",
        world = World.new(seed or 1),
        player = { x = 0, y = 0, z = 0, facing = "east", selectedHero = 1 },
        estate = {
            gold = 150,
            heirlooms = 0,
            week = 1,
            currentEvent = nil,
            eventHistory = {},
            roster = roster,
            graveyard = {},
            trinkets = { ember_pin = 1, cracked_lens = 1, chirurgic_thread = 1 },
            trinketStock = {},
            provisionCart = Inventory.new(),
            upgrades = { stagecoach = 0, guild = 0, forge = 0, infirmary = 0 },
            campaign = newCampaign(),
            dismissed = {},
            missionBoard = {},
            recruits = {},
            nextHeroId = 5,
            recruitSerial = 1,
        },
        party = { 1, 2, 3, 4 },
        expedition = nil,
        combat = nil,
        commandQueue = {},
        status = "ready",
        narration = "",
        log = {},
        events = {},
        eventSerial = 0,
    }, Simulation)
    self:refillRecruits()
    self:refreshMissionBoard(true)
    self:refillTrinketMarket(true)
    self:startExpedition("buried_archive")
    return self
end

Simulation.commands = {}

function Simulation.commands.move(direction)
    return { type = "move", direction = direction }
end

function Simulation.commands.interact()
    return { type = "interact" }
end

function Simulation.commands.startExpedition(locationKey)
    return { type = "startExpedition", locationKey = locationKey or "buried_archive" }
end

function Simulation.commands.endExpedition(retreat)
    return { type = "endExpedition", retreat = retreat == true }
end

function Simulation.commands.camp()
    return { type = "camp" }
end

function Simulation.commands.campSkill(skillKey, heroRank)
    return { type = "campSkill", skillKey = skillKey, heroRank = heroRank }
end

function Simulation.commands.finishCamp()
    return { type = "finishCamp" }
end

function Simulation.commands.useItem(item, heroRank)
    return { type = "useItem", item = item, heroRank = heroRank }
end

function Simulation.commands.combatSkill(skillKey, targetRank, targetSide, targetPart)
    return { type = "combatSkill", skillKey = skillKey, targetRank = targetRank, targetSide = targetSide, targetPart = targetPart }
end

function Simulation.commands.passTurn()
    return { type = "passTurn" }
end

function Simulation.commands.retreat()
    return { type = "retreat" }
end

function Simulation.commands.selectHero(heroRank)
    return { type = "selectHero", heroRank = heroRank }
end

function Simulation.commands.recoverHero(heroId, activityKey)
    return { type = "recoverHero", heroId = heroId, activityKey = activityKey }
end

function Simulation.commands.dismissHero(heroId)
    return { type = "dismissHero", heroId = heroId }
end

function Simulation.commands.advanceWeek()
    return { type = "advanceWeek" }
end

function Simulation.commands.assignParty(heroId, rank)
    return { type = "assignParty", heroId = heroId, rank = rank }
end

function Simulation.commands.buyProvision(item, count)
    return { type = "buyProvision", item = item, count = count or 1 }
end

function Simulation.commands.recruitHero(recruitIndex)
    return { type = "recruitHero", recruitIndex = recruitIndex or 1 }
end

function Simulation.commands.equipTrinket(heroId, trinketKey, slot)
    return { type = "equipTrinket", heroId = heroId, trinketKey = trinketKey, slot = slot or 1 }
end

function Simulation.commands.unequipTrinket(heroId, slot)
    return { type = "unequipTrinket", heroId = heroId, slot = slot or 1 }
end

function Simulation.commands.sellTrinket(trinketKey)
    return { type = "sellTrinket", trinketKey = trinketKey }
end

function Simulation.commands.buyTrinket(stockIndex)
    return { type = "buyTrinket", stockIndex = stockIndex or 1 }
end

function Simulation.commands.upgradeBuilding(buildingKey)
    return { type = "upgradeBuilding", buildingKey = buildingKey }
end

function Simulation.commands.upgradeSkill(heroId, skillKey)
    return { type = "upgradeSkill", heroId = heroId, skillKey = skillKey }
end

function Simulation.commands.upgradeGear(heroId, kind)
    return { type = "upgradeGear", heroId = heroId, kind = kind }
end

function Simulation.commands.treatQuirk(heroId, quirkKey)
    return { type = "treatQuirk", heroId = heroId, quirkKey = quirkKey }
end

function Simulation.commands.lockQuirk(heroId, quirkKey)
    return { type = "lockQuirk", heroId = heroId, quirkKey = quirkKey }
end

function Simulation.commands.treatDisease(heroId, diseaseKey)
    return { type = "treatDisease", heroId = heroId, diseaseKey = diseaseKey }
end

function Simulation:queue(command)
    self.commandQueue[#self.commandQueue + 1] = command
end

function Simulation:step()
    local queue = self.commandQueue
    self.commandQueue = {}
    for _, command in ipairs(queue) do
        self:apply(command)
    end
    self.tick = self.tick + 1
end

function Simulation:apply(command)
    if not command then
        return false
    end
    if command.type == "move" then
        return self:move(command.direction)
    end
    if command.type == "interact" then
        return self:interact()
    end
    if command.type == "startExpedition" then
        return self:startExpedition(command.locationKey)
    end
    if command.type == "endExpedition" then
        return self:endExpedition(command.retreat)
    end
    if command.type == "camp" then
        return self:camp()
    end
    if command.type == "campSkill" then
        return self:campSkill(command.skillKey, command.heroRank)
    end
    if command.type == "finishCamp" then
        return self:finishCamp()
    end
    if command.type == "useItem" then
        return self:useItem(command.item, command.heroRank)
    end
    if command.type == "combatSkill" then
        return self:combatSkill(command.skillKey, command.targetRank, command.targetSide, command.targetPart)
    end
    if command.type == "passTurn" then
        return self:passTurn()
    end
    if command.type == "retreat" then
        return self:retreat()
    end
    if command.type == "selectHero" then
        return self:selectHero(command.heroRank)
    end
    if command.type == "recoverHero" then
        return self:recoverHero(command.heroId, command.activityKey)
    end
    if command.type == "dismissHero" then
        return self:dismissHero(command.heroId)
    end
    if command.type == "advanceWeek" then
        return self:advanceWeek()
    end
    if command.type == "assignParty" then
        return self:assignParty(command.heroId, command.rank)
    end
    if command.type == "buyProvision" then
        return self:buyProvision(command.item, command.count)
    end
    if command.type == "recruitHero" then
        return self:recruitHero(command.recruitIndex)
    end
    if command.type == "equipTrinket" then
        return self:equipTrinket(command.heroId, command.trinketKey, command.slot)
    end
    if command.type == "unequipTrinket" then
        return self:unequipTrinket(command.heroId, command.slot)
    end
    if command.type == "sellTrinket" then
        return self:sellTrinket(command.trinketKey)
    end
    if command.type == "buyTrinket" then
        return self:buyTrinket(command.stockIndex)
    end
    if command.type == "upgradeBuilding" then
        return self:upgradeBuilding(command.buildingKey)
    end
    if command.type == "upgradeSkill" then
        return self:upgradeSkill(command.heroId, command.skillKey)
    end
    if command.type == "upgradeGear" then
        return self:upgradeGear(command.heroId, command.kind)
    end
    if command.type == "treatQuirk" then
        return self:treatQuirk(command.heroId, command.quirkKey)
    end
    if command.type == "lockQuirk" then
        return self:lockQuirk(command.heroId, command.quirkKey)
    end
    if command.type == "treatDisease" then
        return self:treatDisease(command.heroId, command.diseaseKey)
    end
    return false
end

function Simulation:pushLog(message, meta)
    self.status = message
    self.log[#self.log + 1] = message
    self.events = self.events or {}
    self.eventSerial = (self.eventSerial or 0) + 1
    local event = { id = self.eventSerial, message = message }
    for key, value in pairs(meta or {}) do
        if key ~= "id" and key ~= "message" then
            event[key] = value
        end
    end
    self.events[#self.events + 1] = event
    if self.expedition then
        self.expedition.log[#self.expedition.log + 1] = message
    end
    while #self.log > 12 do
        table.remove(self.log, 1)
    end
    while #self.events > 24 do
        table.remove(self.events, 1)
    end
end

function Simulation:narrate(kind, salt)
    local lines = Defs.narrationFor(kind)
    if not lines or #lines == 0 then
        return false
    end
    local index = (Rng.hash(self.seed + 9901, self.tick, self.rollIndex, #(salt or kind)) % #lines) + 1
    local line = lines[index]
    self.narration = type(line) == "table" and line.text or line
    return true
end

function Simulation:roll(minValue, maxValue)
    self.rollIndex = self.rollIndex + 1
    local span = maxValue - minValue + 1
    return minValue + (Rng.hash(self.seed + 17011, self.tick, self.rollIndex, self.player.x + self.player.y) % span)
end

function Simulation:heroById(id)
    for _, hero in ipairs(self.estate.roster) do
        if hero.id == id then
            return hero
        end
    end
    return nil
end

function Simulation:heroAtRank(rank)
    local id = self.party[rank]
    return id and self:heroById(id) or nil
end

function Simulation:heroRank(heroId)
    for rank = 1, 4 do
        if self.party[rank] == heroId then
            return rank
        end
    end
    return nil
end

function Simulation:buildingLevel(buildingKey)
    return (self.estate.upgrades and self.estate.upgrades[buildingKey]) or 0
end

function Simulation:heroModifier(hero, key)
    local total = 0
    for _, quirkKey in ipairs(hero.quirks or {}) do
        local quirk = Defs.quirk(quirkKey)
        total = total + ((quirk and quirk[key]) or 0)
    end
    for _, diseaseKey in ipairs(hero.diseases or {}) do
        local disease = Defs.disease(diseaseKey)
        total = total + ((disease and disease[key]) or 0)
    end
    for _, trinketKey in ipairs(hero.trinkets or {}) do
        local trinket = trinketKey and Defs.trinket(trinketKey)
        total = total + ((trinket and trinket[key]) or 0)
    end
    for _, status in ipairs(hero.statuses or {}) do
        if status.kind == "injury" then
            local injury = Defs.injury(status.injury)
            total = total + ((injury and injury[key]) or 0)
        end
    end
    return total
end

function Simulation:hasInjury(hero, injuryKey)
    for _, status in ipairs((hero and hero.statuses) or {}) do
        if status.kind == "injury" and (not injuryKey or status.injury == injuryKey) then
            return true
        end
    end
    return false
end

function Simulation:addInjury(hero, injuryKey)
    if not hero or not hero.alive or not Defs.injury(injuryKey) or self:hasInjury(hero, injuryKey) then
        return false
    end
    hero.statuses = hero.statuses or {}
    hero.statuses[#hero.statuses + 1] = { kind = "injury", injury = injuryKey, turns = 0 }
    hero.hp = math.min(hero.hp, self:maxHp(hero))
    self:pushLog(hero.name .. " suffered " .. Defs.injury(injuryKey).name, { event = "danger", actor = hero.name, side = "ally" })
    return true
end

function Simulation:addRandomInjury(hero, sourceKey)
    if not hero or not hero.alive or #Defs.injuryOrder == 0 then
        return false
    end
    local index = (Rng.hash(self.seed + 4703, self.tick, hero.id, #(sourceKey or "")) % #Defs.injuryOrder) + 1
    for offset = 0, #Defs.injuryOrder - 1 do
        local injuryKey = Defs.injuryOrder[((index + offset - 1) % #Defs.injuryOrder) + 1]
        if self:addInjury(hero, injuryKey) then
            return true
        end
    end
    return false
end

function Simulation:clearInjury(hero, injuryKey)
    if not hero then
        return false
    end
    local kept = {}
    local cleared = false
    for _, status in ipairs(hero.statuses or {}) do
        if status.kind == "injury" and (not injuryKey or status.injury == injuryKey) and not cleared then
            cleared = true
        else
            kept[#kept + 1] = status
        end
    end
    hero.statuses = kept
    hero.hp = math.min(hero.hp, self:maxHp(hero))
    return cleared
end

function Simulation:quirksByKind(kind)
    local result = {}
    for _, quirkKey in ipairs(Defs.quirkOrder) do
        local quirk = Defs.quirk(quirkKey)
        if quirk and quirk.kind == kind then
            result[#result + 1] = quirkKey
        end
    end
    return result
end

function Simulation:gainQuirk(hero, kind)
    if not hero or not hero.alive then
        return false
    end
    local pool = self:quirksByKind(kind)
    for offset = 1, #pool do
        local quirkKey = pool[((self:roll(1, #pool) + offset - 2) % #pool) + 1]
        if not contains(hero.quirks, quirkKey) then
            if #hero.quirks >= 5 then
                for index, existing in ipairs(hero.quirks) do
                    if not (hero.lockedQuirks and hero.lockedQuirks[existing]) then
                        hero.quirks[index] = quirkKey
                        self:pushLog(hero.name .. " changed: " .. Defs.quirk(quirkKey).name)
                        return true
                    end
                end
                return false
            end
            hero.quirks[#hero.quirks + 1] = quirkKey
            self:pushLog(hero.name .. " gained " .. Defs.quirk(quirkKey).name)
            return true
        end
    end
    return false
end

function Simulation:heroSpeed(hero)
    return math.max(0, self:classDef(hero).speed + self:heroModifier(hero, "speed"))
end

function Simulation:heroResolve(hero)
    return clamp(self:classDef(hero).resolve + ((hero.level or 1) - 1) * 4 + self:heroModifier(hero, "resolve"), 5, 95)
end

function Simulation:skillLevel(hero, skillKey)
    return math.max(1, (hero.skillLevels and hero.skillLevels[skillKey]) or 1)
end

function Simulation:rosterLimit()
    local def = Defs.estateBuilding("stagecoach")
    return def.rosterLimit + self:buildingLevel("stagecoach") * def.rosterPerLevel
end

function Simulation:recruitSlots()
    local def = Defs.estateBuilding("stagecoach")
    return math.max(def.recruitSlots + self:buildingLevel("stagecoach") * def.slotsPerLevel, 4 - self:livingRosterCount())
end

function Simulation:livingRosterCount()
    local count = 0
    for _, hero in ipairs(self.estate.roster) do
        if hero.alive then
            count = count + 1
        end
    end
    return count
end

function Simulation:livingHeroCount()
    local count = 0
    for rank = 1, 4 do
        local hero = self:heroAtRank(rank)
        if hero and hero.alive then
            count = count + 1
        end
    end
    return count
end

function Simulation:compactParty()
    local nextParty = {}
    for rank = 1, 4 do
        local hero = self:heroAtRank(rank)
        if hero and hero.alive then
            nextParty[#nextParty + 1] = hero.id
        end
    end
    for rank = 1, 4 do
        self.party[rank] = nextParty[rank] or false
    end
end

function Simulation:moveHeroRank(fromRank, delta)
    local toRank = clamp(fromRank + delta, 1, 4)
    if toRank == fromRank or not self.party[fromRank] then
        return false
    end
    self.party[fromRank], self.party[toRank] = self.party[toRank], self.party[fromRank]
    return true
end

function Simulation:classDef(hero)
    return Defs.heroClass(hero.class)
end

function Simulation:maxHp(hero)
    return math.max(1, self:classDef(hero).maxHp + ((hero.level or 1) - 1) * 2 + (hero.armor or 0) * 3 + self:heroModifier(hero, "maxHp"))
end

function Simulation:healHero(hero, amount)
    if not hero or not hero.alive then
        return false
    end
    local penalty = hero.affliction and ((Defs.affliction(hero.affliction) or {}).healPenalty or 0) or 0
    hero.hp = math.min(self:maxHp(hero), hero.hp + math.max(0, amount + self:heroModifier(hero, "healBonus") - penalty))
    if hero.hp > 0 then
        hero.deathsDoor = false
    end
    return true
end

function Simulation:damageHero(hero, amount)
    if not hero or not hero.alive then
        return false
    end
    local extra = hero.affliction and ((Defs.affliction(hero.affliction) or {}).damageTaken or 0) or 0
    extra = extra + self:heroModifier(hero, "damageTaken")
    local damage = math.max(0, amount + extra)
    hero.hp = hero.hp - damage
    if hero.hp <= 0 and hero.deathsDoor then
        hero.deathblowChecks = (hero.deathblowChecks or 0) + 1
        local resist = clamp((hero.deathblowResist or 67) + self:heroModifier(hero, "deathblowResist") - (hero.deathblowChecks - 1) * 10, 0, 95)
        if self:roll(1, 100) <= resist then
            hero.hp = 0
            self:addStress(hero, 8)
            self:pushLog(hero.name .. " clung to life", { event = "death_save", actor = hero.name, side = "ally" })
            return true
        end
        hero.alive = false
        hero.hp = 0
        self.estate.graveyard[#self.estate.graveyard + 1] = {
            id = hero.id,
            name = hero.name,
            class = hero.class,
            tick = self.tick,
        }
        self:recordFallenTrinkets(hero)
        self:compactParty()
        self:evaluateCampaignState()
        self:pushLog(hero.name .. " fell", { event = "hero_death", actor = hero.name, side = "ally" })
        self:narrate("death", hero.name)
    elseif hero.hp <= 0 then
        hero.hp = 0
        hero.deathsDoor = true
        hero.deathblowChecks = 0
        self:addStress(hero, 10)
        self:pushLog(hero.name .. " reached death's door", { event = "death_door", actor = hero.name, side = "ally" })
    end
    return true
end

function Simulation:addStress(hero, amount)
    if not hero or not hero.alive then
        return false
    end
    local modifier = 0
    if hero.affliction then
        modifier = modifier + ((Defs.affliction(hero.affliction) or {}).stressTaken or 0)
    end
    if hero.virtue then
        modifier = modifier + ((Defs.virtue(hero.virtue) or {}).stressTaken or 0)
    end
    modifier = modifier + self:heroModifier(hero, "stressTaken")
    hero.stress = clamp(hero.stress + amount + modifier, 0, 200)
    if hero.stress >= 100 and not hero.affliction and not hero.virtue then
        self:resolveCheck(hero)
    end
    if hero.stress >= 160 then
        hero.stress = 120
        self:damageHero(hero, math.max(1, math.floor(self:maxHp(hero) / 3)))
        self:pushLog(hero.name .. " breaks under the dark", { event = "stress_break", actor = hero.name, side = "ally" })
    end
    return true
end

function Simulation:recordFallenTrinkets(hero)
    if not hero or not self.combat then
        return false
    end
    local moved = false
    self.combat.fallenTrinkets = self.combat.fallenTrinkets or {}
    for slot, trinketKey in ipairs(hero.trinkets or {}) do
        if trinketKey then
            self.combat.fallenTrinkets[#self.combat.fallenTrinkets + 1] = trinketKey
            hero.trinkets[slot] = false
            moved = true
        end
    end
    return moved
end

function Simulation:healStress(hero, amount)
    if not hero or not hero.alive then
        return false
    end
    hero.stress = math.max(0, hero.stress - math.max(0, amount))
    return true
end

function Simulation:stressParty(source, amount)
    for _, hero in ipairs(self:livingParty()) do
        if not source or hero.id ~= source.id then
            self:addStress(hero, amount)
        end
    end
end

function Simulation:healPartyStress(amount)
    for _, hero in ipairs(self:livingParty()) do
        self:healStress(hero, amount)
    end
end

function Simulation:resolveCheck(hero)
    local roll = self:roll(1, 100)
    if roll <= self:heroResolve(hero) then
        hero.virtue = Defs.virtueOrder[((roll - 1) % #Defs.virtueOrder) + 1]
        self:healPartyStress(4)
        self:pushLog(hero.name .. " steadied", { event = "resolve_virtue", actor = hero.name, side = "ally" })
    else
        hero.affliction = Defs.afflictionOrder[((roll - 1) % #Defs.afflictionOrder) + 1]
        self:stressParty(hero, 3)
        self:pushLog(hero.name .. " is " .. Defs.affliction(hero.affliction).name, { event = "resolve_affliction", actor = hero.name, side = "ally" })
    end
    self:narrate("resolve", hero.name)
end

function Simulation:afflictionAct(hero)
    if not hero or not hero.alive or not hero.affliction then
        return false
    end
    if hero.affliction == "panic" then
        self:addStress(hero, 4)
        self:stressParty(hero, 2)
    elseif hero.affliction == "spite" then
        self:stressParty(hero, 3)
    elseif hero.affliction == "numb" then
        self:damageHero(hero, 1)
    elseif hero.affliction == "reckless" and self.combat then
        local enemy = self:enemyAtRank(1)
        if enemy then
            enemy.hp = math.max(0, enemy.hp - 2)
        end
        self:addStress(hero, 2)
    end
    self:pushLog(hero.name .. " lost control", { event = "affliction_act", actor = hero.name, side = "ally" })
    return true
end

function Simulation:selectHero(heroRank)
    local rank = clamp(tonumber(heroRank) or 1, 1, 4)
    if self:heroAtRank(rank) then
        self.player.selectedHero = rank
        return true
    end
    return false
end

function Simulation:missionForKey(key)
    if Defs.mission(key) then
        return key, Defs.mission(key)
    end
    for _, missionKey in ipairs(Defs.missionOrder) do
        local mission = Defs.mission(missionKey)
        if mission.location == key then
            return missionKey, mission
        end
    end
    local fallback = Defs.missionOrder[1]
    return fallback, Defs.mission(fallback)
end

function Simulation:missionBoardSlots()
    return 4
end

function Simulation:eligibleMissionKeys()
    local result = {}
    local campaign = self.estate.campaign or {}
    for _, missionKey in ipairs(Defs.missionOrder) do
        local mission = Defs.mission(missionKey)
        if mission.kind ~= "boss" then
            result[#result + 1] = missionKey
        elseif not (campaign.bossKills and campaign.bossKills[mission.location])
            and ((campaign.locationProgress and campaign.locationProgress[mission.location]) or 0) >= 2 then
            result[#result + 1] = missionKey
        end
    end
    return result
end

function Simulation:refreshMissionBoard(force)
    if self.estate.missionBoard and #self.estate.missionBoard > 0 and not force then
        return false
    end
    local eligible = self:eligibleMissionKeys()
    self.estate.missionBoard = {}
    for _, missionKey in ipairs(eligible) do
        local mission = Defs.mission(missionKey)
        if mission.kind == "boss" then
            appendUnique(self.estate.missionBoard, missionKey)
        end
    end
    local slots = self:missionBoardSlots()
    for offset = 1, #eligible do
        if #self.estate.missionBoard >= slots then
            break
        end
        local index = ((Rng.hash(self.seed + 7207, self.estate.week or 1, offset, 0) % #eligible) + 1)
        appendUnique(self.estate.missionBoard, eligible[index])
    end
    for _, missionKey in ipairs(eligible) do
        if #self.estate.missionBoard >= slots then
            break
        end
        appendUnique(self.estate.missionBoard, missionKey)
    end
    if #self.estate.missionBoard == 0 then
        self.estate.missionBoard[1] = Defs.missionOrder[1]
    end
    return true
end

function Simulation:availableMissionKeys()
    self:refreshMissionBoard(false)
    return self.estate.missionBoard
end

function Simulation:missionLevelPenalty(mission)
    local target = mission.resolveLevel or 1
    local penalty = 0
    for rank = 1, 4 do
        local hero = self:heroAtRank(rank)
        if hero and hero.alive then
            if (hero.level or 1) > target + 1 then
                return nil, hero
            end
            if (hero.level or 1) < target then
                penalty = math.max(penalty, target - (hero.level or 1))
            end
        end
    end
    return penalty
end

function Simulation:applyMissionLevelPenalty(mission)
    local penalty = self:missionLevelPenalty(mission)
    if not penalty or penalty <= 0 then
        return false
    end
    for rank = 1, 4 do
        local hero = self:heroAtRank(rank)
        if hero and hero.alive and (hero.level or 1) < (mission.resolveLevel or 1) then
            self:addStress(hero, penalty * 6)
        end
    end
    self:pushLog("mission exceeds resolve")
    return true
end

function Simulation:startExpedition(locationKey)
    if self.expedition and self.expedition.active then
        return false
    end
    if self.estate.campaign and self.estate.campaign.lost then
        return false
    end
    local missionKey, mission = self:missionForKey(locationKey or "archive_scout")
    local location = Defs.location(mission.location)
    if not location then
        return false
    end
    local penalty, refusingHero = self:missionLevelPenalty(mission)
    if refusingHero then
        self:pushLog(refusingHero.name .. " refused " .. (mission.difficulty or "mission"))
        return false
    end
    self.world = World.new(self.seed, mission.location, { tiles = {}, layoutId = missionKey })
    self.player.x = location.start.x
    self.player.y = location.start.y
    self.player.z = location.start.z or 0
    self.player.facing = "east"
    self.player.selectedHero = 1
    self.mode = "expedition"
    self.combat = nil
    local supplies = Inventory.new(location.provisions or {})
    for _, stack in ipairs((self.estate.provisionCart and self.estate.provisionCart:stacks()) or {}) do
        supplies:add(stack.item, stack.count)
    end
    for _, stack in ipairs(mission.questProvision or {}) do
        supplies:add(stack.item, stack.count)
    end
    self.estate.provisionCart = Inventory.new()
    self.expedition = {
        active = true,
        mission = missionKey,
        location = mission.location,
        torch = 75,
        supplies = supplies,
        loot = Inventory.new(),
        packSlots = math.max(6, 12 - (mission.carryLoad or 0)),
        questActivations = 0,
        visitedRooms = {},
        scoutedRooms = {},
        clearedEncounters = {},
        curiosUsed = {},
        roomsScouted = 0,
        stepsSinceMeal = 0,
        hungerChecks = 0,
        threatState = {},
        noise = 0,
        ambushRolls = 0,
        corridorVisits = {},
        currentCorridor = nil,
        generatedLayoutId = self.world:layout().generatedLayoutId,
        campUsed = false,
        objectiveComplete = false,
        bossDefeated = false,
        log = {},
    }
    if mission.noisePressure then
        self:addNoise(mission.noisePressure)
    end
    self:applyMissionLevelPenalty(mission)
    self:discoverCurrentRoom()
    self:pushLog("entered " .. mission.name)
    self:narrate("mission_start", missionKey)
    return true
end

function Simulation:endExpedition(retreat)
    if not self.expedition or not self.expedition.active then
        return false
    end
    local success = self.expedition.objectiveComplete and not retreat
    local coin = self.expedition.loot:count("coin")
    local heirloom = self.expedition.loot:count("heirloom")
    local mission = Defs.mission(self.expedition.mission) or Defs.mission("archive_scout")
    local reward = mission.reward or {}
    if success then
        self.estate.gold = self.estate.gold + coin + (reward.gold or 0)
        self.estate.heirlooms = self.estate.heirlooms + heirloom + self.expedition.loot:count("relic") + (reward.heirlooms or 0)
        if reward.trinket then
            self.estate.trinkets[reward.trinket] = (self.estate.trinkets[reward.trinket] or 0) + 1
        end
        for rank = 1, 4 do
            local hero = self:heroAtRank(rank)
            if hero and hero.alive then
                self:awardXp(hero, 1)
                self:healStress(hero, 8)
                if self:roll(1, 100) <= 45 then
                    self:gainQuirk(hero, "positive")
                end
            end
        end
        self:recordMissionOutcome(mission, true, retreat)
        self:pushLog("mission complete")
        self:narrate("mission_complete", self.expedition.mission)
    else
        self.estate.gold = self.estate.gold + math.floor(coin / 2)
        for rank = 1, 4 do
            local hero = self:heroAtRank(rank)
            if hero and hero.alive then
                self:addStress(hero, 8)
                if self:roll(1, 100) <= 55 then
                    self:gainQuirk(hero, "negative")
                end
            end
        end
        self:recordMissionOutcome(mission, false, retreat)
        self:pushLog("expedition abandoned")
        self:narrate("retreat", self.expedition.mission)
    end
    self.mode = "estate"
    self.combat = nil
    self.expedition.active = false
    self:advanceWeek()
    self:refillRecruits()
    return true
end

function Simulation:recordMissionOutcome(mission, success, retreat)
    self.estate.campaign = self.estate.campaign or newCampaign()
    local campaign = self.estate.campaign
    local locationKey = mission and mission.location or (self.expedition and self.expedition.location) or "buried_archive"
    local missionKey = self.expedition and self.expedition.mission or (mission and mission.name) or locationKey
    if success then
        local progress = mission.kind == "boss" and 2 or 1
        campaign.renown = (campaign.renown or 0) + progress
        campaign.dread = math.max(0, (campaign.dread or 0) - 1)
        if mission.dreadBonus then
            campaign.dread = (campaign.dread or 0) + mission.dreadBonus
        end
        campaign.completedMissions[missionKey] = true
        campaign.locationProgress[locationKey] = (campaign.locationProgress[locationKey] or 0) + progress
        if mission.kind == "boss" then
            campaign.bossKills[locationKey] = true
        end
    else
        campaign.dread = (campaign.dread or 0) + (retreat and 1 or 2)
    end
    local defeated = 0
    for _, key in ipairs(Defs.locationOrder) do
        if campaign.bossKills[key] then
            defeated = defeated + 1
        end
    end
    campaign.victory = defeated >= #Defs.locationOrder
    if campaign.victory and not campaign.finalSeal then
        campaign.finalSeal = true
        self.estate.heirlooms = self.estate.heirlooms + 3
        self.estate.trinkets.scribe_wax = (self.estate.trinkets.scribe_wax or 0) + 1
        self:pushLog("campaign sealed")
        self:narrate("campaign_sealed", "victory")
    end
    self:refreshMissionBoard(true)
    self:evaluateCampaignState()
    return true
end

function Simulation:evaluateCampaignState()
    self.estate.campaign = self.estate.campaign or newCampaign()
    local campaign = self.estate.campaign
    if campaign.victory then
        campaign.lost = false
        campaign.lossReason = nil
        return false
    end
    if campaign.lost then
        return true
    end
    if #self.estate.graveyard >= (campaign.deathLimit or 8) then
        campaign.lost = true
        campaign.lossReason = "deaths"
    elseif (self.estate.week or 1) > (campaign.weekLimit or 48) then
        campaign.lost = true
        campaign.lossReason = "weeks"
    elseif (campaign.dread or 0) >= (campaign.dreadLimit or 18) then
        campaign.lost = true
        campaign.lossReason = "dread"
    end
    if campaign.lost then
        self:pushLog("campaign collapsed: " .. campaign.lossReason)
        self:narrate("collapse", campaign.lossReason or "lost")
    end
    return campaign.lost == true
end

function Simulation:advanceWeek()
    if self.mode ~= "estate" then
        return false
    end
    self.estate.week = (self.estate.week or 1) + 1
    for _, hero in ipairs(self.estate.roster) do
        if hero.recovering and hero.recovering > 0 then
            hero.recovering = hero.recovering - 1
            if hero.recovering == 0 then
                self:resolveRecoveryActivity(hero)
                self:pushLog(hero.name .. " returned")
            end
        end
    end
    self:applyCampaignPressure()
    self:refillRecruits()
    self:refreshMissionBoard(true)
    self:refillTrinketMarket(true)
    self:rollTownEvent()
    self:evaluateCampaignState()
    return true
end

function Simulation:applyCampaignPressure()
    local dread = self.estate.campaign and (self.estate.campaign.dread or 0) or 0
    if dread < 6 then
        return false
    end
    local stress = math.max(2, math.floor(dread / 6))
    for _, hero in ipairs(self.estate.roster) do
        if hero.alive and (hero.recovering or 0) <= 0 then
            self:addStress(hero, stress)
        end
    end
    self:pushLog("dread weighs on the estate")
    return true
end

function Simulation:rollTownEvent()
    local order = Defs.townEventOrder
    if not order or #order == 0 then
        return false
    end
    local eventKey = order[(Rng.hash(self.seed + 4409, self.estate.week or 1, #self.estate.eventHistory + 1, 0) % #order) + 1]
    return self:applyTownEvent(eventKey)
end

function Simulation:applyTownEvent(eventKey)
    local event = Defs.townEvent(eventKey)
    if not event then
        return false
    end
    self.estate.currentEvent = eventKey
    self.estate.eventHistory[#self.estate.eventHistory + 1] = { week = self.estate.week or 1, event = eventKey }
    if event.gold then
        self.estate.gold = math.max(0, self.estate.gold + event.gold)
    end
    if event.heirlooms then
        self.estate.heirlooms = math.max(0, self.estate.heirlooms + event.heirlooms)
    end
    for item, count in pairs(event.provisions or {}) do
        self.estate.provisionCart:add(item, count)
    end
    if event.stressHeal then
        for _, hero in ipairs(self.estate.roster) do
            if hero.alive then
                self:healStress(hero, event.stressHeal)
            end
        end
    end
    if event.stress then
        for _, hero in ipairs(self.estate.roster) do
            if hero.alive then
                self:addStress(hero, event.stress)
            end
        end
    end
    self:pushLog("event: " .. event.name)
    return true
end

function Simulation:lootSlotsUsed()
    if not self.expedition then
        return 0
    end
    return #self.expedition.loot:stacks()
end

function Simulation:addLoot(item, count)
    if not self.expedition or not Defs.item(item) or (count or 0) <= 0 then
        return false
    end
    local capacity = self.expedition.packSlots or 12
    if self.expedition.loot:count(item) <= 0 and self:lootSlotsUsed() >= capacity then
        self:pushLog("pack full")
        return false
    end
    return self.expedition.loot:add(item, count)
end

function Simulation:awardXp(hero, amount)
    if not hero or not hero.alive then
        return false
    end
    hero.xp = (hero.xp or 0) + (amount or 0)
    while hero.level < 5 and hero.xp >= hero.level * 2 do
        hero.xp = hero.xp - hero.level * 2
        hero.level = hero.level + 1
        hero.hp = self:maxHp(hero)
        self:pushLog(hero.name .. " reached resolve " .. hero.level)
    end
    return true
end

function Simulation:refillRecruits()
    self.estate.recruits = self.estate.recruits or {}
    while #self.estate.recruits < self:recruitSlots() do
        local serial = self.estate.recruitSerial or 1
        self.estate.recruits[#self.estate.recruits + 1] = recruitCandidate(self.seed, serial)
        self.estate.recruitSerial = serial + 1
    end
end

function Simulation:recruitCost()
    local def = Defs.estateBuilding("stagecoach")
    return math.max(0, def.recruitCost - self:buildingLevel("stagecoach") * def.discountPerLevel)
end

function Simulation:recruitHero(recruitIndex)
    if self.mode ~= "estate" then
        return false
    end
    self:refillRecruits()
    local index = clamp(tonumber(recruitIndex) or 1, 1, #self.estate.recruits)
    local recruit = self.estate.recruits[index]
    local cost = self:recruitCost()
    if not recruit or self.estate.gold < cost or self:livingRosterCount() >= self:rosterLimit() then
        return false
    end
    self.estate.gold = self.estate.gold - cost
    local hero = newHero(self.estate.nextHeroId or (#self.estate.roster + 1), recruit.class, recruit.name, recruit.quirks)
    self.estate.nextHeroId = hero.id + 1
    self.estate.roster[#self.estate.roster + 1] = hero
    table.remove(self.estate.recruits, index)
    for rank = 1, 4 do
        if not self.party[rank] then
            self.party[rank] = hero.id
            break
        end
    end
    self:refillRecruits()
    self:pushLog(hero.name .. " recruited")
    return true
end

function Simulation:trinketMarketSlots()
    return 3
end

function Simulation:refillTrinketMarket(force)
    if self.estate.trinketStock and #self.estate.trinketStock > 0 and not force then
        return false
    end
    self.estate.trinketStock = {}
    for index = 1, self:trinketMarketSlots() do
        self.estate.trinketStock[#self.estate.trinketStock + 1] = trinketOffer(self.seed, self.estate.week or 1, index)
    end
    return true
end

function Simulation:buyTrinket(stockIndex)
    if self.mode ~= "estate" then
        return false
    end
    self:refillTrinketMarket(false)
    local index = clamp(tonumber(stockIndex) or 1, 1, #self.estate.trinketStock)
    local offer = self.estate.trinketStock[index]
    local trinket = offer and Defs.trinket(offer.trinket)
    if not offer or not trinket or self.estate.gold < (offer.price or 0) then
        return false
    end
    self.estate.gold = self.estate.gold - offer.price
    self.estate.trinkets[offer.trinket] = ((self.estate.trinkets or {})[offer.trinket] or 0) + 1
    table.remove(self.estate.trinketStock, index)
    self:pushLog("bought " .. trinket.name)
    return true
end

function Simulation:dismissHero(heroId)
    if self.mode ~= "estate" then
        return false
    end
    local hero = self:heroById(heroId)
    if not hero or not hero.alive or (hero.recovering or 0) > 0 or self:heroRank(hero.id) or self:livingRosterCount() <= 4 then
        return false
    end
    for _, trinketKey in ipairs(hero.trinkets or {}) do
        if trinketKey then
            self.estate.trinkets[trinketKey] = ((self.estate.trinkets or {})[trinketKey] or 0) + 1
        end
    end
    local kept = {}
    for _, value in ipairs(self.estate.roster) do
        if value.id ~= hero.id then
            kept[#kept + 1] = value
        end
    end
    self.estate.roster = kept
    self.estate.dismissed = self.estate.dismissed or {}
    self.estate.dismissed[#self.estate.dismissed + 1] = { id = hero.id, name = hero.name, class = hero.class, week = self.estate.week or 1 }
    self:pushLog(hero.name .. " dismissed")
    return true
end

function Simulation:assignParty(heroId, rank)
    if self.mode ~= "estate" then
        return false
    end
    local hero = self:heroById(heroId)
    rank = clamp(tonumber(rank) or 1, 1, 4)
    if not hero or not hero.alive or (hero.recovering or 0) > 0 then
        return false
    end
    local current = self:heroRank(hero.id)
    if current then
        self.party[current], self.party[rank] = self.party[rank], self.party[current]
    else
        self.party[rank] = hero.id
    end
    self.player.selectedHero = rank
    self:pushLog(hero.name .. " assigned rank " .. rank)
    return true
end

function Simulation:buyProvision(item, count)
    if self.mode ~= "estate" then
        return false
    end
    local def = Defs.item(item)
    count = math.max(1, tonumber(count) or 1)
    if not def or not def.provision then
        return false
    end
    local cost = (def.cost or 0) * count
    if self.estate.gold < cost then
        return false
    end
    self.estate.gold = self.estate.gold - cost
    self.estate.provisionCart:add(item, count)
    self:pushLog("bought " .. def.name)
    return true
end

function Simulation:equipTrinket(heroId, trinketKey, slot)
    if self.mode ~= "estate" or not Defs.trinket(trinketKey) then
        return false
    end
    local hero = self:heroById(heroId)
    slot = clamp(tonumber(slot) or 1, 1, 2)
    if not hero or not hero.alive or hero.trinkets[slot] or ((self.estate.trinkets or {})[trinketKey] or 0) <= 0 then
        return false
    end
    self.estate.trinkets[trinketKey] = self.estate.trinkets[trinketKey] - 1
    hero.trinkets[slot] = trinketKey
    self:pushLog(hero.name .. " equipped " .. Defs.trinket(trinketKey).name)
    return true
end

function Simulation:unequipTrinket(heroId, slot)
    if self.mode ~= "estate" then
        return false
    end
    local hero = self:heroById(heroId)
    slot = clamp(tonumber(slot) or 1, 1, 2)
    if not hero or not hero.trinkets[slot] then
        return false
    end
    local trinketKey = hero.trinkets[slot]
    hero.trinkets[slot] = false
    self.estate.trinkets[trinketKey] = ((self.estate.trinkets or {})[trinketKey] or 0) + 1
    hero.hp = math.min(hero.hp, self:maxHp(hero))
    self:pushLog(hero.name .. " unequipped " .. Defs.trinket(trinketKey).name)
    return true
end

function Simulation:sellTrinket(trinketKey)
    if self.mode ~= "estate" then
        return false
    end
    local trinket = Defs.trinket(trinketKey)
    if not trinket or ((self.estate.trinkets or {})[trinketKey] or 0) <= 0 then
        return false
    end
    self.estate.trinkets[trinketKey] = self.estate.trinkets[trinketKey] - 1
    self.estate.gold = self.estate.gold + (trinket.value or 0)
    self:pushLog("sold " .. trinket.name)
    return true
end

function Simulation:upgradeBuilding(buildingKey)
    if self.mode ~= "estate" then
        return false
    end
    local def = Defs.estateBuilding(buildingKey)
    if not def then
        return false
    end
    local level = self:buildingLevel(buildingKey)
    local cost = def.heirloomCost * (level + 1)
    if level >= def.maxLevel or self.estate.heirlooms < cost then
        return false
    end
    self.estate.heirlooms = self.estate.heirlooms - cost
    self.estate.upgrades[buildingKey] = level + 1
    if buildingKey == "stagecoach" then
        self:refillRecruits()
    end
    self:pushLog(def.name .. " upgraded")
    return true
end

function Simulation:maxSkillLevel()
    local def = Defs.estateBuilding("guild")
    return def.maxSkillLevel + self:buildingLevel("guild") * def.skillMaxPerLevel
end

function Simulation:upgradeSkill(heroId, skillKey)
    if self.mode ~= "estate" then
        return false
    end
    local hero = self:heroById(heroId)
    local skill = Defs.skill(skillKey)
    if not hero or not hero.alive or not skill or skill.class ~= hero.class or not contains(hero.skills, skillKey) then
        return false
    end
    local current = self:skillLevel(hero, skillKey)
    if current >= self:maxSkillLevel() then
        return false
    end
    local cost = Defs.estateBuilding("guild").skillUpgradeCost * current
    if self.estate.gold < cost then
        return false
    end
    self.estate.gold = self.estate.gold - cost
    hero.skillLevels[skillKey] = current + 1
    self:pushLog(hero.name .. " trained " .. skill.name)
    return true
end

function Simulation:maxGearLevel()
    local def = Defs.estateBuilding("forge")
    return def.maxGearLevel + self:buildingLevel("forge") * def.gearMaxPerLevel
end

function Simulation:upgradeGear(heroId, kind)
    if self.mode ~= "estate" or (kind ~= "weapon" and kind ~= "armor") then
        return false
    end
    local hero = self:heroById(heroId)
    if not hero or not hero.alive or (hero[kind] or 0) >= self:maxGearLevel() then
        return false
    end
    local current = hero[kind] or 0
    local cost = Defs.estateBuilding("forge").gearUpgradeCost * (current + 1)
    if self.estate.gold < cost then
        return false
    end
    self.estate.gold = self.estate.gold - cost
    hero[kind] = current + 1
    if kind == "armor" then
        hero.hp = self:maxHp(hero)
    end
    self:pushLog(hero.name .. " improved " .. kind)
    return true
end

function Simulation:treatQuirk(heroId, quirkKey)
    if self.mode ~= "estate" then
        return false
    end
    local hero = self:heroById(heroId)
    local quirk = Defs.quirk(quirkKey)
    if not hero or not hero.alive or not quirk or quirk.kind ~= "negative" or not contains(hero.quirks, quirkKey) then
        return false
    end
    local def = Defs.estateBuilding("infirmary")
    local cost = math.max(0, def.quirkTreatmentCost - self:buildingLevel("infirmary") * def.discountPerLevel)
    if self.estate.gold < cost then
        return false
    end
    self.estate.gold = self.estate.gold - cost
    local kept = {}
    for _, value in ipairs(hero.quirks or {}) do
        if value ~= quirkKey then
            kept[#kept + 1] = value
        end
    end
    hero.quirks = kept
    hero.hp = math.min(hero.hp, self:maxHp(hero))
    self:pushLog(hero.name .. " treated " .. quirk.name)
    return true
end

function Simulation:lockQuirk(heroId, quirkKey)
    if self.mode ~= "estate" then
        return false
    end
    local hero = self:heroById(heroId)
    local quirk = Defs.quirk(quirkKey)
    if not hero or not hero.alive or not quirk or quirk.kind ~= "positive" or not contains(hero.quirks, quirkKey) then
        return false
    end
    hero.lockedQuirks = hero.lockedQuirks or {}
    if hero.lockedQuirks[quirkKey] then
        return false
    end
    local def = Defs.estateBuilding("infirmary")
    local cost = math.max(0, def.quirkLockCost - self:buildingLevel("infirmary") * def.discountPerLevel)
    if self.estate.gold < cost then
        return false
    end
    self.estate.gold = self.estate.gold - cost
    hero.lockedQuirks[quirkKey] = true
    self:pushLog(hero.name .. " locked " .. quirk.name)
    return true
end

function Simulation:contractDisease(hero, diseaseKey)
    if not hero or not hero.alive or not Defs.disease(diseaseKey) or contains(hero.diseases, diseaseKey) then
        return false
    end
    if #hero.diseases >= 3 then
        return false
    end
    hero.diseases[#hero.diseases + 1] = diseaseKey
    hero.hp = math.min(hero.hp, self:maxHp(hero))
    self:pushLog(hero.name .. " contracted " .. Defs.disease(diseaseKey).name)
    return true
end

function Simulation:maybeContractDisease(hero, sourceKey)
    if not hero or not hero.alive then
        return false
    end
    local roll = self:roll(1, 100)
    if roll > 22 then
        return false
    end
    local index = ((Rng.hash(self.seed + 3301, self.tick, hero.id, #(sourceKey or "")) % #Defs.diseaseOrder) + 1)
    return self:contractDisease(hero, Defs.diseaseOrder[index])
end

function Simulation:treatDisease(heroId, diseaseKey)
    if self.mode ~= "estate" then
        return false
    end
    local hero = self:heroById(heroId)
    if not hero or not hero.alive then
        return false
    end
    diseaseKey = diseaseKey or hero.diseases[1]
    local disease = Defs.disease(diseaseKey)
    if not disease or not contains(hero.diseases, diseaseKey) then
        return false
    end
    local def = Defs.estateBuilding("infirmary")
    local cost = math.max(0, def.diseaseTreatmentCost - self:buildingLevel("infirmary") * def.discountPerLevel)
    if self.estate.gold < cost then
        return false
    end
    self.estate.gold = self.estate.gold - cost
    local kept = {}
    for _, value in ipairs(hero.diseases or {}) do
        if value ~= diseaseKey then
            kept[#kept + 1] = value
        end
    end
    hero.diseases = kept
    hero.hp = math.min(hero.hp, self:maxHp(hero))
    self:pushLog(hero.name .. " cured " .. disease.name)
    return true
end

function Simulation:recoverHero(heroId, activityKey)
    if self.mode ~= "estate" then
        return false
    end
    local hero = self:heroById(heroId)
    local activity = activityKey and Defs.estateActivity(activityKey) or nil
    if activityKey and not activity then
        return false
    end
    local def = Defs.estateBuilding("infirmary")
    local cost = activity and activity.cost or math.max(0, def.recoverCost - self:buildingLevel("infirmary") * def.discountPerLevel)
    if not hero or not hero.alive or (hero.recovering or 0) > 0 or self.estate.gold < cost then
        return false
    end
    self.estate.gold = self.estate.gold - cost
    self:healStress(hero, activity and activity.stressHeal or 30)
    while self:clearInjury(hero) do
    end
    hero.recovering = activity and (activity.weeks or 1) or 1
    hero.recoveryActivity = activityKey
    self:pushLog(hero.name .. " recovered")
    return true
end

function Simulation:resolveRecoveryActivity(hero)
    local activity = hero and hero.recoveryActivity and Defs.estateActivity(hero.recoveryActivity) or nil
    if not activity then
        return false
    end
    hero.recoveryActivity = nil
    local chance = activity.sideEffectChance or 0
    if chance <= 0 or self:roll(1, 100) > chance then
        return false
    end
    if activity.sideEffect == "positive_quirk" then
        return self:gainQuirk(hero, "positive")
    end
    if activity.sideEffect == "gold_swing" then
        local swing = activity.goldSwing or 0
        if self:roll(1, 100) <= 50 then
            self.estate.gold = math.max(0, self.estate.gold - swing)
            self:pushLog(hero.name .. " lost coin at " .. activity.name)
        else
            self.estate.gold = self.estate.gold + swing
            self:pushLog(hero.name .. " won coin at " .. activity.name)
        end
        return true
    end
    return false
end

function Simulation:currentRoomKey()
    local key = self.world:roomAt(self.player.x, self.player.y)
    return key
end

function Simulation:discoverCurrentRoom()
    if not self.expedition then
        return nil
    end
    local roomKey = self:currentRoomKey()
    if roomKey then
        self.expedition.scoutedRooms[roomKey] = true
    end
    if roomKey and not self.expedition.visitedRooms[roomKey] then
        self.expedition.visitedRooms[roomKey] = true
        self.expedition.roomsScouted = self.expedition.roomsScouted + 1
        self:updateObjective()
        self:scoutFromRoom(roomKey)
    end
    return roomKey
end

function Simulation:clearedEncounterCount()
    local count = 0
    if self.expedition then
        for _ in pairs(self.expedition.clearedEncounters or {}) do
            count = count + 1
        end
    end
    return count
end

function Simulation:updateObjective()
    if not self.expedition then
        return false
    end
    local mission = Defs.mission(self.expedition.mission) or Defs.mission("archive_scout")
    if mission.kind == "scout" then
        self.expedition.objectiveComplete = self.expedition.roomsScouted >= (mission.objectiveRooms or Defs.location(mission.location).objectiveRooms)
    elseif mission.kind == "cleanse" then
        self.expedition.objectiveComplete = self:clearedEncounterCount() >= (mission.objectiveEncounters or 1)
    elseif mission.kind == "boss" then
        self.expedition.objectiveComplete = self.expedition.bossDefeated == true
    elseif mission.kind == "gather" then
        local complete = true
        for item, count in pairs(mission.objectiveItems or {}) do
            if self.expedition.loot:count(item) < count then
                complete = false
                break
            end
        end
        self.expedition.objectiveComplete = complete
    elseif mission.kind == "activate" then
        self.expedition.objectiveComplete = (self.expedition.questActivations or 0) >= (mission.objectiveActivations or 1)
    end
    return self.expedition.objectiveComplete
end

function Simulation:scoutFromRoom(roomKey)
    if not self.expedition or not roomKey then
        return false
    end
    local scoutScore = self:roll(1, 100) + math.floor((self.expedition.torch or 0) / 2)
    if scoutScore < 55 then
        return false
    end
    local count = 0
    for _, adjacent in ipairs(self.world:connectedRooms(roomKey)) do
        if not self.expedition.scoutedRooms[adjacent] then
            self.expedition.scoutedRooms[adjacent] = true
            count = count + 1
        end
    end
    if count > 0 then
        self:pushLog("scouted " .. count .. " room" .. (count == 1 and "" or "s"))
    end
    return count > 0
end

function Simulation:decayTorch(amount)
    if self.expedition then
        self.expedition.torch = clamp(self.expedition.torch - (amount or 1), 0, 100)
    end
end

function Simulation:livingParty()
    local heroes = {}
    for rank = 1, 4 do
        local hero = self:heroAtRank(rank)
        if hero and hero.alive then
            heroes[#heroes + 1] = hero
        end
    end
    return heroes
end

function Simulation:checkHunger()
    if not self.expedition then
        return false
    end
    self.expedition.stepsSinceMeal = (self.expedition.stepsSinceMeal or 0) + 1
    if self.expedition.stepsSinceMeal < 6 then
        return false
    end
    self.expedition.stepsSinceMeal = 0
    self.expedition.hungerChecks = (self.expedition.hungerChecks or 0) + 1
    local heroes = self:livingParty()
    local needed = #heroes
    if self.expedition.supplies:count("ration") >= needed then
        self.expedition.supplies:consume("ration", needed)
        self:pushLog("ate rations")
        return true
    end
    local remaining = self.expedition.supplies:count("ration")
    if remaining > 0 then
        self.expedition.supplies:consume("ration", remaining)
    end
    for _, hero in ipairs(heroes) do
        self:damageHero(hero, 2)
        self:addStress(hero, 6)
    end
    self:pushLog("hunger gnawed")
    return true
end

function Simulation:checkDarkness()
    if not self.expedition or self.expedition.torch > 0 then
        return false
    end
    for _, hero in ipairs(self:livingParty()) do
        self:addStress(hero, 1)
    end
    self:pushLog("dark pressed in")
    return true
end

function Simulation:addNoise(amount)
    if not self.expedition then
        return false
    end
    self.expedition.noise = clamp((self.expedition.noise or 0) + (amount or 1), 0, 12)
    return true
end

function Simulation:adjustDread(amount)
    if not self.estate or not self.estate.campaign or not amount or amount == 0 then
        return false
    end
    self.estate.campaign.dread = math.max(0, (self.estate.campaign.dread or 0) + amount)
    self:evaluateCampaignState()
    return true
end

function Simulation:corridorKey(corridor)
    if not corridor then
        return nil
    end
    if corridor.key then
        return corridor.key
    end
    local a = tostring(corridor.ax) .. ":" .. tostring(corridor.ay)
    local b = tostring(corridor.bx) .. ":" .. tostring(corridor.by)
    return a < b and (a .. ">" .. b) or (b .. ">" .. a)
end

function Simulation:applyCorridorRole(corridor)
    if not self.expedition then
        return false
    end
    if not corridor then
        self.expedition.currentCorridor = nil
        return false
    end
    local key = self:corridorKey(corridor)
    if self.expedition.currentCorridor == key then
        return false
    end
    self.expedition.currentCorridor = key
    self.expedition.corridorVisits = self.expedition.corridorVisits or {}
    local visits = self.expedition.corridorVisits[key] or 0
    self.expedition.corridorVisits[key] = visits + 1
    local location = Defs.location(self.expedition.location)
    local role = corridor.role
    local roleDef = location and location.layout and location.layout.corridorRoles and location.layout.corridorRoles[role] or nil
    if not roleDef then
        return false
    end
    if roleDef.noiseOnBacktrack and visits > 0 then
        self:addNoise(roleDef.noiseOnBacktrack)
        self:pushLog(role .. " raised noise")
        return true
    end
    if roleDef.torchCost then
        self:decayTorch(roleDef.torchCost)
        self:pushLog(role .. " cost torch")
        return true
    end
    if roleDef.stressCost then
        self:stressParty(nil, roleDef.stressCost)
        self:pushLog(role .. " cost nerve")
        return true
    end
    return false
end

function Simulation:tryStartPressureEncounter(roomKey)
    if self.mode ~= "expedition" or not self.expedition or self.expedition.location ~= "buried_archive" then
        return false
    end
    if roomKey and self.expedition.clearedEncounters[roomKey] then
        return false
    end
    local threshold = 0
    local torch = self.expedition.torch or 0
    local noise = self.expedition.noise or 0
    if torch < 35 then
        threshold = threshold + 20
    elseif torch < 55 then
        threshold = threshold + 7
    end
    if noise >= 3 then
        threshold = threshold + noise * 4
    end
    if roomKey and not self.expedition.scoutedRooms[roomKey] then
        threshold = threshold + 8
    elseif roomKey then
        threshold = threshold - 8
    end
    if roomKey and self.expedition.threatState and self.expedition.threatState[roomKey] == "stalked" then
        threshold = threshold + 12
    end
    if threshold <= 0 then
        return false
    end
    self.expedition.ambushRolls = (self.expedition.ambushRolls or 0) + 1
    if self:roll(1, 100) > threshold then
        return false
    end
    self.expedition.noise = math.max(0, noise - 2)
    local key = "pressure:" .. tostring(roomKey or (self.player.x .. ":" .. self.player.y)) .. ":" .. tostring(self.expedition.ambushRolls)
    self:pushLog("archive pressure broke")
    return self:startCombat("archive_ambush", key, { ambush = true, pressure = true })
end

function Simulation:checkTileHazard(x, y, z)
    if not self.expedition then
        return false
    end
    local tileDef = Defs.tile(self.world:getTile(x, y, z).id)
    if tileDef.curio and Defs.curio(tileDef.curio) and Defs.curio(tileDef.curio).damage then
        self:addNoise(2)
        return self:resolveCurio(x, y, z, tileDef.curio, { forceNoItem = true })
    end
    return false
end

function Simulation:isWalkable(x, y, z)
    return self.world:isWalkable(x, y, z or 0)
end

function Simulation:move(direction)
    if self.mode ~= "expedition" or (self.expedition and self.expedition.camping) then
        return false
    end
    direction = direction or self.player.facing
    self.player.facing = direction
    local x, y = Grid.front(self.player.x, self.player.y, direction)
    if not self:isWalkable(x, y, self.player.z) then
        self:pushLog("blocked")
        return false
    end
    self.player.x = x
    self.player.y = y
    self:decayTorch(1)
    self:checkHunger()
    self:checkDarkness()
    self:checkTileHazard(x, y, self.player.z)
    local corridor = self.world:corridorAt(x, y)
    self:applyCorridorRole(corridor)
    local roomKey = self:discoverCurrentRoom()
    self:pushLog("moved " .. direction)
    if self:tryStartRoomEncounter(roomKey) then
        return true
    end
    self:tryStartPressureEncounter(roomKey)
    return true
end

function Simulation:tryStartRoomEncounter(roomKey)
    if not self.expedition or not roomKey then
        return false
    end
    local encounterKey = self.world:encounterForRoom(roomKey)
    if encounterKey and not self.expedition.clearedEncounters[roomKey] then
        return self:startCombat(encounterKey, roomKey)
    end
    return false
end

function Simulation:targetCell()
    local x, y = Grid.front(self.player.x, self.player.y, self.player.facing)
    return x, y, self.player.z
end

function Simulation:interact()
    if self.mode ~= "expedition" then
        return false
    end
    local x, y, z = self:targetCell()
    local tile = self.world:getTile(x, y, z)
    local tileDef = Defs.tile(tile.id)
    if tileDef.exit then
        return self:endExpedition(false)
    end
    if tileDef.curio then
        return self:resolveCurio(x, y, z, tileDef.curio)
    end
    local threat = self.world:threatAt(x, y, z)
    if threat and not self.expedition.clearedEncounters[threat.key] then
        if threat.roomKey then
            self.expedition.threatState[threat.roomKey] = "engaged"
        end
        self:addNoise(1)
        return self:startCombat(threat.encounter, threat.key, { visible = true, threatKey = threat.key })
    end
    if tileDef.encounter then
        return self:startCombat(tileDef.encounter, self:currentRoomKey() or (x .. ":" .. y))
    end
    self:pushLog("nothing useful")
    return false
end

function Simulation:resolveCurio(x, y, z, curioKey, options)
    local key = Grid.key(x, y, z)
    if self.expedition.curiosUsed[key] then
        return false
    end
    local curio = Defs.curio(curioKey)
    if not curio then
        return false
    end
    if curio.camp then
        return self:camp()
    end
    if curio.questActivate then
        if curio.item and not self.expedition.supplies:consume(curio.item, 1) then
            self:pushLog("missing " .. Defs.item(curio.item).name)
            return false
        end
        self.expedition.questActivations = (self.expedition.questActivations or 0) + 1
        self.expedition.curiosUsed[key] = true
        self.world:setTile(x, y, z, { id = self.world:floorTile(), data = 0 })
        local hero = self:heroAtRank(self.player.selectedHero) or self:heroAtRank(1)
        if curio.stress then
            if curio.stress < 0 then
                self:healStress(hero, -curio.stress)
            else
                self:addStress(hero, curio.stress)
            end
        end
        if curio.dread then
            self:adjustDread(curio.dread)
        end
        self:updateObjective()
        self:pushLog(curio.name .. " activated")
        self:narrate("curio", curioKey)
        return true
    end
    local usedItem = false
    if not (options and options.forceNoItem) and curio.item and self.expedition.supplies:consume(curio.item, 1) then
        usedItem = true
    end
    for item, count in pairs(curio.loot or {}) do
        self:addLoot(item, usedItem and count or math.max(1, math.floor(count / 2)))
    end
    if curio.questGather then
        self:addLoot(curio.questGather.item, curio.questGather.count or 1)
    end
    local hero = self:heroAtRank(self.player.selectedHero) or self:heroAtRank(1)
    if curio.damage and not usedItem then
        self:damageHero(hero, curio.damage)
        self:addRandomInjury(hero, curioKey)
        if curioKey == "ash_vent" or curioKey == "wire_snare" then
            self:maybeContractDisease(hero, curioKey)
        end
    end
    if curio.stress then
        if curio.stress < 0 then
            self:healStress(hero, -curio.stress)
        else
            self:addStress(hero, usedItem and math.floor(curio.stress / 2) or curio.stress)
        end
    end
    if curio.dread and (curio.dread > 0 or usedItem) then
        self:adjustDread(curio.dread)
    end
    self.expedition.curiosUsed[key] = true
    self.world:setTile(x, y, z, { id = self.world:floorTile(), data = 0 })
    self:updateObjective()
    self:pushLog(curio.name .. " resolved")
    self:narrate("curio", curioKey)
    return true
end

function Simulation:camp()
    if self.mode ~= "expedition" or not self.expedition then
        return false
    end
    if self.expedition.camping then
        return self:finishCamp()
    end
    if self.expedition.campUsed then
        return false
    end
    self.expedition.campUsed = true
    self.expedition.camping = { respite = 4, usedSkills = {}, ambushPrevented = false }
    self.expedition.supplies:consume("ration", math.min(2, self.expedition.supplies:count("ration")))
    self.expedition.torch = clamp(self.expedition.torch + 20, 0, 100)
    for rank = 1, 4 do
        local hero = self:heroAtRank(rank)
        if hero and hero.alive then
            self:healHero(hero, 4)
            self:healStress(hero, 8)
            self:clearInjury(hero)
        end
    end
    self:pushLog("camped")
    self:narrate("camp", "camped")
    return true
end

function Simulation:campTargets(skill, heroRank)
    local targets = {}
    if skill.target == "party" then
        return self:livingParty()
    end
    local hero = self:heroAtRank(heroRank or self.player.selectedHero) or self:heroAtRank(1)
    if hero and hero.alive then
        targets[#targets + 1] = hero
    end
    return targets
end

function Simulation:campSkill(skillKey, heroRank)
    if self.mode ~= "expedition" or not self.expedition or not self.expedition.camping then
        return false
    end
    if tonumber(skillKey) then
        skillKey = Defs.campSkillOrder[tonumber(skillKey)]
    end
    local skill = Defs.campSkill(skillKey)
    local camping = self.expedition.camping
    if not skill or camping.usedSkills[skillKey] or camping.respite < (skill.cost or 0) then
        return false
    end
    local targets = self:campTargets(skill, heroRank)
    if #targets == 0 then
        return false
    end
    camping.respite = camping.respite - (skill.cost or 0)
    camping.usedSkills[skillKey] = true
    for _, target in ipairs(targets) do
        if skill.heal then
            self:healHero(target, skill.heal)
        end
        if skill.stressHeal then
            self:healStress(target, skill.stressHeal)
        end
        for _, statusKey in ipairs(skill.clearStatuses or {}) do
            self:clearStatus(target, statusKey)
        end
    end
    if skill.torch then
        self.expedition.torch = clamp(self.expedition.torch + skill.torch, 0, 100)
    end
    if skill.preventAmbush then
        camping.ambushPrevented = true
    end
    self:pushLog("camp skill " .. skill.name)
    if camping.respite <= 0 then
        self:finishCamp()
    end
    return true
end

function Simulation:finishCamp()
    if self.mode ~= "expedition" or not self.expedition or not self.expedition.camping then
        return false
    end
    local camping = self.expedition.camping
    self.expedition.camping = nil
    if not camping.ambushPrevented and self:roll(1, 100) <= 25 then
        self:pushLog("camp ambush")
        return self:startCombat("entry", "camp", { ambush = true })
    end
    self:pushLog("camp ended")
    return true
end

function Simulation:useItem(item, heroRank)
    if not self.expedition or not self.expedition.supplies:consume(item, 1) then
        return false
    end
    local hero = self:heroAtRank(heroRank or self.player.selectedHero) or self:heroAtRank(1)
    if item == "torch" then
        self.expedition.torch = clamp(self.expedition.torch + 25, 0, 100)
    elseif item == "ration" then
        self:healHero(hero, 2)
        self:healStress(hero, 1)
    elseif item == "bandage" then
        self:clearStatus(hero, "bleed")
        self:clearInjury(hero)
    elseif item == "laudanum" then
        self:healStress(hero, 12)
    elseif item == "salve" then
        self:healHero(hero, 5)
        self:clearInjury(hero)
    elseif item == "ward_charm" then
        hero.virtue = hero.virtue or "focused"
    else
        self.expedition.supplies:add(item, 1)
        return false
    end
    self:pushLog("used " .. Defs.item(item).name)
    return true
end

function Simulation:clearStatus(unit, kind)
    local kept = {}
    for _, status in ipairs(unit.statuses or {}) do
        if status.kind ~= kind then
            kept[#kept + 1] = status
        end
    end
    unit.statuses = kept
end

function Simulation:startCombat(encounterKey, roomKey, options)
    local baseEncounter = encounterKey
    encounterKey, baseEncounter = self:resolveEncounterVariant(encounterKey)
    local encounter = Defs.encounter(encounterKey)
    if not encounter then
        return false
    end
    options = options or {}
    local enemies = {}
    for index, kind in ipairs(encounter) do
        enemies[#enemies + 1] = newEnemy(index, kind, index)
    end
    self.mode = "combat"
    self.combat = {
        encounter = encounterKey,
        baseEncounter = baseEncounter,
        roomKey = roomKey,
        enemies = enemies,
        round = 0,
        turnQueue = {},
        turnIndex = 1,
        active = nil,
        fallenTrinkets = {},
        ambush = options.ambush == true,
        visible = options.visible == true,
        pressure = options.pressure == true,
        threatKey = options.threatKey,
        log = {},
    }
    if self.combat.ambush and self.expedition then
        self.expedition.torch = 0
    end
    local hasBoss = combatHasBoss(self.combat)
    self:pushLog("combat: " .. encounterKey, { event = self.combat.ambush and "ambush_start" or (hasBoss and "boss_start" or "combat_start"), encounter = encounterKey, boss = hasBoss, enemies = combatEnemyNames(self.combat) })
    self:narrate("combat_start", encounterKey)
    self:advanceCombat()
    return true
end

function Simulation:resolveEncounterVariant(encounterKey)
    local mission = self.expedition and Defs.mission(self.expedition.mission)
    if not mission or mission.kind ~= "boss" or mission.bossEncounter ~= encounterKey then
        return encounterKey, encounterKey
    end
    local dread = self.estate.campaign and (self.estate.campaign.dread or 0) or 0
    if mission.bossVariantEncounter and dread >= (mission.variantDread or 4) then
        return mission.bossVariantEncounter, encounterKey
    end
    return encounterKey, encounterKey
end

function Simulation:bossMissionForEncounter(encounterKey)
    for _, missionKey in ipairs(Defs.missionOrder) do
        local mission = Defs.mission(missionKey)
        if mission and mission.kind == "boss" and (mission.bossEncounter == encounterKey or mission.bossVariantEncounter == encounterKey) then
            return missionKey, mission
        end
    end
    return nil, nil
end

function Simulation:enemyAtRank(rank)
    local alive = {}
    for _, enemy in ipairs((self.combat and self.combat.enemies) or {}) do
        if enemy.hp > 0 then
            alive[#alive + 1] = enemy
        end
    end
    table.sort(alive, function(a, b)
        return a.rank < b.rank
    end)
    return alive[rank]
end

function Simulation:livingEnemyCount()
    local count = 0
    for _, enemy in ipairs((self.combat and self.combat.enemies) or {}) do
        if enemy.hp > 0 then
            count = count + 1
        end
    end
    return count
end

function Simulation:actorSpeed(actor)
    if actor.side == "hero" then
        local hero = self:heroById(actor.id)
        return hero and self:heroSpeed(hero) or 0
    end
    local enemy = self.combat.enemies[actor.id]
    return enemy and Defs.enemy(enemy.kind).speed or 0
end

function Simulation:buildTurnQueue()
    self.combat.round = self.combat.round + 1
    local queue = {}
    for rank = 1, 4 do
        local hero = self:heroAtRank(rank)
        if hero and hero.alive then
            queue[#queue + 1] = { side = "hero", id = hero.id, rank = rank }
        end
    end
    for index, enemy in ipairs(self.combat.enemies) do
        if enemy.hp > 0 then
            queue[#queue + 1] = { side = "enemy", id = index, rank = enemy.rank }
        end
    end
    table.sort(queue, function(a, b)
        local as = self:actorSpeed(a)
        local bs = self:actorSpeed(b)
        if as == bs then
            return (a.side .. a.id) < (b.side .. b.id)
        end
        return as > bs
    end)
    self.combat.turnQueue = queue
    self.combat.turnIndex = 1
end

function Simulation:actorStillAlive(actor)
    if actor.side == "hero" then
        local hero = self:heroById(actor.id)
        return hero and hero.alive
    end
    local enemy = self.combat.enemies[actor.id]
    return enemy and enemy.hp > 0
end

function Simulation:hasStatus(unit, kind)
    for _, status in ipairs(unit.statuses or {}) do
        if status.kind == kind then
            return true
        end
    end
    return false
end

function Simulation:enemyPart(enemy, partKey)
    if not enemy or not partKey then
        return nil
    end
    for _, part in ipairs(enemy.parts or {}) do
        if part.key == partKey then
            return part
        end
    end
    return nil
end

function Simulation:enemySkillLocked(enemy, skillKey)
    for _, part in ipairs((enemy and enemy.parts) or {}) do
        if part.disabled and contains(part.skillLocks, skillKey) then
            return true
        end
    end
    return false
end

function Simulation:enemyStressPenalty(enemy)
    local penalty = 0
    for _, part in ipairs((enemy and enemy.parts) or {}) do
        if part.disabled then
            penalty = penalty + (part.stressPenalty or 0)
        end
    end
    return penalty
end

function Simulation:enemyProtectorFor(enemy)
    if not enemy or not self.combat then
        return nil
    end
    for _, candidate in ipairs(self.combat.enemies or {}) do
        local def = Defs.enemy(candidate.kind)
        if candidate ~= enemy and candidate.hp > 0 and def and def.protectsAdjacent and math.abs((candidate.rank or 0) - (enemy.rank or 0)) <= 1 then
            return candidate
        end
    end
    return nil
end

function Simulation:damageEnemyPart(enemy, partKey, amount)
    local part = self:enemyPart(enemy, partKey)
    if not part or part.disabled then
        return false
    end
    part.hp = math.max(0, (part.hp or 0) - math.max(0, amount or 0))
    if part.hp > 0 then
        return true
    end
    part.disabled = true
    enemy.hp = math.max(0, enemy.hp - (part.exposeDamage or 0))
    self:pushLog((Defs.enemy(enemy.kind).name) .. " lost " .. (part.name or part.key), { event = "danger", actor = Defs.enemy(enemy.kind).name, side = "enemy" })
    return true
end

function Simulation:enemyTargetsForSkill(skill, consumeGuard)
    local targets = {}
    if skill.target == "party" then
        for rank = 1, 4 do
            local hero = self:heroAtRank(rank)
            if hero and hero.alive then
                targets[#targets + 1] = hero
            end
        end
        return targets
    end
    if skill.target ~= "hero" then
        return targets
    end
    if not skill.ignoreGuard then
        for rank = 1, 4 do
            local hero = self:heroAtRank(rank)
            if hero and hero.alive and (hero.guard or 0) > 0 then
                if consumeGuard then
                    hero.guard = hero.guard - 1
                end
                return { hero }
            end
        end
    end
    local candidates = {}
    local marked = {}
    for rank = 1, 4 do
        local hero = self:heroAtRank(rank)
        if hero and hero.alive and contains(skill.targetRanks, rank) then
            candidates[#candidates + 1] = hero
            if self:hasStatus(hero, "marked") then
                marked[#marked + 1] = hero
            end
        end
    end
    if #candidates == 0 then
        return targets
    end
    if skill.markBonus and #marked > 0 then
        return { marked[1] }
    end
    if not consumeGuard then
        return { candidates[1] }
    end
    return { candidates[self:roll(1, #candidates)] }
end

function Simulation:chooseEnemySkill(enemy)
    local enemyDef = Defs.enemy(enemy.kind)
    local legal = {}
    for _, skillKey in ipairs(enemyDef.skills or {}) do
        local skill = Defs.enemySkill(skillKey)
        if skill and not self:enemySkillLocked(enemy, skillKey) and #self:enemyTargetsForSkill(skill, false) > 0 then
            legal[#legal + 1] = skillKey
        end
    end
    if #legal == 0 then
        return nil
    end
    if self.expedition and self.expedition.torch < 35 then
        for _, skillKey in ipairs(legal) do
            local skill = Defs.enemySkill(skillKey)
            if skill.stress or skill.target == "party" then
                return skillKey
            end
        end
    end
    for _, skillKey in ipairs(legal) do
        local skill = Defs.enemySkill(skillKey)
        if skill.markBonus and #self:enemyTargetsForSkill(skill, false) > 0 then
            for _, target in ipairs(self:enemyTargetsForSkill(skill, false)) do
                if self:hasStatus(target, "marked") then
                    return skillKey
                end
            end
        end
    end
    return legal[self:roll(1, #legal)]
end

function Simulation:applyStatuses(unit, side)
    local skip = false
    local kept = {}
    for _, status in ipairs(unit.statuses or {}) do
        if status.kind == "injury" then
            kept[#kept + 1] = status
        elseif status.kind == "bleed" or status.kind == "blight" then
            if side == "hero" then
                self:damageHero(unit, status.amount or 1)
            else
                unit.hp = math.max(0, unit.hp - (status.amount or 1))
            end
            status.turns = (status.turns or 0) - 1
            if status.turns > 0 then
                kept[#kept + 1] = status
            end
        else
            if status.kind == "daze" then
                skip = true
            end
            status.turns = (status.turns or 0) - 1
            if status.turns > 0 then
                kept[#kept + 1] = status
            end
        end
    end
    unit.statuses = kept
    return skip
end

function Simulation:advanceCombat()
    while self.mode == "combat" and self.combat do
        if self:livingEnemyCount() <= 0 then
            return self:finishCombat(true)
        end
        if self:livingHeroCount() <= 0 then
            return self:finishCombat(false)
        end
        if #self.combat.turnQueue == 0 or self.combat.turnIndex > #self.combat.turnQueue then
            self:buildTurnQueue()
        end
        local actor = self.combat.turnQueue[self.combat.turnIndex]
        if not actor or not self:actorStillAlive(actor) then
            self.combat.turnIndex = self.combat.turnIndex + 1
        elseif actor.side == "enemy" then
            local enemy = self.combat.enemies[actor.id]
            local skip = self:applyStatuses(enemy, "enemy")
            if enemy.hp <= 0 then
                self.combat.turnIndex = self.combat.turnIndex + 1
            elseif skip then
                self:pushLog(Defs.enemy(enemy.kind).name .. " faltered", { event = "falter", actor = Defs.enemy(enemy.kind).name, side = "enemy" })
                self.combat.turnIndex = self.combat.turnIndex + 1
            else
                self:enemyTurn(enemy)
                self.combat.turnIndex = self.combat.turnIndex + 1
            end
        else
            local hero = self:heroById(actor.id)
            local skip = hero and self:applyStatuses(hero, "hero")
            if not hero or not hero.alive then
                self.combat.turnIndex = self.combat.turnIndex + 1
            elseif skip then
                self:pushLog(hero.name .. " faltered", { event = "falter", actor = hero.name, side = "ally" })
                self.combat.turnIndex = self.combat.turnIndex + 1
            elseif hero.affliction and self:roll(1, 100) <= 15 then
                self:afflictionAct(hero)
                self.combat.turnIndex = self.combat.turnIndex + 1
            else
                self.combat.active = actor
                self.player.selectedHero = self:heroRank(actor.id) or self.player.selectedHero
                return true
            end
        end
    end
    return false
end

function Simulation:enemyTurn(enemy)
    local def = Defs.enemy(enemy.kind)
    local skillKey = self:chooseEnemySkill(enemy)
    local skill = skillKey and Defs.enemySkill(skillKey) or nil
    if not skill then
        return false
    end
    local targets = self:enemyTargetsForSkill(skill, true)
    if #targets == 0 then
        return false
    end
    local damageBonus = 0
    local stressBonus = 0
    local stressPenalty = self:enemyStressPenalty(enemy)
    if self.expedition and self.expedition.torch < 30 then
        damageBonus = damageBonus + 1
        stressBonus = stressBonus + 2
    end
    if skill.noise then
        self:addNoise(skill.noise)
    end
    for _, target in ipairs(targets) do
        local damage = 0
        if skill.damage then
            damage = self:roll(skill.damage[1], skill.damage[2]) + damageBonus
            if skill.markBonus and self:hasStatus(target, "marked") then
                damage = damage + skill.markBonus
            end
            self:damageHero(target, damage)
        end
        if skill.stress then
            self:addStress(target, math.max(0, skill.stress + stressBonus - stressPenalty))
        end
        if skill.status and target.alive then
            target.statuses = target.statuses or {}
            target.statuses[#target.statuses + 1] = copyMap(skill.status)
            if skill.status.kind == "blight" then
                self:maybeContractDisease(target, skillKey)
            end
        end
        if skill.injuryChance and target.alive and self:roll(1, 100) <= skill.injuryChance then
            self:addRandomInjury(target, skillKey)
        end
        if skill.move and target.alive then
            local rank = self:heroRank(target.id)
            if rank then
                self:moveHeroRank(rank, skill.move)
            end
        end
    end
    if def.supportStressRestore then
        for _, ally in ipairs(self.combat.enemies or {}) do
            if ally ~= enemy and ally.hp > 0 and math.abs((ally.rank or 0) - (enemy.rank or 0)) <= 1 then
                ally.stress = math.max(0, (ally.stress or 0) - def.supportStressRestore)
            end
        end
    end
    self:pushLog(def.name .. " used " .. skill.name, { event = def.boss and "boss_skill" or "enemy_skill", actor = def.name, skill = skill.name, side = "enemy", boss = def.boss == true })
    return true
end

function Simulation:clearEncounterSpecial(encounterKey)
    for _, special in ipairs(self.world:specialsInRect(-999, 999, -999, 999, 0)) do
        local tileDef = Defs.tile(special.tile)
        if tileDef.encounter == encounterKey then
            self.world:setTile(special.x, special.y, special.z or 0, { id = self.world:floorTile(), data = 0 })
            return true
        end
    end
    return false
end

function Simulation:finishCombat(victory)
    if not self.combat then
        return false
    end
    local bossActive = combatHasBoss(self.combat)
    local outcomeEncounter = self.combat.encounter
    if victory then
        local bossWon = false
        for _, trinketKey in ipairs(self.combat.fallenTrinkets or {}) do
            self.estate.trinkets[trinketKey] = ((self.estate.trinkets or {})[trinketKey] or 0) + 1
        end
        if self.expedition then
            local baseEncounter = self.combat.baseEncounter or self.combat.encounter
            local _, bossMission = self:bossMissionForEncounter(baseEncounter)
            bossWon = bossMission ~= nil or bossActive
            self.expedition.clearedEncounters[self.combat.roomKey or self.combat.encounter] = true
            self:addLoot("coin", bossWon and 120 or 35)
            self:addLoot("heirloom", bossWon and 2 or 1)
            for rank = 1, 4 do
                local hero = self:heroAtRank(rank)
                if hero and hero.alive then
                    self:awardXp(hero, bossWon and 2 or 1)
                end
            end
            if bossWon then
                self.expedition.bossDefeated = true
            end
            if bossMission and bossMission.location == "buried_archive" then
                self.estate.trinkets.quiet_bell = (self.estate.trinkets.quiet_bell or 0) + 1
            end
            self:clearEncounterSpecial(baseEncounter)
            self:updateObjective()
        end
        self.mode = "expedition"
        self:pushLog("combat won", { event = bossWon and "boss_win" or "combat_win", encounter = outcomeEncounter, boss = bossWon, enemies = combatEnemyNames(self.combat) })
        self:narrate("combat_win", self.combat.encounter)
    else
        self.mode = "estate"
        if self.expedition then
            self.expedition.active = false
        end
        self:pushLog("party lost", { event = bossActive and "boss_loss" or "combat_loss", encounter = outcomeEncounter, boss = bossActive, enemies = combatEnemyNames(self.combat) })
        self:narrate("death", "party")
    end
    self.combat = nil
    return true
end

function Simulation:activeHero()
    if not self.combat or not self.combat.active or self.combat.active.side ~= "hero" then
        return nil
    end
    return self:heroById(self.combat.active.id)
end

function Simulation:firstLegalEnemyRank(skill)
    for rank = 1, 4 do
        if contains(skill.targetRanks, rank) and self:enemyAtRank(rank) then
            return rank
        end
    end
    return nil
end

function Simulation:combatSkill(skillKey, targetRank, targetSide, targetPart)
    if self.mode ~= "combat" or not self.combat then
        return false
    end
    local hero = self:activeHero()
    if not hero or not hero.alive then
        return false
    end
    if tonumber(skillKey) then
        skillKey = hero.skills[tonumber(skillKey)]
    end
    skillKey = skillKey or hero.skills[1]
    local skill = Defs.skill(skillKey)
    local heroRank = self:heroRank(hero.id)
    if not skill or skill.class ~= hero.class or not contains(skill.userRanks, heroRank) then
        self:pushLog("skill blocked")
        return false
    end
    local targets = {}
    if skill.target == "enemy" then
        targetSide = "enemy"
        targetRank = tonumber(targetRank) or self:firstLegalEnemyRank(skill)
        if not targetRank or not contains(skill.targetRanks, targetRank) then
            return false
        end
        local enemy = self:enemyAtRank(targetRank)
        if not enemy then
            return false
        end
        if targetPart and not self:enemyPart(enemy, targetPart) then
            return false
        end
        targets[#targets + 1] = targetPart and { unit = enemy, partKey = targetPart } or enemy
    elseif skill.target == "ally" then
        targetRank = tonumber(targetRank) or heroRank
        if not contains(skill.targetRanks, targetRank) then
            return false
        end
        local ally = self:heroAtRank(targetRank)
        if not ally or not ally.alive then
            return false
        end
        targets[#targets + 1] = ally
    elseif skill.target == "party" then
        for rank = 1, 4 do
            local ally = self:heroAtRank(rank)
            if ally and ally.alive then
                targets[#targets + 1] = ally
            end
        end
    else
        targets[#targets + 1] = hero
    end
    self:applySkill(hero, heroRank, skillKey, skill, targets, targetSide)
    self.combat.turnIndex = self.combat.turnIndex + 1
    return self:advanceCombat()
end

function Simulation:applySkill(hero, heroRank, skillKey, skill, targets, targetSide)
    local skillLevel = self:skillLevel(hero, skillKey)
    local damageBonus = (hero.weapon or 0) + (skillLevel - 1) + self:heroModifier(hero, "damageBonus")
    if hero.affliction == "reckless" then
        damageBonus = damageBonus + 1
    end
    if hero.virtue then
        damageBonus = damageBonus + ((Defs.virtue(hero.virtue) or {}).damageBonus or 0)
    end
    for _, target in ipairs(targets) do
        local unit = target.unit or target
        if skill.damage and targetSide == "enemy" then
            if not target.partKey then
                unit = self:enemyProtectorFor(unit) or unit
            end
            local damage = math.max(0, self:roll(skill.damage[1], skill.damage[2]) + damageBonus)
            if target.partKey then
                self:damageEnemyPart(unit, target.partKey, damage)
            else
                unit.hp = math.max(0, unit.hp - damage)
            end
        end
        if skill.stressDamage and targetSide == "enemy" then
            if target.partKey then
                self:damageEnemyPart(unit, target.partKey, skill.stressDamage)
            else
                unit.hp = math.max(0, unit.hp - skill.stressDamage)
                unit.stress = (unit.stress or 0) + skill.stressDamage
            end
        end
        if skill.heal then
            self:healHero(unit, self:roll(skill.heal[1], skill.heal[2]) + (skillLevel - 1))
        end
        if skill.stressHeal then
            self:healStress(unit, skill.stressHeal + math.floor((skillLevel - 1) / 2))
        end
        if skill.status and targetSide == "enemy" and not target.partKey and unit.hp > 0 then
            unit.statuses[#unit.statuses + 1] = copyMap(skill.status)
        end
    end
    if skill.guard then
        hero.guard = math.max(hero.guard or 0, skill.guard)
    end
    if skill.move then
        self:moveHeroRank(heroRank, skill.move)
    end
    if skill.torch and self.expedition then
        self.expedition.torch = clamp(self.expedition.torch + skill.torch, 0, 100)
    end
    self:pushLog(hero.name .. " used " .. skill.name, { event = "hero_skill", actor = hero.name, skill = skill.name, side = "ally" })
    return true
end

function Simulation:passTurn()
    local hero = self:activeHero()
    if not hero then
        return false
    end
    self:addStress(hero, 2)
    self:pushLog(hero.name .. " held", { event = "hero_hold", actor = hero.name, side = "ally" })
    self.combat.turnIndex = self.combat.turnIndex + 1
    return self:advanceCombat()
end

function Simulation:retreat()
    if self.mode == "combat" then
        if self.combat and self.combat.ambush then
            self:pushLog("ambush blocks retreat", { event = "retreat_blocked", side = "enemy" })
            return false
        end
        local bossActive = combatHasBoss(self.combat)
        local encounterKey = self.combat and self.combat.encounter or nil
        for rank = 1, 4 do
            local hero = self:heroAtRank(rank)
            if hero and hero.alive then
                self:addStress(hero, 6)
            end
        end
        self.mode = "expedition"
        self.combat = nil
        self:decayTorch(10)
        self:pushLog("retreated", { event = "retreat", encounter = encounterKey, boss = bossActive })
        return true
    end
    if self.mode == "expedition" then
        return self:endExpedition(true)
    end
    return false
end

function Simulation:itemCount(item)
    local total = 0
    if self.expedition then
        total = total + self.expedition.supplies:count(item) + self.expedition.loot:count(item)
    end
    return total
end

function Simulation:selectedItem()
    return nil
end

function Simulation:objectsInRect(minX, maxX, minY, maxY, z)
    local result = {}
    if not self.expedition then
        return result
    end
    for _, object in ipairs(self.world:specialsInRect(minX, maxX, minY, maxY, z or 0)) do
        local tileDef = Defs.tile(object.tile)
        local key = Grid.key(object.x, object.y, object.z or 0)
        local used = self.expedition.curiosUsed[key]
        local cleared = tileDef.encounter and self.expedition.clearedEncounters[self.world:roomAt(object.x, object.y) or key]
        if object.tile ~= self.world:floorTile() and not used and not cleared then
            result[#result + 1] = {
                type = tileDef.exit and "exit" or (tileDef.encounter and "boss" or "curio"),
                x = object.x,
                y = object.y,
                z = object.z or 0,
                tile = object.tile,
                curio = tileDef.curio,
                encounter = tileDef.encounter,
            }
        end
    end
    for _, threat in ipairs(self.world:threatsInRect(minX, maxX, minY, maxY, z or 0)) do
        if not self.expedition.clearedEncounters[threat.key] then
            result[#result + 1] = {
                type = threat.rare and "alpha" or "threat",
                x = threat.x,
                y = threat.y,
                z = threat.z or 0,
                encounter = threat.encounter,
                threatKey = threat.key,
                roomKey = threat.roomKey,
            }
        end
    end
    for _, room in ipairs(self.world:roomCenters()) do
        local encounter = self.world:encounterForRoom(room.key)
        if encounter and not self.expedition.clearedEncounters[room.key]
            and room.x >= minX and room.x <= maxX and room.y >= minY and room.y <= maxY
        then
            result[#result + 1] = { type = "encounter", x = room.x, y = room.y, z = z or 0, encounter = encounter }
        end
    end
    table.sort(result, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)
    return result
end

function Simulation:partyState()
    local result = {}
    for rank = 1, 4 do
        local hero = self:heroAtRank(rank)
        if hero then
            local class = Defs.heroClass(hero.class)
            result[#result + 1] = {
                rank = rank,
                id = hero.id,
                name = hero.name,
                class = class.name,
                level = hero.level,
                hp = hero.hp,
                maxHp = self:maxHp(hero),
                stress = hero.stress,
                affliction = hero.affliction,
                virtue = hero.virtue,
                alive = hero.alive,
                deathsDoor = hero.deathsDoor,
                recovering = hero.recovering,
                recoveryActivity = hero.recoveryActivity,
                statuses = copyList(hero.statuses),
                quirks = copyList(hero.quirks),
                lockedQuirks = copyMap(hero.lockedQuirks),
                diseases = copyList(hero.diseases),
                trinkets = copyList(hero.trinkets),
            }
        end
    end
    return result
end

function Simulation:availableSkills()
    local hero = self:activeHero() or self:heroAtRank(self.player.selectedHero)
    local result = {}
    if not hero then
        return result
    end
    local rank = self:heroRank(hero.id) or self.player.selectedHero
    for index, skillKey in ipairs(hero.skills) do
        local skill = Defs.skill(skillKey)
        result[#result + 1] = {
            index = index,
            key = skillKey,
            name = skill.name,
            level = self:skillLevel(hero, skillKey),
            usable = self.mode ~= "combat" or contains(skill.userRanks, rank),
        }
    end
    return result
end

function Simulation:availableCampSkills()
    local result = {}
    local camping = self.expedition and self.expedition.camping
    if not camping then
        return result
    end
    for index, skillKey in ipairs(Defs.campSkillOrder) do
        local skill = Defs.campSkill(skillKey)
        result[#result + 1] = {
            index = index,
            key = skillKey,
            name = skill.name,
            cost = skill.cost or 0,
            usable = not camping.usedSkills[skillKey] and camping.respite >= (skill.cost or 0),
        }
    end
    return result
end

function Simulation:missionProgressText()
    if not self.expedition then
        return "estate"
    end
    local mission = Defs.mission(self.expedition.mission) or Defs.mission("archive_scout")
    local target = mission.objectiveRooms or mission.objectiveEncounters or mission.objectiveActivations or 1
    local progress = mission.kind == "cleanse" and self:clearedEncounterCount() or self.expedition.roomsScouted
    if mission.kind == "boss" then
        progress = self.expedition.bossDefeated and 1 or 0
    elseif mission.kind == "gather" then
        progress = 0
        target = 0
        for item, count in pairs(mission.objectiveItems or {}) do
            progress = progress + math.min(count, self.expedition.loot:count(item))
            target = target + count
        end
    elseif mission.kind == "activate" then
        progress = self.expedition.questActivations or 0
    end
    return mission.kind .. " " .. progress .. "/" .. target
        .. "  light " .. self.expedition.torch
        .. "  pack " .. self:lootSlotsUsed() .. "/" .. (self.expedition.packSlots or 12)
        .. "  loot " .. self.expedition.loot:count("coin") .. "c"
end

function Simulation:objectiveChecklist()
    if not self.expedition then
        return {
            {
                title = "Estate",
                items = {
                    { label = "recover", done = self.estate.gold >= 0, next = "Start an expedition" },
                },
            },
        }
    end
    local mission = Defs.mission(self.expedition.mission) or Defs.mission("archive_scout")
    return {
        {
            title = "Expedition",
            items = {
                { label = mission.kind, done = self.expedition.objectiveComplete, next = mission.name },
                { label = "camp", done = self.expedition.campUsed, next = "Camp at the cold camp if stress climbs" },
                { label = "regent", done = self.expedition.bossDefeated, next = "Defeat the Vault Regent or return after scouting" },
                { label = "exit", done = not self.expedition.active, next = "Face the exit gate and press space" },
            },
        },
    }
end

function Simulation:nextStepText()
    if self.mode == "combat" then
        local hero = self:activeHero()
        return hero and (hero.name .. " acts") or "combat"
    end
    if self.mode == "estate" then
        return "Press space to start a new expedition"
    end
    if self.expedition.objectiveComplete then
        return "Return to the exit gate or hunt the Regent"
    end
    for _, group in ipairs(self:objectiveChecklist()) do
        for _, item in ipairs(group.items) do
            if not item.done then
                return item.next
            end
        end
    end
    return "Press space at the exit gate"
end

function Simulation:objectiveText()
    return self:nextStepText()
end

function Simulation:snapshot()
    local roster = {}
    for _, hero in ipairs(self.estate.roster) do
        roster[#roster + 1] = {
            id = hero.id,
            name = hero.name,
            class = hero.class,
            level = hero.level,
            xp = hero.xp,
            hp = hero.hp,
            stress = hero.stress,
            affliction = hero.affliction,
            virtue = hero.virtue,
            alive = hero.alive,
            deathsDoor = hero.deathsDoor,
            deathblowResist = hero.deathblowResist,
            deathblowChecks = hero.deathblowChecks,
            recovering = hero.recovering,
            recoveryActivity = hero.recoveryActivity,
            guard = hero.guard,
            skills = copyList(hero.skills),
            skillLevels = copyMap(hero.skillLevels),
            weapon = hero.weapon,
            armor = hero.armor,
            quirks = copyList(hero.quirks),
            lockedQuirks = copyMap(hero.lockedQuirks),
            diseases = copyList(hero.diseases),
            trinkets = copyList(hero.trinkets),
            statuses = copyList(hero.statuses),
        }
    end
    local recruits = {}
    for _, recruit in ipairs(self.estate.recruits or {}) do
        recruits[#recruits + 1] = {
            class = recruit.class,
            name = recruit.name,
            quirks = copyList(recruit.quirks),
        }
    end
    local dismissed = {}
    for _, entry in ipairs(self.estate.dismissed or {}) do
        dismissed[#dismissed + 1] = copyMap(entry)
    end
    local trinketStock = {}
    for _, offer in ipairs(self.estate.trinketStock or {}) do
        trinketStock[#trinketStock + 1] = copyMap(offer)
    end
    local expedition = nil
    if self.expedition then
        expedition = {
            active = self.expedition.active,
            mission = self.expedition.mission,
            location = self.expedition.location,
            torch = self.expedition.torch,
            supplies = self.expedition.supplies:stacks(),
            loot = self.expedition.loot:stacks(),
            packSlots = self.expedition.packSlots,
            questActivations = self.expedition.questActivations,
            visitedRooms = copyMap(self.expedition.visitedRooms),
            scoutedRooms = copyMap(self.expedition.scoutedRooms),
            clearedEncounters = copyMap(self.expedition.clearedEncounters),
            curiosUsed = copyMap(self.expedition.curiosUsed),
            roomsScouted = self.expedition.roomsScouted,
            stepsSinceMeal = self.expedition.stepsSinceMeal,
            hungerChecks = self.expedition.hungerChecks,
            threatState = copyMap(self.expedition.threatState),
            noise = self.expedition.noise or 0,
            ambushRolls = self.expedition.ambushRolls or 0,
            corridorVisits = copyMap(self.expedition.corridorVisits),
            currentCorridor = self.expedition.currentCorridor,
            generatedLayoutId = self.expedition.generatedLayoutId,
            campUsed = self.expedition.campUsed,
            camping = self.expedition.camping and {
                respite = self.expedition.camping.respite,
                usedSkills = copyMap(self.expedition.camping.usedSkills),
                ambushPrevented = self.expedition.camping.ambushPrevented,
            } or nil,
            objectiveComplete = self.expedition.objectiveComplete,
            bossDefeated = self.expedition.bossDefeated,
            log = copyList(self.expedition.log),
        }
    end
    local combat = nil
    if self.combat then
        local enemies = {}
        for _, enemy in ipairs(self.combat.enemies) do
            enemies[#enemies + 1] = cloneEnemy(enemy)
        end
        combat = {
            encounter = self.combat.encounter,
            baseEncounter = self.combat.baseEncounter,
            roomKey = self.combat.roomKey,
            enemies = enemies,
            round = self.combat.round,
            turnQueue = copyList(self.combat.turnQueue),
            turnIndex = self.combat.turnIndex,
            active = self.combat.active and copyMap(self.combat.active) or nil,
            fallenTrinkets = copyList(self.combat.fallenTrinkets),
            ambush = self.combat.ambush == true,
            visible = self.combat.visible == true,
            pressure = self.combat.pressure == true,
            threatKey = self.combat.threatKey,
            log = copyList(self.combat.log),
        }
    end
    return {
        version = 3,
        seed = self.seed,
        tick = self.tick,
        rollIndex = self.rollIndex,
        mode = self.mode,
        world = self.world:snapshot(),
        player = copyMap(self.player),
        estate = {
            gold = self.estate.gold,
            heirlooms = self.estate.heirlooms,
            week = self.estate.week,
            currentEvent = self.estate.currentEvent,
            eventHistory = copyList(self.estate.eventHistory),
            roster = roster,
            graveyard = copyList(self.estate.graveyard),
            dismissed = dismissed,
            trinkets = copyMap(self.estate.trinkets),
            trinketStock = trinketStock,
            provisionCart = self.estate.provisionCart:stacks(),
            upgrades = copyMap(self.estate.upgrades),
            campaign = {
                renown = self.estate.campaign and self.estate.campaign.renown or 0,
                dread = self.estate.campaign and self.estate.campaign.dread or 0,
                completedMissions = copyMap(self.estate.campaign and self.estate.campaign.completedMissions),
                locationProgress = copyMap(self.estate.campaign and self.estate.campaign.locationProgress),
                bossKills = copyMap(self.estate.campaign and self.estate.campaign.bossKills),
                victory = self.estate.campaign and self.estate.campaign.victory == true,
                finalSeal = self.estate.campaign and self.estate.campaign.finalSeal == true,
                lost = self.estate.campaign and self.estate.campaign.lost == true,
                lossReason = self.estate.campaign and self.estate.campaign.lossReason or nil,
                weekLimit = self.estate.campaign and self.estate.campaign.weekLimit or 48,
                deathLimit = self.estate.campaign and self.estate.campaign.deathLimit or 8,
                dreadLimit = self.estate.campaign and self.estate.campaign.dreadLimit or 18,
            },
            recruits = recruits,
            missionBoard = copyList(self.estate.missionBoard),
            nextHeroId = self.estate.nextHeroId,
            recruitSerial = self.estate.recruitSerial,
        },
        party = copyList(self.party),
        expedition = expedition,
        combat = combat,
        status = self.status,
        narration = self.narration,
        log = copyList(self.log),
    }
end

function Simulation.fromSnapshot(snapshot)
    if snapshot.version and snapshot.version ~= 2 and snapshot.version ~= 3 then
        return nil, "unsupported simulation snapshot version"
    end
    local self = setmetatable({
        seed = snapshot.seed or 1,
        tick = snapshot.tick or 0,
        rollIndex = snapshot.rollIndex or 0,
        mode = snapshot.mode or "estate",
        world = World.fromSnapshot(snapshot.world or { seed = snapshot.seed or 1, tiles = {} }),
        player = copyMap(snapshot.player or { x = 0, y = 0, z = 0, facing = "east", selectedHero = 1 }),
        estate = { gold = 0, heirlooms = 0, roster = {}, graveyard = {}, dismissed = {}, trinkets = {}, trinketStock = {}, provisionCart = Inventory.new(), upgrades = {}, campaign = newCampaign(), missionBoard = {}, recruits = {}, nextHeroId = 1, recruitSerial = 1 },
        party = copyList(snapshot.party or {}),
        expedition = nil,
        combat = nil,
        commandQueue = {},
        status = snapshot.status or "loaded",
        narration = snapshot.narration or "",
        log = copyList(snapshot.log or {}),
        events = {},
        eventSerial = 0,
    }, Simulation)
    self.estate.gold = (snapshot.estate and snapshot.estate.gold) or 0
    self.estate.heirlooms = (snapshot.estate and snapshot.estate.heirlooms) or 0
    self.estate.week = (snapshot.estate and snapshot.estate.week) or 1
    self.estate.currentEvent = snapshot.estate and snapshot.estate.currentEvent or nil
    self.estate.eventHistory = copyList((snapshot.estate and snapshot.estate.eventHistory) or {})
    self.estate.graveyard = copyList((snapshot.estate and snapshot.estate.graveyard) or {})
    self.estate.dismissed = copyList((snapshot.estate and snapshot.estate.dismissed) or {})
    self.estate.trinkets = copyMap((snapshot.estate and snapshot.estate.trinkets) or {})
    self.estate.trinketStock = {}
    if snapshot.estate and snapshot.estate.trinketStock then
        for _, offer in ipairs(snapshot.estate.trinketStock) do
            self.estate.trinketStock[#self.estate.trinketStock + 1] = copyMap(offer)
        end
    else
        self:refillTrinketMarket(true)
    end
    self.estate.provisionCart = inventoryFromStacks((snapshot.estate and snapshot.estate.provisionCart) or {})
    self.estate.upgrades = copyMap((snapshot.estate and snapshot.estate.upgrades) or { stagecoach = 0, guild = 0, forge = 0, infirmary = 0 })
    for _, buildingKey in ipairs(Defs.estateBuildingOrder) do
        self.estate.upgrades[buildingKey] = self.estate.upgrades[buildingKey] or 0
    end
    local campaign = (snapshot.estate and snapshot.estate.campaign) or {}
    self.estate.campaign = {
        renown = campaign.renown or 0,
        dread = campaign.dread or 0,
        completedMissions = copyMap(campaign.completedMissions),
        locationProgress = copyMap(campaign.locationProgress),
        bossKills = copyMap(campaign.bossKills),
        victory = campaign.victory == true,
        finalSeal = campaign.finalSeal == true,
        lost = campaign.lost == true,
        lossReason = campaign.lossReason,
        weekLimit = campaign.weekLimit or 48,
        deathLimit = campaign.deathLimit or 8,
        dreadLimit = campaign.dreadLimit or 18,
    }
    self.estate.recruits = {}
    for _, recruit in ipairs((snapshot.estate and snapshot.estate.recruits) or {}) do
        self.estate.recruits[#self.estate.recruits + 1] = {
            class = recruit.class,
            name = recruit.name,
            quirks = copyList(recruit.quirks),
        }
    end
    self.estate.nextHeroId = (snapshot.estate and snapshot.estate.nextHeroId) or 1
    self.estate.recruitSerial = (snapshot.estate and snapshot.estate.recruitSerial) or 1
    self.estate.missionBoard = copyList((snapshot.estate and snapshot.estate.missionBoard) or {})
    if #self.estate.missionBoard == 0 then
        self:refreshMissionBoard(true)
    end
    for _, value in ipairs((snapshot.estate and snapshot.estate.roster) or {}) do
        local hero = newHero(value.id, value.class)
        hero.name = value.name or hero.name
        hero.level = value.level or 1
        hero.xp = value.xp or 0
        hero.hp = value.hp or hero.hp
        hero.stress = value.stress or 0
        hero.affliction = value.affliction
        hero.virtue = value.virtue
        hero.alive = value.alive ~= false
        hero.deathsDoor = value.deathsDoor == true
        hero.deathblowResist = value.deathblowResist or hero.deathblowResist
        hero.deathblowChecks = value.deathblowChecks or 0
        hero.recovering = value.recovering or 0
        hero.recoveryActivity = value.recoveryActivity
        hero.guard = value.guard or 0
        hero.skills = copyList(value.skills or hero.skills)
        hero.skillLevels = copyMap(value.skillLevels or hero.skillLevels)
        for _, skillKey in ipairs(hero.skills) do
            hero.skillLevels[skillKey] = hero.skillLevels[skillKey] or 1
        end
        hero.weapon = value.weapon or 0
        hero.armor = value.armor or 0
        hero.quirks = copyList(value.quirks or hero.quirks)
        hero.lockedQuirks = copyMap(value.lockedQuirks or hero.lockedQuirks)
        hero.diseases = copyList(value.diseases or hero.diseases)
        hero.trinkets = copyList(value.trinkets or hero.trinkets)
        hero.trinkets[1] = hero.trinkets[1] or false
        hero.trinkets[2] = hero.trinkets[2] or false
        hero.statuses = copyList(value.statuses or {})
        self.estate.roster[#self.estate.roster + 1] = hero
        self.estate.nextHeroId = math.max(self.estate.nextHeroId, hero.id + 1)
    end
    self:refillRecruits()
    local exp = snapshot.expedition
    if exp then
        self.expedition = {
            active = exp.active == true,
            mission = exp.mission or "archive_scout",
            location = exp.location or "buried_archive",
            torch = exp.torch or 0,
            supplies = inventoryFromStacks(exp.supplies),
            loot = inventoryFromStacks(exp.loot),
            packSlots = exp.packSlots or 12,
            questActivations = exp.questActivations or 0,
            visitedRooms = copyMap(exp.visitedRooms),
            scoutedRooms = copyMap(exp.scoutedRooms),
            clearedEncounters = copyMap(exp.clearedEncounters),
            curiosUsed = copyMap(exp.curiosUsed),
            roomsScouted = exp.roomsScouted or 0,
            stepsSinceMeal = exp.stepsSinceMeal or 0,
            hungerChecks = exp.hungerChecks or 0,
            threatState = copyMap(exp.threatState),
            noise = exp.noise or 0,
            ambushRolls = exp.ambushRolls or 0,
            corridorVisits = copyMap(exp.corridorVisits),
            currentCorridor = exp.currentCorridor,
            generatedLayoutId = exp.generatedLayoutId,
            campUsed = exp.campUsed == true,
            camping = exp.camping and {
                respite = exp.camping.respite or 0,
                usedSkills = copyMap(exp.camping.usedSkills),
                ambushPrevented = exp.camping.ambushPrevented == true,
            } or nil,
            objectiveComplete = exp.objectiveComplete == true,
            bossDefeated = exp.bossDefeated == true,
            log = copyList(exp.log or {}),
        }
        if self.world and not self.world.layoutId then
            self.world.layoutId = self.expedition.mission
            self.world.generatedLayout = nil
        end
    end
    local combat = snapshot.combat
    if combat then
        self.combat = {
            encounter = combat.encounter,
            baseEncounter = combat.baseEncounter or combat.encounter,
            roomKey = combat.roomKey,
            enemies = {},
            round = combat.round or 0,
            turnQueue = copyList(combat.turnQueue),
            turnIndex = combat.turnIndex or 1,
            active = combat.active and copyMap(combat.active) or nil,
            fallenTrinkets = copyList(combat.fallenTrinkets),
            ambush = combat.ambush == true,
            visible = combat.visible == true,
            pressure = combat.pressure == true,
            threatKey = combat.threatKey,
            log = copyList(combat.log or {}),
        }
        for _, enemy in ipairs(combat.enemies or {}) do
            self.combat.enemies[#self.combat.enemies + 1] = cloneEnemy(enemy)
        end
    end
    return self
end

return Simulation
