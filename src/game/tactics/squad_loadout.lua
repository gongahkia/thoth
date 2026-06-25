local ClassCatalog = require("src.game.tactics.class_catalog")
local Identity = require("src.game.tactics.identity")

local SquadLoadout = {}

SquadLoadout.classOrder = { "warden", "duelist", "mender", "harrier", "arcanist", "lamplighter" }
SquadLoadout.missionRules = {
    tutorial = {
        missionId = "tutorial",
        missionLabel = "mission 0",
        squadSize = 1,
        allowDuplicateClasses = false,
        duplicatePolicy = "Tutorial mission uses one Warden.",
        requiredMessage = "select one tutorial class",
    },
    mission1 = {
        missionId = "mission1",
        missionLabel = "mission 1",
        squadSize = 6,
        allowDuplicateClasses = false,
        duplicatePolicy = "Mission 1 uses one unit from each implemented slice class; duplicate classes are rejected.",
        requiredMessage = "select six distinct classes",
    },
}
SquadLoadout.rules = SquadLoadout.missionRules.mission1

local tutorialClassOrder = { "warden" }

local function rulesFor(selection)
    return (selection and selection.rules) or SquadLoadout.rules
end

local function duplicateLabel(rules)
    return rules.allowDuplicateClasses and "duplicates on" or "duplicates off"
end

function SquadLoadout.duplicateLabel(selection)
    return duplicateLabel(rulesFor(selection))
end

function SquadLoadout.missionLabel(selection)
    return rulesFor(selection).missionLabel or "mission 1"
end

function SquadLoadout.requiredMessage(selection)
    local rules = rulesFor(selection)
    return rules.requiredMessage or ("select " .. tostring(rules.squadSize) .. " distinct classes")
end

function SquadLoadout.rulesForMission(missionId)
    return SquadLoadout.missionRules[missionId or "mission1"] or SquadLoadout.rules
end

function SquadLoadout.classOrderForMission(missionId)
    if missionId == "tutorial" then
        return tutorialClassOrder
    end
    return ClassCatalog.starterClassIds()
end

local unitIds = {
    warden = "warden",
    duelist = "duelist",
    mender = "apothecary",
    harrier = "thief",
    arcanist = "arcanist",
    lamplighter = "lamplighter",
}

local hpByClass = {
    warden = 6,
    duelist = 5,
    mender = 4,
    harrier = 4,
    arcanist = 4,
    lamplighter = 4,
}

