local Grid = require("src.core.grid")
local TacticsState = require("src.game.tactics.state")
local TacticsIntent = require("src.game.tactics.intent")
local TacticsResolution = require("src.game.tactics.resolution")
local ClassCatalog = require("src.game.tactics.class_catalog")
local Procgen = require("src.game.tactics.procgen")

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

local function tileKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
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

local function classLoadoutPayload(classId)
    local class = ClassCatalog.class(classId)
    local loadouts = {}
    local tools = {}
    for index, loadout in ipairs(ClassCatalog.loadouts(classId)) do
        if index > (ClassCatalog.loadoutSlots(classId) or 2) then
            break
        end
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

local function applyLiveClassSquad(spec)
    local deployments = deploymentTiles(spec, #liveClassRoster)
    local units = {}
    for index, entry in ipairs(liveClassRoster) do
        local class, loadouts, boardVerbs, tools = classLoadoutPayload(entry.classId)
        units[#units + 1] = {
            id = entry.id,
            name = class and class.name or entry.id,
            side = "player",
            class = entry.classId,
            className = class and class.name or entry.classId,
            x = deployments[index].x,
            y = deployments[index].y,
            hp = entry.hp,
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

local function plannedEnemyTarget(runtime, enemy, options)
    local state = runtime.state
    local objective = objectiveState(state)
    local spec = enemyIntentSpecs[enemy.id] or {}
    if objective and (objective.integrity or 0) <= 1 then
        return {
            target = objective,
            category = "destroy",
            damage = spec.damage or 1,
            label = "finish notice",
            counterplay = { "block objective", "kill source", "repair objective" },
        }
    end
    if (enemy.hp or 0) <= 1 then
        return {
            target = { id = enemy.id, x = enemy.x, y = enemy.y },
            category = "guard",
            damage = 0,
            label = "regroup notice",
            counterplay = { "press wounded enemy", "ignore harmless guard", "contest tile" },
        }
    end
    local target
    if spec.target == "objective" then
        target = objective
    elseif options and options.visibleTargetsOnly then
        target = nearestVisiblePlayer(state, enemy)
    else
        target = nearestPlayer(state, enemy)
    end
    if not target then
        return nil
    end
    return {
        target = target,
        category = "attack",
        damage = spec.damage or 1,
        label = spec.label or "posted notice",
        counterplay = { "move target", "kill source", "block tile" },
    }
end

function Runtime.syncWorld(sim, runtime)
    if not (sim and sim.world and runtime and runtime.state) then
        return
    end
    local tactics = runtime.state
    for x = 0, tactics.board.width + 1 do
        for y = 0, tactics.board.height + 1 do
            local worldX = runtime.originX + x
            local worldY = runtime.originY + y
            local tileId = "archive_wall"
            if x >= 1 and x <= tactics.board.width and y >= 1 and y <= tactics.board.height then
                local tile = tactics:tileAt(x, y)
                tileId = "archive_floor"
                if tile.blocker then
                    tileId = "archive_monolith"
                elseif tile.hazard and tile.hazard.kind then
                    tileId = "false_index"
                end
                local objective = objectiveState(tactics)
                if objective and objective.x == x and objective.y == y then
                    tileId = "sealed_name"
                end
            end
            sim.world:setTile(worldX, worldY, 0, { id = tileId, data = 0 })
        end
    end
    local focus = tactics:unit(runtime.selectedUnitId) or { x = runtime.cursor.x, y = runtime.cursor.y }
    sim.player.x = runtime.originX + focus.x
    sim.player.y = runtime.originY + focus.y
    sim.player.z = 0
    sim.mode = "tactical"
    sim.status = runtime.status or "tactical"
    sim.tick = tactics.tick
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
        mode = "exact",
        category = plan.category,
        source = enemy.id,
        sourceTile = { x = enemy.x, y = enemy.y },
        targetTiles = { { x = target.x, y = target.y } },
        damage = plan.damage,
        objectiveImpact = objective and target.id == objective.id and objective.id or nil,
        label = plan.label,
        counterplay = plan.counterplay,
    })
    return true
end

function Runtime.declareEnemyIntents(runtime)
    local state = runtime.state
    state.intents = {}
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        declareEnemyIntent(runtime, enemy)
    end
end

function Runtime.replanVisibleEnemyIntents(runtime, movedUnit)
    local state = runtime.state
    local count = 0
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        if enemyCanSeeUnit(state, enemy, movedUnit) and declareEnemyIntent(runtime, enemy, { visibleTargetsOnly = true }) then
            count = count + 1
        end
    end
    return count
end

