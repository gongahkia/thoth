local LoS = {}

function LoS.line(state, fromX, fromY, toX, toY)
    return state:lineOfSight(fromX, fromY, toX, toY)
end

function LoS.attackProfile(state, fromX, fromY, toX, toY)
    return state:attackProfile(fromX, fromY, toX, toY)
end

function LoS.movementPreview(state, unitId, options)
    return state:movementLosPreview(unitId, options)
end

return LoS
