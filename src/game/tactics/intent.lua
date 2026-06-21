local Intent = {}

function Intent.declare(state, unitId, intent)
    return state:declareIntent(unitId, intent)
end

function Intent.preview(state, unitId, options)
    return state:intentPreview(unitId, options)
end

function Intent.interrupt(state, unitId, interrupt)
    return state:interruptIntent(unitId, interrupt)
end

function Intent.resolveConditional(state, unitId)
    return state:resolveConditionalIntent(unitId)
end

return Intent
