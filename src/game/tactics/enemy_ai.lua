local Grid = require("src.core.grid")
local EnemyCatalog = require("src.game.tactics.enemy_catalog")

local EnemyAI = {}

local doctrineProfiles = {
    recon = {
        weights = { distance = -4, reconAdvance = 8 },
        targetWeights = { reconUnseen = 28 },
        tacticBias = { isolate = 6 },
    },
    pincer = {
        weights = { flank = 38, pincer = 34 },
        targetWeights = { visible = 28 },
        roleBias = { skirmisherMove = 10 },
    },
    isolate = {
        targetWeights = { isolation = 5, wounded = 7 },
        tacticBias = { isolate = 24 },
        weights = { flank = 36 },
    },
    sabotage = {
        tacticBias = { objective_pressure = 54 },
        weights = { advance = 5 },
        targetWeights = { visible = 16 },
    },
    hold = {
        weights = { cover = 2, hazard = -16 },
        roleBias = { anchorHold = 12 },
    },
    regroup = {
        maxMoveAp = 1,
        weights = { cover = 2, distance = -2, hazard = -18 },
        roleBias = { anchorHold = 14 },
    },
}

local function tileKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function copyValue(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, nested in pairs(value) do
        result[key] = copyValue(nested)
    end
    return result
end

local function mergeProfile(target, source)
    if type(source) ~= "table" then
        return target
    end
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            mergeProfile(target[key], value)
        else
            target[key] = copyValue(value)
        end
    end
    return target
end

local function sortedUnits(state, side)
    local units = state:unitsForSide(side)
    table.sort(units, function(a, b)
        return tostring(a.id) < tostring(b.id)
    end)
    return units
end

local function firstObjective(state)
    for _, id in ipairs(state.objectiveOrder or {}) do
        return state:objective(id)
    end
    return nil
end

local function lineVisible(state, ax, ay, bx, by)
    if not (state:inBounds(ax, ay) and state:inBounds(bx, by)) then
        return false, nil
    end
    local ok, los = pcall(function()
        return state:lineOfSight(ax, ay, bx, by)
    end)
    if not ok then
        return false, nil
    end
    return los.visible == true and los.obscured ~= true, los
end

local function visiblePlayers(state, enemy)
    local result = {}
    for _, player in ipairs(sortedUnits(state, "player")) do
        local visible = lineVisible(state, enemy.x, enemy.y, player.x, player.y)
        if visible then
            result[#result + 1] = player
        end
    end
    return result
end

local function playerSupportDistance(state, player)
    local best
    for _, ally in ipairs(state:unitsForSide("player")) do
        if ally.id ~= player.id then
            local distance = state:distance(player.x, player.y, ally.x, ally.y)
            if not best or distance < best then
                best = distance
            end
        end
    end
    return best or 99
end

local function profileFor(enemy, options)
    local profile = EnemyCatalog.aiProfile(enemy)
    local doctrine = options and options.doctrine
    if doctrine and doctrineProfiles[doctrine.id or doctrine] then
        mergeProfile(profile, doctrineProfiles[doctrine.id or doctrine])
    end
    if options and options.ai then
        mergeProfile(profile, options.ai)
    end
    if options and options.maxMoveAp then
        profile.maxMoveAp = options.maxMoveAp
    end
    if options and options.attackRange then
        profile.attackRange = options.attackRange
    end
    return profile
end

local function anyEnemySeesPlayer(state, player)
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        if lineVisible(state, enemy.x, enemy.y, player.x, player.y) then
            return true
        end
    end
    return false
end

local function countVisiblePlayers(state)
    local count = 0
    for _, player in ipairs(state:unitsForSide("player")) do
        if anyEnemySeesPlayer(state, player) then
            count = count + 1
        end
    end
    return count
end

local function enemyLowHpCount(state)
    local count = 0
    local total = 0
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        total = total + 1
        local maxHp = enemy.maxHp or enemy.hp or 1
        if (enemy.hp or maxHp) <= math.max(1, math.floor(maxHp * 0.4)) then
            count = count + 1
        end
    end
    return count, total
end

local function isolatedVisiblePlayers(state)
    local count = 0
    for _, player in ipairs(state:unitsForSide("player")) do
        if playerSupportDistance(state, player) >= 4 and anyEnemySeesPlayer(state, player) then
            count = count + 1
        end
    end
    return count
end

function EnemyAI.analyzeDoctrine(state, options)
    options = options or {}
    local objective = options.objective or firstObjective(state)
    local visiblePlayers = countVisiblePlayers(state)
    local lowHp, enemyCount = enemyLowHpCount(state)
    local isolated = isolatedVisiblePlayers(state)
    local scores = {
        recon = visiblePlayers == 0 and 80 or 0,
        pincer = math.max(0, visiblePlayers - 0) * 18 + math.max(0, enemyCount - 1) * 8,
        isolate = isolated * 34,
        sabotage = objective and math.max(0, ((objective.maxIntegrity or objective.integrity or 1) - (objective.integrity or 0))) * 12 or 0,
        hold = enemyCount > 0 and 18 or 0,
        regroup = enemyCount > 0 and (lowHp / enemyCount) * 60 or 0,
    }
    if objective and (objective.integrity or 0) <= 1 then
        scores.sabotage = scores.sabotage + 80
    end
    local order = { "sabotage", "isolate", "pincer", "recon", "regroup", "hold" }
    local best = order[1]
    for _, id in ipairs(order) do
        if scores[id] > (scores[best] or -1) then
            best = id
        end
    end
    return {
        id = best,
        scores = scores,
        inputs = {
            visiblePlayers = visiblePlayers,
            isolatedPlayers = isolated,
            enemyLowHp = lowHp,
            enemyCount = enemyCount,
            objectiveIntegrity = objective and objective.integrity or nil,
            objectiveMaxIntegrity = objective and objective.maxIntegrity or nil,
        },
    }
end

local function unitMemory(options, enemy)
    return options and options.memory and options.memory.units and options.memory.units[enemy.id] or nil
end

local function targetMemory(options, target)
    return options and options.memory and options.memory.targets and target and target.id and options.memory.targets[target.id] or nil
end

local function targetScore(state, enemy, target, visible, profile, options)
    local w = profile.targetWeights or {}
    local memoryWeights = profile.memory or {}
    local enemyMemory = unitMemory(options, enemy)
    local pressure = targetMemory(options, target)
    local distance = state:distance(enemy.x, enemy.y, target.x, target.y)
    local score = (w.base or 80) + distance * (w.distance or -3)
    if target.side == "player" then
        score = score + math.max(0, 6 - (target.hp or 1)) * (w.wounded or 5)
        score = score + math.min(24, playerSupportDistance(state, target) * (w.isolation or 3))
        if pressure and (pressure.damage or 0) > 0 then
            score = score + math.min(24, (pressure.damage or 0) * (memoryWeights.damagedTarget or 10))
        end
    end
    if visible then
        score = score + (w.visible or 24)
    end
    if enemyMemory and enemyMemory.lastTarget == target.id then
        if (enemyMemory.lastDamage or 0) > 0 then
            score = score + (memoryWeights.pressureTarget or 14)
        elseif enemyMemory.lastOutcome == "failed" or enemyMemory.lastOutcome == "no_los" then
            score = score + (memoryWeights.failedTarget or -12)
        end
    end
    return score
end

local function chooseTarget(state, enemy, profile, objective, options)
    local role = profile.role or "assault"
    local intent = enemy.intent or {}
    local targetWeights = profile.targetWeights or {}
    if objective and ((objective.integrity or 0) <= 1 or intent.target == "objective" or enemy.intentType == "objective_stamp") then
        return objective, true, "objective_pressure"
    end
    local visible = visiblePlayers(state, enemy)
    local best, bestScore
    for _, player in ipairs(visible) do
        local score = targetScore(state, enemy, player, true, profile, options)
        if role == "skirmisher" then
            score = score + (targetWeights.skirmisherVisible or 10)
        elseif role == "anchor" then
            score = score + (targetWeights.anchorVisible or -4)
        end
        if not bestScore or score > bestScore or (score == bestScore and tostring(player.id) < tostring(best.id)) then
            best, bestScore = player, score
        end
    end
    if best then
        local isolation = playerSupportDistance(state, best) >= 4
        return best, true, isolation and "isolate" or "attack"
    end
    for _, player in ipairs(sortedUnits(state, "player")) do
        local score = targetScore(state, enemy, player, false, profile, options)
        if role == "recon" then
            score = score + (targetWeights.reconUnseen or 18)
        end
        if not bestScore or score > bestScore or (score == bestScore and tostring(player.id) < tostring(best.id)) then
            best, bestScore = player, score
        end
    end
    return best, false, "recon"
end

local function coverProtectionScore(state, x, y, profile)
    local coverWeights = profile.cover or {}
    local score = 0
    for _, player in ipairs(state:unitsForSide("player")) do
        local visible = lineVisible(state, player.x, player.y, x, y)
        if visible then
            local ok, cover = pcall(function()
                return state:coverFromAttack(player.x, player.y, x, y)
            end)
            if ok and cover.cover == "full" then
                score = score + (coverWeights.full or 12)
            elseif ok and cover.cover == "half" then
                score = score + (coverWeights.half or 7)
            elseif state:distance(player.x, player.y, x, y) <= 3 then
                score = score + (coverWeights.closeExposed or -12)
            else
                score = score + (coverWeights.exposed or -4)
            end
        end
    end
    return score
end

local function tileHazardSeverity(tile)
    local hazard = tile and tile.hazard
    if not hazard then
        return 0
    end
    return hazard.damage or hazard.cost or hazard.apCost or 1
end

local function attackInfo(state, x, y, target)
    if not (target and target.side == "player") then
        return { visible = target and lineVisible(state, x, y, target.x, target.y), flanked = false, damage = 1 }
    end
    local visible = lineVisible(state, x, y, target.x, target.y)
    if not visible then
        return { visible = false, flanked = false, damage = 0 }
    end
    local ok, profile = pcall(function()
        return state:attackProfile(x, y, target.x, target.y)
    end)
    if not ok then
        return { visible = true, flanked = false, damage = 1 }
    end
    return profile
end

local function reservationPincerScore(target, x, y, claims, profile)
    local targetClaims = claims and target and claims[target.id] or nil
    if not targetClaims then
        return 0, false
    end
    for _, claim in ipairs(targetClaims) do
        local ax = claim.x - target.x
        local ay = claim.y - target.y
        local bx = x - target.x
        local by = y - target.y
        if ax * bx + ay * by < 0 then
            return (profile.weights and profile.weights.pincer) or 20, true
        end
    end
    return 0, false
end

local function pathTiles(enemy, path)
    local result = {}
    local x, y = enemy.x, enemy.y
    for _, direction in ipairs(path or {}) do
        local delta = Grid.delta(direction)
        x = x + delta.x
        y = y + delta.y
        result[#result + 1] = { x = x, y = y }
    end
    return result
end

local function planLabel(tactic, enemy)
    local code = {
        flank = "FLK",
        pincer = "PIN",
        isolate = "ISO",
        recon = "REC",
        cover = "COV",
        objective_pressure = "OBJ",
        attack = "ATK",
    }
    return tostring(code[tactic] or "ATK") .. " " .. tostring(enemy.kind or enemy.id)
end

local function addTerm(terms, name, raw, weight, value)
    raw = raw or 0
    weight = weight or 0
    value = value ~= nil and value or raw * weight
    terms[#terms + 1] = { name = name, raw = raw, weight = weight, value = value }
    return value
end

local function candidateScore(state, enemy, profile, target, targetVisible, baseTactic, candidate, options)
    local tile = state:tileAt(candidate.x, candidate.y)
    local terms = {}
    local score = 0
    local weights = profile.weights or {}
    local tacticBias = profile.tacticBias or {}
    local roleBias = profile.roleBias or {}
    local role = profile.role or "assault"
    local memoryWeights = profile.memory or {}
    local enemyMemory = unitMemory(options, enemy)
    local pressure = targetMemory(options, target)
    local distance = state:distance(candidate.x, candidate.y, target.x, target.y)
    local startDistance = state:distance(enemy.x, enemy.y, target.x, target.y)
    local attack = attackInfo(state, candidate.x, candidate.y, target)
    local inRange = distance <= (profile.attackRange or options.attackRange or 3)
    local advanceDelta = startDistance - distance
    score = score + addTerm(terms, "distance", distance, weights.distance or -5)
    score = score + addTerm(terms, "apCost", candidate.apCost or 0, weights.apCost or -3)
    score = score + addTerm(terms, "advance", advanceDelta, weights.advance or 4, math.max(-18, advanceDelta * (weights.advance or 4)))
    score = score + addTerm(terms, "cover", coverProtectionScore(state, candidate.x, candidate.y, profile), weights.cover or 1)
    score = score + addTerm(terms, "hazard", tileHazardSeverity(tile), weights.hazard or -12)
    score = score + addTerm(terms, "height", tile.height or 0, weights.height or 2)
    if attack.visible and inRange then
        score = score + addTerm(terms, "los", 1, weights.los or 36)
        score = score + addTerm(terms, "damage", attack.damage or 0, weights.damage or 8)
    elseif targetVisible then
        score = score + addTerm(terms, "targetVisibleMiss", 1, weights.targetVisibleMiss or -14)
    elseif role == "recon" then
        score = score + addTerm(terms, "reconAdvance", math.max(0, advanceDelta), weights.reconAdvance or 5)
    end
    if attack.flanked then
        score = score + addTerm(terms, "flank", 1, weights.flank or 32)
    end
    if attack.highGround then
        score = score + addTerm(terms, "highGround", 1, weights.highGround or 8)
    end
    if baseTactic == "objective_pressure" then
        score = score + addTerm(terms, "objective", 1, tacticBias.objective_pressure or 32)
    elseif baseTactic == "isolate" then
        score = score + addTerm(terms, "isolate", 1, tacticBias.isolate or 10)
    elseif role == "anchor" and candidate.apCost == 0 then
        score = score + addTerm(terms, "roleBias", 1, roleBias.anchorHold or 7)
    elseif role == "skirmisher" and candidate.apCost > 0 then
        score = score + addTerm(terms, "roleBias", 1, roleBias.skirmisherMove or 6)
    end
    local pincerScore, pincer = reservationPincerScore(target, candidate.x, candidate.y, options.targetClaims, profile)
    if pincer then
        score = score + addTerm(terms, "pincer", 1, pincerScore)
    end
    if pressure and (pressure.damage or 0) > 0 and target and target.side == "player" then
        score = score + addTerm(terms, "memoryPressure", pressure.damage or 0, memoryWeights.damagedTarget or 10, math.min(24, (pressure.damage or 0) * (memoryWeights.damagedTarget or 10)))
    end
    if enemyMemory and enemyMemory.lastDestination and enemyMemory.lastDestination.x == candidate.x and enemyMemory.lastDestination.y == candidate.y then
        score = score + addTerm(terms, "memoryRepeatTile", 1, memoryWeights.repeatDestination or -18)
    end
    if enemyMemory and enemyMemory.lastTarget == (target and target.id) then
        if (enemyMemory.lastDamage or 0) > 0 then
            score = score + addTerm(terms, "memoryFocus", 1, memoryWeights.pressureTarget or 14)
        elseif enemyMemory.lastOutcome == "failed" or enemyMemory.lastOutcome == "no_los" then
            score = score + addTerm(terms, "memoryFailedTarget", 1, memoryWeights.failedTarget or -12)
        end
    end
    return score, attack, pincer, terms
end

local function sortedTerms(terms)
    local result = copyValue(terms or {})
    table.sort(result, function(a, b)
        local av = math.abs(a.value or 0)
        local bv = math.abs(b.value or 0)
        if av == bv then
            return tostring(a.name) < tostring(b.name)
        end
        return av > bv
    end)
    return result
end

local function topCandidates(records, limit)
    local result = {}
    for index = 1, math.min(limit or 5, #records) do
        local record = records[index]
        result[#result + 1] = {
            x = record.candidate.x,
            y = record.candidate.y,
            score = record.score,
            apCost = record.candidate.apCost or 0,
            visible = record.attack and record.attack.visible == true,
            flanked = record.attack and record.attack.flanked == true,
            pincer = record.pincer == true,
            terms = sortedTerms(record.terms),
        }
    end
    return result
end

function EnemyAI.profile(enemy, options)
    return profileFor(enemy, options)
end

function EnemyAI.role(enemy)
    return profileFor(enemy).role or "assault"
end

function EnemyAI.planEnemy(state, enemy, options)
    options = options or {}
    local objective = options.objective or firstObjective(state)
    local doctrine = options.doctrine or EnemyAI.analyzeDoctrine(state, { objective = objective })
    options.doctrine = doctrine
    local profile = profileFor(enemy, options)
    local role = profile.role or "assault"
    local target, targetVisible, baseTactic = chooseTarget(state, enemy, profile, objective, options)
    if not target then
        return nil
    end
    local maxMoveAp = math.max(0, math.min(enemy.ap or 0, profile.maxMoveAp or options.maxMoveAp or 2))
    local movement = state:movementPreview(enemy.id, { maxCost = maxMoveAp })
    local records = {}
    local rejected = {}
    local reserved = options.reserved or {}
    for _, candidate in ipairs(movement.reachable or {}) do
        local key = tileKey(candidate.x, candidate.y)
        if reserved[key] and not (candidate.x == enemy.x and candidate.y == enemy.y) then
            local penalty = profile.weights and profile.weights.reservationPenalty or -999
            rejected[#rejected + 1] = {
                x = candidate.x,
                y = candidate.y,
                reason = "reserved",
                owner = reserved[key],
                score = penalty,
                terms = { { name = "reservationPenalty", raw = 1, weight = penalty, value = penalty } },
            }
        else
            local score, attack, pincer, terms = candidateScore(state, enemy, profile, target, targetVisible, baseTactic, candidate, options)
            records[#records + 1] = {
                key = key,
                candidate = candidate,
                score = score,
                attack = attack,
                pincer = pincer,
                terms = terms,
            }
        end
    end
    table.sort(records, function(a, b)
        if a.score == b.score then
            return a.key < b.key
        end
        return a.score > b.score
    end)
    local bestRecord = records[1]
    local best = bestRecord and bestRecord.candidate or { x = enemy.x, y = enemy.y, apCost = 0, path = {} }
    local bestAttack = bestRecord and bestRecord.attack or attackInfo(state, best.x, best.y, target)
    local bestPincer = bestRecord and bestRecord.pincer or false
    local distance = state:distance(best.x, best.y, target.x, target.y)
    local canAct = bestAttack.visible and distance <= (profile.attackRange or options.attackRange or 3)
    local tactic = baseTactic
    if bestPincer then
        tactic = "pincer"
    elseif bestAttack.flanked and canAct then
        tactic = "flank"
    elseif tactic == "attack" and coverProtectionScore(state, best.x, best.y, profile) > 0 then
        tactic = "cover"
    end
    local targetTiles = { { x = target.x, y = target.y } }
    if best.x ~= enemy.x or best.y ~= enemy.y then
        targetTiles[#targetTiles + 1] = { x = best.x, y = best.y }
    end
    local debug = {
        unit = enemy.id,
        role = role,
        debugName = profile.debugName,
        riskProfile = profile.riskProfile,
        weights = copyValue(profile.weights),
        memoryWeights = copyValue(profile.memory),
        tacticBias = copyValue(profile.tacticBias),
        inputs = {
            doctrine = doctrine and doctrine.id or nil,
            memoryTarget = unitMemory(options, enemy) and unitMemory(options, enemy).lastTarget or nil,
            target = target.id,
            targetX = target.x,
            targetY = target.y,
            targetVisible = targetVisible == true,
            baseTactic = baseTactic,
            maxMoveAp = maxMoveAp,
            attackRange = profile.attackRange or options.attackRange or 3,
        },
        doctrine = copyValue(doctrine),
        chosen = {
            x = best.x,
            y = best.y,
            score = bestRecord and bestRecord.score or 0,
            tactic = tactic,
            canAct = canAct == true,
        },
        scoreBreakdown = sortedTerms(bestRecord and bestRecord.terms or {}),
        topCandidates = topCandidates(records, 5),
        rejected = rejected,
        reservation = { tile = tileKey(best.x, best.y), owner = reserved[tileKey(best.x, best.y)] },
    }
    return {
        unit = enemy.id,
        role = role,
        tactic = tactic,
        label = planLabel(tactic, enemy),
        target = target,
        targetVisible = targetVisible,
        destination = { x = best.x, y = best.y },
        path = copyValue(pathTiles(enemy, best.path)),
        directions = best.path or {},
        apCost = best.apCost or 0,
        targetTiles = targetTiles,
        canAct = canAct,
        attack = bestAttack,
        damage = math.max(1, (enemy.intent and enemy.intent.damage) or 1),
        category = target.side == "player" and "attack" or "destroy",
        score = bestRecord and bestRecord.score or 0,
        debug = debug,
    }
end

function EnemyAI.planTurn(state, options)
    options = options or {}
    local reserved = {}
    local targetClaims = {}
    local plans = {}
    local doctrine = options.doctrine or EnemyAI.analyzeDoctrine(state, { objective = options.objective })
    for _, enemy in ipairs(sortedUnits(state, "enemy")) do
        local plan = nil
        if not (options.skipIds and options.skipIds[enemy.id]) then
            plan = EnemyAI.planEnemy(state, enemy, {
                ai = options.ai,
                doctrine = doctrine,
                memory = options.memory,
                objective = options.objective,
                reserved = reserved,
                targetClaims = targetClaims,
                maxMoveAp = options.maxMoveAp,
                attackRange = options.attackRange,
            })
        end
        if plan then
            reserved[tileKey(plan.destination.x, plan.destination.y)] = enemy.id
            if plan.debug and plan.debug.reservation then
                plan.debug.reservation.owner = enemy.id
            end
            if plan.target and plan.target.id then
                targetClaims[plan.target.id] = targetClaims[plan.target.id] or {}
                targetClaims[plan.target.id][#targetClaims[plan.target.id] + 1] = { x = plan.destination.x, y = plan.destination.y }
            end
            plans[#plans + 1] = plan
        end
    end
    return { plans = plans, reserved = reserved, targetClaims = targetClaims, doctrine = doctrine }
end

return EnemyAI
