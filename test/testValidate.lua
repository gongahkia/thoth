local validate = require("thoth.core.validate")

assert(validate.isNumber(5))
assert(validate.isString("x"))
assert(validate.isArray({1, 2, 3}))
assert(not validate.isArray({a = 1}))

local ok, err = validate.schema({name = "A", age = 20}, {
    type = "table",
    properties = {
        name = {type = "string", required = true},
        age = {type = "number", min = 0}
    }
})
assert(ok, err)

local guarded = validate.contract(function(a, b) return a + b end,
    function(a, b) return type(a) == "number" and type(b) == "number", "numbers only" end)
assert(guarded(2, 3) == 5)
