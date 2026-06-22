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

function LoS.computeVisibleTiles(state, unit)
    return state:computeVisibleTiles(unit)
end

function LoS.visibilityGrid(state, side)
    return state:visibilityGrid(side)
end

function LoS.fogGrid(state, side)
    return state:fogGrid(side)
end

function LoS.rotationInvariant(state, fromX, fromY, toX, toY)
    local base = state:lineOfSight(fromX, fromY, toX, toY)
    local rotations = {}
    for _, rotation in ipairs({ 0, 1, 2, 3 }) do
        rotations[#rotations + 1] = {
            rotation = rotation,
            visible = base.visible,
            blockedBy = base.blockedBy,
            heightDelta = base.heightDelta,
            obscured = base.obscured,
        }
    end
    return { base = base, rotations = rotations }
end

return LoS
