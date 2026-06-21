local Intent = {}

function Intent.declare(state, unitId, intent)
    return state:declareIntent(unitId, intent)
end

function Intent.preview(state, unitId, options)
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
