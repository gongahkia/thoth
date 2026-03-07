local ecs = {}

local function matches(entity, criteria)
    if type(criteria) == "function" then
        return criteria(entity)
    end
    if type(criteria) ~= "table" then
        return true
    end
    for key, expected in pairs(criteria) do
        if entity[key] ~= expected then
            return false
        end
    end
    return true
end

function ecs.query(entities, criteria)
    local results = {}
    for _, entity in ipairs(entities) do
        if matches(entity, criteria) then
            results[#results + 1] = entity
        end
    end
    return results
end

function ecs.first(entities, criteria)
    for _, entity in ipairs(entities) do
        if matches(entity, criteria) then
            return entity
        end
    end
    return nil
end

function ecs.groupBy(entities, key)
    local groups = {}
    local resolver = type(key) == "function" and key or function(entity)
        return entity[key]
    end

    for _, entity in ipairs(entities) do
        local groupKey = resolver(entity)
        groups[groupKey] = groups[groupKey] or {}
        groups[groupKey][#groups[groupKey] + 1] = entity
    end

    return groups
end

function ecs.updateEach(entities, criteria, callback)
    for _, entity in ipairs(entities) do
        if matches(entity, criteria) then
            callback(entity)
        end
    end
end

function ecs.removeWhere(entities, criteria)
    local index = 1
    while index <= #entities do
        if matches(entities[index], criteria) then
            table.remove(entities, index)
        else
            index = index + 1
        end
    end
    return entities
end

return ecs
