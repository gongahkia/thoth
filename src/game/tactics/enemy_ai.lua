local Grid = require("src.core.grid")

local EnemyAI = {}

local roleByKind = {
    page_scout = "recon",
    ledger_hound = "skirmisher",
    drawer_mite = "recon",
    binding_indexer = "anchor",
    footnote_trapper = "anchor",
    claim_lens = "anchor",
    writ_bailiff = "anchor",
    errata_physick = "support",
    margin_lumen = "support",
    rafter_notary = "skirmisher",
    seal_clerk = "anchor",
    undertext_miner = "skirmisher",
}

local function tileKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function copyTiles(values)
    local result = {}
    for _, tile in ipairs(values or {}) do
        result[#result + 1] = { x = tile.x, y = tile.y }
    end
    return result
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
            local distance = Grid.manhattan(player.x, player.y, ally.x, ally.y)
            if not best or distance < best then
                best = distance
            end
        end
    end
    return best or 99
end

local function targetScore(state, enemy, target, visible)
    local distance = Grid.manhattan(enemy.x, enemy.y, target.x, target.y)
    local score = 80 - distance * 3
    if target.side == "player" then
        score = score + math.max(0, 6 - (target.hp or 1)) * 5
        score = score + math.min(24, playerSupportDistance(state, target) * 3)
    end
    if visible then
        score = score + 24
    end
    return score
end

local function chooseTarget(state, enemy, role, objective)
    local intent = enemy.intent or {}
    if objective and ((objective.integrity or 0) <= 1 or intent.target == "objective" or enemy.intentType == "objective_stamp") then
        return objective, true, "objective_pressure"
    end
    local visible = visiblePlayers(state, enemy)
    local best, bestScore
    for _, player in ipairs(visible) do
        local score = targetScore(state, enemy, player, true)
        if role == "skirmisher" then
            score = score + 10
        elseif role == "anchor" then
            score = score - 4
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
        local score = targetScore(state, enemy, player, false)
        if role == "recon" then
            score = score + 18
        end
        if not bestScore or score > bestScore or (score == bestScore and tostring(player.id) < tostring(best.id)) then
            best, bestScore = player, score
        end
    end
    return best, false, "recon"
end

local function coverProtectionScore(state, x, y)
    local score = 0
    for _, player in ipairs(state:unitsForSide("player")) do
        local visible = lineVisible(state, player.x, player.y, x, y)
        if visible then
            local ok, cover = pcall(function()
                return state:coverFromAttack(player.x, player.y, x, y)
            end)
            if ok and cover.cover == "full" then
                score = score + 12
            elseif ok and cover.cover == "half" then
                score = score + 7
            elseif Grid.manhattan(player.x, player.y, x, y) <= 3 then
                score = score - 12
            else
                score = score - 4
            end
        end
    end
    return score
end

local function tileHazardPenalty(tile)
    local hazard = tile and tile.hazard
    if not hazard then
        return 0
    end
    return (hazard.damage or hazard.cost or hazard.apCost or 1) * 12
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

local function reservationPincerScore(target, x, y, claims)
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
            return 20, true
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

local function candidateScore(state, enemy, role, target, targetVisible, baseTactic, candidate, options)
    local tile = state:tileAt(candidate.x, candidate.y)
    local score = 0
    local distance = Grid.manhattan(candidate.x, candidate.y, target.x, target.y)
    local startDistance = Grid.manhattan(enemy.x, enemy.y, target.x, target.y)
    local attack = attackInfo(state, candidate.x, candidate.y, target)
    local inRange = distance <= (options.attackRange or 3)
    score = score - distance * 5 - (candidate.apCost or 0) * 3
    score = score + math.max(-18, (startDistance - distance) * 4)
    score = score + coverProtectionScore(state, candidate.x, candidate.y)
    score = score - tileHazardPenalty(tile)
    score = score + ((tile.height or 0) * 2)
    if attack.visible and inRange then
        score = score + 36 + ((attack.damage or 0) * 8)
    elseif targetVisible then
        score = score - 14
    elseif role == "recon" then
        score = score + math.max(0, startDistance - distance) * 5
    end
    if attack.flanked then
        score = score + 32
    end
    if attack.highGround then
        score = score + 8
    end
    if baseTactic == "objective_pressure" then
        score = score + 32
    elseif baseTactic == "isolate" then
        score = score + 10
    elseif role == "anchor" and candidate.apCost == 0 then
        score = score + 7
    elseif role == "skirmisher" and candidate.apCost > 0 then
        score = score + 6
    end
    local pincerScore, pincer = reservationPincerScore(target, candidate.x, candidate.y, options.targetClaims)
    score = score + pincerScore
    return score, attack, pincer
end

function EnemyAI.role(enemy)
    return (enemy and (enemy.role or roleByKind[enemy.kind] or roleByKind[enemy.id])) or "assault"
end

function EnemyAI.planEnemy(state, enemy, options)
    options = options or {}
    local objective = options.objective or firstObjective(state)
    local role = EnemyAI.role(enemy)
    local target, targetVisible, baseTactic = chooseTarget(state, enemy, role, objective)
    if not target then
        return nil
    end
    local movement = state:movementPreview(enemy.id, { maxCost = math.max(0, math.min(enemy.ap or 0, options.maxMoveAp or 2)) })
    local best, bestScore, bestAttack, bestPincer
    local reserved = options.reserved or {}
    for _, candidate in ipairs(movement.reachable or {}) do
        local key = tileKey(candidate.x, candidate.y)
        if not reserved[key] or (candidate.x == enemy.x and candidate.y == enemy.y) then
            local score, attack, pincer = candidateScore(state, enemy, role, target, targetVisible, baseTactic, candidate, options)
            if not bestScore or score > bestScore or (score == bestScore and key < tileKey(best.x, best.y)) then
                best, bestScore, bestAttack, bestPincer = candidate, score, attack, pincer
            end
        end
    end
    best = best or { x = enemy.x, y = enemy.y, apCost = 0, path = {} }
    bestAttack = bestAttack or attackInfo(state, best.x, best.y, target)
    local distance = Grid.manhattan(best.x, best.y, target.x, target.y)
    local canAct = bestAttack.visible and distance <= (options.attackRange or 3)
    local tactic = baseTactic
    if bestPincer then
        tactic = "pincer"
    elseif bestAttack.flanked and canAct then
        tactic = "flank"
    elseif tactic == "attack" and coverProtectionScore(state, best.x, best.y) > 0 then
        tactic = "cover"
    end
    local targetTiles = { { x = target.x, y = target.y } }
    if best.x ~= enemy.x or best.y ~= enemy.y then
        targetTiles[#targetTiles + 1] = { x = best.x, y = best.y }
    end
    return {
        unit = enemy.id,
        role = role,
        tactic = tactic,
        label = planLabel(tactic, enemy),
        target = target,
        targetVisible = targetVisible,
        destination = { x = best.x, y = best.y },
        path = copyTiles(pathTiles(enemy, best.path)),
        directions = best.path or {},
        apCost = best.apCost or 0,
        targetTiles = targetTiles,
        canAct = canAct,
        attack = bestAttack,
        damage = math.max(1, (enemy.intent and enemy.intent.damage) or 1),
        category = target.side == "player" and "attack" or "destroy",
        score = bestScore or 0,
    }
end

function EnemyAI.planTurn(state, options)
    options = options or {}
    local reserved = {}
    local targetClaims = {}
    local plans = {}
    for _, enemy in ipairs(sortedUnits(state, "enemy")) do
        local plan = nil
        if not (options.skipIds and options.skipIds[enemy.id]) then
            plan = EnemyAI.planEnemy(state, enemy, {
                objective = options.objective,
                reserved = reserved,
                targetClaims = targetClaims,
                maxMoveAp = options.maxMoveAp,
                attackRange = options.attackRange,
            })
        end
        if plan then
            reserved[tileKey(plan.destination.x, plan.destination.y)] = enemy.id
            if plan.target and plan.target.id then
                targetClaims[plan.target.id] = targetClaims[plan.target.id] or {}
                targetClaims[plan.target.id][#targetClaims[plan.target.id] + 1] = { x = plan.destination.x, y = plan.destination.y }
            end
            plans[#plans + 1] = plan
        end
    end
    return { plans = plans, reserved = reserved, targetClaims = targetClaims }
end

return EnemyAI
