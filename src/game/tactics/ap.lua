local AP = {}

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

return AP
