local CONFIG = require("config")
local EntitySystem = require("modules/entity_system")
local Items = require("modules/items")
local Survival = require("modules/survival")
local TileRegistry = require("modules/tile_registry")
local Utils = require("modules/utils")
local World = require("modules/world")
local WorldObjects = require("modules/world_objects")

local Wildlife = {}

local LIST_BY_KIND = {
    wolf = "wolves",
    raider = "raiders",
    rabbit = "rabbits",
    deer = "deer",
}

local KIND_BY_LIST = {
    wolves = "wolf",
    raiders = "raider",
    rabbits = "rabbit",
    deer = "deer",
}

local function listNameFor(kindOrList)
    return LIST_BY_KIND[kindOrList] or (KIND_BY_LIST[kindOrList] and kindOrList) or kindOrList
end

local function kindFor(kindOrList)
    return KIND_BY_LIST[kindOrList] or kindOrList
end

local function zoneBounds(zone)
    if not zone then
        return nil
    end
    local width = math.max(1, zone.width or zone.w or 1)
    local height = math.max(1, zone.height or zone.h or 1)
    return zone.x or 1, zone.y or 1, width, height
end

local function coordForTile(x, y)
    return {(x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE}
end

local function patrolPointsForZone(zone)
    local x, y, width, height = zoneBounds(zone)
    if not x then
        return nil
    end
    local maxX = x + width - 1
    local maxY = y + height - 1
    return {
        coordForTile(x, y),
        coordForTile(maxX, y),
        coordForTile(maxX, maxY),
        coordForTile(x, maxY),
    }
end

local function setTargetInZone(entity, zone)
    local x, y, width, height = zoneBounds(zone)
    if not x then
        return
    end
    entity.target = {
        math.random(x, x + width - 1) * CONFIG.TILE_SIZE,
        math.random(y, y + height - 1) * CONFIG.TILE_SIZE,
    }
end

local function syncActorState(actor)
    actor.state = actor.state or actor.aiState or "roam"
    actor.aiState = actor.state
    actor.facingX = actor.facingX or 1
    actor.facingY = actor.facingY or 0
    actor.moving = actor.moving == true
    actor.homeZone = actor.homeZone or actor.territory or actor.zone
    actor.awareness = actor.awareness or {}
    actor.awareness.seesPlayer = actor.awareness.seesPlayer == true
end

local function noteMovementIntent(entity, dx, dy)
    if math.abs(dx) >= 0.01 or math.abs(dy) >= 0.01 then
        local length = math.max(1, math.sqrt((dx * dx) + (dy * dy)))
        entity.facingX = dx / length
        entity.facingY = dy / length
    end
end

local function moveEntity(entity, speed, hours, level)
    entity.moving = false
    if not entity.target then
        return
    end

    local distance = Utils.distance(entity.coord[1], entity.coord[2], entity.target[1], entity.target[2])
    if distance < 2 then
        entity.target = nil
        entity.moving = false
        return
    end

    local dx = (entity.target[1] - entity.coord[1]) / distance
    local dy = (entity.target[2] - entity.coord[2]) / distance
    noteMovementIntent(entity, dx, dy)
    local step = speed * hours * (CONFIG.DAY_DURATION_SECONDS / 24)
    local nextCoord = {
        entity.coord[1] + (dx * step),
        entity.coord[2] + (dy * step),
    }

    if entity._wildlifeEntity and level then
        local moved = EntitySystem.moveEntity(level, entity, nextCoord[1] - entity.coord[1], nextCoord[2] - entity.coord[2])
        entity.moving = moved == true
        if not moved then
            entity.target = nil
        end
        return
    end

    local gx, gy = Utils.pixelToGrid(nextCoord[1], nextCoord[2])
    local tile = level and level.grid[gy + 1] and level.grid[gy + 1][gx + 1]
    if tile and TileRegistry.isWalkable(tile, level, gx + 1, gy + 1, entity) then
        entity.coord[1] = nextCoord[1]
        entity.coord[2] = nextCoord[2]
        entity.moving = true
    else
        entity.target = nil
        entity.moving = false
    end
end

local function playerDeterrenceRadius(player)
    if player.equippedLight == "flare" then
        return CONFIG.WOLF_LIGHT_DETERRENCE_TILES * CONFIG.TILE_SIZE
    elseif player.equippedLight == "torch" then
        return (CONFIG.WOLF_LIGHT_DETERRENCE_TILES - 1) * CONFIG.TILE_SIZE
    end
    return 0
end

local function fireDetersWolf(run, wolf)
    local fires = World.readActiveCollection(run, "fires")
    for _, fire in ipairs(fires) do
        if fire.remainingBurnHours > 0 then
            local distance = Utils.distance(wolf.coord[1], wolf.coord[2], fire.coord[1], fire.coord[2])
            if distance <= CONFIG.WOLF_FIRE_DETERRENCE_TILES * CONFIG.TILE_SIZE then
                return true
            end
        end
    end
    return false
end

local function carcassDrops(kind)
    if kind == "deer" then
        return {
            raw_meat = 3,
            deer_hide = 1,
            gut = 2,
            feather = 2,
        }
    elseif kind == "rabbit" then
        return {
            raw_meat = 1,
            rabbit_pelt = 1,
            gut = 1,
        }
    elseif kind == "fish" then
        return {
            raw_fish = 1,
        }
    end
    return {}
end

local function hostileDropLoot(kind)
    if kind == "raider" then
        return {
            Items.create("arrow", math.random(1, 2)),
            Items.create("bandage", 1),
        }
    end
    if kind == "wolf" then
        return {
            Items.create("raw_meat", 1),
        }
    end
    return {}
end

local function ensureHostile(hostile)
    hostile.kind = hostile.kind or "wolf"
    if hostile.kind == "wolf" then
        hostile.health = hostile.health or CONFIG.WOLF_MAX_HEALTH
        hostile.contactDamage = hostile.contactDamage or CONFIG.WOLF_ATTACK_DAMAGE
        hostile.weaponRange = hostile.weaponRange or CONFIG.WOLF_WEAPON_RANGE_TILES
        hostile.aggroRadius = hostile.aggroRadius or CONFIG.WOLF_DETECTION_RADIUS_TILES
        hostile.attackWindup = hostile.attackWindup or CONFIG.WOLF_ATTACK_WINDUP
        hostile.attackRecovery = hostile.attackRecovery or CONFIG.WOLF_ATTACK_RECOVERY
        hostile.speed = hostile.speed or CONFIG.WOLF_ROAM_SPEED
    elseif hostile.kind == "raider" then
        hostile.health = hostile.health or CONFIG.RAIDER_MAX_HEALTH
        hostile.contactDamage = hostile.contactDamage or CONFIG.RAIDER_ATTACK_DAMAGE
        hostile.weaponRange = hostile.weaponRange or CONFIG.RAIDER_WEAPON_RANGE_TILES
        hostile.aggroRadius = hostile.aggroRadius or CONFIG.RAIDER_AGGRO_RADIUS_TILES
        hostile.attackWindup = hostile.attackWindup or CONFIG.RAIDER_ATTACK_WINDUP
        hostile.attackRecovery = hostile.attackRecovery or CONFIG.RAIDER_ATTACK_RECOVERY
        hostile.speed = hostile.speed or CONFIG.RAIDER_WALK_SPEED
    end
    hostile.attackTimer = hostile.attackTimer or 0
    hostile.staggerTimer = hostile.staggerTimer or 0
end

local function ensurePassive(passive)
    passive.kind = passive.kind or "rabbit"
    if passive.kind == "rabbit" then
        passive.speed = passive.speed or 20
    elseif passive.kind == "deer" then
        passive.speed = passive.speed or 24
    end
end

local function actorKey(kind, coord)
    local gx, gy = Utils.pixelToGrid(coord[1], coord[2])
    return string.format("%s:%d:%d", kind or "wildlife", gx + 1, gy + 1)
end

local function zoneCenter(zone)
    local x, y, width, height = zoneBounds(zone)
    if not x then
        return nil
    end
    return {
        (x + math.floor(width / 2)) * CONFIG.TILE_SIZE,
        (y + math.floor(height / 2)) * CONFIG.TILE_SIZE,
    }
end

local function depthAwarenessBonus(depth)
    if depth == -2 then
        return 2
    elseif depth == -1 then
        return 1
    elseif depth == 1 then
        return 1
    end
    return 0
end

local function defaultAwarenessTiles(kind, depth)
    local bonus = depthAwarenessBonus(depth)
    if kind == "raider" then
        return (CONFIG.RAIDER_AGGRO_RADIUS_TILES or 6) + 2 + bonus
    elseif kind == "wolf" then
        return (CONFIG.WOLF_DETECTION_RADIUS_TILES or 6) + 1 + bonus
    elseif kind == "deer" then
        return (CONFIG.PASSIVE_FLEE_RADIUS_TILES or 4) + 2
    end
    return (CONFIG.PASSIVE_FLEE_RADIUS_TILES or 4) + 1
end

local function applyActorEcology(actor, options)
    actor.homeZone = actor.homeZone or options.homeZone or options.territory or options.zone or actor.territory or actor.zone
    actor.territory = actor.territory or actor.homeZone
    actor.zone = actor.zone or actor.homeZone
    actor.territoryCenter = actor.territoryCenter or options.territoryCenter or zoneCenter(actor.homeZone) or {actor.coord[1], actor.coord[2]}
    actor.awarenessRadiusTiles = actor.awarenessRadiusTiles or options.awarenessRadiusTiles or defaultAwarenessTiles(actor.kind, actor.depth)
    actor.awareness = actor.awareness or {}
    actor.aiState = actor.aiState or options.aiState or actor.state or "roam"
    actor.state = actor.state or actor.aiState
    actor.patrolPoints = actor.patrolPoints or options.patrolPoints or patrolPointsForZone(actor.homeZone)
    actor.patrolIndex = actor.patrolIndex or 1
    actor.spawnRuleId = actor.spawnRuleId or options.spawnRuleId or options.ruleId
end

local function listContains(list, actor)
    for _, entry in ipairs(list or {}) do
        if entry == actor then
            return true
        end
    end
    return false
end

local function renderWildlife(entity, context)
    if context and context.drawWildlife then
        context.drawWildlife(entity)
    end
end

local function entityContains(level, actor)
    for _, entity in ipairs(level.entities or {}) do
        if entity == actor then
            return true
        end
    end
    return false
end

function Wildlife.spawn(level, kind, coord, options)
    options = options or {}
    level.wildlife = level.wildlife or {wolves = {}, rabbits = {}, deer = {}, raiders = {}}
    local listName = listNameFor(kind)
    level.wildlife[listName] = level.wildlife[listName] or {}

    local actor = options.actor or {
        kind = kindFor(kind),
        coord = {coord[1], coord[2]},
        state = options.state or "roam",
    }
    actor.kind = actor.kind or kindFor(kind)
    actor.coord = actor.coord or {coord[1], coord[2]}
    actor.depth = level.depth or options.depth or 0
    actor.solid = false
    actor.width = actor.width or CONFIG.TILE_SIZE - 4
    actor.height = actor.height or CONFIG.TILE_SIZE - 4
    actor._wildlifeEntity = true
    actor._wildlifeKey = actor._wildlifeKey or options.key or actorKey(actor.kind, actor.coord)
    actor.render = actor.render or renderWildlife
    actor.spawnRuleId = actor.spawnRuleId or options.spawnRuleId or options.ruleId
    actor.homeZone = actor.homeZone or options.homeZone or options.territory or options.zone
    actor.facingX = actor.facingX or options.facingX or 1
    actor.facingY = actor.facingY or options.facingY or 0
    actor.moving = actor.moving == true
    actor.aiState = actor.aiState or options.aiState or actor.state or "roam"

    for key, value in pairs(options) do
        if key ~= "actor" and key ~= "addToList" and key ~= "key" then
            actor[key] = value
        end
    end

    if actor.kind == "wolf" or actor.kind == "raider" then
        ensureHostile(actor)
    else
        ensurePassive(actor)
    end
    applyActorEcology(actor, options)
    syncActorState(actor)

    if options.addToList ~= false and not listContains(level.wildlife[listName], actor) then
        table.insert(level.wildlife[listName], actor)
    end
    if not entityContains(level, actor) then
        EntitySystem.add(level, actor)
    else
        EntitySystem.updateTileIndex(level, actor)
    end
    return actor
end

function Wildlife.mirrorLevel(level)
    if not level then
        return level
    end
    level.wildlife = level.wildlife or {wolves = {}, rabbits = {}, deer = {}, raiders = {}}
    for listName, kind in pairs(KIND_BY_LIST) do
        for _, actor in ipairs(level.wildlife[listName] or {}) do
            Wildlife.spawn(level, actor.kind or kind, actor.coord, {
                actor = actor,
                addToList = false,
            })
        end
    end
    EntitySystem.rebuildTileIndex(level)
    return level
end

function Wildlife.getActors(run, kindOrListName)
    World.attachRun(run)
    local level = World.currentLevel(run)
    Wildlife.mirrorLevel(level)
    local listName = listNameFor(kindOrListName)
    return (level.wildlife and level.wildlife[listName]) or {}
end

local function ruleId(rule, index)
    return rule.id or rule.spawnRuleId or string.format("%s:%s:%d", rule.listName or listNameFor(rule.kind), rule.kind or "wildlife", index)
end

local function applySpawnRules(run, level, hours)
    level.spawnState = level.spawnState or {}
    for index, rule in ipairs(level.spawnRules or {}) do
        local id = ruleId(rule, index)
        local state = level.spawnState[id] or {cooldownHours = 0, spawned = 0}
        level.spawnState[id] = state
        state.cooldownHours = math.max(0, (state.cooldownHours or 0) - hours)

        local chance = (rule.chancePerHour or 0) * hours
        if state.cooldownHours <= 0 and chance > 0 and math.random() <= math.min(1, chance) then
            rule.id = rule.id or id
            rule.depth = rule.depth or level.depth or run.world.currentDepth or 0
            local actor = World.spawnOffscreen(run, rule.kind, rule)
            if actor then
                local center = zoneCenter(rule.zone)
                Wildlife.spawn(level, rule.kind, actor.coord, {
                    actor = actor,
                    zone = rule.zone,
                    homeZone = rule.zone,
                    territory = rule.zone,
                    territoryCenter = center,
                    listName = rule.listName,
                    state = rule.aiState or "roam",
                    aiState = rule.aiState or "roam",
                    spawnRuleId = id,
                    awarenessRadiusTiles = rule.awarenessRadiusTiles,
                    patrolPoints = rule.patrolPoints,
                })
                state.spawned = (state.spawned or 0) + 1
                state.cooldownHours = rule.cooldownHours or rule.cooldown or 0
            end
        end
    end
end

local function dropHostileLoot(run, hostile)
    local resourceNodes, level = World.activeCollection(run, "resourceNodes")
    table.insert(resourceNodes, {
        type = "loot",
        coord = {hostile.coord[1], hostile.coord[2]},
        opened = false,
        loot = hostileDropLoot(hostile.kind),
    })
    WorldObjects.mirrorLevel(level)
end

local function removeHostile(run, listName, index)
    local wildlife, level = World.activeWildlife(run)
    local list = wildlife[listName] or {}
    local hostile = list[index]
    if not hostile then
        return false
    end
    dropHostileLoot(run, hostile)
    EntitySystem.remove(level, hostile)
    table.remove(list, index)
    return true
end

local function attackDirection(player)
    local x = player.combatFacingX or player.lastMoveX
    local y = player.combatFacingY or player.lastMoveY
    if (x == 0 or x == nil) and (y == 0 or y == nil) then
        return CONFIG.PLAYER_ATTACK_FACING_FALLBACK_X, 0
    end
    local length = math.max(1, math.sqrt((x * x) + (y * y)))
    return x / length, y / length
end

local function damageHostile(run, listName, index, amount)
    local wildlife = World.activeWildlife(run)
    local hostile = (wildlife[listName] or {})[index]
    if not hostile then
        return false
    end
    ensureHostile(hostile)
    hostile.health = hostile.health - amount
    hostile.staggerTimer = CONFIG.HOSTILE_STAGGER_SECONDS
    hostile.state = "stagger"
    hostile.target = nil
    run.runtime.pendingPulse = {
        kind = "impact",
        coord = {hostile.coord[1], hostile.coord[2]},
    }
    if hostile.health <= 0 then
        removeHostile(run, listName, index)
    end
    return true
end

function Wildlife.spawnCarcass(run, kind, coord)
    local carcasses, level = World.activeCollection(run, "carcasses")
    table.insert(carcasses, {
        kind = kind,
        coord = {coord[1], coord[2]},
        drops = carcassDrops(kind),
        harvestHours = CONFIG.HARVEST_HOURS[kind] or 0.5,
    })
    WorldObjects.mirrorLevel(level)
end

local function resolveStruggle(run, wolf)
    if (run.player.invulnTimer or 0) > 0 then
        wolf.state = "recover"
        wolf.attackTimer = wolf.attackRecovery or CONFIG.WOLF_ATTACK_RECOVERY
        return
    end
    local damage = CONFIG.WOLF_STRUGGLE_BASE_DAMAGE
    if run.player.equippedTool == "knife" then
        damage = damage - 4
    elseif run.player.equippedTool == "hatchet" then
        damage = damage - 2
    end
    if run.player.fatigue < 30 then
        damage = damage + 4
    end
    if run.player.condition < 40 then
        damage = damage + 4
    end

    run.player.condition = Utils.clamp(run.player.condition - damage, 0, run.player.maxCondition)
    run.player.warmth = Utils.clamp(run.player.warmth - 12, 0, CONFIG.MAX_WARMTH)
    run.runtime.causeOfDeath = "wolf attack"
    Survival.applyInfectionRisk(run.player, CONFIG.INFECTION_RISK_HOURS)

    local torso = run.player.clothing.torso
    if torso then
        torso.condition = Utils.clamp(torso.condition - 12, 0, 100)
    end

    run.runtime.pendingShake = {
        intensity = CONFIG.SCREEN_SHAKE_INTENSITY,
        duration = CONFIG.SCREEN_SHAKE_DURATION,
    }
    run.runtime.pendingPulse = {
        kind = "impact",
        coord = {run.player.coord[1], run.player.coord[2]},
    }
    wolf.state = "recover"
    wolf.attackTimer = wolf.attackRecovery or CONFIG.WOLF_ATTACK_RECOVERY
end

local function updateHostile(run, hostile, hours, level)
    ensureHostile(hostile)
    applyActorEcology(hostile, {})
    local seconds = hours * (CONFIG.DAY_DURATION_SECONDS / 24)
    local player = run.player
    local distance = Utils.distance(player.coord[1], player.coord[2], hostile.coord[1], hostile.coord[2])
    local lightRadius = playerDeterrenceRadius(player)
    local lightDeterrent = lightRadius > 0 and distance <= lightRadius
    local fireDeterrent = hostile.kind == "wolf" and fireDetersWolf(run, hostile)
    local awarenessRadius = (hostile.awarenessRadiusTiles or defaultAwarenessTiles(hostile.kind, hostile.depth)) * CONFIG.TILE_SIZE
    hostile.awareness = hostile.awareness or {}
    hostile.awareness.distanceToPlayer = distance
    hostile.awareness.seesPlayer = distance <= awarenessRadius
    if hostile.awareness.seesPlayer then
        hostile.awareness.lastSeenCoord = {player.coord[1], player.coord[2]}
        hostile.awareness.alertness = Utils.clamp((hostile.awareness.alertness or 0) + (hours * 2), 0, 1)
    else
        hostile.awareness.alertness = Utils.clamp((hostile.awareness.alertness or 0) - hours, 0, 1)
    end

    if hostile.staggerTimer > 0 then
        hostile.staggerTimer = math.max(0, hostile.staggerTimer - seconds)
        hostile.state = "stagger"
        return
    end

    if hostile.state == "recover" then
        hostile.attackTimer = math.max(0, (hostile.attackTimer or 0) - seconds)
        if hostile.attackTimer <= 0 then
            hostile.state = "stalk"
        end
        return
    end

    if hostile.state == "windup" then
        hostile.attackTimer = math.max(0, (hostile.attackTimer or 0) - seconds)
        if hostile.attackTimer <= 0 then
            if hostile.kind == "wolf" then
                resolveStruggle(run, hostile)
            elseif (run.player.invulnTimer or 0) <= 0 then
                run.player.condition = Utils.clamp(run.player.condition - hostile.contactDamage, 0, run.player.maxCondition)
                run.player.warmth = Utils.clamp(run.player.warmth - 6, 0, CONFIG.MAX_WARMTH)
                run.runtime.causeOfDeath = "raider attack"
                run.runtime.pendingShake = {
                    intensity = CONFIG.SCREEN_SHAKE_INTENSITY,
                    duration = CONFIG.SCREEN_SHAKE_DURATION,
                }
                run.runtime.pendingPulse = {
                    kind = "impact",
                    coord = {run.player.coord[1], run.player.coord[2]},
                }
            end
            hostile.state = "recover"
            hostile.attackTimer = hostile.attackRecovery
        end
        return
    end

    if hostile.state == "retreat" then
        hostile.fearHours = math.max(0, (hostile.fearHours or 0) - hours)
        if not hostile.target then
            hostile.target = {
                hostile.territoryCenter[1] + math.random(-3, 3) * CONFIG.TILE_SIZE,
                hostile.territoryCenter[2] + math.random(-3, 3) * CONFIG.TILE_SIZE,
            }
        end
        moveEntity(hostile, CONFIG.WOLF_RETREAT_SPEED, hours, level)
        if hostile.fearHours <= 0 and distance > hostile.aggroRadius * CONFIG.TILE_SIZE then
            hostile.state = "roam"
            hostile.target = nil
        end
        return
    end

    if hostile.kind == "wolf" and (fireDeterrent or lightDeterrent) then
        hostile.state = "retreat"
        hostile.fearHours = 0.8
        run.stats.wolvesRepelled = run.stats.wolvesRepelled + 1
        return
    end

    if distance <= hostile.weaponRange * CONFIG.TILE_SIZE then
        hostile.state = "windup"
        hostile.attackTimer = hostile.attackWindup
        return
    end

    local chargeSpeed = hostile.kind == "wolf" and CONFIG.WOLF_CHARGE_SPEED or CONFIG.RAIDER_CHARGE_SPEED
    if distance <= hostile.aggroRadius * CONFIG.TILE_SIZE then
        hostile.state = "charge"
        hostile.target = {player.coord[1], player.coord[2]}
        moveEntity(hostile, chargeSpeed, hours, level)
        return
    end

    if hostile.awareness.seesPlayer then
        hostile.state = hostile.kind == "raider" and "watch" or "stalk"
        hostile.target = hostile.awareness.lastSeenCoord and {hostile.awareness.lastSeenCoord[1], hostile.awareness.lastSeenCoord[2]} or nil
        moveEntity(hostile, hostile.speed * 0.75, hours, level)
        return
    end

    if hostile.patrolPoints and #hostile.patrolPoints > 0 then
        hostile.state = "patrol"
        local point = hostile.patrolPoints[hostile.patrolIndex] or hostile.patrolPoints[1]
        if not hostile.target then
            hostile.target = {point[1], point[2]}
        elseif Utils.distance(hostile.coord[1], hostile.coord[2], hostile.target[1], hostile.target[2]) < 4 then
            hostile.patrolIndex = (hostile.patrolIndex % #hostile.patrolPoints) + 1
            local nextPoint = hostile.patrolPoints[hostile.patrolIndex]
            hostile.target = {nextPoint[1], nextPoint[2]}
        end
    else
        hostile.state = "roam"
    end
    if not hostile.target or math.random() < 0.03 then
        hostile.target = {
            hostile.territoryCenter[1] + math.random(-4, 4) * CONFIG.TILE_SIZE,
            hostile.territoryCenter[2] + math.random(-4, 4) * CONFIG.TILE_SIZE,
        }
    end
    moveEntity(hostile, hostile.speed, hours, level)
end

local function updateWolf(run, wolf, hours, level)
    local player = run.player
    player = player
    updateHostile(run, wolf, hours, level)
end

local function setFleeTarget(entity, playerCoord)
    local dx = entity.coord[1] - playerCoord[1]
    local dy = entity.coord[2] - playerCoord[2]
    local distance = math.max(1, math.sqrt((dx * dx) + (dy * dy)))
    entity.target = {
        entity.coord[1] + (dx / distance) * CONFIG.TILE_SIZE * 3,
        entity.coord[2] + (dy / distance) * CONFIG.TILE_SIZE * 3,
    }
end

local function updatePassive(entity, hours, level, playerCoord)
    applyActorEcology(entity, {})
    entity.awareness = entity.awareness or {}
    local distance = Utils.distance(entity.coord[1], entity.coord[2], playerCoord[1], playerCoord[2])
    local fleeRadius = (entity.awarenessRadiusTiles or defaultAwarenessTiles(entity.kind, entity.depth)) * CONFIG.TILE_SIZE
    entity.awareness.distanceToPlayer = distance
    entity.awareness.seesPlayer = distance <= fleeRadius
    if entity.awareness.seesPlayer then
        entity.state = "flee"
        entity.fearHours = math.max(entity.fearHours or 0, 0.35)
        entity.awareness.lastSeenCoord = {playerCoord[1], playerCoord[2]}
        setFleeTarget(entity, playerCoord)
    elseif (entity.fearHours or 0) > 0 then
        entity.state = "flee"
        entity.fearHours = math.max(0, (entity.fearHours or 0) - hours)
    elseif not entity.target or math.random() < 0.04 then
        entity.state = entity.kind == "deer" and "graze" or "forage"
        setTargetInZone(entity, entity.zone)
    end
    moveEntity(entity, entity.speed, hours, level)
end

function Wildlife.findNearbyTrap(run)
    local traps = World.readActiveCollection(run, "traps")
    for index, trap in ipairs(traps) do
        local distance = Utils.distance(run.player.coord[1], run.player.coord[2], trap.coord[1], trap.coord[2])
        if distance <= CONFIG.TILE_SIZE * 1.2 then
            return trap, index
        end
    end
    return nil
end

function Wildlife.findNearbyCarcass(run)
    local carcasses = World.readActiveCollection(run, "carcasses")
    for index, carcass in ipairs(carcasses) do
        local distance = Utils.distance(run.player.coord[1], run.player.coord[2], carcass.coord[1], carcass.coord[2])
        if distance <= CONFIG.TILE_SIZE * 1.2 then
            return carcass, index
        end
    end
    return nil
end

local function pointInZone(coord, zone)
    local gx, gy = Utils.pixelToGrid(coord[1], coord[2])
    local tileX = gx + 1
    local tileY = gy + 1
    return tileX >= zone.x
        and tileX <= zone.x + zone.width
        and tileY >= zone.y
        and tileY <= zone.y + zone.height
end

function Wildlife.placeSnare(run)
    if Items.count(run.player.inventory, "snare") < 1 then
        return false, "You need a snare."
    end

    local validZone
    local rabbitZones = World.readActiveCollection(run, "rabbitZones")
    for _, zone in ipairs(rabbitZones) do
        if pointInZone(run.player.coord, zone) then
            validZone = zone
            break
        end
    end
    if not validZone then
        return false, "Set snares on rabbit trails."
    end

    Items.remove(run.player.inventory, "snare", 1)
    local traps, level = World.activeCollection(run, "traps")
    table.insert(traps, {
        coord = {run.player.coord[1], run.player.coord[2]},
        zone = validZone,
        state = "set",
        hoursUntilCatch = math.random(CONFIG.SNARE_CATCH_MIN_HOURS, CONFIG.SNARE_CATCH_MAX_HOURS),
    })
    WorldObjects.mirrorLevel(level)
    Survival.updateCarryWeight(run.player)
    return true, "You set a snare."
end

function Wildlife.collectTrap(run)
    local trap, index = Wildlife.findNearbyTrap(run)
    if not trap or trap.state ~= "caught" then
        return false, "No caught snare here."
    end

    Wildlife.spawnCarcass(run, "rabbit", trap.coord)
    local traps = World.activeCollection(run, "traps")
    table.remove(traps, index)
    WorldObjects.mirrorLevel(World.currentLevel(run))
    return true, "A rabbit is caught in the snare."
end

function Wildlife.harvestNearbyCarcass(run)
    local carcass, index = Wildlife.findNearbyCarcass(run)
    if not carcass then
        return false, "No carcass nearby."
    end

    for kind, quantity in pairs(carcass.drops or carcassDrops(carcass.kind)) do
        if quantity > 0 then
            Items.add(run.player.inventory, kind, quantity)
        end
    end
    Items.sortInventory(run.player.inventory)
    Survival.updateCarryWeight(run.player)
    Survival.advanceTime(run, carcass.harvestHours or (CONFIG.HARVEST_HOURS[carcass.kind] or 0.5))
    run.player.fatigue = Utils.clamp(run.player.fatigue - 4, 0, CONFIG.MAX_FATIGUE)
    Survival.gainSkillXP(run.player, "Harvesting", 14)
    if run.player.equippedTool ~= "knife" and run.player.equippedTool ~= "hatchet" then
        Survival.applyInfectionRisk(run.player, CONFIG.INFECTION_RISK_HOURS)
    end
    local carcasses = World.activeCollection(run, "carcasses")
    table.remove(carcasses, index)
    WorldObjects.mirrorLevel(World.currentLevel(run))
    return true, "You harvest the carcass."
end

function Wildlife.playerMeleeAttack(run)
    if run.player.equippedWeapon ~= "sword" then
        return false, "You need a sword ready."
    end

    local aimX, aimY = attackDirection(run.player)
    local bestList
    local bestIndex
    local bestDistance = math.huge
    local wildlife = World.activeWildlife(run)

    local function considerHostiles(listName)
        for index, hostile in ipairs(wildlife[listName] or {}) do
            local dx = hostile.coord[1] - run.player.coord[1]
            local dy = hostile.coord[2] - run.player.coord[2]
            local distance = math.sqrt((dx * dx) + (dy * dy))
            if distance <= CONFIG.PLAYER_MELEE_RANGE_TILES * CONFIG.TILE_SIZE then
                local dot = ((dx / math.max(1, distance)) * aimX) + ((dy / math.max(1, distance)) * aimY)
                if dot >= 0.55 and distance < bestDistance then
                    bestList = listName
                    bestIndex = index
                    bestDistance = distance
                end
            end
        end
    end

    considerHostiles("wolves")
    considerHostiles("raiders")

    if bestList and bestIndex then
        damageHostile(run, bestList, bestIndex, CONFIG.PLAYER_MELEE_DAMAGE)
        return true, "Your sword connects."
    end

    return false, "Your sword cuts empty air."
end

function Wildlife.fireBow(run)
    if run.player.equippedWeapon ~= "bow" then
        return false, "You need a bow ready."
    end
    if Items.count(run.player.inventory, "arrow") < 1 then
        return false, "You have no arrows."
    end

    local aimX, aimY = attackDirection(run.player)
    local bestTarget
    local bestDistance = math.huge
    local wildlife, level = World.activeWildlife(run)

    local function consider(list, kind, listName)
        for index, target in ipairs(list or {}) do
            local dx = target.coord[1] - run.player.coord[1]
            local dy = target.coord[2] - run.player.coord[2]
            local distance = math.sqrt((dx * dx) + (dy * dy))
            if distance <= CONFIG.ARROW_RANGE_TILES * CONFIG.TILE_SIZE then
                local dot = ((dx / math.max(1, distance)) * aimX) + ((dy / math.max(1, distance)) * aimY)
                if dot >= 0.82 and distance < bestDistance then
                    bestTarget = {
                        list = list,
                        listName = listName,
                        index = index,
                        kind = kind,
                        coord = {target.coord[1], target.coord[2]},
                        hostile = kind == "wolf" or kind == "raider",
                    }
                    bestDistance = distance
                end
            end
        end
    end

    consider(wildlife.raiders, "raider", "raiders")
    consider(wildlife.wolves, "wolf", "wolves")
    consider(wildlife.rabbits, "rabbit", "rabbits")
    consider(wildlife.deer, "deer", "deer")

    Items.remove(run.player.inventory, "arrow", 1)
    Survival.updateCarryWeight(run.player)
    Survival.gainSkillXP(run.player, "Archery", 12)

    if not bestTarget then
        run.runtime.pendingPulse = {
            kind = "impact",
            coord = {
                run.player.coord[1] + aimX * CONFIG.ARROW_RANGE_TILES * CONFIG.TILE_SIZE,
                run.player.coord[2] + aimY * CONFIG.ARROW_RANGE_TILES * CONFIG.TILE_SIZE,
            },
        }
        return false, "The arrow vanishes into the snow."
    end

    if bestTarget.hostile then
        damageHostile(run, bestTarget.listName, bestTarget.index, CONFIG.PLAYER_BOW_DAMAGE)
    else
        EntitySystem.remove(level, bestTarget.list[bestTarget.index])
        table.remove(bestTarget.list, bestTarget.index)
        Wildlife.spawnCarcass(run, bestTarget.kind, bestTarget.coord)
    end
    run.runtime.pendingPulse = {
        kind = "impact",
        coord = {bestTarget.coord[1], bestTarget.coord[2]},
    }
    return true, bestTarget.hostile and ("Your arrow hits the " .. bestTarget.kind .. ".")
        or ("Your arrow drops the " .. bestTarget.kind .. ".")
end

function Wildlife.fish(run)
    local nearby
    local fishingSpots = World.readActiveCollection(run, "fishingSpots")
    for _, spot in ipairs(fishingSpots) do
        local distance = Utils.distance(run.player.coord[1], run.player.coord[2], spot.coord[1], spot.coord[2])
        if distance <= CONFIG.TILE_SIZE * 1.2 then
            nearby = spot
            break
        end
    end
    if not nearby then
        return false, "Find a fishing hole."
    end
    if Items.count(run.player.inventory, "fishing_tackle") < 1 then
        return false, "You need fishing tackle."
    end

    Survival.advanceTime(run, CONFIG.FISHING_ACTION_HOURS)
    run.player.fatigue = Utils.clamp(run.player.fatigue - 6, 0, CONFIG.MAX_FATIGUE)
    local chance = CONFIG.FISHING_BASE_CHANCE + ((Survival.getSkillLevel(run.player, "Fishing") - 1) * 0.05)
    Survival.gainSkillXP(run.player, "Fishing", 12)
    if math.random() <= math.min(0.95, chance) then
        Wildlife.spawnCarcass(run, "fish", nearby.coord)
        run.runtime.pendingPulse = {
            kind = "fishing",
            coord = {nearby.coord[1], nearby.coord[2]},
        }
        return true, "You pull a fish from the ice."
    end
    return false, "Nothing bites."
end

function Wildlife.update(run, hours)
    World.attachRun(run)
    local level = World.currentLevel(run)
    Wildlife.mirrorLevel(level)
    applySpawnRules(run, level, hours)
    local wildlife = World.activeWildlife(run)

    for _, wolf in ipairs(wildlife.wolves or {}) do
        updateWolf(run, wolf, hours, level)
        syncActorState(wolf)
    end
    for _, raider in ipairs(wildlife.raiders or {}) do
        updateHostile(run, raider, hours, level)
        syncActorState(raider)
    end
    for _, rabbit in ipairs(wildlife.rabbits or {}) do
        updatePassive(rabbit, hours, level, run.player.coord)
        syncActorState(rabbit)
    end
    for _, deer in ipairs(wildlife.deer or {}) do
        updatePassive(deer, hours, level, run.player.coord)
        syncActorState(deer)
    end

    local traps = World.readActiveCollection(run, "traps")
    for _, trap in ipairs(traps) do
        if trap.state == "set" then
            trap.hoursUntilCatch = trap.hoursUntilCatch - hours
            if trap.hoursUntilCatch <= 0 then
                trap.state = "caught"
            end
        end
    end
end

return Wildlife
