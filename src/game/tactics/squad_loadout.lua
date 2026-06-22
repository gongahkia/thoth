local ClassCatalog = require("src.game.tactics.class_catalog")

local SquadLoadout = {}

SquadLoadout.classOrder = { "warden", "duelist", "mender", "harrier", "arcanist", "lamplighter" }
SquadLoadout.rules = {
    squadSize = 6,
    allowDuplicateClasses = false,
    duplicatePolicy = "Mission 1 uses one unit from each implemented slice class; duplicate classes are rejected.",
}

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

local function classEntry(classId, index)
    local class = ClassCatalog.class(classId) or {}
    return {
        index = index,
        classId = classId,
        className = class.name or classId,
        unitId = unitIds[classId] or (classId .. tostring(index)),
        hp = hpByClass[classId] or 4,
        selected = true,
        loadoutIds = starterLoadoutIds(classId),
        routeRole = (ClassCatalog.starterRoster[index] or {}).routeRole,
        preview = (ClassCatalog.starterRoster[index] or {}).preview,
    }
end

function SquadLoadout.defaultSelection()
    local classes = {}
    local order = ClassCatalog.starterClassIds()
    if #order == 0 then
        order = SquadLoadout.classOrder
    end
    for index, classId in ipairs(order) do
        classes[#classes + 1] = classEntry(classId, index)
    end
    return {
        focus = 1,
        classes = classes,
        rules = SquadLoadout.rules,
        status = SquadLoadout.rules.duplicatePolicy,
    }
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
    selection.status = tostring(SquadLoadout.selectedCount(selection)) .. "/" .. tostring(SquadLoadout.rules.squadSize) .. " selected"
    return true
end

function SquadLoadout.validate(selection)
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
    if selected ~= SquadLoadout.rules.squadSize then
        return false, "select six distinct classes"
    end
    return true, nil
end

function SquadLoadout.ready(selection)
    local ok = SquadLoadout.validate(selection)
    return ok == true
end

function SquadLoadout.runtimeLoadout(selection)
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
            }
        end
    end
    return {
        allowDuplicateClasses = SquadLoadout.rules.allowDuplicateClasses,
        duplicatePolicy = SquadLoadout.rules.duplicatePolicy,
        units = units,
    }
end

function SquadLoadout.summary(selection)
    return {
        selected = SquadLoadout.selectedCount(selection),
        required = SquadLoadout.rules.squadSize,
        ready = SquadLoadout.ready(selection),
        allowDuplicateClasses = SquadLoadout.rules.allowDuplicateClasses,
        duplicatePolicy = SquadLoadout.rules.duplicatePolicy,
        classes = (selection and selection.classes) or {},
    }
end

return SquadLoadout
