local path = {}

local function splitParts(input)
    local parts = {}
    for part in tostring(input):gmatch("[^/]+") do
        parts[#parts + 1] = part
    end
    return parts
end

function path.join(...)
    local parts = {}
    for i = 1, select('#', ...) do
        local value = select(i, ...)
        if value ~= nil and value ~= "" then
            for _, part in ipairs(splitParts(value)) do
                parts[#parts + 1] = part
            end
        end
    end
    return path.normalize(table.concat(parts, "/"))
end

function path.normalize(input)
    local absolute = tostring(input):sub(1, 1) == "/"
    local stack = {}
    for _, part in ipairs(splitParts(input)) do
        if part == "." then
        elseif part == ".." then
            if #stack > 0 and stack[#stack] ~= ".." then
                table.remove(stack)
            elseif not absolute then
                stack[#stack + 1] = part
            end
        else
            stack[#stack + 1] = part
        end
    end
    local normalized = table.concat(stack, "/")
    if absolute then
        normalized = "/" .. normalized
    end
    if normalized == "" then
        return absolute and "/" or "."
    end
    return normalized
end

function path.basename(input)
    local normalized = path.normalize(input)
    return normalized:match("([^/]+)$") or normalized
end

function path.dirname(input)
    local normalized = path.normalize(input)
    local dirname = normalized:match("^(.*)/[^/]*$")
    if dirname == nil or dirname == "" then
        return "."
    end
    return dirname
end

function path.extname(input)
    local base = path.basename(input)
    return base:match("(%.[^%.]+)$") or ""
end

return path