local function copyList(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[#result + 1] = value
    end
    return result
end

local function starterLoadoutIds(classId)
    local result = {}
    for _, loadout in ipairs(ClassCatalog.starterLoadouts(classId)) do
        result[#result + 1] = loadout.id
    end
    if #result > 0 then
        return result
    end
    for index, loadout in ipairs(ClassCatalog.loadouts(classId)) do
        if index > (ClassCatalog.loadoutSlots(classId) or 2) then
            break
        end
        result[#result + 1] = loadout.id
    end
    return result
end

local function starterRosterEntry(classId)
    for _, entry in ipairs(ClassCatalog.starterRoster or {}) do
        if entry.classId == classId then
            return entry
        end
    end
    return nil
end

local function classEntry(classId, index, seed)
    local class = ClassCatalog.class(classId) or {}
    local starter = starterRosterEntry(classId) or {}
    local identity = Identity.generate(seed or index, classId)
    return {
        index = index,
        classId = classId,
        className = class.name or classId,
        unitId = unitIds[classId] or (classId .. tostring(index)),
        hp = hpByClass[classId] or 4,
        selected = true,
        loadoutIds = starterLoadoutIds(classId),
        routeRole = starter.routeRole,
        preview = starter.preview,
        identity = identity,
    }
end

function SquadLoadout.defaultSelection(options)
    if type(options) == "string" then
        options = { missionId = options }
    end
    options = options or {}
    local missionId = options.missionId or "mission1"
    local rules = SquadLoadout.rulesForMission(missionId)
    local classes = {}
    local order = SquadLoadout.classOrderForMission(missionId)
    if #order == 0 then
        order = SquadLoadout.classOrder
    end
    local seed = options.seed or 1
    for index, classId in ipairs(order) do
        classes[#classes + 1] = classEntry(classId, index, seed + index)
    end
    return {
        focus = 1,
        classes = classes,
        rules = rules,
        status = rules.duplicatePolicy,
    }
end

function SquadLoadout.tutorialSelection()
    return SquadLoadout.defaultSelection({ missionId = "tutorial" })
end

function SquadLoadout.selectedCount(selection)
    local count = 0
    for _, entry in ipairs((selection and selection.classes) or {}) do
        if entry.selected then
            count = count + 1
        end
    end
    return count
end

function SquadLoadout.moveFocus(selection, delta)
    local classes = selection and selection.classes or {}
    if #classes == 0 then
        return nil
    end
    selection.focus = ((selection.focus or 1) - 1 + delta) % #classes + 1
    return classes[selection.focus]
end

function SquadLoadout.toggle(selection, index)
    local entry = selection and selection.classes and selection.classes[index or selection.focus or 1]
    if not entry then
        return false
    end
    entry.selected = not entry.selected
    local rules = rulesFor(selection)
    selection.status = tostring(SquadLoadout.selectedCount(selection)) .. "/" .. tostring(rules.squadSize) .. " selected"
    return true
end

function SquadLoadout.validate(selection)
    local rules = rulesFor(selection)
    local seen = {}
    local selected = 0
    for _, entry in ipairs((selection and selection.classes) or {}) do
        if entry.selected then
            selected = selected + 1
            if seen[entry.classId] then
                return false, "duplicate class " .. tostring(entry.classId)
            end
            seen[entry.classId] = true
            if #(entry.loadoutIds or {}) ~= ClassCatalog.loadoutSlots(entry.classId) then
                return false, "loadout slots missing for " .. tostring(entry.classId)
            end
            for _, loadoutId in ipairs(entry.loadoutIds or {}) do
                if not ClassCatalog.loadout(entry.classId, loadoutId) then
                    return false, "unknown loadout " .. tostring(loadoutId)
                end
            end
        end
    end
    if selected ~= rules.squadSize then
        return false, SquadLoadout.requiredMessage(selection)
    end
    return true, nil
end

function SquadLoadout.ready(selection)
    local ok = SquadLoadout.validate(selection)
    return ok == true
end

function SquadLoadout.runtimeLoadout(selection)
    local rules = rulesFor(selection)
    local ok, err = SquadLoadout.validate(selection)
    if not ok then
        return nil, err
    end
    local units = {}
    for _, entry in ipairs(selection.classes or {}) do
        if entry.selected then
            units[#units + 1] = {
                id = entry.unitId,
                classId = entry.classId,
                hp = entry.hp,
                loadoutIds = copyList(entry.loadoutIds),
                name = entry.identity and entry.identity.name,
                portrait = entry.identity and entry.identity.portrait,
                quirks = entry.identity and copyList(entry.identity.quirks),
            }
        end
    end
    return {
        missionId = rules.missionId,
        missionLabel = rules.missionLabel,
        allowDuplicateClasses = rules.allowDuplicateClasses,
        duplicatePolicy = rules.duplicatePolicy,
        units = units,
    }
end

function SquadLoadout.summary(selection)
    local rules = rulesFor(selection)
    return {
        selected = SquadLoadout.selectedCount(selection),
        required = rules.squadSize,
        ready = SquadLoadout.ready(selection),
        missionId = rules.missionId,
        missionLabel = rules.missionLabel,
        allowDuplicateClasses = rules.allowDuplicateClasses,
        duplicatePolicy = rules.duplicatePolicy,
        duplicateLabel = duplicateLabel(rules),
        classes = (selection and selection.classes) or {},
    }
end

return SquadLoadout
