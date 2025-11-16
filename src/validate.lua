-- =============================================
-- Validation and Type Checking Module
-- Runtime type checking and contract programming
-- =============================================

local validate = {}

-- =============================================
-- Type Checking
-- =============================================

---Check if value matches expected type
---@param value any Value to check
---@param expectedType string Expected type name
---@return boolean matches Whether type matches
function validate.isType(value, expectedType)
    return type(value) == expectedType
end

---Assert that value matches expected type (throws error if not)
---@param value any Value to check
---@param expectedType string Expected type name
---@param paramName string|nil Parameter name for error message
function validate.assertType(value, expectedType, paramName)
    if type(value) ~= expectedType then
        local name = paramName and ("'" .. paramName .. "' ") or ""
        error(string.format("Type error: %sexpected %s, got %s", name, expectedType, type(value)))
    end
end

---Check if value is a number
---@param value any Value to check
---@return boolean isNumber
function validate.isNumber(value)
    return type(value) == "number"
end

---Check if value is a string
---@param value any Value to check
---@return boolean isString
function validate.isString(value)
    return type(value) == "string"
end

---Check if value is a table
---@param value any Value to check
---@return boolean isTable
function validate.isTable(value)
    return type(value) == "table"
end

---Check if value is a function
---@param value any Value to check
---@return boolean isFunction
function validate.isFunction(value)
    return type(value) == "function"
end

---Check if value is a boolean
---@param value any Value to check
---@return boolean isBoolean
function validate.isBoolean(value)
    return type(value) == "boolean"
end

---Check if value is nil
---@param value any Value to check
---@return boolean isNil
function validate.isNil(value)
    return value == nil
end

-- =============================================
-- Number Validation
-- =============================================

---Check if value is an integer
---@param value any Value to check
---@return boolean isInteger
function validate.isInteger(value)
    return type(value) == "number" and math.floor(value) == value
end

---Check if value is a positive number
---@param value any Value to check
---@return boolean isPositive
function validate.isPositive(value)
    return type(value) == "number" and value > 0
end

---Check if value is a non-negative number
---@param value any Value to check
---@return boolean isNonNegative
function validate.isNonNegative(value)
    return type(value) == "number" and value >= 0
end

---Check if value is within range (inclusive)
---@param value any Value to check
---@param min number Minimum value
---@param max number Maximum value
---@return boolean inRange
function validate.inRange(value, min, max)
    return type(value) == "number" and value >= min and value <= max
end

---Assert that value is a number in range
---@param value any Value to check
---@param min number Minimum value
---@param max number Maximum value
---@param paramName string|nil Parameter name
function validate.assertInRange(value, min, max, paramName)
    if not validate.inRange(value, min, max) then
        local name = paramName and ("'" .. paramName .. "' ") or ""
        error(string.format("Range error: %smust be between %s and %s, got %s", name, min, max, tostring(value)))
    end
end

-- =============================================
-- String Validation
-- =============================================

---Check if string is not empty
---@param value any Value to check
---@return boolean notEmpty
function validate.isNonEmptyString(value)
    return type(value) == "string" and #value > 0
end

---Check if string matches pattern
---@param value any Value to check
---@param pattern string Lua pattern
---@return boolean matches
function validate.matchesPattern(value, pattern)
    if type(value) ~= "string" then
        return false
    end
    return value:match(pattern) ~= nil
end

---Check if string is a valid email (basic check)
---@param value any Value to check
---@return boolean isEmail
function validate.isEmail(value)
    if type(value) ~= "string" then
        return false
    end
    return value:match("^[%w%._%+%-]+@[%w%.%-]+%.[%a]+$") ~= nil
end

---Check if string contains only alphanumeric characters
---@param value any Value to check
---@return boolean isAlphanumeric
function validate.isAlphanumeric(value)
    if type(value) ~= "string" then
        return false
    end
    return value:match("^[%w]+$") ~= nil
end

-- =============================================
-- Table Validation
-- =============================================

