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
}

local objectCells = {
    { type = "exit", x = -2, y = 2, z = 0, tile = "exit_gate" },
    { type = "curio", x = 4, y = 0, z = 0, tile = "wire_snare", curio = "wire_snare" },
    { type = "curio", x = 8, y = 6, z = 0, tile = "camp_marker", curio = "cold_camp" },
    { type = "curio", x = 16, y = 0, z = 0, tile = "relic_cache", curio = "relic_cache" },
    { type = "curio", x = 16, y = 6, z = 0, tile = "whispering_idol", curio = "whispering_idol" },
    { type = "boss", x = 24, y = 0, z = 0, tile = "boss_sigil", encounter = "regent" },
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

local function newHero(id, classKey)
    local class = Defs.heroClass(classKey)
    return {
        id = id,
        name = heroNames[classKey] or class.name,
        class = classKey,
        level = 1,
        xp = 0,
        hp = class.maxHp,
        stress = 0,
        affliction = nil,
        virtue = nil,
        alive = true,
        recovering = 0,
        guard = 0,
        skills = copyList(class.skills),
    }
end

local function newEnemy(id, kind, rank)
    local def = Defs.enemy(kind)
    return { id = id, kind = kind, rank = rank, hp = def.maxHp, stress = 0, statuses = {}, guard = 0 }
end

local function cloneEnemy(enemy)
    local statuses = {}
    for _, status in ipairs(enemy.statuses or {}) do
        statuses[#statuses + 1] = { kind = status.kind, amount = status.amount or 0, turns = status.turns or 0 }
    end
    return {
        id = enemy.id,
        kind = enemy.kind,
        rank = enemy.rank,
        hp = enemy.hp,
        stress = enemy.stress or 0,
        statuses = statuses,
        guard = enemy.guard or 0,
    }
end

local function inventoryFromStacks(stacks)
    return Inventory.new(stacks or {})
end

function Simulation.new(seed)
    local roster = {}
    for index, classKey in ipairs(Defs.heroClassOrder) do
        roster[#roster + 1] = newHero(index, classKey)
    end
    local self = setmetatable({
        seed = seed or 1,
        tick = 0,
        rollIndex = 0,
        mode = "estate",
        world = World.new(seed or 1),
        player = { x = 0, y = 0, z = 0, facing = "east", selectedHero = 1 },
        estate = { gold = 150, heirlooms = 0, roster = roster, graveyard = {} },
        party = { 1, 2, 3, 4 },
        expedition = nil,
        combat = nil,
        commandQueue = {},
        status = "ready",
        log = {},
    }, Simulation)
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

function Simulation.commands.useItem(item, heroRank)
    return { type = "useItem", item = item, heroRank = heroRank }
end

function Simulation.commands.combatSkill(skillKey, targetRank, targetSide)
    return { type = "combatSkill", skillKey = skillKey, targetRank = targetRank, targetSide = targetSide }
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

function Simulation.commands.recoverHero(heroId)
    return { type = "recoverHero", heroId = heroId }
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
    if command.type == "useItem" then
        return self:useItem(command.item, command.heroRank)
    end
    if command.type == "combatSkill" then
        return self:combatSkill(command.skillKey, command.targetRank, command.targetSide)
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
        return self:recoverHero(command.heroId)
    end
    return false
end

function Simulation:pushLog(message)
    self.status = message
    self.log[#self.log + 1] = message
    if self.expedition then
        self.expedition.log[#self.expedition.log + 1] = message
    end
    while #self.log > 12 do
        table.remove(self.log, 1)
    end
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
    return self:classDef(hero).maxHp
end

function Simulation:healHero(hero, amount)
    if not hero or not hero.alive then
        return false
    end
    local penalty = hero.affliction and ((Defs.affliction(hero.affliction) or {}).healPenalty or 0) or 0
    hero.hp = math.min(self:maxHp(hero), hero.hp + math.max(0, amount - penalty))
    return true
end

function Simulation:damageHero(hero, amount)
    if not hero or not hero.alive then
        return false
    end
    local extra = hero.affliction and ((Defs.affliction(hero.affliction) or {}).damageTaken or 0) or 0
    hero.hp = math.max(0, hero.hp - math.max(0, amount + extra))
    if hero.hp <= 0 then
        hero.alive = false
        self.estate.graveyard[#self.estate.graveyard + 1] = {
            id = hero.id,
            name = hero.name,
            class = hero.class,
            tick = self.tick,
        }
        self:compactParty()
        self:pushLog(hero.name .. " fell")
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
    hero.stress = clamp(hero.stress + amount + modifier, 0, 200)
    if hero.stress >= 100 and not hero.affliction and not hero.virtue then
        self:resolveCheck(hero)
    end
    if hero.stress >= 160 then
        hero.stress = 120
        self:damageHero(hero, math.max(1, math.floor(self:maxHp(hero) / 3)))
        self:pushLog(hero.name .. " breaks under the dark")
    end
    return true
end

function Simulation:healStress(hero, amount)
    if not hero or not hero.alive then
        return false
    end
    hero.stress = math.max(0, hero.stress - math.max(0, amount))
    return true
end

function Simulation:resolveCheck(hero)
    local class = self:classDef(hero)
    local roll = self:roll(1, 100)
    if roll <= class.resolve then
        hero.virtue = "focused"
        self:pushLog(hero.name .. " steadied")
    else
        hero.affliction = Defs.afflictionOrder[((roll - 1) % #Defs.afflictionOrder) + 1]
        self:pushLog(hero.name .. " is " .. Defs.affliction(hero.affliction).name)
    end
end

function Simulation:selectHero(heroRank)
    local rank = clamp(tonumber(heroRank) or 1, 1, 4)
    if self:heroAtRank(rank) then
        self.player.selectedHero = rank
        return true
    end
    return false
end

function Simulation:startExpedition(locationKey)
    if self.expedition and self.expedition.active then
        return false
    end
    local location = Defs.location(locationKey or "buried_archive")
    if not location then
        return false
    end
    self.world = World.new(self.seed)
    self.player.x = location.start.x
    self.player.y = location.start.y
    self.player.z = location.start.z or 0
    self.player.facing = "east"
    self.player.selectedHero = 1
    self.mode = "expedition"
    self.combat = nil
    self.expedition = {
        active = true,
        location = locationKey or "buried_archive",
        torch = 75,
        supplies = Inventory.new({
            { item = "torch", count = 4 },
            { item = "ration", count = 8 },
            { item = "bandage", count = 2 },
            { item = "laudanum", count = 2 },
            { item = "skeleton_key", count = 1 },
            { item = "salve", count = 1 },
        }),
        loot = Inventory.new(),
        visitedRooms = {},
        clearedEncounters = {},
        curiosUsed = {},
        roomsScouted = 0,
        campUsed = false,
        objectiveComplete = false,
        bossDefeated = false,
        log = {},
    }
    self:discoverCurrentRoom()
    self:pushLog("entered " .. location.name)
    return true
end

function Simulation:endExpedition(retreat)
    if not self.expedition or not self.expedition.active then
        return false
    end
    local success = self.expedition.objectiveComplete and not retreat
    local coin = self.expedition.loot:count("coin")
    local heirloom = self.expedition.loot:count("heirloom")
    if success then
        self.estate.gold = self.estate.gold + coin
        self.estate.heirlooms = self.estate.heirlooms + heirloom + self.expedition.loot:count("relic")
        for rank = 1, 4 do
            local hero = self:heroAtRank(rank)
            if hero and hero.alive then
                hero.xp = hero.xp + 1
                self:healStress(hero, 8)
            end
        end
        self:pushLog("mission complete")
    else
        self.estate.gold = self.estate.gold + math.floor(coin / 2)
        for rank = 1, 4 do
            local hero = self:heroAtRank(rank)
            if hero and hero.alive then
                self:addStress(hero, 8)
            end
        end
        self:pushLog("expedition abandoned")
    end
    self.mode = "estate"
    self.combat = nil
    self.expedition.active = false
    return true
end

function Simulation:recoverHero(heroId)
    if self.mode ~= "estate" then
        return false
    end
    local hero = self:heroById(heroId)
    if not hero or not hero.alive or self.estate.gold < 25 then
        return false
    end
    self.estate.gold = self.estate.gold - 25
    self:healStress(hero, 30)
    hero.recovering = math.max(0, (hero.recovering or 0) - 1)
    self:pushLog(hero.name .. " recovered")
    return true
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
    if roomKey and not self.expedition.visitedRooms[roomKey] then
        self.expedition.visitedRooms[roomKey] = true
        self.expedition.roomsScouted = self.expedition.roomsScouted + 1
        local location = Defs.location(self.expedition.location)
        if self.expedition.roomsScouted >= location.objectiveRooms then
            self.expedition.objectiveComplete = true
        end
    end
    return roomKey
end

function Simulation:decayTorch(amount)
    if self.expedition then
        self.expedition.torch = clamp(self.expedition.torch - (amount or 1), 0, 100)
    end
end

function Simulation:isWalkable(x, y, z)
    return self.world:isWalkable(x, y, z or 0)
end

function Simulation:move(direction)
    if self.mode ~= "expedition" then
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
    local roomKey = self:discoverCurrentRoom()
    self:pushLog("moved " .. direction)
    self:tryStartRoomEncounter(roomKey)
    return true
end

function Simulation:tryStartRoomEncounter(roomKey)
    if not self.expedition or not roomKey then
        return false
    end
    local location = Defs.location(self.expedition.location)
    local encounterKey = location.encounters[roomKey]
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
    if tileDef.encounter then
        return self:startCombat(tileDef.encounter, self:currentRoomKey() or (x .. ":" .. y))
    end
    self:pushLog("nothing useful")
    return false
end

function Simulation:resolveCurio(x, y, z, curioKey)
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
    local usedItem = false
    if curio.item and self.expedition.supplies:consume(curio.item, 1) then
        usedItem = true
    end
    for item, count in pairs(curio.loot or {}) do
        self.expedition.loot:add(item, usedItem and count or math.max(1, math.floor(count / 2)))
    end
    local hero = self:heroAtRank(self.player.selectedHero) or self:heroAtRank(1)
    if curio.damage and not usedItem then
        self:damageHero(hero, curio.damage)
    end
    if curio.stress then
        if curio.stress < 0 then
            self:healStress(hero, -curio.stress)
        else
            self:addStress(hero, usedItem and math.floor(curio.stress / 2) or curio.stress)
        end
    end
    self.expedition.curiosUsed[key] = true
    self.world:setTile(x, y, z, { id = "archive_floor", data = 0 })
    self:pushLog(curio.name .. " resolved")
    return true
end

function Simulation:camp()
    if self.mode ~= "expedition" or not self.expedition or self.expedition.campUsed then
        return false
    end
    self.expedition.campUsed = true
    self.expedition.supplies:consume("ration", math.min(2, self.expedition.supplies:count("ration")))
    self.expedition.torch = clamp(self.expedition.torch + 20, 0, 100)
    for rank = 1, 4 do
        local hero = self:heroAtRank(rank)
        if hero and hero.alive then
            self:healHero(hero, 4)
            self:healStress(hero, 8)
        end
    end
    self:pushLog("camped")
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
    elseif item == "laudanum" then
        self:healStress(hero, 12)
    elseif item == "salve" then
        self:healHero(hero, 5)
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

function Simulation:startCombat(encounterKey, roomKey)
    local encounter = Defs.encounter(encounterKey)
    if not encounter then
        return false
    end
    local enemies = {}
    for index, kind in ipairs(encounter) do
        enemies[#enemies + 1] = newEnemy(index, kind, index)
    end
    self.mode = "combat"
    self.combat = {
        encounter = encounterKey,
        roomKey = roomKey,
        enemies = enemies,
        round = 0,
        turnQueue = {},
        turnIndex = 1,
        active = nil,
        log = {},
    }
    self:pushLog("combat: " .. encounterKey)
    self:advanceCombat()
    return true
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
        return hero and self:classDef(hero).speed or 0
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

function Simulation:applyStatuses(unit)
    local skip = false
    local kept = {}
    for _, status in ipairs(unit.statuses or {}) do
        if status.kind == "bleed" then
            unit.hp = math.max(0, unit.hp - (status.amount or 1))
        elseif status.kind == "daze" then
            skip = true
        end
        status.turns = (status.turns or 0) - 1
        if status.turns > 0 then
            kept[#kept + 1] = status
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
            local skip = self:applyStatuses(enemy)
            if enemy.hp <= 0 then
                self.combat.turnIndex = self.combat.turnIndex + 1
            elseif skip then
                self:pushLog(Defs.enemy(enemy.kind).name .. " faltered")
                self.combat.turnIndex = self.combat.turnIndex + 1
            else
                self:enemyTurn(enemy)
                self.combat.turnIndex = self.combat.turnIndex + 1
            end
        else
            self.combat.active = actor
            self.player.selectedHero = self:heroRank(actor.id) or self.player.selectedHero
            return true
        end
    end
    return false
end

function Simulation:enemyTurn(enemy)
    local target = nil
    for rank = 1, 4 do
        local hero = self:heroAtRank(rank)
        if hero and hero.alive and (hero.guard or 0) > 0 then
            target = hero
            hero.guard = hero.guard - 1
            break
        end
    end
    if not target then
        for rank = 1, 4 do
            local hero = self:heroAtRank(rank)
            if hero and hero.alive then
                target = hero
                break
            end
        end
    end
    if not target then
        return false
    end
    local def = Defs.enemy(enemy.kind)
    local damage = self:roll(def.damage[1], def.damage[2])
    local stress = def.stress or 0
    if self.expedition and self.expedition.torch < 30 then
        damage = damage + 1
        stress = stress + 2
    end
    self:damageHero(target, damage)
    self:addStress(target, stress)
    self:pushLog(def.name .. " hit " .. target.name)
    return true
end

function Simulation:finishCombat(victory)
    if not self.combat then
        return false
    end
    if victory then
        if self.expedition then
            self.expedition.clearedEncounters[self.combat.roomKey or self.combat.encounter] = true
            self.expedition.loot:add("coin", self.combat.encounter == "regent" and 120 or 35)
            self.expedition.loot:add("heirloom", self.combat.encounter == "regent" and 2 or 1)
            if self.combat.encounter == "regent" then
                self.expedition.bossDefeated = true
                self.expedition.objectiveComplete = true
                self.world:setTile(24, 0, 0, { id = "archive_floor", data = 0 })
            end
        end
        self.mode = "expedition"
        self:pushLog("combat won")
    else
        self.mode = "estate"
        if self.expedition then
            self.expedition.active = false
        end
        self:pushLog("party lost")
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

function Simulation:combatSkill(skillKey, targetRank, targetSide)
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
        targets[#targets + 1] = enemy
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
    local damageBonus = 0
    if hero.affliction == "reckless" then
        damageBonus = damageBonus + 1
    end
    if hero.virtue then
        damageBonus = damageBonus + ((Defs.virtue(hero.virtue) or {}).damageBonus or 0)
    end
    for _, target in ipairs(targets) do
        if skill.damage and targetSide == "enemy" then
            target.hp = math.max(0, target.hp - self:roll(skill.damage[1], skill.damage[2]) - damageBonus)
        end
        if skill.stressDamage and targetSide == "enemy" then
            target.hp = math.max(0, target.hp - skill.stressDamage)
            target.stress = (target.stress or 0) + skill.stressDamage
        end
        if skill.heal then
            self:healHero(target, self:roll(skill.heal[1], skill.heal[2]))
        end
        if skill.stressHeal then
            self:healStress(target, skill.stressHeal)
        end
        if skill.status and targetSide == "enemy" and target.hp > 0 then
            target.statuses[#target.statuses + 1] = copyMap(skill.status)
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
    self:pushLog(hero.name .. " used " .. skill.name)
    return true
end

function Simulation:passTurn()
    local hero = self:activeHero()
    if not hero then
        return false
    end
    self:addStress(hero, 2)
    self:pushLog(hero.name .. " held")
    self.combat.turnIndex = self.combat.turnIndex + 1
    return self:advanceCombat()
end

function Simulation:retreat()
    if self.mode == "combat" then
        for rank = 1, 4 do
            local hero = self:heroAtRank(rank)
            if hero and hero.alive then
                self:addStress(hero, 6)
            end
        end
        self.mode = "expedition"
        self.combat = nil
        self:decayTorch(10)
        self:pushLog("retreated")
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
    for _, object in ipairs(objectCells) do
        if object.x >= minX and object.x <= maxX and object.y >= minY and object.y <= maxY and (object.z or 0) == (z or 0) then
            local used = self.expedition.curiosUsed[Grid.key(object.x, object.y, object.z or 0)]
            if not used then
                result[#result + 1] = object
            end
        end
    end
    local location = Defs.location(self.expedition.location)
    for _, room in ipairs(self.world:roomCenters()) do
        local encounter = location.encounters[room.key]
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
                hp = hero.hp,
                maxHp = class.maxHp,
                stress = hero.stress,
                affliction = hero.affliction,
                virtue = hero.virtue,
                alive = hero.alive,
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
            usable = self.mode ~= "combat" or contains(skill.userRanks, rank),
        }
    end
    return result
end

function Simulation:missionProgressText()
    if not self.expedition then
        return "estate"
    end
    local location = Defs.location(self.expedition.location)
    return "rooms " .. self.expedition.roomsScouted .. "/" .. location.objectiveRooms
        .. "  light " .. self.expedition.torch
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
    return {
        {
            title = "Expedition",
            items = {
                { label = "scout", done = self.expedition.roomsScouted >= 3, next = "Scout three archive rooms" },
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
            recovering = hero.recovering,
            guard = hero.guard,
            skills = copyList(hero.skills),
            statuses = copyList(hero.statuses),
        }
    end
    local expedition = nil
    if self.expedition then
        expedition = {
            active = self.expedition.active,
            location = self.expedition.location,
            torch = self.expedition.torch,
            supplies = self.expedition.supplies:stacks(),
            loot = self.expedition.loot:stacks(),
            visitedRooms = copyMap(self.expedition.visitedRooms),
            clearedEncounters = copyMap(self.expedition.clearedEncounters),
            curiosUsed = copyMap(self.expedition.curiosUsed),
            roomsScouted = self.expedition.roomsScouted,
            campUsed = self.expedition.campUsed,
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
            roomKey = self.combat.roomKey,
            enemies = enemies,
            round = self.combat.round,
            turnQueue = copyList(self.combat.turnQueue),
            turnIndex = self.combat.turnIndex,
            active = self.combat.active and copyMap(self.combat.active) or nil,
            log = copyList(self.combat.log),
        }
    end
    return {
        version = 2,
        seed = self.seed,
        tick = self.tick,
        rollIndex = self.rollIndex,
        mode = self.mode,
        world = self.world:snapshot(),
        player = copyMap(self.player),
        estate = {
            gold = self.estate.gold,
            heirlooms = self.estate.heirlooms,
            roster = roster,
            graveyard = copyList(self.estate.graveyard),
        },
        party = copyList(self.party),
        expedition = expedition,
        combat = combat,
        status = self.status,
        log = copyList(self.log),
    }
end

function Simulation.fromSnapshot(snapshot)
    if snapshot.version and snapshot.version ~= 2 then
        return nil, "unsupported simulation snapshot version"
    end
    local self = setmetatable({
        seed = snapshot.seed or 1,
        tick = snapshot.tick or 0,
        rollIndex = snapshot.rollIndex or 0,
        mode = snapshot.mode or "estate",
        world = World.fromSnapshot(snapshot.world or { seed = snapshot.seed or 1, tiles = {} }),
        player = copyMap(snapshot.player or { x = 0, y = 0, z = 0, facing = "east", selectedHero = 1 }),
        estate = { gold = 0, heirlooms = 0, roster = {}, graveyard = {} },
        party = copyList(snapshot.party or {}),
        expedition = nil,
        combat = nil,
        commandQueue = {},
        status = snapshot.status or "loaded",
        log = copyList(snapshot.log or {}),
    }, Simulation)
    self.estate.gold = (snapshot.estate and snapshot.estate.gold) or 0
    self.estate.heirlooms = (snapshot.estate and snapshot.estate.heirlooms) or 0
    self.estate.graveyard = copyList((snapshot.estate and snapshot.estate.graveyard) or {})
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
        hero.recovering = value.recovering or 0
        hero.guard = value.guard or 0
        hero.skills = copyList(value.skills or hero.skills)
        hero.statuses = copyList(value.statuses or {})
        self.estate.roster[#self.estate.roster + 1] = hero
    end
    local exp = snapshot.expedition
    if exp then
        self.expedition = {
            active = exp.active == true,
            location = exp.location or "buried_archive",
            torch = exp.torch or 0,
            supplies = inventoryFromStacks(exp.supplies),
            loot = inventoryFromStacks(exp.loot),
            visitedRooms = copyMap(exp.visitedRooms),
            clearedEncounters = copyMap(exp.clearedEncounters),
            curiosUsed = copyMap(exp.curiosUsed),
            roomsScouted = exp.roomsScouted or 0,
            campUsed = exp.campUsed == true,
            objectiveComplete = exp.objectiveComplete == true,
            bossDefeated = exp.bossDefeated == true,
            log = copyList(exp.log or {}),
        }
    end
    local combat = snapshot.combat
    if combat then
        self.combat = {
            encounter = combat.encounter,
            roomKey = combat.roomKey,
            enemies = {},
            round = combat.round or 0,
            turnQueue = copyList(combat.turnQueue),
            turnIndex = combat.turnIndex or 1,
            active = combat.active and copyMap(combat.active) or nil,
            log = copyList(combat.log or {}),
        }
        for _, enemy in ipairs(combat.enemies or {}) do
            self.combat.enemies[#self.combat.enemies + 1] = cloneEnemy(enemy)
        end
    end
    return self
end

return Simulation
