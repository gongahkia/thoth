local config = {}

local function shallowCopy(tbl)
    local out = {}
    for key, value in pairs(tbl or {}) do
        out[key] = value
    end
    return out
end

function config.merge(defaults, overrides)
    local result = shallowCopy(defaults)
    for key, value in pairs(overrides or {}) do
        result[key] = value
    end
    return result
end

function config.getenv(name, default, env)
    env = env or {}
    local value = env[name]
    if value == nil and os and os.getenv then
        value = os.getenv(name)
    end
    if value == nil then
        return default
    end
    return value
end

function config.loadEnvFile(filename)
    local file, err = io.open(filename, "r")
    if not file then
        return nil, err
    end

    local values = {}
    for line in file:lines() do
        if not line:match("^%s*#") and not line:match("^%s*$") then
            local key, value = line:match("^%s*([%w_%.%-]+)%s*=%s*(.-)%s*$")
            if key then
                values[key] = value
            end
        end
    end
    file:close()
    return values
end

return config
