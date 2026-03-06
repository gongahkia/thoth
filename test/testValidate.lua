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

local optionalOk, optionalErr = validate.schema({name = "A"}, {
    type = "table",
    properties = {
        name = {type = "string", required = true},
        nickname = {type = "string"}
    }
})
assert(optionalOk, optionalErr)

local requiredOk = validate.schema({name = "A"}, {
    type = "table",
    properties = {
        name = {type = "string", required = true},
        email = {type = "string", required = true}
    }
})
assert(not requiredOk)

local guarded = validate.contract(function(a, b) return a + b end,
    function(a, b) return type(a) == "number" and type(b) == "number", "numbers only" end)
assert(guarded(2, 3) == 5)
