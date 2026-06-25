-- soldier bond cohesion + bond-level abilities (XCOM 2 War of the Chosen analog)
local Bonds = {}

Bonds.cohesionPerMission = 1.0
Bonds.maxCohesion = 10.0
Bonds.levelThresholds = { 10.0, 20.0, 30.0 } -- cohesion needed to reach bond level 1/2/3

Bonds.abilities = {
    { level = 1, id = "teamwork",    label = "teamwork",    description = "spend 1 AP to grant 1 AP to bondmate (once per mission)" },
    { level = 2, id = "spotter",     label = "spotter",     description = "+1 damage when attacking a target engaged by bondmate" },
    { level = 3, id = "dual_strike", label = "dual strike", description = "free attack from bondmate when you attack a shared target" },
}

local function pairKey(a, b)
    if a < b then return a .. "|" .. b end
    return b .. "|" .. a
end

function Bonds.new()
    return { pairs = {}, bondsByUnit = {} }
end

function Bonds.cohesion(state, a, b)
    if not state or not state.pairs then return 0 end
    local entry = state.pairs[pairKey(a, b)]
    return entry and entry.cohesion or 0
end

function Bonds.level(state, a, b)
    local c = Bonds.cohesion(state, a, b)
    local lvl = 0
    for i, threshold in ipairs(Bonds.levelThresholds) do
        if c >= threshold then lvl = i end
    end
    return lvl
end

function Bonds.gainCohesion(state, a, b, amount)
    if not state then return end
    state.pairs = state.pairs or {}
    local key = pairKey(a, b)
    local entry = state.pairs[key]
    if not entry then
        entry = { a = a, b = b, cohesion = 0, teamworkUsed = false }
        state.pairs[key] = entry
    end
    entry.cohesion = math.min(Bonds.maxCohesion * 3, entry.cohesion + (amount or Bonds.cohesionPerMission))
    state.bondsByUnit = state.bondsByUnit or {}
    state.bondsByUnit[a] = state.bondsByUnit[a] or {}
    state.bondsByUnit[a][b] = entry.cohesion
    state.bondsByUnit[b] = state.bondsByUnit[b] or {}
    state.bondsByUnit[b][a] = entry.cohesion
    return entry
end

function Bonds.resetTeamwork(state)
    if not state or not state.pairs then return end
    for _, entry in pairs(state.pairs) do
        entry.teamworkUsed = false
    end
end

function Bonds.useTeamwork(state, a, b)
    if not state or not state.pairs then return false, "no_bonds_state" end
    local entry = state.pairs[pairKey(a, b)]
    if not entry then return false, "no_bond" end
    if entry.cohesion < Bonds.levelThresholds[1] then return false, "bond_too_weak" end
    if entry.teamworkUsed then return false, "teamwork_consumed" end
    entry.teamworkUsed = true
    return true
end

function Bonds.onUnitDeath(state, unitId)
    if not state or not state.pairs then return {} end
    local consequences = {} -- list of { bondmate, stressGain }
    for _, entry in pairs(state.pairs) do
        if entry.a == unitId or entry.b == unitId then
            local survivor = (entry.a == unitId) and entry.b or entry.a
            local lvl = 0
            for i, threshold in ipairs(Bonds.levelThresholds) do
                if entry.cohesion >= threshold then lvl = i end
            end
            consequences[#consequences + 1] = { bondmate = survivor, stressGain = 2 + lvl, severed = true }
            entry.cohesion = 0 -- bond severed; survivor can re-bond after recovery
            entry.teamworkUsed = true
        end
    end
    return consequences
end

function Bonds.snapshot(state)
    if not state then return nil end
    local pairs_ = {}
    for k, entry in pairs(state.pairs or {}) do
        pairs_[k] = { a = entry.a, b = entry.b, cohesion = entry.cohesion, teamworkUsed = entry.teamworkUsed == true }
    end
    return { pairs = pairs_ }
end

function Bonds.fromSnapshot(snap)
    if not snap then return nil end
    local state = Bonds.new()
    for k, entry in pairs(snap.pairs or {}) do
        state.pairs[k] = { a = entry.a, b = entry.b, cohesion = entry.cohesion or 0, teamworkUsed = entry.teamworkUsed == true }
        state.bondsByUnit[entry.a] = state.bondsByUnit[entry.a] or {}
        state.bondsByUnit[entry.a][entry.b] = entry.cohesion
        state.bondsByUnit[entry.b] = state.bondsByUnit[entry.b] or {}
        state.bondsByUnit[entry.b][entry.a] = entry.cohesion
    end
    return state
end

return Bonds
