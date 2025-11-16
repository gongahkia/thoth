-- Test file for serialize module

local serialize = require("src.serialize")

print("=== Testing Serialize Module ===\n")

-- Test DeepCopy
print("Testing deepCopy...")
local original = {
    name = "John",
    age = 30,
    skills = {"Lua", "Python", "JavaScript"},
    address = {
        city = "New York",
        zip = "10001"
    }
}

local copy = serialize.deepCopy(original)

assert(copy.name == "John", "Should copy simple values")
assert(copy.skills[1] == "Lua", "Should copy arrays")
assert(copy.address.city == "New York", "Should deep copy nested tables")

-- Test deep copy independence
copy.name = "Jane"
copy.skills[1] = "Go"
copy.address.city = "Boston"

assert(original.name == "John", "Original should be unchanged")
assert(original.skills[1] == "Lua", "Original array should be unchanged")
assert(original.address.city == "New York", "Original nested table should be unchanged")

print("✓ DeepCopy works\n")

-- Test Circular References
print("Testing deepCopy with circular references...")
local circular = {value = 1}
circular.self = circular

local circularCopy = serialize.deepCopy(circular)
assert(circularCopy.value == 1, "Should copy value")
assert(circularCopy.self == circularCopy, "Should handle circular reference")
print("✓ Circular references handled\n")

-- Test JSON Encoding
print("Testing toJSON...")

-- Simple values
assert(serialize.toJSON(nil) == "null", "nil should be null")
assert(serialize.toJSON(true) == "true", "true should be true")
assert(serialize.toJSON(false) == "false", "false should be false")
assert(serialize.toJSON(42) == "42", "number should work")
assert(serialize.toJSON("hello") == '"hello"', "string should work")

-- Array
local arr = {1, 2, 3}
local jsonArr = serialize.toJSON(arr)
assert(jsonArr == "[1,2,3]", "array should work")
print("JSON array: " .. jsonArr)

-- Object
local obj = {name = "Alice", age = 25}
local jsonObj = serialize.toJSON(obj)
print("JSON object: " .. jsonObj)
assert(jsonObj:find('"name"'), "should have name field")

-- Nested
local nested = {
    user = {
        name = "Bob",
        scores = {10, 20, 30}
    }
}
local jsonNested = serialize.toJSON(nested)
print("JSON nested: " .. jsonNested)

-- Pretty print
local pretty = serialize.toJSON(nested, 2)
print("JSON pretty:\n" .. pretty)

print("✓ toJSON works\n")

-- Test JSON Decoding
print("Testing fromJSON...")

-- Simple values
local val, err = serialize.fromJSON("null")
assert(val == nil and err == nil, "should parse null")

val = serialize.fromJSON("true")
assert(val == true, "should parse true")

val = serialize.fromJSON("false")
assert(val == false, "should parse false")

val = serialize.fromJSON("42")
assert(val == 42, "should parse number")

val = serialize.fromJSON('"hello"')
assert(val == "hello", "should parse string")

-- Array
val = serialize.fromJSON('[1, 2, 3]')
assert(#val == 3, "should parse array")
assert(val[1] == 1 and val[3] == 3, "should have correct values")

-- Object
val = serialize.fromJSON('{"name": "Alice", "age": 25}')
assert(val.name == "Alice", "should parse object")
assert(val.age == 25, "should have correct values")

-- Nested
val = serialize.fromJSON('{"user": {"name": "Bob", "scores": [10, 20, 30]}}')
assert(val.user.name == "Bob", "should parse nested")
assert(val.user.scores[2] == 20, "should parse nested array")

print("✓ fromJSON works\n")

-- Test Round-trip
print("Testing JSON round-trip...")
local data = {
    string = "test",
    number = 123,
    boolean = true,
    array = {1, 2, 3},
    object = {key = "value"}
}

local json = serialize.toJSON(data)
local decoded = serialize.fromJSON(json)

assert(decoded.string == "test", "string should survive round-trip")
assert(decoded.number == 123, "number should survive round-trip")
assert(decoded.boolean == true, "boolean should survive round-trip")
assert(#decoded.array == 3, "array should survive round-trip")
assert(decoded.object.key == "value", "object should survive round-trip")

print("✓ JSON round-trip works\n")

-- Test Lua Serialization
print("Testing toLua...")
local luaTable = {
    name = "test",
    count = 42,
    items = {1, 2, 3},
    nested = {key = "value"}
}

local luaCode = serialize.toLua(luaTable, "myTable")
print("Lua serialization:\n" .. luaCode)

assert(luaCode:find("myTable ="), "should include variable name")
assert(luaCode:find("name ="), "should include fields")

print("✓ toLua works\n")

-- Test Escape Characters
print("Testing escape characters...")
local escaped = serialize.toJSON("line1\nline2\ttab\"quote")
assert(escaped:find("\\n"), "should escape newline")
assert(escaped:find("\\t"), "should escape tab")
assert(escaped:find('\\"'), "should escape quote")

local unescaped = serialize.fromJSON(escaped)
assert(unescaped:find("\n"), "should unescape newline")

print("✓ Escape characters work\n")

print("=== All Serialize Tests Passed ===")
