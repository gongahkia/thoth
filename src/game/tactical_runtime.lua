local Grid = require("src.core.grid")
local TacticsState = require("src.game.tactics.state")
local TacticsResolution = require("src.game.tactics.resolution")
local ClassCatalog = require("src.game.tactics.class_catalog")
local Procgen = require("src.game.tactics.procgen")
local TacticsAP = require("src.game.tactics.ap")
local EnemyAI = require("src.game.tactics.enemy_ai")

local Runtime = {}

local originX = -5
local originY = -5
local liveClassRoster = {
    { id = "warden", classId = "warden", hp = 6 },
    { id = "duelist", classId = "duelist", hp = 5 },
    { id = "apothecary", classId = "mender", hp = 4 },
    { id = "thief", classId = "harrier", hp = 4 },
    { id = "arcanist", classId = "arcanist", hp = 4 },
    { id = "lamplighter", classId = "lamplighter", hp = 4 },
}
local sliceBoardActions = {
    warden = { "line_guard", "brace", "shove" },
    duelist = { "red_line", "dash_strike", "position_swap" },
    mender = { "field_triage", "stabilize", "smoke_binder" },
    harrier = { "ghost_route", "courier_cut" },
    arcanist = { "seal_reader", "line_bender", "intent_breaker" },
    lamplighter = { "beacon_runner", "cone_keeper", "ash_lamp" },
}
local enemyIntentSpecs = {
    audit_hound = { label = "bite notice", target = "nearest_player" },
    claim_lens = { label = "claim beam", target = "objective" },
    claimant = { label = "claim notice", target = "nearest_player" },
}

