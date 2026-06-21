local Unit = {}

function Unit.select(state, unitId)
    return state:selectUnit(unitId)
end

function Unit.forSide(state, side)
    return state:unitsForSide(side)
end

function Unit.at(state, x, y)
    return state:unitAt(x, y)
end

function Unit.move(state, unitId, direction)
    state:apply(state.commands.move(unitId, direction))
    return state:unit(unitId)
end

return Unit
