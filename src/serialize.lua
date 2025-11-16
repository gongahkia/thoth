-- =============================================
-- Serialization Module
-- JSON encoding/decoding, deep copy, table serialization
-- =============================================

local serialize = {}

-- =============================================
-- Deep Copy
-- =============================================

---Deep copy a table (handles circular references)
---@param original table Table to copy
---@param seen table|nil Internal parameter for tracking circular references
---@return table copy Deep copy of the table
function serialize.deepCopy(original, seen)
    if type(original) ~= "table" then
        return original
    end

    -- Handle circular references
    seen = seen or {}
    if seen[original] then
        return seen[original]
    end

    local copy = {}
    seen[original] = copy

    for key, value in pairs(original) do
        copy[serialize.deepCopy(key, seen)] = serialize.deepCopy(value, seen)
    end

    -- Copy metatable if it exists
    local mt = getmetatable(original)
    if mt then
        setmetatable(copy, serialize.deepCopy(mt, seen))
    end

    return copy
end

-- =============================================
-- JSON Encoder
-- =============================================

---Encode a value to JSON string
---@param value any Value to encode
---@param indent number|nil Indentation level (for pretty printing)
---@param currentIndent number|nil Internal parameter
---@return string json JSON string
function serialize.toJSON(value, indent, currentIndent)
    indent = indent or 0
    currentIndent = currentIndent or 0

    local valueType = type(value)

    -- Nil
    if valueType == "nil" then
        return "null"
    end

    -- Boolean
    if valueType == "boolean" then
        return value and "true" or "false"
    end

    -- Number
    if valueType == "number" then
        if value ~= value then
            return "null" -- NaN
        elseif value == math.huge then
            return "null" -- Infinity
        elseif value == -math.huge then
            return "null" -- -Infinity
        else
            return tostring(value)
        end
    end

    -- String
    if valueType == "string" then
        -- Escape special characters
        local escaped = value:gsub('\\', '\\\\')
                            :gsub('"', '\\"')
                            :gsub('\n', '\\n')
                            :gsub('\r', '\\r')
                            :gsub('\t', '\\t')
        return '"' .. escaped .. '"'
    end

    -- Table (object or array)
    if valueType == "table" then
        local isArray = true
        local maxIndex = 0

        -- Check if it's an array
        for key, _ in pairs(value) do
            if type(key) ~= "number" or key <= 0 or key ~= math.floor(key) then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, key)
        end

        -- Also check for holes in array
        if isArray then
            for i = 1, maxIndex do
                if value[i] == nil then
                    isArray = false
                    break
                end
            end
        end

        local indentStr = string.rep(" ", currentIndent)
        local nextIndentStr = string.rep(" ", currentIndent + indent)

        if isArray then
            -- Encode as JSON array
            local parts = {}

            for i = 1, maxIndex do
                local encoded = serialize.toJSON(value[i], indent, currentIndent + indent)
                if indent > 0 then
                    table.insert(parts, nextIndentStr .. encoded)
                else
                    table.insert(parts, encoded)
                end
            end

            if indent > 0 and #parts > 0 then
                return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indentStr .. "]"
            else
                return "[" .. table.concat(parts, ",") .. "]"
            end
        else
            -- Encode as JSON object
            local parts = {}

            for key, val in pairs(value) do
                if type(key) == "string" then
                    local encodedKey = serialize.toJSON(key)
                    local encodedVal = serialize.toJSON(val, indent, currentIndent + indent)

                    if indent > 0 then
                        table.insert(parts, nextIndentStr .. encodedKey .. ": " .. encodedVal)
                    else
                        table.insert(parts, encodedKey .. ":" .. encodedVal)
                    end
                end
            end

            if indent > 0 and #parts > 0 then
                return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indentStr .. "}"
            else
                return "{" .. table.concat(parts, ",") .. "}"
            end
        end
    end

    -- Unsupported type
    return "null"
end

-- =============================================
-- JSON Decoder
-- =============================================