local function makePrototypeState()
    return TacticsState.new({
        defaultAp = 3,
        board = {
            width = 8,
            height = 8,
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

local function firstPlayerId(state)
    for _, unit in ipairs(state:unitsForSide("player")) do
        return unit.id
    end
    return nil
end

local function makeRouteState(options)
    local route = Procgen.archiveRoute()
    local variantId = (options and options.variantId) or route.start
    local seed = options and options.seed
    local spec = Procgen.generateArchiveRouteBoard(variantId, seed)
    applyLiveClassSquad(spec)
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

function Runtime.new(sim, options)
    options = options or {}
    local state, boardSpec
    local route = Procgen.archiveRoute()
    if options.prototype then
        state = makePrototypeState()
    else
        state, boardSpec = makeRouteState(options)
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
        state = state,
        boardSpec = boardSpec,
        route = boardSpec and boardSpec.archiveRoute or nil,
        routeOrder = boardSpec and copyList(route.variantOrder) or nil,
        routeIndex = boardSpec and routeVariantIndex(route.variantOrder, boardSpec.archiveRoute.variantId) or nil,
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
    }
    Runtime.declareEnemyIntents(runtime)
    Runtime.refreshOverlays(runtime)
    Runtime.syncWorld(sim, runtime)
    return runtime
end

function Runtime.loadRouteVariant(runtime, variantId)
    local state, boardSpec = makeRouteState({ variantId = variantId })
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
    Runtime.syncWorld(runtime.sim, runtime)
    return runtime
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
    local visibility = runtime.state:fogGrid("player")
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
    local preview = { apCost = 0, affectedTiles = {}, pushedPath = {}, objectiveDamage = {}, coverBreak = {}, hazardChain = {} }
    local sim = TacticsState.fromSnapshot(state:snapshot())
    for _, command in ipairs(commands or {}) do
        local ok, commandPreview = pcall(TacticsResolution.actionPreview, sim, command)
        if not ok then
            return { error = tostring(commandPreview):gsub("^.*:%d+: ", "") }
        end
        if commandPreview.error then
            return { error = commandPreview.error }
        end
        preview.apCost = preview.apCost + (commandPreview.apCost or command.cost or 0)
        appendTiles(preview.affectedTiles, commandPreview.affectedTiles)
        appendTiles(preview.pushedPath, commandPreview.pushedPath)
        appendPreviewList(preview.objectiveDamage, commandPreview.objectiveDamage)
        appendPreviewList(preview.coverBreak, commandPreview.coverBreak)
        appendPreviewList(preview.hazardChain, commandPreview.hazardChain)
        preview.dashPath = commandPreview.dashPath or preview.dashPath
        preview.swap = commandPreview.swap or preview.swap
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

local function classVerbPreview(runtime, selected, verb)
    if selected and selected.class == "warden" then
        return wardenPreview(runtime, selected, verb)
    end
    if selected and selected.class == "duelist" then
        return duelistPreview(runtime, selected, verb)
    end
    return nil
end

function Runtime.refreshOverlays(runtime)
    local state = runtime.state
    local selected = Runtime.selectedUnit(runtime)
    local visibility = Runtime.visibilityGrid(runtime)
    TacticsIntent.revealVisible(state, "player")
    local movement = {}
    if selected and selected.side == "player" and selected.alive and selected.ap > 0 then
        for _, tile in ipairs(state:movementPreview(selected.id).reachable) do
            movement[#movement + 1] = { x = tile.x, y = tile.y, label = tostring(tile.apCost) .. "AP" }
        end
    end
    local intents = {}
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        if Runtime.enemyVisible(runtime, enemy, visibility) then
            local preview = TacticsIntent.preview(state, enemy.id, { side = "player" })
            for _, tile in ipairs((preview and preview.targetTiles) or {}) do
                if visibility.visible[tileKey(tile.x, tile.y)] then
                    intents[#intents + 1] = { x = tile.x, y = tile.y, label = preview.label or preview.category }
                end
            end
        end
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
    runtime.overwatchTrigger = state.lastOverwatchTrigger
    runtime.overlays = {
        movement = movement,
        intents = intents,
        overwatch = overwatch,
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

local function setStatus(runtime, message)
    runtime.message = message
    runtime.status = message
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
        runtime.state:apply(command)
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
    local preview = state:movementPreview(selected.id)
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
        local tile = reachableByKey(state:movementPreview(selected.id))[tostring(x) .. ":" .. tostring(y)]
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
        local preview = classVerbPreview(runtime, selected, verb)
        local detail = (preview and preview.error) or selected.className or selected.class
        local apCost = (preview and preview.apCost) or 1
        actions[#actions + 1] = { id = "class:" .. verb, key = tostring(index), label = labelForVerb(verb), detail = detail, enabled = selected and selected.ap >= apCost and not (preview and preview.error), classVerb = verb, preview = preview }
    end
    actions[#actions + 1] = { id = "brace", key = "B", label = "Brace", detail = "1 AP guard", enabled = selected and selected.ap >= 1 }
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
    local preview = selected and state:movementPreview(selected.id)
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
    local attack = state:attackResolution(selected.id, target.id, 1)
    if tryApply(runtime, TacticsState.commands.attack(selected.id, target.id, 1, 1)) then
        if not target.alive then
            state.intents[target.id] = nil
        end
        setStatus(runtime, selected.id .. " hit " .. target.id .. " for " .. tostring(attack.damage))
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
    state:resolveIntentTrigger(enemy.id, intent, {
        kind = "damage",
        damage = intent.damage or 1,
        targetTiles = copyList(intent.targetTiles),
    })
end

function Runtime.endPlayerTurn(runtime)
    local state = runtime.state
    state.phase = "enemy"
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        resolveEnemyIntent(runtime, enemy)
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

function Runtime.advanceRoute(runtime)
    local order = runtime.routeOrder or {}
    local nextIndex = (runtime.routeIndex or 1) + 1
    local nextVariant = order[nextIndex]
    if nextVariant then
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
    elseif key == "e" then
        Runtime.endPlayerTurn(runtime)
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
            local intent = TacticsIntent.preview(state, enemy.id, { side = "player" })
            enemies[#enemies + 1] = {
                id = enemy.id,
                hp = enemy.hp,
                x = enemy.x,
                y = enemy.y,
                visible = true,
                intent = intent and intent.label or "-",
                targetTiles = intent and intent.targetTiles or {},
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
        players[#players + 1] = { id = unit.id, hp = unit.hp, ap = unit.ap, x = unit.x, y = unit.y, selected = selected and selected.id == unit.id }
    end
    return {
        mode = "tactical",
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
    }
end

return Runtime
