local Cover = {}

function Cover.fromAttack(state, fromX, fromY, targetX, targetY)
    return state:coverFromAttack(fromX, fromY, targetX, targetY)
end

function Cover.flankFromAttack(state, fromX, fromY, targetX, targetY)
    return state:flankFromAttack(fromX, fromY, targetX, targetY)
end

function Cover.profile(state, fromX, fromY, targetX, targetY)
    return state:attackProfile(fromX, fromY, targetX, targetY)
end

return Cover
