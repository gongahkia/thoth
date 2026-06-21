local AP = {}

AP.costs = {
    move = 1,
    dash = 1,
    attack = 1,
    interact = 1,
    brace = 1,
    overwatch = 1,
    reload = 1,
    cooldown = 1,
    class_special = 1,
}

function AP.spend(state, unitId, amount)
    return state:spendAP(unitId, amount)
end

function AP.startTurn(state, side)
    return state:startTurn(side)
end

function AP.remaining(state, unitId)
    local unit = state:unit(unitId)
    return unit and unit.ap or nil
end

function AP.cost(action)
    return AP.costs[action]
end

function AP.allCosts()
    return AP.costs
end

return AP
