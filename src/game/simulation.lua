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
    merchant = "Leto",
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
    merchant = { "field_reader", "gloomy" },
}

local starterClassOrder = { "warden", "duelist", "mender", "harrier" }

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

local function copyNestedMap(values)
    local result = {}
    for key, value in pairs(values or {}) do
        if type(value) == "table" then
            result[key] = copyNestedMap(value)
        else
            result[key] = value
        end
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

local function hasValue(list)
    for _, entry in ipairs(list or {}) do
        if entry then
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

local function recruitCandidate(seed, serial, classes)
    classes = classes or Defs.heroClassOrder
    local positives = { "iron_nerves", "quick_reflexes", "steady_hand", "field_reader" }
    local negatives = { "gloomy", "brittle", "faint_pulse", "soft_voice" }
    local classKey = classes[(Rng.hash(seed + 2101, serial, 1, 0) % #classes) + 1]
    local name = recruitNames[(Rng.hash(seed + 2101, serial, 2, 0) % #recruitNames) + 1]
    local positive = positives[(Rng.hash(seed + 2101, serial, 3, 0) % #positives) + 1]
    local negative = negatives[(Rng.hash(seed + 2101, serial, 4, 0) % #negatives) + 1]
    return { class = classKey, name = name, quirks = { positive, negative } }
end

local function merchantLedgerGateOpen(campaign)
    if not campaign or not campaign.flags or campaign.flags.merchant_ledger_accepted then
        return false
    end
    return (campaign.completedMissions and campaign.completedMissions.archive_regent == true)
        or (campaign.bossKills and campaign.bossKills.buried_archive == true)
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

local function combatHasWarden(combat)
    for _, enemy in ipairs((combat and combat.enemies) or {}) do
        local def = Defs.enemy(enemy.kind)
        if def and def.warden then
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
            hint = part.hint,
        }
    end
    return { id = id, kind = kind, rank = rank, hp = def.maxHp, stress = 0, statuses = {}, guard = 0, parts = parts, resurrected = false, deathSpawned = false, deathFrontDamaged = false, bossPhase = nil, nextBossSkill = nil }
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
            hint = part.hint,
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
        resurrected = enemy.resurrected == true,
        deathSpawned = enemy.deathSpawned == true,
        deathFrontDamaged = enemy.deathFrontDamaged == true,
        weakPointChainTurns = enemy.weakPointChainTurns or 0,
        bossPhase = enemy.bossPhase,
        nextBossSkill = enemy.nextBossSkill,
    }
end

local function inventoryFromStacks(stacks)
    return Inventory.new(stacks or {})
end

local function defaultFactions()
    local result = {}
    for _, factionKey in ipairs(Defs.factionOrder or {}) do
        result[factionKey] = { value = 0, state = "neutral" }
    end
    return result
end

local function newCampaign()
    local timer = Defs.campaignTimer("twin_timer_v1") or {}
    return {
        renown = 0,
        dread = 0,
        completedMissions = {},
        locationProgress = {},
        bossKills = {},
        victory = false,
        finalSeal = false,
        lost = false,
        lossReason = nil,
        weekLimit = timer.weekCap or 14,
        deathLimit = 8,
        dreadLimit = timer.dreadCap or 18,
        factions = defaultFactions(),
        flags = { repairMissions = 0, extractMissions = 0, greedyExtracts = 0 },
        endingRoute = nil,
    }
end

function Simulation.new(seed, options)
    options = options or {}
    local roster = {}
    for index = 1, 4 do
        local classKey = starterClassOrder[index]
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
            documents = {},
            documentLog = {},
            nextHeroId = 5,
            recruitSerial = 1,
        },
        party = { 1, 2, 3, 4 },
        expedition = nil,
        combat = nil,
        commandQueue = {},
        status = "ready",
        narration = "",
        documentPopup = nil,
        log = {},
        events = {},
        eventSerial = 0,
    }, Simulation)
    self:refillRecruits()
    self:refreshMissionBoard(true)
    self:refillTrinketMarket(true)
    if not options.startInEstate then
        self:startExpedition("buried_archive")
    end
    return self
end

function Simulation.newEstate(seed)
    return Simulation.new(seed, { startInEstate = true })
end

Simulation.commands = {}

function Simulation.commands.move(direction)
    return { type = "move", direction = direction }
end

function Simulation.commands.interact()
    return { type = "interact" }
end

function Simulation.commands.curioChoice(x, y, z, curioKey, choice)
    return { type = "curioChoice", x = x, y = y, z = z or 0, curioKey = curioKey, choice = choice }
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

function Simulation.commands.stealthApproach()
    return { type = "stealthApproach" }
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
    if command.type == "curioChoice" then
        return self:curioChoice(command.x, command.y, command.z, command.curioKey, command.choice)
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
    if command.type == "stealthApproach" then
        return self:stealthApproach()
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

function Simulation:narrate(kind, salt, filter)
    local lines = Defs.narrationFor(kind)
    if not lines or #lines == 0 then
        return false
    end
    local choices = {}
    for _, line in ipairs(lines) do
        if not filter or filter(line) then
            choices[#choices + 1] = line
        end
    end
    if #choices == 0 then
        return false
    end
    local index = (Rng.hash(self.seed + 9901, self.tick, self.rollIndex, #(salt or kind)) % #choices) + 1
    local line = choices[index]
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

function Simulation:heroHasSetPiece(hero, setDef)
    for _, trinketKey in ipairs(hero.trinkets or {}) do
        if trinketKey and contains(setDef.pieces or {}, trinketKey) then
            return true
        end
    end
    return false
end

function Simulation:trinketSetCounts()
    local counts = {}
    local setOrder = Defs.trinketSetOrder or {}
    local sets = Defs.trinketSets
    for _, setKey in ipairs(setOrder) do
        counts[setKey] = 0
    end
    for _, hero in ipairs(self:livingParty()) do
        for _, trinketKey in ipairs(hero.trinkets or {}) do
            if trinketKey then
                for _, setKey in ipairs(setOrder) do
                    local setDef = sets[setKey]
                    if setDef and contains(setDef.pieces or {}, trinketKey) then
                        counts[setKey] = (counts[setKey] or 0) + 1
                    end
                end
            end
        end
    end
    return counts
end

function Simulation:trinketSetModifier(hero, key)
    if not hero or not hasValue(hero.trinkets) then
        return 0
    end
    local counts = self:trinketSetCounts()
    local total = 0
    local sets = Defs.trinketSets
    for _, setKey in ipairs(Defs.trinketSetOrder or {}) do
        local setDef = sets[setKey]
        local count = counts[setKey] or 0
        if setDef and count >= 2 and self:heroHasSetPiece(hero, setDef) then
            total = total + ((setDef.twoPiece and setDef.twoPiece[key]) or 0)
            total = total + ((setDef.cost and setDef.cost[key]) or 0)
            if count >= 4 then
                total = total + ((setDef.fourPiece and setDef.fourPiece[key]) or 0)
            end
        end
    end
    return total
end

function Simulation:partyModifierMax(key)
    local best = 0
    for _, hero in ipairs(self:livingParty()) do
        best = math.max(best, self:heroModifier(hero, key))
    end
    return best
end

function Simulation:partyHasClass(classKey)
    for _, hero in ipairs(self:livingParty()) do
        if hero.class == classKey then
            return true
        end
    end
    return false
end

function Simulation:heroModifier(hero, key)
    local total = 0
    local quirks = Defs.quirks
    local diseases = Defs.diseases
    local trinkets = Defs.trinkets
    local injuries = Defs.injuries
    for _, quirkKey in ipairs(hero.quirks or {}) do
        local quirk = quirks[quirkKey]
        total = total + ((quirk and quirk[key]) or 0)
    end
    for _, diseaseKey in ipairs(hero.diseases or {}) do
        local disease = diseases[diseaseKey]
        total = total + ((disease and disease[key]) or 0)
    end
    for _, trinketKey in ipairs(hero.trinkets or {}) do
        local trinket = trinketKey and trinkets[trinketKey]
        total = total + ((trinket and trinket[key]) or 0)
    end
    for _, status in ipairs(hero.statuses or {}) do
        if status.kind == "injury" then
            local injury = injuries[status.injury]
            total = total + ((injury and injury[key]) or 0)
        end
    end
    if key == "damageBonus" and contains(hero.quirks, "quirk_bound_by_page") and self.expedition and self.expedition.location == "buried_archive" then
        total = total + ((quirks.quirk_bound_by_page and quirks.quirk_bound_by_page.custodianSkillBonus) or 0)
    end
    total = total + self:trinketSetModifier(hero, key)
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
    return Defs.heroClasses[hero.class]
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
        self:adjustDread((Defs.dreadRule("dread_rules_v1") or {}).hero_death or 0)
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

function Simulation:ensureCampaignState()
    self.estate.campaign = self.estate.campaign or newCampaign()
    local campaign = self.estate.campaign
    local timer = Defs.campaignTimer("twin_timer_v1") or {}
    campaign.completedMissions = campaign.completedMissions or {}
    campaign.locationProgress = campaign.locationProgress or {}
    campaign.bossKills = campaign.bossKills or {}
    campaign.flags = campaign.flags or { repairMissions = 0, extractMissions = 0, greedyExtracts = 0 }
    campaign.flags.repairMissions = campaign.flags.repairMissions or 0
    campaign.flags.extractMissions = campaign.flags.extractMissions or 0
    campaign.flags.greedyExtracts = campaign.flags.greedyExtracts or 0
    campaign.factions = campaign.factions or {}
    for _, factionKey in ipairs(Defs.factionOrder or {}) do
        campaign.factions[factionKey] = campaign.factions[factionKey] or { value = 0, state = "neutral" }
    end
    campaign.weekLimit = campaign.weekLimit or timer.weekCap or 14
    campaign.dreadLimit = campaign.dreadLimit or timer.dreadCap or 18
    campaign.deathLimit = campaign.deathLimit or 8
    return campaign
end

function Simulation:factionState(factionKey)
    local campaign = self:ensureCampaignState()
    local entry = campaign.factions[factionKey]
    local def = Defs.faction(factionKey)
    if not entry or not def then
        return nil
    end
    local value = entry.value or 0
    for _, state in ipairs(def.states or {}) do
        if not state.max or value <= state.max then
            entry.state = state.id
            return entry.state
        end
    end
    entry.state = ((def.states or {})[#(def.states or {})] or {}).id or "neutral"
    return entry.state
end

function Simulation:adjustFaction(factionKey, amount)
    if not Defs.faction(factionKey) or not amount or amount == 0 then
        return false
    end
    local campaign = self:ensureCampaignState()
    local entry = campaign.factions[factionKey] or { value = 0, state = "neutral" }
    entry.value = clamp((entry.value or 0) + amount, -4, 5)
    campaign.factions[factionKey] = entry
    self:factionState(factionKey)
    return true
end

function Simulation:localFactionForLocation(locationKey)
    if locationKey == "buried_archive" then
        return "faction_custodians"
    end
    if locationKey == "salt_cistern" then
        return "faction_cistern_keepers"
    end
    if locationKey == "ember_warrens" then
        return "faction_ember_penitents"
    end
    return nil
end

function Simulation:missionHasTag(mission, tag)
    return contains((mission and mission.tags) or {}, tag)
end

local function addFactionDelta(profile, factionKey, amount)
    if factionKey and amount and amount ~= 0 then
        profile.factions[factionKey] = (profile.factions[factionKey] or 0) + amount
    end
end

function Simulation:missionPressureProfile(mission, success, retreat)
    local rules = Defs.factionPressureRule("mission_pressure_v1") or {}
    local profile = { dread = 0, factions = {} }
    if not mission then
        return profile
    end
    if not success then
        profile.dread = retreat and (rules.abandonedDread or 1) or (rules.failedDread or 2)
        return profile
    end
    local localFaction = self:localFactionForLocation(mission.location)
    profile.dread = (rules.successDread or 0) + (mission.dreadBonus or 0) + (mission.dreadTradeoff or 0)
    if self:missionHasTag(mission, "repair") then
        profile.dread = profile.dread + (rules.repairDread or 0)
        addFactionDelta(profile, "enclave_meter", rules.repairEnclave or 0)
        addFactionDelta(profile, localFaction, rules.repairLocal or 0)
    end
    if self:missionHasTag(mission, "extract") and not self:missionHasTag(mission, "repair") then
        addFactionDelta(profile, "enclave_meter", rules.extractEnclave or 0)
        addFactionDelta(profile, localFaction, rules.extractLocal or 0)
    end
    if self:missionHasTag(mission, "rescue") then
        addFactionDelta(profile, "enclave_meter", rules.rescueEnclave or 0)
    end
    if self:missionHasTag(mission, "survey") then
        addFactionDelta(profile, "faction_lamplighters", rules.surveyLamplighters or 0)
    end
    if self:missionHasTag(mission, "cleanse") then
        addFactionDelta(profile, localFaction, rules.cleanseLocal or 0)
    end
    if self:missionHasTag(mission, "activate") and not self:missionHasTag(mission, "repair") then
        addFactionDelta(profile, localFaction, rules.activateLocal or 0)
    end
    if self:missionHasTag(mission, "seal") or mission.kind == "boss" then
        addFactionDelta(profile, localFaction, rules.sealLocal or 0)
        addFactionDelta(profile, "faction_lamplighters", rules.sealLamplighters or 0)
    end
    addFactionDelta(profile, mission.factionTradeoff or mission.factionCost, rules.factionTradeoff or 0)
    if mission.enclaveTradeoff then
        addFactionDelta(profile, "enclave_meter", rules.enclaveTradeoff or 0)
    end
    if mission.enclaveFavor then
        addFactionDelta(profile, "enclave_meter", mission.enclaveFavor)
    end
    if mission.namedNpcConsequence then
        addFactionDelta(profile, "enclave_meter", rules.namedNpcEnclave or 0)
        addFactionDelta(profile, localFaction, rules.namedNpcLocal or 0)
    end
    return profile
end

function Simulation:lateWeekPressure()
    local week = self.estate and (self.estate.week or 1) or 1
    if week <= 8 then
        return 0
    end
    return math.min(4, week - 8)
end

function Simulation:resolveEndingRoute(reason)
    local campaign = self:ensureCampaignState()
    if reason == "victory" then
        local repairs = campaign.flags.repairMissions or 0
        local extracts = campaign.flags.extractMissions or 0
        return repairs >= 3 and repairs >= extracts and "repair_compact" or "estate_seal"
    end
    if reason == "dread" then
        return "extraction_collapse"
    end
    return "quiet_failure"
end

function Simulation:endingRouteStatus()
    local campaign = self:ensureCampaignState()
    local bosses = 0
    for _, key in ipairs(Defs.locationOrder or {}) do
        if campaign.bossKills and campaign.bossKills[key] then
            bosses = bosses + 1
        end
    end
    local repairs = campaign.flags.repairMissions or 0
    local extracts = campaign.flags.extractMissions or 0
    local statuses = {}
    for _, routeKey in ipairs(Defs.endingRouteOrder or {}) do
        local route = Defs.endingRoute(routeKey) or {}
        local reached = false
        if routeKey == "estate_seal" then
            reached = bosses >= #(Defs.locationOrder or {}) and not (repairs >= 3 and repairs >= extracts)
        elseif routeKey == "repair_compact" then
            reached = bosses >= #(Defs.locationOrder or {}) and repairs >= 3 and repairs >= extracts
        elseif routeKey == "extraction_collapse" then
            reached = (campaign.dread or 0) >= (campaign.dreadLimit or 18)
        elseif routeKey == "quiet_failure" then
            reached = ((self.estate and self.estate.week) or 1) >= (campaign.weekLimit or 14) or #((self.estate and self.estate.graveyard) or {}) >= (campaign.deathLimit or 8)
        end
        statuses[#statuses + 1] = {
            key = routeKey,
            alias = route.alias or routeKey,
            name = route.name or routeKey,
            condition = route.condition or "",
            result = route.result or "",
            reached = reached,
        }
    end
    return statuses
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

function Simulation:classUnlocked(classKey)
    local rule = Defs.classUnlock(classKey) or {}
    if rule.default then
        return true
    end
    local campaign = self.estate.campaign or {}
    if rule.bossKill then
        return campaign.bossKills and campaign.bossKills[rule.bossKill] == true
    end
    if rule.location and rule.progress then
        return ((campaign.locationProgress and campaign.locationProgress[rule.location]) or 0) >= rule.progress
    end
    if rule.eventFlag then
        return campaign.flags and campaign.flags[rule.eventFlag] == true
    end
    return false
end

function Simulation:classUnlockStatus()
    local result = {}
    for _, classKey in ipairs(Defs.classUnlockOrder or Defs.heroClassOrder) do
        local class = Defs.heroClass(classKey) or {}
        local rule = Defs.classUnlock(classKey) or {}
        result[#result + 1] = {
            class = classKey,
            name = class.name or classKey,
            unlocked = self:classUnlocked(classKey),
            reason = rule.reason or "Locked.",
        }
    end
    return result
end

function Simulation:unlockedClassKeys()
    local result = {}
    for _, status in ipairs(self:classUnlockStatus()) do
        if status.unlocked then
            result[#result + 1] = status.class
        end
    end
    return #result > 0 and result or { "warden" }
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

function Simulation:applyFactionHazards(mission)
    if not self.expedition then
        return false
    end
    local applied = false
    local hazards = Defs.factionHazard("faction_hazards_v1")
    for _, hazard in pairs(hazards or {}) do
        if self:factionState(hazard.faction) == hazard.state then
            if hazard.torch then
                self.expedition.torch = clamp((self.expedition.torch or 0) + hazard.torch, 0, 100)
                applied = true
            end
            if hazard.heatFatigue and mission and mission.location == "ember_warrens" then
                self.expedition.heatFatigue = (self.expedition.heatFatigue or 0) + hazard.heatFatigue
                applied = true
            end
            if hazard.packSlots then
                self.expedition.packSlots = math.max(6, (self.expedition.packSlots or 12) + hazard.packSlots)
                applied = true
            end
        end
    end
    return applied
end

function Simulation:applyStartOfMissionPressure(mission)
    if not self.expedition then
        return false
    end
    local applied = false
    local event = Defs.townEvent(self.estate.currentEvent)
    if event and event.nextMissionNoise and self:missionHasTag(mission, "survey") then
        self:addNoise(event.nextMissionNoise)
        applied = true
    end
    local late = self:lateWeekPressure()
    if late > 0 then
        self.expedition.latePressure = late
        self:addNoise(late)
        applied = true
    end
    if mission.location == "ember_warrens" then
        for rank = 1, 4 do
            local hero = self:heroAtRank(rank)
            local quirk = Defs.quirk("quirk_bound_by_page")
            if hero and contains(hero.quirks, "quirk_bound_by_page") and self:roll(1, 100) <= (quirk.emberPanicChance or 0) then
                hero.affliction = hero.affliction or "panic"
                applied = true
            end
        end
    end
    return applied
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
        alphaMarkers = {},
        noise = 0,
        ambushRolls = 0,
        stealthApproach = false,
        heatFatigue = 0,
        corridorVisits = {},
        currentCorridor = nil,
        generatedLayoutId = self.world:layout().generatedLayoutId,
        campUsed = false,
        objectiveComplete = false,
        bossDefeated = false,
        log = {},
    }
    self:applyFactionHazards(mission)
    self:applyMerchantCutPackBonus()
    if mission.noisePressure then
        self:addNoise(mission.noisePressure)
    end
    self:applyStartOfMissionPressure(mission)
    self:applyMissionLevelPenalty(mission)
    self:discoverCurrentRoom()
    self:pushLog("entered " .. mission.name)
    self:narrate("mission_start", missionKey)
    self:narrate("location_barks", mission.location, function(line)
        return line.location == mission.location
    end)
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
        self.estate.gold = self.estate.gold + coin + (reward.gold or 0) + self:partyModifierMax("rewardBonus")
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
    local campaign = self:ensureCampaignState()
    local locationKey = mission and mission.location or (self.expedition and self.expedition.location) or "buried_archive"
    local missionKey = self.expedition and self.expedition.mission or (mission and mission.name) or locationKey
    local pressure = self:missionPressureProfile(mission, success, retreat)
    if success then
        local progress = mission.kind == "boss" and 2 or 1
        campaign.renown = (campaign.renown or 0) + progress
        campaign.dread = math.max(0, (campaign.dread or 0) + (pressure.dread or 0))
        if self:missionHasTag(mission, "repair") then
            campaign.flags.repairMissions = (campaign.flags.repairMissions or 0) + 1
        end
        if self:missionHasTag(mission, "extract") then
            campaign.flags.extractMissions = (campaign.flags.extractMissions or 0) + 1
            if not self:missionHasTag(mission, "repair") then
                campaign.flags.greedyExtracts = (campaign.flags.greedyExtracts or 0) + 1
            end
        end
        for factionKey, amount in pairs(pressure.factions or {}) do
            self:adjustFaction(factionKey, amount)
        end
        local event = Defs.townEvent(self.estate.currentEvent)
        if event and event.completionDread then
            campaign.dread = math.max(0, (campaign.dread or 0) + event.completionDread)
        end
        campaign.completedMissions[missionKey] = true
        campaign.locationProgress[locationKey] = (campaign.locationProgress[locationKey] or 0) + progress
        if mission.kind == "boss" then
            campaign.bossKills[locationKey] = true
        end
    else
        campaign.dread = math.max(0, (campaign.dread or 0) + (pressure.dread or 0))
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
        campaign.endingRoute = self:resolveEndingRoute("victory")
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
    local campaign = self:ensureCampaignState()
    if campaign.victory then
        campaign.lost = false
        campaign.lossReason = nil
        campaign.endingRoute = campaign.endingRoute or self:resolveEndingRoute("victory")
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
        campaign.endingRoute = self:resolveEndingRoute(campaign.lossReason)
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
    local late = self:lateWeekPressure()
    if dread < 6 and late <= 0 then
        return false
    end
    local stress = (dread >= 6 and math.max(2, math.floor(dread / 6)) or 0) + late
    if stress <= 0 then
        return false
    end
    for _, hero in ipairs(self.estate.roster) do
        if hero.alive and (hero.recovering or 0) <= 0 then
            self:addStress(hero, stress)
        end
    end
    self:pushLog(late > 0 and "late weeks tighten" or "dread weighs on the estate")
    return true
end

function Simulation:rollTownEvent()
    local order = Defs.townEventOrder
    if not order or #order == 0 then
        return false
    end
    local campaign = self:ensureCampaignState()
    if merchantLedgerGateOpen(campaign) then
        return self:applyTownEvent("merchant_ledger_offer")
    end
    if (campaign.flags.repairMissions or 0) >= 3 and not campaign.flags.enclaveCompactSigned then
        campaign.flags.enclaveCompactSigned = true
        return self:applyTownEvent("enclave_compact_signed")
    end
    if (campaign.dread or 0) >= (campaign.dreadLimit or 18) - 2 and not campaign.flags.estateReckoning then
        campaign.flags.estateReckoning = true
        return self:applyTownEvent("estate_reckoning")
    end
    local randomOrder = {}
    for index = 1, math.min(8, #order) do
        randomOrder[#randomOrder + 1] = order[index]
    end
    local eventKey = randomOrder[(Rng.hash(self.seed + 4409, self.estate.week or 1, #self.estate.eventHistory + 1, 0) % #randomOrder) + 1]
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
    if event.dread then
        self:adjustDread(event.dread)
    end
    for factionKey, amount in pairs(event.faction or {}) do
        self:adjustFaction(factionKey, amount)
    end
    if event.openMission then
        appendUnique(self.estate.missionBoard, event.openMission)
    end
    for item, count in pairs(event.provisions or {}) do
        self.estate.provisionCart:add(item, count)
    end
    if event.merchantUnlock then
        self:unlockMerchantLedger()
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
    local meta = event.cutsceneEvent and { event = event.cutsceneEvent, actor = event.name, side = "ally" } or nil
    self:pushLog("event: " .. event.name, meta)
    return true
end

function Simulation:unlockMerchantLedger()
    local campaign = self:ensureCampaignState()
    if campaign.flags.merchant_ledger_accepted then
        return false
    end
    campaign.flags.merchant_ledger_accepted = true
    self.estate.recruits = self.estate.recruits or {}
    table.insert(self.estate.recruits, 1, { class = "merchant", name = heroNames.merchant, quirks = copyList(defaultQuirks.merchant) })
    while #self.estate.recruits > self:recruitSlots() do
        table.remove(self.estate.recruits)
    end
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

function Simulation:hasDocument(documentKey)
    return self.estate and self.estate.documents and self.estate.documents[documentKey] == true
end

function Simulation:documentBankForLocation(locationKey)
    local rule = Defs.documentDropRule("document_drop_rules") or {}
    local bankKey = rule.bankByLocation and rule.bankByLocation[locationKey]
    return bankKey and Defs.documentBank(bankKey) or nil
end

function Simulation:collectDocument(documentKey, source)
    local document = Defs.document(documentKey)
    if not document or self:hasDocument(documentKey) then
        return false
    end
    self.estate.documents = self.estate.documents or {}
    self.estate.documentLog = self.estate.documentLog or {}
    self.estate.documents[documentKey] = true
    appendUnique(self.estate.documentLog, documentKey)
    self.documentPopup = { key = documentKey, title = document.title, text = document.text }
    self:pushLog("document: " .. document.title)
    local bark = (Defs.fixtureDocumentBark("fixture_document_barks") or {})[document.type]
    if bark then
        local fixture = Defs.estateFixture(bark.fixture)
        self:pushLog((fixture and fixture.name or "Estate") .. ": " .. bark.text)
    end
    return true
end

function Simulation:collectDocumentFromLocation(locationKey, source)
    local bank = self:documentBankForLocation(locationKey)
    if not bank then
        return false
    end
    for _, documentKey in ipairs(bank.documents or {}) do
        if not self:hasDocument(documentKey) then
            return self:collectDocument(documentKey, source)
        end
    end
    return false
end

function Simulation:dropDocument(source)
    if not self.expedition then
        return false
    end
    local rule = Defs.documentDropRule("document_drop_rules") or {}
    if source == "curio" and not rule.curio then
        return false
    end
    if source == "room_loot" and not rule.roomLoot then
        return false
    end
    if source == "warden" and not rule.warden then
        return false
    end
    return self:collectDocumentFromLocation(self.expedition.location, source)
end

function Simulation:journalEntries()
    local result = {}
    local seen = {}
    local function add(documentKey)
        if seen[documentKey] or not self:hasDocument(documentKey) then
            return
        end
        local document = Defs.document(documentKey)
        if not document then
            return
        end
        seen[documentKey] = true
        local documentType = Defs.documentType(document.type)
        result[#result + 1] = {
            key = documentKey,
            title = document.title,
            type = document.type,
            typeName = documentType and documentType.name or document.type,
            location = document.location,
            abstract = document.abstract,
        }
    end
    for _, documentKey in ipairs((self.estate and self.estate.documentLog) or {}) do
        add(documentKey)
    end
    for _, documentKey in ipairs(Defs.documentOrder) do
        add(documentKey)
    end
    return result
end

function Simulation:missionIntro(missionKey)
    local mission = Defs.mission(missionKey or (self.expedition and self.expedition.mission) or "archive_scout")
    return mission and mission.intro or nil
end

function Simulation:curioCopy(curioKey)
    local curio = Defs.curio(curioKey)
    return curio and curio.copy or nil
end

function Simulation:bestiaryEntry(enemyKey)
    local enemy = Defs.enemy(enemyKey)
    return enemy and enemy.bestiary or nil
end

function Simulation:glossaryEntries()
    local terms = Defs.glossary("terms_v1") or {}
    local result = {}
    for _, key in ipairs({ "dread", "noise", "injury", "alpha", "repair", "extraction" }) do
        result[#result + 1] = { key = key, text = terms[key] }
    end
    return result
end

function Simulation:panelCopy(copyKey)
    return Defs.panelCopyFor(copyKey)
end

function Simulation:endingScreenCopy(routeKey)
    local copy = Defs.panelCopyFor("ending_screen_copy") or {}
    local route = Defs.endingRoute(routeKey) or {}
    return copy[routeKey] or route.result
end

function Simulation:originBark(classKey, eventKey)
    local bank = Defs.originBark("origin_barks_v1") or {}
    local classBarks = bank[classKey] or {}
    return classBarks[eventKey]
end

function Simulation:enclaveLeaderReaction(leaderKey)
    local leader = Defs.enclaveLeader(leaderKey)
    if not leader then
        return nil
    end
    local bank = Defs.enclaveLeaderBark("enclave_leader_barks") or {}
    local factionKey = leader.faction
    local merchantBarks = bank.merchant or {}
    if self:partyHasClass("merchant") and factionKey and merchantBarks[factionKey] then
        return merchantBarks[factionKey]
    end
    local state = factionKey and self:factionState(factionKey) or "neutral"
    if state == "hostile" or state == "embargo" or state == "pyre_open" or state == "strike" then
        return bank.high or leader.barks[1]
    end
    if state ~= "neutral" then
        return bank.tense or leader.barks[1]
    end
    return bank.low or leader.barks[1]
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
    local classes = self:unlockedClassKeys()
    local unlocked = {}
    for _, classKey in ipairs(classes) do
        unlocked[classKey] = true
    end
    local kept = {}
    for _, recruit in ipairs(self.estate.recruits) do
        if unlocked[recruit.class] then
            kept[#kept + 1] = recruit
        end
    end
    self.estate.recruits = kept
    while #self.estate.recruits < self:recruitSlots() do
        local serial = self.estate.recruitSerial or 1
        self.estate.recruits[#self.estate.recruits + 1] = recruitCandidate(self.seed, serial, classes)
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
    local event = Defs.townEvent(self.estate.currentEvent)
    local multiplier = (event and event.provisionCostMultiplier) or 1
    local surcharge = (event and event.torchDelay and item == "torch") and event.torchDelay or 0
    local cost = ((def.cost or 0) * multiplier + surcharge) * count
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
    local event = Defs.townEvent(self.estate.currentEvent)
    local multiplier = (event and event.recoveryCostMultiplier) or 1
    local cost = (activity and activity.cost or math.max(0, def.recoverCost - self:buildingLevel("infirmary") * def.discountPerLevel)) * multiplier
    if not hero or not hero.alive or (hero.recovering or 0) > 0 or self.estate.gold < cost then
        return false
    end
    self.estate.gold = self.estate.gold - cost
    self:healStress(hero, (activity and activity.stressHeal or 30) + self:heroModifier(hero, "stressRecoveryBonus"))
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
    self:narrate("low_torch_zone_voice", self.expedition.location, function(line)
        return line.location == self.expedition.location
    end)
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
    local discount = self:partyModifierMax("noiseDiscount")
    self.expedition.noise = clamp((self.expedition.noise or 0) + math.max(0, (amount or 1) - discount), 0, 12)
    return true
end

function Simulation:decayNoise(amount)
    if not self.expedition then
        return false
    end
    self.expedition.noise = math.max(0, (self.expedition.noise or 0) - (amount or 1))
    return true
end

function Simulation:isAlphaThreatKey(threatKey)
    if not threatKey or not self.world then
        return false
    end
    for _, threat in ipairs(self.world:layout().threats or {}) do
        if threat.key == threatKey then
            return threat.rare == true
        end
    end
    return false
end

function Simulation:updateThreatBehaviors()
    if not self.expedition or not self.world then
        return false
    end
    local changed = false
    local behavior = Defs.threatBehavior("visible_threat_behaviors") or {}
    local alphaStalk = Defs.alphaRule("alpha_stalk_corridor") or {}
    for _, threat in ipairs(self.world:threatsInRect(self.player.x - 8, self.player.x + 8, self.player.y - 8, self.player.y + 8, self.player.z or 0)) do
        if not self.expedition.clearedEncounters[threat.key] and threat.rare then
            self.expedition.alphaMarkers[threat.key] = { x = threat.x, y = threat.y, roomKey = threat.roomKey }
            if threat.roomKey and not self.expedition.threatState[threat.roomKey] then
                self.expedition.threatState[threat.roomKey] = alphaStalk.state or (behavior.stalk and behavior.stalk.state) or "stalked"
            end
            changed = true
        end
    end
    return changed
end

function Simulation:stealthApproach()
    if self.mode ~= "expedition" or not self.expedition then
        return false
    end
    local rule = Defs.expeditionCommand("stealth_approach") or {}
    local cost = rule.torchCost or 10
    if (self.expedition.torch or 0) < cost then
        return false
    end
    local x, y, z = self:targetCell()
    local threat = self.world:threatAt(x, y, z)
    if not threat or self.expedition.clearedEncounters[threat.key] then
        return false
    end
    self.expedition.torch = math.max(0, self.expedition.torch - cost)
    self.expedition.stealthApproach = true
    if threat.roomKey then
        self.expedition.threatState[threat.roomKey] = "stealthed"
    end
    self:pushLog("stealth approach")
    return true
end

function Simulation:lureThreat()
    if self.mode ~= "expedition" or not self.expedition then
        return false
    end
    for _, threat in ipairs(self.world:threatsInRect(-999, 999, -999, 999, self.player.z or 0)) do
        if not self.expedition.clearedEncounters[threat.key] then
            self.expedition.clearedEncounters[threat.key] = true
            if threat.roomKey then
                self.expedition.threatState[threat.roomKey] = "lured"
            end
            self:addNoise(2)
            self:pushLog("bait chime lured threat")
            return true
        end
    end
    return false
end

function Simulation:adjustDread(amount)
    if not self.estate or not self.estate.campaign or not amount or amount == 0 then
        return false
    end
    self.estate.campaign.dread = math.max(0, (self.estate.campaign.dread or 0) + amount)
    self:evaluateCampaignState()
    return true
end

function Simulation:dreadTier()
    local campaign = self:ensureCampaignState()
    local cap = math.max(1, campaign.dreadLimit or 18)
    return clamp(math.floor(((campaign.dread or 0) / cap) * 4), 0, 4)
end

function Simulation:applyMerchantCutPackBonus()
    if not self.expedition or self.expedition.merchantCutPackApplied or not self:partyHasClass("merchant") then
        return false
    end
    local rule = Defs.rewardRule("merchant_cut") or {}
    if self:dreadTier() < (rule.packDreadTier or 2) then
        return false
    end
    self.expedition.packSlots = (self.expedition.packSlots or 12) + (rule.packSlots or 1)
    self.expedition.merchantCutPackApplied = true
    return true
end

function Simulation:grantMerchantCutRoomLoot()
    if not self.expedition or self.expedition.merchantCutLootClaimed or not self:partyHasClass("merchant") then
        return false
    end
    local rule = Defs.rewardRule("merchant_cut") or {}
    if self:dreadTier() < (rule.lootDreadTier or 4) then
        return false
    end
    local granted = false
    if rule.bonusCoin then
        granted = self:addLoot("coin", rule.bonusCoin) or granted
    end
    if rule.bonusRelic then
        granted = self:addLoot("relic", rule.bonusRelic) or granted
    end
    if granted then
        self.expedition.merchantCutLootClaimed = true
        self:pushLog("merchant cut claimed")
    end
    return granted
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
    if roleDef.heatFatigueOnBacktrack and visits > 0 then
        self.expedition.heatFatigue = (self.expedition.heatFatigue or 0) + roleDef.heatFatigueOnBacktrack
        self:pushLog(role .. " raised heat")
        return true
    end
    if roleDef.ambushNoise then
        self:addNoise(roleDef.ambushNoise)
        self:pushLog(role .. " hid threats")
        return true
    end
    if roleDef.floodAfterActivations and (self.expedition.questActivations or 0) >= roleDef.floodAfterActivations then
        self:addNoise(roleDef.noise or 1)
        self:pushLog(role .. " flooded")
        return true
    end
    if roleDef.diseaseRisk then
        local hero = self:heroAtRank(self.player.selectedHero) or self:heroAtRank(1)
        self:contractDisease(hero, roleDef.diseaseRisk)
        self:pushLog(role .. " carried disease")
        return true
    end
    if roleDef.rankPullLowTorch and (self.expedition.torch or 0) < (roleDef.torchThreshold or 35) then
        self:moveHeroRank(1, 1)
        self:pushLog(role .. " pulled ranks")
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
    local downgrade = Defs.ambushRule("stealth_downgrade") or {}
    local stealthed = self.expedition.stealthApproach and (self.expedition.torch or 0) >= (downgrade.fullTorch or 70)
    self.expedition.stealthApproach = false
    return self:startCombat("archive_ambush", key, { ambush = not stealthed, pressure = true, stealthed = stealthed })
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
    self:updateThreatBehaviors()
    local tile = self.world:getTile(self.player.x, self.player.y, self.player.z)
    self:pushLog("moved " .. direction, { event = "move", direction = direction, tile = tile and tile.id })
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

function Simulation:campMarkerAt(x, y, z)
    if not self.world then
        return false
    end
    local tile = self.world:getTile(x, y, z or 0)
    return tile and tile.id == "camp_marker"
end

function Simulation:canCampHere(x, y, z)
    local playerZ = self.player.z or 0
    local targetX, targetY, targetZ = self:targetCell()
    targetZ = targetZ or 0
    if x then
        local zValue = z or 0
        local matchesPlayer = x == self.player.x and y == self.player.y and zValue == playerZ
        local matchesTarget = x == targetX and y == targetY and zValue == targetZ
        return (matchesPlayer or matchesTarget) and self:campMarkerAt(x, y, zValue)
    end
    if self:campMarkerAt(self.player.x, self.player.y, playerZ) then
        return true
    end
    return self:campMarkerAt(targetX, targetY, targetZ)
end

function Simulation:targetCurio()
    if self.mode ~= "expedition" then
        return nil
    end
    local x, y, z = self:targetCell()
    local tile = self.world:getTile(x, y, z)
    local tileDef = Defs.tile(tile.id)
    if not (tileDef and tileDef.curio and Defs.curio(tileDef.curio)) then
        return nil
    end
    return { x = x, y = y, z = z, key = tileDef.curio, curio = Defs.curio(tileDef.curio), usedKey = Grid.key(x, y, z) }
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
            self.expedition.threatState[threat.roomKey] = self.expedition.threatState[threat.roomKey] == "stealthed" and "stealthed" or "engaged"
        end
        self:addNoise(1)
        local stealthed = self.expedition.stealthApproach == true
        self.expedition.stealthApproach = false
        return self:startCombat(threat.encounter, threat.key, { visible = true, threatKey = threat.key, stealthed = stealthed })
    end
    if tileDef.encounter then
        return self:startCombat(tileDef.encounter, self:currentRoomKey() or (x .. ":" .. y))
    end
    self:pushLog("nothing useful")
    return false
end

function Simulation:curioChoice(x, y, z, curioKey, choice)
    choice = choice or "safe_use"
    if choice == "leave_alone" then
        local curio = Defs.curio(curioKey)
        self:pushLog((curio and curio.name or "curio") .. " left alone")
        return true
    end
    local options = { ignoreRefusal = true }
    if choice == "greedy_use" then
        options.forceNoItem = true
    end
    return self:resolveCurio(x, y, z or 0, curioKey, options)
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
        return self:camp(x, y, z)
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
        if curio.partyStressHeal then
            self:healPartyStress(curio.partyStressHeal)
        end
        if curio.dread then
            self:adjustDread(curio.dread)
        end
        if curio.heatFatigue then
            self.expedition.heatFatigue = (self.expedition.heatFatigue or 0) + curio.heatFatigue
        end
        self:updateObjective()
        self:pushLog(curio.name .. " activated")
        self:narrate("curio", curioKey)
        self:dropDocument("curio")
        return true
    end
    local hero = self:heroAtRank(self.player.selectedHero) or self:heroAtRank(1)
    if self:heroModifier(hero, "curioRefusal") > 0 and not (options and options.ignoreRefusal) and self:roll(1, 100) <= self:heroModifier(hero, "curioRefusal") then
        self:pushLog(hero.name .. " refused the curio")
        return false
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
    if curio.damage and not usedItem then
        self:damageHero(hero, curio.damage)
        self:addRandomInjury(hero, curioKey)
        if curioKey == "ash_vent" or curioKey == "wire_snare" then
            self:maybeContractDisease(hero, curioKey)
        end
    end
    if curio.disease and not usedItem then
        self:contractDisease(hero, curio.disease)
    end
    if curio.stress then
        if curio.stress < 0 then
            self:healStress(hero, -curio.stress)
        else
            self:addStress(hero, usedItem and math.floor(curio.stress / 2) or curio.stress)
        end
    end
    if curio.partyStressHeal and usedItem then
        self:healPartyStress(curio.partyStressHeal)
    end
    if curio.noise and not usedItem then
        self:addNoise(curio.noise)
    end
    if curio.dread and (curio.dread > 0 or usedItem) then
        self:adjustDread(curio.dread)
    end
    if curio.heatFatigue and not usedItem then
        self.expedition.heatFatigue = (self.expedition.heatFatigue or 0) + curio.heatFatigue
    end
    self.expedition.curiosUsed[key] = true
    self.world:setTile(x, y, z, { id = self.world:floorTile(), data = 0 })
    self:updateObjective()
    self:pushLog(curio.name .. " resolved")
    self:narrate("curio", curioKey)
    self:dropDocument("curio")
    return true
end

function Simulation:camp(x, y, z)
    if self.mode ~= "expedition" or not self.expedition then
        return false
    end
    if self.expedition.camping then
        return self:finishCamp()
    end
    if self.expedition.campUsed then
        return false
    end
    if not self:canCampHere(x, y, z) then
        self:pushLog("camp requires cold camp")
        return false
    end
    self.expedition.campUsed = true
    self.expedition.camping = { respite = 4, usedSkills = {}, ambushPrevented = false }
    self:decayNoise((Defs.pressureRule("noise_decay") or {}).camp or 2)
    local rations = self.expedition.supplies:count("ration")
    if rations > 0 then
        self.expedition.supplies:consume("ration", math.min(2, rations))
    end
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
    self:narrate("camp_complicity_voice", "camped")
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

function Simulation:campTrinketCount()
    local count = 0
    for _, hero in ipairs(self:livingParty()) do
        for _, trinketKey in ipairs(hero.trinkets or {}) do
            if trinketKey then
                count = count + 1
            end
        end
    end
    for _, trinketKey in ipairs(Defs.trinketOrder or {}) do
        count = count + ((self.estate.trinkets or {})[trinketKey] or 0)
    end
    return count
end

function Simulation:consumeCampTrinket()
    for _, hero in ipairs(self:livingParty()) do
        for slot, trinketKey in ipairs(hero.trinkets or {}) do
            if trinketKey then
                hero.trinkets[slot] = false
                return trinketKey
            end
        end
    end
    for _, trinketKey in ipairs(Defs.trinketOrder or {}) do
        if ((self.estate.trinkets or {})[trinketKey] or 0) > 0 then
            self.estate.trinkets[trinketKey] = self.estate.trinkets[trinketKey] - 1
            return trinketKey
        end
    end
    return nil
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
    for item, count in pairs(skill.itemCost or {}) do
        if self.expedition.supplies:count(item) < count then
            return false
        end
    end
    if skill.trinketCost and self:campTrinketCount() < skill.trinketCost then
        return false
    end
    for item, count in pairs(skill.itemCost or {}) do
        self.expedition.supplies:consume(item, count)
    end
    for _ = 1, skill.trinketCost or 0 do
        self:consumeCampTrinket()
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
        if skill.clearDisease and #(target.diseases or {}) > 0 then
            table.remove(target.diseases, 1)
            target.hp = math.min(target.hp, self:maxHp(target))
        end
    end
    if skill.dread then
        self:adjustDread(skill.dread)
    end
    if skill.clearHeatFatigue and self.expedition then
        self.expedition.heatFatigue = 0
    end
    for factionKey, cost in pairs(skill.factionCost or {}) do
        local entry = self:ensureCampaignState().factions[factionKey]
        local paid = math.min(cost, math.max(0, (entry and entry.value) or 0))
        if paid > 0 then
            self:adjustFaction(factionKey, -paid)
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
    local noiseRule = Defs.ambushRule("camp_ambush_noise") or {}
    if (self.expedition.noise or 0) >= (noiseRule.noise or 10) and not camping.ambushPrevented then
        self:pushLog("noise drew camp ambush")
        return self:startCombat(noiseRule.encounter or "archive_ambush", "camp_noise", { ambush = true, pressure = true })
    end
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
        local torchGain = 25 + self:partyModifierMax("torchEfficiency") - self:heroModifier(hero, "torchWaste")
        self.expedition.torch = clamp(self.expedition.torch + torchGain, 0, 100)
        local noiseRule = Defs.pressureRule("noise_decay") or {}
        if self.expedition.torch >= (noiseRule.highTorchThreshold or 75) then
            self:decayNoise(noiseRule.highTorch or 1)
        end
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
    elseif item == "bait_chime" then
        if not self:lureThreat() then
            self.expedition.supplies:add(item, 1)
            return false
        end
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
        stealthed = options.stealthed == true,
        threatKey = options.threatKey,
        partRepaired = false,
        log = {},
    }
    if self.combat.ambush and self.expedition then
        self.expedition.torch = 0
    end
    local hasBoss = combatHasBoss(self.combat)
    if hasBoss then
        for _, enemy in ipairs(self.combat.enemies) do
            local def = Defs.enemy(enemy.kind)
            if def and def.boss then
                self:announceBossWeakPoints(enemy)
                self:applyBossPhase(enemy, true)
            end
        end
    end
    self:pushLog("combat: " .. encounterKey, { event = self.combat.ambush and "ambush_start" or (hasBoss and "boss_start" or "combat_start"), encounter = encounterKey, boss = hasBoss, enemies = combatEnemyNames(self.combat) })
    self:narrate("combat_start", encounterKey)
    if combatHasWarden(self.combat) then
        self:narrate("warden_voice_v1", encounterKey)
    end
    if hasBoss then
        for _, enemy in ipairs(self.combat.enemies) do
            local def = Defs.enemy(enemy.kind)
            for _, phase in ipairs((def and def.bossPhases) or {}) do
                if phase.key == enemy.bossPhase and phase.dialogue then
                    self.narration = phase.dialogue
                end
            end
        end
    end
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
    local enemyDef = enemy and Defs.enemies[enemy.kind]
    return enemyDef and enemyDef.speed or 0
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

function Simulation:disabledPartCount(enemy)
    local count = 0
    for _, part in ipairs((enemy and enemy.parts) or {}) do
        if part.disabled then
            count = count + 1
        end
    end
    return count
end

function Simulation:bossPhaseFor(enemy, opening)
    local def = Defs.enemy(enemy and enemy.kind)
    if not def or not def.bossPhases then
        return nil
    end
    local selected = nil
    for _, phase in ipairs(def.bossPhases) do
        local matched = opening and phase.opening == true
        if not matched and not phase.opening then
            if phase.disabledParts and self:disabledPartCount(enemy) >= phase.disabledParts then
                matched = true
            end
            if phase.hpBelow and (enemy.hp or 0) <= (def.maxHp or 1) * phase.hpBelow then
                matched = true
            end
        end
        if matched then
            selected = phase
        end
    end
    return selected
end

function Simulation:applyBossPhase(enemy, opening)
    local phase = self:bossPhaseFor(enemy, opening)
    if not phase or enemy.bossPhase == phase.key then
        return false
    end
    local def = Defs.enemy(enemy.kind)
    enemy.bossPhase = phase.key
    enemy.nextBossSkill = phase.preferredSkill
    if phase.dialogue then
        self.narration = phase.dialogue
    end
    self:pushLog(def.name .. " entered " .. (phase.name or phase.key), {
        event = "boss_phase",
        actor = def.name,
        phase = phase.key,
        phaseName = phase.name,
        dialogue = phase.dialogue,
        boss = true,
        side = "enemy",
    })
    return true
end

function Simulation:announceBossWeakPoints(enemy)
    local def = Defs.enemy(enemy and enemy.kind)
    if not def or not def.boss or #(enemy.parts or {}) == 0 then
        return false
    end
    local parts = {}
    for _, part in ipairs(enemy.parts or {}) do
        parts[#parts + 1] = (part.name or part.key) .. " - " .. (part.hint or "break to weaken")
    end
    self:pushLog(def.name .. " weak points: " .. table.concat(parts, "; "), {
        event = "boss_weak_points",
        actor = def.name,
        parts = parts,
        boss = true,
        side = "enemy",
    })
    return true
end

function Simulation:repairDisabledPart(support)
    if not self.combat or self.combat.partRepaired then
        return false
    end
    local supportDef = Defs.enemy(support and support.kind)
    if not supportDef or not contains(supportDef.roles, "support") then
        return false
    end
    local rule = Defs.supportRule("part_repair_skill") or {}
    for _, ally in ipairs(self.combat.enemies or {}) do
        local allyDef = Defs.enemy(ally.kind)
        if ally ~= support and ally.hp > 0 and allyDef and (allyDef.elite or contains(allyDef.roles, "elite")) then
            for _, part in ipairs(ally.parts or {}) do
                if part.disabled then
                    part.disabled = false
                    part.hp = math.min(part.maxHp or (rule.heal or 4), math.max(1, rule.heal or 4))
                    self.combat.partRepaired = true
                    self:pushLog(supportDef.name .. " repaired " .. (part.name or part.key), { event = "enemy_support", actor = supportDef.name, side = "enemy" })
                    return true
                end
            end
        end
    end
    return false
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

function Simulation:afterEnemyDamaged(enemy)
    if not enemy or enemy.hp > 0 then
        return false
    end
    local def = Defs.enemy(enemy.kind)
    if not def then
        return false
    end
    if def.resurrectOnce and not enemy.resurrected then
        enemy.resurrected = true
        enemy.hp = math.max(1, math.floor((def.maxHp or 2) / 2))
        self:pushLog(def.name .. " rose again", { event = "danger", actor = def.name, side = "enemy" })
        return true
    end
    if def.deathSpawn and not enemy.deathSpawned then
        enemy.deathSpawned = true
        local spawned = newEnemy(#self.combat.enemies + 1, def.deathSpawn, enemy.rank or (#self.combat.enemies + 1))
        self.combat.enemies[#self.combat.enemies + 1] = spawned
        self:pushLog(def.name .. " burst", { event = "danger", actor = def.name, side = "enemy" })
        return true
    end
    if def.deathFrontDamage and not enemy.deathFrontDamaged then
        enemy.deathFrontDamaged = true
        local hero = self:heroAtRank(1)
        if hero and hero.alive then
            self:damageHero(hero, def.deathFrontDamage)
            self:pushLog(def.name .. " immolated", { event = "danger", actor = def.name, side = "enemy" })
            return true
        end
    end
    return false
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
    local enemyDef = Defs.enemy(enemy.kind)
    local message = enemyDef.name .. " lost " .. (part.name or part.key)
    local logRule = Defs.weakPointRule("part_disable_log") or {}
    if logRule.includeDisabledSkill and #(part.skillLocks or {}) > 0 then
        local names = {}
        for _, skillKey in ipairs(part.skillLocks or {}) do
            names[#names + 1] = (Defs.enemySkill(skillKey) or {}).name or skillKey
        end
        message = message .. " disabled " .. table.concat(names, ", ")
    end
    self:pushLog(message, { event = "danger", actor = enemyDef.name, side = "enemy" })
    local chainRule = Defs.weakPointRule("weak_point_chain") or {}
    if self:disabledPartCount(enemy) >= (chainRule.disabledParts or 2) and not self:hasStatus(enemy, "daze") then
        enemy.statuses = enemy.statuses or {}
        enemy.statuses[#enemy.statuses + 1] = { kind = "daze", turns = chainRule.dazeTurns or 1 }
        enemy.weakPointChainTurns = chainRule.dazeTurns or 1
        self:pushLog(enemyDef.name .. " procedure broke", { event = "falter", actor = enemyDef.name, side = "enemy" })
    end
    self:applyBossPhase(enemy, false)
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
    if skill.targetMostInjured then
        table.sort(candidates, function(a, b)
            return (a.hp or 0) < (b.hp or 0)
        end)
        return { candidates[1] }
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
    if enemy.nextBossSkill and contains(legal, enemy.nextBossSkill) then
        return enemy.nextBossSkill
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
    self:applyBossPhase(enemy, false)
    local skillKey = self:chooseEnemySkill(enemy)
    enemy.nextBossSkill = nil
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
    if self.expedition and (self.expedition.latePressure or 0) > 0 then
        damageBonus = damageBonus + math.floor((self.expedition.latePressure or 0) / 2)
        stressBonus = stressBonus + (self.expedition.latePressure or 0)
    end
    if skill.noise then
        self:addNoise(skill.noise)
    end
    if skill.heatFatigue and self.expedition then
        self.expedition.heatFatigue = (self.expedition.heatFatigue or 0) + skill.heatFatigue
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
        if skill.disease and target.alive then
            self:contractDisease(target, skill.disease)
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
    if def.supportHeal then
        for _, ally in ipairs(self.combat.enemies or {}) do
            local allyDef = Defs.enemy(ally.kind)
            if ally ~= enemy and ally.hp > 0 and allyDef and math.abs((ally.rank or 0) - (enemy.rank or 0)) <= 1 then
                ally.hp = math.min(allyDef.maxHp, ally.hp + def.supportHeal)
            end
        end
    end
    self:repairDisabledPart(enemy)
    self:pushLog(def.name .. " used " .. skill.name, { event = def.boss and "boss_skill" or "enemy_skill", actor = def.name, skill = skill.name, skillKey = skillKey, side = "enemy", boss = def.boss == true })
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
    local wardenActive = combatHasWarden(self.combat)
    local outcomeEncounter = self.combat.encounter
    if victory then
        local bossWon = false
        local alphaWon = self.combat.visible and self:isAlphaThreatKey(self.combat.threatKey)
        local victoryResult = "extract"
        for _, trinketKey in ipairs(self.combat.fallenTrinkets or {}) do
            self.estate.trinkets[trinketKey] = ((self.estate.trinkets or {})[trinketKey] or 0) + 1
        end
        if self.expedition then
            local baseEncounter = self.combat.baseEncounter or self.combat.encounter
            local _, bossMission = self:bossMissionForEncounter(baseEncounter)
            local mission = Defs.mission(self.expedition.mission)
            bossWon = bossMission ~= nil or bossActive
            victoryResult = bossWon and "boss" or (self:missionHasTag(mission, "repair") and "repair" or "extract")
            self.expedition.clearedEncounters[self.combat.roomKey or self.combat.encounter] = true
            self:addLoot("coin", bossWon and 120 or 35)
            self:addLoot("heirloom", bossWon and 2 or 1)
            if not bossWon then
                self:grantMerchantCutRoomLoot()
            end
            if alphaWon then
                local reward = Defs.rewardRule("alpha_reward") or {}
                self:addLoot("coin", reward.coin or 45)
                self:addLoot("heirloom", reward.heirloom or 1)
            end
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
            self:dropDocument(wardenActive and "warden" or "room_loot")
            self:clearEncounterSpecial(baseEncounter)
            self:updateObjective()
        end
        self.mode = "expedition"
        self:pushLog("combat won", { event = bossWon and "boss_win" or "combat_win", encounter = outcomeEncounter, boss = bossWon, enemies = combatEnemyNames(self.combat) })
        self:narrate("combat_win", self.combat.encounter)
        self:narrate("victory_result_voice", victoryResult, function(line)
            return line.result == victoryResult
        end)
        if wardenActive then
            self:narrate("warden_voice_v1", outcomeEncounter)
        end
    else
        self.mode = "estate"
        if self.expedition then
            self.expedition.active = false
        end
        if self.estate.campaign and self.estate.campaign.flags and self.estate.campaign.flags.survivorTrinketDebt then
            local rule = Defs.recoveryRule("survivor_trinket_debt") or {}
            local recovered = 0
            for _, trinketKey in ipairs(self.combat.fallenTrinkets or {}) do
                if recovered >= (rule.trinkets or 1) then
                    break
                end
                self.estate.trinkets[trinketKey] = ((self.estate.trinkets or {})[trinketKey] or 0) + 1
                recovered = recovered + 1
            end
            if recovered > 0 then
                self:adjustDread(rule.dread or 1)
                self:pushLog("survivor trinket debt paid")
            end
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
            local enemyDef = Defs.enemy(unit.kind) or {}
            local marked = not target.partKey and self:hasStatus(unit, "marked")
            local damage = self:roll(skill.damage[1], skill.damage[2]) + damageBonus
            if skill.missingHpScale and enemyDef.maxHp then
                damage = damage + math.floor(math.max(0, enemyDef.maxHp - (unit.hp or 0)) / enemyDef.maxHp * skill.missingHpScale)
            end
            if marked then
                damage = damage + (skill.markedDamageBonus or 2)
            else
                damage = damage - (enemyDef.armor or 0)
            end
            damage = math.max(0, damage)
            if target.partKey then
                self:damageEnemyPart(unit, target.partKey, damage)
            else
                unit.hp = math.max(0, unit.hp - damage)
                if marked and damage > 0 then
                    self:clearStatus(unit, "marked")
                end
                self:afterEnemyDamaged(unit)
                local enemyDef = Defs.enemy(unit.kind)
                if enemyDef and enemyDef.reflectDamage and damage > 0 then
                    self:damageHero(hero, enemyDef.reflectDamage)
                end
            end
        end
        if skill.stressDamage and targetSide == "enemy" then
            if target.partKey then
                self:damageEnemyPart(unit, target.partKey, skill.stressDamage)
            else
                unit.hp = math.max(0, unit.hp - skill.stressDamage)
                unit.stress = (unit.stress or 0) + skill.stressDamage
                self:afterEnemyDamaged(unit)
                local enemyDef = Defs.enemy(unit.kind)
                if enemyDef and enemyDef.reflectStressDamage then
                    self:addStress(hero, skill.stressDamage)
                end
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
    if skill.selfStress then
        self:addStress(hero, skill.selfStress)
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
    self:pushLog(hero.name .. " used " .. skill.name, { event = "hero_skill", actor = hero.name, skill = skill.name, skillKey = skillKey, side = "ally" })
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

function Simulation:itemTooltip(itemKey)
    local item = Defs.item(itemKey)
    if not item then
        return nil
    end
    local cure = (Defs.injuryCureTooltip("injury_cure_tooltips") or {})[itemKey]
    return cure and (item.name .. ": " .. cure) or item.name
end

function Simulation:scoutOddsTooltip(roomKey)
    local copy = Defs.scoutTooltip("scout_odds_tooltip") or {}
    if self.expedition and roomKey and self.expedition.scoutedRooms[roomKey] then
        return copy.low
    end
    return copy.high
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
            if threat.rare then
                self.expedition.alphaMarkers[threat.key] = { x = threat.x, y = threat.y, roomKey = threat.roomKey }
            end
            result[#result + 1] = {
                type = threat.rare and "alpha" or "threat",
                x = threat.x,
                y = threat.y,
                z = threat.z or 0,
                encounter = threat.encounter,
                threatKey = threat.key,
                roomKey = threat.roomKey,
                tooltip = self:scoutOddsTooltip(threat.roomKey),
            }
        end
    end
    for _, room in ipairs(self.world:roomCenters()) do
        local encounter = self.world:encounterForRoom(room.key)
        if encounter and not self.expedition.clearedEncounters[room.key]
            and room.x >= minX and room.x <= maxX and room.y >= minY and room.y <= maxY
        then
            result[#result + 1] = { type = "encounter", x = room.x, y = room.y, z = z or 0, encounter = encounter, tooltip = self:scoutOddsTooltip(room.key) }
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
                classId = hero.class,
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
    return (mission.progressLabel or mission.kind) .. " " .. progress .. "/" .. target
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
                { label = mission.objectiveLabel or mission.kind, done = self.expedition.objectiveComplete, next = mission.objectiveNext or mission.name },
                { label = "camp", done = self.expedition.campUsed, next = mission.campHint or "Camp at the cold camp if stress climbs" },
                { label = "regent", done = self.expedition.bossDefeated, next = mission.regentHint or "Defeat the Vault Regent or return after scouting" },
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
            merchantCutPackApplied = self.expedition.merchantCutPackApplied == true,
            merchantCutLootClaimed = self.expedition.merchantCutLootClaimed == true,
            questActivations = self.expedition.questActivations,
            visitedRooms = copyMap(self.expedition.visitedRooms),
            scoutedRooms = copyMap(self.expedition.scoutedRooms),
            clearedEncounters = copyMap(self.expedition.clearedEncounters),
            curiosUsed = copyMap(self.expedition.curiosUsed),
            roomsScouted = self.expedition.roomsScouted,
            stepsSinceMeal = self.expedition.stepsSinceMeal,
            hungerChecks = self.expedition.hungerChecks,
            threatState = copyMap(self.expedition.threatState),
            alphaMarkers = copyNestedMap(self.expedition.alphaMarkers),
            stealthApproach = self.expedition.stealthApproach == true,
            noise = self.expedition.noise or 0,
            ambushRolls = self.expedition.ambushRolls or 0,
            heatFatigue = self.expedition.heatFatigue or 0,
            latePressure = self.expedition.latePressure or 0,
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
            stealthed = self.combat.stealthed == true,
            threatKey = self.combat.threatKey,
            partRepaired = self.combat.partRepaired == true,
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
            documents = copyMap(self.estate.documents),
            documentLog = copyList(self.estate.documentLog),
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
                weekLimit = self.estate.campaign and self.estate.campaign.weekLimit or ((Defs.campaignTimer("twin_timer_v1") or {}).weekCap or 14),
                deathLimit = self.estate.campaign and self.estate.campaign.deathLimit or 8,
                dreadLimit = self.estate.campaign and self.estate.campaign.dreadLimit or 18,
                factions = copyNestedMap(self.estate.campaign and self.estate.campaign.factions),
                flags = copyNestedMap(self.estate.campaign and self.estate.campaign.flags),
                endingRoute = self.estate.campaign and self.estate.campaign.endingRoute or nil,
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
        documentPopup = self.documentPopup and copyMap(self.documentPopup) or nil,
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
        estate = { gold = 0, heirlooms = 0, roster = {}, graveyard = {}, dismissed = {}, trinkets = {}, trinketStock = {}, provisionCart = Inventory.new(), upgrades = {}, campaign = newCampaign(), missionBoard = {}, recruits = {}, documents = {}, documentLog = {}, nextHeroId = 1, recruitSerial = 1 },
        party = copyList(snapshot.party or {}),
        expedition = nil,
        combat = nil,
        commandQueue = {},
        status = snapshot.status or "loaded",
        narration = snapshot.narration or "",
        documentPopup = snapshot.documentPopup and copyMap(snapshot.documentPopup) or nil,
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
    self.estate.documents = copyMap((snapshot.estate and snapshot.estate.documents) or {})
    self.estate.documentLog = copyList((snapshot.estate and snapshot.estate.documentLog) or {})
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
        weekLimit = campaign.weekLimit or ((Defs.campaignTimer("twin_timer_v1") or {}).weekCap or 14),
        deathLimit = campaign.deathLimit or 8,
        dreadLimit = campaign.dreadLimit or 18,
        factions = copyNestedMap(campaign.factions),
        flags = copyNestedMap(campaign.flags),
        endingRoute = campaign.endingRoute,
    }
    self:ensureCampaignState()
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
            merchantCutPackApplied = exp.merchantCutPackApplied == true,
            merchantCutLootClaimed = exp.merchantCutLootClaimed == true,
            questActivations = exp.questActivations or 0,
            visitedRooms = copyMap(exp.visitedRooms),
            scoutedRooms = copyMap(exp.scoutedRooms),
            clearedEncounters = copyMap(exp.clearedEncounters),
            curiosUsed = copyMap(exp.curiosUsed),
            roomsScouted = exp.roomsScouted or 0,
            stepsSinceMeal = exp.stepsSinceMeal or 0,
            hungerChecks = exp.hungerChecks or 0,
            threatState = copyMap(exp.threatState),
            alphaMarkers = copyNestedMap(exp.alphaMarkers),
            stealthApproach = exp.stealthApproach == true,
            noise = exp.noise or 0,
            ambushRolls = exp.ambushRolls or 0,
            heatFatigue = exp.heatFatigue or 0,
            latePressure = exp.latePressure or 0,
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
            stealthed = combat.stealthed == true,
            threatKey = combat.threatKey,
            partRepaired = combat.partRepaired == true,
            log = copyList(combat.log or {}),
        }
        for _, enemy in ipairs(combat.enemies or {}) do
            self.combat.enemies[#self.combat.enemies + 1] = cloneEnemy(enemy)
        end
    end
    return self
end

return Simulation
