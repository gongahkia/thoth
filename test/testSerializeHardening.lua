local serialize = require("thoth.core.serialize")

local original = {label = "root"}
original.self = original
setmetatable(original, {kind = "meta"})

local copy = serialize.deepCopy(original)
assert(copy ~= original)
assert(copy.self == copy)
assert(getmetatable(copy) ~= getmetatable(original))
assert(getmetatable(copy).kind == "meta")

local escaped = {
    quote = [["quoted"]],
    slash = [[path\\to\\file]],
    whitespace = "line1\nline2\tend",
}
local encoded = serialize.toJSON(escaped)
local decoded = assert(serialize.fromJSON(encoded))
assert(decoded.quote == escaped.quote)
assert(decoded.slash == escaped.slash)
assert(decoded.whitespace == escaped.whitespace)

local invalidCases = {
    "{\"a\":1} trailing",
    "[1,,2]",
    "{\"a\":}",
    "\"unterminated",
}

for _, json in ipairs(invalidCases) do
    local value, err = serialize.fromJSON(json)
    assert(value == nil)
    assert(type(err) == "string" and #err > 0)
end

local trailingValue, trailingErr = serialize.fromJSON("{\"a\":1} trailing")
assert(trailingValue == nil)
assert(trailingErr == "Unexpected trailing content")