---Decode a JSON string to Lua value
---@param json string JSON string
---@return any|nil value Decoded value or nil on error
---@return string|nil error Error message if decoding failed
function serialize.fromJSON(json)
    local pos = 1

    -- Skip whitespace
    local function skipWhitespace()
        while pos <= #json do
            local char = json:sub(pos, pos)
            if char ~= " " and char ~= "\t" and char ~= "\n" and char ~= "\r" then
                break
            end
            pos = pos + 1
        end
    end

    -- Parse string
    local function parseString()
        local result = ""
        pos = pos + 1 -- Skip opening quote

        while pos <= #json do
            local char = json:sub(pos, pos)

            if char == '"' then
                pos = pos + 1
                return result
            elseif char == "\\" then
                pos = pos + 1
                local escapeChar = json:sub(pos, pos)

                if escapeChar == "n" then
                    result = result .. "\n"
                elseif escapeChar == "r" then
                    result = result .. "\r"
                elseif escapeChar == "t" then
                    result = result .. "\t"
                elseif escapeChar == '"' then
                    result = result .. '"'
                elseif escapeChar == "\\" then
                    result = result .. "\\"
                else
                    result = result .. escapeChar
                end

                pos = pos + 1
            else
                result = result .. char
                pos = pos + 1
            end
        end

        return nil, "Unterminated string"
    end

    -- Parse number
    local function parseNumber()
        local startPos = pos
        local hasDecimal = false

        if json:sub(pos, pos) == "-" then
            pos = pos + 1
        end

        while pos <= #json do
            local char = json:sub(pos, pos)

            if char:match("[0-9]") then
                pos = pos + 1
            elseif char == "." and not hasDecimal then
                hasDecimal = true
                pos = pos + 1
            elseif char == "e" or char == "E" then
                pos = pos + 1
                if json:sub(pos, pos) == "+" or json:sub(pos, pos) == "-" then
                    pos = pos + 1
                end
            else
                break
            end
        end

        local numStr = json:sub(startPos, pos - 1)
        return tonumber(numStr)
    end

    -- Forward declaration
    local parseValue

    -- Parse array
    local function parseArray()
        local result = {}
        pos = pos + 1 -- Skip '['

        skipWhitespace()

        if json:sub(pos, pos) == "]" then
            pos = pos + 1
            return result
        end

        while true do
            local value, err = parseValue()
            if err then
                return nil, err
            end

            table.insert(result, value)
            skipWhitespace()

            local char = json:sub(pos, pos)
            if char == "]" then
                pos = pos + 1
                return result
            elseif char == "," then
                pos = pos + 1
                skipWhitespace()
            else
                return nil, "Expected ',' or ']' in array"
            end
        end
    end

    -- Parse object
    local function parseObject()
        local result = {}
        pos = pos + 1 -- Skip '{'

        skipWhitespace()

        if json:sub(pos, pos) == "}" then
            pos = pos + 1
            return result
        end

        while true do
            skipWhitespace()

            if json:sub(pos, pos) ~= '"' then
                return nil, "Expected string key in object"
            end

            local key, err = parseString()
            if err then
                return nil, err
            end

            skipWhitespace()

            if json:sub(pos, pos) ~= ":" then
                return nil, "Expected ':' after key in object"
            end

            pos = pos + 1
            skipWhitespace()

            local value
            value, err = parseValue()
            if err then
                return nil, err
            end

            result[key] = value
            skipWhitespace()

            local char = json:sub(pos, pos)
            if char == "}" then
                pos = pos + 1
                return result
            elseif char == "," then
                pos = pos + 1
            else
                return nil, "Expected ',' or '}' in object"
            end
        end
    end

    -- Parse value
    parseValue = function()
        skipWhitespace()

        if pos > #json then
            return nil, "Unexpected end of JSON"
        end

        local char = json:sub(pos, pos)

        -- String
        if char == '"' then
            return parseString()
        end

        -- Number
        if char:match("[0-9%-]") then
            return parseNumber()
        end

        -- Array
        if char == "[" then
            return parseArray()
        end

        -- Object
        if char == "{" then
            return parseObject()
        end

        -- true
        if json:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        end

        -- false
        if json:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        end

        -- null
        if json:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end

        return nil, "Unexpected character: " .. char
    end

    return parseValue()
end

-- =============================================
-- Lua Table Serialization
-- =============================================

---Serialize a Lua table to a string that can be loaded back
---@param tbl table Table to serialize
---@param name string|nil Variable name
---@param indent number|nil Indentation level
---@return string serialized Lua code string
function serialize.toLua(tbl, name, indent)
    indent = indent or 0
    local indentStr = string.rep("  ", indent)

    if type(tbl) ~= "table" then
        if type(tbl) == "string" then
            return string.format("%q", tbl)
        else
            return tostring(tbl)
        end
    end

    local result = {}
    local prefix = name and (name .. " = ") or ""

    table.insert(result, prefix .. "{")

    for key, value in pairs(tbl) do
        local keyStr

        if type(key) == "string" and key:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
            keyStr = key
        elseif type(key) == "string" then
            keyStr = "[" .. string.format("%q", key) .. "]"
        else
            keyStr = "[" .. tostring(key) .. "]"
        end

        local valueStr
        if type(value) == "table" then
            valueStr = serialize.toLua(value, nil, indent + 1)
        elseif type(value) == "string" then
            valueStr = string.format("%q", value)
        else
            valueStr = tostring(value)
        end

        table.insert(result, indentStr .. "  " .. keyStr .. " = " .. valueStr .. ",")
    end

    table.insert(result, indentStr .. "}")

    return table.concat(result, "\n")
end

-- =============================================
-- File I/O Helpers
-- =============================================

---Save a table to a JSON file
---@param filename string File path
---@param data table Data to save
---@param pretty boolean|nil Whether to pretty-print (default: false)
---@return boolean success
---@return string|nil error Error message if failed
function serialize.saveJSON(filename, data, pretty)
    local json = serialize.toJSON(data, pretty and 2 or 0)

    local file, err = io.open(filename, "w")
    if not file then
        return false, err
    end

    file:write(json)
    file:close()

    return true
end

---Load a table from a JSON file
---@param filename string File path
---@return table|nil data Loaded data or nil on error
---@return string|nil error Error message if failed
function serialize.loadJSON(filename)
    local file, err = io.open(filename, "r")
    if not file then
        return nil, err
    end

    local content = file:read("*all")
    file:close()

    return serialize.fromJSON(content)
end

---Save a table to a Lua file
---@param filename string File path
---@param data table Data to save
---@param varName string|nil Variable name (default: "data")
---@return boolean success
---@return string|nil error Error message if failed
function serialize.saveLua(filename, data, varName)
    varName = varName or "data"
    local luaStr = serialize.toLua(data, varName)

    local file, err = io.open(filename, "w")
    if not file then
        return false, err
    end

    file:write("return " .. luaStr)
    file:close()

    return true
end

---Load a table from a Lua file
---@param filename string File path
---@return table|nil data Loaded data or nil on error
---@return string|nil error Error message if failed
function serialize.loadLua(filename)
    local chunk, err = loadfile(filename)
    if not chunk then
        return nil, err
    end

    local success, result = pcall(chunk)
    if not success then
        return nil, result
    end

    return result
end

return serialize
