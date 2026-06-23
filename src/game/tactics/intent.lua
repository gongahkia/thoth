local Intent = {}

local function tileKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function sourceVisible(state, unitId, side, visibility)
    local unit = state:unit(unitId)
    if not unit then
        return false
    end
    visibility = visibility or state:fogGrid(side or "player")
    return visibility.visible[tileKey(unit.x, unit.y)] == true
end

local function categoryOnly(preview)
    preview.target = nil
    preview.sourceTile = nil
    preview.targetTiles = nil
    preview.path = nil
    preview.damage = nil
    preview.effect = nil
    preview.collision = nil
    preview.objectiveImpact = nil
    preview.trigger = nil
    preview.branches = nil
    preview.anchor = nil
    preview.categoryOnly = true
    preview.footprintHidden = true
    preview.hiddenByVision = true
    return preview
end

function Intent.declare(state, unitId, intent)
    return state:declareIntent(unitId, intent)
end

function Intent.revealVisible(state, side)
    local visibility = state:fogGrid(side or "player")
    local revealed = {}
    for _, enemy in ipairs(state:unitsForSide("enemy")) do
        local intent = state.intents[enemy.id]
        if intent and intent.mode ~= "hiddenFootprint" and sourceVisible(state, enemy.id, side, visibility) then
            intent.revealed = true
            revealed[#revealed + 1] = enemy.id
        end
    end
    table.sort(revealed)
    return { side = side or "player", revealed = revealed, visibility = visibility }
end

function Intent.preview(state, unitId, options)
    options = options or {}
    local unit = state:unit(unitId)
    if unit and unit.side == "enemy" and options.ignoreVision ~= true then
        local reveal = Intent.revealVisible(state, options.side or "player")
        local intent = state.intents[unitId]
        if not sourceVisible(state, unitId, options.side or "player", reveal.visibility) and not (intent and intent.revealed == true) then
            local preview = state:intentPreview(unitId, options)
            return preview and categoryOnly(preview) or nil
        end
    end
    return state:intentPreview(unitId, options)
end

function Intent.activateEnemies(state)
    state:startTurn("enemy")
    return state:unitsForSide("enemy")
end

function Intent.select(state, unitId, choices, context)
    context = context or {}
    local index = context.index or 1
    local intent = choices and choices[index]
    return state:declareIntent(unitId, intent)
end

function Intent.resolve(state, unitId)
    local intent = state.intents[unitId]
    if not intent then
        return nil
    end
    local result
    if intent.mode == "fuse" then
        result = state:resolveIntentFuse(unitId, intent)
    elseif intent.mode == "conditional" then
        result = state:resolveConditionalIntent(unitId)
        return result
    else
        result = state:resolveIntentTrigger(unitId, intent, {
            kind = "damage",
            damage = intent.damage or 0,
            targetTiles = intent.targetTiles,
            target = intent.target,
        })
    end
    state.intents[unitId] = nil
    return result
end

function Intent.declareNextTurn(state, unitId, intent)
    return state:declareIntent(unitId, intent)
end

function Intent.interrupt(state, unitId, interrupt)
    return state:interruptIntent(unitId, interrupt)
end

function Intent.resolveConditional(state, unitId)
    return state:resolveConditionalIntent(unitId)
end

return Intent
