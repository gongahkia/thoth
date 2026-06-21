local Cover = {}

Cover.classes = {
    none = { edge = "none", damageReduction = 0, blocksDamage = false, blocksMovement = false, blocksLos = false },
    half = { edge = "half", damageReduction = 1, blocksDamage = false, blocksMovement = false, blocksLos = false },
    full = { edge = "full", damageReduction = 0, blocksDamage = true, blocksMovement = false, blocksLos = false },
    hard = { blockerKind = "hard", blocksDamage = true, blocksMovement = true, blocksLos = true },
    destructible = { blockerKind = "destructible", blocksDamage = true, blocksMovement = true, blocksLos = true, hpRequired = true },
    mobile = { blockerKind = "mobile", blocksDamage = false, blocksMovement = true, blocksLos = false, canMove = true },
}

function Cover.fromAttack(state, fromX, fromY, targetX, targetY)
    return state:coverFromAttack(fromX, fromY, targetX, targetY)
end

function Cover.flankFromAttack(state, fromX, fromY, targetX, targetY)
    return state:flankFromAttack(fromX, fromY, targetX, targetY)
end

function Cover.profile(state, fromX, fromY, targetX, targetY)
    return state:attackProfile(fromX, fromY, targetX, targetY)
end

local function targetTile(state, target)
    if type(target) == "string" then
        local unit = state:unit(target)
        return unit.x, unit.y
    end
    return target.x, target.y
end

function Cover.flankPreview(state, candidates, target)
    local targetX, targetY = targetTile(state, target)
    local result = {}
    for _, candidate in ipairs(candidates or {}) do
        local flank = state:flankFromAttack(candidate.x, candidate.y, targetX, targetY)
        local profile = state:attackProfile(candidate.x, candidate.y, targetX, targetY)
        result[#result + 1] = {
            x = candidate.x,
            y = candidate.y,
            targetX = targetX,
            targetY = targetY,
            flanked = flank.flanked,
            invalidated = flank.invalidated,
            cover = flank.cover,
            visible = profile.visible,
            effectiveCover = profile.effectiveCover,
            damageReduction = profile.damageReduction,
        }
    end
    return result
end

function Cover.class(id)
    return Cover.classes[id]
end

function Cover.allClasses()
    return Cover.classes
end

return Cover
