local api = {}

local function camelToSnake(name)
    local snake = name:gsub("([A-Z]+)([A-Z][a-z])", "%1_%2")
    snake = snake:gsub("([a-z0-9])([A-Z])", "%1_%2")
    return snake:lower()
end

function api.withSnakeCaseAliases(module, aliases)
    if type(module) ~= "table" then
        return module
    end

    for key, value in pairs(module) do
        if type(key) == "string" and key:match("^[A-Z]") then
            local alias = camelToSnake(key)
            if alias ~= key and module[alias] == nil then
                module[alias] = value
            end
        end
    end

    if aliases then
        for alias, key in pairs(aliases) do
            if module[alias] == nil and module[key] ~= nil then
                module[alias] = module[key]
            end
        end
    end

    return module
end

return api
