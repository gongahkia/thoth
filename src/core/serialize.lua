local Serialize = {}

local function sortedKeys(value)
    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then
            return a < b
        end
        return type(a) < type(b)
    end)
    return keys
end

local function isArray(value)
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
    end
    for i = 1, count do
        if value[i] == nil then
            return false
        end
    end
    return true
end

function Serialize.encode(value)
    local valueType = type(value)
    if valueType == "nil" then
        return "nil"
    end
    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end
    if valueType == "string" then
        return string.format("%q", value)
    end
    if valueType ~= "table" then
        error("cannot serialize " .. valueType)
    end

    local parts = {}
    if isArray(value) then
        for i = 1, #value do
            parts[#parts + 1] = Serialize.encode(value[i])
        end
    else
        for _, key in ipairs(sortedKeys(value)) do
            parts[#parts + 1] = "[" .. Serialize.encode(key) .. "]=" .. Serialize.encode(value[key])
        end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function Serialize.decode(text)
    local loader, err = loadstring("return " .. text)
    if not loader then
        return nil, err
    end
    local ok, result = pcall(loader)
    if not ok then
        return nil, result
    end
    return result
end

return Serialize
