local Grid = require("src.core.grid")
local TacticsState = require("src.game.tactics.state")

local Runtime = {}

local originX = -5
local originY = -5
local enemyIntentSpecs = {
    audit_hound = { label = "bite notice", target = "nearest_player" },
    claim_lens = { label = "claim beam", target = "objective" },
}

local function copyList(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[#result + 1] = value
    end
    return result
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
    return state:objective("route_machine")
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
                elseif objectiveState(tactics).x == x and objectiveState(tactics).y == y then
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

function Runtime.declareEnemyIntents(runtime)
    local state = runtime.state
    state.intents = {}
    local objective = objectiveState(state)
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        local spec = enemyIntentSpecs[enemy.id] or {}
        local target = spec.target == "objective" and objective or nearestPlayer(state, enemy)
        if target then
            state:declareIntent(enemy.id, {
                mode = "exact",
                category = "attack",
                source = enemy.id,
                sourceTile = { x = enemy.x, y = enemy.y },
                targetTiles = { { x = target.x, y = target.y } },
                damage = spec.damage or 1,
                objectiveImpact = target.id == objective.id and objective.id or nil,
                label = spec.label or "posted notice",
                counterplay = { "move target", "kill source", "block tile" },
            })
        end
    end
end

local function makeState()
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

function Runtime.new(sim)
    local runtime = {
        active = true,
        originX = originX,
        originY = originY,
        cursor = { x = 2, y = 6 },
        selectedUnitId = "warden",
        status = "tactical prototype",
        message = "read intents, spend AP, protect the route machine",
        turn = 1,
        state = makeState(),
        summary = Runtime.summary,
        handleKey = Runtime.handleKey,
        setCursor = Runtime.setCursor,
        handleMouseTile = Runtime.handleMouseTile,
    }
    Runtime.declareEnemyIntents(runtime)
    Runtime.refreshOverlays(runtime)
    Runtime.syncWorld(sim, runtime)
    return runtime
end

function Runtime.selectedUnit(runtime)
    return runtime and runtime.state:unit(runtime.selectedUnitId) or nil
end

local function reachableByKey(preview)
    local result = {}
    for _, tile in ipairs((preview and preview.reachable) or {}) do
        result[tostring(tile.x) .. ":" .. tostring(tile.y)] = tile
    end
    return result
end

function Runtime.refreshOverlays(runtime)
    local state = runtime.state
    local selected = Runtime.selectedUnit(runtime)
    local movement = {}
    if selected and selected.side == "player" and selected.alive and selected.ap > 0 then
        for _, tile in ipairs(state:movementPreview(selected.id).reachable) do
            movement[#movement + 1] = { x = tile.x, y = tile.y, label = tostring(tile.apCost) .. "AP" }
        end
    end
    local intents = {}
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        local preview = state:intentPreview(enemy.id)
        for _, tile in ipairs((preview and preview.targetTiles) or {}) do
            intents[#intents + 1] = { x = tile.x, y = tile.y, label = preview.label or preview.category }
        end
    end
    runtime.overlays = {
        movement = movement,
        intents = intents,
        los = selected and { { x = selected.x, y = selected.y, label = "selected" } } or {},
        flanks = { { x = runtime.cursor.x, y = runtime.cursor.y, label = "cursor" } },
        cursor = { { x = runtime.cursor.x, y = runtime.cursor.y, label = "cursor" } },
    }
    return runtime.overlays
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
    setStatus(runtime, selected.id .. " moved")
    Runtime.refreshOverlays(runtime)
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
    if unit and unit.side == "enemy" then
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
    if not (selected and target and target.side == "enemy") then
        setStatus(runtime, "no enemy on cursor")
        return false
    end
    local distance = Grid.manhattan(selected.x, selected.y, target.x, target.y)
    if distance > 3 then
        setStatus(runtime, "target outside deterministic range")
        return false
    end
    if tryApply(runtime, TacticsState.commands.attack(selected.id, target.id, 1, 1)) then
        if not target.alive then
            state.intents[target.id] = nil
        end
        setStatus(runtime, selected.id .. " hit " .. target.id .. " for 1")
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

function Runtime.evaluate(runtime)
    local state = runtime.state
    local objective = objectiveState(state)
    local status = state:objectiveStatus(objective.id)
    if livingEnemies(state) == 0 then
        runtime.complete = true
        setStatus(runtime, "board cleared: all posted threats removed")
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
    elseif key == "return" or key == "kpenter" or key == "space" then
        Runtime.moveSelectedToCursor(runtime)
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
    local enemies = {}
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        local intent = state:intentPreview(enemy.id)
        enemies[#enemies + 1] = {
            id = enemy.id,
            hp = enemy.hp,
            x = enemy.x,
            y = enemy.y,
            intent = intent and intent.label or "-",
            targetTiles = intent and intent.targetTiles or {},
        }
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
        players = players,
        enemies = enemies,
        message = runtime.message,
        complete = runtime.complete == true,
        failed = runtime.failed == true,
    }
end

return Runtime
