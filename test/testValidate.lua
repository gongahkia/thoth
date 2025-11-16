-- Test file for validate module

local validate = require("src.validate")

print("=== Testing Validate Module ===\n")

-- Test Type Checking
print("Testing type checking...")
assert(validate.isType(42, "number"), "42 is a number")
assert(validate.isType("hello", "string"), "hello is a string")
assert(not validate.isType(42, "string"), "42 is not a string")

assert(validate.isNumber(42), "42 is number")
assert(validate.isString("test"), "test is string")
assert(validate.isTable({}), "{} is table")
assert(validate.isBoolean(true), "true is boolean")
assert(validate.isNil(nil), "nil is nil")

print("✓ Type checking works\n")

-- Test Number Validation
print("Testing number validation...")
assert(validate.isInteger(5), "5 is integer")
assert(not validate.isInteger(5.5), "5.5 is not integer")

assert(validate.isPositive(10), "10 is positive")
assert(not validate.isPositive(-5), "-5 is not positive")

assert(validate.isNonNegative(0), "0 is non-negative")
assert(validate.isNonNegative(5), "5 is non-negative")
assert(not validate.isNonNegative(-1), "-1 is not non-negative")

assert(validate.inRange(5, 1, 10), "5 is in range [1, 10]")
assert(not validate.inRange(15, 1, 10), "15 is not in range [1, 10]")

print("✓ Number validation works\n")

-- Test String Validation
print("Testing string validation...")
assert(validate.isNonEmptyString("hello"), "hello is non-empty")
assert(not validate.isNonEmptyString(""), "empty string is not non-empty")

assert(validate.matchesPattern("abc123", "^%a+%d+$"), "abc123 matches pattern")
assert(not validate.matchesPattern("123abc", "^%a+%d+$"), "123abc doesn't match")

assert(validate.isEmail("test@example.com"), "valid email")
assert(not validate.isEmail("notanemail"), "invalid email")

assert(validate.isAlphanumeric("abc123"), "abc123 is alphanumeric")
assert(not validate.isAlphanumeric("abc-123"), "abc-123 is not alphanumeric")

print("✓ String validation works\n")

-- Test Table Validation
print("Testing table validation...")
local arr = {1, 2, 3}
local obj = {a = 1, b = 2}

assert(validate.isArray(arr), "array is array")
assert(not validate.isArray(obj), "object is not array")

assert(validate.isNonEmptyTable(arr), "array is non-empty")
assert(not validate.isNonEmptyTable({}), "{} is empty")

assert(validate.hasKeys(obj, {"a", "b"}), "object has keys a, b")
assert(not validate.hasKeys(obj, {"a", "c"}), "object doesn't have key c")

print("✓ Table validation works\n")

-- Test Schema Validation
print("Testing schema validation...")

-- Number schema
local numberSchema = {
    type = "number",
    min = 0,
    max = 100
}

local valid, err = validate.schema(50, numberSchema)
assert(valid, "50 passes schema")

valid, err = validate.schema(150, numberSchema)
assert(not valid, "150 fails schema (too large)")
assert(err:find("maximum"), "error mentions maximum")

-- String schema
local stringSchema = {
    type = "string",
    minLength = 3,
    maxLength = 10,
    pattern = "^%a+$"
}

valid = validate.schema("hello", stringSchema)
assert(valid, "hello passes string schema")

valid = validate.schema("ab", stringSchema)
assert(not valid, "ab fails (too short)")

valid = validate.schema("hello123", stringSchema)
assert(not valid, "hello123 fails (doesn't match pattern)")

-- Object schema
local userSchema = {
    type = "table",
    properties = {
        name = {type = "string", required = true},
        age = {type = "number", min = 0, max = 150}
    }
}

local user = {name = "Alice", age = 30}
valid = validate.schema(user, userSchema)
assert(valid, "valid user passes schema")

local invalidUser = {name = "Bob", age = 200}
valid, err = validate.schema(invalidUser, userSchema)
assert(not valid, "invalid user fails schema")
assert(err:find("age"), "error mentions age")

-- Array schema
local arraySchema = {
    type = "table",
    items = {type = "number", min = 0}
}

valid = validate.schema({1, 2, 3}, arraySchema)
assert(valid, "array of positive numbers passes")

valid = validate.schema({1, -2, 3}, arraySchema)
assert(not valid, "array with negative number fails")

print("✓ Schema validation works\n")

-- Test Enum
print("Testing enum validation...")
local enumSchema = {
    enum = {"red", "green", "blue"}
}

valid = validate.schema("red", enumSchema)
assert(valid, "red is in enum")

valid = validate.schema("yellow", enumSchema)
assert(not valid, "yellow is not in enum")

print("✓ Enum validation works\n")

-- Test Custom Validator
print("Testing custom validator...")
local customSchema = {
    type = "number",
    validator = function(value)
        if value % 2 == 0 then
            return true
        else
            return false, "value must be even"
        end
    end
}

valid = validate.schema(4, customSchema)
assert(valid, "4 passes custom validator")

valid, err = validate.schema(5, customSchema)
assert(not valid, "5 fails custom validator")
assert(err:find("even"), "error mentions even")

print("✓ Custom validator works\n")

-- Test Contract Programming
print("Testing contract programming...")

local function divide(a, b)
    return a / b
end

local safeDivide = validate.contract(
    divide,
    function(a, b) -- precondition
        if b == 0 then
            return false, "divisor cannot be zero"
        end
        return true
    end,
    function(result, a, b) -- postcondition
        if result * b ~= a then
            return false, "result validation failed"
        end
        return true
    end
)

local result = safeDivide(10, 2)
assert(result == 5, "10 / 2 = 5")

-- This should error
local success = pcall(function()
    safeDivide(10, 0)
end)
assert(not success, "should fail on zero divisor")

print("✓ Contract programming works\n")

-- Test AssertType
print("Testing assertType...")
local ok = pcall(function()
    validate.assertType("hello", "string")
end)
assert(ok, "should not error for correct type")

ok = pcall(function()
    validate.assertType(42, "string", "myParam")
end)
assert(not ok, "should error for wrong type")

print("✓ AssertType works\n")

-- Test GetTypeInfo
print("Testing getTypeInfo...")
assert(validate.getTypeInfo(5) == "integer", "5 is integer")
assert(validate.getTypeInfo(5.5) == "float", "5.5 is float")
assert(validate.getTypeInfo({1, 2, 3}):find("array"), "array detection")
assert(validate.getTypeInfo({a = 1}):find("table"), "table detection")

print("✓ GetTypeInfo works\n")

print("=== All Validate Tests Passed ===")
