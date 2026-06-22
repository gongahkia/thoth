local AP = {}

AP.squadEconomy = {
    targetSquadSize = 6,
    minTurnAp = 18,
    maxTurnAp = 24,
    defaultUnitAp = 3,
}

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

function AP.defaultUnitApForSquad()
    return AP.squadEconomy.defaultUnitAp
end

function AP.turnBudgetForState(state, side)
    local total = 0
    for _, unit in ipairs(state:unitsForSide(side or "player")) do
        total = total + (unit.maxAp or unit.ap or state.rules.defaultAp or AP.squadEconomy.defaultUnitAp)
    end
    return total
end

function AP.auditTurnBudget(state, side)
    local total = AP.turnBudgetForState(state, side or "player")
    return {
        ok = total >= AP.squadEconomy.minTurnAp and total <= AP.squadEconomy.maxTurnAp,
        total = total,
        min = AP.squadEconomy.minTurnAp,
        max = AP.squadEconomy.maxTurnAp,
        side = side or "player",
    }
end

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