local function copyList(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[#result + 1] = value
    end
    return result
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

local function applyIntentMetadata(plan, intent)
    intent = intent or {}
    plan.mode = intent.mode or "exact"
    plan.mask = intent.mask
    plan.footprintHidden = intent.footprintHidden == true
    plan.revealRotations = copyList(intent.revealRotations)
    plan.revealActions = copyList(intent.revealActions)
    plan.revealClasses = copyList(intent.revealClasses)
    plan.weakPoint = intent.weakPoint
    plan.statusEffect = copyValue(intent.statusEffect)
    plan.effect = intent.effect
    plan.aiCanReposition = intent.aiCanReposition == true
    return plan
end

local function tileKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function reverseList(values)
    local left = 1
    local right = #values
    while left < right do
        values[left], values[right] = values[right], values[left]
        left = left + 1
        right = right - 1
    end
    return values
end

local function partyPath(queue, node)
    local path = {}
    while node do
        path[#path + 1] = { x = node.x, y = node.y }
        node = node.parent and queue[node.parent] or nil
    end
    return reverseList(path)
end

local function heapLess(a, b)
    if a.priority == b.priority then
        if a.distance == b.distance then
            return a.sequence < b.sequence
        end
        return a.distance < b.distance
    end
    return a.priority < b.priority
end

local function heapPush(heap, item)
    heap[#heap + 1] = item
    local index = #heap
    while index > 1 do
        local parent = math.floor(index / 2)
        if not heapLess(heap[index], heap[parent]) then
            break
        end
        heap[index], heap[parent] = heap[parent], heap[index]
        index = parent
    end
end

local function heapPop(heap)
    local root = heap[1]
    local last = table.remove(heap)
    if #heap > 0 then
        heap[1] = last
        local index = 1
        while true do
            local left = index * 2
            local right = left + 1
            local smallest = index
            if left <= #heap and heapLess(heap[left], heap[smallest]) then
                smallest = left
            end
            if right <= #heap and heapLess(heap[right], heap[smallest]) then
                smallest = right
            end
            if smallest == index then
                break
            end
            heap[index], heap[smallest] = heap[smallest], heap[index]
            index = smallest
        end
    end
    return root
end

local function labelForVerb(verb)
    local words = {}
    for part in tostring(verb or ""):gmatch("[^_]+") do
        words[#words + 1] = part:sub(1, 1):upper() .. part:sub(2)
    end
    return table.concat(words, " ")
end

local function boardActionsForUnit(unit)
    return (unit and sliceBoardActions[unit.class]) or (unit and unit.boardVerbs) or {}
end

local function directionBetween(fromX, fromY, toX, toY)
    local dx = toX - fromX
    local dy = toY - fromY
    if math.abs(dx) >= math.abs(dy) and dx ~= 0 then
        return dx > 0 and "east" or "west"
    end
    if dy ~= 0 then
        return dy > 0 and "south" or "north"
    end
    return "east"
end

local function straightLineDirection(fromX, fromY, toX, toY)
    if fromY == toY and fromX ~= toX then
        return toX > fromX and "east" or "west", math.abs(toX - fromX)
    end
    if fromX == toX and fromY ~= toY then
        return toY > fromY and "south" or "north", math.abs(toY - fromY)
    end
    return nil, 0
end

local function classLoadoutPayload(classId, loadoutIds)
    local class = ClassCatalog.class(classId)
    local loadouts = {}
    local tools = {}
    local selectedLoadouts = {}
    for _, loadoutId in ipairs(loadoutIds or {}) do
        local loadout = ClassCatalog.loadout(classId, loadoutId)
        if not loadout then
            error("unknown tactical loadout " .. tostring(classId) .. "." .. tostring(loadoutId), 2)
        end
        selectedLoadouts[#selectedLoadouts + 1] = loadout
    end
    if #selectedLoadouts == 0 then
        for index, loadout in ipairs(ClassCatalog.loadouts(classId)) do
            if index > (ClassCatalog.loadoutSlots(classId) or 2) then
                break
            end
            selectedLoadouts[#selectedLoadouts + 1] = loadout
        end
    end
    for _, loadout in ipairs(selectedLoadouts) do
        loadouts[#loadouts + 1] = { id = loadout.id, boardVerb = loadout.boardVerb, tools = copyList(loadout.tools) }
        for _, tool in ipairs(loadout.tools or {}) do
            tools[#tools + 1] = tool
        end
    end
    return class, loadouts, ClassCatalog.boardVerbs(classId), tools
end

local function addDeploymentCandidate(result, used, spec, x, y)
    if not (spec and spec.board and x and y and x >= 1 and y >= 1 and x <= spec.board.width and y <= spec.board.height) then
        return
    end
    local key = tileKey(x, y)
    local tile = (spec.board.tiles or {})[key] or {}
    if used[key] or tile.blocker then
        return
    end
    used[key] = true
    result[#result + 1] = { x = x, y = y }
end

local function deploymentTiles(spec, count)
    local result = {}
    local used = {}
    for _, unit in ipairs(spec.units or {}) do
        if unit.side ~= "player" then
            used[tileKey(unit.x, unit.y)] = true
        end
    end
    for _, pocket in ipairs((((spec.grammar or {}).components or {}).spawnPockets) or {}) do
        if pocket.side == "player" then
            for _, tile in ipairs(pocket.tiles or {}) do
                addDeploymentCandidate(result, used, spec, tile.x, tile.y)
            end
            local lead = pocket.tiles and pocket.tiles[1]
            if lead then
                used[tileKey(lead.x + 1, lead.y)] = true
                used[tileKey(lead.x, lead.y - 1)] = true
                used[tileKey(lead.x + 1, lead.y - 1)] = true
            end
        end
    end
    for x = 1, math.min(3, spec.board.width) do
        for y = 1, spec.board.height do
            addDeploymentCandidate(result, used, spec, x, y)
        end
    end
    for x = 1, spec.board.width do
        for y = 1, spec.board.height do
            addDeploymentCandidate(result, used, spec, x, y)
        end
    end
    if #result < count then
        error("not enough deployment tiles for live tactical squad", 2)
    end
    return result
end

local function normalizeSquadLoadout(loadout)
    local source = loadout and (loadout.units or loadout) or liveClassRoster
    local allowDuplicateClasses = loadout and loadout.allowDuplicateClasses == true
    local roster = {}
    local seenClasses = {}
    for index, entry in ipairs(source or {}) do
        local classId = entry.classId
        if not ClassCatalog.class(classId) then
            error("unknown tactical class " .. tostring(classId), 2)
        end
        if not allowDuplicateClasses and seenClasses[classId] then
            error("duplicate tactical class " .. tostring(classId), 2)
        end
        seenClasses[classId] = true
        roster[#roster + 1] = {
            id = entry.id or (classId .. "_" .. tostring(index)),
            classId = classId,
            hp = entry.hp or 4,
            loadoutIds = copyList(entry.loadoutIds),
        }
    end
    return roster
end

local function applyLiveClassSquad(spec, squadLoadout)
    local roster = normalizeSquadLoadout(squadLoadout)
    local deployments = deploymentTiles(spec, #roster)
    local unitAp = TacticsAP.defaultUnitApForSquad(#roster)
    local units = {}
    for index, entry in ipairs(roster) do
        local class, loadouts, boardVerbs, tools = classLoadoutPayload(entry.classId, entry.loadoutIds)
        local maxAp = entry.maxAp or entry.apMax or entry.ap or unitAp
        units[#units + 1] = {
            id = entry.id,
            name = class and class.name or entry.id,
            side = "player",
            class = entry.classId,
            className = class and class.name or entry.classId,
            x = deployments[index].x,
            y = deployments[index].y,
            hp = entry.hp,
            ap = entry.ap or maxAp,
            maxAp = maxAp,
            loadouts = loadouts,
            boardVerbs = boardVerbs,
            tools = tools,
            catalogBoardVerbs = ClassCatalog.boardVerbs(entry.classId),
        }
    end
    for _, unit in ipairs(spec.units or {}) do
        if unit.side ~= "player" then
            units[#units + 1] = unit
        end
    end
    spec.units = units
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function nearestPlayer(state, enemy)
    local best
    local bestDistance
    for _, unit in ipairs(state:unitsForSide("player")) do
        local distance = Grid.manhattan(enemy.x, enemy.y, unit.x, unit.y)
        if not bestDistance or distance < bestDistance then
            best = unit
            bestDistance = distance
        end
    end
    return best
end

local function activeObscurantAt(state, x, y)
    local tile = state:tileAt(x, y)
    return tile.hazard and tile.hazard.active and tile.hazard.losModifier == "obscure"
end

local function enemyCanSeeUnit(state, enemy, unit)
    if not (enemy and unit) then
        return false
    end
    if state:unitHiddenFromSide(unit, enemy.side or "enemy") then
        return false
    end
    if activeObscurantAt(state, unit.x, unit.y) then
        return false
    end
    local los = state:lineOfSight(enemy.x, enemy.y, unit.x, unit.y)
    return los.visible == true and los.obscured ~= true
end

local function nearestVisiblePlayer(state, enemy)
    local best
    local bestDistance
    for _, unit in ipairs(state:unitsForSide("player")) do
        if enemyCanSeeUnit(state, enemy, unit) then
            local distance = Grid.manhattan(enemy.x, enemy.y, unit.x, unit.y)
            if not bestDistance or distance < bestDistance then
                best = unit
                bestDistance = distance
            end
        end
    end
    return best
end

local function livingEnemies(state)
    local count = 0
    for _, unit in ipairs(state:unitsForSide("enemy")) do
        count = count + 1
    end
    return count
end

local function livingPlayers(state)
    local count = 0
    for _, unit in ipairs(state:unitsForSide("player")) do
        count = count + 1
    end
    return count
end

local function objectiveState(state)
    for _, id in ipairs(state.objectiveOrder or {}) do
        return state:objective(id)
    end
    return nil
end

local classVerbPreview

local function stateRevision(state, kind)
    return state and state.revision and state:revision(kind) or (state and state.tick) or 0
end

local function cache(runtime)
    runtime.cache = runtime.cache or {}
    return runtime.cache
end

local function cachedMovementPreview(runtime, unitId, options)
    if options then
        return runtime.state:movementPreview(unitId, options)
    end
    local state = runtime.state
    local unit = state:unit(unitId)
    if not unit then
        return state:movementPreview(unitId)
    end
    local c = cache(runtime)
    c.movement = c.movement or {}
    local key = table.concat({
        tostring(stateRevision(state, "units")),
        tostring(stateRevision(state, "terrain")),
        unitId,
        tostring(unit.x),
        tostring(unit.y),
        tostring(unit.ap or 0),
    }, ":")
    if c.movement[unitId] and c.movement[unitId].key == key then
        return c.movement[unitId].preview
    end
    local preview = state:movementPreview(unitId)
    c.movement[unitId] = { key = key, preview = preview }
    return preview
end

local function cachedClassVerbPreview(runtime, selected, verb)
    if not (selected and verb) then
        return nil
    end
    local state = runtime.state
    local c = cache(runtime)
    c.classPreview = c.classPreview or {}
    local key = table.concat({
        tostring(stateRevision(state, "world")),
        selected.id,
        tostring(selected.x),
        tostring(selected.y),
        tostring(selected.ap or 0),
        tostring(runtime.cursor.x),
        tostring(runtime.cursor.y),
        verb,
    }, ":")
    if c.classPreview[key] then
        return c.classPreview[key]
    end
    local preview = classVerbPreview(runtime, selected, verb)
    c.classPreview[key] = preview
    return preview
end

local function plannedEnemyTarget(runtime, enemy, options)
    local state = runtime.state
    local objective = objectiveState(state)
    local spec = enemyIntentSpecs[enemy.id] or enemyIntentSpecs[enemy.kind] or {}
    local intent = enemy.intent or {}
    local intentType = intent.intentType or enemy.intentType
    local targetRule = intent.target or spec.target
    local exactStatusIntent = (intent.category == "buff" or intent.category == "debuff" or intent.category == "repair") and intent.aiCanReposition ~= true
    local supportIntent = targetRule == "self" or exactStatusIntent
    if objective and (objective.integrity or 0) <= 1 and not supportIntent then
        return applyIntentMetadata({
            target = objective,
            category = "destroy",
            damage = intent.damage or spec.damage or 1,
            intentType = intentType,
            label = "finish notice",
            counterplay = { "block objective", "kill source", "repair objective" },
        }, intent)
    end
    if (enemy.hp or 0) <= 1 then
        local plan = applyIntentMetadata({
            target = { id = enemy.id, x = enemy.x, y = enemy.y },
            category = "guard",
            damage = 0,
            intentType = intentType,
            label = "regroup notice",
            counterplay = { "press wounded enemy", "ignore harmless guard", "contest tile" },
        }, intent)
        if not supportIntent then
            plan.statusEffect = nil
        end
        return plan
    end
    local aiPlan = (not supportIntent and not (options and options.visibleTargetsOnly)) and EnemyAI.planEnemy(state, enemy, { doctrine = options and options.doctrine, memory = runtime.aiMemory, objective = objective, maxMoveAp = 2, attackRange = 3 }) or nil
    if aiPlan and aiPlan.target then
        return applyIntentMetadata({
            target = aiPlan.target,
            category = aiPlan.category,
            damage = aiPlan.damage or intent.damage or spec.damage or 1,
            intentType = intentType or aiPlan.tactic,
            label = intentType or aiPlan.label,
            counterplay = intent.counterplay or { "move target", "raise cover", "break line" },
            targetTiles = { { x = aiPlan.target.x, y = aiPlan.target.y } },
            destination = aiPlan.destination,
            path = aiPlan.path,
            tactic = aiPlan.tactic,
            aiDebug = runtime.aiDebug and aiPlan.debug or nil,
        }, intent)
    end
    local target
    if targetRule == "self" then
        target = enemy
    elseif targetRule == "objective" or targetRule == "claim_tile" or targetRule == "seal" or targetRule == "drawer" then
        target = objective
    elseif options and options.visibleTargetsOnly then
        target = nearestVisiblePlayer(state, enemy)
    else
        target = nearestPlayer(state, enemy)
    end
    if not target then
        return nil
    end
    return applyIntentMetadata({
        target = target,
        category = intent.category or "attack",
        damage = intent.damage or spec.damage or 1,
        intentType = intentType,
        label = intentType or spec.label or "posted notice",
        counterplay = intent.counterplay or { "move target", "kill source", "block tile" },
    }, intent)
end

function Runtime.syncWorld(sim, runtime)
    if not (sim and sim.world and runtime and runtime.state) then
        return
    end
    local tactics = runtime.state
    local focus = tactics:unit(runtime.selectedUnitId) or { x = runtime.cursor.x, y = runtime.cursor.y }
    sim.player.x = runtime.originX + focus.x
    sim.player.y = runtime.originY + focus.y
    sim.player.z = 0
    sim.mode = "tactical"
    sim.status = runtime.status or "tactical"
    sim.tick = tactics.tick
    local revision = stateRevision(tactics, "world")
    if runtime.syncedWorldRevision == revision then
        return
    end
    runtime.worldRevision = (runtime.worldRevision or 0) + 1
    for x = 0, tactics.board.width + 1 do
        for y = 0, tactics.board.height + 1 do
            local worldX = runtime.originX + x
            local worldY = runtime.originY + y
            local tileId = "archive_wall"
            if x >= 1 and x <= tactics.board.width and y >= 1 and y <= tactics.board.height then
                local tile = tactics:tileAt(x, y)
                tileId = "archive_floor"
                if tile.destroyed then
                    tileId = "archive_floor"
                elseif tile.blocker then
                    tileId = "archive_monolith"
                elseif tile.hazard and tile.hazard.kind then
                    tileId = "false_index"
                end
                local objective = objectiveState(tactics)
                if objective and objective.x == x and objective.y == y then
                    tileId = "sealed_name"
                end
                sim.world:setTile(worldX, worldY, 0, {
                    id = tileId,
                    data = 0,
                    height = tile.height or 0,
                    blocker = tile.blocker,
                    losBlocker = tile.losBlocker,
                    destructibleHp = tile.destructibleHp,
                    destroyed = tile.destroyed,
                    kind = tile.kind,
                    material = tile.material,
                    terrainType = tile.terrainType,
                    blockerKind = tile.blockerKind,
                    coverEdges = copyValue(tile.coverEdges),
                    interact = copyValue(tile.interact),
                    tags = copyList(tile.tags),
                })
            else
                sim.world:setTile(worldX, worldY, 0, { id = tileId, data = 0, height = 0, blocker = true, losBlocker = true, kind = "boundary_wall", tags = { "boundary" } })
            end
        end
    end
    runtime.syncedWorldRevision = revision
end

local function declareEnemyIntent(runtime, enemy, options)
    local state = runtime.state
    local objective = objectiveState(state)
    local plan = plannedEnemyTarget(runtime, enemy, options)
    if not plan then
        return false
    end
    local target = plan.target
    state:declareIntent(enemy.id, {
        mode = plan.mode,
        intentType = plan.intentType,
        category = plan.category,
        source = enemy.id,
        sourceTile = { x = enemy.x, y = enemy.y },
        targetTiles = copyValue(plan.targetTiles) or { { x = target.x, y = target.y } },
        destination = copyValue(plan.destination),
        path = copyValue(plan.path),
        tactic = plan.tactic,
        target = target.id,
        damage = plan.damage,
        effect = plan.effect,
        statusEffect = plan.statusEffect,
        objectiveImpact = objective and target.id == objective.id and objective.id or nil,
        label = plan.label,
        counterplay = plan.counterplay,
        revealRotations = plan.revealRotations,
        revealActions = plan.revealActions,
        revealClasses = plan.revealClasses,
        mask = plan.mask,
        footprintHidden = plan.footprintHidden,
        weakPoint = plan.weakPoint,
        aiDebug = copyValue(plan.aiDebug),
        aiCanReposition = plan.aiCanReposition == true,
    })
    if runtime.aiDebug and plan.aiDebug then
        runtime.aiDebugPlans = runtime.aiDebugPlans or {}
        runtime.aiDebugPlans[enemy.id] = copyValue(plan.aiDebug)
    end
    return true
end

function Runtime.declareEnemyIntents(runtime)
    local state = runtime.state
    state.intents = {}
    runtime.aiDebugPlans = runtime.aiDebug and {} or nil
    runtime.aiDoctrine = EnemyAI.analyzeDoctrine(state, { objective = objectiveState(state) })
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        declareEnemyIntent(runtime, enemy, { doctrine = runtime.aiDoctrine })
    end
end

function Runtime.replanVisibleEnemyIntents(runtime, movedUnit)
    local state = runtime.state
    local count = 0
    local doctrine = EnemyAI.analyzeDoctrine(state, { objective = objectiveState(state) })
    runtime.aiDoctrine = doctrine
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        if enemyCanSeeUnit(state, enemy, movedUnit) and declareEnemyIntent(runtime, enemy, { visibleTargetsOnly = true, doctrine = doctrine }) then
            count = count + 1
        end
    end
    return count
end

local function makePrototypeState(options)
    return TacticsState.new({
        defaultAp = 3,
        board = {
            width = 8,
            height = 8,
            topology = options and options.topology,
            tiles = {
                ["3:4"] = { kind = "witness_desk", coverEdges = { north = "half", east = "full" } },
                ["5:4"] = { kind = "shelf_rank", blocker = true, losBlocker = true, height = 2 },
                ["6:5"] = { kind = "ink_spread", hazard = { kind = "ink_spread", damage = 1 } },
                ["4:6"] = { kind = "claim_bench", coverEdges = { west = "half", south = "half" } },
                ["7:2"] = { kind = "seal_pillar", blocker = true, losBlocker = true, height = 2 },
            },
        },
        units = {
            { id = "warden", side = "player", class = "warden", x = 2, y = 6, hp = 6, ap = 3, maxAp = 3 },
            { id = "lamplighter", side = "player", class = "lamplighter", x = 2, y = 7, hp = 4, ap = 3, maxAp = 3 },
            { id = "audit_hound", side = "enemy", x = 6, y = 3, hp = 3 },
            { id = "claim_lens", side = "enemy", x = 7, y = 6, hp = 2 },
        },
        objectives = {
            { id = "route_machine", kind = "protect_route_machine", x = 5, y = 6, integrity = 4, maxIntegrity = 4, evacuateAt = { x = 1, y = 8 } },
        },
    })
end

local function makeTutorialState(options)
    local spec = {
        defaultAp = 3,
        board = {
            width = 6,
            height = 6,
            topology = options and options.topology,
            tiles = {
                ["2:3"] = { kind = "archive_cover", coverEdges = { west = "half" }, tags = { "move_goal" } },
                ["3:3"] = { kind = "filing_lane", coverEdges = { east = "half" }, rotationMarks = { east = "sealed_intent" }, tags = { "rotate_read" } },
                ["4:3"] = { kind = "audit_line", tags = { "intent_lane" } },
                ["2:4"] = { kind = "lamp_tile", tags = { "overwatch_anchor" } },
            },
        },
        grammar = {
            components = {
                spawnPockets = {
                    { side = "player", tiles = { { x = 1, y = 3 } } },
                },
            },
        },
        units = {
            { id = "bailiff", side = "enemy", kind = "claimant", x = 5, y = 3, hp = 2, maxHp = 2, ap = 0, maxAp = 0, visionRadius = 4 },
        },
        objectives = {
            { id = "tutorial_exit", kind = "evacuate_board", x = 6, y = 3, integrity = 1, maxIntegrity = 1, minUnits = 1, evacuateAt = { x = 6, y = 3 } },
        },
        archiveRoute = {
            id = "tutorial_mission",
            variantId = "tutorial_onboarding",
            preview = "mission 0: one Warden learns movement, intent, and attack timing",
            tutorial = true,
            variantOrder = { "tutorial_onboarding" },
        },
        generator = { routeId = "tutorial_mission", variantId = "tutorial_onboarding", template = "tutorial" },
    }
    local loadout = options and options.squadLoadout or {
        missionId = "tutorial",
        units = {
            { id = "warden", classId = "warden", hp = 6, loadoutIds = { "line_guard", "claim_anchor" } },
        },
    }
    applyLiveClassSquad(spec, loadout)
    spec.bonusChallenges = { "no_damage", "no_cover_destroyed" } -- tutorial bonus picks
    return TacticsState.new(spec), spec
end

local function firstPlayerId(state)
    for _, unit in ipairs(state:unitsForSide("player")) do
        return unit.id
    end
    return nil
end

local function makeRouteState(options)
    local seed = options and options.seed
    local spec
    if options and options.variantId then
        spec = Procgen.generateArchiveRouteBoard(options.variantId, seed, { topology = options.topology })
    else
        spec = Procgen.generateArchiveExpanse(seed, { topology = options and options.topology })
    end
    applyLiveClassSquad(spec, options and options.squadLoadout)
    -- seed bonus challenges per route board; pick two distinct from pool deterministically
    local pool = { "no_damage", "fast_extract", "no_cover_destroyed", "no_deaths", "no_objective_loss", "no_overwatch" }
    local base = (tonumber(seed) or 1) % #pool
    local firstIdx = base + 1
    local secondIdx = ((base + 1 + math.floor((tonumber(seed) or 1) / #pool)) % #pool) + 1
    if secondIdx == firstIdx then secondIdx = (firstIdx % #pool) + 1 end -- deterministic distinct fallback
    spec.bonusChallenges = { pool[firstIdx], pool[secondIdx] }
    return TacticsState.new(spec), spec
end

local function routeVariantIndex(order, variantId)
    for index, id in ipairs(order or {}) do
        if id == variantId then
            return index
        end
    end
    return 1
end

local function activeRegionForVariant(runtime, variantId)
    for _, region in ipairs((((runtime.boardSpec or {}).archiveRoute or {}).regions) or {}) do
        if region.id == variantId then
            return region
        end
    end
    return nil
end

local function setActiveRouteRegion(runtime, variantId)
    local region = activeRegionForVariant(runtime, variantId)
    if not region then
        return false
    end
    runtime.route.variantId = variantId
    runtime.routeIndex = routeVariantIndex(runtime.routeOrder, variantId)
    local objectiveSet = {}
    for _, objectiveId in ipairs(region.objectives or {}) do
        objectiveSet[objectiveId] = true
    end
    local reordered = {}
    for _, objectiveId in ipairs(region.objectives or {}) do
        if runtime.state.objectives[objectiveId] then
            reordered[#reordered + 1] = objectiveId
        end
    end
    for _, objectiveId in ipairs(runtime.state.objectiveOrder or {}) do
        if not objectiveSet[objectiveId] then
            reordered[#reordered + 1] = objectiveId
        end
    end
    runtime.state.objectiveOrder = reordered
    local regionEnemySet = {}
    for _, enemyId in ipairs(region.enemies or {}) do
        regionEnemySet[enemyId] = true
    end
    for _, enemy in ipairs(runtime.state:unitsForSide("enemy")) do
        if not regionEnemySet[enemy.id] then
            enemy.alive = false
        end
    end
    for _, enemyId in ipairs(region.enemies or {}) do
        local enemy = runtime.state:unit(enemyId)
        if enemy then
            enemy.alive = true
            enemy.evacuated = false
            enemy.hp = math.max(enemy.hp or 0, enemy.maxHp or enemy.hp or 1)
        end
    end
    local variant = Procgen.archiveRouteVariant(variantId)
    runtime.message = variant and variant.preview or runtime.message
    runtime.status = "route " .. tostring(variantId)
    if runtime.state.bumpRevision then
        runtime.state:bumpRevision("units")
    end
    Runtime.declareEnemyIntents(runtime)
    Runtime.refreshOverlays(runtime)
    runtime.syncedWorldRevision = nil
    Runtime.syncWorld(runtime.sim, runtime)
    return true
end

function Runtime.new(sim, options)
    options = options or {}
    local state, boardSpec
    local route = Procgen.archiveRoute()
    local tutorial = options.tutorial == true or ((options.squadLoadout or {}).missionId == "tutorial")
    if options.prototype then
        state = makePrototypeState(options)
    elseif tutorial then
        state, boardSpec = makeTutorialState(options)
    else
        state, boardSpec = makeRouteState(options)
    end
    local routeOrder = nil
    if boardSpec and boardSpec.archiveRoute then
        routeOrder = boardSpec.archiveRoute.variantOrder and copyList(boardSpec.archiveRoute.variantOrder) or copyList(route.variantOrder)
    end
    local selectedUnitId = state.selectedUnitId or firstPlayerId(state)
    local selected = selectedUnitId and state:unit(selectedUnitId) or nil
    local runtime = {
        active = true,
        originX = originX,
        originY = originY,
        cursor = { x = selected and selected.x or 1, y = selected and selected.y or 1 },
        selectedUnitId = selectedUnitId,
        status = boardSpec and ("route " .. boardSpec.archiveRoute.variantId) or "tactical prototype",
        message = boardSpec and boardSpec.archiveRoute.preview or "read intents, spend AP, protect the route machine",
        turn = 1,
        sim = sim,
        squadLoadout = options.squadLoadout,
        aiDebug = options.aiDebug == true,
        aiDebugPlans = options.aiDebug == true and {} or nil,
        aiMemory = { units = {}, targets = {} },
        state = state,
        boardSpec = boardSpec,
        route = boardSpec and boardSpec.archiveRoute or nil,
        routeOrder = routeOrder,
        routeIndex = boardSpec and boardSpec.archiveRoute and routeVariantIndex(routeOrder, boardSpec.archiveRoute.variantId) or nil,
        summary = Runtime.summary,
        handleKey = Runtime.handleKey,
        setCursor = Runtime.setCursor,
        moveSelectedToCursor = Runtime.moveSelectedToCursor,
        handleMouseTile = Runtime.handleMouseTile,
        activateCursor = Runtime.activateCursor,
        inspectCursor = Runtime.inspectCursor,
        actionAtTile = Runtime.actionAtTile,
        actionBar = Runtime.actionBar,
        visibilityGrid = Runtime.visibilityGrid,
        enemyVisible = Runtime.enemyVisible,
        overwatchPreview = Runtime.overwatchPreview,
        setOverwatchPreview = Runtime.setOverwatchPreview,
        clearOverwatchPreview = Runtime.clearOverwatchPreview,
        setAiDebug = Runtime.setAiDebug,
        toggleAiDebug = Runtime.toggleAiDebug,
        setTopology = Runtime.setTopology,
        cycleTopology = Runtime.cycleTopology,
        partyPathTo = Runtime.partyPathTo,
        movePartyTo = Runtime.movePartyTo,
        drainHitEvents = Runtime.drainHitEvents,
        hitEvents = {},
        cache = {},
        worldRevision = 0,
        topology = state.board.topology or "square",
        partyMovementEnabled = options.partyMovement == true,
        explorationMode = options.exploration == true,
    }
    Runtime.declareEnemyIntents(runtime)
    Runtime.refreshOverlays(runtime)
    Runtime.syncWorld(sim, runtime)
    return runtime
end

function Runtime.loadRouteVariant(runtime, variantId)
    if runtime.boardSpec and runtime.boardSpec.archiveRoute and runtime.boardSpec.archiveRoute.expanse then
        return setActiveRouteRegion(runtime, variantId) and runtime or nil
    end
    local state, boardSpec = makeRouteState({ variantId = variantId, squadLoadout = runtime.squadLoadout, topology = runtime.topology })
    local selectedUnitId = state.selectedUnitId or firstPlayerId(state)
    local selected = selectedUnitId and state:unit(selectedUnitId) or nil
    runtime.state = state
    runtime.boardSpec = boardSpec
    runtime.route = boardSpec.archiveRoute
    runtime.routeIndex = routeVariantIndex(runtime.routeOrder, variantId)
    runtime.selectedUnitId = selectedUnitId
    runtime.cursor.x = selected and selected.x or 1
    runtime.cursor.y = selected and selected.y or 1
    runtime.turn = 1
    runtime.complete = false
    runtime.failed = false
    runtime.routeComplete = false
    runtime.status = "route " .. tostring(variantId)
    runtime.message = boardSpec.archiveRoute.preview
    Runtime.declareEnemyIntents(runtime)
    Runtime.refreshOverlays(runtime)
    runtime.syncedWorldRevision = nil
    Runtime.syncWorld(runtime.sim, runtime)
    return runtime
end

local setStatus

function Runtime.setTopology(runtime, topology)
    topology = topology or "square"
    local currentVariant = runtime.route and runtime.route.variantId
    local state, boardSpec
    if runtime.boardSpec and runtime.boardSpec.archiveRoute and runtime.boardSpec.archiveRoute.tutorial then
        state, boardSpec = makeTutorialState({ squadLoadout = runtime.squadLoadout, topology = topology })
    elseif runtime.boardSpec and runtime.boardSpec.archiveRoute then
        state, boardSpec = makeRouteState({ variantId = not runtime.boardSpec.archiveRoute.expanse and currentVariant or nil, squadLoadout = runtime.squadLoadout, topology = topology })
    else
        state = makePrototypeState({ topology = topology })
    end
    runtime.state = state
    runtime.boardSpec = boardSpec
    runtime.topology = state.board.topology or topology
    runtime.route = boardSpec and boardSpec.archiveRoute or runtime.route
    runtime.routeOrder = boardSpec and boardSpec.archiveRoute and boardSpec.archiveRoute.variantOrder and copyList(boardSpec.archiveRoute.variantOrder) or runtime.routeOrder
    runtime.routeIndex = currentVariant and routeVariantIndex(runtime.routeOrder, currentVariant) or runtime.routeIndex
    local selectedUnitId = state.selectedUnitId or firstPlayerId(state)
    local selected = selectedUnitId and state:unit(selectedUnitId) or nil
    runtime.selectedUnitId = selectedUnitId
    runtime.cursor.x = selected and selected.x or 1
    runtime.cursor.y = selected and selected.y or 1
    if boardSpec and boardSpec.archiveRoute and boardSpec.archiveRoute.expanse and currentVariant then
        setActiveRouteRegion(runtime, currentVariant)
    end
    Runtime.declareEnemyIntents(runtime)
    Runtime.refreshOverlays(runtime)
    runtime.syncedWorldRevision = nil
    Runtime.syncWorld(runtime.sim, runtime)
    setStatus(runtime, "topology " .. tostring(runtime.topology))
    return runtime
end

function Runtime.cycleTopology(runtime, delta)
    local order = { "triangle", "square", "hex" }
    delta = delta or 1
    local current = runtime and runtime.topology or "square"
    for index, topology in ipairs(order) do
        if topology == current then
            local nextIndex = ((index - 1 + delta) % #order) + 1
            return Runtime.setTopology(runtime, order[nextIndex])
        end
    end
    return Runtime.setTopology(runtime, "triangle")
end

local function partyUnits(runtime)
    return runtime.state:unitsForSide("player")
end

local function canPartyEnter(state, x, y)
    if not state:inBounds(x, y) then
        return false
    end
    local tile = state:tileAt(x, y)
    if tile.blocker then
        return false
    end
    local unit = state:unitAt(x, y)
    return not (unit and unit.side == "enemy")
end

function Runtime.partyPathTo(runtime, targetX, targetY)
    local units = partyUnits(runtime)
    local lead = units[1]
    if not lead then
        return nil, "no party"
    end
    if not runtime.state:inBounds(targetX, targetY) then
        return nil, "target out of bounds"
    end
    local startKey = tileKey(lead.x, lead.y)
    local targetKey = tileKey(targetX, targetY)
    local nodes = { { x = lead.x, y = lead.y, depth = 1, cost = 0 } }
    local open = {}
    local seen = { [startKey] = 0 }
    local closed = {}
    local best = nodes[1]
    local bestDistance = runtime.state:distance(lead.x, lead.y, targetX, targetY)
    local sequence = 1
    heapPush(open, { node = 1, priority = bestDistance, distance = bestDistance, sequence = sequence })
    while #open > 0 do
        local item = heapPop(open)
        local nodeIndex = item.node
        local node = nodes[nodeIndex]
        local nodeKey = tileKey(node.x, node.y)
        if closed[nodeKey] then
            goto continue
        end
        closed[nodeKey] = true
        local distance = runtime.state:distance(node.x, node.y, targetX, targetY)
        if distance < bestDistance or (distance == bestDistance and (node.depth or 1) > (best.depth or 1)) then
            best = node
            bestDistance = distance
        end
        if tileKey(node.x, node.y) == targetKey then
            return partyPath(nodes, node), "exact"
        end
        for _, neighbor in ipairs(runtime.state:neighbors(node.x, node.y)) do
            local key = tileKey(neighbor.x, neighbor.y)
            local nextCost = (node.cost or 0) + 1
            if (seen[key] == nil or nextCost < seen[key]) and canPartyEnter(runtime.state, neighbor.x, neighbor.y) then
                seen[key] = nextCost
                local nextDistance = runtime.state:distance(neighbor.x, neighbor.y, targetX, targetY)
                nodes[#nodes + 1] = { x = neighbor.x, y = neighbor.y, parent = nodeIndex, depth = (node.depth or 1) + 1, cost = nextCost }
                sequence = sequence + 1
                heapPush(open, { node = #nodes, priority = nextCost + nextDistance, distance = nextDistance, sequence = sequence })
            end
        end
        ::continue::
    end
    if best and (best.depth or 1) > 1 then
        return partyPath(nodes, best), "partial"
    end
    return nil, "unreachable"
end

function Runtime.explorationCombatContact(runtime)
    for _, enemy in ipairs(runtime.state:unitsForSide("enemy")) do
        for _, unit in ipairs(runtime.state:unitsForSide("player")) do
            local los = runtime.state:lineOfSight(unit.x, unit.y, enemy.x, enemy.y)
            if los.visible and los.obscured ~= true then
                return true, enemy.id
            end
        end
    end
    return false
end

function Runtime.movePartyTo(runtime, targetX, targetY)
    if not runtime.partyMovementEnabled then
        return false, "party movement disabled"
    end
    local path, kind = Runtime.partyPathTo(runtime, targetX, targetY)
    if not path then
        setStatus(runtime, kind or "no route")
        return false
    end
    local units = partyUnits(runtime)
    for step = 2, #path do
        local previous = {}
        for index, unit in ipairs(units) do
            previous[index] = { x = unit.x, y = unit.y }
        end
        runtime.state:moveUnitTo(units[1], path[step].x, path[step].y)
        for index = 2, #units do
            runtime.state:moveUnitTo(units[index], previous[index - 1].x, previous[index - 1].y)
        end
    end
    runtime.cursor.x = path[#path].x
    runtime.cursor.y = path[#path].y
    if runtime.state.bumpRevision then
        runtime.state:bumpRevision("units")
    end
    local contact, enemyId = Runtime.explorationCombatContact(runtime)
    if contact then
        runtime.explorationMode = false
        Runtime.declareEnemyIntents(runtime)
        setStatus(runtime, "combat contact " .. tostring(enemyId))
    else
        setStatus(runtime, kind == "partial" and "party moved as far as possible" or "party moved")
    end
    Runtime.refreshOverlays(runtime)
    return true
end

function Runtime.selectedUnit(runtime)
    return runtime and runtime.state:unit(runtime.selectedUnitId) or nil
end

function Runtime.updateEnemySightings(runtime, visibility)
    if not (runtime and runtime.state and visibility) then
        return {}
    end
    runtime.lastSeenEnemies = runtime.lastSeenEnemies or {}
    local live = {}
    for _, enemy in ipairs(runtime.state:unitsForSide("enemy")) do
        live[enemy.id] = true
        if visibility.visible[tileKey(enemy.x, enemy.y)] then
            runtime.lastSeenEnemies[enemy.id] = {
                id = enemy.id,
                kind = enemy.kind,
                hp = enemy.hp,
                x = enemy.x,
                y = enemy.y,
                turn = runtime.turn or 1,
                tick = runtime.state.tick,
            }
        end
    end
    for id in pairs(runtime.lastSeenEnemies) do
        if not live[id] then
            runtime.lastSeenEnemies[id] = nil
        end
    end
    return runtime.lastSeenEnemies
end

function Runtime.visibilityGrid(runtime)
    local c = cache(runtime)
    local key = tostring(stateRevision(runtime.state, "vision")) .. ":player"
    if c.visibility and c.visibility.key == key then
        return c.visibility.value
    end
    local visibility = runtime.state:fogGrid("player")
    c.visibility = { key = key, value = visibility }
    runtime.fog = visibility
    Runtime.updateEnemySightings(runtime, visibility)
    return visibility
end

function Runtime.enemyVisible(runtime, enemy, visibility)
    if not (runtime and runtime.state) then
        return false
    end
    if type(enemy) ~= "table" then
        enemy = runtime.state:unit(enemy)
    end
    if not enemy then
        return false
    end
    visibility = visibility or Runtime.visibilityGrid(runtime)
    return visibility.visible[tileKey(enemy.x, enemy.y)] == true
end

local function revealVisibleEnemyIntents(runtime, visibility)
    local state = runtime.state
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        local intent = state.intents[enemy.id]
        if intent and intent.mode ~= "hiddenFootprint" and visibility.visible[tileKey(enemy.x, enemy.y)] == true then
            intent.revealed = true
        end
    end
end

local function reachableByKey(preview)
    local result = {}
    for _, tile in ipairs((preview and preview.reachable) or {}) do
        result[tostring(tile.x) .. ":" .. tostring(tile.y)] = tile
    end
    return result
end

local function wardenCommand(runtime, selected, verb)
    local state = runtime.state
    if verb == "line_guard" then
        local direction = directionBetween(selected.x, selected.y, runtime.cursor.x, runtime.cursor.y)
        return { type = "overwatch", unit = selected.id, shape = "line", direction = direction, length = 3, damage = 1, limit = 1, cost = 1, triggerPhase = "enemy", label = "line_guard", reaction = { kind = "shoot", damage = 1 } }
    end
    if verb == "brace" then
        return TacticsState.commands.status(selected.id, selected.id, "braced", 1, 1, 1)
    end
    if verb == "shove" then
        local target = state:unitAt(runtime.cursor.x, runtime.cursor.y)
        if not (target and target.id ~= selected.id and Grid.manhattan(selected.x, selected.y, target.x, target.y) == 1) then
            return nil, "shove needs adjacent target"
        end
        return TacticsState.commands.shove(selected.id, target.id, directionBetween(selected.x, selected.y, target.x, target.y), 1, 1, 1)
    end
    return nil, "unknown Warden verb"
end

local function wardenPreview(runtime, selected, verb)
    local command, err = wardenCommand(runtime, selected, verb)
    if not command then
        return { error = err }
    end
    if verb == "line_guard" then
        return { apCost = 1, affectedTiles = runtime.state:threatZoneTiles(selected.id, "line", { direction = command.direction, length = command.length }) }
    end
    if verb == "brace" then
        return { apCost = 1, status = "braced", target = selected.id }
    end
    return TacticsResolution.actionPreview(runtime.state, command)
end

local function appendTiles(target, source)
    for _, tile in ipairs(source or {}) do
        target[#target + 1] = { x = tile.x, y = tile.y, label = tile.label }
    end
end

local function appendPreviewList(target, source)
    for _, entry in ipairs(source or {}) do
        target[#target + 1] = entry
    end
end

local function previewCommandSequence(state, commands)
    local preview = { apCost = 0, affectedTiles = {}, pushedPath = {}, objectiveDamage = {}, coverBreak = {}, hazardChain = {}, obscurants = {} }
    local sim = TacticsState.fromSnapshot(state:snapshot())
    for _, command in ipairs(commands or {}) do
        local ok, commandPreview = pcall(TacticsResolution.actionPreview, sim, command)
        if not ok then
            return { error = tostring(commandPreview):gsub("^.*:%d+: ", "") }
        end
        if commandPreview.error then
            return { error = commandPreview.error }
        end
        preview.apCost = preview.apCost + (commandPreview.apCost or command.cost or command.amount or 0)
        appendTiles(preview.affectedTiles, commandPreview.affectedTiles)
        appendTiles(preview.pushedPath, commandPreview.pushedPath)
        appendPreviewList(preview.objectiveDamage, commandPreview.objectiveDamage)
        appendPreviewList(preview.coverBreak, commandPreview.coverBreak)
        appendPreviewList(preview.hazardChain, commandPreview.hazardChain)
        preview.dashPath = commandPreview.dashPath or preview.dashPath
        preview.swap = commandPreview.swap or preview.swap
        preview.healing = commandPreview.healing or preview.healing
        preview.objectiveRepair = commandPreview.objectiveRepair or preview.objectiveRepair
        preview.objectiveExtract = commandPreview.objectiveExtract or preview.objectiveExtract
        preview.cargo = commandPreview.cargo or preview.cargo
        preview.status = commandPreview.status or preview.status
        preview.reveal = commandPreview.reveal or preview.reveal
        preview.intentInterrupt = commandPreview.intentInterrupt or preview.intentInterrupt
        preview.intentReduction = commandPreview.intentReduction or preview.intentReduction
        preview.overwatch = commandPreview.overwatch or preview.overwatch
        if commandPreview.obscurant then
            preview.obscurants[#preview.obscurants + 1] = commandPreview.obscurant
        end
        if commandPreview.damage then
            preview.damage = (preview.damage or 0) + commandPreview.damage
            preview.flanked = commandPreview.flanked
            preview.flankingBonus = commandPreview.flankingBonus
        end
        ok, commandPreview = pcall(function()
            sim:apply(command)
        end)
        if not ok then
            return { error = tostring(commandPreview):gsub("^.*:%d+: ", "") }
        end
    end
    return preview
end

local function areaTiles(state, cx, cy)
    local tiles = {}
    local offsets = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
    for _, offset in ipairs(offsets) do
        local x = cx + offset[1]
        local y = cy + offset[2]
        if state:inBounds(x, y) then
            tiles[#tiles + 1] = { x = x, y = y }
        end
    end
    return tiles
end

local function movementDestination(state, selected, x, y, options)
    return reachableByKey(state:movementPreview(selected.id, options))[tostring(x) .. ":" .. tostring(y)]
end

local function movementCommands(unitId, path, cost)
    local commands = {}
    for index, direction in ipairs(path or {}) do
        commands[#commands + 1] = TacticsState.commands.move(unitId, direction, index == 1 and cost or 0)
    end
    return commands
end

local function cursorUnit(runtime)
    return runtime.state:unitAt(runtime.cursor.x, runtime.cursor.y)
end

local function visibleCursorTarget(runtime, selected)
    local target = cursorUnit(runtime)
    if not (target and target.id ~= selected.id) then
        return nil, "needs cursor target"
    end
    if target.side == "enemy" and not Runtime.enemyVisible(runtime, target) then
        return nil, "target hidden"
    end
    return target
end

local function duelistCommands(runtime, selected, verb)
    if verb == "red_line" then
        local direction, distance = straightLineDirection(selected.x, selected.y, runtime.cursor.x, runtime.cursor.y)
        if not direction or distance < 1 or distance > 2 then
            return nil, "red_line needs 1-2 tile line"
        end
        return { TacticsState.commands.dash(selected.id, direction, distance, 1) }
    end
    if verb == "dash_strike" then
        local target, err = visibleCursorTarget(runtime, selected)
        if not target then
            return nil, err
        end
        if target.side ~= "enemy" then
            return nil, "dash_strike needs enemy"
        end
        local direction, distance = straightLineDirection(selected.x, selected.y, target.x, target.y)
        if not direction then
            return nil, "dash_strike needs straight target"
        end
        local dashDistance = math.min(2, distance - 1)
        if dashDistance < 1 then
            return nil, "dash_strike needs dash lane"
        end
        if distance - dashDistance > 3 then
            return nil, "dash_strike target outside range"
        end
        return {
            TacticsState.commands.dash(selected.id, direction, dashDistance, 1),
            TacticsState.commands.attack(selected.id, target.id, 2, 1),
        }
    end
    if verb == "position_swap" then
        local target, err = visibleCursorTarget(runtime, selected)
        if not target then
            return nil, err
        end
        if Grid.manhattan(selected.x, selected.y, target.x, target.y) ~= 1 then
            return nil, "position_swap needs adjacent target"
        end
        return { TacticsState.commands.swap(selected.id, target.id, 1) }
    end
    return nil, "unknown Duelist verb"
end

local function duelistPreview(runtime, selected, verb)
    local commands, err = duelistCommands(runtime, selected, verb)
    if not commands then
        return { error = err }
    end
    return previewCommandSequence(runtime.state, commands)
end

local function menderCommands(runtime, selected, verb)
    local state = runtime.state
    local target = cursorUnit(runtime)
    local objective = state:objectiveAt(runtime.cursor.x, runtime.cursor.y)
    local distance = Grid.manhattan(selected.x, selected.y, runtime.cursor.x, runtime.cursor.y)
    if verb == "field_triage" then
        if target and target.side == "player" and distance <= 1 then
            return {
                TacticsState.commands.heal(selected.id, target.id, 2, 1),
                TacticsState.commands.status(selected.id, target.id, "stabilized", 2, 1, 0),
            }
        end
        if objective and distance <= 1 then
            return { TacticsState.commands.repairObjective(selected.id, objective.id, 2, 1) }
        end
        return nil, "field_triage needs adjacent ally or objective"
    end
    if verb == "stabilize" then
        if target and target.side == "player" and distance <= 3 then
            return { TacticsState.commands.status(selected.id, target.id, "stabilized", 2, 1, 1) }
        end
        if objective and distance <= 3 then
            return { TacticsState.commands.repairObjective(selected.id, objective.id, 1, 1) }
        end
        return nil, "stabilize needs ally or objective"
    end
    if verb == "smoke_binder" then
        if distance > 3 then
            return nil, "smoke_binder range 3"
        end
        local commands = {}
        for index, tile in ipairs(areaTiles(state, runtime.cursor.x, runtime.cursor.y)) do
            commands[#commands + 1] = TacticsState.commands.obscurant(selected.id, tile.x, tile.y, "smoke", 2, index == 1 and 1 or 0)
        end
        return commands
    end
    return nil, "unknown Apothecary verb"
end

local function menderPreview(runtime, selected, verb)
    local commands, err = menderCommands(runtime, selected, verb)
    if not commands then
        return { error = err }
    end
    return previewCommandSequence(runtime.state, commands)
end

local function extractionObjectiveAt(state, x, y)
    local objective = state:objectiveAt(x, y)
    if objective then
        return objective
    end
    for _, id in ipairs(state.objectiveOrder or {}) do
        objective = state:objective(id)
        if objective and objective.evacuateAt and objective.evacuateAt.x == x and objective.evacuateAt.y == y then
            return objective
        end
    end
    return nil
end

local function harrierCommands(runtime, selected, verb)
    local state = runtime.state
    if verb == "ghost_route" then
        local destination = movementDestination(state, selected, runtime.cursor.x, runtime.cursor.y, { maxCost = 3 })
        if not destination or #(destination.path or {}) == 0 then
            return nil, "ghost_route needs reachable lane"
        end
        local commands = { TacticsState.commands.status(selected.id, selected.id, "ghosted", 2, 1, 1) }
        for _, command in ipairs(movementCommands(selected.id, destination.path, 0)) do
            commands[#commands + 1] = command
        end
        return commands
    end
    if verb == "courier_cut" then
        if selected.carryingCargo then
            local objective = extractionObjectiveAt(state, selected.x, selected.y) or extractionObjectiveAt(state, runtime.cursor.x, runtime.cursor.y)
            if not objective then
                return nil, "courier_cut needs extraction tile"
            end
            return { TacticsState.commands.extractCargo(selected.id, objective.id, 1) }
        end
        local cargo = state:cargoAt(runtime.cursor.x, runtime.cursor.y) or state:cargoAt(selected.x, selected.y)
        if not cargo then
            return nil, "courier_cut needs cargo"
        end
        if Grid.manhattan(selected.x, selected.y, cargo.x, cargo.y) > 1 then
            return nil, "courier_cut cargo adjacent"
        end
        return { TacticsState.commands.carryCargo(selected.id, cargo.id, 1) }
    end
    return nil, "unknown Thief verb"
end

local function harrierPreview(runtime, selected, verb)
    local commands, err = harrierCommands(runtime, selected, verb)
    if not commands then
        return { error = err }
    end
    return previewCommandSequence(runtime.state, commands)
end

local function arcanistCommands(runtime, selected, verb)
    local state = runtime.state
    if verb == "seal_reader" then
        return { TacticsState.commands.classReveal(selected.id, { revealClass = "arcanist", revealAction = "seal_reader" }, 1) }
    end
    if verb == "line_bender" then
        local distance = Grid.manhattan(selected.x, selected.y, runtime.cursor.x, runtime.cursor.y)
        if distance > 4 then
            return nil, "line_bender range 4"
        end
        local tile = state:tileAt(runtime.cursor.x, runtime.cursor.y)
        if not tile.losBlocker then
            return nil, "line_bender needs LoS blocker"
        end
        return { TacticsState.commands.convertTile(selected.id, runtime.cursor.x, runtime.cursor.y, "bend_los", 1) }
    end
    if verb == "intent_breaker" then
        local target = cursorUnit(runtime)
        if not (target and target.side == "enemy") then
            return nil, "intent_breaker needs enemy"
        end
        if not state:intentPreview(target.id, { reveal = true }) then
            return nil, "intent_breaker needs intent"
        end
        if not Runtime.enemyVisible(runtime, target) then
            return nil, "intent_breaker target hidden"
        end
        return {
            TacticsState.commands.spend(selected.id, 1, "intent_breaker"),
            TacticsState.commands.interruptIntent(target.id, "losBreak"),
        }
    end
    return nil, "unknown Arcanist verb"
end

local function arcanistPreview(runtime, selected, verb)
    local commands, err = arcanistCommands(runtime, selected, verb)
    if not commands then
        return { error = err }
    end
    return previewCommandSequence(runtime.state, commands)
end

local function lamplighterCommands(runtime, selected, verb)
    local state = runtime.state
    if verb == "beacon_runner" then
        return { TacticsState.commands.classReveal(selected.id, { revealClass = "lamplighter", revealAction = "beacon_runner" }, 1) }
    end
    if verb == "cone_keeper" then
        local direction = directionBetween(selected.x, selected.y, runtime.cursor.x, runtime.cursor.y)
        return { { type = "overwatch", unit = selected.id, cone = true, facing = direction, range = 4, arc = 2, reaction = { kind = "mark", turns = 2, amount = 2 }, limit = 1, cost = 1, label = "cone_keeper" } }
    end
    if verb == "ash_lamp" then
        local target = cursorUnit(runtime)
        if not (target and target.side == "enemy") then
            return nil, "ash_lamp needs enemy"
        end
        if not state:intentPreview(target.id, { reveal = true }) then
            return nil, "ash_lamp needs intent"
        end
        if not Runtime.enemyVisible(runtime, target) then
            return nil, "ash_lamp target hidden"
        end
        return { TacticsState.commands.reduceIntent(selected.id, target.id, 1, 1) }
    end
    return nil, "unknown Lamplighter verb"
end

local function lamplighterPreview(runtime, selected, verb)
    local commands, err = lamplighterCommands(runtime, selected, verb)
    if not commands then
        return { error = err }
    end
    return previewCommandSequence(runtime.state, commands)
end

function classVerbPreview(runtime, selected, verb)
    if selected and selected.class == "warden" then
        return wardenPreview(runtime, selected, verb)
    end
    if selected and selected.class == "duelist" then
        return duelistPreview(runtime, selected, verb)
    end
    if selected and selected.class == "mender" then
        return menderPreview(runtime, selected, verb)
    end
    if selected and selected.class == "harrier" then
        return harrierPreview(runtime, selected, verb)
    end
    if selected and selected.class == "arcanist" then
        return arcanistPreview(runtime, selected, verb)
    end
    if selected and selected.class == "lamplighter" then
        return lamplighterPreview(runtime, selected, verb)
    end
    return nil
end

local function overlayCache(runtime)
    local c = cache(runtime)
    c.overlayParts = c.overlayParts or {}
    return c.overlayParts
end

local function cachedMovementOverlay(runtime, selected)
    local parts = overlayCache(runtime)
    local state = runtime.state
    local key = table.concat({
        "movement",
        tostring(stateRevision(state, "units")),
        tostring(stateRevision(state, "terrain")),
        tostring(selected and selected.id or ""),
        tostring(selected and selected.x or ""),
        tostring(selected and selected.y or ""),
        tostring(selected and selected.ap or ""),
    }, ":")
    if parts.movement and parts.movement.key == key then
        return parts.movement.value
    end
    local movement = {}
    if selected and selected.side == "player" and selected.alive and selected.ap > 0 then
        local board = state.board or {}
        local boardCells = (board.width or 0) * (board.height or 0)
        local overlayMaxCost = selected.ap
        if boardCells >= 2048 and overlayMaxCost > 16 then
            overlayMaxCost = 16
        end
        for _, tile in ipairs(state:movementPreview(selected.id, { includePaths = false, maxCost = overlayMaxCost }).reachable) do
            movement[#movement + 1] = { x = tile.x, y = tile.y, label = tostring(tile.apCost) .. "AP" }
        end
    end
    parts.movement = { key = key, value = movement }
    return movement
end

local function activeUnitPositionKey(state, side)
    local parts = { tostring(side or "all") }
    for _, id in ipairs(state.unitOrder or {}) do
        local unit = state.units[id]
        if unit and (not side or unit.side == side) then
            parts[#parts + 1] = id
            parts[#parts + 1] = tostring(unit.x)
            parts[#parts + 1] = tostring(unit.y)
            parts[#parts + 1] = tostring(unit.alive == true)
            parts[#parts + 1] = tostring(unit.evacuated == true)
        end
    end
    return table.concat(parts, ":")
end

local function cachedIntentOverlay(runtime, visibility)
    local parts = overlayCache(runtime)
    local state = runtime.state
    local key = table.concat({
        "intent",
        tostring(stateRevision(state, "units")),
        tostring(stateRevision(state, "terrain")),
        tostring(stateRevision(state, "vision")),
        tostring(stateRevision(state, "overlays")),
        activeUnitPositionKey(state, "enemy"),
    }, ":")
    if parts.intents and parts.intents.key == key then
        return parts.intents.value
    end
    local intents = {}
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        if Runtime.enemyVisible(runtime, enemy, visibility) then
            local preview = state:intentPreview(enemy.id, { side = "player" })
            for _, tile in ipairs((preview and preview.targetTiles) or {}) do
                if visibility.visible[tileKey(tile.x, tile.y)] then
                    intents[#intents + 1] = { x = tile.x, y = tile.y, label = preview.label or preview.category }
                end
            end
        end
    end
    parts.intents = { key = key, value = intents }
    return intents
end

local function overwatchSelectionKey(selection)
    if not selection then
        return "none"
    end
    return table.concat({
        tostring(selection.direction or ""),
        tostring(selection.range or ""),
        tostring(selection.arc or ""),
        tostring(#(selection.tiles or {})),
    }, ":")
end

local function cachedOverwatchOverlay(runtime)
    local parts = overlayCache(runtime)
    local state = runtime.state
    local key = table.concat({
        "overwatch",
        tostring(stateRevision(state, "units")),
        tostring(stateRevision(state, "overlays")),
        overwatchSelectionKey(runtime.overwatchSelection),
    }, ":")
    if parts.overwatch and parts.overwatch.key == key then
        return parts.overwatch.value
    end
    local overwatch = {}
    for _, zone in ipairs(state.threatZones or {}) do
        if zone.kind == "overwatch" then
            for _, tile in ipairs(zone.tiles or {}) do
                overwatch[#overwatch + 1] = { x = tile.x, y = tile.y, label = zone.reaction and zone.reaction.kind or zone.label or "overwatch" }
            end
        end
    end
    if runtime.overwatchSelection then
        for _, tile in ipairs(runtime.overwatchSelection.tiles or {}) do
            overwatch[#overwatch + 1] = { x = tile.x, y = tile.y, label = "preview" }
        end
    end
    parts.overwatch = { key = key, value = overwatch }
    return overwatch
end

local function aiDebugOverlay(runtime, visibility)
    local state = runtime.state
    local aiDebug = {}
    if runtime.aiDebug then
        for _, enemy in ipairs(state:unitsForSide("enemy")) do
            if Runtime.enemyVisible(runtime, enemy, visibility) then
                local intent = state.intents[enemy.id]
                local debug = runtime.aiDebugPlans and runtime.aiDebugPlans[enemy.id]
                if intent and debug then
                    for _, tile in ipairs(intent.path or {}) do
                        aiDebug[#aiDebug + 1] = { x = tile.x, y = tile.y, label = enemy.id .. " path" }
                    end
                    if intent.destination then
                        aiDebug[#aiDebug + 1] = { x = intent.destination.x, y = intent.destination.y, label = tostring(debug.chosen and debug.chosen.tactic or intent.tactic or "ai") }
                    end
                    local target = intent.targetTiles and intent.targetTiles[1]
                    if target then
                        aiDebug[#aiDebug + 1] = { x = target.x, y = target.y, label = enemy.id .. " target" }
                    end
                end
            end
        end
    end
    return aiDebug
end

function Runtime.refreshOverlays(runtime)
    local state = runtime.state
    local selected = Runtime.selectedUnit(runtime)
    local visibility = Runtime.visibilityGrid(runtime)
    revealVisibleEnemyIntents(runtime, visibility)
    local movement = cachedMovementOverlay(runtime, selected)
    local intents = cachedIntentOverlay(runtime, visibility)
    local overwatch = cachedOverwatchOverlay(runtime)
    local aiDebug = aiDebugOverlay(runtime, visibility)
    runtime.overwatchTrigger = state.lastOverwatchTrigger
    runtime.overlays = {
        movement = movement,
        intents = intents,
        overwatch = overwatch,
        aiDebug = aiDebug,
        los = selected and { { x = selected.x, y = selected.y, label = "selected" } } or {},
        flanks = { { x = runtime.cursor.x, y = runtime.cursor.y, label = "cursor" } },
        cursor = { { x = runtime.cursor.x, y = runtime.cursor.y, label = "cursor" } },
        fog = visibility,
    }
    return runtime.overlays
end

function Runtime.overwatchPreview(runtime, direction, range, arc)
    local selected = Runtime.selectedUnit(runtime)
    if not (selected and selected.side == "player") then
        return {}
    end
    return runtime.state:threatZoneTiles(selected.id, "cone", { direction = direction or selected.facing or "east", length = range or 3, width = arc or 1 })
end

function Runtime.setOverwatchPreview(runtime, direction, range, arc)
    runtime.overwatchSelection = {
        direction = direction or "east",
        range = range or 3,
        arc = arc or 1,
        tiles = Runtime.overwatchPreview(runtime, direction, range, arc),
    }
    Runtime.refreshOverlays(runtime)
    return runtime.overwatchSelection
end

function Runtime.clearOverwatchPreview(runtime)
    runtime.overwatchSelection = nil
    Runtime.refreshOverlays(runtime)
end

function setStatus(runtime, message)
    runtime.message = message
    runtime.status = message
end

local function queueHitEvent(runtime, event)
    runtime.hitEvents = runtime.hitEvents or {}
    runtime.hitEvents[#runtime.hitEvents + 1] = event
end

function Runtime.drainHitEvents(runtime)
    local events = runtime.hitEvents or {}
    runtime.hitEvents = {}
    return events
end

function Runtime.setAiDebug(runtime, enabled)
    runtime.aiDebug = enabled == true
    Runtime.declareEnemyIntents(runtime)
    Runtime.refreshOverlays(runtime)
    setStatus(runtime, runtime.aiDebug and "AI debug on" or "AI debug off")
    return runtime.aiDebug
end

function Runtime.toggleAiDebug(runtime)
    return Runtime.setAiDebug(runtime, not runtime.aiDebug)
end

local function tryApply(runtime, command)
    local ok, err = pcall(function()
        runtime.state:apply(command)
    end)
    if not ok then
        setStatus(runtime, tostring(err):gsub("^.*:%d+: ", ""))
        return false
    end
    return true
end

local function tryApplyCommands(runtime, commands)
    local sim = TacticsState.fromSnapshot(runtime.state:snapshot())
    for _, command in ipairs(commands or {}) do
        local ok, err = pcall(function()
            sim:apply(command)
        end)
        if not ok then
            setStatus(runtime, tostring(err):gsub("^.*:%d+: ", ""))
            return false
        end
    end
    for _, command in ipairs(commands or {}) do
        local hit = nil
        if command.type == "attack" then
            local source = runtime.state:unit(command.unit)
            local target = runtime.state:unit(command.target)
            local resolution = source and target and runtime.state:attackResolution(command.unit, command.target, command.damage or 1) or nil
            hit = source and target and {
                source = source.id,
                sourceSide = source.side,
                target = target.id,
                targetSide = target.side,
                before = target.hp,
                x = target.x,
                y = target.y,
                blocked = resolution and resolution.blocked == true,
            } or nil
        end
        runtime.state:apply(command)
        if hit then
            local target = runtime.state:unit(hit.target)
            local amount = math.max(0, (hit.before or 0) - ((target and target.hp) or 0))
            queueHitEvent(runtime, {
                source = hit.source,
                sourceSide = hit.sourceSide,
                target = hit.target,
                targetSide = hit.targetSide,
                amount = amount,
                x = hit.x,
                y = hit.y,
                killed = target and not target.alive or false,
                blocked = amount <= 0 or hit.blocked,
            })
        end
    end
    return true
end

function Runtime.moveCursor(runtime, dx, dy)
    local state = runtime.state
    runtime.cursor.x = math.max(1, math.min(state.board.width, runtime.cursor.x + dx))
    runtime.cursor.y = math.max(1, math.min(state.board.height, runtime.cursor.y + dy))
    Runtime.refreshOverlays(runtime)
end

function Runtime.setCursor(runtime, x, y)
    local state = runtime and runtime.state
    if not (state and state:inBounds(x, y)) then
        return false
    end
    runtime.cursor.x = x
    runtime.cursor.y = y
    Runtime.refreshOverlays(runtime)
    return true
end

function Runtime.moveSelectedToCursor(runtime)
    local state = runtime.state
    local selected = Runtime.selectedUnit(runtime)
    if not selected or selected.side ~= "player" then
        return false
    end
    local fromX = selected.x
    local fromY = selected.y
    local preview = cachedMovementPreview(runtime, selected.id)
    local destination = reachableByKey(preview)[tostring(runtime.cursor.x) .. ":" .. tostring(runtime.cursor.y)]
    if not destination then
        setStatus(runtime, "cursor tile is not reachable")
        return false
    end
    for _, direction in ipairs(destination.path or {}) do
        if not tryApply(runtime, TacticsState.commands.move(selected.id, direction)) then
            break
        end
    end
    local moved = selected.x ~= fromX or selected.y ~= fromY
    local replanned = moved and Runtime.replanVisibleEnemyIntents(runtime, selected) or 0
    setStatus(runtime, selected.id .. (replanned > 0 and " moved; enemies adjusted" or " moved"))
    Runtime.refreshOverlays(runtime)
    return true
end

function Runtime.activateCursor(runtime)
    return Runtime.handleMouseTile(runtime, runtime.cursor.x, runtime.cursor.y, 1)
end

function Runtime.inspectCursor(runtime)
    local action = Runtime.actionAtTile(runtime, runtime.cursor.x, runtime.cursor.y)
    setStatus(runtime, action.label .. (action.detail ~= "" and (" " .. action.detail) or ""))
    return true
end

function Runtime.actionAtTile(runtime, x, y)
    local state = runtime and runtime.state
    if not (state and state:inBounds(x, y)) then
        return { kind = "none", label = "No tile", key = "LMB", enabled = false, detail = "" }
    end
    local unit = state:unitAt(x, y)
    local selected = Runtime.selectedUnit(runtime)
    if runtime.explorationMode and runtime.partyMovementEnabled then
        local path, kind = Runtime.partyPathTo(runtime, x, y)
        return { kind = "partyMove", label = "Party Move", key = "LMB", enabled = path ~= nil, detail = path and ((kind == "partial" and "partial " or "") .. tostring(math.max(0, #path - 1)) .. " steps") or tostring(kind or "blocked") }
    end
    if unit and unit.side == "player" then
        return { kind = "select", label = "Select", key = "LMB", enabled = true, detail = unit.id }
    end
    if unit and unit.side == "enemy" then
        if not Runtime.enemyVisible(runtime, unit) then
            return { kind = "cursor", label = "Inspect tile", key = "RMB", enabled = true, detail = tostring(x) .. "," .. tostring(y) }
        end
        local distance = selected and Grid.manhattan(selected.x, selected.y, unit.x, unit.y) or nil
        local enabled = selected and selected.ap >= 1 and distance and distance <= 3
        local attack = selected and distance and distance <= 3 and state:attackResolution(selected.id, unit.id, 1) or nil
        local detail = distance and ("HP" .. tostring(unit.hp) .. " r" .. tostring(distance) .. "/3" .. (attack and (" dmg" .. tostring(attack.damage) .. (attack.flanked and " flank" or "")) or "")) or "no unit"
        if selected and selected.ap < 1 then
            detail = "need AP"
        end
        return { kind = "attack", label = "Attack", key = "LMB/A", enabled = enabled == true, detail = detail }
    end
    if selected and selected.side == "player" then
        local tile = reachableByKey(cachedMovementPreview(runtime, selected.id))[tostring(x) .. ":" .. tostring(y)]
        if tile and (tile.apCost or 0) > 0 then
            return { kind = "move", label = "Move", key = "LMB/Enter", enabled = true, detail = tostring(tile.apCost or 0) .. " AP" }
        elseif tile then
            return { kind = "hold", label = "Hold", key = "LMB", enabled = false, detail = "already here" }
        end
    end
    return { kind = "cursor", label = "Inspect tile", key = "RMB", enabled = true, detail = tostring(x) .. "," .. tostring(y) }
end

function Runtime.actionBar(runtime, hover)
    local selected = Runtime.selectedUnit(runtime)
    local cursorAction = Runtime.actionAtTile(runtime, runtime.cursor.x, runtime.cursor.y)
    local hoverAction = hover and Runtime.actionAtTile(runtime, hover.x, hover.y) or nil
    local context = hoverAction or cursorAction
    if hoverAction then
        context = { id = context.id, key = "LMB", label = context.label, detail = context.detail, enabled = context.enabled, primary = context.primary }
    end
    local canAttack = cursorAction.kind == "attack" and cursorAction.enabled
    local canMove = cursorAction.kind == "move" and cursorAction.enabled
    local playerCount = livingPlayers(runtime.state)
    local actions = {
        { id = "context", key = context.key or "LMB", label = context.label, detail = context.detail, enabled = context.enabled, primary = true },
        { id = "cursor", key = "WASD", label = "Cursor", detail = "aim tile", enabled = true },
        { id = "move", key = "Enter", label = "Move", detail = canMove and cursorAction.detail or "blue tile", enabled = canMove },
        { id = "attack", key = "A", label = "Attack", detail = canAttack and cursorAction.detail or "enemy", enabled = canAttack },
    }
    for index, verb in ipairs(boardActionsForUnit(selected)) do
        local preview = cachedClassVerbPreview(runtime, selected, verb)
        local detail = (preview and preview.error) or selected.className or selected.class
        local apCost = (preview and preview.apCost) or 1
        actions[#actions + 1] = { id = "class:" .. verb, key = tostring(index), label = labelForVerb(verb), detail = detail, enabled = selected and selected.ap >= apCost and not (preview and preview.error), classVerb = verb, preview = preview }
    end
    actions[#actions + 1] = { id = "brace", key = "B", label = "Brace", detail = "1 AP guard", enabled = selected and selected.ap >= 1 }
    actions[#actions + 1] = { id = "parry", key = "P", label = "Parry", detail = "block + counter", enabled = selected and selected.ap >= 1 }
    actions[#actions + 1] = { id = "dodge", key = "O", label = "Dodge", detail = "-50% next hit", enabled = selected and selected.ap >= 1 }
    local hasBond = false
    if selected and runtime.state.bonds and runtime.state.bonds.bondsByUnit then
        local Bonds = require("src.game.tactics.bonds")
        for _, cohesion in pairs(runtime.state.bonds.bondsByUnit[selected.id] or {}) do
            if cohesion >= Bonds.levelThresholds[1] then hasBond = true; break end
        end
    end
    actions[#actions + 1] = { id = "teamwork", key = "T", label = "Teamwork", detail = "+1 AP to bondmate", enabled = hasBond and selected and selected.ap >= 1 }
    actions[#actions + 1] = { id = "unit", key = "Tab", label = "Unit", detail = tostring(playerCount) .. " squad", enabled = playerCount > 1 }
    actions[#actions + 1] = { id = "rotate", key = "[ ]", label = "Rotate", detail = "view", enabled = true }
    actions[#actions + 1] = { id = "end", key = "E", label = "End Turn", detail = "resolve red", enabled = true }
    actions[#actions + 1] = { id = "zoom", key = "Wheel", label = "Zoom", detail = "board scale", enabled = true }
    return actions
end

function Runtime.activateClassVerb(runtime, index)
    local selected = Runtime.selectedUnit(runtime)
    local verb = boardActionsForUnit(selected)[index]
    if not verb then
        setStatus(runtime, "no class verb")
        return false
    end
    if selected.class == "warden" then
        local command, err = wardenCommand(runtime, selected, verb)
        if not command then
            setStatus(runtime, err)
            return false
        end
        if tryApply(runtime, command) then
            Runtime.refreshOverlays(runtime)
            setStatus(runtime, selected.id .. " " .. verb)
            return true
        end
        return false
    end
    if selected.class == "duelist" then
        local commands, err = duelistCommands(runtime, selected, verb)
        if not commands then
            setStatus(runtime, err)
            return false
        end
        if tryApplyCommands(runtime, commands) then
            Runtime.refreshOverlays(runtime)
            setStatus(runtime, selected.id .. " " .. verb)
            return true
        end
        return false
    end
    if selected.class == "mender" then
        local commands, err = menderCommands(runtime, selected, verb)
        if not commands then
            setStatus(runtime, err)
            return false
        end
        if tryApplyCommands(runtime, commands) then
            Runtime.refreshOverlays(runtime)
            setStatus(runtime, selected.id .. " " .. verb)
            return true
        end
        return false
    end
    if selected.class == "harrier" then
        local commands, err = harrierCommands(runtime, selected, verb)
        if not commands then
            setStatus(runtime, err)
            return false
        end
        if tryApplyCommands(runtime, commands) then
            Runtime.refreshOverlays(runtime)
            setStatus(runtime, selected.id .. " " .. verb)
            return true
        end
        return false
    end
    if selected.class == "arcanist" then
        local commands, err = arcanistCommands(runtime, selected, verb)
        if not commands then
            setStatus(runtime, err)
            return false
        end
        if tryApplyCommands(runtime, commands) then
            Runtime.refreshOverlays(runtime)
            setStatus(runtime, selected.id .. " " .. verb)
            return true
        end
        return false
    end
    if selected.class == "lamplighter" then
        local commands, err = lamplighterCommands(runtime, selected, verb)
        if not commands then
            setStatus(runtime, err)
            return false
        end
        if tryApplyCommands(runtime, commands) then
            Runtime.refreshOverlays(runtime)
            setStatus(runtime, selected.id .. " " .. verb)
            return true
        end
        return false
    end
    setStatus(runtime, selected.id .. " ready " .. verb)
    return true
end

function Runtime.handleMouseTile(runtime, x, y, button)
    if button ~= 1 and button ~= 2 then
        return false
    end
    if not Runtime.setCursor(runtime, x, y) then
        return false
    end
    local state = runtime.state
    local unit = state:unitAt(x, y)
    if button == 2 then
        setStatus(runtime, "cursor " .. tostring(x) .. "," .. tostring(y))
        return true
    end
    if runtime.explorationMode and runtime.partyMovementEnabled then
        return Runtime.movePartyTo(runtime, x, y)
    end
    if unit and unit.side == "player" then
        runtime.selectedUnitId = unit.id
        setStatus(runtime, "selected " .. unit.id)
        Runtime.refreshOverlays(runtime)
        return true
    end
    if unit and unit.side == "enemy" and Runtime.enemyVisible(runtime, unit) then
        return Runtime.attackCursor(runtime)
    end
    local selected = Runtime.selectedUnit(runtime)
    local preview = selected and cachedMovementPreview(runtime, selected.id)
    if selected and reachableByKey(preview)[tostring(x) .. ":" .. tostring(y)] then
        return Runtime.moveSelectedToCursor(runtime)
    end
    setStatus(runtime, "cursor " .. tostring(x) .. "," .. tostring(y))
    return true
end

function Runtime.attackCursor(runtime)
    local state = runtime.state
    local selected = Runtime.selectedUnit(runtime)
    local target = state:unitAt(runtime.cursor.x, runtime.cursor.y)
    if not (selected and target and target.side == "enemy" and Runtime.enemyVisible(runtime, target)) then
        setStatus(runtime, "no enemy on cursor")
        return false
    end
    local distance = Grid.manhattan(selected.x, selected.y, target.x, target.y)
    if distance > 3 then
        setStatus(runtime, "target outside deterministic range")
        return false
    end
    local targetX = target.x
    local targetY = target.y
    local before = target.hp
    local attack = state:attackResolution(selected.id, target.id, 1)
    if tryApply(runtime, TacticsState.commands.attack(selected.id, target.id, 1, 1)) then
        local amount = math.max(0, (before or 0) - (target.hp or 0))
        queueHitEvent(runtime, {
            source = selected.id,
            sourceSide = selected.side,
            target = target.id,
            targetSide = target.side,
            amount = amount,
            x = targetX,
            y = targetY,
            killed = not target.alive,
            blocked = amount <= 0 or attack.blocked == true,
        })
        if not target.alive then
            state.intents[target.id] = nil
        end
        setStatus(runtime, selected.id .. " hit " .. target.id .. " for " .. tostring(amount))
    end
    Runtime.refreshOverlays(runtime)
    return true
end

function Runtime.cycleUnit(runtime)
    local units = runtime.state:unitsForSide("player")
    if #units == 0 then
        return
    end
    local index = 1
    for i, unit in ipairs(units) do
        if unit.id == runtime.selectedUnitId then
            index = i % #units + 1
            break
        end
    end
    runtime.selectedUnitId = units[index].id
    runtime.cursor.x = units[index].x
    runtime.cursor.y = units[index].y
    setStatus(runtime, "selected " .. runtime.selectedUnitId)
    Runtime.refreshOverlays(runtime)
end

local function resolveEnemyIntent(runtime, enemy)
    local state = runtime.state
    local intent = state.intents[enemy.id]
    if not intent then
        return
    end
    if intent.damage and intent.damage > 0 then
        state:resolveIntentTrigger(enemy.id, intent, {
            kind = "damage",
            damage = intent.damage,
            targetTiles = copyList(intent.targetTiles),
        })
    end
    if intent.statusEffect and intent.statusEffect.status then
        local targetId = intent.statusEffect.target or intent.target
        if not (targetId and state.units[targetId]) then
            local tile = intent.targetTiles and intent.targetTiles[1]
            local unit = tile and state:unitAt(tile.x, tile.y)
            targetId = unit and unit.id or nil
        end
        if targetId and state.units[targetId] then
            state:resolveIntentTrigger(enemy.id, intent, {
                kind = "status",
                target = targetId,
                status = intent.statusEffect.status,
                turns = intent.statusEffect.turns,
                amount = intent.statusEffect.amount,
            })
        end
        return
    end
    state:resolveIntentTrigger(enemy.id, intent, {
        kind = "damage",
        damage = intent.damage or 1,
        targetTiles = copyList(intent.targetTiles),
    })
end

local function enemyCanActOnTarget(state, enemy, target, range)
    if not (enemy and target and state:inBounds(enemy.x, enemy.y) and state:inBounds(target.x, target.y)) then
        return false
    end
    if Grid.manhattan(enemy.x, enemy.y, target.x, target.y) > (range or 3) then
        return false
    end
    local los = state:lineOfSight(enemy.x, enemy.y, target.x, target.y)
    return los.visible == true and los.obscured ~= true
end

local function rememberEnemyPlan(runtime, enemy, plan, result)
    runtime.aiMemory = runtime.aiMemory or { units = {}, targets = {} }
    runtime.aiMemory.units = runtime.aiMemory.units or {}
    runtime.aiMemory.targets = runtime.aiMemory.targets or {}
    local targetId = plan.target and plan.target.id
    local damage = (result and (result.damage or result.objectiveDamage)) or 0
    local outcome = "failed"
    if result and targetId and damage > 0 then
        outcome = "damaged"
    elseif result and targetId then
        outcome = "acted"
    elseif result and (result.moved or 0) > 0 then
        outcome = "moved"
    elseif result and result.noLos then
        outcome = "no_los"
    end
    runtime.aiMemory.units[enemy.id] = {
        turn = runtime.turn or 1,
        lastTarget = targetId,
        lastDestination = plan.destination and { x = plan.destination.x, y = plan.destination.y } or { x = enemy.x, y = enemy.y },
        lastTactic = plan.tactic,
        lastDamage = damage,
        lastOutcome = outcome,
    }
    if targetId then
        local pressure = runtime.aiMemory.targets[targetId] or { damage = 0, touches = 0 }
        pressure.damage = math.min(9, (pressure.damage or 0) + damage)
        pressure.touches = math.min(9, (pressure.touches or 0) + 1)
        pressure.lastTurn = runtime.turn or 1
        runtime.aiMemory.targets[targetId] = pressure
    end
end

local function decayAiMemory(runtime)
    runtime.aiMemory = runtime.aiMemory or { units = {}, targets = {} }
    runtime.aiMemory.targets = runtime.aiMemory.targets or {}
    for targetId, pressure in pairs(runtime.aiMemory.targets) do
        if (runtime.turn or 1) - (pressure.lastTurn or 0) > 1 then
            pressure.damage = math.max(0, (pressure.damage or 0) - 1)
            pressure.touches = math.max(0, (pressure.touches or 0) - 1)
            if pressure.damage <= 0 and pressure.touches <= 0 then
                runtime.aiMemory.targets[targetId] = nil
            end
        end
    end
end

local function executeEnemyPlan(runtime, plan)
    local state = runtime.state
    local enemy = state:unit(plan.unit)
    if not (enemy and enemy.alive and not enemy.evacuated) then
        return nil
    end
    for _, direction in ipairs(plan.directions or {}) do
        if (enemy.ap or 0) <= 0 then
            break
        end
        if not tryApply(runtime, TacticsState.commands.move(enemy.id, direction)) then
            break
        end
    end
    local target = plan.target and plan.target.id and (state:unit(plan.target.id) or state:objective(plan.target.id)) or nil
    if not (target and (enemy.ap or 0) > 0 and enemyCanActOnTarget(state, enemy, target, 3)) then
        return { unit = enemy.id, tactic = plan.tactic, moved = #(plan.directions or {}), target = target and target.id or nil, noLos = target ~= nil }
    end
    if target.side == "player" then
        local targetX = target.x
        local targetY = target.y
        local before = target.hp
        if tryApply(runtime, TacticsState.commands.attack(enemy.id, target.id, plan.damage or 1, 1)) then
            local amount = math.max(0, (before or 0) - (target.hp or 0))
            queueHitEvent(runtime, {
                source = enemy.id,
                sourceSide = enemy.side,
                target = target.id,
                targetSide = target.side,
                amount = amount,
                x = targetX,
                y = targetY,
                killed = not target.alive,
                blocked = amount <= 0,
            })
            return { unit = enemy.id, tactic = plan.tactic, target = target.id, damage = amount, moved = #(plan.directions or {}) }
        end
    elseif target.integrity ~= nil then
        local before = target.integrity
        if tryApply(runtime, TacticsState.commands.damageObjective(enemy.id, target.id, plan.damage or 1, 1)) then
            return { unit = enemy.id, tactic = plan.tactic, target = target.id, objectiveDamage = math.max(0, (before or 0) - (target.integrity or 0)), moved = #(plan.directions or {}) }
        end
    end
    return { unit = enemy.id, tactic = plan.tactic, moved = #(plan.directions or {}) }
end

function Runtime.endPlayerTurn(runtime)
    local state = runtime.state
    decayAiMemory(runtime)
    state:startTurn("enemy")
    local skipIds = {}
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        local intent = state.intents[enemy.id]
        local statusEffect = intent and intent.statusEffect
        if intent and ((statusEffect and statusEffect.status) or intent.category == "buff" or intent.category == "debuff" or intent.category == "repair") and intent.aiCanReposition ~= true then
            resolveEnemyIntent(runtime, enemy)
            skipIds[enemy.id] = true
        end
    end
    local report = EnemyAI.planTurn(state, { objective = objectiveState(state), memory = runtime.aiMemory, maxMoveAp = 2, attackRange = 3, skipIds = skipIds })
    runtime.lastEnemyPlans = report.plans
    runtime.lastEnemyDoctrine = copyValue(report.doctrine)
    runtime.aiDebugPlans = runtime.aiDebug and {} or nil
    if runtime.aiDebug then
        for _, plan in ipairs(report.plans or {}) do
            runtime.aiDebugPlans[plan.unit] = copyValue(plan.debug)
        end
    end
    runtime.lastEnemyResults = {}
    for _, plan in ipairs(report.plans or {}) do
        local result = executeEnemyPlan(runtime, plan)
        runtime.lastEnemyResults[#runtime.lastEnemyResults + 1] = result
        local enemy = state:unit(plan.unit)
        if enemy then
            rememberEnemyPlan(runtime, enemy, plan, result)
        end
    end
    runtime.turn = runtime.turn + 1
    state:startTurn("player")
    Runtime.declareEnemyIntents(runtime)
    Runtime.refreshOverlays(runtime)
    setStatus(runtime, "enemy notices resolved; player AP refreshed")
end

function Runtime.brace(runtime)
    local selected = Runtime.selectedUnit(runtime)
    if not selected then
        return false
    end
    if tryApply(runtime, TacticsState.commands.status(selected.id, selected.id, "braced", 1, 1, 1)) then
        setStatus(runtime, selected.id .. " braced")
        Runtime.refreshOverlays(runtime)
        return true
    end
    return false
end

function Runtime.parry(runtime)
    local selected = Runtime.selectedUnit(runtime)
    if not selected then return false end
    if (selected.ap or 0) < 1 then setStatus(runtime, "parry needs 1 AP"); return false end
    if tryApply(runtime, TacticsState.commands.parry(selected.id, 1)) then
        setStatus(runtime, selected.id .. " parries: full block + AP refund on next hit")
        Runtime.refreshOverlays(runtime)
        return true
    end
    return false
end

function Runtime.dodge(runtime)
    local selected = Runtime.selectedUnit(runtime)
    if not selected then return false end
    if (selected.ap or 0) < 1 then setStatus(runtime, "dodge needs 1 AP"); return false end
    if tryApply(runtime, TacticsState.commands.dodge(selected.id, 1)) then
        setStatus(runtime, selected.id .. " dodges: -50% damage on next hit")
        Runtime.refreshOverlays(runtime)
        return true
    end
    return false
end

function Runtime.teamwork(runtime)
    local state = runtime.state
    local selected = Runtime.selectedUnit(runtime)
    if not selected or not state.bonds or not state.bonds.bondsByUnit then
        setStatus(runtime, "no bond available"); return false
    end
    local mates = state.bonds.bondsByUnit[selected.id] or {}
    local Bonds = require("src.game.tactics.bonds")
    local mateId
    for id, cohesion in pairs(mates) do
        if cohesion >= Bonds.levelThresholds[1] then
            local mate = state:unit(id)
            if mate and mate.alive and not mate.evacuated then
                mateId = id; break
            end
        end
    end
    if not mateId then setStatus(runtime, "no eligible bondmate"); return false end
    if tryApply(runtime, TacticsState.commands.teamwork(selected.id, mateId, 1)) then
        setStatus(runtime, selected.id .. " grants 1 AP to " .. mateId)
        Runtime.refreshOverlays(runtime)
        return true
    end
    return false
end

function Runtime.advanceRoute(runtime)
    local order = runtime.routeOrder or {}
    local nextIndex = (runtime.routeIndex or 1) + 1
    local nextVariant = order[nextIndex]
    if nextVariant then
        if runtime.boardSpec and runtime.boardSpec.archiveRoute and runtime.boardSpec.archiveRoute.expanse then
            setActiveRouteRegion(runtime, nextVariant)
            setStatus(runtime, "route advanced: " .. tostring(nextVariant))
            runtime.complete = false
            runtime.routeComplete = false
            return true
        end
        Runtime.loadRouteVariant(runtime, nextVariant)
        setStatus(runtime, "route advanced: " .. tostring(nextVariant))
        return true
    end
    runtime.complete = true
    runtime.routeComplete = true
    setStatus(runtime, "route cleared: all Archive nodes answered")
    Runtime.syncWorld(runtime.sim, runtime)
    return false
end

function Runtime.evaluate(runtime)
    local state = runtime.state
    local objective = objectiveState(state)
    local status = state:objectiveStatus(objective.id)
    if livingEnemies(state) == 0 then
        Runtime.advanceRoute(runtime)
    elseif status == "failed" or livingPlayers(state) == 0 then
        runtime.failed = true
        setStatus(runtime, "board failed: route machine or squad lost")
    end
    return runtime.complete, runtime.failed
end

function Runtime.handleKey(runtime, key)
    if key == "up" or key == "w" then
        Runtime.moveCursor(runtime, 0, -1)
    elseif key == "down" or key == "s" then
        Runtime.moveCursor(runtime, 0, 1)
    elseif key == "left" then
        Runtime.moveCursor(runtime, -1, 0)
    elseif key == "right" or key == "d" then
        Runtime.moveCursor(runtime, 1, 0)
    elseif key == "tab" then
        Runtime.cycleUnit(runtime)
    elseif key:match("^[1-9]$") then
        Runtime.activateClassVerb(runtime, tonumber(key))
    elseif key == "return" or key == "kpenter" or key == "space" then
        if key == "space" then
            Runtime.inspectCursor(runtime)
        else
            Runtime.activateCursor(runtime)
        end
    elseif key == "a" then
        Runtime.attackCursor(runtime)
    elseif key == "b" then
        Runtime.brace(runtime)
    elseif key == "p" then
        Runtime.parry(runtime)
    elseif key == "o" then
        Runtime.dodge(runtime)
    elseif key == "t" then
        Runtime.teamwork(runtime)
    elseif key == "e" then
        Runtime.endPlayerTurn(runtime)
    elseif key == "+" or key == "=" or key == "kp+" then
        Runtime.cycleTopology(runtime, 1)
    elseif key == "-" or key == "kp-" then
        Runtime.cycleTopology(runtime, -1)
    else
        return false
    end
    Runtime.evaluate(runtime)
    return true
end

function Runtime.summary(runtime)
    local state = runtime.state
    local selected = Runtime.selectedUnit(runtime)
    local objective = objectiveState(state)
    local visibility = Runtime.visibilityGrid(runtime)
    local enemies = {}
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        if Runtime.enemyVisible(runtime, enemy, visibility) then
            local intent = state:intentPreview(enemy.id, { side = "player" })
            enemies[#enemies + 1] = {
                id = enemy.id,
                kind = enemy.kind,
                hp = enemy.hp,
                maxHp = enemy.maxHp,
                x = enemy.x,
                y = enemy.y,
                visible = true,
                intent = intent and intent.label or "-",
                intentCategory = intent and intent.category or nil,
                intentLabel = intent and (intent.label or intent.effect or intent.category) or "-",
                intentDamage = intent and intent.damage or 0,
                intentHidden = intent and (intent.hiddenByVision == true or intent.categoryOnly == true) or false,
                targetTiles = intent and intent.targetTiles or {},
                breakGauge = enemy.breakGauge or 0,
                breakMax = enemy.breakMax,
                broken = enemy.broken == true,
                brokenTurns = enemy.brokenTurns or 0,
                aiDebug = runtime.aiDebug and runtime.aiDebugPlans and copyValue(runtime.aiDebugPlans[enemy.id]) or nil,
            }
        end
    end
    local lastSeenEnemies = {}
    for _, id in ipairs(sortedKeys(runtime.lastSeenEnemies)) do
        local sighting = runtime.lastSeenEnemies[id]
        local enemy = state:unit(id)
        if sighting and enemy and enemy.alive and not Runtime.enemyVisible(runtime, enemy, visibility) then
            lastSeenEnemies[#lastSeenEnemies + 1] = {
                id = sighting.id,
                hp = sighting.hp,
                x = sighting.x,
                y = sighting.y,
                turn = sighting.turn,
                tick = sighting.tick,
                ghost = true,
                intent = "last seen",
                targetTiles = {},
            }
        end
    end
    local players = {}
    for _, unit in ipairs(state:unitsForSide("player")) do
        players[#players + 1] = {
            id = unit.id, class = unit.class, className = unit.className, loadouts = unit.loadouts,
            hp = unit.hp, maxHp = unit.maxHp, ap = unit.ap, maxAp = unit.maxAp, x = unit.x, y = unit.y,
            selected = selected and selected.id == unit.id,
            name = unit.name,
            portrait = unit.portrait,
            quirks = unit.quirks and copyValue(unit.quirks) or nil,
            stress = unit.stress or 0,
            defense = unit.defense and unit.defense.kind or nil,
        }
    end
    local bonusStatus = (state.bonusStatus and state:bonusStatus()) or {}
    local bondList = {}
    if state.bonds and state.bonds.pairs then
        for _, entry in pairs(state.bonds.pairs) do
            bondList[#bondList + 1] = { a = entry.a, b = entry.b, cohesion = entry.cohesion or 0, teamworkUsed = entry.teamworkUsed == true }
        end
    end
    return {
        mode = "tactical",
        topology = state.board.topology or "square",
        explorationMode = runtime.explorationMode == true,
        partyMovementEnabled = runtime.partyMovementEnabled == true,
        tick = state.tick,
        phase = state.phase,
        turn = runtime.turn,
        cursor = { x = runtime.cursor.x, y = runtime.cursor.y },
        selected = selected and selected.id or "-",
        selectedAp = selected and selected.ap or 0,
        selectedHp = selected and selected.hp or 0,
        objective = { id = objective.id, integrity = objective.integrity, maxIntegrity = objective.maxIntegrity, status = state:objectiveStatus(objective.id) },
        route = runtime.route,
        routeIndex = runtime.routeIndex,
        routeCount = runtime.routeOrder and #runtime.routeOrder or nil,
        players = players,
        enemies = enemies,
        lastSeenEnemies = lastSeenEnemies,
        fog = visibility,
        message = runtime.message,
        complete = runtime.complete == true,
        routeComplete = runtime.routeComplete == true,
        failed = runtime.failed == true,
        aiDebug = runtime.aiDebug == true,
        aiDoctrine = copyValue(runtime.aiDoctrine),
        lastEnemyDoctrine = copyValue(runtime.lastEnemyDoctrine),
        aiMemory = runtime.aiDebug and copyValue(runtime.aiMemory) or nil,
        bonus = bonusStatus,
        bonds = bondList,
        aestheticPassed = runtime.boardSpec and runtime.boardSpec.budget and runtime.boardSpec.budget.aesthetic and runtime.boardSpec.budget.aesthetic.passed,
    }
end

return Runtime