---Check if table is an array (has consecutive integer keys starting from 1)
---@param value any Value to check
---@return boolean isArray
function validate.isArray(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    local maxIndex = 0

    for key, _ in pairs(value) do
        if type(key) ~= "number" or key <= 0 or key ~= math.floor(key) then
            return false
        end
        count = count + 1
        maxIndex = math.max(maxIndex, key)
    end

    return count == maxIndex
end

---Check if table is not empty
---@param value any Value to check
---@return boolean notEmpty
function validate.isNonEmptyTable(value)
    return type(value) == "table" and next(value) ~= nil
end

---Check if table has specific keys
---@param value any Value to check
---@param keys table Array of required key names
---@return boolean hasKeys
function validate.hasKeys(value, keys)
    if type(value) ~= "table" then
        return false
    end

    for _, key in ipairs(keys) do
        if value[key] == nil then
            return false
        end
    end

    return true
end

---Assert that table has specific keys
---@param value any Value to check
---@param keys table Array of required key names
---@param paramName string|nil Parameter name
function validate.assertHasKeys(value, keys, paramName)
    if not validate.hasKeys(value, keys) then
        local name = paramName and ("'" .. paramName .. "' ") or ""
        local keyList = table.concat(keys, ", ")
        error(string.format("Key error: %smissing required keys: %s", name, keyList))
    end
end

-- =============================================
-- Schema Validation
-- =============================================

---Validate value against a schema
---@param value any Value to validate
---@param schema table Schema definition
---@return boolean valid Whether validation passed
---@return string|nil error Error message if validation failed
function validate.schema(value, schema)
    -- Type validation
    if schema.type then
        if type(value) ~= schema.type then
            return false, string.format("Expected type %s, got %s", schema.type, type(value))
        end
    end

    -- Required validation
    if schema.required and value == nil then
        return false, "Value is required but got nil"
    end

    -- Number validations
    if type(value) == "number" then
        if schema.min and value < schema.min then
            return false, string.format("Value %s is less than minimum %s", value, schema.min)
        end

        if schema.max and value > schema.max then
            return false, string.format("Value %s is greater than maximum %s", value, schema.max)
        end

        if schema.integer and math.floor(value) ~= value then
            return false, "Value must be an integer"
        end
    end

    -- String validations
    if type(value) == "string" then
        if schema.minLength and #value < schema.minLength then
            return false, string.format("String length %s is less than minimum %s", #value, schema.minLength)
        end

        if schema.maxLength and #value > schema.maxLength then
            return false, string.format("String length %s is greater than maximum %s", #value, schema.maxLength)
        end

        if schema.pattern and not value:match(schema.pattern) then
            return false, string.format("String does not match pattern %s", schema.pattern)
        end
    end

    -- Array validation
    if type(value) == "table" and schema.items then
        if not validate.isArray(value) then
            return false, "Value must be an array"
        end

        for i, item in ipairs(value) do
            local valid, err = validate.schema(item, schema.items)
            if not valid then
                return false, string.format("Item at index %s: %s", i, err)
            end
        end
    end

    -- Object validation
    if type(value) == "table" and schema.properties then
        for key, propSchema in pairs(schema.properties) do
            local valid, err = validate.schema(value[key], propSchema)
            if not valid then
                return false, string.format("Property '%s': %s", key, err)
            end
        end
    end

    -- Enum validation
    if schema.enum then
        local found = false
        for _, enumValue in ipairs(schema.enum) do
            if value == enumValue then
                found = true
                break
            end
        end

        if not found then
            return false, "Value not in enum"
        end
    end

    -- Custom validator
    if schema.validator and type(schema.validator) == "function" then
        local valid, err = schema.validator(value)
        if not valid then
            return false, err or "Custom validation failed"
        end
    end

    return true
end

-- =============================================
-- Contract Programming (Pre/Post Conditions)
-- =============================================

---Create a function wrapper with preconditions and postconditions
---@param func function Function to wrap
---@param precondition function|nil Precondition function(args...)
---@param postcondition function|nil Postcondition function(result, args...)
---@return function wrapped Wrapped function with contracts
function validate.contract(func, precondition, postcondition)
    return function(...)
        local args = {...}

        -- Check precondition
        if precondition then
            local ok, err = precondition(...)
            if not ok then
                error("Precondition failed: " .. (err or "unknown error"))
            end
        end

        -- Execute function
        local results = {func(...)}

        -- Check postcondition
        if postcondition then
            local ok, err = postcondition(results[1], ...)
            if not ok then
                error("Postcondition failed: " .. (err or "unknown error"))
            end
        end

        return table.unpack(results)
    end
end

-- =============================================
-- Utility Functions
-- =============================================

---Create a validator function from a schema
---@param schema table Schema definition
---@return function validator Validator function(value)
function validate.createValidator(schema)
    return function(value)
        return validate.schema(value, schema)
    end
end

---Get detailed type information about a value
---@param value any Value to inspect
---@return string typeInfo Type information string
function validate.getTypeInfo(value)
    local t = type(value)

    if t == "table" then
        if validate.isArray(value) then
            return "array[" .. #value .. "]"
        else
            local count = 0
            for _ in pairs(value) do
                count = count + 1
            end
            return "table{" .. count .. " keys}"
        end
    elseif t == "number" then
        if validate.isInteger(value) then
            return "integer"
        else
            return "float"
        end
    else
        return t
    end
end

-- =============================================
-- Example Schemas (commented out)
-- =============================================

--[[
-- Example: User schema
local userSchema = {
    type = "table",
    required = true,
    properties = {
        name = {
            type = "string",
            required = true,
            minLength = 1,
            maxLength = 100
        },
        age = {
            type = "number",
            required = true,
            integer = true,
            min = 0,
            max = 150
        },
        email = {
            type = "string",
            pattern = "^[%w%._%+%-]+@[%w%.%-]+%.[%a]+$"
        }
    }
}

-- Validate a user
local user = {
    name = "John Doe",
    age = 30,
    email = "john@example.com"
}

local valid, err = validate.schema(user, userSchema)
if not valid then
    print("Validation error: " .. err)
end
]]

return validate
